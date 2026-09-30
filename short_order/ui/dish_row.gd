extends PanelContainer
## One dish on the printed menu: its picture and name, a dotted leader to the
## price chip (tap − and +, or drag the price sideways), what it makes per
## plate after ingredients (green is good, red is thin), a star for today's
## special and a switch to take it off the menu. Locked recipes show how to
## unlock them.

const PAPER_INK := Color("3a2e26")
const PAPER_MUTED := Color("7a6a5a")
const PAPER_RED := Color("b23a2e")
const PAPER_GREEN := Color("2f7d55")
const PAPER_GOLD := Color("9a6c0c")
const PRICE_STEP := 0.5

var dish := ""
var special_button: Button
var price_label: Label
var profit_label: Label
var minus_button: Button
var plus_button: Button
var lock_label: Label
var _drag_from := -1.0
var _drag_price := 0.0

@onready var icon: ArtIcon = %Icon
@onready var name_label: Label = %Name
@onready var note: Label = %Note
@onready var price: SpinBox = %Price
@onready var on_switch: CheckButton = %On


func setup(d: String) -> void:
	dish = d


func _ready() -> void:
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.content_margin_left = 4
	clear.content_margin_right = 4
	clear.content_margin_top = 3
	clear.content_margin_bottom = 3
	add_theme_stylebox_override("panel", clear)
	icon.what = "dish:" + dish
	name_label.text = Data.DISHES[dish]["name"]
	name_label.add_theme_color_override("font_color", PAPER_INK)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size.x = 40
	name_label.draw.connect(_draw_leader)
	note.add_theme_font_size_override("font_size", 11)
	special_button = Button.new()
	special_button.theme_type_variation = &"FlatButton"
	special_button.icon = UiKit.icon("star")
	special_button.toggle_mode = true
	special_button.custom_minimum_size = Vector2(26, 22)
	special_button.expand_icon = true
	name_label.get_parent().add_child(special_button)
	special_button.toggled.connect(func(on: bool):
		GameState.special = dish if on else ("" if GameState.special == dish else GameState.special)
		GameState.menu_changed.emit())
	price.value_changed.connect(func(v: float):
		GameState.menu[dish]["price"] = v
		refresh())
	on_switch.toggled.connect(func(on: bool):
		GameState.menu[dish]["on"] = on
		refresh())
	# the price chip replaces the spin box (which stays, hidden, for the value)
	price.visible = false
	var chip_box := VBoxContainer.new()
	chip_box.add_theme_constant_override("separation", -2)
	chip_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 0)
	chip_box.add_child(chip)
	minus_button = _chip_button("minus", -PRICE_STEP)
	chip.add_child(minus_button)
	price_label = Label.new()
	price_label.custom_minimum_size = Vector2(52, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.theme_type_variation = &"StatLabel"
	price_label.add_theme_color_override("font_color", PAPER_RED)
	price_label.mouse_filter = Control.MOUSE_FILTER_STOP
	price_label.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	price_label.tooltip_text = "Drag sideways to change the price, or tap − and +."
	price_label.gui_input.connect(_price_input)
	chip.add_child(price_label)
	plus_button = _chip_button("plus", PRICE_STEP)
	chip.add_child(plus_button)
	profit_label = Label.new()
	profit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profit_label.add_theme_font_size_override("font_size", 11)
	profit_label.mouse_filter = Control.MOUSE_FILTER_PASS
	chip_box.add_child(profit_label)
	price.get_parent().add_child(chip_box)
	price.get_parent().move_child(chip_box, price.get_index())
	# the on/off switch sits on a dark pill so it reads on the paper
	var pill := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("3a2e26")
	ps.set_corner_radius_all(12)
	ps.content_margin_left = 2
	ps.content_margin_right = 2
	pill.add_theme_stylebox_override("panel", ps)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row_box := on_switch.get_parent()
	var at := on_switch.get_index()
	on_switch.reparent(pill)
	row_box.add_child(pill)
	row_box.move_child(pill, at)
	lock_label = Label.new()
	lock_label.add_theme_font_size_override("font_size", 11)
	lock_label.add_theme_color_override("font_color", PAPER_MUTED)
	lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_label.custom_minimum_size = Vector2(110, 0)
	lock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock_label.visible = false
	price.get_parent().add_child(lock_label)
	refresh()


func _chip_button(ic: String, step: float) -> Button:
	var b := Button.new()
	b.icon = UiKit.icon(ic)
	b.theme_type_variation = &"FlatButton"
	b.custom_minimum_size = Vector2(22, 22)
	b.expand_icon = true
	b.add_theme_color_override("icon_normal_color", PAPER_INK)
	b.add_theme_color_override("icon_hover_color", PAPER_RED)
	b.tooltip_text = "%s the price by $%.2f" % ["Raise" if step > 0 else "Lower", absf(step)]
	b.pressed.connect(func(): price.value = price.value + step)
	return b


func _price_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = e.global_position.x if e.pressed else -1.0
		_drag_price = price.value
	elif e is InputEventMouseMotion and _drag_from >= 0.0:
		var steps := roundi((e.global_position.x - _drag_from) / 10.0)
		price.value = _drag_price + steps * 0.25


func _draw_leader() -> void:
	var font := name_label.get_theme_font("font")
	var fs := name_label.get_theme_font_size("font_size")
	var tw := font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := tw + 6.0
	var y := name_label.size.y * 0.72
	while x < name_label.size.x - 2.0:
		name_label.draw_circle(Vector2(x, y), 1.0, Color(PAPER_INK, 0.35))
		x += 5.0


## Ingredients for one plate at today's supplier prices.
func plate_cost() -> float:
	var c := 0.0
	var needs: Dictionary = Data.DISHES[dish]["needs"]
	for ing in needs:
		c += needs[ing] * Stock.unit_cost(ing)
	return c


func refresh(lot = null) -> void:
	var info: Dictionary = Data.DISHES[dish]
	name_label.text = info["name"]
	var known := GameState.dish_known(dish)
	price.set_value_no_signal(GameState.menu[dish]["price"])
	var p: float = GameState.menu[dish]["price"]
	price_label.text = "$%.2f" % p if not is_equal_approx(p, roundf(p)) else "$%d" % int(p)
	var cost := plate_cost()
	var profit := p - cost
	var margin := profit / p if p > 0.0 else 0.0
	profit_label.text = ("+$%.2f a plate" % profit) if profit >= 0.0 else ("-$%.2f a plate" % -profit)
	profit_label.add_theme_color_override("font_color", PAPER_GREEN if margin >= 0.7 else (PAPER_GOLD if margin >= 0.5 else PAPER_RED))
	profit_label.tooltip_text = "Ingredients cost about $%.2f a plate (%s supplier), so you keep $%.2f of the $%.2f price (%d%%), before wages and bills." % [cost,
		Data.SUPPLIERS[GameState.supplier]["name"].to_lower(), profit, p, int(round(margin * 100))]
	var is_special := GameState.special == dish
	special_button.set_pressed_no_signal(is_special)
	special_button.self_modulate = PAPER_GOLD if is_special else Color(PAPER_INK, 0.3)
	special_button.tooltip_text = "Today's special: customers pick it %d times as often, and like getting it." % Data.SPECIAL_PICKS if not is_special else "This is today's special. Click to stop."
	on_switch.set_pressed_no_signal(GameState.menu[dish]["on"])
	# locked recipes: greyed, with how to get them
	for c in [special_button, on_switch.get_parent(), minus_button, plus_button, price_label, profit_label]:
		c.visible = known
	lock_label.visible = not known
	modulate = Color(1, 1, 1, 1.0 if known else 0.55)
	if not known:
		note.text = "Locked recipe"
		note.add_theme_color_override("font_color", PAPER_MUTED)
		lock_label.text = Data.RECIPES.get(dish, {}).get("how", "Not yet")
		tooltip_text = "%s: a recipe you haven't learned yet. %s." % [info["name"], lock_label.text]
		return
	var station: String = info["station"]
	var usual: float = info["price"]
	var text := "Usual price $%s" % (str(int(usual)) if is_equal_approx(usual, roundf(usual)) else "%.2f" % usual)
	var col := PAPER_MUTED
	if is_special:
		text = "Today's special"
		col = PAPER_GOLD
	if lot != null and not lot.has_type(station):
		text = "Needs a " + Data.FURNITURE[station]["name"].to_lower()
		col = PAPER_RED
	elif lot != null and info.get("ice", false) and not lot.has_type("ice"):
		text = "Needs an ice machine"
		col = PAPER_RED
	elif Stock.sold_out.has(dish):
		text = "Sold out: nothing left to make it"
		col = PAPER_RED
	elif GameState.menu[dish]["price"] > info["price"] * 1.25:
		text = "Pricey: customers will grumble"
		col = PAPER_GOLD
	note.text = text
	note.add_theme_color_override("font_color", col)
	var needs: Array = []
	for ing in info["needs"]:
		needs.append(Data.INGREDIENTS[ing]["name"].to_lower())
	tooltip_text = "%s: made at the %s from %s. Takes about %d minutes." % [info["name"],
		Data.FURNITURE[station]["name"].to_lower(), ", ".join(needs) if not needs.is_empty() else "nothing from the fridge", int(info["minutes"])]
