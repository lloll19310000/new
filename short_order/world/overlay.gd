extends Node2D
## Things that float above everyone: order bubbles over tables, "ready to
## order" notes, wrenches over broken stations, sleepy staff on breaks, staff
## speech bubbles (from the Crew autoload) and phones you can click to catch.
## Also owns the evening light: the world gets darker after 18:00 and
## lamps and neon signs glow.

const Art = preload("res://world/art.gd")
const BUBBLE_ICON_COLORS := {"heart": Color("e0578f"), "storm": Color("c9473d"), "alert": Color("d98a1f"),
	"chat": Color("5b7896"), "phone": Color("3f86c6"), "music": Color("8a5cc2"), "sparkle": Color("d9a21f")}

var main
var t := 0.0
var glow: Node2D
var night: CanvasModulate


func _ready() -> void:
	z_index = 10
	glow = Node2D.new()
	glow.name = "Glow"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.z_index = -1
	glow.draw.connect(_draw_glow)
	add_child(glow)
	night = CanvasModulate.new()
	night.name = "Evening"
	main.add_child.call_deferred(night)


func evening() -> float:
	## 0 in daylight, 1 at night.
	if GameState.phase == GameState.Phase.PLANNING:
		return 0.0
	return clampf((GameState.minute - 18.0 * 60.0) / 180.0, 0.0, 1.0)


func _process(delta: float) -> void:
	t += delta
	if GameState.sim_speed() > 0.0:
		Crew.tick_bubbles(delta)
	queue_redraw()
	var e := evening()
	if night != null:
		var c := Color.WHITE.lerp(Color(0.62, 0.62, 0.8), e)
		if Events.raining and GameState.phase != GameState.Phase.PLANNING:
			c = c * Color(0.86, 0.88, 0.95)
		if not Events.powered():
			c = c * Color(0.62, 0.62, 0.72)
		night.color = c
	if not Events.powered():
		e = 0.0
	if e > 0.0 or glow.visible:
		glow.visible = e > 0.0
		glow.queue_redraw()


func _draw_glow() -> void:
	var e := evening()
	for f in main.lot.furniture:
		if not f.info().get("glow", false):
			continue
		var c: Vector2 = f.center_px()
		var col := Color(1.0, 0.75, 0.4) if f.type == "lamp" else Color(1.0, 0.35, 0.65)
		if f.on_wall():
			# a sign on a wall only lights up the room it faces
			var d := Vector2(Data.DIRS[main.lot.inside_dir(f)])
			for i in 6:
				Art.half_disc(glow, c + d * 6.0, d, 18.0 + i * 12.0, Color(col.r, col.g, col.b, 0.05 * e))
			continue
		for i in 6:
			var r := 18.0 + i * 12.0
			glow.draw_circle(c, r, Color(col.r, col.g, col.b, 0.05 * e))


func _draw() -> void:
	var lot = main.lot
	# table numbers (they match the kitchen tickets) and booked tables
	var num_font := Art.font()
	for t in lot.tables():
		if t.is_counter():
			continue
		var n: int = lot.table_number(t)
		var corner: Vector2 = t.rect_px().position + Vector2(5, 11)
		draw_string_outline(num_font, corner, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.2, 0.13, 0.08, 0.85))
		draw_string(num_font, corner, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fbf3e0"))
		if t.reserved != null and t.group == null:
			var c: Vector2 = t.center_px()
			Art.rbox(self, Rect2(c - Vector2(13, 7), Vector2(26, 14)), Color("fbfbf5"), Color("c8403a"), 2, 1)
			draw_string(num_font, c + Vector2(-11, 4), "RSVD", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("c8403a"))
	for g in main.groups:
		if not is_instance_valid(g):
			continue
		if g.state == "paying" or g.state == "complaining":
			var at: Vector2 = (g.pay_spot.center_px() if g.pay_spot != null else (g.table.center_px() if g.table != null else g.members[0].position)) + Vector2(0, -12)
			var pl: float = g.patience_left()
			var bcol := Color("d9463b").lerp(Color("4f9a6a"), clampf(pl, 0.0, 1.0))
			var rb := Art.bubble(self, at + Vector2(0, sin(t * 4.0 + g.get_instance_id()) * 1.5), Vector2(22, 20), Color("fbf8f1"), bcol)
			draw_texture_rect(UiKit.icon("alert" if g.state == "complaining" else "money"), Rect2(rb.position + Vector2(4, 3), Vector2(14, 14)), false,
				Color("d9463b") if g.state == "complaining" else Color("3f8f5a"))
			continue
		if g.table == null:
			continue
		var tip: Vector2
		if g.takeout:
			var out: Vector2i = lot.window_outside(g.table)
			tip = lot.cell_center(out) + Vector2(0, -16)
		else:
			tip = g.table.center_px() + Vector2(0, -10)
		var p: float = g.patience_left()
		var border := Color("d9463b").lerp(Color("4f9a6a"), clampf(p, 0.0, 1.0)) if p >= 0.0 else Color("3a2c25")
		match g.state:
			"seated":
				var bob := sin(t * 4.0) * 1.5
				var r := Art.bubble(self, tip + Vector2(0, bob), Vector2(24, 20), Color("fbf8f1"), border)
				# a little order pad
				var pad := Rect2(r.get_center() - Vector2(5, 6), Vector2(10, 12))
				draw_rect(pad, Color("ffffff"))
				draw_rect(pad, Color("9a8f84"), false, 1.0)
				for i in 3:
					draw_line(pad.position + Vector2(2, 3 + i * 3), pad.position + Vector2(8, 3 + i * 3), Color("9a8f84"), 1.0)
			"ordered":
				var left: Array = g.waiting_for()
				if left.is_empty():
					continue
				var shown := mini(left.size(), 4)
				var w := 8.0 + shown * 15.0 + (12.0 if left.size() > 4 else 0.0)
				var r := Art.bubble(self, tip, Vector2(w, 22), Color("fbf8f1"), border)
				for i in shown:
					Art.dish(self, left[i], r.position + Vector2(11.5 + i * 15.0, 11), 0.72)
				if left.size() > 4:
					draw_string(Art.font(), r.position + Vector2(w - 13, 15), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3a2c25"))
	# steam over hot food on the pass; food that's been sitting there gets a chilly blue ring
	for f in lot.of_type("pass"):
		for i in f.items.size():
			var it: Dictionary = f.items[i]
			var age: float = GameState.minute - it.get("t", GameState.minute)
			var p: Vector2 = Art.pass_slot(f.rect_px(), i)
			if age <= Data.PASS_HOT:
				for k in 2:
					var ph := fmod(t * 0.9 + i * 0.37 + k * 0.5, 1.0)
					var sp: Vector2 = p + Vector2(sin(ph * 6.0 + i) * 2.0 + (k - 0.5) * 3.0, -6.0 - ph * 10.0)
					draw_circle(sp, 1.6 + ph * 1.2, Color(1, 1, 1, 0.45 * (1.0 - ph)))
			elif age > Data.PASS_COLD:
				draw_arc(p, 6.5, 0, TAU, 14, Color(0.45, 0.7, 1.0, 0.8), 1.4, true)
	for f in lot.furniture:
		if f.broken:
			var bob := sin(t * 3.0 + f.id) * 2.0
			var r := Art.bubble(self, f.center_px() + Vector2(0, -12 + bob), Vector2(22, 20), Color("fff1e6"), Color("d9463b"))
			Art.wrench(self, r.get_center(), 1.0, Color("d9463b"))
	for s in GameState.staff:
		if not is_instance_valid(s) or not s.on_break:
			continue
		for i in 2:
			var k := fmod(t * 0.7 + i * 0.5, 1.0)
			var zp: Vector2 = s.position + Vector2(8 + k * 8, -16 - k * 14)
			draw_string(Art.font(), zp, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11 + int(k * 4), Color(0.25, 0.3, 0.45, 1.0 - k))
	if Stock.van_until >= 0.0 and GameState.is_active() and GameState.minute < Stock.van_until:
		var vx := float(lot.entry_door.x if lot.has_entry() else lot.W / 2)
		Art.van(self, Vector2((vx + 3.5) * Data.TILE, (Data.SIDEWALK_Y + 1.5) * Data.TILE))
	draw_staff_bubbles()
	if Events.raining and (GameState.phase == GameState.Phase.SERVICE or GameState.phase == GameState.Phase.CLEANUP):
		draw_rain()


## Rain streaks over the whole lot.
func draw_rain() -> void:
	var w := float(main.lot.W * Data.TILE)
	var h := float(main.lot.H * Data.TILE)
	var col := Color(0.75, 0.82, 0.95, 0.35)
	for i in 180:
		var x := fmod(i * 97.13 + t * 40.0, w)
		var y := fmod(i * 53.71 + t * 420.0 + i * 13.0, h)
		draw_line(Vector2(x, y), Vector2(x - 3.0, y + 11.0), col, 1.0)


## Speech bubbles over staff, and a phone over anyone sneaking a look at theirs.
func draw_staff_bubbles() -> void:
	var talking := {}
	var used: Array[Rect2] = []
	for b in Crew.bubbles:
		var s = b["who"]
		if not is_instance_valid(s):
			continue
		talking[s] = true
		var a := clampf(b["t"] / 0.35, 0.0, 1.0)
		var text: String = b["text"]
		var font := Art.font()
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x if text != "" else 0.0
		var w := 22.0 + (tw + 4.0 if tw > 0.0 else 0.0)
		# nudge a bubble up if it would cover one already drawn
		var tip: Vector2 = s.position + Vector2(0, -15)
		for i in 3:
			var probe := Rect2(tip - Vector2(w / 2.0, 24), Vector2(w, 18))
			var hit := false
			for u in used:
				if u.intersects(probe):
					hit = true
			if not hit:
				break
			tip.y -= 21.0
		var r := Art.bubble(self, tip, Vector2(w, 18), Color(0.984, 0.973, 0.945, a), Color(0.23, 0.17, 0.15, a))
		used.append(r)
		if tip.y < s.position.y - 16.0:
			draw_line(s.position + Vector2(0, -10), tip, Color(0.23, 0.17, 0.15, 0.5 * a), 1.0)
		var col: Color = BUBBLE_ICON_COLORS.get(b["icon"], Color("5b7896"))
		col.a = a
		draw_texture_rect(UiKit.icon(b["icon"]), Rect2(r.position + Vector2(4, 2), Vector2(14, 14)), false, col)
		if text != "":
			draw_string(font, r.position + Vector2(20, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.23, 0.17, 0.15, a))
	for s in GameState.staff:
		if not is_instance_valid(s) or not s.on_phone or talking.has(s):
			continue
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		var border := Color("3f86c6").lerp(Color("9fd0ff"), pulse)
		var r := Art.bubble(self, s.position + Vector2(0, -15 + sin(t * 3.0)), Vector2(20, 18), Color("fbf8f1"), border)
		draw_texture_rect(UiKit.icon("phone"), Rect2(r.position + Vector2(3, 2), Vector2(14, 14)), false, Color("3f86c6"))
