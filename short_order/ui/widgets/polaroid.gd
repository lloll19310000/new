class_name Polaroid
extends Control
## A snapshot pinned to the day report: a white-bordered photo, slightly
## tilted, with a handwritten-style caption. kind is "best", "worst" or "mvp";
## data comes from the report ({who, what, score, at} or the MVP's looks).

const Art = preload("res://world/art.gd")
const PAPER := Color("f6f1e6")
const INK_DARK := Color("3a2e26")

var kind := "best"
var data: Dictionary = {}
var tilt := 0.0
var title := ""
var caption := ""


func _ready() -> void:
	custom_minimum_size = Vector2(136, 192)
	mouse_filter = Control.MOUSE_FILTER_PASS


func show_moment(k: String, d: Dictionary, t: float) -> void:
	kind = k
	data = d.duplicate()
	if data.has("what") and data["what"] != "":
		data["what"] = String(data["what"])[0].to_lower() + String(data["what"]).substr(1)
	d = data
	tilt = t
	match kind:
		"best":
			title = "Best moment"
			caption = "No reviews today." if d.is_empty() else "%s gave %.1f stars for the %s. (%s)" % [d["who"], d["score"], d["what"], d["at"]]
		"worst":
			title = "Worst moment"
			if d.is_empty():
				caption = "Nobody left unhappy. Nice."
			elif d.get("left", false):
				caption = "%s walked out: %s. (%s)" % [d["who"], d["what"], d["at"]]
			else:
				caption = "%s gave %.1f stars over %s. (%s)" % [d["who"], d["score"], d["what"], d["at"]]
		"mvp":
			title = "MVP of the day"
			caption = "Nobody worked today." if d.is_empty() else "%s, %s: %d jobs done." % [d["name"], Data.ROLES[d["role"]]["name"].to_lower(), d["jobs"]]
	tooltip_text = "%s: %s" % [title, caption]
	queue_redraw()


func _draw() -> void:
	var w := size.x - 10.0
	var h := size.y - 10.0
	draw_set_transform(size / 2.0, tilt, Vector2.ONE)
	var card := Rect2(Vector2(-w / 2.0, -h / 2.0), Vector2(w, h))
	draw_rect(Rect2(card.position + Vector2(3, 4), card.size), Color(0, 0, 0, 0.35))
	draw_rect(card, PAPER)
	var photo := Rect2(card.position + Vector2(8, 8), Vector2(w - 16, w - 22))
	var bg: Color = {"best": Color("f2c14e"), "worst": Color("4a5a78"), "mvp": Color("6cc3a0")}[kind]
	draw_rect(photo, bg.darkened(0.25) if not data.is_empty() else Color("6d5f55"))
	# a soft vignette
	draw_rect(Rect2(photo.position, Vector2(photo.size.x, photo.size.y * 0.35)), Color(1, 1, 1, 0.08))
	var c := photo.get_center()
	if not data.is_empty():
		match kind:
			"mvp":
				var pr := Rect2(c - Vector2(34, 34), Vector2(68, 68))
				Art.portrait(self, pr, data["skin"], data["hair"], data["shirt"], true, data.get("look", ""), Art.style_for(hash(str(data.get("name", "")))))
				_icon("star", Rect2(photo.end - Vector2(24, 24), Vector2(18, 18)), Color("fff4c2"))
			"best":
				_icon("star", Rect2(c - Vector2(26, 30), Vector2(52, 52)), Color("fff4c2"))
				_text("%.1f" % data["score"], c + Vector2(0, 36), 15, Color("3a2e26"))
			"worst":
				_icon("walkout" if data.get("left", false) else "storm", Rect2(c - Vector2(24, 30), Vector2(48, 48)), Color("dfe7f2"))
				_text("walked out" if data.get("left", false) else "%.1f" % data["score"], c + Vector2(0, 36), 13, Color("dfe7f2"))
	else:
		_icon({"best": "star", "worst": "check", "mvp": "staff"}[kind], Rect2(c - Vector2(20, 20), Vector2(40, 40)), Color(1, 1, 1, 0.5))
	# the caption
	var font := get_theme_default_font()
	var y := photo.end.y + 14.0
	draw_string(font, Vector2(card.position.x + 8, y), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 16, 10, Color("a0522d"))
	draw_multiline_string(font, Vector2(card.position.x + 8, y + 13), caption, HORIZONTAL_ALIGNMENT_LEFT, w - 16, 10, 4, INK_DARK)
	# a strip of tape
	draw_rect(Rect2(Vector2(-18, card.position.y - 5), Vector2(36, 11)), Color(1, 0.96, 0.8, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _icon(n: String, r: Rect2, col: Color) -> void:
	draw_texture_rect(UiKit.icon(n), r, false, col)


func _text(t: String, at: Vector2, fs: int, col: Color) -> void:
	var font := get_theme_default_font()
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at - Vector2(tw / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
