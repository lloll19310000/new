extends VBoxContainer
## The Staff page, in three tabs:
##   Crew      everyone, grouped by role, as compact rows (click one for more)
##   Hire      people looking for work today, by role, and job ads
##   Schedule  who works the day, mid and night shifts and who's off, and
##             whether the schedule writes itself
## A line on top sums it up: how many, today's pay, and who's on.

signal hire_requested(index: int)
signal fire_requested(who)

const StaffRow = preload("res://ui/staff_row.gd")
const CandidateRow = preload("res://ui/candidate_row.gd")
const ScheduleBoard = preload("res://ui/widgets/schedule_board.gd")
const TABS := ["crew", "hire", "schedule"]
const TAB_NAMES := {"crew": "Crew", "hire": "Hire", "schedule": "Schedule"}

var tab := "crew"
var tab_buttons := {}
var bodies := {}
var summary: Label
var crew_box: VBoxContainer
var candidates_box: VBoxContainer
var cards := {}                 # staff node -> row
var role_filter := ""
var filter_buttons := {}
var ad_role: OptionButton
var ad_button: Button
var board
var auto_switch: CheckButton
var auto_note: Label
var redo_button: Button
var jobs_row: HBoxContainer
var empty_note: Label
var crew_count: Label
var _job_labels := {}
var _cand_key := ""
var _group_key := ""
var _t := 0.0


func _ready() -> void:
	# a line that sums it all up
	summary = UiKit.label("", 12, UiKit.MUTED, &"SmallLabel")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(100, 0)
	add_child(summary)
	crew_count = summary
	# the tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	var group := ButtonGroup.new()
	for k in TABS:
		var b := Button.new()
		b.text = TAB_NAMES[k]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = &"CategoryButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_tab.bind(k))
		tabs.add_child(b)
		tab_buttons[k] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	bodies["crew"] = _crew_tab()
	bodies["hire"] = _hire_tab()
	bodies["schedule"] = _schedule_tab()
	for k in TABS:
		stack.add_child(bodies[k])
	GameState.staff_changed.connect(refresh)
	GameState.phase_changed.connect(func(_p): refresh())
	show_tab("crew")
	refresh()


func show_tab(k: String) -> void:
	tab = k
	for key in TABS:
		bodies[key].visible = key == k
		tab_buttons[key].set_pressed_no_signal(key == k)
	refresh()


# ------------------------------------------------------------------ crew

func _crew_tab() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	empty_note = UiKit.label("Nobody works here yet. Open the Hire tab: you need at least a cook and a server.", 13, UiKit.INK)
	empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_note.custom_minimum_size = Vector2(100, 0)
	box.add_child(empty_note)
	crew_box = VBoxContainer.new()
	crew_box.add_theme_constant_override("separation", 3)
	box.add_child(crew_box)
	# how many jobs of each kind are waiting (handy for seeing why the floors are dirty)
	var well := PanelContainer.new()
	well.theme_type_variation = &"Well"
	var jb := HBoxContainer.new()
	jb.add_theme_constant_override("separation", 10)
	well.add_child(jb)
	jb.add_child(UiKit.label("Jobs waiting", 12, UiKit.MUTED, &"MutedLabel"))
	jobs_row = HBoxContainer.new()
	jobs_row.add_theme_constant_override("separation", 9)
	jb.add_child(jobs_row)
	for j in Data.JOBS:
		var b := HBoxContainer.new()
		b.add_theme_constant_override("separation", 2)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.tooltip_text = "%s jobs waiting: %s" % [Data.JOB_NAMES[j], Data.JOB_DESC[j]]
		b.add_child(UiKit.icon_rect(UiKit.JOB_ICONS[j], 13, UiKit.MUTED))
		var l := UiKit.label("0", 12, UiKit.INK, &"SmallLabel")
		b.add_child(l)
		jobs_row.add_child(b)
		_job_labels[j] = l
	box.add_child(well)
	return box


func _rebuild_crew() -> void:
	# rows are kept (so an open one stays open); the role headings are rebuilt when the mix changes
	for s in cards.keys():
		if not GameState.staff.has(s):
			cards[s].queue_free()
			cards.erase(s)
	var key := ""
	for s in GameState.staff:
		key += "%d:%s," % [s.id, s.role]
	if key == _group_key:
		return
	_group_key = key
	for c in crew_box.get_children():
		if not c.has_method("set_open"):
			c.queue_free()
		else:
			crew_box.remove_child(c)
	for r in Data.ROLE_ORDER:
		var people: Array = GameState.staff.filter(func(s): return s.role == r)
		if people.is_empty():
			continue
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 5)
		head.add_child(UiKit.icon_rect(Data.ROLES[r]["icon"], 12, UiKit.ROLE_COLORS[r]))
		head.add_child(UiKit.label("%s  ·  %d" % [Data.ROLES[r]["plural"], people.size()], 12, UiKit.ROLE_COLORS[r], &"StatLabel"))
		head.tooltip_text = Data.ROLES[r]["desc"]
		head.mouse_filter = Control.MOUSE_FILTER_PASS
		crew_box.add_child(head)
		for s in people:
			if not cards.has(s):
				var row = StaffRow.new()
				row.setup(s)
				row.fire_requested.connect(func(who): fire_requested.emit(who))
				row.opened.connect(_on_row_opened)
				cards[s] = row
			crew_box.add_child(cards[s])


## Only one row open at a time.
func _on_row_opened(row) -> void:
	for s in cards:
		if cards[s] != row and cards[s].is_open:
			cards[s].set_open(false)


# ------------------------------------------------------------------ hiring

func _hire_tab() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	box.add_child(flow)
	var fgroup := ButtonGroup.new()
	for r in [""] + Data.ROLE_ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = fgroup
		b.theme_type_variation = &"SmallButton"
		b.add_theme_font_size_override("font_size", 11)
		b.text = "All" if r == "" else Data.ROLES[r]["plural"]
		if r != "":
			b.add_theme_color_override("font_color", UiKit.ROLE_COLORS[r])
		b.pressed.connect(func():
			role_filter = r
			_cand_key = ""
			refresh())
		flow.add_child(b)
		filter_buttons[r] = b
	filter_buttons[""].set_pressed_no_signal(true)
	candidates_box = VBoxContainer.new()
	candidates_box.add_theme_constant_override("separation", 3)
	box.add_child(candidates_box)
	# a job ad: more people for one role
	var ad := PanelContainer.new()
	ad.theme_type_variation = &"Well"
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	ad.add_child(arow)
	var need := UiKit.label("Need more?", 12, UiKit.MUTED, &"SmallLabel")
	need.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	need.custom_minimum_size = Vector2(24, 0)
	arow.add_child(need)
	ad_role = OptionButton.new()
	ad_role.add_theme_font_size_override("font_size", 12)
	ad_role.fit_to_longest_item = false      # so the row fits the panel
	ad_role.clip_text = true
	ad_role.custom_minimum_size = Vector2(80, 0)
	ad_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in Data.ROLE_ORDER:
		ad_role.add_item(Data.ROLES[r]["name"])
	ad_role.select(1)
	arow.add_child(ad_role)
	ad_button = Button.new()
	ad_button.theme_type_variation = &"SmallButton"
	ad_button.text = "Post ad ($%d)" % Data.JOB_AD_COST
	ad_button.add_theme_font_size_override("font_size", 12)
	ad_button.tooltip_text = "A job ad brings %d more people for that role today. Everyone here goes when the day ends; new people come every morning." % Data.JOB_AD_PEOPLE
	ad_button.pressed.connect(func():
		if GameState.post_job_ad(Data.ROLE_ORDER[ad_role.selected]):
			Sfx.play("cash", -8.0)
			role_filter = ""
			filter_buttons[""].set_pressed_no_signal(true)
			_cand_key = ""
			refresh())
	arow.add_child(ad_button)
	box.add_child(ad)
	var note := UiKit.label("Hire as many as you like, up to %d staff. Pay is by the hour (California: at least $%.2f)." % [Data.MAX_STAFF, Data.MIN_WAGE], 11, UiKit.MUTED, &"SmallLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(100, 0)
	box.add_child(note)
	return box


func _rebuild_candidates() -> void:
	var key := "%d|%s|" % [GameState.day, role_filter]
	for c in GameState.candidates:
		key += c["name"] + ","
	if key == _cand_key:
		return
	_cand_key = key
	for c in candidates_box.get_children():
		c.queue_free()
	var shown := 0
	for i in GameState.candidates.size():
		var c: Dictionary = GameState.candidates[i]
		if role_filter != "" and c["role"] != role_filter:
			continue
		var row = CandidateRow.new()
		row.setup(c, i)
		row.hire_requested.connect(func(idx: int): hire_requested.emit(idx))
		candidates_box.add_child(row)
		shown += 1
	if shown == 0:
		var l := UiKit.label("Nobody %s today. Post an ad below, or new people come by tomorrow morning." % ("else" if role_filter == "" else "for that job"), 12, UiKit.MUTED, &"MutedLabel")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(100, 0)
		candidates_box.add_child(l)


# ------------------------------------------------------------------ the schedule

func _schedule_tab() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	auto_switch = CheckButton.new()
	auto_switch.text = "Write the schedule automatically"
	auto_switch.button_pressed = Shifts.auto
	auto_switch.toggled.connect(func(on: bool):
		Shifts.auto = on
		if on:
			Shifts.replan()
		refresh())
	box.add_child(auto_switch)
	auto_note = UiKit.label("", 12, UiKit.MUTED, &"SmallLabel")
	auto_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auto_note.custom_minimum_size = Vector2(100, 0)
	box.add_child(auto_note)
	board = ScheduleBoard.new()
	box.add_child(board)
	redo_button = Button.new()
	redo_button.theme_type_variation = &"SmallButton"
	redo_button.icon = UiKit.icon("calendar")
	redo_button.text = "Redo today's schedule"
	redo_button.tooltip_text = "Work out today's shifts and days off again, from scratch. Shifts you've set by hand (the lock) stay."
	redo_button.pressed.connect(func():
		Shifts.plan_schedule(GameState.day)
		refresh())
	box.add_child(redo_button)
	return box


# ------------------------------------------------------------------ refresh

func refresh() -> void:
	if not is_node_ready():
		return
	var n := GameState.staff.size()
	var pay := 0.0
	for s in GameState.staff:
		var h: float = Shifts.hours_today(s) if GameState.is_active() or GameState.phase == GameState.Phase.REPORT else (0.0 if Shifts.works_off(s, GameState.day) else _planned_hours(s))
		if h > 0.0:
			pay += Shifts.pay_for_hours(s.wage, h)
	summary.text = "%d of %d staff  ·  %s pay about $%s  ·  %d looking for work" % [n, Data.MAX_STAFF,
		"today's" if GameState.phase != GameState.Phase.PLANNING else "today's planned", UiKit.thousands(int(pay)), GameState.candidates.size()]
	empty_note.visible = n == 0
	tab_buttons["hire"].text = "Hire (%d)" % GameState.candidates.size()
	match tab:
		"crew":
			_rebuild_crew()
			for s in cards:
				if is_instance_valid(s):
					cards[s].refresh()
		"hire":
			_rebuild_candidates()
		"schedule":
			auto_switch.set_pressed_no_signal(Shifts.auto)
			var boss = Shifts.scheduler()
			if not Shifts.auto:
				auto_note.text = "You set everyone's shift by hand on their row in the Crew tab. Days off are up to you too (a day off request event, or let the schedule do it)."
			elif boss != null:
				auto_note.text = "%s, your manager, writes it every night: day, mid and night shifts, two days off a week each, rest for anyone stressed or burning out, rivals on different shifts and trainees with their trainers." % boss.person_name
			else:
				auto_note.text = "It writes itself every night: day, mid and night shifts, and a day off after five or six in a row. A manager does it better: they also rest the stressed, keep rivals apart and pair trainees with trainers."
			redo_button.visible = Shifts.auto and GameState.phase == GameState.Phase.PLANNING and n > 0
			board.refresh()


## How long someone's shift runs today, in hours (for the planned pay).
func _planned_hours(s) -> float:
	var a: float = Shifts.shift_start(s)
	var e: float = Shifts.shift_end(s)
	if e < 0.0:
		e = GameState.close_min() + Data.CLOSE_EXTRA
	return maxf(0.0, (e - a) / 60.0)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not is_visible_in_tree():
		return
	_t = 0.3
	if tab == "crew":
		for s in cards:
			if is_instance_valid(s) and cards[s].is_node_ready():
				cards[s].refresh()
		var counts: Dictionary = JobBoard.count_by_type()
		for j in _job_labels:
			_job_labels[j].text = str(counts.get(j, 0))
			_job_labels[j].add_theme_color_override("font_color", UiKit.GOLD if counts.get(j, 0) > 4 else UiKit.INK)
	elif tab == "schedule":
		board.refresh()
