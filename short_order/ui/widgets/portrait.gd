class_name Portrait
extends Control
## A little head-and-shoulders picture of a person, drawn in code.
## Call show_person() with a staff member, a hiring candidate or a customer.

const Art = preload("res://world/art.gd")

@export var skin := Color("e0ac86")
@export var hair := Color("5a3a22")
@export var shirt := Color("c8403a")
@export var staff := true
@export var look := ""
@export var ring := Color(0, 0, 0, 0)


func show_person(p) -> void:
	if p is Dictionary:
		skin = p["skin"]
		hair = p["hair"]
		shirt = Color("7d8a96")
		staff = false
		look = ""
	elif p != null:
		skin = p.skin
		hair = p.hair
		shirt = p.shirt
		staff = p.is_staff
		look = p.look
	queue_redraw()


func _draw() -> void:
	var d := minf(size.x, size.y)
	var r := Rect2((size - Vector2(d, d)) / 2.0, Vector2(d, d))
	draw_circle(r.get_center(), d * 0.5, Color("201915"))
	Art.portrait(self, r, skin, hair, shirt, staff, look)
	if ring.a > 0.0:
		draw_arc(r.get_center(), d * 0.5 - 1.0, 0, TAU, 32, ring, 2.0, true)
