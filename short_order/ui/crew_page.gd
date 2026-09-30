extends ScrollContainer
## The Crew page: a grid of how everyone feels about everyone, and the staff
## log underneath (newest first). Click a face in the grid to see only the
## log lines about that person.

const ICON_COLORS := {"heart": "#e27fa8", "storm": "#e75a4e", "alert": "#f2c14e", "phone": "#6aa6d9",
	"star": "#f2c14e", "fix": "#6cc3a0", "people": "#6cc3a0", "staff": "#6cc3a0", "walkout": "#e75a4e"}
const LEGEND := ["friends", "friendly", "neutral", "tense", "rivals"]

@onready var grid: OpinionGrid = %Grid
@onready var empty_note: Label = %EmptyNote
@onready var log_title: Label = %LogTitle
@onready var show_all: Button = %ShowAll
@onready var log_text: RichTextLabel = %Log
@onready var legend: HFlowContainer = %Legend

var filter_id := -1
var _dirty := false


func _ready() -> void:
	for l in LEGEND:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var sw := ColorRect.new()
		sw.color = Crew.LABEL_COLORS[l]
		sw.custom_minimum_size = Vector2(11, 11)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var lab := Label.new()
		lab.text = Crew.LABEL_NAMES[l]
		lab.theme_type_variation = &"SmallLabel"
		row.add_child(lab)
		legend.add_child(row)
	grid.person_clicked.connect(func(s):
		filter_id = -1 if filter_id == s.id else s.id
		refresh_log())
	show_all.pressed.connect(func():
		filter_id = -1
		refresh_log())
	Crew.log_added.connect(func(_e): _dirty = true)
	GameState.staff_changed.connect(refresh)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			refresh())
	refresh()


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		refresh_log()


func refresh() -> void:
	var n := Crew.team().size()
	grid.visible = n >= 2
	legend.visible = n >= 2
	empty_note.visible = n < 2
	grid.refresh()
	if filter_id >= 0 and Crew.by_id(filter_id) == null:
		filter_id = -1
	refresh_log()


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
