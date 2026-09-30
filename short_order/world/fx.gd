extends Node2D
## Floating text like "+$23" or review stars that rise and fade.

const Art = preload("res://world/art.gd")

var items: Array = []   # {"pos": Vector2, "text": String, "color": Color, "t": float}


func add(pos: Vector2, text: String, color: Color) -> void:
	items.append({"pos": pos, "text": text, "color": color, "t": 0.0})
	if items.size() > 60:
		items.pop_front()


func _process(delta: float) -> void:
	if items.is_empty():
		return
	for it in items:
		it["t"] += delta
	items = items.filter(func(it): return it["t"] < 1.8)
	queue_redraw()


func _draw() -> void:
	var font := Art.font()
	for it in items:
		var t: float = it["t"]
		var a := clampf(1.8 - t, 0.0, 1.0)
		var p: Vector2 = it["pos"] - Vector2(0, 18 + t * 22)
		var c: Color = it["color"]
		c.a = a
		var text: String = it["text"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(font, p - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.08, 0.08, 0.1, a * 0.85))
		draw_string(font, p - Vector2(w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
