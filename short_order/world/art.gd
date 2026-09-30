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
static func person(ci: CanvasItem, p: Vector2, facing: Vector2, shirt: Color, skin: Color, hair: Color,
		step: float, staff: bool, hat: bool, sitting: bool = false, look: String = "", s: float = 1.0) -> void:
	var f := facing.normalized() if facing.length() > 0.01 else Vector2.DOWN
	var side := Vector2(-f.y, f.x)
	ellipse(ci, p + Vector2(0, 8) * s, Vector2(9, 4) * s, Color(0, 0, 0, 0.22))
	if look == "backpack":
		rbox(ci, Rect2(p - f * 8.0 * s - Vector2(5, 4) * s, Vector2(10, 8) * s), shirt.darkened(0.45), shirt.darkened(0.6), 3, 1)
	elif look == "driver":
		# a big insulated delivery bag on their back
		rbox(ci, Rect2(p - f * 9.0 * s - Vector2(7, 6) * s, Vector2(14, 12) * s), Color("e2703a"), Color("a84e22"), 3, 1)
		ci.draw_rect(Rect2(p - f * 9.0 * s - Vector2(5, 1) * s, Vector2(10, 2) * s), Color("fbe3cf"))
	var swing := 0.0 if sitting else sin(step) * 3.0
	ci.draw_circle(p + (side * 8.5 + f * (2.0 + swing)) * s, 3.0 * s, skin)
	ci.draw_circle(p + (-side * 8.5 + f * (2.0 - swing)) * s, 3.0 * s, skin)
	var body := Color("f4f4f0") if look == "coat" else shirt
	ellipse(ci, p, Vector2(10, 7) * s, body.darkened(0.25), side.angle())
	ellipse(ci, p - Vector2(0, 1) * s, Vector2(9, 6) * s, body, side.angle())
	if staff:
		ellipse(ci, p + f * 3.0 * s, Vector2(5.5, 3.5) * s, Color("f4f1ea"), side.angle())
	if look == "coat":
		# clipboard held in front
		var cb := p + f * 9.0 * s
		rbox(ci, Rect2(cb - Vector2(4, 5) * s, Vector2(8, 10) * s), Color("8b5a2b"), Color("5e3b1a"), 1, 1)
		ci.draw_rect(Rect2(cb - Vector2(3, 3) * s, Vector2(6, 7) * s), Color("fbfbf5"))
	elif look == "camera":
		var cm := p + f * 8.0 * s
		rbox(ci, Rect2(cm - Vector2(4, 3) * s, Vector2(8, 6) * s), Color("2b2b30"), Color("15151a"), 1, 1)
		ci.draw_circle(cm, 1.8 * s, Color("7fb4d6"))
	elif look == "beret":
		var nb := p + f * 9.0 * s + side * 4.0 * s
		ci.draw_rect(Rect2(nb - Vector2(3, 4) * s, Vector2(6, 8) * s), Color("fbfbf5"))
		ci.draw_line(nb - Vector2(2, 1) * s, nb + Vector2(2, -1) * s, Color("555555"), 1.0)
	var hp := p + (f * 1.5 - Vector2(0, 2)) * s
	ci.draw_circle(hp, 6.3 * s, skin)
	ci.draw_circle(hp - f * 1.9 * s, 5.7 * s, hair)
	if hat:
		ci.draw_circle(hp - f * 0.8 * s, 5.4 * s, Color("fbfbf8"))
		ci.draw_arc(hp - f * 0.8 * s, 5.4 * s, 0, TAU, 16, Color("d6d3cc"), 1.2, true)
	match look:
		"cap":
			ci.draw_circle(hp - f * 1.2 * s, 5.8 * s, Color("2f6db0"))
			ellipse(ci, hp + f * 4.0 * s, Vector2(3, 5.2) * s, Color("24558a"), f.angle())
			ci.draw_circle(hp - f * 1.2 * s, 2.0 * s, Color("f2f2f2"))
		"beret":
			ellipse(ci, hp - f * 1.4 * s + side * 1.2 * s, Vector2(6.8, 6.0) * s, Color("30303a"), f.angle())
			ci.draw_circle(hp - f * 1.4 * s + side * 1.2 * s, 1.1 * s, Color("15151a"))
		"shades":
			ci.draw_line(hp + f * 3.5 * s - side * 4.5 * s, hp + f * 3.5 * s + side * 4.5 * s, Color("111114"), 2.6 * s)
		"driver":
			ci.draw_circle(hp - f * 0.6 * s, 6.4 * s, Color("e2703a"))
			ci.draw_arc(hp - f * 0.6 * s, 6.4 * s, 0, TAU, 16, Color("a84e22"), 1.0 * s, true)
			ellipse(ci, hp + f * 3.2 * s, Vector2(2.4, 5.0) * s, Color("2b2b30"), f.angle())


## A head-and-shoulders picture for the interface, filling rect r.
static func portrait(ci: CanvasItem, r: Rect2, skin: Color, hair: Color, shirt: Color, staff: bool, look: String = "") -> void:
	var c := r.get_center()
	var u := r.size.y / 48.0
	ci.draw_circle(c, r.size.y * 0.5, Color(1, 1, 1, 0.07))
	# shoulders
	ellipse(ci, c + Vector2(0, 20) * u, Vector2(17, 11) * u, shirt.darkened(0.2))
	ellipse(ci, c + Vector2(0, 21) * u, Vector2(15.5, 10) * u, shirt)
	if staff:
		var col := PackedVector2Array([c + Vector2(-6, 11) * u, c + Vector2(6, 11) * u, c + Vector2(0, 19) * u])
		ci.draw_colored_polygon(col, Color("f4f1ea"))
	ci.draw_rect(Rect2(c + Vector2(-3, 5) * u, Vector2(6, 7) * u), skin.darkened(0.08))
	# head
	ci.draw_circle(c + Vector2(0, -2) * u, 10.5 * u, skin)
	# hair: a cap over the top of the head
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(c + Vector2(0, -3) * u + Vector2(cos(a) * 11.2, sin(a) * 10.5) * u)
	pts.append(c + Vector2(9, -4) * u)
	pts.append(c + Vector2(-9, -4) * u)
	ci.draw_colored_polygon(pts, hair)
	# face
	ci.draw_circle(c + Vector2(-3.8, 0) * u, 1.3 * u, Color("2a1d17"))
	ci.draw_circle(c + Vector2(3.8, 0) * u, 1.3 * u, Color("2a1d17"))
	ci.draw_arc(c + Vector2(0, 3) * u, 3.4 * u, 0.25, PI - 0.25, 10, Color("2a1d17"), maxf(1.0, 1.2 * u), true)
	if staff:
		# a little paper diner cap
		var cap := PackedVector2Array([c + Vector2(-9, -9) * u, c + Vector2(9, -9) * u, c + Vector2(6, -15) * u, c + Vector2(-6, -15) * u])
		ci.draw_colored_polygon(cap, Color("fbfbf8"))
		ci.draw_rect(Rect2(c + Vector2(-9, -10) * u, Vector2(18, 2) * u), Color("c8403a"))
	match look:
		"cap":
			ellipse(ci, c + Vector2(0, -10) * u, Vector2(11, 5) * u, Color("2f6db0"))
			ellipse(ci, c + Vector2(6, -7) * u, Vector2(7, 2.5) * u, Color("24558a"))
		"beret":
			ellipse(ci, c + Vector2(-2, -11) * u, Vector2(12, 4.5) * u, Color("30303a"), -0.15)
		"coat":
			ci.draw_rect(Rect2(c + Vector2(-2, 12) * u, Vector2(4, 12) * u), Color("dcdcd6"))
		"camera":
			rbox(ci, Rect2(c + Vector2(-5, 14) * u, Vector2(10, 7) * u), Color("2b2b30"), Color("15151a"), 1, 1)
			ci.draw_circle(c + Vector2(0, 17.5) * u, 2.2 * u, Color("7fb4d6"))
		"shades":
			rbox(ci, Rect2(c + Vector2(-8, -2.5) * u, Vector2(7, 4) * u), Color("111114"), Color("111114"), 2, 0)
			rbox(ci, Rect2(c + Vector2(1, -2.5) * u, Vector2(7, 4) * u), Color("111114"), Color("111114"), 2, 0)


# ------------------------------------------------------------------ food

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


static func bag(ci: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	rbox(ci, Rect2(p - Vector2(5, 6) * s, Vector2(10, 12) * s), Color("c9a06a"), Color("9c7644"), 2, 1)
	ci.draw_rect(Rect2(p + Vector2(-5, -6) * s, Vector2(10, 2.5) * s), Color("b38a55"))
	ci.draw_circle(p + Vector2(0, -2.5) * s, 1.6 * s, Color("c8403a"))


static func dish(ci: CanvasItem, d: String, p: Vector2, s: float = 1.0, on_plate: bool = true) -> void:
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


static func wall_rect(ci: CanvasItem, r: Rect2, n_up: bool, n_down: bool, n_left: bool, n_right: bool) -> void:
	var s := r.size.x / T
	_wall_shape(ci, r, 7.0 * s, Color("5b4d44"), n_up, n_down, n_left, n_right)
	_wall_shape(ci, r, 9.5 * s, Color("7d6c60"), n_up, n_down, n_left, n_right)


static func _wall_shape(ci: CanvasItem, r: Rect2, inset: float, color: Color, n_up: bool, n_down: bool, n_left: bool, n_right: bool) -> void:
	var inner := Rect2(r.position + Vector2(inset, inset), r.size - Vector2(inset, inset) * 2.0)
	ci.draw_rect(inner, color)
	if n_up:
		ci.draw_rect(Rect2(Vector2(inner.position.x, r.position.y), Vector2(inner.size.x, inset)), color)
	if n_down:
		ci.draw_rect(Rect2(Vector2(inner.position.x, inner.end.y), Vector2(inner.size.x, inset)), color)
	if n_left:
		ci.draw_rect(Rect2(Vector2(r.position.x, inner.position.y), Vector2(inset, inner.size.y)), color)
	if n_right:
		ci.draw_rect(Rect2(Vector2(inner.end.x, inner.position.y), Vector2(inset, inner.size.y)), color)


static func door_tile(ci: CanvasItem, c: Vector2i, horizontal: bool) -> void:
	door_rect(ci, Rect2(Vector2(c) * T, Vector2(T, T)), horizontal)


static func door_rect(ci: CanvasItem, r: Rect2, horizontal: bool) -> void:
	var s := r.size.x / T
	if horizontal:
		ci.draw_rect(Rect2(r.position + Vector2(0, 12) * s, Vector2(T, 8) * s), Color("8b5a2b"))
		ci.draw_rect(Rect2(r.position + Vector2(2, 14) * s, Vector2(T - 4, 4) * s), Color("b07a45"))
	else:
		ci.draw_rect(Rect2(r.position + Vector2(12, 0) * s, Vector2(8, T) * s), Color("8b5a2b"))
		ci.draw_rect(Rect2(r.position + Vector2(14, 2) * s, Vector2(4, T - 4) * s), Color("b07a45"))


## The health grade card that hangs by the front door.
static func grade_sign(ci: CanvasItem, door: Vector2i, outside: Vector2i, g: String) -> void:
	var out := Vector2(outside - door)
	var side := Vector2(-out.y, out.x)
	var p := (Vector2(door) + Vector2(0.5, 0.5)) * T + out * 14.0 + side * 24.0
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
		# Pro stations get a gold trim and a little star
		ci.draw_rect(r.grow(-2), Color("f2c14e"), false, 1.5)
		ci.draw_circle(r.position + Vector2(r.size.x - 5, 5), 3.2, Color("f2c14e"))
		ci.draw_circle(r.position + Vector2(r.size.x - 5, 5), 1.4, Color("fff4c2"))


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
static func furniture_in(ci: CanvasItem, type: String, r: Rect2, dir: int, f = null, wall_dir: int = -1) -> void:
	var s := r.size.y / T if r.size.x >= r.size.y else r.size.x / T
	var inner := r.grow(-3 * s)
	var cooking: String = f.cooking if f != null else ""
	match type:
		"table":
			rbox(ci, inner, Color("b07a4a"), Color("7a5230"), 5)
			rbox(ci, inner.grow(-4 * s), Color("c08a58"), Color("c08a58"), 4, 0)
			if f != null and f.dirty_plates > 0:
				var n: int = f.dirty_plates
				for i in n:
					var t := (i + 0.5) / n
					var p := inner.position + Vector2(inner.size.x * t, inner.size.y * 0.5) if f.size.x >= f.size.y else inner.position + Vector2(inner.size.x * 0.5, inner.size.y * t)
					plate(ci, p, 0.8, true)
		"chair":
			var seat := r.grow(-8 * s)
			rbox(ci, seat, Color("9a6a3f"), Color("6e4a2b"), 3)
			var b: Vector2i = -Data.DIRS[dir]
			var bar: Rect2
			if b.x != 0:
				bar = Rect2(Vector2(r.position.x + (r.size.x - 7 * s if b.x > 0 else 4 * s), r.position.y + 6 * s), Vector2(3, r.size.y / s - 12) * s)
			else:
				bar = Rect2(Vector2(r.position.x + 6 * s, r.position.y + (r.size.y - 7 * s if b.y > 0 else 4 * s)), Vector2(r.size.x / s - 12, 3) * s)
			ci.draw_rect(bar, Color("6e4a2b"))
		"grill":
			rbox(ci, inner, Color("3a3d42"), Color("25272b"), 4)
			var g := inner.grow(-5 * s)
			ci.draw_rect(g, Color("2a2c30"))
			if g.size.x >= g.size.y:
				var steps := int(g.size.x / (5 * s))
				for i in steps:
					ci.draw_line(Vector2(g.position.x + (i * 5 + 2) * s, g.position.y), Vector2(g.position.x + (i * 5 + 2) * s, g.end.y), Color("55585e"), 1.0)
			else:
				var steps := int(g.size.y / (5 * s))
				for i in steps:
					ci.draw_line(Vector2(g.position.x, g.position.y + (i * 5 + 2) * s), Vector2(g.end.x, g.position.y + (i * 5 + 2) * s), Color("55585e"), 1.0)
			if cooking != "":
				ci.draw_rect(g, Color(1, 0.45, 0.1, 0.25))
				var along := Vector2(6, 0) if g.size.x >= g.size.y else Vector2(0, 6)
				ci.draw_circle(g.get_center() - along, 4.5, Color("6b3a1f"))
				ci.draw_circle(g.get_center() + along, 4.5, Color("6b3a1f"))
		"fryer":
			rbox(ci, inner, Color("8d959d"), Color("5f666d"), 4)
			ci.draw_rect(Rect2(inner.position + Vector2(4, 4) * s, Vector2(inner.size.x - 8 * s, inner.size.y / 2.0 - 5 * s)), Color("d9b44a"))
			ci.draw_rect(Rect2(inner.position + Vector2(4 * s, inner.size.y / 2.0 + 1 * s), Vector2(inner.size.x - 8 * s, inner.size.y / 2.0 - 5 * s)), Color("d9b44a"))
			if cooking != "":
				for o in [Vector2(-4, -5), Vector2(3, -3), Vector2(-2, 5), Vector2(4, 6)]:
					ci.draw_circle(inner.get_center() + o * s, 1.3 * s, Color("fff3c0"))
		"griddle":
			rbox(ci, inner, Color("9aa3ab"), Color("6b737a"), 4)
			ci.draw_rect(inner.grow(-5 * s), Color("6f777f"))
			if cooking != "":
				var along2 := Vector2(7, 0) if inner.size.x >= inner.size.y else Vector2(0, 7)
				ci.draw_circle(inner.get_center() - along2, 5, Color("e3b25a"))
				ci.draw_circle(inner.get_center() + along2, 5, Color("e3b25a"))
		"drinks":
			rbox(ci, inner, Color("c8403a"), Color("8c2a25"), 4)
			rbox(ci, Rect2(inner.position + Vector2(3, 3) * s, Vector2(inner.size.x - 6 * s, 9 * s)), Color("f4efe6"), Color("d8d0c2"), 2, 1)
			ci.draw_circle(inner.position + Vector2(7, 7.5) * s, 2 * s, Color("f2a7c3"))
			ci.draw_circle(inner.position + Vector2(13, 7.5) * s, 2 * s, Color("6b4226"))
			ci.draw_circle(inner.position + Vector2(19, 7.5) * s, 2 * s, Color("f7e27a"))
			if cooking != "":
				dish(ci, cooking, inner.get_center() + Vector2(0, 5) * s, 0.8 * s, false)
		"pass":
			rbox(ci, inner, Color("c7ccd1"), Color("9aa1a8"), 3)
			var horiz := inner.size.x >= inner.size.y
			var lamp: Rect2
			if horiz:
				lamp = Rect2(Vector2(inner.position.x + 3 * s, inner.position.y + 2 * s), Vector2(inner.size.x - 6 * s, 2 * s))
			else:
				lamp = Rect2(Vector2(inner.position.x + 2 * s, inner.position.y + 3 * s), Vector2(2 * s, inner.size.y - 6 * s))
			ci.draw_rect(lamp, Color("f0b35a"))
			if f != null:
				for i in f.items.size():
					var p: Vector2 = pass_slot(inner, i)
					var it: Dictionary = f.items[i]
					if it.get("takeout", false):
						bag(ci, p, 0.7)
					else:
						dish(ci, it["dish"], p, 0.75)
		"oven":
			rbox(ci, inner, Color("4a4f57"), Color("2c3036"), 4)
			var door := Rect2(inner.position + Vector2(4, inner.size.y / s * 0.35) * s, Vector2(inner.size.x - 8 * s, inner.size.y * 0.5))
			rbox(ci, door, Color("2a1f1a") if cooking == "" else Color("7a3a18"), Color("8d949c"), 3, 1)
			if cooking != "":
				ci.draw_rect(door.grow(-3 * s), Color(1.0, 0.55, 0.15, 0.55))
			for i in 3:
				ci.draw_circle(inner.position + Vector2(7 + i * 6, 5) * s, 1.6 * s, Color("c9ccd1"))
		"fridge":
			rbox(ci, inner, Color("e8eef2"), Color("aab4bd"), 4)
			ci.draw_line(inner.position + Vector2(inner.size.x - 6 * s, 6 * s), inner.position + Vector2(inner.size.x - 6 * s, inner.size.y - 6 * s), Color("8d99a3"), 2.0)
			ci.draw_line(inner.position + Vector2(4 * s, inner.size.y * 0.4), inner.position + Vector2(inner.size.x - 9 * s, inner.size.y * 0.4), Color("cfd8de"), 1.0)
		"toilet":
			var face_t: Vector2 = Vector2(Data.DIRS[dir])
			var c_t := r.get_center()
			var tank := Rect2(c_t - face_t * 9.0 * s - Vector2(7, 7) * s, Vector2(14, 14) * s)
			if face_t.x != 0:
				tank = Rect2(c_t - face_t * 9.0 * s - Vector2(4, 8) * s, Vector2(8, 16) * s)
			else:
				tank = Rect2(c_t - face_t * 9.0 * s - Vector2(8, 4) * s, Vector2(16, 8) * s)
			rbox(ci, tank, Color("f4f7f9"), Color("aab8c2"), 3, 1)
			ellipse(ci, c_t + face_t * 2.0 * s, Vector2(7.5, 8.5) * s if face_t.y != 0 else Vector2(8.5, 7.5) * s, Color("aab8c2"))
			ellipse(ci, c_t + face_t * 2.0 * s, Vector2(6.5, 7.5) * s if face_t.y != 0 else Vector2(7.5, 6.5) * s, Color("f7fafc"))
			ellipse(ci, c_t + face_t * 3.0 * s, Vector2(3.5, 4.2) * s if face_t.y != 0 else Vector2(4.2, 3.5) * s, Color("bcd9ea"))
			if f != null and f.grime > 0.15:
				for o in [Vector2(-4, 5), Vector2(3, -4), Vector2(5, 4)]:
					ci.draw_circle(c_t + o * s, (1.2 + f.grime * 2.5) * s, Color(0.45, 0.36, 0.2, 0.25 + f.grime * 0.5))
		"handsink":
			rbox(ci, inner, Color("e8eef2"), Color("9aa8b3"), 4)
			ellipse(ci, inner.get_center() + Vector2(0, 2) * s, Vector2(7, 5.5) * s, Color("7fb4d6"))
			ci.draw_line(inner.get_center() + Vector2(0, -7) * s, inner.get_center() + Vector2(0, -2) * s, Color("7d868f"), 2.0 * s)
			rbox(ci, Rect2(inner.position + Vector2(inner.size.x - 9 * s, 3 * s), Vector2(6, 8) * s), Color("f2c14e"), Color("b8912e"), 1, 1)
		"bin":
			var cb := r.get_center()
			ci.draw_circle(cb + Vector2(1, 2) * s, 10 * s, Color(0, 0, 0, 0.18))
			ci.draw_circle(cb, 10 * s, Color("5b6570"))
			ci.draw_circle(cb, 8.2 * s, Color("3a4149"))
			var fl: float = f.fill if f != null else 0.3
			if fl > 0.05:
				ci.draw_circle(cb, minf(8.0, 3.0 + fl * 5.0) * s, Color("2a2a2e"))
				ci.draw_circle(cb + Vector2(-2, -2) * s, minf(4.0, 1.5 + fl * 2.5) * s, Color("3f3f45"))
			if fl >= 1.0:
				for o in [Vector2(-9, 7), Vector2(8, 8), Vector2(10, -6)]:
					ci.draw_circle(cb + o * s, 2.2 * s, Color("8a6a3a"))
		"trap":
			var ct := r.get_center()
			rbox(ci, Rect2(ct - Vector2(7, 4.5) * s, Vector2(14, 9) * s), Color("c79a5b"), Color("8a6533"), 1, 1)
			ci.draw_line(ct + Vector2(-5, -2) * s, ct + Vector2(5, -2) * s, Color("b8bec4"), 1.2 * s)
			ci.draw_arc(ct + Vector2(0, 1) * s, 3.5 * s, PI, TAU, 8, Color("b8bec4"), 1.0 * s)
			ci.draw_circle(ct + Vector2(3, 2) * s, 1.4 * s, Color("f2c14e"))
		"dumpster":
			rbox(ci, inner, Color("2f6a4a"), Color("1f4a33"), 3)
			var lid := Rect2(inner.position + Vector2(2, 2) * s, Vector2(inner.size.x - 4 * s, inner.size.y * 0.42))
			rbox(ci, lid, Color("3f8a60"), Color("2a5e42"), 2, 1)
			ci.draw_line(Vector2(inner.get_center().x, lid.position.y), Vector2(inner.get_center().x, lid.end.y), Color("2a5e42"), 1.5)
		"freezer":
			rbox(ci, inner, Color("d7e6f2"), Color("8fa8bd"), 4)
			ci.draw_rect(Rect2(inner.position + Vector2(3, 3) * s, Vector2(inner.size.x - 6 * s, inner.size.y * 0.3)), Color("bcd6ea"))
			ci.draw_line(inner.position + Vector2(inner.size.x - 6 * s, inner.size.y * 0.45), inner.position + Vector2(inner.size.x - 6 * s, inner.size.y - 5 * s), Color("7f97ab"), 2.0)
			var fc := inner.position + Vector2(inner.size.x * 0.42, inner.size.y * 0.66)
			for a in 3:
				var d := Vector2.RIGHT.rotated(a * PI / 3.0) * 4.0 * s
				ci.draw_line(fc - d, fc + d, Color("5a8fc0"), 1.1 * s)
		"prep":
			rbox(ci, inner, Color("c7ccd1"), Color("9aa1a8"), 3)
			var horiz_p := inner.size.x >= inner.size.y
			var board := Rect2(inner.position + Vector2(4, 4) * s, Vector2(inner.size.x * 0.45, inner.size.y - 8 * s)) if horiz_p \
				else Rect2(inner.position + Vector2(4, 4) * s, Vector2(inner.size.x - 8 * s, inner.size.y * 0.45))
			rbox(ci, board, Color("d9b07a"), Color("a97f4a"), 2, 1)
			ci.draw_line(board.get_center() + Vector2(-5, 3) * s, board.get_center() + Vector2(5, -3) * s, Color("e8ecef"), 1.6 * s)
			ci.draw_line(board.get_center() + Vector2(3, -1.8) * s, board.get_center() + Vector2(6, -3.6) * s, Color("3a2c25"), 2.0 * s)
			if f != null and f.cooking != "":
				for o in [Vector2(-4, 4), Vector2(-2, 5), Vector2(-5, 2)]:
					ci.draw_circle(board.get_center() + o * s, 1.0 * s, Color("7fb24a"))
			# prepped portions waiting in little tubs
			var ready := 0
			if f != null:
				for d in Stock.prepped:
					ready += Stock.prepped[d]
			var tubs := mini(ready, 6)
			for i in tubs:
				var tp: Vector2
				if horiz_p:
					tp = inner.position + Vector2(inner.size.x * 0.55 + (i % 3) * 7 * s + 4 * s, inner.size.y * (0.33 if i < 3 else 0.7))
				else:
					tp = inner.position + Vector2(inner.size.x * (0.33 if i < 3 else 0.7), inner.size.y * 0.55 + (i % 3) * 7 * s + 4 * s)
				rbox(ci, Rect2(tp - Vector2(3, 2.5) * s, Vector2(6, 5) * s), Color("f4f6f8"), Color("aab4bd"), 1, 1)
		"sink":
			rbox(ci, inner, Color("b8c0c8"), Color("7d868f"), 4)
			rbox(ci, inner.grow(-5 * s), Color("7fb4d6"), Color("5f93b5"), 6, 1)
			if f != null:
				var n := mini(f.dirty, 5)
				for i in n:
					plate(ci, inner.position + Vector2(8 + i * 2.5, inner.size.y / s - 8 - i * 2.0) * s, 0.7, true)
		"plant":
			var c := r.get_center()
			ci.draw_circle(c, 9 * s, Color("b5653a"))
			ci.draw_circle(c, 7 * s, Color("5a3a22"))
			for o in [Vector2(-4, -3), Vector2(4, -4), Vector2(0, 4), Vector2(-5, 4), Vector2(5, 3), Vector2(0, -6)]:
				ci.draw_circle(c + o * s, 4.5 * s, Color("4f9a45"))
			ci.draw_circle(c + Vector2(1, -1) * s, 3.5 * s, Color("68b152"))
		"lamp":
			var c := r.get_center()
			ci.draw_circle(c + Vector2(1, 2) * s, 10 * s, Color(0, 0, 0, 0.18))
			ci.draw_circle(c, 10 * s, Color("c9b27a"))
			ci.draw_circle(c, 8.5 * s, Color("f3e3b5"))
			ci.draw_circle(c, 3.2 * s, Color("fff4c2"))
			ci.draw_arc(c, 6 * s, 0, TAU, 20, Color("e6d09a"), 1.0 * s, true)
		"jukebox":
			rbox(ci, inner, Color("8c2f2a"), Color("5e1d19"), 8)
			var top := Rect2(inner.position + Vector2(3, 3) * s, Vector2(inner.size.x - 6 * s, inner.size.y * 0.55))
			var cols := [Color("f2c14e"), Color("ef8a3a"), Color("d9463b"), Color("5aa9d6")]
			for i in cols.size():
				rbox(ci, top.grow(-i * 2.2 * s), cols[i], cols[i], int(8 - i * 1.5), 0)
			rbox(ci, top.grow(-9 * s), Color("2b1d17"), Color("2b1d17"), 3, 0)
			for i in 3:
				ci.draw_line(Vector2(inner.position.x + 6 * s, inner.end.y - (4 + i * 3) * s), Vector2(inner.end.x - 6 * s, inner.end.y - (4 + i * 3) * s), Color("d8d0c2"), 1.0)
		"sofa":
			var face: Vector2i = Data.DIRS[dir]
			rbox(ci, inner, Color("3f8f86"), Color("2b6a63"), 6)
			var back: Rect2
			var cushions: Array = []
			if face.y != 0:
				back = Rect2(Vector2(inner.position.x, inner.position.y if face.y > 0 else inner.end.y - 7 * s), Vector2(inner.size.x, 7 * s))
				var y0 := inner.position.y + (8 * s if face.y > 0 else 2 * s)
				var half := (inner.size.x - 12 * s) / 2.0
				cushions = [Rect2(Vector2(inner.position.x + 5 * s, y0), Vector2(half - 1 * s, inner.size.y - 11 * s)),
					Rect2(Vector2(inner.position.x + 7 * s + half, y0), Vector2(half - 1 * s, inner.size.y - 11 * s))]
			else:
				back = Rect2(Vector2(inner.position.x if face.x > 0 else inner.end.x - 7 * s, inner.position.y), Vector2(7 * s, inner.size.y))
				var x0 := inner.position.x + (8 * s if face.x > 0 else 2 * s)
				var half2 := (inner.size.y - 12 * s) / 2.0
				cushions = [Rect2(Vector2(x0, inner.position.y + 5 * s), Vector2(inner.size.x - 11 * s, half2 - 1 * s)),
					Rect2(Vector2(x0, inner.position.y + 7 * s + half2), Vector2(inner.size.x - 11 * s, half2 - 1 * s))]
			rbox(ci, back, Color("2f7a72"), Color("2b6a63"), 4, 1)
			for cr in cushions:
				rbox(ci, cr, Color("52a89e"), Color("3f8f86"), 4, 1)
		"wall_art":
			var fr := _on_wall_rect(r, wall_dir, 20 * s, 7 * s)
			rbox(ci, fr, Color("d8a63a"), Color("9c7424"), 2, 2)
			var pic := fr.grow(-2.5 * s)
			ci.draw_rect(pic, Color("8fc3e6"))
			var hill := PackedVector2Array([pic.position + Vector2(0, pic.size.y), pic.position + Vector2(pic.size.x * 0.35, pic.size.y * 0.35), pic.position + Vector2(pic.size.x * 0.7, pic.size.y * 0.7), pic.end])
			ci.draw_colored_polygon(hill, Color("5c9a4a"))
			ci.draw_circle(pic.position + Vector2(pic.size.x * 0.78, pic.size.y * 0.3), 1.6 * s, Color("f7e27a"))
		"neon":
			var nr := _on_wall_rect(r, wall_dir, 24 * s, 9 * s)
			ci.draw_circle(nr.get_center(), 15 * s, Color(1.0, 0.35, 0.6, 0.12))
			rbox(ci, nr, Color("1f1a24"), Color("15121a"), 3, 1)
			var tube := nr.grow(-2.5 * s)
			ci.draw_rect(tube, Color("ff5fa2"), false, 1.6 * s)
			var mid := tube.get_center()
			ci.draw_polyline(PackedVector2Array([mid + Vector2(-6, 1) * s, mid + Vector2(-3, -2) * s, mid + Vector2(0, 1) * s, mid + Vector2(3, -2) * s, mid + Vector2(6, 1) * s]), Color("6ff2ff"), 1.5 * s)
		"takeout":
			var inside: Vector2i = Data.DIRS[wall_dir if wall_dir >= 0 else 0]
			var sill := r.grow(-4 * s)
			rbox(ci, sill, Color("d9d4ca"), Color("a8a196"), 2, 2)
			var awn: Rect2
			if inside.y != 0:
				awn = Rect2(Vector2(r.position.x - 3 * s, r.position.y + (r.size.y - 5 * s if inside.y < 0 else -4 * s)), Vector2(r.size.x + 6 * s, 9 * s))
			else:
				awn = Rect2(Vector2(r.position.x + (r.size.x - 5 * s if inside.x < 0 else -4 * s), r.position.y - 3 * s), Vector2(9 * s, r.size.y + 6 * s))
			ci.draw_rect(awn, Color("f4efe6"))
			var stripes := 5
			for i in stripes:
				if i % 2 == 0:
					var st: Rect2
					if inside.y != 0:
						st = Rect2(Vector2(awn.position.x + awn.size.x * i / stripes, awn.position.y), Vector2(awn.size.x / stripes, awn.size.y))
					else:
						st = Rect2(Vector2(awn.position.x, awn.position.y + awn.size.y * i / stripes), Vector2(awn.size.x, awn.size.y / stripes))
					ci.draw_rect(st, Color("c8403a"))
			ci.draw_circle(sill.get_center(), 2.4 * s, Color("d8a63a"))
	if f != null and f.broken:
		ci.draw_rect(inner, Color(0.1, 0.1, 0.12, 0.45))
		for o in [Vector2(-4, -6), Vector2(3, -9), Vector2(-1, -13)]:
			ci.draw_circle(r.get_center() + o * s, (3.5 + absf(o.y) * 0.15) * s, Color(0.35, 0.35, 0.38, 0.7))


## Where the i-th item sits on a pass counter whose inside rect is `inner`.
static func pass_slot(inner: Rect2, i: int) -> Vector2:
	var t: float = (i + 0.5) / float(Data.PASS_SLOTS)
	if inner.size.x >= inner.size.y:
		return inner.position + Vector2(inner.size.x * t, inner.size.y * 0.55)
	return inner.position + Vector2(inner.size.x * 0.55, inner.size.y * t)


## A smaller rect hugging the room side of a wall tile (for pictures and signs).
static func _on_wall_rect(r: Rect2, wall_dir: int, length: float, depth: float) -> Rect2:
	var d: Vector2i = Data.DIRS[wall_dir if wall_dir >= 0 else 2]
	var c := r.get_center() + Vector2(d) * (r.size.x * 0.5 - depth * 0.5 - 1.0)
	if d.y != 0:
		return Rect2(c - Vector2(length, depth) / 2.0, Vector2(length, depth))
	return Rect2(c - Vector2(depth, length) / 2.0, Vector2(depth, length))


static func table_food(ci: CanvasItem, f) -> void:
	# dishes being eaten, placed toward each chair
	var foods: Array = f.food_on_table
	if foods.is_empty():
		return
	var c: Vector2 = f.center_px()
	var slots: Array = []
	for ch in f.chairs:
		slots.append(c.lerp(ch.center_px(), 0.42))
	if slots.is_empty():
		slots.append(c)
	for i in foods.size():
		var p: Vector2 = slots[i % slots.size()] + Vector2((i / slots.size()) * 6.0, 0)
		dish(ci, foods[i], p, 0.72)


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
	ellipse(ci, p + Vector2(2, 14) * s, Vector2(40, 6) * s, Color(0, 0, 0, 0.25))
	rbox(ci, Rect2(p + Vector2(-38, -16) * s, Vector2(56, 30) * s), Color("f4f1ea"), Color("b8b2a6"), 4, 2)
	rbox(ci, Rect2(p + Vector2(18, -8) * s, Vector2(20, 22) * s), Color("e9e4d8"), Color("b8b2a6"), 5, 2)
	rbox(ci, Rect2(p + Vector2(26, -5) * s, Vector2(10, 8) * s), Color("8fc3e6"), Color("6a93ad"), 2, 1)
	ci.draw_rect(Rect2(p + Vector2(-34, -4) * s, Vector2(48, 6) * s), Color("4f9a45"))
	var f := font()
	ci.draw_string(f, p + Vector2(-32, -7) * s, "FRESH", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * s), Color("4f9a45"))
	for x in [-24.0, 26.0]:
		ci.draw_circle(p + Vector2(x, 14) * s, 5.5 * s, Color("25252b"))
		ci.draw_circle(p + Vector2(x, 14) * s, 2.2 * s, Color("9aa1a8"))


static func wrench(ci: CanvasItem, p: Vector2, s: float, color: Color) -> void:
	ci.draw_line(p + Vector2(-4, 4) * s, p + Vector2(2, -2) * s, color, 2.4 * s)
	ci.draw_arc(p + Vector2(3.5, -3.5) * s, 3.0 * s, PI * 0.9, PI * 2.6, 10, color, 2.0 * s)
