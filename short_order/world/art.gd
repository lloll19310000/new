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


static func person(ci: CanvasItem, p: Vector2, facing: Vector2, shirt: Color, skin: Color, hair: Color,
		step: float, staff: bool, hat: bool, sitting: bool = false, look: String = "", s: float = 1.0, st: Dictionary = {}) -> void:
	var build: float = st.get("build", 1.0)
	var hstyle: int = st.get("hair", 0)
	var f := facing.normalized() if facing.length() > 0.01 else Vector2.DOWN
	var side := Vector2(-f.y, f.x)
	ellipse(ci, p + Vector2(0, 8) * s, Vector2(9, 4) * s, Color(0, 0, 0, 0.22))
	if look == "backpack":
		rbox(ci, Rect2(p - f * 8.0 * s - Vector2(5, 4) * s, Vector2(10, 8) * s), shirt.darkened(0.45), shirt.darkened(0.6), 3, 1)
	elif look == "driver":
		# a big insulated delivery bag on their back
		rbox(ci, Rect2(p - f * 9.0 * s - Vector2(7, 6) * s, Vector2(14, 12) * s), Color("e2703a"), Color("a84e22"), 3, 1)
		ci.draw_rect(Rect2(p - f * 9.0 * s - Vector2(5, 1) * s, Vector2(10, 2) * s), Color("fbe3cf"))
	var role := look.substr(5) if look.begins_with("role:") else ""
	var swing := 0.0 if sitting else sin(step) * 3.0 * float(st.get("bounce", 1.0))
	var hands := Color("f2c14e") if role == "dishwasher" else skin
	ci.draw_circle(p + (side * 8.5 * build + f * (2.0 + swing)) * s, 3.0 * s, hands)
	ci.draw_circle(p + (-side * 8.5 * build + f * (2.0 - swing)) * s, 3.0 * s, hands)
	var body := Color("f4f4f0") if look == "coat" else shirt
	ellipse(ci, p, Vector2(10 * build, 7) * s, body.darkened(0.25), side.angle())
	ellipse(ci, p - Vector2(0, 1) * s, Vector2(9 * build, 6) * s, body, side.angle())
	if not staff and look != "coat":
		clothes_pattern(ci, p - Vector2(0, 1) * s, f, side, body, int(st.get("pattern", 0)), st.get("accent", Color("2b2b30")), build, s)
	if int(st.get("extra", 0)) == 4:
		# a scarf round the neck
		ci.draw_arc(p + (f * 1.5 - Vector2(0, 2)) * s, 6.4 * s, 0, TAU, 16, st.get("accent", Color("d23b30")), 2.2 * s, true)
	if staff:
		uniform(ci, p, f, side, role, s)
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
	# long hair and ponytails hang behind the head
	if hstyle == 1:
		ellipse(ci, hp - f * 3.2 * s, Vector2(6.8, 5.2) * s, hair.darkened(0.1), side.angle())
	elif hstyle == 3:
		ci.draw_line(hp - f * 5.0 * s, hp - f * 10.5 * s, hair.darkened(0.1), 3.2 * s)
		ci.draw_circle(hp - f * 10.5 * s, 1.8 * s, hair.darkened(0.1))
	ci.draw_circle(hp, 6.3 * s, skin)
	if int(st.get("extra", 0)) == 1:
		for k in [-1.0, 1.0]:
			ci.draw_circle(hp + side * 6.2 * k * s + f * 0.8 * s, 0.9 * s, Color("f2c14e"))
	match hstyle:
		5:
			ci.draw_circle(hp - f * 1.2 * s - side * 1.5 * s, 1.8 * s, Color(1, 1, 1, 0.35))   # bald, with a shine
		6:
			ci.draw_circle(hp - f * 1.9 * s, 5.5 * s, Color(hair, 0.55))                       # a buzz cut
		4:
			ci.draw_circle(hp - f * 1.9 * s, 6.2 * s, hair)
			for k in 7:
				ci.draw_circle(hp - f * 1.9 * s + Vector2.from_angle(TAU * k / 7.0) * 5.4 * s, 2.3 * s, hair)
		_:
			ci.draw_circle(hp - f * 1.9 * s, 5.7 * s, hair)
	if hstyle == 2:
		ci.draw_circle(hp - f * 5.2 * s, 2.8 * s, hair.darkened(0.12))                      # a bun
	elif hstyle == 7:
		for k in [-1.0, 1.0]:
			ci.draw_circle(hp + side * 6.0 * k * s - f * 1.5 * s, 2.4 * s, hair.darkened(0.08))   # pigtails
	if st.get("beard", false) and hstyle != 7:
		ci.draw_arc(hp + f * 1.5 * s, 5.2 * s, f.angle() - 1.1, f.angle() + 1.1, 10, hair.darkened(0.2), 2.4 * s, true)
	if st.get("glasses", false) and look != "shades":
		ci.draw_line(hp + f * 4.6 * s - side * 3.8 * s, hp + f * 4.6 * s + side * 3.8 * s, Color("2b2b30"), 1.2 * s)
	if int(st.get("extra", 0)) == 2 and not staff:
		ci.draw_arc(hp - f * 1.0 * s, 5.9 * s, f.angle() + PI * 0.5 - 1.2, f.angle() + PI * 0.5 + 1.2, 8, st.get("accent", Color("d23b30")), 1.8 * s, true)
	if hat or role == "cook":
		# a chef's toque, puffed at the top
		ci.draw_circle(hp - f * 0.8 * s, 5.6 * s, Color("fbfbf8"))
		ci.draw_arc(hp - f * 0.8 * s, 5.6 * s, 0, TAU, 16, Color("d6d3cc"), 1.2, true)
		ci.draw_circle(hp - f * 1.6 * s + side * 1.5 * s, 2.6 * s, Color("ffffff"))
		ci.draw_circle(hp - f * 1.6 * s - side * 1.5 * s, 2.6 * s, Color("f4f2ec"))
	elif role == "busser" or role == "porter":
		var capc := Color("2e2e34") if role == "busser" else Color("2f6db0")
		ci.draw_circle(hp - f * 1.2 * s, 5.8 * s, capc)
		ellipse(ci, hp + f * 4.0 * s, Vector2(2.6, 4.8) * s, capc.darkened(0.3), f.angle())
	elif role == "dishwasher":
		# a hairnet
		ci.draw_arc(hp - f * 1.9 * s, 5.2 * s, 0, TAU, 14, Color(1, 1, 1, 0.55), 1.0 * s, true)
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


## Stripes, polka dots, a plaid or an open jacket on a customer's shirt.
static func clothes_pattern(ci: CanvasItem, p: Vector2, f: Vector2, side: Vector2, body: Color, pattern: int, accent: Color, build: float, s: float) -> void:
	var line := body.darkened(0.28) if body.get_luminance() > 0.35 else body.lightened(0.3)
	match pattern:
		1:
			for k in [-3.0, 0.0, 3.0]:
				ci.draw_line(p + f * k * s - side * 7.5 * build * s, p + f * k * s + side * 7.5 * build * s, line, 1.1 * s)
		2:
			for k in 5:
				ci.draw_circle(p + side * (k - 2) * 3.2 * s + f * ((k % 2) * 2.4 - 1.2) * s, 0.8 * s, line)
		3:
			for k in [-2.5, 2.5]:
				ci.draw_line(p + f * k * s - side * 7.5 * build * s, p + f * k * s + side * 7.5 * build * s, accent, 0.9 * s)
				ci.draw_line(p + side * k * s - f * 5.0 * s, p + side * k * s + f * 5.0 * s, accent, 0.9 * s)
		4:
			# an open jacket: darker sides, the shirt showing in the middle
			ellipse(ci, p + side * 5.0 * build * s, Vector2(3.6, 5.6) * s, accent.darkened(0.2), side.angle() + PI * 0.5)
			ellipse(ci, p - side * 5.0 * build * s, Vector2(3.6, 5.6) * s, accent.darkened(0.2), side.angle() + PI * 0.5)


## The uniform on top of the shirt, seen from above: the chef's buttons, an
## apron, a vest, the manager's tie.
static func uniform(ci: CanvasItem, p: Vector2, f: Vector2, side: Vector2, role: String, s: float) -> void:
	match role:
		"cook":
			for k in [-1.0, 1.0]:
				ci.draw_circle(p + f * 3.0 * s + side * 2.2 * k * s, 0.9 * s, Color("8d949c"))
				ci.draw_circle(p + f * 0.0 + side * 2.2 * k * s, 0.9 * s, Color("8d949c"))
		"server":
			ellipse(ci, p + f * 3.5 * s, Vector2(5.5, 3.6) * s, Color("fbfbf5"), side.angle())
			ci.draw_rect(Rect2(p + f * 1.5 * s + side * 3.0 * s - Vector2(1.2, 1.2) * s, Vector2(2.4, 2.4) * s), Color("f2c14e"))
		"host":
			ellipse(ci, p + f * 3.0 * s, Vector2(3.0, 3.4) * s, Color("f4f1ea"), side.angle())
			ci.draw_line(p + f * 1.0 * s, p + f * 6.0 * s, Color("2b1d17"), 1.2 * s)
		"busser":
			ellipse(ci, p + f * 3.5 * s, Vector2(5.5, 3.6) * s, Color("f4f1ea"), side.angle())
		"dishwasher":
			ellipse(ci, p + f * 3.5 * s, Vector2(6.0, 4.0) * s, Color("c9d6e2"), side.angle())
		"porter":
			ci.draw_line(p - side * 6.0 * s + f * 1.0 * s, p + side * 6.0 * s + f * 1.0 * s, Color("8b5a2b"), 1.6 * s)
			ci.draw_circle(p + side * 4.0 * s + f * 1.5 * s, 1.5 * s, Color("b8bec4"))
		"manager":
			ci.draw_line(p + f * 0.5 * s, p + f * 6.5 * s, Color("c8403a"), 2.2 * s)
			ci.draw_circle(p + f * 0.5 * s, 1.4 * s, Color("c8403a"))
		_:
			ellipse(ci, p + f * 3.0 * s, Vector2(5.5, 3.5) * s, Color("f4f1ea"), side.angle())


## A head-and-shoulders picture for the interface, filling rect r.
static func portrait(ci: CanvasItem, r: Rect2, skin: Color, hair: Color, shirt: Color, staff: bool, look: String = "", st: Dictionary = {}) -> void:
	var hstyle: int = st.get("hair", 0)
	var cc := r.get_center()
	var uu := r.size.y / 48.0
	# long hair and pigtails behind the head and shoulders
	if hstyle == 1:
		ci.draw_rect(Rect2(cc + Vector2(-12, -4) * uu, Vector2(24, 20) * uu), hair.darkened(0.1))
	elif hstyle == 7:
		for k in [-1.0, 1.0]:
			ci.draw_circle(cc + Vector2(12.5 * k, 2) * uu, 4.5 * uu, hair.darkened(0.08))
	_portrait_body(ci, r, skin, hair, shirt, staff, look, st)
	var c := cc
	var u := uu
	match hstyle:
		2:
			ci.draw_circle(c + Vector2(0, -14) * u, 4.5 * u, hair)
		3:
			ci.draw_circle(c + Vector2(10.5, -4) * u, 3.5 * u, hair.darkened(0.08))
		4:
			for k in 9:
				ci.draw_circle(c + Vector2(0, -4) * u + Vector2.from_angle(PI + PI * k / 8.0) * 10.5 * u, 3.4 * u, hair)
	if st.get("beard", false) and hstyle != 7:
		var bpts := PackedVector2Array()
		for i in 11:
			var a := PI * i / 10.0
			bpts.append(c + Vector2(0, 1) * u + Vector2(cos(a) * 9.8, sin(a) * 8.8) * u)
		ci.draw_colored_polygon(bpts, hair.darkened(0.15))
		ci.draw_arc(c + Vector2(0, 3.5) * u, 3.0 * u, 0.3, PI - 0.3, 8, Color("2a1d17"), maxf(1.0, 1.1 * u), true)
	if st.get("glasses", false) and look != "shades":
		for k in [-1.0, 1.0]:
			ci.draw_arc(c + Vector2(3.8 * k, 0) * u, 3.0 * u, 0, TAU, 12, Color("2b2b30"), maxf(1.0, 1.0 * u), true)
		ci.draw_line(c + Vector2(-0.8, 0) * u, c + Vector2(0.8, 0) * u, Color("2b2b30"), maxf(1.0, 0.9 * u))
	match int(st.get("extra", 0)):
		1:
			for k in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(10.4 * k, 3) * u, 1.3 * u, Color("f2c14e"))
		2:
			if not staff:
				ci.draw_rect(Rect2(c + Vector2(-10.5, -9.5) * u, Vector2(21, 2.6) * u), st.get("accent", Color("d23b30")))
		3:
			for k in [Vector2(-5.5, 2.5), Vector2(-4, 3.5), Vector2(5.5, 2.5), Vector2(4, 3.5), Vector2(-4.8, 1.2), Vector2(4.8, 1.2)]:
				ci.draw_circle(c + k * u, 0.55 * u, skin.darkened(0.3))
		4:
			ellipse(ci, c + Vector2(0, 11) * u, Vector2(10, 3.2) * u, st.get("accent", Color("d23b30")))


static func _portrait_body(ci: CanvasItem, r: Rect2, skin: Color, hair: Color, shirt: Color, staff: bool, look: String = "", st: Dictionary = {}) -> void:
	var hstyle: int = st.get("hair", 0)
	var c := r.get_center()
	var u := r.size.y / 48.0
	ci.draw_circle(c, r.size.y * 0.5, Color(1, 1, 1, 0.07))
	# shoulders
	ellipse(ci, c + Vector2(0, 20) * u, Vector2(17, 11) * u, shirt.darkened(0.2))
	ellipse(ci, c + Vector2(0, 21) * u, Vector2(15.5, 10) * u, shirt)
	var role := look.substr(5) if look.begins_with("role:") else ""
	if staff:
		var col := PackedVector2Array([c + Vector2(-6, 11) * u, c + Vector2(6, 11) * u, c + Vector2(0, 19) * u])
		ci.draw_colored_polygon(col, Color("f4f1ea"))
		match role:
			"manager":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-1.6, 12) * u, c + Vector2(1.6, 12) * u, c + Vector2(2.2, 21) * u, c + Vector2(0, 23) * u, c + Vector2(-2.2, 21) * u]), Color("c8403a"))
			"host":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.5, 12) * u, c + Vector2(0, 14) * u, c + Vector2(2.5, 12) * u, c + Vector2(0, 16) * u]), Color("2b1d17"))
			"server", "busser":
				ci.draw_rect(Rect2(c + Vector2(-9, 19) * u, Vector2(18, 7) * u), Color("fbfbf5"))
			"cook":
				for k in [-1.0, 1.0]:
					ci.draw_circle(c + Vector2(4.0 * k, 17) * u, 1.1 * u, Color("8d949c"))
					ci.draw_circle(c + Vector2(4.0 * k, 21) * u, 1.1 * u, Color("8d949c"))
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
	if hstyle == 5:
		ci.draw_circle(c + Vector2(-3, -8) * u, 2.5 * u, Color(1, 1, 1, 0.3))
	elif hstyle == 6:
		ci.draw_colored_polygon(pts, Color(hair, 0.5))
	else:
		ci.draw_colored_polygon(pts, hair)
	# face: eyes, brows and a mouth of their own
	ci.draw_circle(c + Vector2(-3.8, 0) * u, 1.3 * u, Color("2a1d17"))
	ci.draw_circle(c + Vector2(3.8, 0) * u, 1.3 * u, Color("2a1d17"))
	var tilt: float = st.get("brows", 0.0)
	if not st.is_empty():
		for k in [-1.0, 1.0]:
			var bc := c + Vector2(3.8 * k, -3.2) * u
			var d := Vector2(cos(tilt * k), sin(tilt * k)) * 2.2 * u
			ci.draw_line(bc - d, bc + d, hair.darkened(0.3), maxf(1.0, 1.1 * u))
	match int(st.get("mouth", 0)):
		1:
			ci.draw_arc(c + Vector2(0, 2.6) * u, 3.6 * u, 0.1, PI - 0.1, 10, Color("2a1d17"), maxf(1.0, 1.2 * u), true)
			ci.draw_line(c + Vector2(-3.4, 2.8) * u, c + Vector2(3.4, 2.8) * u, Color("2a1d17"), maxf(1.0, 1.0 * u))
		2:
			ci.draw_line(c + Vector2(-2.6, 4.8) * u, c + Vector2(2.6, 4.8) * u, Color("2a1d17"), maxf(1.0, 1.2 * u))
		3:
			ci.draw_arc(c + Vector2(1, 3) * u, 3.0 * u, 0.2, PI * 0.6, 8, Color("2a1d17"), maxf(1.0, 1.2 * u), true)
		_:
			ci.draw_arc(c + Vector2(0, 3) * u, 3.4 * u, 0.25, PI - 0.25, 10, Color("2a1d17"), maxf(1.0, 1.2 * u), true)
	if role == "cook":
		# a tall chef's toque
		ci.draw_rect(Rect2(c + Vector2(-8, -16) * u, Vector2(16, 8) * u), Color("fbfbf8"))
		for k in [-5.0, 0.0, 5.0]:
			ci.draw_circle(c + Vector2(k, -17) * u, 5.0 * u, Color("fbfbf8"))
		ci.draw_rect(Rect2(c + Vector2(-8, -10) * u, Vector2(16, 1.5) * u), Color("d6d3cc"))
	elif role == "busser" or role == "porter":
		var capc := Color("2e2e34") if role == "busser" else Color("2f6db0")
		ellipse(ci, c + Vector2(0, -10) * u, Vector2(11, 5) * u, capc)
		ellipse(ci, c + Vector2(6, -7) * u, Vector2(7, 2.5) * u, capc.darkened(0.3))
	elif staff and role in ["server", "host", ""]:
		# a little paper diner cap
		var cap := PackedVector2Array([c + Vector2(-9, -9) * u, c + Vector2(9, -9) * u, c + Vector2(6, -15) * u, c + Vector2(-6, -15) * u])
		ci.draw_colored_polygon(cap, Color("fbfbf8"))
		ci.draw_rect(Rect2(c + Vector2(-9, -10) * u, Vector2(18, 2) * u), Color("c8403a") if role != "server" else Color("3fa89a"))
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


## Things with a front: they're drawn facing up (the front toward the top of
## the tile, the back against the wall below), then turned to face their way.
const TURNS := ["sink", "jukebox", "drinks", "oven", "fridge", "freezer", "handsink", "host", "till", "ice", "booth"]


## Draws a piece of furniture of this type filling rect r. f may be null (for icons).
static func furniture_in(ci: CanvasItem, type: String, r: Rect2, dir: int, f = null, wall_dir: int = -1) -> void:
	if dir % 4 != 0 and type in TURNS and absf(r.size.x - r.size.y) < 0.5:
		ci.draw_set_transform(r.get_center(), (dir % 4) * PI * 0.5, Vector2.ONE)
		furniture_in(ci, type, Rect2(-r.size * 0.5, r.size), 0, f, wall_dir)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var s := r.size.y / T if r.size.x >= r.size.y else r.size.x / T
	var inner := r.grow(-3 * s)
	var cooking: String = f.cooking if f != null else ""
	match type:
		"table", "long_table":
			rbox(ci, inner, Color("b07a4a"), Color("7a5230"), 5)
			rbox(ci, inner.grow(-4 * s), Color("c08a58"), Color("c08a58"), 4, 0)
			if f != null and f.dirty_plates > 0:
				var n: int = f.dirty_plates
				for i in n:
					var t := (i + 0.5) / n
					var p := inner.position + Vector2(inner.size.x * t, inner.size.y * 0.5) if f.size.x >= f.size.y else inner.position + Vector2(inner.size.x * 0.5, inner.size.y * t)
					plate(ci, p, 0.8, true)
		"table_small":
			var ct := r.get_center()
			ci.draw_circle(ct + Vector2(1, 1.5) * s, 12.5 * s, Color(0, 0, 0, 0.18))
			ci.draw_circle(ct, 12.5 * s, Color("7a5230"))
			ci.draw_circle(ct, 11 * s, Color("b07a4a"))
			ci.draw_circle(ct, 8 * s, Color("c08a58"))
			if f != null and f.dirty_plates > 0:
				for i in f.dirty_plates:
					plate(ci, ct + Vector2(i * 3.0, -i * 2.0) * s, 0.8 * s, true)
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
		"booth":
			# red vinyl bench with a high back on the side away from the table
			var bk: Vector2i = -Data.DIRS[dir]
			var bench := r.grow(-3 * s)
			rbox(ci, bench, Color("b8332f"), Color("7a2020"), 4, 1)
			rbox(ci, bench.grow(-3 * s), Color("d9463b"), Color("b8332f"), 3, 0)
			var back := axis_rect(r.get_center() + Vector2(bk) * 10.0 * s, Vector2(absf(bk.y), absf(bk.x)), 28 * s, 7 * s)
			rbox(ci, back, Color("8f2522"), Color("5e1614"), 3, 1)
			for k in [-6.0, 0.0, 6.0]:
				ci.draw_circle(r.get_center() + Vector2(absf(bk.y), absf(bk.x)) * k * s + Vector2(bk) * 1.0 * s, 0.9 * s, Color("f5b0a6"))
		"counter":
			var jn: int = f.join if f != null else 0
			var top := r.grow(-3 * s)
			# stretch toward joined neighbours so a row reads as one counter
			if jn & 1: top = top.grow_side(SIDE_TOP, 3 * s)
			if jn & 2: top = top.grow_side(SIDE_RIGHT, 3 * s)
			if jn & 4: top = top.grow_side(SIDE_BOTTOM, 3 * s)
			if jn & 8: top = top.grow_side(SIDE_LEFT, 3 * s)
			# a laminate top with a chrome edge, speckled like an old diner counter
			ci.draw_rect(Rect2(top.position + Vector2(1.5, 2) * s, top.size), Color(0, 0, 0, 0.2))
			ci.draw_rect(top, Color("8d949c"))
			ci.draw_rect(top.grow(-2 * s), Color("d8566a"))
			for k in 5:
				ci.draw_circle(top.position + Vector2(4 + fmod(k * 7.3, 20.0), 5 + fmod(k * 5.1, 16.0)) * s, 0.8 * s, Color("f3b0bb"))
			if f != null and f.dirty_plates > 0:
				plate(ci, top.get_center(), 0.8 * s, true)
		"stool":
			var sc := r.get_center()
			ci.draw_circle(sc + Vector2(1, 1.5) * s, 8.5 * s, Color(0, 0, 0, 0.18))
			ci.draw_circle(sc, 8.5 * s, Color("b8bec4"))
			ci.draw_circle(sc, 7.0 * s, Color("d9463b"))
			ci.draw_circle(sc + Vector2(-2, -2) * s, 2.5 * s, Color(1, 1, 1, 0.3))
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
			# from above: the nozzles over a drip tray at the front, the syrup tanks at the back
			rbox(ci, inner, Color("c8403a"), Color("8c2a25"), 4)
			var tray := Rect2(inner.position + Vector2(3, 2.5) * s, Vector2(inner.size.x - 6 * s, 9 * s))
			rbox(ci, tray, Color("3a3d42"), Color("25272b"), 2, 1)
			for i in 4:
				var tx := tray.position.x + (3.5 + i * 5.0) * s
				ci.draw_line(Vector2(tx, tray.position.y + 1.5 * s), Vector2(tx, tray.end.y - 1.5 * s), Color("55585e"), 1.0)
			var tanks := [Color("f2a7c3"), Color("6b4226"), Color("f7e27a")]
			for i in 3:
				var tp := inner.position + Vector2(inner.size.x * (0.25 + i * 0.25), inner.size.y * 0.7)
				ci.draw_circle(tp, 3.4 * s, Color("f4efe6"))
				ci.draw_circle(tp, 2.4 * s, tanks[i])
			if cooking != "":
				dish(ci, cooking, tray.get_center(), 0.75 * s, false)
		"pass":
			# a hatch through the wall: a steel shelf across the wall, lips on the
			# kitchen and dining sides, and a heat lamp over the middle
			var along := Vector2.RIGHT if r.size.x >= r.size.y else Vector2.DOWN
			var across := Vector2(along.y, along.x)
			var len_a := maxf(r.size.x, r.size.y) - 2 * s
			var pc := r.get_center()
			rbox(ci, axis_rect(pc, along, len_a, 29 * s), Color("c7ccd1"), Color("8d949c"), 3, 2)
			for side in [-1.0, 1.0]:
				ci.draw_rect(axis_rect(pc + across * side * 12.0 * s, along, len_a - 5 * s, 2 * s), Color("9aa1a8"))
			ci.draw_rect(axis_rect(pc, along, len_a - 8 * s, 3.2 * s), Color("e39a3f"))
			ci.draw_rect(axis_rect(pc, along, len_a - 10 * s, 1.2 * s), Color("fff0c8"))
			if f != null:
				for i in f.items.size():
					var p: Vector2 = pass_slot(r, i)
					var it: Dictionary = f.items[i]
					if it.get("takeout", false):
						bag(ci, p, 0.7)
					else:
						dish(ci, it["dish"], p, 0.75, true, float(it.get("q", -1.0)))
		"oven":
			# a range from above: the door handle and knobs along the front, two
			# burners, and the back riser against the wall
			rbox(ci, inner, Color("4a4f57"), Color("2c3036"), 4)
			var hot := cooking != ""
			if hot:
				ci.draw_rect(inner.grow(-2 * s), Color(1.0, 0.5, 0.15, 0.14))
			ci.draw_rect(Rect2(inner.position.x + 2 * s, inner.end.y - 5.5 * s, inner.size.x - 4 * s, 3.5 * s), Color("2f333a"))
			for bx in [0.3, 0.7]:
				var bc := inner.position + Vector2(inner.size.x * bx, inner.size.y * 0.55)
				ci.draw_circle(bc, 5.0 * s, Color("25282d"))
				ci.draw_arc(bc, 3.9 * s, 0, TAU, 16, Color("ff7a2e") if hot else Color("5b6068"), 1.3 * s, true)
				ci.draw_arc(bc, 1.9 * s, 0, TAU, 12, Color("ffb35a") if hot else Color("5b6068"), 1.0 * s, true)
			ci.draw_rect(Rect2(inner.position.x + 3 * s, inner.position.y + 2 * s, inner.size.x - 6 * s, 1.8 * s), Color("aeb4bb"))
			for i in 4:
				ci.draw_circle(inner.position + Vector2(inner.size.x * (0.2 + i * 0.2), 6.5 * s), 1.4 * s, Color("d5d9de"))
		"fridge":
			# a reach-in fridge from above: the door handle at the front, the coils at the back
			rbox(ci, inner, Color("e8eef2"), Color("aab4bd"), 4)
			ci.draw_rect(Rect2(inner.position.x + 3 * s, inner.end.y - 5.5 * s, inner.size.x - 6 * s, 3.5 * s), Color("b9c3cb"))
			for i in 4:
				var gx := inner.position.x + (6.0 + i * 4.5) * s
				ci.draw_line(Vector2(gx, inner.end.y - 5.5 * s), Vector2(gx, inner.end.y - 2 * s), Color("8d99a3"), 1.0)
			ci.draw_line(inner.position + Vector2(3 * s, inner.size.y * 0.5), inner.position + Vector2(inner.size.x - 3 * s, inner.size.y * 0.5), Color("cfd8de"), 1.0)
			rbox(ci, Rect2(inner.position.x + inner.size.x * 0.22, inner.position.y + 2 * s, inner.size.x * 0.56, 3 * s), Color("8d99a3"), Color("7a8690"), 1, 1)
			ci.draw_circle(inner.position + Vector2(inner.size.x - 5 * s, inner.size.y * 0.32), 1.3 * s, Color("5aa9d6"))
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
			# a small basin, the tap at the back and the soap beside it
			rbox(ci, inner, Color("e8eef2"), Color("9aa8b3"), 4)
			ellipse(ci, inner.get_center() + Vector2(0, -2) * s, Vector2(7.5, 6) * s, Color("7fb4d6"))
			var htap := Vector2(inner.get_center().x, inner.end.y - 4 * s)
			ci.draw_circle(htap, 2.0 * s, Color("8d949c"))
			ci.draw_line(htap, htap + Vector2(0, -6) * s, Color("7d868f"), 2.0 * s)
			rbox(ci, Rect2(inner.position + Vector2(inner.size.x - 7 * s, inner.size.y - 9 * s), Vector2(5, 6) * s), Color("f2c14e"), Color("b8912e"), 1, 1)
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
			# a chest freezer from above: the lid with its handle at the front, hinges at the back
			rbox(ci, inner, Color("d7e6f2"), Color("8fa8bd"), 4)
			rbox(ci, inner.grow(-2.5 * s), Color("c4dbec"), Color("a9c3d7"), 3, 1)
			rbox(ci, Rect2(inner.position.x + inner.size.x * 0.28, inner.position.y + 1.5 * s, inner.size.x * 0.44, 3 * s), Color("7f97ab"), Color("6a8296"), 1, 1)
			for hx in [0.25, 0.75]:
				ci.draw_rect(Rect2(inner.position.x + inner.size.x * hx - 2.5 * s, inner.end.y - 4 * s, 5 * s, 2.5 * s), Color("8fa8bd"))
			var fc := inner.get_center() + Vector2(0, 1) * s
			for a in 3:
				var d := Vector2.RIGHT.rotated(a * PI / 3.0) * 5.0 * s
				ci.draw_line(fc - d, fc + d, Color("5a8fc0"), 1.2 * s)
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
			# the basin, with the tap at the back
			rbox(ci, inner, Color("b8c0c8"), Color("7d868f"), 4)
			var basin := Rect2(inner.position + Vector2(3, 3) * s, Vector2(inner.size.x - 6 * s, inner.size.y - 11 * s))
			rbox(ci, basin, Color("7fb4d6"), Color("5f93b5"), 5, 1)
			var tap := Vector2(inner.get_center().x, inner.end.y - 4 * s)
			ci.draw_circle(tap, 2.2 * s, Color("8d949c"))
			ci.draw_line(tap, tap + Vector2(0, -7) * s, Color("d5d9de"), 2.0 * s)
			ci.draw_circle(tap + Vector2(-5.5, 0) * s, 1.4 * s, Color("e06b5e"))
			ci.draw_circle(tap + Vector2(5.5, 0) * s, 1.4 * s, Color("5aa9d6"))
			if f != null:
				var n := mini(f.dirty, 5)
				for i in n:
					plate(ci, basin.get_center() + Vector2(-4.0 + i * 2.2, 1.5 - i * 1.2) * s, 0.7 * s, true)
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
		"aquarium":
			# a glass tank on a wooden stand: water, gravel, a plant and goldfish
			rbox(ci, inner, Color("6a4226"), Color("4a2c18"), 3, 1)
			var tank := inner.grow(-2.5 * s)
			rbox(ci, tank, Color("6fb8d9"), Color("d8eef7"), 2, 1)
			var wide := tank.size.x >= tank.size.y
			var gr := Rect2(tank.position + Vector2(0, tank.size.y * 0.72), Vector2(tank.size.x, tank.size.y * 0.28)) if wide else Rect2(tank.position + Vector2(tank.size.x * 0.72, 0), Vector2(tank.size.x * 0.28, tank.size.y))
			ci.draw_rect(gr.grow(-1 * s), Color("c9a870"))
			var tc := tank.get_center()
			var ax := Vector2(1, 0) if wide else Vector2(0, 1)
			for k in 3:
				var fp := tc + ax * (k - 1) * tank.size[0 if wide else 1] * 0.28 + Vector2(ax.y, ax.x) * (k % 2 * 3.0 - 1.5) * s
				ellipse(ci, fp, Vector2(2.6, 1.6) * s if wide else Vector2(1.6, 2.6) * s, Color("f2903a"))
				ci.draw_colored_polygon(PackedVector2Array([fp - ax * 2.2 * s, fp - ax * 4.2 * s + Vector2(ax.y, ax.x) * 1.6 * s, fp - ax * 4.2 * s - Vector2(ax.y, ax.x) * 1.6 * s]), Color("f7b35a"))
			for k in 3:
				ci.draw_circle(tank.position + Vector2(tank.size.x * (0.2 + k * 0.07), tank.size.y * (0.25 + k * 0.12)), 0.9 * s, Color(1, 1, 1, 0.6))
			ci.draw_line(gr.get_center(), gr.get_center() - Vector2(ax.y, ax.x).abs() * 0.0 - (Vector2(0, 1) if wide else Vector2(1, 0)) * 7.0 * s, Color("4f9a45"), 1.6 * s)
		"jukebox":
			# the speaker grille at the front, the glowing dome at the back
			rbox(ci, inner, Color("8c2f2a"), Color("5e1d19"), 8)
			var top := Rect2(Vector2(inner.position.x + 3 * s, inner.end.y - 3 * s - inner.size.y * 0.55), Vector2(inner.size.x - 6 * s, inner.size.y * 0.55))
			var cols := [Color("f2c14e"), Color("ef8a3a"), Color("d9463b"), Color("5aa9d6")]
			for i in cols.size():
				rbox(ci, top.grow(-i * 2.2 * s), cols[i], cols[i], int(8 - i * 1.5), 0)
			rbox(ci, top.grow(-9 * s), Color("2b1d17"), Color("2b1d17"), 3, 0)
			for i in 3:
				ci.draw_line(Vector2(inner.position.x + 6 * s, inner.position.y + (4 + i * 3) * s), Vector2(inner.end.x - 6 * s, inner.position.y + (4 + i * 3) * s), Color("d8d0c2"), 1.0)
		"radio":
			var rc2 := r.get_center()
			rbox(ci, Rect2(rc2 - Vector2(9, 6) * s, Vector2(18, 12) * s), Color("c8403a"), Color("8a2a24"), 3, 1)
			ci.draw_circle(rc2 + Vector2(-3.5, 0) * s, 3.6 * s, Color("3a2e26"))
			for k in 3:
				ci.draw_arc(rc2 + Vector2(-3.5, 0) * s, (1.0 + k) * s, 0, TAU, 8, Color("6a5a4c"), 0.6 * s)
			ci.draw_rect(Rect2(rc2 + Vector2(2, -3) * s, Vector2(5, 3) * s), Color("fff4c2"))
			ci.draw_line(rc2 + Vector2(6, -6) * s, rc2 + Vector2(10, -12) * s, Color("c9ced6"), 1.0 * s)
		"highchair":
			var hc := r.get_center()
			ci.draw_circle(hc + Vector2(1, 1.5) * s, 8 * s, Color(0, 0, 0, 0.18))
			rbox(ci, Rect2(hc - Vector2(8, 8) * s, Vector2(16, 16) * s), Color("d9a14a"), Color("a8732e"), 4, 1)
			rbox(ci, Rect2(hc - Vector2(8, 8) * s, Vector2(16, 6) * s), Color("f2c14e"), Color("a8732e"), 3, 1)
			ci.draw_circle(hc + Vector2(0, 2) * s, 3 * s, Color("e75a4e"))
		"stall":
			# a parking bay: asphalt, white lines and a lit menu board on a post
			ci.draw_rect(r.grow(-1 * s), Color("4a4a50"))
			var wide2 := r.size.x >= r.size.y
			for xx in [r.position.x + 3 * s, r.end.x - 3 * s]:
				ci.draw_line(Vector2(xx, r.position.y + 3 * s), Vector2(xx, r.end.y - 3 * s), Color("f4f4f0"), 2 * s)
			var board := Rect2(r.position + Vector2(r.size.x - 16 * s, 3 * s), Vector2(12, 16) * s)
			ci.draw_rect(Rect2(board.get_center() + Vector2(-1, 6) * s, Vector2(2, 8) * s), Color("8d949b"))
			rbox(ci, board, Color("c8403a"), Color("8a2a24"), 2, 1)
			for k in 3:
				ci.draw_line(board.position + Vector2(2.5, 4 + k * 3.5) * s, board.position + Vector2(9.5, 4 + k * 3.5) * s, Color("fff4c2"), 0.9 * s)
			if f != null and f.group != null and is_instance_valid(f.group):
				car(ci, r.get_center() + Vector2(-2, 2) * s, 1 if wide2 else 0, [Color("6aa6d9"), Color("e75a4e"), Color("f2c14e"), Color("6cc3a0")][f.group.get_instance_id() % 4])
		"bench", "wait_chair":
			# a wooden bench (or a single chair) with a red seat cushion and a back rail
			var wide := inner.size.x >= inner.size.y
			var back := Rect2(inner.position, Vector2(inner.size.x, 5 * s)) if wide else Rect2(inner.position, Vector2(5 * s, inner.size.y))
			ci.draw_rect(Rect2(inner.position + Vector2(1, 2) * s, inner.size), Color(0, 0, 0, 0.18))
			rbox(ci, inner, Color("8a5a36"), Color("5e3b20"), 3, 1)
			rbox(ci, back, Color("6e4526"), Color("5e3b20"), 2, 1)
			var seat := inner.grow(-4 * s)
			if wide:
				seat.position.y += 3 * s
				seat.size.y -= 3 * s
			else:
				seat.position.x += 3 * s
				seat.size.x -= 3 * s
			rbox(ci, seat, Color("c8403a"), Color("9e2f28"), 3, 1)
			if type == "bench":
				var mid := seat.get_center()
				if wide:
					ci.draw_line(Vector2(mid.x, seat.position.y), Vector2(mid.x, seat.end.y), Color("9e2f28"), 1.2 * s)
				else:
					ci.draw_line(Vector2(seat.position.x, mid.y), Vector2(seat.end.x, mid.y), Color("9e2f28"), 1.2 * s)
		"staff_table":
			rbox(ci, inner, Color("9aa3a8"), Color("6e777c"), 3)
			rbox(ci, inner.grow(-3 * s), Color("c9d0d4"), Color("c9d0d4"), 2, 0)
			ci.draw_circle(inner.get_center() + Vector2(-inner.size.x * 0.2, 0), 3.2 * s, Color("f4f4f4"))
			ci.draw_circle(inner.get_center() + Vector2(inner.size.x * 0.22, -1 * s), 2.4 * s, Color("c98a3a"))
		"coffee_maker":
			rbox(ci, inner, Color("3a3d42"), Color("25272b"), 3)
			ci.draw_circle(inner.get_center() + Vector2(0, 2) * s, 6 * s, Color("dfeef6"))
			ci.draw_circle(inner.get_center() + Vector2(0, 2) * s, 4.8 * s, Color("5a3520"))
			ci.draw_rect(Rect2(inner.position + Vector2(3, 3) * s, Vector2(inner.size.x - 6 * s, 4 * s)), Color("d23b30"))
		"vending":
			rbox(ci, inner, Color("2f6fb3"), Color("1f4f82"), 3)
			var glass := Rect2(inner.position + Vector2(3, 3) * s, Vector2(inner.size.x * 0.62, inner.size.y - 6 * s))
			ci.draw_rect(glass, Color("bfe3f7"))
			for yy in 3:
				for xx in 3:
					var cc: Color = [Color("e75a4e"), Color("f2c14e"), Color("6cc3a0")][(xx + yy) % 3]
					ci.draw_rect(Rect2(glass.position + Vector2(2 + xx * glass.size.x / 3.2, 2 + yy * glass.size.y / 3.2), Vector2(glass.size.x / 4.5, glass.size.y / 5.0)), cc)
			ci.draw_rect(Rect2(Vector2(glass.end.x + 2 * s, inner.position.y + 5 * s), Vector2(inner.end.x - glass.end.x - 5 * s, 6 * s)), Color("1a1a1a"))
		"tv":
			rbox(ci, inner, Color("5a4030"), Color("3e2b1f"), 3)
			var scr := inner.grow(-4 * s)
			scr.size.y *= 0.7
			ci.draw_rect(scr, Color("1b1d22"))
			ci.draw_rect(scr.grow(-1.5 * s), Color("3f86c6"))
			ci.draw_rect(Rect2(scr.position + Vector2(scr.size.x * 0.1, scr.size.y * 0.55), Vector2(scr.size.x * 0.8, scr.size.y * 0.3)), Color("4f9a45"))
		"lockers":
			rbox(ci, inner, Color("6c8aa3"), Color("4a6377"), 2)
			var n := 4
			for i in n:
				var lw := inner.size.x / n if inner.size.x >= inner.size.y else inner.size.x
				var lh := inner.size.y if inner.size.x >= inner.size.y else inner.size.y / n
				var lr := Rect2(inner.position + (Vector2(lw * i, 0) if inner.size.x >= inner.size.y else Vector2(0, lh * i)), Vector2(lw, lh)).grow(-1.2 * s)
				ci.draw_rect(lr, Color("7fa0ba"))
				for k in 3:
					ci.draw_line(lr.position + Vector2(2 * s, (3 + k * 2) * s), lr.position + Vector2(lr.size.x - 2 * s, (3 + k * 2) * s), Color("4a6377"), 0.8 * s)
				ci.draw_circle(lr.get_center() + Vector2(lr.size.x * 0.25, 0), 1.0 * s, Color("f2c14e"))
		"desk":
			rbox(ci, inner, Color("6b4226"), Color("4a2c18"), 3)
			rbox(ci, inner.grow(-3 * s), Color("8a5a36"), Color("8a5a36"), 2, 0)
			var dc := inner.get_center()
			ci.draw_rect(Rect2(dc + Vector2(-inner.size.x * 0.35, -4 * s), Vector2(9 * s, 7 * s)), Color("f6f1e6"))
			ci.draw_rect(Rect2(dc + Vector2(-inner.size.x * 0.33, -3 * s), Vector2(9 * s, 7 * s)), Color("fbfbf5"))
			ci.draw_rect(Rect2(dc + Vector2(inner.size.x * 0.05, -5 * s), Vector2(11 * s, 8 * s)), Color("2a2c30"))
			ci.draw_rect(Rect2(dc + Vector2(inner.size.x * 0.05 + 1, -4 * s), Vector2(11 * s - 2, 6 * s)), Color("6aa6d9"))
			ci.draw_circle(dc + Vector2(inner.size.x * 0.36, 2 * s), 2 * s, Color("f4f4f4"))
		"filing":
			rbox(ci, inner, Color("8d949b"), Color("5f666c"), 2)
			for k in 3:
				var dr := Rect2(inner.position + Vector2(2 * s, 2 * s + k * (inner.size.y - 4 * s) / 3.0), Vector2(inner.size.x - 4 * s, (inner.size.y - 4 * s) / 3.0 - 1 * s))
				ci.draw_rect(dr, Color("aab1b7"))
				ci.draw_rect(Rect2(dr.get_center() - Vector2(3, 0.8) * s, Vector2(6, 1.6) * s), Color("4a4f54"))
		"whiteboard", "tin_sign", "records":
			var dw2 := Vector2(Data.DIRS[wall_dir if wall_dir >= 0 else 2])
			var bsz := Vector2(12, 24) * s if dw2.x != 0 else Vector2(24, 12) * s
			var br := Rect2(r.get_center() + dw2 * 7.0 * s - bsz / 2.0, bsz)
			rbox(ci, Rect2(br.position + Vector2(1, 1.5) * s, br.size), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0), 2, 0)
			match type:
				"whiteboard":
					rbox(ci, br, Color("f7f7f2"), Color("9aa3a8"), 2, 1)
					for k in 3:
						var y0 := br.position + Vector2(2.5, 2.5 + k * 3.0) * s
						ci.draw_line(y0, y0 + Vector2(br.size.x - 5 * s, 0) * (0.5 + 0.15 * k) if br.size.x > br.size.y else y0 + Vector2(br.size.x - 5 * s, 0), [Color("d23b30"), Color("3f86c6"), Color("3a2e26")][k], 0.9 * s)
				"tin_sign":
					rbox(ci, br, Color("c8403a"), Color("8a2a24"), 2, 1)
					ci.draw_circle(br.get_center(), 3.2 * s, Color("f4f4f4"))
					ci.draw_circle(br.get_center(), 2.4 * s, Color("5a3520"))
					ci.draw_line(br.get_center() + Vector2(-1, -4) * s, br.get_center() + Vector2(0, -6) * s, Color(1, 1, 1, 0.7), 0.8 * s)
				"records":
					var along2 := Vector2(dw2.y, dw2.x).abs()
					for k in 3:
						var rc := br.get_center() + along2 * (k - 1) * 7.5 * s
						ci.draw_circle(rc, 3.6 * s, Color("16161a"))
						ci.draw_arc(rc, 2.6 * s, 0, TAU, 12, Color("33333a"), 0.6 * s)
						ci.draw_circle(rc, 1.2 * s, [Color("e75a4e"), Color("f2c14e"), Color("6aa6d9")][k])
		"rug":
			rbox(ci, inner, Color("a8452a"), Color("7e3220"), 3)
			rbox(ci, inner.grow(-3 * s), Color("d9a14a"), Color("d9a14a"), 2, 0)
			rbox(ci, inner.grow(-6 * s), Color("2f6b52"), Color("2f6b52"), 2, 0)
		"flowers":
			rbox(ci, inner.grow(-3 * s), Color("8a5a36"), Color("5e3b20"), 2)
			var fc := inner.get_center()
			for k in 5:
				var fp := fc + Vector2.from_angle(TAU * k / 5.0) * 4.5 * s
				ci.draw_circle(fp, 2.6 * s, [Color("e75a4e"), Color("f2c14e"), Color("e27fa8"), Color("f7f7f2"), Color("b58be0")][k])
				ci.draw_circle(fp, 0.8 * s, Color("f2c14e"))
			ci.draw_circle(fc, 2 * s, Color("4f9a45"))
		"palm":
			ci.draw_circle(r.get_center() + Vector2(1, 1.5) * s, 9 * s, Color(0, 0, 0, 0.2))
			ci.draw_circle(r.get_center(), 7 * s, Color("b8793a"))
			for k in 7:
				var a2 := TAU * k / 7.0 + 0.3
				ellipse(ci, r.get_center() + Vector2.from_angle(a2) * 8 * s, Vector2(9, 3) * s, Color("3f8a3c") if k % 2 == 0 else Color("56a84a"), a2)
			ci.draw_circle(r.get_center(), 2.5 * s, Color("6b4226"))
		"gumball":
			ci.draw_circle(r.get_center() + Vector2(1, 1.5) * s, 9 * s, Color(0, 0, 0, 0.2))
			ci.draw_circle(r.get_center(), 8.5 * s, Color("c8403a"))
			ci.draw_circle(r.get_center(), 7 * s, Color("dfeef6"))
			for k in 9:
				var gp := r.get_center() + Vector2.from_angle(k * 2.4) * (1.5 + (k % 3) * 1.8) * s
				ci.draw_circle(gp, 1.5 * s, [Color("e75a4e"), Color("f2c14e"), Color("6aa6d9"), Color("6cc3a0"), Color("e27fa8")][k % 5])
			ci.draw_circle(r.get_center() + Vector2(-2.5, -2.5) * s, 1.6 * s, Color(1, 1, 1, 0.6))
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
		"clock":
			# a round chrome diner clock with a red rim, hanging on the wall
			var dc := Vector2(Data.DIRS[wall_dir if wall_dir >= 0 else 2])
			var cc := r.get_center() + dc * 6.0 * s
			ci.draw_circle(cc + Vector2(1, 1.5) * s, 9.5 * s, Color(0, 0, 0, 0.28))
			ci.draw_circle(cc, 9.5 * s, Color("c9ced6"))
			ci.draw_circle(cc, 8.2 * s, Color("d23b30"))
			ci.draw_circle(cc, 6.8 * s, Color("fbfbf5"))
			for i in 12:
				var a := TAU * i / 12.0
				ci.draw_line(cc + Vector2.from_angle(a) * 5.4 * s, cc + Vector2.from_angle(a) * 6.3 * s, Color("3a2e26"), 0.8 * s)
			var mins := GameState.minute
			var ha := TAU * fmod(mins / 720.0, 1.0) - PI / 2.0
			var ma := TAU * fmod(mins / 60.0, 1.0) - PI / 2.0
			ci.draw_line(cc, cc + Vector2.from_angle(ha) * 3.4 * s, Color("3a2e26"), 1.3 * s)
			ci.draw_line(cc, cc + Vector2.from_angle(ma) * 5.0 * s, Color("3a2e26"), 0.9 * s)
			ci.draw_circle(cc, 0.9 * s, Color("d23b30"))
		"trophy":
			# a little wooden shelf with a gold cup and two plaques
			var dt := Vector2(Data.DIRS[wall_dir if wall_dir >= 0 else 2])
			var tsz := Vector2(12, 26) * s if dt.x != 0 else Vector2(26, 12) * s
			var tr := Rect2(r.get_center() + dt * 7.0 * s - tsz / 2.0, tsz)
			rbox(ci, Rect2(tr.position + Vector2(1, 1.5) * s, tr.size), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0), 2, 0)
			rbox(ci, tr, Color("8a5a36"), Color("6a4226"), 2, 1)
			var tc := tr.get_center()
			ci.draw_circle(tc, 4.2 * s, Color("a8801e"))
			ci.draw_circle(tc, 3.4 * s, Color("f2c14e"))
			ci.draw_circle(tc + Vector2(-1, -1) * s, 1.2 * s, Color("fff4c2"))
			var along := Vector2(dt.y, dt.x).abs()
			for k in [-1.0, 1.0]:
				var pp: Vector2 = tc + along * k * 8.5 * s
				ci.draw_rect(Rect2(pp - Vector2(2.2, 2.2) * s, Vector2(4.4, 4.4) * s), Color("c9ced6"))
				ci.draw_rect(Rect2(pp - Vector2(1.2, 1.2) * s, Vector2(2.4, 2.4) * s), Color("a8801e"))
		"eotm":
			# a gold frame with this month's best worker (or an empty silhouette)
			var de := Vector2(Data.DIRS[wall_dir if wall_dir >= 0 else 2])
			var esz := Vector2(16, 22) * s if de.x != 0 else Vector2(20, 18) * s
			var er := Rect2(r.get_center() + de * 6.0 * s - esz / 2.0, esz)
			rbox(ci, Rect2(er.position + (de * 2.0 + Vector2(1, 1)) * s, er.size), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0), 2, 0)
			rbox(ci, er, Color("f2c14e"), Color("a8801e"), 2, 2)
			var ep := er.grow(-2.5 * s)
			ci.draw_rect(ep, Color("f6f1e6"))
			var lk: Dictionary = Moments.eotm_look()
			var pr := Rect2(ep.get_center() - Vector2(1, 1) * minf(ep.size.x, ep.size.y) * 0.45, Vector2(1, 1) * minf(ep.size.x, ep.size.y) * 0.9)
			if lk.is_empty():
				ci.draw_circle(pr.get_center() + Vector2(0, -1.5) * s, 3.0 * s, Color("c9bfae"))
				ci.draw_circle(pr.get_center() + Vector2(0, 4.5) * s, 4.5 * s, Color("c9bfae"))
			else:
				portrait(ci, pr, lk["skin"], lk["hair"], lk["shirt"], true, lk["look"], style_for(hash(str(Moments.eotm.get("name", "")))))
			ci.draw_circle(er.position + Vector2(er.size.x / 2.0, er.size.y - 1.5 * s), 2.2 * s, Color("e75a4e"))
		"wall_art":
			# a framed landscape hanging on the room side of the wall: wide on the
			# top and bottom walls, tall on the side walls
			var dw := Vector2(Data.DIRS[wall_dir if wall_dir >= 0 else 2])
			var fsz := Vector2(15, 24) * s if dw.x != 0 else Vector2(24, 15) * s
			var fr := Rect2(r.get_center() + dw * 6.5 * s - fsz / 2.0, fsz)
			rbox(ci, Rect2(fr.position + (dw * 2.0 + Vector2(1, 1)) * s, fr.size), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0), 2, 0)
			rbox(ci, fr, Color("d8a63a"), Color("9c7424"), 2, 2)
			var pic := fr.grow(-3 * s)
			ci.draw_rect(pic, Color("8fc3e6"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(pic.position.x, pic.end.y), pic.position + Vector2(pic.size.x * 0.38, pic.size.y * 0.45),
				pic.position + Vector2(pic.size.x * 0.7, pic.size.y * 0.72), pic.end]), Color("5c9a4a"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(pic.position.x + pic.size.x * 0.45, pic.end.y), pic.position + Vector2(pic.size.x * 0.78, pic.size.y * 0.55), pic.end]), Color("4a8a3c"))
			ci.draw_circle(pic.position + Vector2(pic.size.x * 0.76, pic.size.y * 0.28), 1.8 * s, Color("f7e27a"))
		"neon":
			# a neon EAT sign on the room side of the wall: the letters side by side
			# on the top and bottom walls, stacked on the side walls. It only glows into the room.
			var dn := Vector2(Data.DIRS[wall_dir if wall_dir >= 0 else 2])
			var nsz := Vector2(13, 28) * s if dn.x != 0 else Vector2(28, 13) * s
			var nc := r.get_center() + dn * 6.0 * s
			half_disc(ci, nc, dn, 17 * s, Color(1.0, 0.35, 0.6, 0.13))
			var nr := Rect2(nc - nsz / 2.0, nsz)
			rbox(ci, nr, Color("1f1a24"), Color("15121a"), 3, 1)
			ci.draw_rect(nr.grow(-1.5 * s), Color(1.0, 0.37, 0.64, 0.5), false, 0.8 * s)
			neon_letters(ci, nr.grow(-1.5 * s), dn.x != 0, Color("ff5fa2"), 1.6 * s)
			neon_letters(ci, nr.grow(-1.5 * s), dn.x != 0, Color("ffd6ea"), 0.6 * s)
		"takeout":
			# a counter through the wall with a glass pane over the wall line and a
			# bell on the inside; outside, a striped awning with a scalloped edge.
			# All of it stays inside its own tile.
			var ins := Vector2(Data.DIRS[wall_dir if wall_dir >= 0 else 0])
			var along_w := Vector2(absf(ins.y), absf(ins.x))
			var tc := r.get_center()
			rbox(ci, axis_rect(tc + ins * 1.0 * s, along_w, 24 * s, 26 * s), Color("d9d4ca"), Color("a8a196"), 2, 2)
			ci.draw_rect(axis_rect(tc, along_w, 22 * s, 2.4 * s), Color(0.62, 0.84, 0.95, 0.95))
			ci.draw_rect(axis_rect(tc - ins * 0.7 * s, along_w, 20 * s, 0.7 * s), Color(1, 1, 1, 0.85))
			var bell := tc + ins * 7.5 * s + along_w * 6.0 * s
			ci.draw_circle(bell, 2.8 * s, Color("b8912e"))
			ci.draw_circle(bell, 2.2 * s, Color("d8a63a"))
			ci.draw_circle(bell - Vector2(0.7, 0.7) * s, 0.9 * s, Color("f7e27a"))
			var out := -ins
			var awn := axis_rect(tc + out * 8.5 * s, along_w, 30 * s, 9 * s)
			ci.draw_rect(awn, Color("f4efe6"))
			for i in 5:
				var mid := tc + out * 8.5 * s + along_w * (-12.0 + i * 6.0) * s
				if i % 2 == 0:
					ci.draw_rect(axis_rect(mid, along_w, 6 * s, 9 * s), Color("c8403a"))
				half_disc(ci, mid + out * 4.5 * s, out, 3.0 * s, Color("c8403a") if i % 2 == 0 else Color("f4efe6"))
		"host":
			# a wooden podium: a brass nameplate on the guest side (the front) and the open booking book
			rbox(ci, inner.grow(-1 * s), Color("6e4526"), Color("4f3219"), 4)
			rbox(ci, inner.grow(-3.5 * s), Color("9a6a3f"), Color("7a4f2c"), 3, 1)
			ci.draw_rect(Rect2(inner.position.x + inner.size.x * 0.28, inner.position.y + 1.2 * s, inner.size.x * 0.44, 2.4 * s), Color("e0b64a"))
			var book := Rect2(inner.position.x + 5 * s, inner.position.y + 7 * s, inner.size.x - 10 * s, 12 * s)
			rbox(ci, book, Color("7a2a2a"), Color("5a1c1c"), 1, 1)
			var pg := book.grow(-1.2 * s)
			var half := pg.size.x / 2.0
			ci.draw_rect(Rect2(pg.position, Vector2(half - 0.4 * s, pg.size.y)), Color("f7f1e3"))
			ci.draw_rect(Rect2(pg.position + Vector2(half + 0.4 * s, 0), Vector2(half - 0.4 * s, pg.size.y)), Color("efe6d2"))
			for i in 3:
				var ly := pg.position.y + (2.2 + i * 2.8) * s
				ci.draw_line(Vector2(pg.position.x + 1.2 * s, ly), Vector2(pg.position.x + half - 1.2 * s, ly), Color("9a8f7e"), 0.7 * s)
				ci.draw_line(Vector2(pg.position.x + half + 1.2 * s, ly), Vector2(pg.end.x - 1.2 * s, ly), Color("9a8f7e"), 0.7 * s)
			ci.draw_line(inner.position + Vector2(inner.size.x - 7, inner.size.y - 3.5) * s, inner.position + Vector2(inner.size.x - 3, inner.size.y - 7.5) * s, Color("2b3a5a"), 1.4 * s)
		"till":
			# a counter with a retro register: the display faces the customers (the
			# front), the keys face the staff, and there's a tip jar
			rbox(ci, inner, Color("8b5a2b"), Color("5e3b1a"), 3)
			var reg := Rect2(inner.position + Vector2(3, 3.5) * s, Vector2(inner.size.x - 11 * s, inner.size.y - 7 * s))
			rbox(ci, reg, Color("3d4148"), Color("25282d"), 3, 1)
			rbox(ci, Rect2(reg.position + Vector2(2, 1.5) * s, Vector2(reg.size.x - 4 * s, 4.5 * s)), Color("1d2a22"), Color("111814"), 1, 1)
			ci.draw_rect(Rect2(reg.position + Vector2(3, 2.6) * s, Vector2(reg.size.x * 0.45, 2.2 * s)), Color("7df29a"))
			for ky in 3:
				for kx in 3:
					var kp := reg.position + Vector2(2.4 + kx * 3.6, 8.5 + ky * 3.0) * s
					ci.draw_rect(Rect2(kp, Vector2(2.6, 2.0) * s), Color("d8d0c2") if not (kx == 2 and ky == 2) else Color("e06b5e"))
			var jar := Vector2(inner.end.x - 4.5 * s, inner.position.y + 7 * s)
			ci.draw_circle(jar, 3.4 * s, Color(0.85, 0.93, 0.98, 0.9))
			ci.draw_arc(jar, 3.4 * s, 0, TAU, 14, Color("9fb7ca"), 0.8 * s, true)
			ci.draw_circle(jar + Vector2(0.6, 0.8) * s, 1.4 * s, Color("7fb24a"))
			ci.draw_circle(jar + Vector2(-1.0, -0.6) * s, 1.0 * s, Color("e0b64a"))
		"ice":
			# an ice machine from above: the bin full of cubes at the front, the ice maker at the back
			rbox(ci, inner, Color("c5ccd3"), Color("8d969f"), 4)
			var bin := Rect2(inner.position + Vector2(3, 2.5) * s, Vector2(inner.size.x - 6 * s, inner.size.y * 0.52))
			rbox(ci, bin, Color("e9f6fd"), Color("9fb7ca"), 3, 1)
			for i in 6:
				var cp := bin.position + Vector2(3.0 + (i % 3) * 6.2, 2.6 + floorf(i / 3.0) * 5.2) * s
				rbox(ci, Rect2(cp, Vector2(4.2, 3.8) * s), Color("cdeefd"), Color("8fc3e6"), 1, 1)
			ci.draw_rect(Rect2(inner.position.x + 3 * s, inner.end.y - 8.5 * s, inner.size.x - 6 * s, 5.5 * s), Color("a7b0b8"))
			ci.draw_rect(Rect2(inner.position.x + inner.size.x * 0.55, inner.end.y - 7.5 * s, 7 * s, 3.5 * s), Color("2a3a4a"))
			ci.draw_rect(Rect2(inner.position.x + inner.size.x * 0.55 + 1 * s, inner.end.y - 6.8 * s, 3.2 * s, 2 * s), Color("6ff2ff"))
	if f != null and f.broken:
		ci.draw_rect(inner, Color(0.1, 0.1, 0.12, 0.45))
		for o in [Vector2(-4, -6), Vector2(3, -9), Vector2(-1, -13)]:
			ci.draw_circle(r.get_center() + o * s, (3.5 + absf(o.y) * 0.15) * s, Color(0.35, 0.35, 0.38, 0.7))


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


## A worn path across a floor tile: faint scuffs that get darker with use.
static func scuff(ci: CanvasItem, c: Vector2i, amount: float, v: float) -> void:
	var r := Rect2(Vector2(c) * T, Vector2(T, T))
	var a := clampf((amount - 0.2) * 0.35, 0.0, 0.22)
	ci.draw_rect(r.grow(-2), Color(0.25, 0.2, 0.15, a * 0.5))
	for k in 3:
		var p := r.position + Vector2(6 + fmod(v * 97.0 + k * 11.0, 20.0), 6 + fmod(v * 53.0 + k * 7.0, 20.0))
		ci.draw_line(p, p + Vector2(5, 1.5), Color(0.2, 0.16, 0.12, a), 1.2)


## A car (or a bus) seen from above, driving right (dir 1) or left (-1).
static func car(ci: CanvasItem, p: Vector2, dir: int, col: Color, bus: bool = false) -> void:
	var l := 86.0 if bus else 48.0
	var w := 24.0 if bus else 22.0
	var r := Rect2(p - Vector2(l, w) / 2.0, Vector2(l, w))
	rbox(ci, Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 6, 0)
	rbox(ci, r, col, col.darkened(0.35), 6, 2)
	if bus:
		for i in 6:
			ci.draw_rect(Rect2(r.position + Vector2(8 + i * 12, 4), Vector2(9, w - 8)), Color("9fd4f0"))
		ci.draw_rect(Rect2(r.position + Vector2(0, w / 2 - 1), Vector2(l, 2)), col.darkened(0.2))
		return
	# roof and windscreens, the front one toward where it's going
	var front := 1.0 if dir > 0 else -1.0
	var roof := Rect2(p - Vector2(12, 8), Vector2(24, 16))
	rbox(ci, roof, col.darkened(0.12), col.darkened(0.12), 4, 0)
	ci.draw_rect(Rect2(p + Vector2(front * 12 - (4 if front < 0 else 0), -8), Vector2(4, 16)), Color("9fd4f0"))
	ci.draw_rect(Rect2(p + Vector2(-front * 12 - (3 if front > 0 else 0), -7), Vector2(3, 14)), Color("7fb4d6"))
	for k in [-1.0, 1.0]:
		ci.draw_circle(p + Vector2(front * (l / 2 - 2), k * (w / 2 - 4)), 2.2, Color("fff4c2"))


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
	var sc := dc + out * 27.0
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
	var op := dc + out * 12.0 - along * 40.0
	rbox(ci, Rect2(op - Vector2(15, 6), Vector2(30, 12)), Color("1f1a24"), Color("15121a"), 3, 1)
	var oc := Color("7df29a") if open else Color("ff6f6f")
	ci.draw_string(f, op + Vector2(-13, 4), "OPEN" if open else "CLOSED", HORIZONTAL_ALIGNMENT_CENTER, 26, 8, oc)
	# a brass plaque by the door for each step up in reputation
	if level > 0:
		var pp := dc + out * 12.0 + along * 50.0
		rbox(ci, Rect2(pp - Vector2(10, 8), Vector2(20, 16)), Color("d8a63a"), Color("8a6414"), 2, 1)
		for i in level:
			var sp := pp + Vector2((i - (level - 1) / 2.0) * 4.2, 0)
			ci.draw_circle(sp, 1.6, Color("fff4c2"))
	if hiring:
		var hp := dc + out * 12.0 - along * 72.0
		rbox(ci, Rect2(hp - Vector2(13, 7), Vector2(26, 14)), Color("fbfbf5"), Color("c8403a"), 2, 1)
		ci.draw_string(f, hp + Vector2(-12, -0.5), "NOW", HORIZONTAL_ALIGNMENT_CENTER, 24, 6, Color("c8403a"))
		ci.draw_string(f, hp + Vector2(-12, 5.5), "HIRING", HORIZONTAL_ALIGNMENT_CENTER, 24, 6, Color("3a2c25"))


static func wrench(ci: CanvasItem, p: Vector2, s: float, color: Color) -> void:
	ci.draw_line(p + Vector2(-4, 4) * s, p + Vector2(2, -2) * s, color, 2.4 * s)
	ci.draw_arc(p + Vector2(3.5, -3.5) * s, 3.0 * s, PI * 0.9, PI * 2.6, 10, color, 2.0 * s)
