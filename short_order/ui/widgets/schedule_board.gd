extends VBoxContainer
## Today's schedule at a glance: a row for each shift (day, mid, night,
## double and off) with who's on it, and underneath, how many of each role
## are on each shift. A shift with no cook or no server shows in red.

const SHIFTS := ["open", "mid", "close", "double", "off"]
const HEAD := {"open": "Day", "mid": "Mid", "close": "Night", "double": "Double", "off": "Off"}

var _key := ""
var rows := {}
var grid: GridContainer


func _init() -> void:
	add_theme_constant_override("separation", 6)


func refresh() -> void:
	var key := "%d|%d|" % [GameState.day, GameState.phase]
	for s in GameState.staff:
		key += "%d%s%s%s%s," % [s.id, UiKit.shift_key(s), s.role, s.shift_locked, s.at_work]
	key += str(GameState.hours)
	if key == _key:
		return
	_key = key
	for c in get_children():
		c.queue_free()
	var by_shift := {}
	for k in SHIFTS:
		by_shift[k] = []
	for s in GameState.staff:
		by_shift[UiKit.shift_key(s)].append(s)
	for k in SHIFTS:
		if by_shift[k].is_empty() and k in ["mid", "double", "off"]:
			continue
		add_child(_shift_row(k, by_shift[k]))
	# how many of each role on each shift
	var used_roles: Array = Data.ROLE_ORDER.filter(func(r): return GameState.staff.any(func(s): return s.role == r))
	if used_roles.is_empty():
		var l := UiKit.label("Hire some people and their shifts show up here.", 12, UiKit.MUTED, &"MutedLabel")
		add_child(l)
		return
	var cols: Array = ["open", "mid", "close"] if Shifts.two_shifts() else ["open"]
	grid = GridContainer.new()
	grid.columns = cols.size() + 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	grid.add_child(UiKit.label("On shift", 11, UiKit.MUTED, &"SmallLabel"))
	for c in cols:
		var h := UiKit.label(HEAD[c] if Shifts.two_shifts() else "All day", 11, UiKit.SHIFT_COLORS[c], &"SmallLabel")
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(h)
	for r in used_roles:
		var rl := HBoxContainer.new()
		rl.add_theme_constant_override("separation", 4)
		rl.add_child(UiKit.icon_rect(Data.ROLES[r]["icon"], 11, UiKit.ROLE_COLORS[r]))
		rl.add_child(UiKit.label(Data.ROLES[r]["plural"], 11, UiKit.INK, &"SmallLabel"))
		grid.add_child(rl)
		for c in cols:
			var n := 0
			for s in GameState.staff:
				if s.role == r and (UiKit.shift_key(s) == c or UiKit.shift_key(s) == "double"):
					n += 1
			var essential: bool = r in Shifts.ESSENTIAL
			var col: Color = UiKit.CHERRY if n == 0 and essential else (UiKit.MUTED if n == 0 else UiKit.INK)
			var cell := UiKit.label(str(n) if n > 0 else "–", 12, col, &"StatLabel")
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if n == 0 and essential:
				cell.tooltip_text = "No %s on this shift. Hire another, or set someone's shift by hand." % Data.ROLES[r]["name"].to_lower()
				cell.mouse_filter = Control.MOUSE_FILTER_PASS
			grid.add_child(cell)
	var well := PanelContainer.new()
	well.theme_type_variation = &"Well"
	well.add_child(grid)
	add_child(well)


func _shift_row(k: String, people: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.row_style(Color("2a221d"), UiKit.SHIFT_COLORS[k].darkened(0.45)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(UiKit.label(HEAD[k], 13, UiKit.SHIFT_COLORS[k].lightened(0.15), &"StatLabel"))
	var hours := ""
	if k == "off":
		hours = "not working today"
	elif not people.is_empty():
		hours = Shifts.hours_text(people[0])
	elif k == "open":
		hours = "in for prep"
	head.add_child(UiKit.label(hours, 11, UiKit.MUTED, &"SmallLabel"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UiKit.label(str(people.size()), 12, UiKit.MUTED, &"StatLabel"))
	col.add_child(head)
	if people.is_empty():
		col.add_child(UiKit.label("Nobody", 11, UiKit.CHERRY if k == "open" else UiKit.MUTED, &"SmallLabel"))
		return panel
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	col.add_child(flow)
	for s in people:
		var chip := VBoxContainer.new()
		chip.add_theme_constant_override("separation", 0)
		chip.custom_minimum_size = Vector2(46, 0)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.tooltip_text = "%s, %s%s" % [s.person_name, Data.ROLES[s.role]["name"].to_lower(), " (shift set by you)" if s.shift_locked else ""]
		var p := Portrait.new()
		p.custom_minimum_size = Vector2(26, 26)
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.ring = UiKit.ROLE_COLORS.get(s.role, UiKit.MUTED)
		p.show_person(s)
		chip.add_child(p)
		var n := UiKit.label(s.person_name.split(" ")[0], 10, UiKit.INK, &"SmallLabel")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.clip_text = true
		n.custom_minimum_size = Vector2(46, 0)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(n)
		flow.add_child(chip)
	return panel
