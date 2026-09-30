extends CanvasLayer
## The whole interface. Each part is its own scene in res://ui/ — open
## hud.tscn in the editor to see the layout, or any piece (top_bar.tscn,
## build_menu.tscn, side_panel.tscn...) to change it. The look comes from
## res://ui/theme.tres. This script only wires the pieces to the game.

var main

@onready var top_bar = %TopBar
@onready var build_menu = %BuildMenu
@onready var side_panel = %SidePanel
@onready var checklist = %Checklist
@onready var today_card = %TodayCard
@onready var inspect_card = %InspectCard
@onready var toasts = %Toasts
@onready var report = %Report
@onready var help = %Help
@onready var start = %Start
@onready var event_card = %EventCard
var tickets_card
var inbox
var overlay_bar: HBoxContainer
var overlay_buttons := {}
var overlay_legend: Label
var game_menu
var _speed_before_event := 1


## Draws the whole interface at the chosen size (Settings > Interface):
## the layer is scaled and the root stretched to fill the window.
func apply_ui_scale() -> void:
	var s: float = Sfx.ui_scale
	scale = Vector2(s, s)
	var root: Control = $Root
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.position = Vector2.ZERO
	root.size = get_viewport().get_visible_rect().size / s
	_place_overlay_bar.call_deferred()


func _ready() -> void:
	apply_ui_scale()
	get_viewport().size_changed.connect(apply_ui_scale)
	Sfx.settings_changed.connect(apply_ui_scale)
	for n in [checklist, today_card, inspect_card]:
		n.main = main
	# the ticket rail sits under the Today card
	tickets_card = preload("res://ui/tickets_card.gd").new()
	tickets_card.name = "TicketsCard"
	tickets_card.main = main
	today_card.get_parent().add_child(tickets_card)
	today_card.get_parent().move_child(tickets_card, today_card.get_index() + 1)
	side_panel.setup(main)
	# the pause menu sits over everything
	game_menu = preload("res://ui/game_menu.gd").new()
	game_menu.name = "GameMenu"
	game_menu.main = main
	start.get_parent().add_child(game_menu)
	game_menu.save_requested.connect(func(sl: String):
		if main.save_game(sl if sl != "" else main.new_slot()):
			show_toast("Saved %s." % GameState.diner_name, "good"))
	game_menu.load_requested.connect(_load)
	game_menu.delete_requested.connect(main.delete_save)
	game_menu.main_menu_requested.connect(func():
		set_speed(0)
		start.open(main.list_saves(), GameState.diner_name))
	top_bar.menu_pressed.connect(game_menu.open)
	top_bar.open_pressed.connect(func():
		if GameState.phase == GameState.Phase.PREP:
			main.open_doors()
		else:
			main.open_diner())
	top_bar.speed_chosen.connect(set_speed)
	top_bar.help_pressed.connect(help.toggle)
	build_menu.tool_chosen.connect(func(t: String): main.build.set_tool(t))
	side_panel.hire_requested.connect(main.hire)
	side_panel.fire_requested.connect(main.fire)
	report.next_pressed.connect(main.start_next_day)
	start.continue_pressed.connect(func():
		var saves: Array = main.list_saves()
		if not saves.is_empty():
			_load(saves[0]["slot"]))
	start.load_requested.connect(_load)
	start.delete_requested.connect(func(sl: String):
		main.delete_save(sl)
		start.open(main.list_saves()))
	start.resume_pressed.connect(func(): set_speed(1))
	start.new_requested.connect(func(n: String):
		main.new_game(n)
		main.save_game()
		start.visible = false
		refresh_all()
		help.visible = true)
	Events.ask.connect(show_event)
	event_card.chosen.connect(func(i: int):
		Events.choose(i)
		set_speed(maxi(_speed_before_event, 1)))
	GameState.staff_changed.connect(refresh_checklist)
	GameState.phase_changed.connect(func(_p): refresh_checklist())
	# the map overlays: dirt, foot traffic, table waits, station wear
	overlay_bar = _overlay_bar()
	toasts.get_parent().add_child(overlay_bar)
	toasts.get_parent().move_child(overlay_bar, build_menu.get_index() + 1)
	build_menu.resized.connect(_place_overlay_bar)
	_place_overlay_bar.call_deferred()
	# the message inbox, under the bell in the top bar
	inbox = preload("res://ui/inbox.gd").new()
	inbox.name = "Inbox"
	inbox.toasts = toasts
	toasts.get_parent().add_child(inbox)
	toasts.get_parent().move_child(inbox, toasts.get_index() + 1)
	inbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	inbox.offset_top = 64.0
	inbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top_bar.inbox_pressed.connect(inbox.toggle)
	toasts.history_changed.connect(func():
		top_bar.show_unread(toasts.unread)
		if inbox.visible:
			inbox.refresh())
	refresh_all()


# ------------------------------------------------------------------ called by the game

func show_selection(thing) -> void:
	inspect_card.show_thing(thing)
	checklist.pinned = false
	_fit_left_column.call_deferred()


func on_tool_changed(t: String) -> void:
	build_menu.set_current(t)


func show_toast(text: String, kind: String = "") -> void:
	toasts.show_toast(text, kind)


func refresh_checklist() -> void:
	checklist.refresh()


func show_start() -> void:
	start.open(main.list_saves())


func _load(sl: String) -> void:
	if main.load_game(sl):
		start.visible = false
		game_menu.visible = false
		refresh_all()
		show_toast("Welcome back to %s. Day %d." % [GameState.diner_name if GameState.diner_name != "" else "your diner", GameState.day], "good")
	else:
		show_toast("That save couldn't be loaded.", "bad")


## An event needs you to choose: pause and show the card.
func show_event(ev: Dictionary) -> void:
	_speed_before_event = GameState.speed
	set_speed(0)
	event_card.show_event(ev)


func show_report(r: Dictionary) -> void:
	report.show_report(r)


func refresh_all() -> void:
	set_speed(GameState.speed)
	top_bar.refresh()
	checklist.refresh()
	side_panel.pages["staff"].refresh()
	side_panel.pages["menu"].refresh()
	side_panel.pages["supplies"].refresh()
	side_panel.pages["crew"].refresh()
	side_panel.pages["office"].refresh()
	side_panel.pages["goals"].refresh()


func set_speed(v: int) -> void:
	if v > 0 and event_card != null and event_card.visible:
		return   # answer the event first
	GameState.speed = v
	top_bar.show_speed(v)


func _overlay_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.name = "OverlayBar"
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icons := {"dirt": "clean", "traffic": "people", "waits": "clock", "wear": "fix"}
	for m in ["dirt", "traffic", "waits", "wear"]:
		var b := Button.new()
		b.toggle_mode = true
		b.icon = UiKit.icon(icons[m])
		b.theme_type_variation = &"SmallButton"
		b.custom_minimum_size = Vector2(30, 28)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.tooltip_text = "Show %s on the map (V cycles).\n%s" % [main.heatmap.NAMES[m].to_lower(), main.heatmap.LEGENDS[m]]
		b.toggled.connect(func(on: bool):
			if on:
				show_overlay(m)
			elif main.heatmap.mode == m:
				show_overlay(""))
		bar.add_child(b)
		overlay_buttons[m] = b
	overlay_legend = UiKit.label("", 12, UiKit.INK, &"SmallLabel")
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.1, 0.09, 0.9)
	st.set_corner_radius_all(6)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	overlay_legend.add_theme_stylebox_override("normal", st)
	overlay_legend.visible = false
	overlay_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_legend.custom_minimum_size = Vector2(300, 0)
	bar.add_child(overlay_legend)
	bar.move_child(overlay_legend, 0)
	return bar


## Switches a map overlay on ("dirt", "traffic", "waits", "wear") or off ("").
func show_overlay(m: String) -> void:
	main.heatmap.set_mode(m)
	for k in overlay_buttons:
		overlay_buttons[k].set_pressed_no_signal(k == main.heatmap.mode)
	var mode: String = main.heatmap.mode
	overlay_legend.visible = mode != ""
	if mode != "":
		overlay_legend.text = "%s: %s" % [main.heatmap.NAMES[mode], main.heatmap.LEGENDS[mode]]
	_place_overlay_bar.call_deferred()


## Right above the right end of the build bar, clear of the cards on the left.
func _place_overlay_bar() -> void:
	overlay_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var right: float = build_menu.position.x + build_menu.size.x
	# ...and left of the side panel when it's out
	if side_panel.is_open and side_panel.panel.visible:
		right = minf(right, side_panel.panel.global_position.x - 10.0)
	overlay_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	overlay_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	overlay_bar.offset_right = right
	overlay_bar.offset_left = right - overlay_bar.get_combined_minimum_size().x
	overlay_bar.offset_bottom = -(build_menu.size.y + 16.0)
	overlay_bar.offset_top = overlay_bar.offset_bottom - 28.0


func _process(_delta: float) -> void:
	# the side panel slides in and out: keep the overlay buttons beside it
	if overlay_bar != null and Engine.get_process_frames() % 10 == 0:
		_place_overlay_bar()
		_fit_left_column()


## The cards on the left must stay above the build bar: if the inspect card
## (a plot's Buy button, a person's details) would run under it, the morning
## checklist folds into its pill to make room.
func _fit_left_column() -> void:
	var col: Control = checklist.get_parent()
	var limit: float = build_menu.position.y - 8.0
	var bottom: float = col.position.y + col.get_combined_minimum_size().y
	if bottom > limit and checklist.visible and not checklist.collapsed and not checklist.pinned:
		checklist.collapsed = true
		checklist.refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		# Esc: stop building, then let go of the selection, then the pause menu
		if start.visible:
			return
		if game_menu.visible:
			game_menu.close()
		elif inbox.visible:
			inbox.visible = false
		elif main.build.tool != "select":
			main.build.set_tool("select")
		elif main.build.selection != null:
			main.build.selection = null
			main.build.selected.emit(null)
			main.build.queue_redraw()
		else:
			game_menu.open()
		get_viewport().set_input_as_handled()
		return
	if game_menu.visible or start.visible:
		return
	match k.keycode:
		KEY_SPACE:
			set_speed(1 if GameState.speed == 0 else 0)
		KEY_1:
			set_speed(1)
		KEY_2:
			set_speed(2)
		KEY_3:
			set_speed(4)
		KEY_4:
			set_speed(8)
		KEY_P:
			main.take_photo()
		KEY_V:
			main.heatmap.cycle()
			show_overlay(main.heatmap.mode)
		KEY_TAB:
			if side_panel.is_open:
				side_panel.close()
			else:
				side_panel.open(side_panel.current)
		_:
			return
	get_viewport().set_input_as_handled()
