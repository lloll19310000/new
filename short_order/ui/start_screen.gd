extends Control
## The main menu: continue your latest diner, start a new one (and name it),
## load any saved diner, change the settings, or quit. The front page looks
## like a laminated diner menu, with your saved diners as today's specials.

signal continue_pressed
signal resume_pressed
signal new_pressed
signal new_requested(diner_name: String)
signal load_requested(slot: String)
signal delete_requested(slot: String)

var _t := 0.0
var pages := {}
var saves: Array = []
var name_edit: LineEdit
var save_list: SaveList
var settings: SettingsBox
var load_button: Button
var settings_button: Button
var start_button: Button
var resume_button: Button
var specials: VBoxContainer
var _dark_style: StyleBox
var _paper_style: StyleBoxFlat

const PAPER := Color("f4ecd8")
const MENU_INK := Color("3a2e26")
const MENU_RED := Color("c8372d")

@onready var logo: Label = %Logo
@onready var card: PanelContainer = $Center/Box/Card
@onready var buttons: VBoxContainer = $Center/Box/Card/Buttons
@onready var intro: Label = $Center/Box/Card/Buttons/Intro
@onready var continue_button: Button = %ContinueButton
@onready var new_button: Button = %NewButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	intro.text = "An empty lot and $%s. Build a diner, hire a crew, and keep the coffee coming." % UiKit.thousands(int(Data.START_MONEY))
	new_button.text = "New diner"
	load_button = _button("Load a diner", "folder")
	settings_button = _button("Settings", "settings")
	buttons.add_child(load_button)
	buttons.move_child(load_button, new_button.get_index() + 1)
	buttons.add_child(settings_button)
	buttons.move_child(settings_button, load_button.get_index() + 1)
	resume_button = _button("Back to your diner", "play")
	resume_button.theme_type_variation = &"PrimaryButton"
	resume_button.pressed.connect(func():
		visible = false
		resume_pressed.emit())
	buttons.add_child(resume_button)
	buttons.move_child(resume_button, continue_button.get_index())
	pages["menu"] = buttons
	_dress_menu()
	pages["new"] = _new_page()
	pages["load"] = _load_page()
	pages["settings"] = _settings_page()
	for k in pages:
		if k != "menu":
			card.add_child(pages[k])
	continue_button.pressed.connect(continue_pressed.emit)
	new_button.pressed.connect(func():
		new_pressed.emit()
		name_edit.text = ""
		name_edit.placeholder_text = Data.DINER_NAMES.pick_random()
		show_page("new")
		name_edit.grab_focus.call_deferred())
	load_button.pressed.connect(func(): show_page("load"))
	settings_button.pressed.connect(func():
		settings.refresh()
		show_page("settings"))
	quit_button.pressed.connect(Sfx.quit_game)
	show_page("menu")


## The front page as a printed menu: cream paper, a red rim, a checked
## strip top and bottom, a laminate shine, and the buttons as menu items.
func _dress_menu() -> void:
	_dark_style = card.get_theme_stylebox("panel")
	_paper_style = StyleBoxFlat.new()
	_paper_style.bg_color = PAPER
	_paper_style.border_color = MENU_RED
	_paper_style.set_border_width_all(5)
	_paper_style.set_corner_radius_all(16)
	_paper_style.content_margin_left = 30
	_paper_style.content_margin_right = 30
	_paper_style.content_margin_top = 34
	_paper_style.content_margin_bottom = 30
	_paper_style.shadow_color = Color(0, 0, 0, 0.5)
	_paper_style.shadow_size = 14
	_paper_style.shadow_offset = Vector2(0, 6)
	card.draw.connect(_draw_paper)
	buttons.add_theme_constant_override("separation", 2)
	$Center/Box/Footer.visible = false
	intro.add_theme_color_override("font_color", MENU_INK.lightened(0.15))
	var head := UiKit.label("~ Menu ~", 20, MENU_RED, &"HeaderLabel")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(head)
	buttons.move_child(head, 0)
	for b in [resume_button, continue_button, new_button, load_button, settings_button, quit_button]:
		_menu_item(b)
	# saved diners, as the specials board
	specials = VBoxContainer.new()
	specials.add_theme_constant_override("separation", 2)
	buttons.add_child(specials)
	buttons.move_child(specials, quit_button.get_index())


func _draw_paper() -> void:
	if card.get_theme_stylebox("panel") != _paper_style:
		return
	var w := card.size.x
	var h := card.size.y
	# checked strips
	var sq := 9.0
	for row in [[12.0], [h - 12.0 - sq * 2.0]]:
		var y: float = row[0]
		var n := int((w - 40.0) / sq)
		var x0 := (w - n * sq) / 2.0
		for i in n:
			for j in 2:
				if (i + j) % 2 == 0:
					card.draw_rect(Rect2(x0 + i * sq, y + j * sq, sq, sq), MENU_RED.lerp(PAPER, 0.15))
	# a laminate shine across the corner
	var pts := PackedVector2Array([Vector2(w * 0.55, 5), Vector2(w * 0.78, 5), Vector2(w * 0.35, h - 5), Vector2(w * 0.12, h - 5)])
	card.draw_colored_polygon(pts, Color(1, 1, 1, 0.12))


## A menu line: dark ink, dotted leader to a "price" on the right.
func _menu_item(b: Button, price: String = "") -> void:
	b.theme_type_variation = &"FlatButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 17)
	for k in ["font_color", "icon_normal_color"]:
		b.add_theme_color_override(k, MENU_INK)
	for k in ["font_hover_color", "font_pressed_color", "font_focus_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, MENU_RED)
	b.add_theme_color_override("font_disabled_color", Color(MENU_INK, 0.35))
	b.add_theme_color_override("icon_disabled_color", Color(MENU_INK, 0.35))
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(MENU_RED, 0.08)
	hover.set_corner_radius_all(6)
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	var plain := hover.duplicate()
	plain.bg_color = Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", plain)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", plain)
	b.set_meta("price", price)
	if not b.draw.is_connected(_draw_leader.bind(b)):
		b.draw.connect(_draw_leader.bind(b))


func _draw_leader(b: Button) -> void:
	var price: String = b.get_meta("price", "")
	if price == "":
		return
	var font := b.get_theme_font("font")
	var fs := 15
	var tw := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
	var pw := font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := b.size.y / 2.0
	var x0 := 8.0 + (26.0 if b.icon != null else 0.0) + tw + 8.0
	var x1 := b.size.x - 8.0 - pw - 6.0
	var x := x0
	while x < x1:
		b.draw_circle(Vector2(x, y + 5.0), 1.2, Color(MENU_INK, 0.45))
		x += 6.0
	b.draw_string(font, Vector2(b.size.x - 8.0 - pw, y + 6.0), price, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, MENU_RED if not b.disabled else Color(MENU_INK, 0.35))


func _fill_specials() -> void:
	for c in specials.get_children():
		c.queue_free()
	if saves.is_empty():
		return
	var head := UiKit.label("Today's specials: your diners", 13, MENU_RED, &"StatLabel")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	specials.add_child(head)
	for sv in saves.slice(0, 3 if get_viewport_rect().size.y >= 820.0 else 2):
		var b := Button.new()
		b.text = str(sv["name"])
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(360, 0)
		b.tooltip_text = "Day %d · $%s · %d staff. Click to open it." % [sv["day"], UiKit.thousands(int(sv["money"])), sv["staff"]]
		_menu_item(b, "Day %d  %s" % [sv["day"], "★".repeat(clampi(int(round(sv["rating"])), 1, 5))])
		b.add_theme_font_size_override("font_size", 15)
		var sl: String = sv["slot"]
		b.pressed.connect(func(): load_requested.emit(sl))
		specials.add_child(b)


func _button(text: String, icon_name: String) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = UiKit.icon(icon_name)
	return b


func _page(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(380, 0)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = &"HeaderLabel"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	return box


func _back(box: VBoxContainer) -> void:
	var b := _button("Back", "chevron_left")
	b.theme_type_variation = &"FlatButton"
	b.pressed.connect(func(): show_page("menu"))
	box.add_child(b)


func _new_page() -> VBoxContainer:
	var box := _page("A new diner")
	var l := Label.new()
	l.text = "What's it called?"
	l.theme_type_variation = &"BodyLabel"
	box.add_child(l)
	name_edit = LineEdit.new()
	name_edit.max_length = 32
	name_edit.text_submitted.connect(func(_t): _start_new())
	box.add_child(name_edit)
	var hint := Label.new()
	hint.theme_type_variation = &"MutedLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(300, 0)
	hint.text = "Leave it empty for the suggestion. It gets its own save, and saves itself every morning."
	box.add_child(hint)
	start_button = _button("Open the lot", "play")
	start_button.theme_type_variation = &"PrimaryButton"
	start_button.pressed.connect(_start_new)
	box.add_child(start_button)
	_back(box)
	return box


func _start_new() -> void:
	var n := name_edit.text.strip_edges()
	new_requested.emit(n if n != "" else name_edit.placeholder_text)


func _load_page() -> VBoxContainer:
	var box := _page("Your diners")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(420, 300)
	save_list = SaveList.new()
	save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_list.picked.connect(func(sl: String): load_requested.emit(sl))
	save_list.deleted.connect(func(sl: String): delete_requested.emit(sl))
	scroll.add_child(save_list)
	box.add_child(scroll)
	_back(box)
	return box


func _settings_page() -> VBoxContainer:
	var box := _page("Settings")
	settings = SettingsBox.new()
	box.add_child(settings)
	_back(box)
	return box


func show_page(key: String) -> void:
	for k in pages:
		pages[k].visible = k == key
	if _paper_style != null:
		card.add_theme_stylebox_override("panel", _paper_style if key == "menu" else _dark_style)
		card.queue_redraw()


## Shows the menu. saves: from main.list_saves(), newest first. playing: the
## diner you came from (the pause menu's Main menu), or "".
func open(saves_: Array, playing: String = "") -> void:
	saves = saves_
	var has_save := not saves.is_empty()
	resume_button.visible = playing != ""
	# on its own the menu covers the empty lot; over a diner you can see it behind
	$Backdrop.color.a = 0.8 if playing != "" else 0.93
	resume_button.text = "Back to %s" % playing
	continue_button.visible = has_save and playing == ""
	if has_save:
		continue_button.text = "Continue %s" % saves[0]["name"]
		continue_button.set_meta("price", "Day %d" % saves[0]["day"])
	load_button.disabled = not has_save
	save_list.fill(saves, "load")
	_fill_specials()
	resume_button.set_meta("price", "Day %d" % GameState.day)
	show_page("menu")
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3).from(0.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	logo.rotation = sin(_t * 1.3) * 0.015
	logo.pivot_offset = logo.size / 2.0
