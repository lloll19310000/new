class_name ArtIcon
extends Control
## Draws a piece of the game's own art, scaled to fit: furniture, a floor,
## walls, a dish or an ingredient. Set `what` to something like
## "furniture:grill", "floor:1", "wall", "door", "dish:burger" or "ingredient:meat".
## (It draws when the game runs; in the editor it's an empty box.)

const Art = preload("res://world/art.gd")

@export var what := "furniture:table":
	set(v):
		what = v
		queue_redraw()
@export var dir := 0:
	set(v):
		dir = v
		queue_redraw()


func _draw() -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	var parts := what.split(":")
	var kind: String = parts[0]
	var key: String = parts[1] if parts.size() > 1 else ""
	match kind:
		"furniture":
			if not Data.FURNITURE.has(key):
				return
			var s: Array = Data.FURNITURE[key]["size"]
			var tiles := Vector2(s[0], s[1]) if dir % 2 == 0 else Vector2(s[1], s[0])
			var cell := minf(size.x / tiles.x, size.y / tiles.y)
			cell = minf(cell, size.y * 0.8)
			var on_wall: bool = Data.FURNITURE[key]["floor"] == "wall"
			var run := int(tiles.x) + 2          # a run of wall one tile wider each side
			if on_wall:
				cell = minf(cell, minf(size.x / run, size.y / 1.6))
			var r := Rect2((size - tiles * cell) / 2.0, tiles * cell)
			if on_wall:
				r.position.y -= cell * 0.25   # room for the strip of floor below the wall
				var wr := Rect2(r.position - Vector2(cell, 0), Vector2(cell * run, cell))
				# the diner floor on the room side of the wall, one tile per cell, kept inside the icon
				for i in run:
					var ft := Rect2(wr.position + Vector2(cell * i, cell * 0.5), Vector2(cell, cell * 0.5))
					draw_rect(ft, Color("efe8dc") if i % 2 == 0 else Color("b4bcbf"))
				for i in run:
					Art.wall_rect(self, Rect2(wr.position + Vector2(cell * i, 0), Vector2(cell, cell)), false, false, i > 0, i < run - 1)
			Art.furniture_in(self, key, r, dir, null, 2)
		"floor":
			var n := int(key)
			var c := minf(size.x, size.y) / 2.0
			var o := (size - Vector2(c, c) * 2.0) / 2.0
			for y in 2:
				for x in 2:
					Art.floor_tile(self, Rect2(o + Vector2(x, y) * c, Vector2(c, c)), n, 0.3 + 0.3 * x, Vector2i(x, y))
		"wall", "door":
			var c2 := minf(size.x / 3.0, size.y)
			var o2 := (size - Vector2(c2 * 3.0, c2)) / 2.0
			for i in 3:
				var rr := Rect2(o2 + Vector2(c2 * i, 0), Vector2(c2, c2))
				if kind == "door" and i == 1:
					Art.door_rect(self, rr, true)
				else:
					Art.wall_rect(self, rr, false, false, i > 0, i < 2)
		"dish":
			Art.dish(self, key, size / 2.0, minf(size.x, size.y) / 16.0)
		"land":
			var c3 := minf(size.x, size.y)
			draw_rect(Rect2((size - Vector2(c3, c3)) / 2.0, Vector2(c3, c3)), Color("5f9a4a"))
			Art.for_sale_sign(self, size / 2.0 + Vector2(0, c3 * 0.12), "", c3 / 90.0)
		"ingredient":
			Art.ingredient(self, key, size / 2.0 + Vector2(0, 1), minf(size.x, size.y) / 20.0)
