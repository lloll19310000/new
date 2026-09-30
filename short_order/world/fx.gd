extends Node2D
## Little pops that rise and fade: a coin with the amount when someone pays,
## a gold coin for a tip, a row of stars for a review, or a short word
## ("Burnt!"). Pops at the same spot stack instead of piling on top of each other.

const Art = preload("res://world/art.gd")
const LIFE := 1.8

var items: Array = []   # {"pos", "text", "color", "t", "kind", "value", "lift"}


func add(pos: Vector2, text: String, color: Color, kind: String = "text", value: float = 0.0) -> void:
	# stack on anything still fresh at the same spot
	var lift := 0.0
	for it in items:
		if it["t"] < 0.9 and it["pos"].distance_to(pos) < 24.0:
			lift = minf(maxf(lift, it["lift"] + 15.0), 45.0)
	items.append({"pos": pos, "text": text, "color": color, "t": 0.0, "kind": kind, "value": value, "lift": lift})
	if items.size() > 60:
		items.pop_front()


## Someone paid: a coin and the amount, and the tip beside it in gold.
## tip_only: just a tip (a gold coin).
func money(pos: Vector2, amount: float, tip_only: bool = false, tip: float = 0.0) -> void:
	if amount < 0.5:
		return
	var text := "$%d" % int(round(amount))
	if tip >= 1.0:
		text += " +%d" % int(round(tip))
	add(pos, text, Color("f2c14e") if tip_only else Color("8ae596"), "tip" if tip_only else "coin", amount)


## A review: filled and empty stars.
func stars(pos: Vector2, score: float) -> void:
	add(pos, "", Color("f0c24f") if score >= 3.0 else Color("ff8f7a"), "stars", score)


func _process(delta: float) -> void:
	if items.is_empty():
		return
	for it in items:
		it["t"] += delta
	items = items.filter(func(it): return it["t"] < LIFE)
	queue_redraw()


func _draw() -> void:
	var font := Art.font()
	for it in items:
		var t: float = it["t"]
		var a := clampf(LIFE - t, 0.0, 1.0)
		var p: Vector2 = it["pos"] - Vector2(0, 18 + t * 18 + it["lift"])
		var c: Color = it["color"]
		c.a = a
		var shade := Color(0.08, 0.08, 0.1, a * 0.85)
		match it["kind"]:
			"coin", "tip":
				var r := 5.0 if it["kind"] == "coin" else 4.0
				var text: String = it["text"]
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				var cp := p - Vector2((w + r * 2 + 3) / 2.0 - r, 4)
				draw_circle(cp, r + 1.2, shade)
				draw_circle(cp, r, Color("e0b64a", a) if it["kind"] == "tip" else Color("6cc3a0", a))
				draw_circle(cp - Vector2(1.2, 1.2), r * 0.45, Color(1, 1, 1, 0.5 * a))
				var tp := cp + Vector2(r + 3, 4)
				draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, shade)
				draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
			"stars":
				var n := int(round(it["value"]))
				for i in 5:
					var sp := p + Vector2((i - 2) * 9.0, -4)
					_star(sp, 4.2, shade)
					_star(sp, 3.4, c if i < n else Color(0.4, 0.36, 0.33, a))
			_:
				var text2: String = it["text"]
				var w2 := font.get_string_size(text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				draw_string_outline(font, p - Vector2(w2 / 2, 0), text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, shade)
				draw_string(font, p - Vector2(w2 / 2, 0), text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * rr)
	draw_colored_polygon(pts, col)
