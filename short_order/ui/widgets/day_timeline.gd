class_name DayTimeline
extends Control
## A thin bar for today's opening hours with the rushes marked, and a
## marker for the time right now.

const RUSH := Color("e2703a")
const QUIET := Color("5f8fb8")
const TRACK := Color("201915")
const PAST := Color("6a574b")

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		queue_redraw()
		var bits: Array = []
		for r in Data.RUSHES:
			if r["to"] > GameState.open_min() and r["from"] < GameState.close_min():
				bits.append("%s %s to %s" % [r["name"], clock(r["from"]), clock(r["to"])])
		tooltip_text = "Opening hours, %s to %s. Staff come in at %s to prep.\n%s" % [
			clock(GameState.open_min()), clock(GameState.close_min()), clock(GameState.prep_min()), "\n".join(bits)]


static func clock(m: float) -> String:
	return "%02d:%02d" % [int(m / 60.0) % 24, int(m) % 60]


func x_of(m: float) -> float:
	var o := GameState.open_min()
	return clampf((m - o) / (GameState.close_min() - o), 0.0, 1.0) * size.x


func _draw() -> void:
	var h := size.y
	var y := (size.y - h) / 2.0
	draw_rect(Rect2(0, y, size.x, h), TRACK)
	for r in Data.RUSHES:
		var col := RUSH if r["mult"] > 1.0 else QUIET
		draw_rect(Rect2(x_of(r["from"]), y, x_of(r["to"]) - x_of(r["from"]), h), Color(col, 0.75))
	var now := GameState.minute if GameState.phase != GameState.Phase.PLANNING else GameState.open_min()
	var nx := x_of(now)
	draw_rect(Rect2(0, y, nx, h), Color(PAST, 0.55))
	draw_rect(Rect2(nx - 1.5, y - 2, 3, h + 4), Color("f5ecdf"))
