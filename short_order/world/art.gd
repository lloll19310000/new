extends RefCounted
## All the world drawing, done in code with simple shapes (no image files).
## Every function takes the CanvasItem to draw on as its first argument.
## The interface uses these too, for build icons, dish icons and portraits.
##
## Want sprites instead? Replace the body of a function with
## ci.draw_texture(preload("res://art/grill.png"), r.position) and so on.

const T := 32.0

static var _boxes := {}


static func font() -> Font:
	var th := ThemeDB.get_project_theme()
	if th != null and th.default_font != null:
		return th.default_font
	return ThemeDB.fallback_font


static func box_style(fill: Color, border: Color, radius: int = 4, bw: int = 2) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d" % [fill.to_html(), border.to_html(), radius, bw]
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	_boxes[key] = sb
	return sb


static func rbox(ci: CanvasItem, r: Rect2, fill: Color, border: Color, radius: int = 4, bw: int = 2) -> void:
	ci.draw_style_box(box_style(fill, border, radius, bw), r)


static func ellipse(ci: CanvasItem, c: Vector2, radii: Vector2, color: Color, angle: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(angle))
	ci.draw_colored_polygon(pts, color)


# ------------------------------------------------------------------ people

## look: "" (plain), "backpack", "cap", "beret", "coat", "apron".
## A look of their own, the same every time for the same seed: hairstyle,
## build, beard, glasses, clothes pattern, an accessory and an expression.
static func style_for(seed_: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var accents := [Color("d23b30"), Color("3f86c6"), Color("f2c14e"), Color("4f9a45"), Color("b58be0"), Color("e27fa8"), Color("2b2b30")]
	return {"hair": rng.randi_range(0, 7), "beard": rng.randf() < 0.22, "glasses": rng.randf() < 0.25,
		"build": rng.randf_range(0.88, 1.16), "pattern": rng.randi_range(0, 4), "extra": rng.randi_range(0, 5),
		"accent": accents[rng.randi() % accents.size()], "mouth": rng.randi_range(0, 3), "brows": rng.randf_range(-0.25, 0.25),
		"bounce": rng.randf_range(0.7, 1.35)}


## Someone standing at p (their feet a little below it), from the Kenney
## walkers in their own colours. step < 0: standing still.
static func person(ci: CanvasItem, p: Vector2, facing: Vector2, shirt: Color, skin: Color, hair: Color,
		step: float, staff: bool, _hat: bool, sitting: bool = false, look: String = "", s: float = 1.0, st: Dictionary = {}) -> void:
	var tex := Sprites.person(skin, hair, shirt, st, staff, look)
	var col := Sprites.dir_col(facing)
	var fr := 0
	if step >= 0.0 and not sitting:
		fr = 1 + int(step / 2.8) % 2
	var sz := 32.0 * s
	ci.draw_rect(Rect2(p + Vector2(-8, 9) * s, Vector2(16, 3) * s), Color(0, 0, 0, 0.22))
	ci.draw_rect(Rect2(p + Vector2(-6, 8) * s, Vector2(12, 5) * s), Color(0, 0, 0, 0.14))
	var top := p + Vector2(-sz / 2.0, (-20.0 if not sitting else -24.0) * s)
	ci.draw_texture_rect_region(tex, Rect2(top, Vector2(sz, sz)), Rect2(col * 16, fr * 16, 16, 16))


## A head-and-shoulders picture for the interface, filling rect r: the same
## pixel person as in the world, blown up.
static func portrait(ci: CanvasItem, r: Rect2, skin: Color, hair: Color, shirt: Color, staff: bool, look: String = "", st: Dictionary = {}) -> void:
	var tex := Sprites.portrait(skin, hair, shirt, st, staff, look)
	var d := minf(r.size.x, r.size.y) * 0.86
	ci.draw_texture_rect(tex, Rect2(r.get_center() - Vector2(d, d * 0.93) / 2.0 + Vector2(0, r.size.y * 0.04), Vector2(d, d * 0.93)), false)


static func plate(ci: CanvasItem, p: Vector2, s: float = 1.0, dirty: bool = false) -> void:
	ci.draw_circle(p, 7.5 * s, Color("dcdcd6"))
	ci.draw_circle(p, 6.2 * s, Color("fbfbf7"))
	if dirty:
		ci.draw_circle(p + Vector2(-1.5, 1) * s, 2.4 * s, Color(0.55, 0.38, 0.2, 0.7))
		ci.draw_circle(p + Vector2(2, -1.5) * s, 1.4 * s, Color(0.7, 0.2, 0.15, 0.6))


static func trash_bag(ci: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	ellipse(ci, p + Vector2(0, 1) * s, Vector2(6, 7) * s, Color("1d1d22"))
	ellipse(ci, p + Vector2(-1.5, -1) * s, Vector2(2.5, 3) * s, Color("34343c"))
	ci.draw_line(p + Vector2(-2, -7) * s, p + Vector2(2, -9) * s, Color("1d1d22"), 1.4 * s)


## A glass coffee pot with a black handle, from above.
static func coffee_pot(ci: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	ci.draw_circle(p, 5.0 * s, Color("dfeef6"))
	ci.draw_circle(p, 4.0 * s, Color("5a3520"))
	ci.draw_circle(p + Vector2(-1.2, -1.2) * s, 1.1 * s, Color(1, 1, 1, 0.35))
	ci.draw_line(p + Vector2(4.5, 0) * s, p + Vector2(8.5, 0) * s, Color("222222"), 2.0 * s)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-4.5, -1.5) * s, p + Vector2(-7.5, 0) * s, p + Vector2(-4.5, 1.5) * s]), Color("dfeef6"))


## A birthday cake with candles, from above.
static func cake(ci: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	ci.draw_circle(p + Vector2(1, 1.5) * s, 7.5 * s, Color(0, 0, 0, 0.25))
	ci.draw_circle(p, 7.5 * s, Color("f4f4f4"))
	ci.draw_circle(p, 6.2 * s, Color("f2a7c3"))
	ci.draw_circle(p, 4.6 * s, Color("fbe3ec"))
	for i in 5:
		var a := TAU * i / 5.0
		var cp := p + Vector2.from_angle(a) * 3.0 * s
		ci.draw_circle(cp, 0.8 * s, Color("6aa6d9") if i % 2 == 0 else Color("f2c14e"))
		ci.draw_circle(cp + Vector2(0, -1.2) * s, 0.5 * s, Color("ffcf5a"))


static func bag(ci: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	rbox(ci, Rect2(p - Vector2(5, 6) * s, Vector2(10, 12) * s), Color("c9a06a"), Color("9c7644"), 2, 1)
	ci.draw_rect(Rect2(p + Vector2(-5, -6) * s, Vector2(10, 2.5) * s), Color("b38a55"))
	ci.draw_circle(p + Vector2(0, -2.5) * s, 1.6 * s, Color("c8403a"))


## q: how well it was cooked (0..1), or -1 to leave presentation out. A
## sloppy plate has a smear and crumbs; a beautiful one a garnish and a drizzle.
static func dish(ci: CanvasItem, d: String, p: Vector2, s: float = 1.0, on_plate: bool = true, q: float = -1.0) -> void:
	if q >= 0.0 and on_plate and Data.DISHES.has(d) and Data.DISHES[d]["plate"] and q < 0.4:
		plate(ci, p, s)
		ellipse(ci, p + Vector2(4.2, 3.2) * s, Vector2(3.0, 1.5) * s, Color(0.45, 0.25, 0.12, 0.55), 0.5)
		p += Vector2(-1.6, 1.2) * s   # slid off-centre
		_dish(ci, d, p, s, false)
	else:
		_dish(ci, d, p, s, on_plate)
	if q < 0.0 or not on_plate or not Data.DISHES.has(d) or not Data.DISHES[d]["plate"]:
		return
	if q < 0.4:
		for o in [Vector2(5.2, -2.5), Vector2(-5.4, 3.6), Vector2(3.4, 5.4)]:
			ci.draw_circle(p + o * s, 0.55 * s, Color("b8793a"))
	elif q >= 0.8:
		# a parsley sprig on the rim and a neat drizzle
		ellipse(ci, p + Vector2(-5.6, -3.6) * s, Vector2(1.6, 0.9) * s, Color("4f9a45"), -0.6)
		ellipse(ci, p + Vector2(-4.4, -4.8) * s, Vector2(1.3, 0.8) * s, Color("6cbf55"), 0.4)
		ci.draw_arc(p + Vector2(0, 0.5) * s, 6.2 * s, 0.3, 1.3, 6, Color(0.78, 0.25, 0.2, 0.8), 0.8 * s)


static func _dish(ci: CanvasItem, d: String, p: Vector2, s: float = 1.0, on_plate: bool = true) -> void:
	match d:
		"burger":
			if on_plate: plate(ci, p, s)
			ci.draw_circle(p, 5.2 * s, Color("6b3a1f"))
			ci.draw_circle(p, 4.4 * s, Color("d9a45b"))
			for o in [Vector2(-1.8, -1), Vector2(1.5, -1.8), Vector2(0.6, 1.4), Vector2(-0.8, 2)]:
				ci.draw_circle(p + o * s, 0.55 * s, Color("f7ecd0"))
		"pancakes":
			if on_plate: plate(ci, p, s)
			ci.draw_circle(p + Vector2(0.6, 0.6) * s, 5 * s, Color("c48a3a"))
			ci.draw_circle(p, 4.8 * s, Color("e3b25a"))
			ci.draw_rect(Rect2(p - Vector2(1.4, 1.4) * s, Vector2(2.8, 2.8) * s), Color("f7e27a"))
		"fries":
			if on_plate: plate(ci, p, s)
			ci.draw_rect(Rect2(p + Vector2(-3.5, -1) * s, Vector2(7, 5) * s), Color("d23b30"))
			for i in 5:
				var x := (-3.0 + i * 1.5) * s
				ci.draw_line(p + Vector2(x, 0), p + Vector2(x + 0.4 * s, -5 * s), Color("f2cf4a"), 1.3 * s)
		"milkshake":
			ci.draw_circle(p, 4.6 * s, Color("f4f4f4"))
			ci.draw_circle(p, 3.7 * s, Color("f2a7c3"))
			ci.draw_line(p, p + Vector2(3, -5) * s, Color("d23b30"), 1.2 * s)
		"omelette":
			if on_plate: plate(ci, p, s)
			ellipse(ci, p, Vector2(5.4, 3.8) * s, Color("e8b93c"), 0.3)
			ellipse(ci, p + Vector2(-0.5, -0.4) * s, Vector2(4.6, 3.0) * s, Color("f7d45a"), 0.3)
			ci.draw_circle(p + Vector2(1.5, 0.5) * s, 0.7 * s, Color("5a9a45"))
			ci.draw_circle(p + Vector2(-1.5, -0.5) * s, 0.6 * s, Color("d23b30"))
		"meatloaf":
			if on_plate: plate(ci, p, s)
			rbox(ci, Rect2(p - Vector2(5, 3) * s, Vector2(10, 6) * s), Color("7a3e22"), Color("5a2a15"), 2, 1)
			ci.draw_rect(Rect2(p - Vector2(4, 2.6) * s, Vector2(8, 1.6) * s), Color("c8403a"))
			ci.draw_line(p + Vector2(-1, -3) * s, p + Vector2(-1, 3) * s, Color("5a2a15"), 0.8 * s)
			ci.draw_line(p + Vector2(2, -3) * s, p + Vector2(2, 3) * s, Color("5a2a15"), 0.8 * s)
		"pie":
			if on_plate: plate(ci, p, s)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-4.5, 3) * s, p + Vector2(4.5, 3) * s, p + Vector2(0, -5) * s]), Color("d9a45b"))
			ci.draw_line(p + Vector2(-4.5, 3) * s, p + Vector2(4.5, 3) * s, Color("b8793a"), 1.6 * s)
			ci.draw_circle(p + Vector2(0, 0.5) * s, 1.2 * s, Color("c8403a"))
			ci.draw_line(p + Vector2(-1.6, -1) * s, p + Vector2(1.6, -1) * s, Color("b8793a"), 0.7 * s)
		"coffee":
			ci.draw_circle(p, 4.2 * s, Color("f4f4f4"))
			ci.draw_circle(p, 3.1 * s, Color("6b4226"))
			ci.draw_arc(p + Vector2(4.5, 0) * s, 1.6 * s, -PI / 2, PI / 2, 8, Color("f4f4f4"), 1.2 * s)
		"double":
			if on_plate: plate(ci, p, s)
			ci.draw_circle(p, 5.6 * s, Color("6b3a1f"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-5.5, -1) * s, p + Vector2(5.5, -2) * s, p + Vector2(4, 3) * s, p + Vector2(-4.5, 3.5) * s]), Color("f2b632"))
			ci.draw_circle(p + Vector2(0, -0.6) * s, 4.5 * s, Color("d9a45b"))
			for o in [Vector2(-1.8, -1.6), Vector2(1.5, -2.4), Vector2(0.6, 0.8), Vector2(-0.8, 1.4), Vector2(2.2, 0.4)]:
				ci.draw_circle(p + o * s, 0.5 * s, Color("f7ecd0"))
		"club":
			if on_plate: plate(ci, p, s)
			for side in [-1.0, 1.0]:
				var q := p + Vector2(side * 2.4, 0) * s
				var tri := PackedVector2Array([q + Vector2(-side * 2.6, -4.2) * s, q + Vector2(side * 2.6, 3.6) * s, q + Vector2(-side * 2.6, 3.6) * s])
				ci.draw_colored_polygon(tri, Color("e9c98a"))
				ci.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("b8793a"), 0.8 * s)
				ci.draw_line(tri[0] + Vector2(0, 1.5) * s, tri[2] + Vector2(side * 1.2, -0.6) * s, Color("5fa84a"), 0.9 * s)
				ci.draw_line(q + Vector2(-side * 1.2, -1.8) * s, q + Vector2(-side * 1.2, -4.5) * s, Color("c8403a"), 0.6 * s)
		"waffles":
			if on_plate: plate(ci, p, s)
			rbox(ci, Rect2(p - Vector2(4.6, 4.6) * s, Vector2(9.2, 9.2) * s), Color("d9a14a"), Color("a8732e"), 2, 1)
			for i in 3:
				var o := (-2.3 + i * 2.3) * s
				ci.draw_line(p + Vector2(o, -4.2 * s), p + Vector2(o, 4.2 * s), Color("b8803a"), 0.8 * s)
				ci.draw_line(p + Vector2(-4.2 * s, o), p + Vector2(4.2 * s, o), Color("b8803a"), 0.8 * s)
			ci.draw_rect(Rect2(p - Vector2(1.2, 1.2) * s, Vector2(2.4, 2.4) * s), Color("f7e27a"))
		"chili", "soup":
			ci.draw_circle(p, 5.2 * s, Color("f4f4f4"))
			ci.draw_circle(p, 4.2 * s, Color("8a2f1c") if d == "chili" else Color("e0a040"))
			if d == "chili":
				for o in [Vector2(-1.5, -1), Vector2(1.6, 0.4), Vector2(-0.2, 1.8), Vector2(1.2, -2)]:
					ellipse(ci, p + o * s, Vector2(0.9, 0.6) * s, Color("5a1c10"))
				ci.draw_circle(p + Vector2(-1.8, 1.4) * s, 0.9 * s, Color("f2e7c6"))
			else:
				for o in [Vector2(-1.5, -1), Vector2(1.6, 0.4), Vector2(-0.2, 1.8)]:
					ci.draw_circle(p + o * s, 0.6 * s, Color("5fa84a"))
				ci.draw_circle(p + Vector2(1.4, -1.8) * s, 0.7 * s, Color("d23b30"))
			ci.draw_line(p + Vector2(3, 2) * s, p + Vector2(6.5, 5) * s, Color("c9c9d1"), 1.1 * s)
		"hometown":
			if on_plate: plate(ci, p, s)
			ci.draw_circle(p, 4.8 * s, Color("e8c170"))
			ci.draw_arc(p, 3.4 * s, 0, TAU * 0.8, 12, Color("c8603a"), 1.4 * s)
			ci.draw_arc(p, 1.8 * s, 1.0, TAU * 0.9, 10, Color("c8603a"), 1.2 * s)
			ci.draw_circle(p + Vector2(2.4, -2.4) * s, 0.9 * s, Color("4f9a45"))
			ci.draw_circle(p + Vector2(-2.6, 1.8) * s, 0.8 * s, Color("4f9a45"))
		"soda", "icedtea":
			# a tall glass seen from above, with ice cubes and a straw
			ci.draw_circle(p, 4.4 * s, Color("dfeef6"))
			ci.draw_circle(p, 3.5 * s, Color("5a2a1a") if d == "soda" else Color("c98a3a"))
			rbox(ci, Rect2(p + Vector2(-2.6, -1.8) * s, Vector2(2.4, 2.2) * s), Color("eaf7ff"), Color("bfe3f7"), 1, 1)
			rbox(ci, Rect2(p + Vector2(0.4, -0.2) * s, Vector2(2.2, 2.2) * s), Color("eaf7ff"), Color("bfe3f7"), 1, 1)
			if d == "icedtea":
				ci.draw_circle(p + Vector2(-1.2, 2.0) * s, 1.3 * s, Color("f7e27a"))
			ci.draw_line(p, p + Vector2(3.4, -5) * s, Color("d23b30") if d == "soda" else Color("4f9a45"), 1.2 * s)


static func ingredient(ci: CanvasItem, key: String, p: Vector2, s: float = 1.0) -> void:
	match key:
		"meat":
			ellipse(ci, p, Vector2(8, 6) * s, Color("b8453a"), -0.3)
			ellipse(ci, p + Vector2(-1, -0.5) * s, Vector2(6, 4.2) * s, Color("d8685a"), -0.3)
			ellipse(ci, p + Vector2(2, 1) * s, Vector2(2.4, 1.6) * s, Color("f3e4d4"), -0.3)
		"bread":
			ellipse(ci, p, Vector2(8.5, 5.5) * s, Color("b8793a"))
			ellipse(ci, p + Vector2(0, -0.8) * s, Vector2(7.5, 4.3) * s, Color("dca25b"))
			for x in [-3.5, 0.0, 3.5]:
				ci.draw_line(p + Vector2(x - 1, -3) * s, p + Vector2(x + 1, 1) * s, Color("b8793a"), 1.2 * s)
		"potatoes":
			ellipse(ci, p + Vector2(-3, 1) * s, Vector2(5.5, 4.2) * s, Color("a4763f"), 0.4)
			ellipse(ci, p + Vector2(3, -1) * s, Vector2(5.2, 4) * s, Color("bf8c4c"), -0.3)
			ci.draw_circle(p + Vector2(4, -2) * s, 0.8 * s, Color("7d5a2e"))
			ci.draw_circle(p + Vector2(-4, 2) * s, 0.8 * s, Color("7d5a2e"))
		"eggs":
			for o in [Vector2(-4, 1), Vector2(0, -2), Vector2(4, 1)]:
				ellipse(ci, p + o * s, Vector2(3.4, 4.3) * s, Color("e6d3b8"))
				ellipse(ci, p + (o + Vector2(-0.8, -1)) * s, Vector2(1.2, 1.6) * s, Color("f6ecdd"))
		"fruit":
			ci.draw_circle(p + Vector2(-3, 1) * s, 4.4 * s, Color("c8403a"))
			ci.draw_circle(p + Vector2(3, 0) * s, 4.4 * s, Color("7fb24a"))
			ci.draw_line(p + Vector2(-3, -3) * s, p + Vector2(-2, -6) * s, Color("6b4226"), 1.2 * s)
			ellipse(ci, p + Vector2(4.5, -4) * s, Vector2(2.2, 1.1) * s, Color("4f9a45"), -0.5)
		"veg":
			ci.draw_circle(p + Vector2(-3, 1) * s, 5.2 * s, Color("5fa84a"))
			ci.draw_circle(p + Vector2(-3.5, 0.5) * s, 3.4 * s, Color("8fcf6a"))
			ci.draw_line(p + Vector2(-6, 1) * s, p + Vector2(-1, 0) * s, Color("4a8a38"), 0.9 * s)
			ci.draw_circle(p + Vector2(3.5, 1.5) * s, 4.3 * s, Color("d8412f"))
			ci.draw_circle(p + Vector2(2.5, 0.2) * s, 1.4 * s, Color("f06a55"))
			ci.draw_line(p + Vector2(3.5, -2.8) * s, p + Vector2(4.5, -4.5) * s, Color("4a8a38"), 1.2 * s)
		"icecream":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, -1) * s, p + Vector2(4, -1) * s, p + Vector2(0, 9) * s]), Color("d9a45b"))
			ci.draw_line(p + Vector2(-2, 1) * s, p + Vector2(1.5, 5) * s, Color("b8793a"), 0.7 * s)
			ci.draw_line(p + Vector2(2, 1) * s, p + Vector2(-1, 5) * s, Color("b8793a"), 0.7 * s)
			ci.draw_circle(p + Vector2(0, -3) * s, 4.6 * s, Color("f7e6f0"))
			ci.draw_circle(p + Vector2(-1.4, -4.4) * s, 1.6 * s, Color("fff7fb"))
			ci.draw_circle(p + Vector2(2.2, -2.4) * s, 0.8 * s, Color("f2a7c3"))
		"dairy":
			rbox(ci, Rect2(p + Vector2(-4.5, -3) * s, Vector2(9, 11) * s), Color("f7f7f2"), Color("c9ccd1"), 2, 1)
			ci.draw_rect(Rect2(p + Vector2(-2.5, -8) * s, Vector2(5, 5) * s), Color("f7f7f2"))
			ci.draw_rect(Rect2(p + Vector2(-2.5, -9) * s, Vector2(5, 2) * s), Color("5a9ad6"))
			ci.draw_rect(Rect2(p + Vector2(-4.5, 1) * s, Vector2(9, 3) * s), Color("5a9ad6"))


# ------------------------------------------------------------------ ground

static func ground(ci: CanvasItem, c: Vector2i, floor_type: int, v: float) -> void:
	var r := Rect2(Vector2(c) * T, Vector2(T, T))
	if c.y >= Data.SIDEWALK_Y + 1:
		ci.draw_rect(r, Color("3c3f44"))
		if c.y == Data.SIDEWALK_Y + 1:
			ci.draw_rect(Rect2(r.position + Vector2(0, T - 2), Vector2(T, 2)), Color("2f3236"))
		if c.y == Data.SIDEWALK_Y + 2 and c.x % 2 == 0:
			ci.draw_rect(Rect2(r.position + Vector2(4, 1), Vector2(T - 8, 3)), Color("e6c34a"))
		return
	if c.y == Data.SIDEWALK_Y:
		ci.draw_rect(r, Color("c9c6bf"))
		ci.draw_rect(Rect2(r.position, Vector2(1, T)), Color("b3b0a9"))
		ci.draw_rect(Rect2(r.position + Vector2(0, T - 3), Vector2(T, 3)), Color("9d9a93"))
		return
	floor_tile(ci, r, floor_type, v, c)


static func floor_tile(ci: CanvasItem, r: Rect2, floor_type: int, v: float, c: Vector2i = Vector2i.ZERO) -> void:
	match floor_type:
		1:
			var a := Color("efe8dc")
			var b := Color("b4bcbf")
			var h := r.size.x / 2.0
			ci.draw_rect(Rect2(r.position, Vector2(h, h)), a)
			ci.draw_rect(Rect2(r.position + Vector2(h, 0), Vector2(h, h)), b)
			ci.draw_rect(Rect2(r.position + Vector2(0, h), Vector2(h, h)), b)
			ci.draw_rect(Rect2(r.position + Vector2(h, h), Vector2(h, h)), a)
		2:
			ci.draw_rect(r, Color("a3aaae"))
			ci.draw_rect(r.grow(-1), Color("bcc3c7"))
		4:
			# small white and pale blue restroom tiles
			var q := r.size.x / 4.0
			for yy in 4:
				for xx in 4:
					var col := Color("e9f1f5") if (xx + yy) % 2 == 0 else Color("cfe0ea")
					ci.draw_rect(Rect2(r.position + Vector2(xx, yy) * q, Vector2(q, q)), col)
			ci.draw_rect(r, Color("b9ccd8"), false, 1.0)
		3:
			var s := r.size.x / T
			var base := Color("b98a5a").lerp(Color("c29460"), v)
			ci.draw_rect(r, base)
			for i in 4:
				var y := r.position.y + i * 8.0 * s
				ci.draw_rect(Rect2(Vector2(r.position.x, y + 7.0 * s), Vector2(r.size.x, 1.0 * s)), Color("9c6f43"))
				var off := fmod((c.x * 13 + c.y * 7 + i * 11) * 5.0, 32.0) * s
				ci.draw_rect(Rect2(Vector2(r.position.x + off, y), Vector2(1.0 * s, 7.0 * s)), Color("a67749"))
		_:
			var g := Color("6e9a4f").lerp(Color("78a657"), v)
			ci.draw_rect(r, g)
			if v > 0.85:
				ci.draw_circle(r.position + Vector2(8 + v * 10, 10 + v * 8) * (r.size.x / T), 1.6, Color("f4efd0"))


static func wall_tile(ci: CanvasItem, c: Vector2i, n_up: bool, n_down: bool, n_left: bool, n_right: bool) -> void:
	var r := Rect2(Vector2(c) * T, Vector2(T, T))
	wall_rect(ci, r, n_up, n_down, n_left, n_right)


const WALL_TOP := Color("e4d6b4")
const WALL_EDGE := Color("9c8360")
const WALL_FACE := Color("c7ab7e")
const WALL_BASE := Color("8e7452")


## A wall seen from a little in front, like the Kenney rooms: a pale top, an
## edge where it meets the room, and its face showing where the room is below.
static func wall_rect(ci: CanvasItem, r: Rect2, n_up: bool, n_down: bool, n_left: bool, n_right: bool) -> void:
	var s := r.size.x / T
	var e := 2.0 * s
	ci.draw_rect(r, WALL_TOP)
	if not n_up:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, e)), WALL_EDGE)
	if not n_left:
		ci.draw_rect(Rect2(r.position, Vector2(e, r.size.y)), WALL_EDGE)
	if not n_right:
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x - e, 0), Vector2(e, r.size.y)), WALL_EDGE)
	if not n_down:
		var face := Rect2(r.position + Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5))
		ci.draw_rect(face, WALL_FACE)
		ci.draw_rect(Rect2(face.position, Vector2(face.size.x, e)), WALL_EDGE)
		ci.draw_rect(Rect2(face.position + Vector2(0, face.size.y * 0.5 - s), Vector2(face.size.x, s)), WALL_FACE.darkened(0.08))
		ci.draw_rect(Rect2(face.position + Vector2(0, face.size.y - 2 * e), Vector2(face.size.x, 2 * e)), WALL_BASE)
		if not n_left:
			ci.draw_rect(Rect2(face.position, Vector2(e, face.size.y)), WALL_EDGE)
		if not n_right:
			ci.draw_rect(Rect2(face.position + Vector2(face.size.x - e, 0), Vector2(e, face.size.y)), WALL_EDGE)


static func door_tile(ci: CanvasItem, c: Vector2i, horizontal: bool) -> void:
	door_rect(ci, Rect2(Vector2(c) * T, Vector2(T, T)), horizontal)


## A doorway: wooden posts either side and a worn threshold between them.
static func door_rect(ci: CanvasItem, r: Rect2, horizontal: bool) -> void:
	var s := r.size.x / T
	var wood := Color("a4703f")
	var dark := Color("6e4526")
	if horizontal:
		ci.draw_rect(Rect2(r.position + Vector2(4, 12) * s, Vector2(24, 8) * s), Color("b98b58"))
		ci.draw_rect(Rect2(r.position + Vector2(4, 18) * s, Vector2(24, 2) * s), dark)
		for x in [0.0, 26.0]:
			ci.draw_rect(Rect2(r.position + Vector2(x, 0) * s, Vector2(6, 32) * s), dark)
			ci.draw_rect(Rect2(r.position + Vector2(x + 2, 0) * s, Vector2(2, 30) * s), wood)
	else:
		ci.draw_rect(Rect2(r.position + Vector2(12, 4) * s, Vector2(8, 24) * s), Color("b98b58"))
		for y in [0.0, 26.0]:
			ci.draw_rect(Rect2(r.position + Vector2(4, y) * s, Vector2(24, 6) * s), dark)
			ci.draw_rect(Rect2(r.position + Vector2(4, y + 2) * s, Vector2(24, 2) * s), wood)


## The health grade card that hangs by the front door.
static func grade_sign(ci: CanvasItem, door: Vector2i, outside: Vector2i, g: String) -> void:
	var out := Vector2(outside - door)
	var along := Vector2(absf(out.y), absf(out.x))
	var p := (Vector2(door) + Vector2(0.5, 0.5)) * T + out * 6.0 - along * 68.0
	var col: Color = {"A": Color("2f9a58"), "B": Color("d99a2b"), "C": Color("c8403a")}.get(g, Color.GRAY)
	rbox(ci, Rect2(p - Vector2(8, 9), Vector2(16, 18)), Color("fbfbf5"), col, 2, 2)
	var fnt := font()
	var w := fnt.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	ci.draw_string(fnt, p + Vector2(-w / 2.0, 5), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


# ------------------------------------------------------------------ furniture

## wall_dir: for things on walls, which side the room is on (0-3).
static func furniture(ci: CanvasItem, f, wall_dir: int = -1) -> void:
	var r: Rect2 = f.rect_px()
	furniture_in(ci, f.type, r, f.dir, f, wall_dir)
	if f.tier > 0:
		# Pro stations get a little gold star
		star(ci, r.position + Vector2(r.size.x - 6, 6), 4.0, Color("f2c14e"))


static func star(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (rad if i % 2 == 0 else rad * 0.45))
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), col.darkened(0.45), 1.0)


## A spill or tracked-in dirt on the floor, darker the worse it is.
static func spill(ci: CanvasItem, p: Vector2, d: float) -> void:
	var col := Color(0.30, 0.22, 0.13, 0.25 + d * 0.45)
	# chunky, pixel-ish blobs to sit with the tiles
	ci.draw_rect(Rect2(p - Vector2(6, 2) * (0.6 + d * 0.6), Vector2(12, 4) * (0.6 + d * 0.6)), col)
	ci.draw_rect(Rect2(p - Vector2(4, 4) * (0.6 + d * 0.6), Vector2(8, 8) * (0.6 + d * 0.6)), col)
	if d > 0.3:
		ci.draw_rect(Rect2(p + Vector2(6, 4), Vector2(4, 4) * (0.6 + d * 0.5)), col)


## A "For sale" board on a post, on land you can buy.
static func for_sale_sign(ci: CanvasItem, c: Vector2, price: String, s: float = 1.0) -> void:
	ci.draw_rect(Rect2(c + Vector2(-2, -2) * s, Vector2(4, 22) * s), Color("6e4a2b"))
	rbox(ci, Rect2(c + Vector2(-38, -30) * s, Vector2(76, 34) * s), Color("fbf3e0"), Color("8a5a30"), int(4 * s) + 1, maxi(1, int(2 * s)))
	if s < 0.5:
		ci.draw_rect(Rect2(c + Vector2(-28, -21) * s, Vector2(56, 6) * s), Color("c8403a"))
		ci.draw_rect(Rect2(c + Vector2(-18, -11) * s, Vector2(36, 5) * s), Color("3a2c25"))
		return
	var f := font()
	ci.draw_string(f, c + Vector2(-38, -15) * s, "FOR SALE", HORIZONTAL_ALIGNMENT_CENTER, 76 * s, int(12 * s), Color("c8403a"))
	ci.draw_string(f, c + Vector2(-38, -1) * s, price, HORIZONTAL_ALIGNMENT_CENTER, 76 * s, int(12 * s), Color("3a2c25"))


## Draws a piece of furniture of this type filling rect r. f may be null (for icons).
## Things with a front: the build tool turns them to face away from a wall.
const TURNS := ["sink", "jukebox", "drinks", "oven", "fridge", "freezer", "handsink", "host", "till", "ice", "booth"]


static func furniture_in(ci: CanvasItem, type: String, r: Rect2, dir: int, f = null, _wall_dir: int = -1) -> void:
	if Sprites.furniture(ci, type, r, dir):
		furniture_state(ci, type, r, f)
		return
	# no sprite for it (every piece in Data.FURNITURE has one; the tests check)
	rbox(ci, r.grow(-3), Color("8a7a6a"), Color("4a3f36"), 3, 2)


## What's going on at a piece of furniture, over its sprite: food cooking,
## plates waiting, a full bin, a broken machine smoking.
static func furniture_state(ci: CanvasItem, type: String, r: Rect2, f) -> void:
	if f == null:
		return
	var c := r.get_center()
	var along := Vector2.RIGHT if r.size.x >= r.size.y else Vector2.DOWN
	match type:
		"table", "long_table", "counter", "table_small", "staff_table":
			var n: int = mini(f.dirty_plates, 6)
			for i in n:
				var t := (i + 0.5) / n - 0.5
				plate(ci, c + along * t * (maxf(r.size.x, r.size.y) - 16.0) - Vector2(0, 3), 0.8, true)
		"grill", "griddle":
			if f.cooking != "":
				for k in [-1.0, 1.0]:
					var p: Vector2 = c + along * k * 12.0 - Vector2(0, 7)
					ellipse(ci, p, Vector2(5, 3), Color("6b3a1f") if type == "grill" else Color("e3b25a"))
					ci.draw_rect(Rect2(p + Vector2(-1, -9), Vector2(2, 4)), Color(1, 1, 1, 0.35))
		"fryer", "oven":
			if f.cooking != "":
				ci.draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color(1.0, 0.55, 0.15, 0.18))
				for o in [Vector2(-5, -10), Vector2(3, -12), Vector2(-1, -15)]:
					ci.draw_rect(Rect2(c + o, Vector2(2, 2)), Color(1, 1, 1, 0.5))
		"prep":
			if f.cooking != "":
				for o in [Vector2(-10, -5), Vector2(-7, -4), Vector2(-12, -3)]:
					ci.draw_rect(Rect2(c + o, Vector2(2, 2)), Color("7fb24a"))
		"drinks":
			if f.cooking != "":
				dish(ci, f.cooking, c + Vector2(0, 6), 0.7, false)
		"pass":
			for i in f.items.size():
				var p: Vector2 = pass_slot(r, i)
				var it: Dictionary = f.items[i]
				if it.get("takeout", false):
					bag(ci, p, 0.7)
				else:
					dish(ci, it["dish"], p, 0.75, true, float(it.get("q", -1.0)))
		"sink":
			var n: int = mini(f.dirty, 5)
			for i in n:
				plate(ci, c + Vector2(-4.0 + i * 2.2, -6.0 - i * 1.2), 0.7, true)
		"toilet":
			if f.grime > 0.15:
				for o in [Vector2(-4, 5), Vector2(3, 2), Vector2(5, 7)]:
					ci.draw_rect(Rect2(c + o, Vector2(3, 3) * (0.6 + f.grime)), Color(0.45, 0.36, 0.2, 0.3 + f.grime * 0.5))
		"bin":
			if f.fill >= 1.0:
				for o in [Vector2(-11, 8), Vector2(9, 10), Vector2(11, -2)]:
					ci.draw_rect(Rect2(c + o, Vector2(5, 4)), Color("3a3f45"))
		"stall":
			if f.group != null and is_instance_valid(f.group):
				car(ci, c + Vector2(-2, 10), 1 if r.size.x >= r.size.y else 0, [Color("6aa6d9"), Color("e75a4e"), Color("f2c14e"), Color("6cc3a0")][f.group.get_instance_id() % 4])
	if f.broken:
		ci.draw_rect(r.grow(-3), Color(0.1, 0.1, 0.12, 0.4))
		for o in [Vector2(-4, -6), Vector2(3, -10), Vector2(-1, -15)]:
			ci.draw_rect(Rect2(c + o - Vector2(3, 3), Vector2(6, 6)), Color(0.4, 0.4, 0.43, 0.7))


## Where the i-th item sits on a pass counter filling rect r: two rows, one
## each side of the heat lamp.
static func pass_slot(r: Rect2, i: int) -> Vector2:
	var per := maxi(1, Data.PASS_SLOTS / 2)
	var t: float = ((i % per) + 0.5) / float(per)
	var side := -7.0 if i < per else 7.0
	if r.size.x >= r.size.y:
		return Vector2(r.position.x + 5.0 + (r.size.x - 10.0) * t, r.get_center().y + side)
	return Vector2(r.get_center().x + side, r.position.y + 5.0 + (r.size.y - 10.0) * t)


## An axis-aligned rect centred on c, len_a long along `along` (a unit axis) and len_b across it.
static func axis_rect(c: Vector2, along: Vector2, len_a: float, len_b: float) -> Rect2:
	var sz := Vector2(absf(along.x) * len_a + absf(along.y) * len_b, absf(along.y) * len_a + absf(along.x) * len_b)
	return Rect2(c - sz / 2.0, sz)


## Half a disc on the `toward` side of c (for glows that stay in the room).
static func half_disc(ci: CanvasItem, c: Vector2, toward: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array([c])
	var a0 := toward.angle() - PI * 0.5
	for i in 13:
		pts.append(c + Vector2.from_angle(a0 + PI * i / 12.0) * radius)
	ci.draw_colored_polygon(pts, color)


## E, A and T in neon tubes: side by side, or stacked for a sign on a side wall.
static func neon_letters(ci: CanvasItem, box: Rect2, stacked: bool, col: Color, w: float) -> void:
	for i in 3:
		var cell: Rect2
		if stacked:
			cell = Rect2(box.position + Vector2(0, box.size.y / 3.0 * i), Vector2(box.size.x, box.size.y / 3.0))
		else:
			cell = Rect2(box.position + Vector2(box.size.x / 3.0 * i, 0), Vector2(box.size.x / 3.0, box.size.y))
		var g := cell.grow(-minf(cell.size.x, cell.size.y) * 0.2)
		var l := g.position.x
		var rt := g.end.x
		var tp := g.position.y
		var bt := g.end.y
		var mx := g.get_center().x
		var my := g.get_center().y
		var lines: Array = []
		match i:
			0:
				lines = [[Vector2(rt, tp), Vector2(l, tp), Vector2(l, bt), Vector2(rt, bt)], [Vector2(l, my), Vector2(lerpf(l, rt, 0.8), my)]]
			1:
				var cy := lerpf(my, bt, 0.2)
				lines = [[Vector2(l, bt), Vector2(mx, tp), Vector2(rt, bt)], [Vector2(lerpf(l, mx, 0.45), cy), Vector2(lerpf(rt, mx, 0.45), cy)]]
			2:
				lines = [[Vector2(l, tp), Vector2(rt, tp)], [Vector2(mx, tp), Vector2(mx, bt)]]
		for pl in lines:
			ci.draw_polyline(PackedVector2Array(pl), col, w, true)


## A smaller rect hugging the room side of a wall tile (for pictures and signs).
static func _on_wall_rect(r: Rect2, wall_dir: int, length: float, depth: float) -> Rect2:
	var d: Vector2i = Data.DIRS[wall_dir if wall_dir >= 0 else 2]
	var c := r.get_center() + Vector2(d) * (r.size.x * 0.5 - depth * 0.5 - 1.0)
	if d.y != 0:
		return Rect2(c - Vector2(length, depth) / 2.0, Vector2(length, depth))
	return Rect2(c - Vector2(depth, length) / 2.0, Vector2(depth, length))


## Dishes being eaten, each in front of its chair, and any money left behind.
## Everything stays well inside the tabletop so nothing looks about to fall off.
static func table_food(ci: CanvasItem, f) -> void:
	var c: Vector2 = f.center_px()
	var top: Rect2 = f.rect_px().grow(-10.0)
	if top.size.x < 1.0 or top.size.y < 1.0:
		top = Rect2(c, Vector2.ZERO)
	var foods: Array = f.food_on_table
	if not foods.is_empty():
		var slots: Array = []
		for ch in f.chairs:
			var toward: Vector2 = ch.center_px() - c
			slots.append(c + Vector2(toward.x * 0.7, toward.y * 0.7))
		if slots.is_empty():
			slots.append(c)
		for i in foods.size():
			var p: Vector2 = slots[i % slots.size()]
			# a second dish for the same person sits a little further in
			var extra := int(i / float(slots.size()))
			if extra > 0:
				p = p.lerp(c, 0.45) + Vector2(extra * 5.0 - 2.5, 0)
			p = Vector2(clampf(p.x, top.position.x, top.end.x), clampf(p.y, top.position.y, top.end.y))
			dish(ci, foods[i], p, 0.66, true, f.food_q[i] if i < f.food_q.size() else -1.0)
	if f.cash > 0.0:
		# the check folder with the money tucked in, on the side away from the chairs
		var away := Vector2.ZERO
		for ch in f.chairs:
			away -= ch.center_px() - c
		var mp := c + (away.normalized() * 8.0 if away.length() > 1.0 else Vector2.ZERO)
		mp = Vector2(clampf(mp.x, top.position.x, top.end.x), clampf(mp.y, top.position.y, top.end.y))
		rbox(ci, Rect2(mp - Vector2(5, 3.5), Vector2(10, 7)), Color("2b2622"), Color("171412"), 1, 1)
		ci.draw_rect(Rect2(mp - Vector2(3.5, 4.8), Vector2(7, 3)), Color("8fc27a"))
		ci.draw_circle(mp + Vector2(3.5, 2.5), 1.6, Color("e0b64a"))


# ------------------------------------------------------------------ bubbles and icons

## A speech bubble with its tail pointing down at `tip`. Returns the inside rect.
static func bubble(ci: CanvasItem, tip: Vector2, size: Vector2, fill: Color = Color("fbf8f1"), border: Color = Color("3a2c25")) -> Rect2:
	var r := Rect2(tip - Vector2(size.x / 2.0, size.y + 6), size)
	var tail := PackedVector2Array([tip + Vector2(-4, -7), tip + Vector2(4, -7), tip])
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-5.5, -6.5), tip + Vector2(5.5, -6.5), tip + Vector2(0, 1.5)]), border)
	rbox(ci, r, fill, border, 6, 2)
	ci.draw_colored_polygon(tail, fill)
	return r


## The supplier's delivery van, parked facing right, centred on p.
static func van(ci: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	Sprites.vehicle(ci, "van", p, true, 2.4 * s)


## A worn path across a floor tile: faint scuffs that get darker with use.
static func scuff(ci: CanvasItem, c: Vector2i, amount: float, v: float) -> void:
	var r := Rect2(Vector2(c) * T, Vector2(T, T))
	var a := clampf((amount - 0.2) * 0.35, 0.0, 0.22)
	ci.draw_rect(r.grow(-2), Color(0.25, 0.2, 0.15, a * 0.5))
	for k in 3:
		var p := r.position + Vector2(6 + fmod(v * 97.0 + k * 11.0, 20.0), 6 + fmod(v * 53.0 + k * 7.0, 20.0))
		ci.draw_line(p, p + Vector2(5, 1.5), Color(0.2, 0.16, 0.12, a), 1.2)


## A car (or a bus) from the side, driving right (dir 1) or left (-1).
static func car(ci: CanvasItem, p: Vector2, dir: int, col: Color, bus: bool = false) -> void:
	Sprites.vehicle(ci, "bus" if bus else Sprites.car_for(col), p, dir >= 0)


## The front of the diner: its name on a sign over the door (lit at night),
## a striped awning, an OPEN or CLOSED sign, and a "Now hiring" card.
static func storefront(ci: CanvasItem, door: Vector2i, outside: Vector2i, name_: String, open: bool, lit: float, hiring: bool, level: int = 0) -> void:
	var out := Vector2(outside - door)
	var along := Vector2(absf(out.y), absf(out.x))
	var dc := (Vector2(door) + Vector2(0.5, 0.5)) * T
	# the awning over the door
	var awn := axis_rect(dc + out * 12.0, along, 44, 12)
	ci.draw_rect(awn, Color("fbf3e0"))
	for i in 5:
		if i % 2 == 0:
			ci.draw_rect(axis_rect(dc + out * 12.0 + along * (-17.6 + i * 8.8), along, 8.8, 12), Color("c8403a"))
	# the name sign, above the awning along the wall
	var f := font()
	var text: String = name_ if name_ != "" else "DINER"
	var fs := 13
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > 150.0 and fs > 9:
		fs -= 1
		tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# on the wall beside the door, where nobody walks through it
	var sc := dc + out * 6.0 + along * (tw / 2.0 + 36.0)
	var sr := Rect2(sc - Vector2(tw / 2.0 + 9, 10), Vector2(tw + 18, 20))
	if absf(out.x) > 0.5:
		sr = Rect2(sc - Vector2(10, tw / 2.0 + 9), Vector2(20, tw + 18))
	if lit > 0.0:
		ci.draw_rect(sr.grow(5), Color(1.0, 0.45, 0.35, 0.18 * lit))
	rbox(ci, sr, Color("c8403a"), Color("7a2020"), 4, 2)
	ci.draw_rect(sr.grow(-3), Color(1, 0.95, 0.85, 0.25 + 0.4 * lit), false, 1.0)
	var ink := Color("fff4dc").lerp(Color("fffbe8"), lit)
	if absf(out.x) > 0.5:
		ci.draw_set_transform(sc, -PI / 2.0 if out.x < 0 else PI / 2.0, Vector2.ONE)
		ci.draw_string(f, Vector2(-tw / 2.0, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_string(f, Vector2(sc.x - tw / 2.0, sc.y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# OPEN / CLOSED beside the door, on the other side from the health grade
	var op := dc + out * 6.0 - along * 38.0
	rbox(ci, Rect2(op - Vector2(15, 6), Vector2(30, 12)), Color("1f1a24"), Color("15121a"), 3, 1)
	var oc := Color("7df29a") if open else Color("ff6f6f")
	ci.draw_string(f, op + Vector2(-13, 4), "OPEN" if open else "CLOSED", HORIZONTAL_ALIGNMENT_CENTER, 26, 8, oc)
	# a brass plaque by the door for each step up in reputation
	if level > 0:
		var pp := dc + out * 6.0 + along * (tw + 64.0)
		rbox(ci, Rect2(pp - Vector2(10, 8), Vector2(20, 16)), Color("d8a63a"), Color("8a6414"), 2, 1)
		for i in level:
			var sp := pp + Vector2((i - (level - 1) / 2.0) * 4.2, 0)
			ci.draw_circle(sp, 1.6, Color("fff4c2"))
	if hiring:
		var hp := dc + out * 6.0 - along * 98.0
		rbox(ci, Rect2(hp - Vector2(13, 7), Vector2(26, 14)), Color("fbfbf5"), Color("c8403a"), 2, 1)
		ci.draw_string(f, hp + Vector2(-12, -0.5), "NOW", HORIZONTAL_ALIGNMENT_CENTER, 24, 6, Color("c8403a"))
		ci.draw_string(f, hp + Vector2(-12, 5.5), "HIRING", HORIZONTAL_ALIGNMENT_CENTER, 24, 6, Color("3a2c25"))


static func wrench(ci: CanvasItem, p: Vector2, s: float, color: Color) -> void:
	ci.draw_line(p + Vector2(-4, 4) * s, p + Vector2(2, -2) * s, color, 2.4 * s)
	ci.draw_arc(p + Vector2(3.5, -3.5) * s, 3.0 * s, PI * 0.9, PI * 2.6, 10, color, 2.0 * s)
