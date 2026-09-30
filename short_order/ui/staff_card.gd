extends PanelContainer
## One member of staff: portrait, hometown, traits, mood, what they're doing,
## skills, energy, friends and rivals, and their job priorities. Click a
## priority to raise it, right-click to lower it. The star makes them a
## manager; the x lets them go (click twice to confirm). Hover the name for
## their life story.

signal fire_requested(who)

var who = null
var priority_buttons := {}
var _fire_armed := 0.0
var shift_button: Button
var train_button: Button
var train_menu: PopupMenu
var _train_ids: Array = []

@onready var portrait: Portrait = %Portrait
@onready var name_label: Label = %Name
@onready var traits_box: HFlowContainer = %Traits
@onready var status_icon: TextureRect = %StatusIcon
@onready var status_label: Label = %Status
@onready var wage_label: Label = %Wage
@onready var fire_button: Button = %Fire
@onready var cook_bar: ProgressBar = %CookBar
@onready var cook_value: Label = %CookValue
@onready var serve_bar: ProgressBar = %ServeBar
@onready var serve_value: Label = %ServeValue
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var priorities_box: HBoxContainer = %Priorities
@onready var info_box: VBoxContainer = %Info
@onready var mood_icon: TextureRect = %MoodIcon
@onready var origin_label: Label = %Origin
@onready var manager_button: Button = %Manager
@onready var relations: Label = %Relations
@onready var stress_bar: ProgressBar = %StressBar
var _traits_key := ""


func setup(s) -> void:
	who = s


func _ready() -> void:
	fire_button.pressed.connect(_on_fire)
	manager_button.toggled.connect(func(on: bool): Crew.set_manager(who, on))
	# their shift: click to go Opening -> Closing -> Double
	shift_button = Button.new()
	shift_button.theme_type_variation = &"SmallButton"
	shift_button.icon = UiKit.icon("clock")
	shift_button.custom_minimum_size = Vector2(0, 24)
	shift_button.add_theme_font_size_override("font_size", 11)
	shift_button.pressed.connect(func():
		var i := Data.SHIFT_ORDER.find(who.shift)
		who.shift = Data.SHIFT_ORDER[(i + 1) % Data.SHIFT_ORDER.size()]
		GameState.staff_changed.emit())
	wage_label.get_parent().add_child(shift_button)
	# training: pick someone better to show them the ropes
	train_button = Button.new()
	train_button.theme_type_variation = &"FlatButton"
	train_button.icon = UiKit.icon("school")
	train_button.toggle_mode = false
	manager_button.get_parent().add_child(train_button)
	manager_button.get_parent().move_child(train_button, manager_button.get_index())
	train_menu = PopupMenu.new()
	add_child(train_menu)
	train_menu.id_pressed.connect(_on_train_pick)
	train_button.pressed.connect(func():
		train_menu.clear()
		_train_ids = []
		var options: Array = Shifts.possible_trainers(who)
		for o in options:
			train_menu.add_item("Train with %s (cook %d, serve %d)" % [o.person_name, o.cooking, o.service], _train_ids.size())
			_train_ids.append(o.id)
		if who.trainer_id > 0:
			train_menu.add_separator()
			train_menu.add_item("Stop training", 999)
		if options.is_empty() and who.trainer_id <= 0:
			train_menu.add_item("Nobody here is 2 or more points better", 998)
			train_menu.set_item_disabled(train_menu.item_count - 1, true)
		train_menu.position = Vector2i(train_button.get_screen_position() + Vector2(0, train_button.size.y))
		train_menu.popup())
	for j in Data.JOBS:
		var b := Button.new()
		b.theme_type_variation = &"PriorityButton"
		b.custom_minimum_size = Vector2(44, 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = UiKit.icon(UiKit.JOB_ICONS[j])
		b.pressed.connect(_step_priority.bind(j, 1))
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
				_step_priority(j, -1)
				b.accept_event())
		priorities_box.add_child(b)
		priority_buttons[j] = b
	portrait.show_person(who)
	name_label.text = who.person_name
	origin_label.text = Data.hometown(who.origin)
	info_box.tooltip_text = "%s\n\n%s\nSignature dish: %s" % [who.person_name, who.bio, who.origin.get("dish", "?")]
	refresh()


func _on_train_pick(id: int) -> void:
	if id == 999:
		Shifts.set_trainer(who, null)
	elif id >= 0 and id < _train_ids.size():
		Shifts.set_trainer(who, Crew.by_id(_train_ids[id]))


func _step_priority(job: String, step: int) -> void:
	# order when clicking: - 1 2 3 4 -   (right-click goes the other way)
	var v: int = who.priorities[job]
	v = (v + step + 5) % 5
	who.priorities[job] = v
	GameState.staff_changed.emit()


func status_text() -> String:
	if who.away:
		return "Off sick" if who.sick_days > 0 and who.away_day != GameState.day else "Day off"
	if who.no_show:
		return "Didn't show up"
	if not who.at_work:
		if GameState.is_active():
			if who.came_at >= 0.0:
				return "Gone home"
			if who.arrive_at >= 0.0:
				return "In at %s%s" % [DayTimeline.clock(who.arrive_at), " (late)" if who.late_by > 0.0 else ""]
			return "Called in sick"
		return "Off"
	return who.status + (" (sick)" if who.sick_at_work else "")


func _on_fire() -> void:
	if _fire_armed > 0.0:
		fire_requested.emit(who)
		return
	_fire_armed = 3.0
	fire_button.text = "Let go?"
	fire_button.modulate = Color("ff8f7a")


func _process(delta: float) -> void:
	if _fire_armed > 0.0:
		_fire_armed -= delta
		if _fire_armed <= 0.0:
			fire_button.text = ""
			fire_button.modulate = Color.WHITE


func refresh() -> void:
	if who == null or not is_instance_valid(who):
		return
	wage_label.text = "$%d/shift" % who.wage
	if who.tips_today >= 1.0:
		wage_label.text = "$%d +$%d tips" % [who.wage, int(who.tips_today)]
	wage_label.tooltip_text = "Paid $%d for an 8-hour shift ($%.2f an hour), and time and a half after that. Tips so far today: $%d (%s)." % [
		who.wage, who.wage / Data.SHIFT_HOURS, int(who.tips_today), "from the tables they served" if Books.tip_policy == "keep" else "the shared pot is split at night"]
	shift_button.text = Data.SHIFTS[who.shift]["name"]
	shift_button.tooltip_text = "%s shift: %s\n%s\nClick to change: Opening, Closing or Double." % [Data.SHIFTS[who.shift]["name"], Shifts.hours_text(who), Data.SHIFTS[who.shift]["desc"]]
	var tr = Crew.by_id(who.trainer_id) if who.trainer_id > 0 else null
	train_button.self_modulate = UiKit.MINT if tr != null else UiKit.FAINT
	train_button.tooltip_text = ("Training with %s (day %d of up to %d). They learn twice as fast working side by side. Click to change." % [tr.person_name, who.training_days + 1, Data.TRAIN_DAYS]) \
		if tr != null else "Pair %s with someone better to train them: they learn twice as fast working side by side." % who.person_name
	var tk := str(who.traits) + str(who.manager) + str(who.warnings) + str(who.sick_days) + str(who.trainer_id)
	if tk != _traits_key:
		_traits_key = tk
		UiKit.fill_traits(traits_box, who.traits)
		if who.manager:
			traits_box.add_child(UiKit.tag_chip("Manager", "star", UiKit.GOLD, "Keeps an eye on phones and breaks up arguments. +$%d a shift." % Data.MANAGER_WAGE))
		if who.warnings > 0:
			traits_box.add_child(UiKit.tag_chip("%d warning%s" % [who.warnings, "" if who.warnings == 1 else "s"], "alert", UiKit.CHERRY, "Caught on the phone too often, or didn't show up for a shift."))
		if who.sick_days > 0:
			traits_box.add_child(UiKit.tag_chip("Sick", "sick", UiKit.SKY, "Has a cold. They'll call in sick tomorrow morning; working sick spreads it."))
		var tr2 = Crew.by_id(who.trainer_id) if who.trainer_id > 0 else null
		if tr2 != null:
			traits_box.add_child(UiKit.tag_chip("Training", "school", UiKit.MINT, "Training with %s." % tr2.person_name))
	manager_button.set_pressed_no_signal(who.manager)
	manager_button.self_modulate = UiKit.GOLD if who.manager else UiKit.FAINT
	manager_button.tooltip_text = ("%s is a manager. Click to make them regular staff again." % who.person_name) if who.manager else \
		"Make %s a manager (+$%d a shift). Managers still do their jobs, tell people off for being on their phones and break up arguments." % [who.person_name, Data.MANAGER_WAGE]
	mood_icon.texture = UiKit.icon(Crew.MOOD_ICONS.get(who.mood, "mood_okay"))
	mood_icon.self_modulate = Crew.MOOD_COLORS.get(who.mood, UiKit.MUTED)
	mood_icon.tooltip_text = "Mood: %s" % Crew.MOOD_NAMES.get(who.mood, "Okay")
	stress_bar.value = who.stress
	stress_bar.theme_type_variation = &"WarnBar" if who.stress >= Data.STRESS_FED_UP else &"SkillBar"
	stress_bar.tooltip_text = "Stress %d%%. Rushes, rivals, being tired and bad moments raise it; breaks (on a sofa is best), friends nearby and a quiet moment bring it down.\nOver %d%%: mistakes. End two days in a row over %d%% and they quit.%s" % [
		int(who.stress), int(Data.STRESS_MISTAKES), int(Data.STRESS_BURNOUT), "\n[b]Burning out![/b]" if who.burnout_warned else ""]
	var rel := Crew.summary(who)
	relations.visible = rel != ""
	relations.text = rel
	cook_bar.value = who.cooking
	cook_value.text = str(who.cooking)
	serve_bar.value = who.service
	serve_value.text = str(who.service)
	cook_bar.tooltip_text = "Cooking %d of 10: cooks faster and better food.\n%d%% of the way to the next level." % [who.cooking, int(100.0 * who.xp["cooking"] / Data.xp_needed(who.cooking))]
	serve_bar.tooltip_text = "Service %d of 10: walks and serves faster.\n%d%% of the way to the next level." % [who.service, int(100.0 * who.xp["service"] / Data.xp_needed(who.service))]
	energy_bar.value = who.energy
	energy_bar.theme_type_variation = &"WarnBar" if who.energy < Data.BREAK_AT else &"EnergyBar"
	energy_bar.tooltip_text = "Energy %d%%. Tired staff work slower. Below %d%% they take a break, faster on a sofa in the staff room." % [int(who.energy), int(Data.BREAK_AT)]
	status_label.text = status_text()
	var ic := ""
	if who.on_phone:
		ic = "phone"
	elif who.pause_left > 0.0:
		ic = "storm"
	elif who.on_break:
		ic = "energy"
	elif who.job != null:
		ic = UiKit.JOB_ICONS.get(who.job.type, "")
	status_icon.visible = ic != ""
	if ic != "":
		status_icon.texture = UiKit.icon(ic)
	for j in priority_buttons:
		var b: Button = priority_buttons[j]
		var p: int = who.priorities.get(j, 0)
		b.text = UiKit.priority_text(p)
		var col: Color = UiKit.PRIORITY_COLORS[p]
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color",
				"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(k, col)
		b.tooltip_text = "%s: %s\n%s\n\n1 = do this first, 4 = last, – = never.\nClick to change, right-click to go back." % [
			Data.JOB_NAMES[j], "never" if p == 0 else "priority %d" % p, Data.JOB_DESC[j]]
