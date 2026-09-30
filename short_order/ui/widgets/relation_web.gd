class_name RelationWeb
extends Control
## Who gets along, as a picture: everyone's face around a circle, and a line
## between two people when they feel something about each other.
##   thick green + heart   best friends
##   green                 friends
##   faint green           friendly
##   dashed orange         tense
##   thick red + bolt      rivals
## No line means they're neutral (friendly lines only show for the person you
## hover or pick, to keep it readable). Each face is ringed in its mood's colour.
## Hover a face to see only their lines; hover a line for the reasons; click a
## face to show only their part of the staff log.

signal person_clicked(who)

const Art = preload("res://world/art.gd")
const STYLE := {
	"best": {"color": Color("4fd99a"), "width": 4.0},
	"friends": {"color": Color("6cc3a0"), "width": 2.6},
	"friendly": {"color": Color(0.42, 0.76, 0.63, 0.45), "width": 1.4},
	"tense": {"color": Color("e0923a"), "width": 2.0, "dashed": true},
	"rivals": {"color": Color("e75a4e"), "width": 3.6},
}

var hover_person := -1
var hover_pair := Vector2i(-1, -1)
var selected := -1
var _pos: Array = []
var _face := 30.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = " "
	custom_minimum_size = Vector2(0, 300)
	Crew.changed.connect(queue_redraw)
	GameState.staff_changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func team() -> Array:
	return Crew.team()


func _layout() -> void:
	var t := team()
	var n := t.size()
	_pos = []
	_face = clampf(220.0 / maxf(1.0, sqrt(n) * 2.2), 18.0, 34.0)
	var h := clampf(size.x * 0.9, 220.0, 380.0)
	if absf(custom_minimum_size.y - h) > 1.0:
		custom_minimum_size = Vector2(0, h)
	var c := Vector2(size.x / 2.0, h / 2.0)
	var r := minf(size.x, h) / 2.0 - _face * 0.9 - 8.0
	for i in n:
		var a := -PI / 2.0 + TAU * i / maxf(1.0, n)
		_pos.append(c + Vector2.from_angle(a) * (r if n > 1 else 0.0))


func person_at(p: Vector2) -> int:
	for i in _pos.size():
		if p.distance_to(_pos[i]) <= _face * 0.6:
			return i
	return -1


func pair_at(p: Vector2) -> Vector2i:
	var t := team()
	var best := Vector2i(-1, -1)
	var best_d := 7.0
	for i in t.size():
		for j in range(i + 1, t.size()):
			var l := Crew.label(t[i], t[j])
			if l == "neutral" or not _shown(i, j) or (l == "friendly" and hover_person < 0 and selected < 0):
				continue
			var q := Geometry2D.get_closest_point_to_segment(p, _pos[i], _pos[j])
			var d := q.distance_to(p)
			if d < best_d:
				best_d = d
				best = Vector2i(i, j)
	return best


func _shown(i: int, j: int) -> bool:
	var focus := hover_person if hover_person >= 0 else selected
	return focus < 0 or focus == i or focus == j


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p := (event as InputEventMouseMotion).position
		var hp := person_at(p)
		var pp := pair_at(p) if hp < 0 else Vector2i(-1, -1)
		if hp != hover_person or pp != hover_pair:
			hover_person = hp
			hover_pair = pp
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var i := person_at((event as InputEventMouseButton).position)
		var t := team()
		if i >= 0 and i < t.size():
			selected = -1 if selected == i else i
			person_clicked.emit(t[i])
			queue_redraw()
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_person = -1
		hover_pair = Vector2i(-1, -1)
		queue_redraw()


func _get_tooltip(p: Vector2) -> String:
	var t := team()
	var i := person_at(p)
	if i >= 0 and i < t.size():
		var s = t[i]
		var lines: Array = ["%s, %s. Mood: %s (stress %d%%)." % [s.person_name, Data.ROLES[s.role]["name"].to_lower(), Crew.MOOD_NAMES.get(s.mood, "Okay"), int(s.stress)]]
		var sm := Crew.summary(s)
		lines.append(sm if sm != "" else "No close friends or rivals yet.")
		lines.append("Click to show only their part of the log.")
		return "\n".join(lines)
	var pr := pair_at(p)
	if pr.x < 0:
		return ""
	var a = t[pr.x]
	var b = t[pr.y]
	var out: Array = ["%s and %s: %s" % [a.person_name, b.person_name, Crew.LABEL_NAMES[Crew.label(a, b)]]]
	for pq in [[a, b], [b, a]]:
		var v := int(round(Crew.opinion(pq[0], pq[1])))
		var why: Array = Crew.reasons(pq[0], pq[1]).slice(0, 3).map(func(r): return "%s %+d" % [r[0], int(round(r[1]))])
		out.append("%s thinks %s of %s: %s" % [pq[0].person_name, "well" if v >= 10 else ("badly" if v <= -10 else "nothing much"), pq[1].person_name, ", ".join(why) if not why.is_empty() else "no reason yet"])
	return "\n".join(out)


func _draw() -> void:
	_layout()
	var t := team()
	var n := t.size()
	if n == 0:
		return
	var focus := hover_person if hover_person >= 0 else selected
	# the lines first, weakest underneath
	var pairs: Array = []
	for i in n:
		for j in range(i + 1, n):
			var l := Crew.label(t[i], t[j])
			if l == "neutral" or (l == "friendly" and focus != i and focus != j):
				continue
			pairs.append([["friendly", "tense", "friends", "rivals", "best"].find(l), i, j, l])
	pairs.sort_custom(func(x, y): return x[0] < y[0])
	for pr in pairs:
		var i: int = pr[1]
		var j: int = pr[2]
		var st: Dictionary = STYLE[pr[3]]
		var col: Color = st["color"]
		var w: float = st["width"]
		if focus >= 0 and focus != i and focus != j:
			col.a *= 0.12
		elif hover_pair == Vector2i(i, j):
			w += 2.0
		var a: Vector2 = _pos[i]
		var b: Vector2 = _pos[j]
		if st.get("dashed", false):
			draw_dashed_line(a, b, col, w, 6.0, true, true)
		else:
			draw_line(a, b, col, w, true)
		if (pr[3] == "best" or pr[3] == "rivals") and col.a > 0.5:
			var m := (a + b) / 2.0
			draw_circle(m, 8.0, Color("201915"))
			draw_arc(m, 8.0, 0, TAU, 16, col, 1.5, true)
			var ic: Texture2D = UiKit.icon("heart" if pr[3] == "best" else "storm")
			draw_texture_rect(ic, Rect2(m - Vector2(5.5, 5.5), Vector2(11, 11)), false, col)
	# then the faces, with their names
	var font := get_theme_default_font()
	for i in n:
		var s = t[i]
		var r := Rect2(_pos[i] - Vector2(_face, _face) / 2.0, Vector2(_face, _face))
		var dim: bool = focus >= 0 and focus != i and not _linked(focus, i)
		draw_circle(r.get_center(), _face / 2.0 + 2.5, Crew.MOOD_COLORS.get(s.mood, UiKit.MUTED) * Color(1, 1, 1, 0.35 if dim else 1.0))
		draw_circle(r.get_center(), _face / 2.0, Color("201915"))
		Art.portrait(self, r, s.skin, s.hair, s.shirt, true, s.look, s.style)
		if dim:
			draw_circle(r.get_center(), _face / 2.0 + 3.0, Color(0.12, 0.09, 0.08, 0.6))
		if s.manager:
			draw_circle(r.position + Vector2(_face - 3, 3), 5.0, Color("f2c14e"))
			draw_circle(r.position + Vector2(_face - 3, 3), 2.0, Color("fff4c2"))
		if i == focus:
			draw_arc(r.get_center(), _face / 2.0 + 5.0, 0, TAU, 32, Color("f5ecdf"), 1.5, true)
		var nm: String = s.person_name.split(" ")[0]
		var fs := 11 if _face >= 26.0 else 10
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp: Vector2 = _pos[i] + Vector2(-tw / 2.0, _face / 2.0 + 13.0)
		draw_string_outline(font, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.1, 0.08, 0.07, 0.9))
		draw_string(font, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f5ecdf") if not dim else Color("7d6d61"))


func _linked(a: int, b: int) -> bool:
	var t := team()
	if a < 0 or b < 0 or a >= t.size() or b >= t.size():
		return false
	return Crew.label(t[a], t[b]) != "neutral"
