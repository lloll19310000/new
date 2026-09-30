extends PanelContainer
## One dish on the Menu page: switch it on or off, set its price, and
## star it to make it today's special.

var dish := ""
var special_button: Button

@onready var icon: ArtIcon = %Icon
@onready var name_label: Label = %Name
@onready var note: Label = %Note
@onready var price: SpinBox = %Price
@onready var on_switch: CheckButton = %On


func setup(d: String) -> void:
	dish = d


func _ready() -> void:
	icon.what = "dish:" + dish
	name_label.text = Data.DISHES[dish]["name"]
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
	refresh()


func refresh(lot = null) -> void:
	var info: Dictionary = Data.DISHES[dish]
	price.set_value_no_signal(GameState.menu[dish]["price"])
	var is_special := GameState.special == dish
	special_button.set_pressed_no_signal(is_special)
	special_button.self_modulate = UiKit.GOLD if is_special else UiKit.FAINT
	special_button.tooltip_text = "Today's special: customers pick it %d times as often, and like getting it." % Data.SPECIAL_PICKS if not is_special else "This is today's special. Click to stop."
	on_switch.set_pressed_no_signal(GameState.menu[dish]["on"])
	var station: String = info["station"]
	var usual: float = info["price"]
	var text := "Usual price $%s" % (str(int(usual)) if is_equal_approx(usual, roundf(usual)) else "%.2f" % usual)
	var col := UiKit.MUTED
	if is_special:
		text = "Today's special"
		col = UiKit.GOLD
	if lot != null and not lot.has_type(station):
		text = "Needs a " + Data.FURNITURE[station]["name"].to_lower()
		col = UiKit.CHERRY
	elif lot != null and info.get("ice", false) and not lot.has_type("ice"):
		text = "Needs an ice machine"
		col = UiKit.CHERRY
	elif Stock.sold_out.has(dish):
		text = "Sold out: nothing left to make it"
		col = UiKit.CHERRY
	elif GameState.menu[dish]["price"] > info["price"] * 1.25:
		text = "Pricey: customers will grumble"
		col = UiKit.GOLD
	note.text = text
	note.add_theme_color_override("font_color", col)
	var needs: Array = []
	for ing in info["needs"]:
		needs.append(Data.INGREDIENTS[ing]["name"].to_lower())
	tooltip_text = "%s: made at the %s from %s. Takes about %d minutes." % [info["name"],
		Data.FURNITURE[station]["name"].to_lower(), ", ".join(needs) if not needs.is_empty() else "nothing from the fridge", int(info["minutes"])]
