extends Node2D
## Shared by staff and customers: walking along a path and drawing a person.

const Art = preload("res://world/art.gd")

var lot
var path: Array[Vector2i] = []
var facing := Vector2.DOWN
var step_anim := 0.0
var speed_mult := 1.0
var skin := Color.WHITE
var hair := Color.BLACK
var shirt := Color.WHITE
var carry: Array = []          # dish ids, or "dirty" for a dirty plate
var carry_bag := false         # carrying takeout (drawn as a paper bag)
var sitting := false
var offset := Vector2.ZERO     # small nudge so people in a group don't stack exactly
var is_staff := false
var wears_hat := false
var look := ""                 # extra details: "backpack", "cap", "beret", "coat"
var body_scale := 1.0          # kids are a bit smaller
var customer_nav := false      # customers stay out of the kitchen and staff room
var mess := 1.0                # how much dirt they track in


func _ready() -> void:
	add_to_group("pawns")


func current_cell() -> Vector2i:
	return lot.to_cell(position - offset)


func place_at(c: Vector2i) -> void:
	position = lot.cell_center(c) + offset
	queue_redraw()


func set_path(p: Array[Vector2i]) -> void:
	path = p.duplicate()
	if not path.is_empty() and path[0] == current_cell():
		path.pop_front()


func go_to(target: Vector2i) -> bool:
	var p: Array[Vector2i] = lot.find_path(current_cell(), target, customer_nav)
	if p.is_empty():
		return false
	set_path(p)
	return true


func go_to_any(targets: Array) -> bool:
	if targets.is_empty():
		return false
	if current_cell() in targets and path.is_empty():
		return true
	var p: Array[Vector2i] = lot.path_to_any(current_cell(), targets, customer_nav)
	if p.is_empty():
		return false
	set_path(p)
	return true


func is_moving() -> bool:
	return not path.is_empty()


func move_tick(dt: float) -> void:
	if path.is_empty():
		return
	var remaining := Data.WALK_TILES_PER_SEC * speed_mult * Data.TILE * dt
	while remaining > 0.0 and not path.is_empty():
		var next: Vector2i = path[0]
		if not lot.can_walk(next, customer_nav):
			path.clear()   # something was built in the way; the caller will re-plan
			break
		var target: Vector2 = lot.cell_center(next) + offset
		var to := target - position
		var d := to.length()
		if d <= remaining:
			position = target
			remaining -= d
			path.pop_front()
			on_enter_cell(next)
		else:
			facing = to / d
			position += facing * remaining
			remaining = 0.0
	step_anim += dt * 11.0
	queue_redraw()


func on_enter_cell(c: Vector2i) -> void:
	if lot.indoors(c) and randf() < 0.015 * mess:
		lot.add_dirt(c, 0.1)


func face_toward(p: Vector2) -> void:
	var d := p - position
	if d.length() > 0.5:
		facing = d.normalized()
		queue_redraw()


func _draw() -> void:
	Art.person(self, Vector2.ZERO, facing, shirt, skin, hair, step_anim, is_staff, wears_hat, sitting, look, body_scale)
	if carry.is_empty():
		return
	var side := Vector2(-facing.y, facing.x)
	for i in carry.size():
		var p := facing * 10.0 + side * (float(i) - (carry.size() - 1) / 2.0) * 7.0 - Vector2(0, 3)
		if carry[i] == "trash":
			Art.trash_bag(self, p, 0.9)
		elif carry_bag:
			Art.bag(self, p, 0.6)
		elif carry[i] == "dirty":
			Art.plate(self, p, 0.6, true)
		else:
			Art.dish(self, carry[i], p, 0.62)
