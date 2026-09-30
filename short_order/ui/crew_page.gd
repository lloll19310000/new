extends ScrollContainer
## The Crew page (under Staff): not a picture of every pair, which stops
## meaning anything past a dozen people, but the handful of things that need
## you, worst first, each with a button that deals with it. Who someone
## likes and can't stand is on their own card (click them).

const ICON_COLORS := {"heart": "#e27fa8", "storm": "#e75a4e", "alert": "#f2c14e", "phone": "#6aa6d9",
	"star": "#f2c14e", "fix": "#6cc3a0", "people": "#6cc3a0", "staff": "#6cc3a0", "walkout": "#e75a4e", "chat": "#6aa6d9", "clock": "#6aa6d9"}
## Log lines worth seeing when there are dozens of people: the rest is under "Everything".
const IMPORTANT := ["storm", "walkout", "alert", "star", "staff"]
const MAX_ISSUES := 5
const LOG_LINES := 25

@onready var summary: Label = %Summary
@onready var attention: VBoxContainer = %Attention
@onready var empty_note: Label = %EmptyNote
@onready var log_title: Label = %LogTitle
@onready var show_all: Button = %ShowAll
@onready var log_text: RichTextLabel = %Log

var _dirty := false
var _key := ""


func _ready() -> void:
	show_all.toggled.connect(func(_on): refresh_log())
	Crew.log_added.connect(func(_e): _dirty = true)
	Crew.changed.connect(func(): _dirty = true)
	GameState.staff_changed.connect(func(): _dirty = true)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			refresh())
	refresh()


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		refresh()


func refresh() -> void:
	var t := Crew.team()
	empty_note.visible = t.size() < 2
	summary.text = summary_text(t)
	refresh_issues(t)
	refresh_log()


## "12 cheerful, 20 okay, 3 fed up · 4 pairs of friends, 1 pair of rivals"
static func summary_text(t: Array) -> String:
	if t.is_empty():
		return ""
	var moods := {"cheerful": 0, "okay": 0, "fed_up": 0}
	for s in t:
		moods[s.mood] = moods.get(s.mood, 0) + 1
	var friends := 0
	var rivals := 0
	for k in Crew.labels:
		match Crew.labels[k]:
			"best", "friends":
				friends += 1
			"rivals":
				rivals += 1
	return "%d cheerful, %d okay, %d fed up  ·  %d %s of friends, %d %s of rivals" % [moods["cheerful"], moods["okay"], moods["fed_up"],
		friends, "pair" if friends == 1 else "pairs", rivals, "pair" if rivals == 1 else "pairs"]


## Everything that needs the owner, worst first: [{score, who, title, detail, action, fix}].
static func issues(t: Array) -> Array:
	var out: Array = []
	var has_manager: bool = t.any(func(s): return s.manager and s.is_here())
	for s in t:
		if s.burnout_warned or s.burnout_nights > 0:
			var left: int = maxi(1, Data.BURNOUT_QUIT_NIGHTS - s.burnout_nights)
			out.append({"score": 100.0 + s.burnout_nights * 10.0, "who": [s], "title": "%s is burning out" % s.person_name,
				"detail": "%d more bad %s and they quit." % [left, "night" if left == 1 else "nights"],
				"action": "Tomorrow off" if s.away_day != GameState.day + 1 else "", "fix": day_off.bind(s)})
		elif s.raise_refused >= Data.RAISE_REFUSALS_QUIT - 1:
			out.append({"score": 90.0, "who": [s], "title": "%s wants a raise" % s.person_name,
				"detail": "Turned down %d times. Once more and they find another job." % s.raise_refused,
				"action": "+$0.50/hr", "fix": give_raise.bind(s)})
		elif s.stress >= Data.STRESS_FED_UP:
			var why: String = s.stress_reasons_text(2)
			out.append({"score": 40.0 + s.stress * 0.5, "who": [s], "title": "%s is fed up (%d%% stress)" % [s.person_name, int(s.stress)],
				"detail": why if why != "" else "Breaks, a sofa and friends nearby help.",
				"action": "Take a break" if s.is_here() and not s.on_break and not s.break_asked else "", "fix": send_on_break.bind(s)})
	for i in t.size():
		for j in range(i + 1, t.size()):
			var a = t[i]
			var b = t[j]
			if Crew.labels.get(Crew.pair_key(a, b), "") != "rivals":
				continue
			var together: bool = a.shift == b.shift or a.shift == "double" or b.shift == "double"
			var avg := (Crew.opinion(a, b) + Crew.opinion(b, a)) / 2.0
			var fix: Callable = split_shifts.bind(a, b)
			var action := "Split shifts" if together else ""
			if has_manager and a.is_here() and b.is_here():
				fix = talk_it_out.bind(a, b)
				action = "Manager talk"
			out.append({"score": (65.0 if together else 30.0) - avg * 0.2, "who": [a, b], "title": "%s and %s are rivals" % [a.person_name, b.person_name],
				"detail": ("On the same shift: they bicker and slow down." if together else "Kept apart on different shifts."),
				"action": action, "fix": fix})
	out.sort_custom(func(x, y): return x["score"] > y["score"])
	return out


func refresh_issues(t: Array) -> void:
	var list: Array = issues(t).slice(0, MAX_ISSUES)
	var key := ""
	for it in list:
		key += "%s|%s|" % [it["title"], it["action"]]
	if key == _key and attention.get_child_count() > 0:
		return
	_key = key
	for c in attention.get_children():
		c.queue_free()
	if list.is_empty():
		if t.size() >= 2:
			attention.add_child(UiKit.label("Nothing right now. Everyone's getting on with it.", 12, UiKit.MUTED, &"SmallLabel"))
		return
	for it in list:
		attention.add_child(_issue_row(it))


func _issue_row(it: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.row_style(Color("2a221d")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	for s in it["who"]:
		row.add_child(_face(s))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := UiKit.label(it["title"], 13, UiKit.INK, &"StatLabel")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(title)
	var d := UiKit.label(it["detail"], 11, UiKit.MUTED, &"SmallLabel")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(80, 0)
	col.add_child(d)
	if it["action"] != "":
		var b := Button.new()
		b.text = it["action"]
		b.theme_type_variation = &"SmallButton"
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.focus_mode = Control.FOCUS_NONE
		var fix: Callable = it["fix"]
		b.pressed.connect(func():
			fix.call()
			_key = ""
			refresh())
		row.add_child(b)
	return panel


func _face(s, px: float = 26.0) -> Portrait:
	var p := Portrait.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.ring = Crew.MOOD_COLORS.get(s.mood, UiKit.MUTED) if s.mood != "okay" else Color(0, 0, 0, 0)
	p.show_person(s)
	return p


# ------------------------------------------------------------------ the fixes

static func day_off(s) -> void:
	s.away_day = GameState.day + 1
	s.add_stress(-10.0, "a day off coming")
	Crew.say(s, "thanks", "heart")
	Crew.log_line("You gave %s tomorrow off." % s.person_name, "sun", [s])
	GameState.staff_changed.emit()


static func give_raise(s) -> void:
	s.raises += 0.5
	s.wage += 0.5
	s.raise_refused = 0
	s.add_stress(-8.0, "a raise")
	Crew.log_line("You gave %s a raise ($%.2f an hour)." % [s.person_name, s.wage], "star", [s])
	GameState.staff_changed.emit()


static func send_on_break(s) -> void:
	s.break_asked = true
	Crew.log_line("You told %s to take a break after this job." % s.person_name, "clock", [s])


## One on the day shift, one on nights, and the schedule leaves them there.
static func split_shifts(a, b) -> void:
	a.shift = "open"
	b.shift = "close"
	a.shift_locked = true
	b.shift_locked = true
	Crew.log_line("You put %s on days and %s on nights, well apart." % [a.person_name, b.person_name], "clock", [a, b])
	GameState.staff_changed.emit()


static func talk_it_out(a, b) -> void:
	if Crew.ask_mediation(a, b):
		Crew.log_line("You asked a manager to sit %s and %s down." % [a.person_name, b.person_name], "chat", [a, b])


func refresh_log() -> void:
	var everything := show_all.button_pressed
	log_title.text = "Staff log" if everything else "Recent"
	var lines: Array = []
	for i in range(Crew.entries.size() - 1, -1, -1):
		var e: Dictionary = Crew.entries[i]
		if not everything and not e["icon"] in IMPORTANT and e["day"] < GameState.day:
			continue
		var m := int(e["min"])
		var col: String = ICON_COLORS.get(e["icon"], "#b9a797")
		lines.append("[color=#7d6d61]Day %d, %02d:%02d[/color]  [img width=13 height=13 color=%s]res://ui/icons/%s.svg[/img] %s" % [
			e["day"], (m / 60) % 24, m % 60, col, e["icon"], e["text"]])
		if lines.size() >= LOG_LINES:
			break
	if lines.is_empty():
		log_text.text = "[color=#b9a797]Nothing yet. Open the diner and see what happens.[/color]"
	else:
		log_text.text = "\n".join(lines)
