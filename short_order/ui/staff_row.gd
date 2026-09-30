extends PanelContainer
## One member of staff on the Staff page, as a compact row: face (ringed in
## their mood's colour), name, role, what they're doing, their shift and pay.
## Click it to open the details: hometown and life story, traits, skills,
## energy and stress, friends and rivals, their role, job priorities,
## training, and letting them go.

signal fire_requested(who)
signal opened(row)

const NORMAL := Color("2a221d")

var stress_why: Label
var who = null
var is_open := false
var _hover := false
var _fire_armed := 0.0
var _traits_key := ""

var portrait: Portrait
var name_label: Label
var status_label: Label
var status_icon: TextureRect
var shift_button: Button
var wage_label: Label
var details: VBoxContainer
var origin_label: Label
var info_box: Control
var traits_box: HFlowContainer
var bars := {}
var relations: Label
var role_button: OptionButton
var priority_buttons := {}
var train_button: Button
var train_menu: PopupMenu
var _train_ids: Array = []
var fire_button: Button
var manager_button: Button     # promotes to manager (or back); kept for the tests and old habits


func setup(s) -> void:
	who = s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	add_theme_stylebox_override("panel", UiKit.row_style(NORMAL))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# ---- the row
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(32, 32)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", -2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid)
	info_box = mid
	name_label = UiKit.label("", 14, UiKit.INK, &"StatLabel")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(name_label)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 3)
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(srow)
	status_icon = UiKit.icon_rect("cook", 11, UiKit.MUTED)
	srow.add_child(status_icon)
	status_label = UiKit.label("", 11, UiKit.MUTED, &"SmallLabel")
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	srow.add_child(status_label)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 1)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	shift_button = Button.new()
	shift_button.theme_type_variation = &"SmallButton"
	shift_button.custom_minimum_size = Vector2(72, 22)
	shift_button.add_theme_font_size_override("font_size", 11)
	shift_button.icon = UiKit.icon("clock")
	shift_button.add_theme_constant_override("icon_max_width", 11)
	shift_button.pressed.connect(_cycle_shift)
	right.add_child(shift_button)
	wage_label = UiKit.label("", 11, UiKit.MUTED, &"SmallLabel")
	wage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(wage_label)
	# ---- the details, shown when the row is open
	details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 6)
	details.visible = false
	col.add_child(details)
	origin_label = UiKit.label("", 12, UiKit.MUTED, &"SmallLabel")
	origin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	origin_label.custom_minimum_size = Vector2(120, 0)
	details.add_child(origin_label)
	traits_box = HFlowContainer.new()
	traits_box.add_theme_constant_override("h_separation", 4)
	traits_box.add_theme_constant_override("v_separation", 4)
	details.add_child(traits_box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	details.add_child(grid)
	for k in [["cooking", "cook", "Cooking"], ["service", "serve", "Service"], ["energy", "energy", "Energy"], ["stress", "storm", "Stress"]]:
		var b := HBoxContainer.new()
		b.add_theme_constant_override("separation", 4)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_child(UiKit.icon_rect(k[1], 12, UiKit.MUTED))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 10.0 if k[0] in ["cooking", "service"] else 100.0
		bar.theme_type_variation = &"SkillBar"
		b.add_child(bar)
		var v := UiKit.label("", 11, UiKit.INK, &"SmallLabel")
		v.custom_minimum_size = Vector2(26, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(v)
		b.tooltip_text = k[2]
		grid.add_child(b)
		bars[k[0]] = [bar, v, b]
	relations = UiKit.label("", 12, UiKit.MUTED, &"SmallLabel")
	relations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relations.custom_minimum_size = Vector2(120, 0)
	details.add_child(relations)
	# role
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 6)
	rrow.add_child(UiKit.label("Role", 12, UiKit.MUTED, &"SmallLabel"))
	role_button = OptionButton.new()
	role_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_button.add_theme_font_size_override("font_size", 12)
	role_button.item_selected.connect(func(i: int): Crew.set_role(who, Data.ROLE_ORDER[i]))
	rrow.add_child(role_button)
	details.add_child(rrow)
	# job priorities
	var jl := UiKit.label("Jobs, in order (1 first, – never). The role sets these; click to change, right-click to go back.", 11, UiKit.MUTED, &"SmallLabel")
	jl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jl.custom_minimum_size = Vector2(120, 0)
	details.add_child(jl)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 3)
	details.add_child(prow)
	for j in Data.JOBS:
		var pb := Button.new()
		pb.theme_type_variation = &"PriorityButton"
		pb.custom_minimum_size = Vector2(38, 26)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.icon = UiKit.icon(UiKit.JOB_ICONS[j])
		pb.add_theme_constant_override("icon_max_width", 13)
		pb.add_theme_font_size_override("font_size", 12)
		pb.pressed.connect(_step_priority.bind(j, 1))
		pb.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
				_step_priority(j, -1)
				pb.accept_event())
		prow.add_child(pb)
		priority_buttons[j] = pb
	# training, manager, let go
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	details.add_child(arow)
	train_button = Button.new()
	train_button.theme_type_variation = &"SmallButton"
	train_button.icon = UiKit.icon("school")
	train_button.text = "Training"
	train_button.add_theme_font_size_override("font_size", 12)
	arow.add_child(train_button)
	train_menu = PopupMenu.new()
	add_child(train_menu)
	train_menu.id_pressed.connect(_on_train_pick)
	train_button.pressed.connect(_open_train_menu)
	manager_button = Button.new()
	manager_button.theme_type_variation = &"SmallButton"
	manager_button.toggle_mode = true
	manager_button.icon = UiKit.icon("star")
	manager_button.add_theme_font_size_override("font_size", 12)
	manager_button.toggled.connect(func(on: bool): Crew.set_manager(who, on))
	arow.add_child(manager_button)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(sp)
	fire_button = Button.new()
	fire_button.theme_type_variation = &"DangerButton"
	fire_button.icon = UiKit.icon("close")
	fire_button.text = "Let go"
	fire_button.pressed.connect(_on_fire)
	arow.add_child(fire_button)
	portrait.show_person(who)
	name_label.text = who.person_name
	for r in Data.ROLE_ORDER:
		role_button.add_item("%s  ($%.2f/hr)" % [Data.ROLES[r]["name"], Data.role_pay(r, who.cooking, who.service, who.traits) + who.raises])
	refresh()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_open(not is_open)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hover = what == NOTIFICATION_MOUSE_ENTER
		add_theme_stylebox_override("panel", UiKit.row_style(Color("342a24") if _hover or is_open else NORMAL,
			UiKit.ROLE_COLORS.get(who.role, UiKit.MUTED).darkened(0.3) if is_open else Color(0, 0, 0, 0)))


func set_open(on: bool) -> void:
	is_open = on
	details.visible = on
	add_theme_stylebox_override("panel", UiKit.row_style(Color("342a24") if on or _hover else NORMAL,
		UiKit.ROLE_COLORS.get(who.role, UiKit.MUTED).darkened(0.3) if on else Color(0, 0, 0, 0)))
	if on:
		opened.emit(self)
		refresh()


## Day -> Mid -> Night -> Double -> back to the schedule's choice. Setting it
## by hand pins it (the lock), so the schedule leaves it alone.
func _cycle_shift() -> void:
	if who.shift_locked and who.shift == "double":
		who.shift_locked = false
		Shifts.replan()
	else:
		var i: int = Data.SHIFT_ORDER.find(who.shift)
		who.shift = Data.SHIFT_ORDER[(i + 1) % Data.SHIFT_ORDER.size()]
		who.shift_locked = true
	GameState.staff_changed.emit()


func _open_train_menu() -> void:
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
	train_menu.popup()


func _on_train_pick(id: int) -> void:
	if id == 999:
		Shifts.set_trainer(who, null)
	elif id >= 0 and id < _train_ids.size():
		Shifts.set_trainer(who, Crew.by_id(_train_ids[id]))


func _step_priority(job: String, step: int) -> void:
	var v: int = who.priorities[job]
	v = (v + step + 5) % 5
	who.priorities[job] = v
	GameState.staff_changed.emit()


func _on_fire() -> void:
	if _fire_armed > 0.0:
		fire_requested.emit(who)
		return
	_fire_armed = 3.0
	fire_button.text = "Sure?"


func _process(delta: float) -> void:
	if _fire_armed > 0.0:
		_fire_armed -= delta
		if _fire_armed <= 0.0:
			fire_button.text = "Let go"


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
	if GameState.phase == GameState.Phase.PLANNING:
		if Shifts.works_off(who, GameState.day):
			return "Day off today"
		return "In at %s" % DayTimeline.clock(Shifts.shift_start(who))
	return who.status + (" (sick)" if who.sick_at_work else "")


func refresh() -> void:
	if who == null or not is_instance_valid(who):
		return
	var rc: Color = UiKit.ROLE_COLORS.get(who.role, UiKit.MUTED)
	portrait.ring = Crew.MOOD_COLORS.get(who.mood, UiKit.MUTED) if who.mood != "okay" else Color(0, 0, 0, 0)
	portrait.queue_redraw()
	name_label.text = who.person_name + ("  ★" if who.manager else "")
	status_label.text = "%s · %s" % [Career.title(who), status_text()]
	status_label.add_theme_color_override("font_color", rc.lerp(UiKit.MUTED, 0.35))
	var ic: String = Data.ROLES[who.role]["icon"]
	if who.on_phone:
		ic = "phone"
	elif who.pause_left > 0.0:
		ic = "storm"
	elif who.on_break:
		ic = "energy"
	status_icon.texture = UiKit.icon(ic)
	status_icon.self_modulate = rc
	var sk := UiKit.shift_key(who)
	shift_button.text = UiKit.shift_name(who)
	shift_button.icon = UiKit.icon("lock" if who.shift_locked else "clock")
	shift_button.add_theme_color_override("font_color", UiKit.SHIFT_COLORS.get(sk, UiKit.MUTED).lightened(0.2))
	var hours: String = Shifts.hours_text(who) if sk != "off" else "not working"
	shift_button.tooltip_text = "%s shift: %s.%s\nClick to set it yourself (Day, Mid, Night, Double); click past Double to let the schedule choose again." % [
		UiKit.shift_name(who), hours, "\nSet by you: the schedule leaves it alone." if who.shift_locked else "\nChosen by the schedule."]
	wage_label.text = Data.hourly(who.wage) + (" +$%d" % int(who.tips_today) if who.tips_today >= 1.0 else "")
	wage_label.tooltip_text = "Paid $%.2f an hour: time and a half past 8 hours in a day, double time past 12.%s" % [who.wage,
		(" Tips today: $%d." % int(who.tips_today)) if who.tips_today >= 1.0 else ""]
	if not details.visible:
		return
	origin_label.text = "%s. %s Signature dish: %s." % [Data.hometown(who.origin), who.bio, who.origin.get("dish", "?")]
	info_box.tooltip_text = origin_label.text
	var tk: String = str(who.traits) + str(who.role) + str(who.warnings) + str(who.sick_days) + str(who.trainer_id) + str(who.burnout_warned) + str(who.perks) + who.avail + str(who.rank)
	if tk != _traits_key:
		_traits_key = tk
		UiKit.fill_traits(traits_box, who.traits)
		traits_box.add_child(UiKit.role_chip(who.role))
		if who.warnings > 0:
			traits_box.add_child(UiKit.tag_chip("%d warning%s" % [who.warnings, "" if who.warnings == 1 else "s"], "alert", UiKit.CHERRY, "Caught on the phone too often, or didn't show up for a shift."))
		if who.sick_days > 0:
			traits_box.add_child(UiKit.tag_chip("Sick", "sick", UiKit.SKY, "Has a cold. They'll call in sick tomorrow morning; working sick spreads it."))
		if who.burnout_warned:
			traits_box.add_child(UiKit.tag_chip("Burning out", "alert", UiKit.CHERRY, "Very stressed for %d night%s in a row; at %d they quit. A day off helps." % [who.burnout_nights, "" if who.burnout_nights == 1 else "s", Data.BURNOUT_QUIT_NIGHTS]))
		var tr = Crew.by_id(who.trainer_id) if who.trainer_id > 0 else null
		if tr != null:
			traits_box.add_child(UiKit.tag_chip("Training with %s" % tr.person_name, "school", UiKit.MINT, "They learn twice as fast working beside %s." % tr.person_name))
		for p in who.perks:
			traits_box.add_child(UiKit.tag_chip(Data.PERKS[p]["name"], "star", UiKit.GOLD, Data.PERKS[p]["desc"]))
		if who.avail != "":
			traits_box.add_child(UiKit.tag_chip("No mornings" if who.avail == "no_mornings" else "No nights", "calendar", UiKit.SKY,
				"They can't work %s (school, kids or a second job): the schedule works around it." % ("mornings" if who.avail == "no_mornings" else "nights")))
		var nxt: int = who.rank + 1
		var titles: Array = Data.CAREER_TITLES.get(who.role, [])
		if nxt < titles.size() and nxt < Data.CAREER_STEPS.size():
			var st: Array = Data.CAREER_STEPS[nxt]
			traits_box.add_child(UiKit.tag_chip(Career.title(who), "school", UiKit.MUTED, "Next: %s at skill %d and %d shifts (now %d and %d)." % [titles[nxt].to_lower(), st[0], st[1], Career.role_skill(who), who.shifts_worked]))
	_bar("cooking", who.cooking, str(who.cooking), "Cooking %d of 10: cooks faster and better food. %d%% of the way to the next level." % [who.cooking, int(100.0 * who.xp["cooking"] / Data.xp_needed(who.cooking))])
	_bar("service", who.service, str(who.service), "Service %d of 10: walks and serves faster. %d%% of the way to the next level." % [who.service, int(100.0 * who.xp["service"] / Data.xp_needed(who.service))])
	_bar("energy", who.energy, "%d%%" % int(who.energy), "Energy. Tired staff work slower; below %d%% they take a break (faster on a sofa)." % int(Data.BREAK_AT))
	_bar("stress", who.stress, "%d%%" % int(who.stress), "Stress. Rushes, rivals and long days raise it; breaks, friends, days off and a manager bring it down. Over %d%% for %d nights and they quit." % [int(Data.STRESS_BURNOUT), Data.BURNOUT_QUIT_NIGHTS])
	bars["energy"][0].theme_type_variation = &"WarnBar" if who.energy < Data.BREAK_AT else &"EnergyBar"
	bars["stress"][0].theme_type_variation = &"WarnBar" if who.stress >= Data.STRESS_FED_UP else &"SkillBar"
	var rel := Crew.summary(who)
	relations.text = rel if rel != "" else "Gets on fine with everyone."
	# why their stress moved today, biggest first
	if stress_why == null:
		stress_why = Label.new()
		stress_why.theme_type_variation = &"SmallLabel"
		stress_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stress_why.custom_minimum_size = Vector2(100, 0)
		relations.get_parent().add_child(stress_why)
		relations.get_parent().move_child(stress_why, relations.get_index() + 1)
	var why: String = who.stress_reasons_text(4)
	stress_why.visible = why != ""
	stress_why.text = "Stress today: " + why
	stress_why.add_theme_color_override("font_color", UiKit.CHERRY.lightened(0.2) if who.stress >= Data.STRESS_FED_UP else UiKit.MUTED)
	bars["stress"][2].tooltip_text += ("\nToday: " + why) if why != "" else ""
	role_button.select(Data.ROLE_ORDER.find(who.role))
	manager_button.set_pressed_no_signal(who.manager)
	manager_button.text = "Manager" if who.manager else "Make manager"
	manager_button.tooltip_text = Data.ROLES["manager"]["desc"]
	var tr2 = Crew.by_id(who.trainer_id) if who.trainer_id > 0 else null
	train_button.text = ("Training: %s" % tr2.person_name) if tr2 != null else "Train"
	train_button.tooltip_text = "Pair %s with someone at least 2 points better: working side by side, they learn twice as fast." % who.person_name
	for j in priority_buttons:
		var b: Button = priority_buttons[j]
		var p: int = who.priorities.get(j, 0)
		b.text = UiKit.priority_text(p)
		var c: Color = UiKit.PRIORITY_COLORS[p]
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color",
				"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(k, c)
		b.tooltip_text = "%s: %s\n%s\n\n1 = do this first, 4 = last, – = never.\nClick to change, right-click to go back." % [
			Data.JOB_NAMES[j], "never" if p == 0 else "priority %d" % p, Data.JOB_DESC[j]]


func _bar(key: String, v: float, text: String, tip: String) -> void:
	bars[key][0].value = v
	bars[key][1].text = text
	bars[key][2].tooltip_text = tip
