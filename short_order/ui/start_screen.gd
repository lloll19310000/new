extends Control
## The main menu: continue your latest diner, start a new one (and name it),
## load any saved diner, change the settings, or quit.

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
		continue_button.text = "Continue: %s, day %d" % [saves[0]["name"], saves[0]["day"]]
	load_button.disabled = not has_save
	new_button.theme_type_variation = &"Button" if has_save else &"PrimaryButton"
	save_list.fill(saves, "load")
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
