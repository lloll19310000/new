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
var game_menu
var _speed_before_event := 1


func _ready() -> void:
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
	build_menu.resized.connect(place_toasts)
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
	refresh_all()
	place_toasts.call_deferred()


# ------------------------------------------------------------------ called by the game

func show_selection(thing) -> void:
	inspect_card.show_thing(thing)


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


func set_speed(v: int) -> void:
	if v > 0 and event_card != null and event_card.visible:
		return   # answer the event first
	GameState.speed = v
	top_bar.show_speed(v)


func place_toasts() -> void:
	# toasts sit just above the build menu, which grows when a tray opens
	toasts.offset_bottom = -(build_menu.size.y + 18.0)
	toasts.offset_top = toasts.offset_bottom - 10.0


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
		KEY_TAB:
			if side_panel.is_open:
				side_panel.close()
			else:
				side_panel.open(side_panel.current)
		_:
			return
	get_viewport().set_input_as_handled()
