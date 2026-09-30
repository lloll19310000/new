extends Control
## The pause menu (Esc, or the menu button on the top bar): resume, save,
## load another diner, settings, back to the main menu, or quit. The game
## pauses while it's open.

signal save_requested(slot: String)       # "" = a new slot
signal load_requested(slot: String)
signal delete_requested(slot: String)
signal main_menu_requested
signal closed

var main
var pages := {}
var save_list: SaveList
var load_list: SaveList
var settings: SettingsBox
var save_button: Button
var save_note: Label
var title: Label
var _speed_before := 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.045, 0.035, 0.66)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ModalPanel"
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	title = Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var stack := VBoxContainer.new()
	col.add_child(stack)
	pages["menu"] = _menu_page()
	pages["save"] = _list_page("Save this diner", true)
	pages["load"] = _list_page("Load a diner", false)
	pages["settings"] = _settings_page()
	for k in pages:
		stack.add_child(pages[k])


func _button(text: String, icon_name: String, variation: StringName = &"Button") -> Button:
	var b := Button.new()
	b.text = text
	b.icon = UiKit.icon(icon_name)
	b.theme_type_variation = variation
	return b


func _menu_page() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(340, 0)
	var resume := _button("Back to the diner", "play", &"PrimaryButton")
	resume.pressed.connect(close)
	box.add_child(resume)
	save_button = _button("Save", "save")
	save_button.pressed.connect(func():
		save_list.fill(main.list_saves(), "save", main.slot)
		show_page("save"))
	box.add_child(save_button)
	save_note = Label.new()
	save_note.theme_type_variation = &"MutedLabel"
	save_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_note.custom_minimum_size = Vector2(300, 0)
	box.add_child(save_note)
	var load_b := _button("Load a diner", "folder")
	load_b.pressed.connect(func():
		load_list.fill(main.list_saves(), "load", main.slot)
		show_page("load"))
	box.add_child(load_b)
	var set_b := _button("Settings", "settings")
	set_b.pressed.connect(func():
		settings.refresh()
		show_page("settings"))
	box.add_child(set_b)
	var menu_b := _button("Main menu", "chevron_left")
	menu_b.pressed.connect(func():
		visible = false
		main_menu_requested.emit())
	box.add_child(menu_b)
	var quit := _button("Quit the game", "close", &"DangerButton")
	quit.pressed.connect(Sfx.quit_game)
	box.add_child(quit)
	return box


func _list_page(heading: String, saving: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var t := Label.new()
	t.text = heading
	t.theme_type_variation = &"HeaderLabel"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(430, 300)
	var list := SaveList.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)
	if saving:
		save_list = list
		list.picked.connect(func(sl: String):
			save_requested.emit(sl)
			close())
		list.new_slot_picked.connect(func():
			save_requested.emit("")
			close())
	else:
		load_list = list
		list.picked.connect(func(sl: String):
			visible = false
			load_requested.emit(sl))
	list.deleted.connect(func(sl: String):
		delete_requested.emit(sl)
		list.fill(main.list_saves(), list.mode, main.slot))
	var back := _button("Back", "chevron_left", &"FlatButton")
	back.pressed.connect(func(): show_page("menu"))
	box.add_child(back)
	return box


func _settings_page() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(340, 0)
	settings = SettingsBox.new()
	box.add_child(settings)
	var back := _button("Back", "chevron_left", &"FlatButton")
	back.pressed.connect(func(): show_page("menu"))
	box.add_child(back)
	return box


func show_page(key: String) -> void:
	for k in pages:
		pages[k].visible = k == key


func open() -> void:
	if visible:
		return
	_speed_before = GameState.speed
	GameState.speed = 0
	var can_save := GameState.phase == GameState.Phase.PLANNING
	save_button.disabled = not can_save
	title.text = GameState.diner_name if GameState.diner_name != "" else "Paused"
	save_note.text = ("Saving keeps this morning. The diner also saves itself every morning." if can_save
		else "You can save in the morning, before you start the day. The diner also saves itself every morning.")
	show_page("menu")
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.speed = _speed_before
	closed.emit()
