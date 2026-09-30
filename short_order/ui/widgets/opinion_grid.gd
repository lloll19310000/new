class_name OpinionGrid
extends Control
## Everyone's opinion of everyone, as a grid of squares. Each row is how that
## person feels about each column. The colour is the pair's label (friends,
## rivals...). Hover a square for the reasons; click a face to filter the log.

signal person_clicked(who)

const Art = preload("res://world/art.gd")
const FACE := 24.0
const GAP := 3.0

var cell := 24.0
var hover := Vector2i(-1, -1)      # (column, row) under the mouse; -1 on a header face


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = " "
	Crew.changed.connect(refresh)
	GameState.staff_changed.connect(refresh)
	resized.connect(_fit)
	refresh()


func team() -> Array:
	return Crew.team()


func _fit() -> void:
	var n := maxi(team().size(), 1)
	var avail := size.x if size.x > 10.0 else 300.0
	var c := clampf(floorf((avail - FACE - GAP * 2.0) / n) - GAP, 14.0, 30.0)
	if c != cell:
		cell = c
	custom_minimum_size = Vector2(0, FACE + GAP * 2.0 + team().size() * (cell + GAP))
	queue_redraw()


func refresh() -> void:
	_fit()


func top() -> float:
	return FACE + GAP * 2.0


func cell_rect(row: int, col: int) -> Rect2:
	return Rect2(Vector2(top() + col * (cell + GAP), top() + row * (cell + GAP)), Vector2(cell, cell))


## (col, row) at a point: row -1 = the faces along the top, col -1 = the faces down the side.
func at(p: Vector2) -> Vector2i:
	var n := team().size()
	var col := -1 if p.x < top() else int((p.x - top()) / (cell + GAP))
	var row := -1 if p.y < top() else int((p.y - top()) / (cell + GAP))
	if col >= n or row >= n or (col < 0 and row < 0):
		return Vector2i(-2, -2)
	return Vector2i(col, row)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := at((event as InputEventMouseMotion).position)
		if h != hover:
			hover = h
			queue_redraw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var h := at((event as InputEventMouseButton).position)
		var t := team()
		var i := h.x if h.y < 0 else (h.y if h.x < 0 else h.y)
		if h.x >= -1 and i >= 0 and i < t.size():
			person_clicked.emit(t[i])
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = Vector2i(-1, -1)
		queue_redraw()


func _get_tooltip(p: Vector2) -> String:
	var h := at(p)
	var t := team()
	if h.x < 0 and h.y >= 0 and h.y < t.size():
		return "%s: click to show only their part of the log." % t[h.y].person_name
	if h.y < 0 and h.x >= 0 and h.x < t.size():
		return "%s: click to show only their part of the log." % t[h.x].person_name
	if h.x < 0 or h.y < 0 or h.x == h.y:
		return ""
	var a = t[h.y]
	var b = t[h.x]
	var v := int(round(Crew.opinion(a, b)))
	var lines: Array = ["%s → %s: %s (%s)" % [a.person_name, b.person_name, signed(v), Crew.LABEL_NAMES[Crew.label(a, b)]]]
	for r in Crew.reasons(a, b).slice(0, 6):
		lines.append("   %s  %s" % [r[0], signed(int(round(r[1])))])
	lines.append("%s → %s: %s" % [b.person_name, a.person_name, signed(int(round(Crew.opinion(b, a))))])
	return "\n".join(lines)


static func signed(v: int) -> String:
	if v > 0:
		return "+%d" % v
	if v < 0:
		return "−%d" % absi(v)
	return "0"


func _draw() -> void:
	var t := team()
	var n := t.size()
	if n == 0:
		return
	var font := get_theme_default_font()
	var fs := 10 if cell >= 22.0 else 9
	for i in n:
		var off := (cell - FACE) / 2.0
		face(t[i], Rect2(Vector2(top() + i * (cell + GAP) + off, 0), Vector2(FACE, FACE)), hover.x == i and hover.y < 0)
		face(t[i], Rect2(Vector2(0, top() + i * (cell + GAP) + off), Vector2(FACE, FACE)), hover.y == i and hover.x < 0)
	for r in n:
		for c in n:
			var rect := cell_rect(r, c)
			if r == c:
				draw_line(rect.position + Vector2(5, 5), rect.end - Vector2(5, 5), Color(1, 1, 1, 0.08), 1.5)
				continue
			var col: Color = Crew.LABEL_COLORS[Crew.label(t[r], t[c])]
			var hot := hover == Vector2i(c, r)
			var line_hot := hover.x == c or hover.y == r
			Art.rbox(self, rect, col.lightened(0.08) if line_hot else col, Color("f5ecdf") if hot else col.darkened(0.25), 4, 2 if hot else 1)
			var v := int(round(Crew.opinion(t[r], t[c])))
			var ink := Color("f5ecdf") if col.get_luminance() < 0.45 else Color("201915")
			draw_string(font, rect.position + Vector2(0, cell / 2.0 + fs * 0.36), signed(v), HORIZONTAL_ALIGNMENT_CENTER, cell, fs, ink)


func face(s, r: Rect2, hot: bool) -> void:
	draw_circle(r.get_center(), r.size.x / 2.0, Color("201915"))
	Art.portrait(self, r, s.skin, s.hair, s.shirt, true, s.look)
	var ring := Color("f2c14e") if s.manager else (Color("f5ecdf") if hot else Color(0, 0, 0, 0))
	if ring.a > 0.0:
		draw_arc(r.get_center(), r.size.x / 2.0 - 0.5, 0, TAU, 24, ring, 1.5, true)
