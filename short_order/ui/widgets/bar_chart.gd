class_name BarChart
extends Control
## A small chart drawn in code: bars (green up, red down), with an optional
## line on top, a zero line and a few labels. Used by the Books tab.

var values: Array = []          # bar heights
var labels: Array = []          # one short label per bar (every few are shown)
var line: Array = []            # an optional line (same length), on its own scale
var line_color := Color("f2c14e")
var bar_color := Color("6cc3a0")
var neg_color := Color("e75a4e")
var horizontal := false         # bars sideways, labelled (for the dishes)
var fmt := "$%d"


func _ready() -> void:
	custom_minimum_size = Vector2(0, 110)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_data(v: Array, l: Array = [], ln: Array = []) -> void:
	values = v
	labels = l
	line = ln
	if horizontal:
		custom_minimum_size.y = 18.0 * maxi(1, values.size()) + 4.0
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18))
	if values.is_empty():
		draw_string(font, Vector2(8, size.y / 2.0), "Nothing yet: it fills in as the days go by.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiKit.MUTED)
		return
	if horizontal:
		var top := 0.001
		for v in values:
			top = maxf(top, float(v))
		for i in values.size():
			var y := 2.0 + i * 18.0
			var lw := 90.0
			draw_string(font, Vector2(4, y + 12), str(labels[i]) if i < labels.size() else "", HORIZONTAL_ALIGNMENT_LEFT, lw - 6, 11, UiKit.INK)
			var w := (size.x - lw - 40.0) * float(values[i]) / top
			draw_rect(Rect2(Vector2(lw, y + 3), Vector2(maxf(1.0, w), 11)), bar_color)
			draw_string(font, Vector2(lw + w + 4, y + 12), str(int(values[i])), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.MUTED)
		return
	var hi := 0.001
	var lo := 0.0
	for v in values:
		hi = maxf(hi, float(v))
		lo = minf(lo, float(v))
	var span := hi - lo
	var plot := Rect2(Vector2(4, 14), size - Vector2(8, 30))
	var zero_y := plot.position.y + plot.size.y * hi / span
	var bw := plot.size.x / values.size()
	for i in values.size():
		var v: float = values[i]
		var h := plot.size.y * absf(v) / span
		var x := plot.position.x + i * bw + 1.0
		var r := Rect2(Vector2(x, zero_y - h if v >= 0.0 else zero_y), Vector2(maxf(1.0, bw - 2.0), h))
		draw_rect(r, bar_color if v >= 0.0 else neg_color)
		var every := maxi(1, values.size() / 7)
		if i < labels.size() and i % every == 0:
			draw_string(font, Vector2(x, size.y - 3), str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiKit.FAINT)
	draw_line(Vector2(plot.position.x, zero_y), Vector2(plot.end.x, zero_y), Color(1, 1, 1, 0.25), 1.0)
	draw_string(font, Vector2(plot.position.x, 11), fmt % int(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.MUTED)
	if lo < 0.0:
		draw_string(font, Vector2(plot.end.x - 60, 11), ("low " + fmt) % int(lo), HORIZONTAL_ALIGNMENT_RIGHT, 60, 10, UiKit.CHERRY)
	if line.size() >= 2:
		var lhi := 0.001
		var llo := 999999.0
		for v in line:
			lhi = maxf(lhi, float(v))
			llo = minf(llo, float(v))
		var pts := PackedVector2Array()
		for i in line.size():
			var t := (float(line[i]) - llo) / maxf(0.001, lhi - llo)
			pts.append(Vector2(plot.position.x + (i + 0.5) * bw, plot.end.y - t * plot.size.y))
		draw_polyline(pts, line_color, 2.0, true)
