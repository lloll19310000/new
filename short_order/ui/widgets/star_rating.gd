@tool
class_name StarRating
extends Control
## Five stars, filled up to `value` (0 to 5), with partial stars.

@export_range(0.0, 5.0, 0.1) var value := 3.0:
	set(v):
		value = v
		queue_redraw()
@export var star_size := 16.0:
	set(v):
		star_size = v
		update_minimum_size()
		queue_redraw()
@export var gap := 2.0
@export var filled := Color("f2c14e")
@export var empty := Color("4d3f36")


func _get_minimum_size() -> Vector2:
	return Vector2(star_size * 5 + gap * 4, star_size)


func star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.46
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


func _draw() -> void:
	var y := (size.y - star_size) / 2.0
	for i in 5:
		var c := Vector2(i * (star_size + gap) + star_size / 2.0, y + star_size / 2.0 + star_size * 0.04)
		var pts := star_points(c, star_size * 0.52)
		draw_colored_polygon(pts, empty)
		var part := clampf(value - i, 0.0, 1.0)
		if part >= 0.999:
			draw_colored_polygon(pts, filled)
		elif part > 0.01:
			var x0 := c.x - star_size / 2.0
			var clip := PackedVector2Array([Vector2(x0 - 1, c.y - star_size), Vector2(x0 + star_size * part, c.y - star_size),
				Vector2(x0 + star_size * part, c.y + star_size), Vector2(x0 - 1, c.y + star_size)])
			for poly in Geometry2D.intersect_polygons(pts, clip):
				draw_colored_polygon(poly, filled)
