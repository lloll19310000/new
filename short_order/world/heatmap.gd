extends Node2D
## The map overlays you can switch on (the eye buttons above the build bar,
## or V to cycle): where it's dirty, where people walk, how long each table
## has been waiting, and how worn each station is.

const MODES := ["", "dirt", "traffic", "waits", "wear"]
const NAMES := {"dirt": "Dirt", "traffic": "Foot traffic", "waits": "Table waits", "wear": "Station wear"}
const LEGENDS := {
	"dirt": "Brown to red: how dirty each floor tile is. Cleaners go where it's reddest.",
	"traffic": "Where people walk most today: busy lanes wear the floor. Keep them short and clear.",
	"waits": "Minutes each table has waited for its order and food: green is fine, red is unhappy.",
	"wear": "How worn each station is: worn ones break down more. Repairs reset it.",
}

var lot
var mode := ""
var _t := 0.0


func _ready() -> void:
	z_index = 5


func set_mode(m: String) -> void:
	mode = m if m in MODES else ""
	visible = mode != ""
	queue_redraw()


func cycle() -> void:
	set_mode(MODES[(MODES.find(mode) + 1) % MODES.size()])


func _process(delta: float) -> void:
	if mode == "":
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		queue_redraw()


func _draw() -> void:
	if lot == null or mode == "":
		return
	var tile := float(Data.TILE)
	var font := ThemeDB.fallback_font
	match mode:
		"dirt":
			for y in lot.H:
				for x in lot.W:
					var c := Vector2i(x, y)
					var v: float = lot.dirt[lot.idx(c)]
					if v < 0.03:
						continue
					var col := Color("8a5a2b").lerp(Color("e0402a"), clampf(v * 1.4, 0.0, 1.0))
					col.a = clampf(0.15 + v * 0.6, 0.0, 0.7)
					draw_rect(Rect2(Vector2(c) * tile, Vector2(tile, tile)), col)
		"traffic":
			# scale to the busy lanes, not the single busiest tile (the door)
			var vals: Array = []
			for v in lot.scuff:
				if v > 0.0:
					vals.append(v)
			vals.sort()
			var top: float = maxf(0.001, vals[int(vals.size() * 0.85)] if not vals.is_empty() else 0.001)
			for y in lot.H:
				for x in lot.W:
					var c := Vector2i(x, y)
					var v: float = minf(1.0, lot.scuff[lot.idx(c)] / top)
					if v < 0.08:
						continue
					var col := Color("3d7fd9").lerp(Color("f2d04e"), clampf(v, 0.0, 1.0))
					col.a = clampf(0.12 + v * 0.55, 0.0, 0.65)
					draw_rect(Rect2(Vector2(c) * tile, Vector2(tile, tile)), col)
		"waits":
			for f in lot.furniture:
				if not f.is_table():
					continue
				var g = f.group
				var r: Rect2 = f.rect_px()
				if g == null or not is_instance_valid(g):
					draw_rect(r.grow(2), Color(0.5, 0.5, 0.5, 0.25))
					continue
				var m: float = g.order_wait + g.food_wait
				var col := Color("4fbf7a") if m < 10.0 else (Color("f2c14e") if m < 25.0 else Color("e75a4e"))
				draw_rect(r.grow(2), Color(col, 0.35))
				draw_rect(r.grow(2), col, false, 2.0)
				_label(font, r.get_center(), "%d min" % int(m), col)
		"wear":
			for f in lot.furniture:
				if not f.is_station() and f.wear <= 0.0 and not f.broken:
					continue
				var r: Rect2 = f.rect_px()
				var w: float = f.wear
				var col := Color("4fbf7a").lerp(Color("f2c14e"), clampf(w * 2.0, 0.0, 1.0)).lerp(Color("e75a4e"), clampf(w * 2.0 - 1.0, 0.0, 1.0))
				if f.broken:
					col = Color("e75a4e")
				draw_rect(r, Color(col, 0.35))
				draw_rect(r, col, false, 2.0)
				_label(font, r.get_center(), "broken" if f.broken else "%d%%" % int(w * 100), col)


func _label(font: Font, at: Vector2, text: String, col: Color) -> void:
	var fs := 11
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := at + Vector2(-tw / 2.0, 4)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.1, 0.08, 0.07, 0.9))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col.lightened(0.3))
