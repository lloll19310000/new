extends RefCounted
## One placed piece of furniture. Stations, tables, the pass, the sink and
## sofas also keep a little state here (who is using them, what sits on them).

var id: int = 0
var type: String = ""
var cell: Vector2i = Vector2i.ZERO      # top-left tile
var size: Vector2i = Vector2i.ONE       # after rotation
var dir: int = 0                        # 0 up, 1 right, 2 down, 3 left (which way it faces)

# stations
var user = null                         # staff member cooking here
var cooking: String = ""                # dish on the heat right now
var wear: float = 0.0                   # 0 = new, 1 = worn out
var broken: bool = false
var broke_by = null                     # the cook who was using it when it broke
var tier: int = 0                       # 1 = upgraded to Pro: faster, wears slower
var stocked: bool = true                # restocked since last night (see closing duties)
# pass counter
var items: Array = []                   # [{"dish": String, "group": Group, "q": float, "plated": bool}]
# tables and takeout windows
var group = null                        # customer group sitting here (or waiting at the window)
var dirty_plates: int = 0
var food_on_table: Array = []           # dishes being eaten
var chairs: Array = []                  # chairs next to this table
var reserved = null                     # the booking this table is held for (a Dictionary), or null
# chairs
var table = null
var occupant = null
# sinks
var dirty: int = 0
# sofas
var resters: Dictionary = {}            # cell -> staff member resting there
# toilets and bins
var grime: float = 0.0                  # toilets: 0 = clean, 1 = filthy
var fill: float = 0.0                   # trash cans: 0 = empty, 1 = full (more is overflowing)


var rotated: bool:
	get:
		return dir % 2 == 1


func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			out.append(cell + Vector2i(x, y))
	return out


func rect_px() -> Rect2:
	var t := Data.TILE
	return Rect2(Vector2(cell) * t, Vector2(size) * t)


func center_px() -> Vector2:
	return rect_px().get_center()


func info() -> Dictionary:
	return Data.FURNITURE[type]


func facing() -> Vector2i:
	return Data.DIRS[dir]


func is_station() -> bool:
	return type in Data.STATIONS


func on_wall() -> bool:
	return info()["floor"] == "wall"


func beauty() -> int:
	return info().get("beauty", 0)


func table_free() -> bool:
	return type == "table" and group == null and dirty_plates == 0 and chairs.size() > 0


func pass_free_slots() -> int:
	return Data.PASS_SLOTS - items.size()


func free_rest_cell():
	for c in cells():
		if not resters.has(c) or resters[c] == null or not is_instance_valid(resters[c]):
			return c
	return null
