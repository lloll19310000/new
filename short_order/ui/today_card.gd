extends PanelContainer
## Live numbers while you're open: customers served, walk-outs, sales, tips,
## the line at the door, and the rush hour if there is one.

var main
var _t := 0.0

@onready var served: Label = %Served
@onready var left_label: Label = %Left
@onready var sales: Label = %Sales
@onready var tips: Label = %Tips
@onready var waiting: Label = %Waiting
@onready var rush_chip: PanelContainer = %RushChip
@onready var rush_label: Label = %RushLabel


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	visible = GameState.is_active()
	if not visible or main == null:
		return
	var t: Dictionary = GameState.today
	served.text = str(t["served"])
	left_label.text = str(t["left"])
	left_label.add_theme_color_override("font_color", UiKit.CHERRY if t["left"] > 0 else UiKit.INK)
	sales.text = "$%d" % int(t["revenue"])
	tips.text = "$%d" % int(t["tips"])
	var n := 0
	for g in main.groups:
		if is_instance_valid(g) and (g.state == "waiting"):
			n += g.members.size()
	waiting.text = str(n)
	var r: Dictionary = GameState.current_rush()
	rush_chip.visible = not r.is_empty()
	if not r.is_empty():
		rush_label.text = r["name"]
