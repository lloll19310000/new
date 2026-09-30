extends Node2D
## The lot: floors, walls, doors, furniture, dirt and pathfinding.
## Everything static is drawn here; people are child nodes drawn on top.
##
## There are two pathfinding grids: staff can go anywhere, customers are
## kept out of the kitchen and the staff room.

const Furniture = preload("res://world/furniture.gd")
const Art = preload("res://world/art.gd")

signal layout_changed

var W: int = Data.LOT_W
var H: int = Data.LOT_H
var floor_type := PackedByteArray()   # Data.FLOOR_NONE, _DINER, _KITCHEN or _STAFF
var wall := PackedByteArray()         # 0 none, 1 wall, 2 door
var dirt := PackedFloat32Array()
var scuff := PackedFloat32Array()     # worn paths where people walk a lot (just for looks)
var noise := PackedFloat32Array()     # fixed per-tile variation for grass
var furn_at: Array = []
var furniture: Array = []
var astar := AStarGrid2D.new()        # staff
var astar_c := AStarGrid2D.new()      # customers
var cleaner_on_shift := false         # someone whose job is cleaning is in (see update_cleaners)
var entry_door := Vector2i(-1, -1)
var entry_outside := Vector2i(-1, -1)
var entry_inside := Vector2i(-1, -1)
var fx: Node2D


func _ready() -> void:
	init_grid()


func init_grid() -> void:
	var n := W * H
	floor_type = PackedByteArray()
	floor_type.resize(n)
	wall = PackedByteArray()
	wall.resize(n)
	dirt = PackedFloat32Array()
	dirt.resize(n)
	scuff = PackedFloat32Array()
	scuff.resize(n)
	noise = PackedFloat32Array()
	noise.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		noise[i] = rng.randf()
	for f in furniture:
		f.chairs = []
		f.table = null
		f.group = null
		f.occupant = null
	furn_at = []
	furn_at.resize(n)
	furniture = []
	for grid in [astar, astar_c]:
		grid.region = Rect2i(0, 0, W, H)
		grid.cell_size = Vector2(Data.TILE, Data.TILE)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
	refresh()


# ------------------------------------------------------------------ grid helpers

func idx(c: Vector2i) -> int:
	return c.y * W + c.x


func in_lot(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func buildable(c: Vector2i) -> bool:
	return in_lot(c) and c.y <= Data.BUILD_MAX_Y and GameState.owns(c)


func is_street(c: Vector2i) -> bool:
	return c.y > Data.SIDEWALK_Y


func walkable(c: Vector2i) -> bool:
	if not in_lot(c) or is_street(c):
		return false
	var i := idx(c)
	if wall[i] == 1:
		return false
	var f = furn_at[i]
	if f != null and f.info()["solid"]:
		return false
	return true


## Customers can't go into the kitchen or the staff room.
func walkable_c(c: Vector2i) -> bool:
	if not walkable(c):
		return false
	var i := idx(c)
	if wall[i] == 2:
		return true
	return floor_type[i] != Data.FLOOR_KITCHEN and floor_type[i] != Data.FLOOR_STAFF


func can_walk(c: Vector2i, customer: bool) -> bool:
	return walkable_c(c) if customer else walkable(c)


func indoors(c: Vector2i) -> bool:
	return in_lot(c) and floor_type[idx(c)] > 0


func floor_at(c: Vector2i) -> int:
	return floor_type[idx(c)] if in_lot(c) else 0


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * Data.TILE + Vector2.ONE * (Data.TILE * 0.5)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Data.TILE), floori(p.y / Data.TILE))


func furniture_at(c: Vector2i):
	if not in_lot(c):
		return null
	return furn_at[idx(c)]


func of_type(t: String) -> Array:
	return furniture.filter(func(f): return f.type == t)


func has_type(t: String) -> bool:
	for f in furniture:
		if f.type == t:
			return true
	return false


func working(t: String) -> bool:
	for f in furniture:
		if f.type == t and not f.broken:
			return true
	return false


# ------------------------------------------------------------------ pathfinding

func refresh() -> void:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, not walkable(c))
			astar_c.set_point_solid(c, not walkable_c(c))
	link_tables()
	find_entry()
	layout_changed.emit()
	queue_redraw()


func nearest_walkable(c: Vector2i, customer: bool = false) -> Vector2i:
	if can_walk(c, customer):
		return c
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if can_walk(n, customer):
					return n
	return c


func find_path(from: Vector2i, to: Vector2i, customer: bool = false) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not in_lot(from) or not in_lot(to) or not can_walk(to, customer):
		return none
	var start := nearest_walkable(from, customer)
	if start == to:
		var here: Array[Vector2i] = [to]
		return here
	var grid: AStarGrid2D = astar_c if customer else astar
	return grid.get_id_path(start, to)


## Shortest path to whichever of the target cells is closest to walk to.
func path_to_any(from: Vector2i, targets: Array, customer: bool = false) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var sorted := targets.duplicate()
	sorted.sort_custom(func(a, b): return (a - from).length_squared() < (b - from).length_squared())
	var tries := 0
	for t in sorted:
		if tries >= 6:
			break
		var p := find_path(from, t, customer)
		if p.is_empty():
			continue
		tries += 1
		if best.is_empty() or p.size() < best.size():
			best = p
	return best


## Walkable cells next to a piece of furniture, where someone stands to use it.
func access_cells(f) -> Array:
	var out: Array = []
	var own := {}
	for c in f.cells():
		own[c] = true
	for c in f.cells():
		for d in Data.DIRS:
			var n: Vector2i = c + d
			if own.has(n) or not walkable(n) or out.has(n):
				continue
			if f.type == "takeout" and floor_at(n) == 0:
				continue   # staff work the window from inside
			if f.type == "pass" and not floor_at(n) in [Data.FLOOR_KITCHEN, Data.FLOOR_DINER]:
				continue
			out.append(n)
	if f.is_table():
		var no_chairs := out.filter(func(n):
			var o = furniture_at(n)
			return o == null or not o.is_seat())
		if not no_chairs.is_empty():
			return no_chairs
	return out


## Somewhere to stand by a person at c: their tile or one beside it.
func access_cells_near(c: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i.ZERO] + Data.DIRS:
		if walkable(c + d):
			out.append(c + d)
	return out


## Where a takeout customer stands: the outside tile next to the window.
func window_outside(f) -> Vector2i:
	for d in Data.DIRS:
		var n: Vector2i = f.cell + d
		if walkable_c(n) and floor_at(n) == 0:
			return n
	return Vector2i(-1, -1)


func distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


# ------------------------------------------------------------------ entrance and tables

func spawn_cells() -> Array:
	return [Vector2i(0, Data.SIDEWALK_Y), Vector2i(W - 1, Data.SIDEWALK_Y)]


func find_entry() -> void:
	entry_door = Vector2i(-1, -1)
	entry_inside = Vector2i(-1, -1)
	entry_outside = Vector2i(-1, -1)
	var best_len := 1 << 30
	for y in H:
		for x in W:
			var d := Vector2i(x, y)
			if wall[idx(d)] != 2:
				continue
			var outside := Vector2i(-1, -1)
			var inside := Vector2i(-1, -1)
			for dir in Data.DIRS:
				var n: Vector2i = d + dir
				if not walkable_c(n):
					continue
				if floor_type[idx(n)] == Data.FLOOR_NONE:
					outside = n
				elif floor_type[idx(n)] == Data.FLOOR_DINER:
					inside = n
			if outside.x < 0 or inside.x < 0:
				continue
			var p := find_path(Vector2i(0, Data.SIDEWALK_Y), outside, true)
			if p.is_empty():
				continue
			if p.size() < best_len:
				best_len = p.size()
				entry_door = d
				entry_inside = inside
				entry_outside = outside


func has_entry() -> bool:
	return entry_door.x >= 0


func link_tables() -> void:
	for f in furniture:
		if f.is_table():
			f.chairs = []
		elif f.is_seat():
			f.table = null
	# chairs facing a table sit at it first; any other chair joins a table beside it
	for pass_n in 2:
		for f in furniture:
			if not f.is_seat() or f.table != null:
				continue
			var dirs: Array = [f.facing()] if pass_n == 0 else Data.DIRS
			for d in dirs:
				var t = furniture_at(f.cell + d)
				if t != null and t.is_table() and t.chairs.size() < t.seats_max():
					f.table = t
					t.chairs.append(f)
					break


	# counters join up with their neighbours
	for f in furniture:
		if f.is_counter():
			f.join = 0
			for i in 4:
				var n = furniture_at(f.cell + Data.DIRS[i])
				if n != null and n.is_counter():
					f.join |= 1 << i


## The way a chair placed here should face so it looks at a table, or -1.
func chair_dir_toward_table(c: Vector2i) -> int:
	for i in 4:
		var t = furniture_at(c + Data.DIRS[i])
		if t != null and t.is_table():
			return i
	return -1


func tables() -> Array:
	return furniture.filter(func(f): return f.is_table() and f.chairs.size() > 0)


## Tables are numbered left to right, top to bottom: "Table 3".
func table_number(t) -> int:
	var ts: Array = tables()
	ts.sort_custom(func(a, b): return a.cell.y < b.cell.y or (a.cell.y == b.cell.y and a.cell.x < b.cell.x))
	return ts.find(t) + 1


func seats() -> int:
	var n := 0
	for t in tables():
		n += t.chairs.size()
	return n


# ------------------------------------------------------------------ building

func rect_cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


func floor_cost(r: Rect2i, kind: int) -> int:
	var n := 0
	for c in rect_cells(r):
		if buildable(c) and floor_type[idx(c)] != kind:
			n += 1
	return n * Data.BUILD["floor_diner"]["cost"]


## Floors can't be changed under furniture that needs a particular floor.
func place_floor(r: Rect2i, kind: int) -> bool:
	var cost := floor_cost(r, kind)
	if cost == 0 or not GameState.spend(cost):
		return false
	var kept := 0
	for c in rect_cells(r):
		if not buildable(c):
			continue
		var f = furn_at[idx(c)]
		if f != null and not f.on_wall() and not floor_ok(f.info()["floor"], kind):
			kept += 1
			continue
		floor_type[idx(c)] = kind
	if kept > 0:
		GameState.add_money(kept * Data.BUILD["floor_diner"]["cost"])
		GameState.toast.emit("Some tiles were left alone because furniture there needs its floor.", "")
	refresh()
	return true


func wall_cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in rect_cells(r):
		var edge := c.x == r.position.x or c.y == r.position.y or c.x == r.end.x - 1 or c.y == r.end.y - 1
		if edge and buildable(c) and wall[idx(c)] == 0 and furn_at[idx(c)] == null:
			out.append(c)
	return out


func place_walls(r: Rect2i) -> bool:
	var cells := wall_cells(r)
	if cells.is_empty():
		return false
	if not GameState.spend(cells.size() * Data.BUILD["wall"]["cost"]):
		return false
	for c in cells:
		wall[idx(c)] = 1
	refresh()
	return true


func can_place_door(c: Vector2i) -> bool:
	return buildable(c) and wall[idx(c)] != 2 and furn_at[idx(c)] == null


func place_door(c: Vector2i) -> bool:
	if not can_place_door(c) or not GameState.spend(Data.BUILD["door"]["cost"]):
		return false
	wall[idx(c)] = 2
	refresh()
	return true


func furniture_size(type: String, dir: int) -> Vector2i:
	var s: Array = Data.FURNITURE[type]["size"]
	return Vector2i(s[1], s[0]) if dir % 2 == 1 else Vector2i(s[0], s[1])


func floor_ok(need: String, kind: int) -> bool:
	match need:
		"any": return kind != Data.FLOOR_NONE
		"diner": return kind == Data.FLOOR_DINER
		"kitchen": return kind == Data.FLOOR_KITCHEN
		"staff": return kind == Data.FLOOR_STAFF
		"inside": return kind == Data.FLOOR_DINER or kind == Data.FLOOR_KITCHEN
		"restroom": return kind == Data.FLOOR_RESTROOM
		"wash": return kind == Data.FLOOR_KITCHEN or kind == Data.FLOOR_RESTROOM
		"outside": return kind == Data.FLOOR_NONE
	return true


const FLOOR_HINT := {
	"any": "Furniture goes on a floor. Lay a floor first.",
	"diner": "This goes on diner floor.",
	"kitchen": "This goes on kitchen floor.",
	"staff": "This goes on staff room floor.",
	"inside": "This goes on diner or kitchen floor.",
	"restroom": "This goes on restroom floor.",
	"wash": "This goes in the kitchen or a restroom.",
	"outside": "This goes outside, on the grass.",
}


## Returns "" when the furniture fits, otherwise the reason it doesn't.
## ignore: a piece of furniture to pretend isn't there (used when rotating it).
func furniture_blocker(type: String, c: Vector2i, dir: int, ignore = null) -> String:
	var info: Dictionary = Data.FURNITURE[type]
	var size := furniture_size(type, dir)
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			if not buildable(cc):
				return "Keep furniture inside the lot."
			var i := idx(cc)
			var there = furn_at[i]
			if there != null and there != ignore:
				return "Something is already there."
			if info["floor"] == "wall":
				if wall[i] != 1:
					return "This goes on a wall."
				continue
			if wall[i] != 0:
				return "There's a wall or door there."
			if not floor_ok(info["floor"], floor_type[i]):
				return FLOOR_HINT[info["floor"]]
	if type == "pass":
		return pass_blocker(c, size)
	if info["floor"] == "wall":
		var inside := false
		var outside := false
		for d in Data.DIRS:
			var n: Vector2i = c + d
			if not in_lot(n) or wall[idx(n)] != 0:
				continue
			if floor_type[idx(n)] > 0:
				inside = true
			elif walkable_c(n):
				outside = true
		if type == "takeout" and not (inside and outside):
			return "Put it in a wall with a room on one side and outdoors on the other."
		if not inside:
			return "Hang it on a wall next to a room."
	return ""


## The pass sits in a wall with the kitchen on one side and the dining room on the other.
func pass_blocker(c: Vector2i, size: Vector2i) -> String:
	var across: Array = [Vector2i.UP, Vector2i.DOWN] if size.x >= size.y else [Vector2i.LEFT, Vector2i.RIGHT]
	for y in size.y:
		for x in size.x:
			var cc := c + Vector2i(x, y)
			var a := floor_at(cc + across[0]) if not is_wallish(cc + across[0]) else -1
			var b := floor_at(cc + across[1]) if not is_wallish(cc + across[1]) else -1
			var ok := (a == Data.FLOOR_KITCHEN and b == Data.FLOOR_DINER) or (a == Data.FLOOR_DINER and b == Data.FLOOR_KITCHEN)
			if not ok:
				return "Put it in the wall between the kitchen and the dining room."
	return ""


## Which way a wall runs through c: true when it goes up and down.
func wall_runs_vertical(c: Vector2i) -> bool:
	if is_wallish(c + Vector2i.RIGHT) or is_wallish(c + Vector2i.LEFT):
		return false
	return is_wallish(c + Vector2i.DOWN) or is_wallish(c + Vector2i.UP)


## For things with a front: the way that faces away from a wall beside c, or -1.
func dir_away_from_wall(c: Vector2i) -> int:
	for i in 4:
		if is_wallish(c + Data.DIRS[i]):
			return (i + 2) % 4
	return -1


func place_furniture(type: String, c: Vector2i, dir: int) -> bool:
	if not GameState.item_unlocked(type):
		return false
	var why := furniture_blocker(type, c, dir)
	if why != "":
		GameState.toast.emit(why, "bad")
		return false
	if not GameState.spend(Data.FURNITURE[type]["cost"]):
		return false
	add_furniture(type, c, dir)
	refresh()
	return true


## Puts furniture down without paying or checking (used when loading a save).
func add_furniture(type: String, c: Vector2i, dir: int):
	var f := Furniture.new()
	f.id = GameState.new_id()
	f.type = type
	f.cell = c
	f.dir = dir
	f.size = furniture_size(type, dir)
	furniture.append(f)
	for cc in f.cells():
		furn_at[idx(cc)] = f
	return f


## Turns a placed piece a quarter turn clockwise. Free, mornings only.
func rotate_furniture(f) -> bool:
	if not GameState.is_building_allowed():
		GameState.toast.emit("You can only move things around in the morning.", "bad")
		return false
	var nd: int = (f.dir + 1) % 4
	var ns := furniture_size(f.type, nd)
	if ns != f.size:
		var why := furniture_blocker(f.type, f.cell, nd, f)
		if why != "":
			GameState.toast.emit("It doesn't fit turned that way: " + why.to_lower(), "bad")
			return false
	for cc in f.cells():
		furn_at[idx(cc)] = null
	f.dir = nd
	f.size = ns
	for cc in f.cells():
		furn_at[idx(cc)] = f
	refresh()
	return true


func remove_furniture(f) -> float:
	if f.is_table():
		GameState.plates_clean += f.dirty_plates
		f.dirty_plates = 0
		if f.cash > 0.0:
			GameState.add_money(f.cash)
			f.cash = 0.0
	if f.type == "sink":
		GameState.plates_clean += f.dirty
		f.dirty = 0
	if f.type == "pass":
		for it in f.items:
			if it.get("plated", false):
				GameState.plates_clean += 1
		f.items.clear()
	for cc in f.cells():
		furn_at[idx(cc)] = null
	furniture.erase(f)
	return Data.FURNITURE[f.type]["cost"] * Data.REFUND


## Removes one layer at a time: furniture first, then walls and doors, then floor.
func remove_rect(r: Rect2i) -> float:
	var refund := 0.0
	var seen := {}
	for c in rect_cells(r):
		if not buildable(c):
			continue
		var f = furn_at[idx(c)]
		if f != null and not seen.has(f):
			seen[f] = true
			if f.user != null or f.group != null:
				continue
			refund += remove_furniture(f)
	if seen.is_empty():
		for c in rect_cells(r):
			if not buildable(c):
				continue
			var i := idx(c)
			if wall[i] != 0:
				var key := "wall" if wall[i] == 1 else "door"
				refund += Data.BUILD[key]["cost"] * Data.REFUND
				wall[i] = 0
				seen[c] = true
	if seen.is_empty():
		for c in rect_cells(r):
			if not buildable(c):
				continue
			var i := idx(c)
			if floor_type[i] != 0:
				refund += Data.BUILD["floor_diner"]["cost"] * Data.REFUND
				floor_type[i] = 0
				dirt[i] = 0.0
	if refund > 0:
		GameState.add_money(refund)
	refresh()
	return refund


# ------------------------------------------------------------------ dirt

## Is someone whose job is keeping the place clean in right now? Then spills
## are swept as soon as they happen and small ones never show.
func update_cleaners() -> void:
	var was := cleaner_on_shift
	cleaner_on_shift = false
	for s in GameState.staff:
		if is_instance_valid(s) and s.is_here() and (s.role in ["busser", "porter"] or s.priorities.get("clean", 0) == 1):
			cleaner_on_shift = true
			break
	if was != cleaner_on_shift:
		queue_redraw()


func dirt_visible(c: Vector2i) -> bool:
	return dirt[idx(c)] >= (Data.DIRT_SHOW_CLEANER if cleaner_on_shift else Data.DIRT_SHOW)


## Someone walked across c: busy paths wear in.
func wear_path(c: Vector2i) -> void:
	if not indoors(c):
		return
	var i := idx(c)
	var before := scuff[i]
	scuff[i] = minf(1.0, scuff[i] + Data.SCUFF_PER_STEP)
	if int(before * 5) != int(scuff[i] * 5):
		queue_redraw()


## Overnight the worn paths fade a little.
func fade_scuffs() -> void:
	for i in scuff.size():
		scuff[i] *= Data.SCUFF_FADE


func add_dirt(c: Vector2i, amount: float) -> void:
	if not indoors(c) or wall[idx(c)] == 1:
		return
	var i := idx(c)
	var before := dirt[i]
	dirt[i] = minf(1.0, dirt[i] + amount)
	if dirt[i] >= (Data.DIRT_SHOW if cleaner_on_shift else Data.DIRT_JOB):
		post_sweep(c)
	if int(before * 8) != int(dirt[i] * 8) or (before < Data.DIRT_SHOW and dirt[i] >= Data.DIRT_SHOW):
		queue_redraw()


func post_sweep(c: Vector2i) -> void:
	if walkable(c) and not JobBoard.has_open("sweep", "cell", c):
		JobBoard.post("clean", "sweep", {"cell": c})


## After closing, every visible speck gets a sweep job so the diner is clean by morning.
func post_closing_sweeps() -> void:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if dirt[idx(c)] >= Data.DIRT_SHOW:
				post_sweep(c)


func clean_cell(c: Vector2i, radius: int = 0) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cc := c + Vector2i(dx, dy)
			if in_lot(cc) and indoors(cc):
				dirt[idx(cc)] = 0.0
	queue_redraw()


## 0 = spotless, 1 = filthy. Looks at the floor around a spot.
func dirt_near(c: Vector2i, radius: int = 4) -> float:
	var total := 0.0
	var n := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cc := c + Vector2i(dx, dy)
			if indoors(cc):
				total += dirt[idx(cc)]
				n += 1
	return total / n if n > 0 else 0.0


## How dirty the kitchen floor is on average, 0 to 1.
func kitchen_dirt() -> float:
	var total := 0.0
	var n := 0
	for i in floor_type.size():
		if floor_type[i] == Data.FLOOR_KITCHEN and wall[i] == 0:
			total += dirt[i]
			n += 1
	return total / n if n > 0 else 0.0


## How nice a spot is: decorations within their reach, capped at Data.MAX_BEAUTY.
func beauty_near(c: Vector2i) -> int:
	var total := 0
	for f in furniture:
		var b: int = f.beauty()
		if b > 0 and distance(f.cell, c) <= f.info().get("radius", 3):
			total += b
	return mini(total, Data.MAX_BEAUTY)


## The kitchen has what this dish needs: its station, and an ice machine for cold drinks.
func can_make(d: String) -> bool:
	var info: Dictionary = Data.DISHES[d]
	return working(info["station"]) and (not info.get("ice", false) or has_type("ice"))


func music_near(c: Vector2i) -> bool:
	for f in furniture:
		if f.info().get("music", false) and distance(f.cell, c) <= f.info().get("radius", 6):
			return true
	return false


# ------------------------------------------------------------------ health inspection

## What the inspector sees: floor dirt (kitchen counts double), dirty tables,
## plates piling up at the sink and broken equipment.
func inspection() -> Dictionary:
	var total := 0.0
	var n := 0.0
	for i in floor_type.size():
		if floor_type[i] == 0 or wall[i] == 1:
			continue
		var w := 2.0 if floor_type[i] == Data.FLOOR_KITCHEN else 1.0
		total += dirt[i] * w
		n += w
	var avg := total / n if n > 0 else 0.0
	var dirty_tables := 0
	var sink_backlog := 0
	var broken := 0
	for f in furniture:
		if f.is_table() and f.dirty_plates > 0:
			dirty_tables += 1
		if f.type == "sink":
			sink_backlog += f.dirty
		if f.broken:
			broken += 1
	var score := 100.0 - avg * 300.0 - dirty_tables * 4.0 - maxf(0, sink_backlog - 4) * 1.5 - broken * 8.0
	var notes: Array = []
	var extra: Array = Health.inspection_extra() if Health.main != null else [0.0, []]
	score -= extra[0]
	if avg > 0.04:
		notes.append("dirty floors")
	if dirty_tables > 0:
		notes.append("%d uncleared table%s" % [dirty_tables, "" if dirty_tables == 1 else "s"])
	if sink_backlog > 4:
		notes.append("plates piling up at the sink")
	if broken > 0:
		notes.append("broken equipment")
	notes.append_array(extra[1])
	var g := "A" if score >= 85.0 else ("B" if score >= 65.0 else "C")
	return {"score": score, "grade": g, "notes": notes}


# ------------------------------------------------------------------ readiness

func checklist() -> Array:
	var cook := false
	var serve := false
	for s in GameState.staff:
		if s.priorities["cook"] > 0:
			cook = true
		if s.priorities["serve"] > 0:
			serve = true
	var station := false
	for t in Data.STATIONS:
		if has_type(t):
			station = true
	# [what, done, only recommended]: the recommended ones don't stop you opening
	return [
		["A door from the street into the dining room", has_entry()],
		["A table with at least one chair beside it", not tables().is_empty()],
		["A cooking station: grill, fryer, griddle, oven or drinks", station],
		["A fridge", has_type("fridge")],
		["A pass counter", has_type("pass")],
		["A sink", has_type("sink")],
		["Someone with Cook switched on", cook],
		["Someone with Serve switched on", serve],
		["A restroom with a toilet (customers expect one)", has_type("toilet"), true],
		["A hand sink, and a trash can in the kitchen", has_type("handsink") and has_type("bin"), true],
	]


func ready_to_open() -> bool:
	for item in checklist():
		if not item[1] and not (item.size() > 2 and item[2]):
			return false
	return true


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var i := idx(c)
			Art.ground(self, c, floor_type[i], noise[i])
			if scuff[i] > 0.2 and floor_type[i] > 0:
				Art.scuff(self, c, scuff[i], noise[i])
			if dirt_visible(c):
				var d := dirt[i]
				var p := cell_center(c) + Vector2(noise[i] * 8 - 4, noise[(i + 7) % noise.size()] * 8 - 4)
				Art.ellipse(self, p, Vector2(7, 5) * (0.6 + d * 0.6), Color(0.36, 0.26, 0.15, 0.2 + d * 0.45))
				if d > 0.3:
					Art.ellipse(self, p + Vector2(6, 5), Vector2(4, 3) * (0.5 + d * 0.5), Color(0.36, 0.26, 0.15, 0.15 + d * 0.35))
	# land you own is outlined; plots for sale are darker, with a sign
	var t := float(Data.TILE)
	for p in Data.PLOTS:
		var r := Rect2(Vector2((p["rect"] as Rect2i).position) * t, Vector2((p["rect"] as Rect2i).size) * t)
		if GameState.owned.has(p["id"]):
			draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
		else:
			draw_rect(r, Color(0.05, 0.08, 0.04, 0.28))
			draw_rect(r.grow(-1), Color(1, 1, 1, 0.08), false, 1.0)
			Art.for_sale_sign(self, r.get_center(), "$%d" % p["cost"])
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var w := wall[idx(c)]
			if w == 1:
				Art.wall_tile(self, c, is_wallish(c + Vector2i.UP), is_wallish(c + Vector2i.DOWN), is_wallish(c + Vector2i.LEFT), is_wallish(c + Vector2i.RIGHT))
			elif w == 2:
				var horizontal := is_wallish(c + Vector2i.LEFT) or is_wallish(c + Vector2i.RIGHT)
				Art.door_tile(self, c, horizontal)
	for f in furniture:
		Art.furniture(self, f, inside_dir(f) if f.on_wall() else -1)
	for f in furniture:
		if f.is_table():
			Art.table_food(self, f)
	# a birthday: cake in the staff room, on the sofa's arm
	if Moments.cake_for != "" and GameState.phase != GameState.Phase.REPORT:
		var sofas: Array = of_type("sofa")
		if not sofas.is_empty():
			Art.cake(self, sofas[0].center_px() + Vector2(0, -2), 1.0)
	if has_entry() and GameState.grade != "":
		Art.grade_sign(self, entry_door, entry_outside, GameState.grade)
	if has_entry():
		var lit := clampf((GameState.minute - 18.0 * 60.0) / 120.0, 0.0, 1.0) if GameState.phase != GameState.Phase.PLANNING else 0.0
		Art.storefront(self, entry_door, entry_outside, GameState.diner_name, GameState.is_open(), lit, GameState.staff.size() < 4, GameState.rep_level)


## For wall-hung things: which side the room is on (0-3), so they face into it.
func inside_dir(f) -> int:
	for i in 4:
		var n: Vector2i = f.cell + Data.DIRS[i]
		if in_lot(n) and wall[idx(n)] == 0 and floor_type[idx(n)] > 0:
			return i
	return 2


func is_wallish(c: Vector2i) -> bool:
	return in_lot(c) and wall[idx(c)] != 0
