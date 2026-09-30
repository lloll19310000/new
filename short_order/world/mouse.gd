extends "res://people/pawn.gd"
## A mouse. It darts from place to place along the walls for a few minutes,
## then slips back into a crack. Customers who see one aren't happy; staff
## who get close chase it out; traps catch it. Click it to shoo it yourself.

var life := 10.0                # game minutes before it leaves on its own
var seen_by := {}               # staff ids who've already noticed it
var is_mouse := true
var _acc := 0.0
var _wait := 0.0


func _ready() -> void:
	super()
	mess = 0.0
	speed_mult = 1.7
	z_index = 1


func tick(dt: float, minutes: float) -> void:
	life -= minutes
	if life <= 0.0:
		Health.remove_mouse(self)
		return
	_acc += minutes
	if _acc >= 1.0:
		_acc -= 1.0
		Health.mouse_minute(self)
		if is_queued_for_deletion():
			return
	if not is_moving():
		_wait -= minutes
		if _wait <= 0.0:
			_wait = randf_range(0.2, 1.2)
			scurry()
	move_tick(dt)


## A short dash to somewhere nearby indoors, hugging the walls when it can.
func scurry() -> void:
	var here := current_cell()
	var best := here
	for i in 10:
		var c := here + Vector2i(randi_range(-5, 5), randi_range(-5, 5))
		if not lot.in_lot(c) or not lot.indoors(c) or not lot.walkable(c):
			continue
		best = c
		for d in Data.DIRS:
			if lot.in_lot(c + d) and lot.wall[lot.idx(c + d)] == 1:
				go_to(c)
				return
	if best != here:
		go_to(best)


func _draw() -> void:
	var f := facing.normalized() if facing.length() > 0.01 else Vector2.RIGHT
	var side := Vector2(-f.y, f.x)
	var wig := sin(step_anim * 1.5) * 2.0
	draw_polyline(PackedVector2Array([-f * 5.0, -f * 9.0 + side * wig, -f * 13.0 - side * wig * 0.5]), Color("c9a7a0"), 1.2, true)
	Art.ellipse(self, Vector2(0, 2), Vector2(6, 3), Color(0, 0, 0, 0.2))
	Art.ellipse(self, Vector2.ZERO, Vector2(6.5, 4.2), Color("7c7a80"), f.angle())
	Art.ellipse(self, f * 4.5, Vector2(3.2, 2.6), Color("8c8a90"), f.angle())
	draw_circle(f * 3.0 + side * 2.6, 1.8, Color("e8a8b8"))
	draw_circle(f * 3.0 - side * 2.6, 1.8, Color("e8a8b8"))
	draw_circle(f * 7.2, 0.9, Color("2b2226"))
