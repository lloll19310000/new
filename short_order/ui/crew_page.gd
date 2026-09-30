extends ScrollContainer
## The Crew page: a picture of who gets along (see RelationWeb), then the
## same in plain words (who's friends, where there's trouble and what to do
## about it, who's stressed), and the staff log underneath, newest first.
## Click a face to see only the log lines about that person.

const ICON_COLORS := {"heart": "#e27fa8", "storm": "#e75a4e", "alert": "#f2c14e", "phone": "#6aa6d9",
	"star": "#f2c14e", "fix": "#6cc3a0", "people": "#6cc3a0", "staff": "#6cc3a0", "walkout": "#e75a4e", "chat": "#6aa6d9", "clock": "#6aa6d9"}
const LEGEND := [["best", "Best friends"], ["friends", "Friends"], ["friendly", "Friendly"], ["tense", "Tense"], ["rivals", "Rivals"]]
const Art = preload("res://world/art.gd")

@onready var grid: RelationWeb = %Grid
@onready var glance: VBoxContainer = %Glance
@onready var empty_note: Label = %EmptyNote
@onready var log_title: Label = %LogTitle
@onready var show_all: Button = %ShowAll
@onready var log_text: RichTextLabel = %Log
@onready var legend: HFlowContainer = %Legend

var filter_id := -1
var _dirty := false
var _glance_key := ""


func _ready() -> void:
	for l in LEGEND:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var sw := ColorRect.new()
		sw.color = RelationWeb.STYLE[l[0]]["color"]
		sw.custom_minimum_size = Vector2(16, 4)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		row.add_child(UiKit.label(l[1], 11, UiKit.MUTED, &"SmallLabel"))
		legend.add_child(row)
	grid.person_clicked.connect(func(s):
		filter_id = -1 if filter_id == s.id else s.id
		refresh_log())
	show_all.pressed.connect(func():
		filter_id = -1
		grid.selected = -1
		grid.queue_redraw()
		refresh_log())
	Crew.log_added.connect(func(_e): _dirty = true)
	Crew.changed.connect(func(): _dirty = true)
	GameState.staff_changed.connect(refresh)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			refresh())
	refresh()


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		refresh_glance()
		refresh_log()


func refresh() -> void:
	var n := Crew.team().size()
	grid.visible = n >= 2
	legend.visible = n >= 2
	glance.visible = n >= 2
	empty_note.visible = n < 2
	grid.queue_redraw()
	if filter_id >= 0 and Crew.by_id(filter_id) == null:
		filter_id = -1
	refresh_glance()
	refresh_log()


## The picture in words: the closest pairs, the trouble, and who's stressed.
func refresh_glance() -> void:
	var t := Crew.team()
	var good: Array = []
	var bad: Array = []
	for i in t.size():
		for j in range(i + 1, t.size()):
			var l := Crew.label(t[i], t[j])
			var avg := (Crew.opinion(t[i], t[j]) + Crew.opinion(t[j], t[i])) / 2.0
			if l == "best" or l == "friends":
				good.append([avg, t[i], t[j], l])
			elif l == "rivals" or l == "tense":
				bad.append([avg, t[i], t[j], l])
	good.sort_custom(func(a, b): return a[0] > b[0])
	bad.sort_custom(func(a, b): return a[0] < b[0])
	var stressed: Array = t.filter(func(s): return s.stress >= Data.STRESS_FED_UP or s.burnout_warned)
	stressed.sort_custom(func(a, b): return a.stress > b.stress)
	var key := ""
	for g in good.slice(0, 5) + bad.slice(0, 6):
		key += "%d-%d-%s," % [g[1].id, g[2].id, g[3]]
	for s in stressed:
		key += "s%d-%d," % [s.id, int(s.stress / 5)]
	if key == _glance_key:
		return
	_glance_key = key
	for c in glance.get_children():
		c.queue_free()
	var has_manager: bool = t.any(func(s): return s.manager)
	if not bad.is_empty():
		glance.add_child(_heading("Trouble", "storm", UiKit.CHERRY))
		for b in bad.slice(0, 6):
			var hint := "A manager on shift will sit them down." if has_manager else "Put them on different shifts, or hire a manager to settle it."
			glance.add_child(_pair_row(b[1], b[2], b[3], _top_reason(b[1], b[2], false), hint))
	if not good.is_empty():
		glance.add_child(_heading("Getting along", "heart", UiKit.MINT))
		for g in good.slice(0, 5):
			glance.add_child(_pair_row(g[1], g[2], g[3], _top_reason(g[1], g[2], true), "They work faster side by side."))
	if not stressed.is_empty():
		glance.add_child(_heading("Stressed", "alert", UiKit.GOLD))
		for s in stressed.slice(0, 5):
			var what := "burning out: a day off would help" if s.burnout_warned else "fed up: breaks, a sofa and friends nearby help"
			glance.add_child(_person_row(s, "%d%% stress, %s" % [int(s.stress), what]))
	if bad.is_empty() and good.is_empty() and stressed.is_empty():
		glance.add_child(UiKit.label("No close friends or rivals yet: they're still getting to know each other.", 12, UiKit.MUTED, &"SmallLabel"))


func _heading(text: String, icon_name: String, col: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.add_child(UiKit.icon_rect(icon_name, 13, col))
	h.add_child(UiKit.label(text, 13, col, &"StatLabel"))
	return h


func _top_reason(a, b, positive: bool) -> String:
	var all: Array = Crew.reasons(a, b) + Crew.reasons(b, a)
	all = all.filter(func(r): return (r[1] > 0.0) == positive)
	all.sort_custom(func(x, y): return absf(x[1]) > absf(y[1]))
	if all.is_empty():
		return ""
	var why: String = all[0][0]
	if why == "Chemistry":
		why = "They just clicked" if positive else "Their personalities clash"
	return why


func _face(s, px: float = 24.0) -> Portrait:
	var p := Portrait.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.ring = Crew.MOOD_COLORS.get(s.mood, UiKit.MUTED) if s.mood != "okay" else Color(0, 0, 0, 0)
	p.show_person(s)
	return p


func _pair_row(a, b, l: String, why: String, hint: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.row_style(Color("2a221d")))
	panel.tooltip_text = hint
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	panel.add_child(row)
	row.add_child(_face(a))
	row.add_child(_face(b))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var names := UiKit.label("%s & %s" % [a.person_name, b.person_name], 13, UiKit.INK, &"StatLabel")
	names.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(names)
	if why != "":
		col.add_child(UiKit.label(why, 11, UiKit.MUTED, &"SmallLabel"))
	var st: Dictionary = RelationWeb.STYLE[l]
	var chip := UiKit.tag_chip(Crew.LABEL_NAMES[l], "heart" if l in ["best", "friends"] else "storm", Color(st["color"], 1.0), hint)
	row.add_child(chip)
	return panel


func _person_row(s, text: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.row_style(Color("2a221d")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	row.add_child(_face(s))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiKit.label(s.person_name, 13, UiKit.INK, &"StatLabel"))
	var l := UiKit.label(text, 11, UiKit.MUTED, &"SmallLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(80, 0)
	col.add_child(l)
	return panel


func refresh_log() -> void:
	var who = Crew.by_id(filter_id) if filter_id >= 0 else null
	log_title.text = "Staff log" if who == null else "Staff log: %s" % who.person_name
	show_all.visible = who != null
	var lines: Array = []
	for i in range(Crew.entries.size() - 1, -1, -1):
		var e: Dictionary = Crew.entries[i]
		if who != null and not e["who"].has(filter_id):
			continue
		var m := int(e["min"])
		var col: String = ICON_COLORS.get(e["icon"], "#b9a797")
		lines.append("[color=#7d6d61]Day %d, %02d:%02d[/color]  [img width=13 height=13 color=%s]res://ui/icons/%s.svg[/img] %s" % [
			e["day"], (m / 60) % 24, m % 60, col, e["icon"], e["text"]])
		if lines.size() >= 60:
			break
	if lines.is_empty():
		log_text.text = "[color=#b9a797]Nothing yet. Open the diner and see what happens.[/color]"
	else:
		log_text.text = "\n".join(lines)
