extends ScrollContainer
## The Staff page: people looking for work today, your crew, and how many
## jobs of each kind are waiting (handy for seeing why the floors are dirty).

signal hire_requested(index: int)
signal fire_requested(who)

const StaffCard = preload("res://ui/staff_card.tscn")
const CandidateCard = preload("res://ui/candidate_card.tscn")

@onready var candidates_box: VBoxContainer = %Candidates
@onready var crew_box: VBoxContainer = %Crew
@onready var crew_count: Label = %CrewCount
@onready var jobs_row: HBoxContainer = %JobsRow
@onready var empty_note: Label = %EmptyNote

var cards := {}            # staff node -> card
var _cand_key := ""
var _job_labels := {}
var _t := 0.0


func _ready() -> void:
	GameState.staff_changed.connect(refresh)
	for j in Data.JOBS:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		box.tooltip_text = "%s jobs waiting: %s" % [Data.JOB_NAMES[j], Data.JOB_DESC[j]]
		box.add_child(UiKit.icon_rect(UiKit.JOB_ICONS[j], 14, UiKit.MUTED))
		var l := Label.new()
		l.theme_type_variation = &"SmallLabel"
		l.text = "0"
		box.add_child(l)
		jobs_row.add_child(box)
		_job_labels[j] = l
	refresh()


func refresh() -> void:
	# candidates: rebuilt only when the list changes
	var key := str(GameState.day) + "|"
	for c in GameState.candidates:
		key += c["name"] + ","
	if key != _cand_key:
		_cand_key = key
		for c in candidates_box.get_children():
			c.queue_free()
		for i in GameState.candidates.size():
			var card = CandidateCard.instantiate()
			card.setup(GameState.candidates[i], i)
			card.hire_requested.connect(func(idx: int): hire_requested.emit(idx))
			candidates_box.add_child(card)
		if GameState.candidates.is_empty():
			var l := Label.new()
			l.theme_type_variation = &"MutedLabel"
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(100, 0)
			l.text = "Nobody else today. New people come by every morning."
			candidates_box.add_child(l)
	# crew: add and remove cards as people join and leave, refresh the rest
	for s in cards.keys():
		if not GameState.staff.has(s):
			cards[s].queue_free()
			cards.erase(s)
	for s in GameState.staff:
		if not cards.has(s):
			var card = StaffCard.instantiate()
			card.setup(s)
			card.fire_requested.connect(func(who): fire_requested.emit(who))
			crew_box.add_child(card)
			cards[s] = card
		elif cards[s].is_node_ready():
			cards[s].refresh()
	crew_count.text = "%d of %d" % [GameState.staff.size(), Data.MAX_STAFF]
	empty_note.visible = GameState.staff.is_empty()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not is_visible_in_tree():
		return
	_t = 0.25
	for s in cards:
		if is_instance_valid(s) and cards[s].is_node_ready():
			cards[s].refresh()
	var counts: Dictionary = JobBoard.count_by_type()
	for j in _job_labels:
		_job_labels[j].text = str(counts.get(j, 0))
		_job_labels[j].add_theme_color_override("font_color", UiKit.GOLD if counts.get(j, 0) > 4 else UiKit.INK)
