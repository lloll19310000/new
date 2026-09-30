extends Button
## One item in the build menu: a picture, the name and the price.

signal chosen(key: String)

const ART_KEYS := {"floor_diner": "floor:1", "floor_kitchen": "floor:2", "floor_staff": "floor:3", "floor_restroom": "floor:4", "wall": "wall", "door": "door", "land": "land"}
const PER_TILE := ["floor_diner", "floor_kitchen", "floor_staff", "floor_restroom", "wall"]

var key := ""

@onready var art: ArtIcon = %Art
@onready var name_label: Label = %Name
@onready var cost_label: Label = %Cost


func setup(k: String) -> void:
	key = k
	if is_node_ready():
		apply()


func _ready() -> void:
	pressed.connect(func():
		if not disabled:
			chosen.emit(key))
	apply()


func apply() -> void:
	if key == "":
		return
	art.what = ART_KEYS.get(key, "furniture:" + key)
	name_label.text = Data.item_name(key)
	cost_label.text = "$%d%s" % [Data.item_cost(key), "/tile" if key in PER_TILE else ""]
	if key == "land":
		cost_label.text = "Plots"
	refresh()


func refresh() -> void:
	tooltip_text = "%s  ($%d%s)\n%s" % [Data.item_name(key), Data.item_cost(key), " a tile" if key in PER_TILE else "", Data.item_desc(key)]
	if not GameState.item_unlocked(key):
		disabled = true
		modulate = Color(1, 1, 1, 0.45)
		cost_label.text = "Locked"
		for g in Data.GOALS:
			if g["reward"].get("decor", "") == key:
				tooltip_text += "\nLocked: reach the goal \"%s\" (%s) on the Goals board." % [g["name"], g["desc"].to_lower().trim_suffix(".")]
		return
