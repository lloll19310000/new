extends Node
## Health and cleanliness, the part of a diner customers don't see until it
## goes wrong:
##   - restrooms: customers (and staff on breaks) use them, and they get dirty
##   - trash: every order fills the kitchen bins, which someone has to take out
##   - mice: dirt, overflowing bins and food left out bring them in
##   - hand-washing: after the restroom or the trash, staff should wash up
## The health inspector looks at all of it (see inspection_extra).

const Mouse = preload("res://world/mouse.gd")

var main                               # set by main.gd
var mice: Array = []                   # mice running around right now
var last_mouse_day := -99              # the last day anyone saw a mouse
var _acc := 0.0
var _skipped_today := {}               # staff id -> true once their skipped hand-wash is logged


func _ready() -> void:
	reset()


func reset() -> void:
	for m in mice:
		if is_instance_valid(m):
			m.queue_free()
	mice = []
	last_mouse_day = -99
	_acc = 0.0
	_skipped_today = {}


func reset_day() -> void:
	_skipped_today = {}


# ------------------------------------------------------------------ restrooms

func toilets() -> Array:
	return main.lot.of_type("toilet") if main != null else []


## A free toilet customers can reach from the dining room, nearest first.
func free_toilet(from: Vector2i):
	var best = null
	var best_d := 1 << 30
	for t in toilets():
		if t.occupant != null and is_instance_valid(t.occupant):
			continue
		if main.lot.find_path(from, t.cell, true).is_empty():
			continue
		var d: int = main.lot.distance(from, t.cell)
		if d < best_d:
			best_d = d
			best = t
	return best


## Someone used the toilet: it gets a bit dirtier, and needs a scrub now and then.
func used_toilet(t, g = null) -> void:
	if g != null and t.grime >= Data.RESTROOM_DIRTY:
		g.extra_hits["a dirty restroom"] = clampf(t.grime * 0.8, 0.2, 0.6)
		GameState.today["dirty_restroom"] += 1
	t.grime = minf(1.0, t.grime + randf_range(Data.TOILET_GRIME.x, Data.TOILET_GRIME.y))
	GameState.today["restroom_uses"] += 1
	if t.grime >= Data.TOILET_SCRUB_AT and not JobBoard.has_open("scrub", "furniture", t):
		JobBoard.post("clean", "scrub", {"furniture": t})
	main.lot.queue_redraw()


# ------------------------------------------------------------------ trash

## Scraps from cooking, prep or plates go in the nearest kitchen bin. With no
## bin they end up on the floor.
func add_trash(near: Vector2i, amount: float) -> void:
	if main == null:
		return
	var bin = null
	var best_d := 1 << 30
	for b in main.lot.of_type("bin"):
		var d: int = main.lot.distance(near, b.cell)
		if d < best_d:
			best_d = d
			bin = b
	if bin == null:
		main.lot.add_dirt(near, amount * 2.0)
		return
	bin.fill = minf(1.5, bin.fill + amount)
	if bin.fill >= Data.BIN_EMPTY_AT and not JobBoard.has_open("trash", "furniture", bin):
		JobBoard.post("clean", "trash", {"furniture": bin})
	main.lot.queue_redraw()


func overflowing() -> Array:
	return main.lot.of_type("bin").filter(func(b): return b.fill >= 1.0) if main != null else []


## Where a bag of trash goes: the dumpster, or out the front door.
func trash_spot() -> Array:
	var lot = main.lot
	for d in lot.of_type("dumpster"):
		var cells: Array = lot.access_cells(d)
		if not cells.is_empty():
			return cells
	if lot.has_entry():
		return [lot.entry_outside]
	return []


# ------------------------------------------------------------------ hand-washing

## After the restroom or the trash: wash up, or skip it. Returns true if they'll wash.
func will_wash(s) -> bool:
	if main == null or main.lot.of_type("handsink").is_empty():
		skipped(s, "there's no hand sink")
		return false
	var p := Data.HANDWASH_SKIP
	if s.has_trait("tidy"):
		p = 0.0
	if s.mood == "fed_up":
		p += 0.2
	if Crew.customers_waiting() >= Crew.present().size():
		p += 0.1
	if s.has_trait("clumsy"):
		p += 0.05
	if randf() < p:
		skipped(s, "")
		return false
	return true


func skipped(s, why: String) -> void:
	GameState.today["handwash_skipped"] += 1
	if _skipped_today.has(s.id):
		return
	_skipped_today[s.id] = true
	Crew.log_line("%s didn't wash their hands%s." % [s.person_name, (": " + why) if why != "" else ""], "alert", [s])
	# Tidy coworkers who notice are not impressed
	for o in Crew.present():
		if o != s and o.has_trait("tidy") and Crew.tile_dist(o, s) <= 5.0:
			Crew.add(o, s, "hands")
			Crew.say(o, "hands", "alert")


# ------------------------------------------------------------------ mice

## How likely a mouse is to turn up in the next hour.
func mouse_risk() -> float:
	if main == null:
		return 0.0
	var lot = main.lot
	var r := maxf(0.0, lot.kitchen_dirt() - 0.03) * 5.0
	r += overflowing().size() * 0.25
	for t in lot.tables():
		if t.dirty_plates > 0:
			r += 0.01
	r *= pow(0.6, mini(lot.of_type("trap").size(), 3))
	return clampf(r, 0.0, 0.8)


## Once a game minute while open or tidying: bins overflow, mice turn up.
func tick(minutes: float) -> void:
	if main == null or not (GameState.is_open() or GameState.phase == GameState.Phase.CLEANUP):
		return
	_acc += minutes
	while _acc >= 1.0:
		_acc -= 1.0
		minute_step()


func minute_step() -> void:
	var lot = main.lot
	for b in overflowing():
		for c in lot.access_cells(b):
			lot.add_dirt(c, 0.02)
	if mice.size() < 2 and randf() < mouse_risk() / 60.0:
		spawn_mouse()
	for m in mice.duplicate():
		if not is_instance_valid(m):
			mice.erase(m)


func spawn_mouse() -> void:
	var lot = main.lot
	var spots: Array = []
	for y in lot.H:
		for x in lot.W:
			var c := Vector2i(x, y)
			if lot.indoors(c) and lot.walkable(c) and lot.floor_at(c) in [Data.FLOOR_KITCHEN, Data.FLOOR_DINER]:
				for d in Data.DIRS:
					if lot.in_lot(c + d) and lot.wall[lot.idx(c + d)] == 1:
						spots.append(c)
						break
	if spots.is_empty():
		return
	var m := Mouse.new()
	m.lot = lot
	m.life = randf_range(Data.MOUSE_MINUTES.x, Data.MOUSE_MINUTES.y)
	main.people.add_child(m)
	m.place_at(spots.pick_random())
	mice.append(m)
	last_mouse_day = GameState.day
	GameState.today["mice"] += 1
	Crew.log_line("A mouse ran across the %s." % ("kitchen" if lot.floor_at(m.current_cell()) == Data.FLOOR_KITCHEN else "dining room"), "mouse")


## Called by a mouse every game minute: people nearby react, traps and staff get it.
func mouse_minute(m) -> void:
	var lot = main.lot
	var here: Vector2i = m.current_cell()
	for t in lot.of_type("trap"):
		if lot.distance(here, t.cell) <= 1 and randf() < 0.6:
			GameState.today["mice_caught"] += 1
			Crew.log_line("A trap caught a mouse.", "mouse")
			Sfx.play("pop", -6.0)
			remove_mouse(m)
			return
	for s in Crew.present():
		var d: float = s.position.distance_to(m.position) / Data.TILE
		if d <= 1.2 and not s.on_break:
			Crew.say(s, "mouse", "alert")
			Crew.log_line("%s chased a mouse out." % s.person_name, "mouse", [s])
			remove_mouse(m)
			return
		if d <= Data.MOUSE_SEEN_TILES and s.has_trait("tidy") and not m.seen_by.has(s.id):
			m.seen_by[s.id] = true
			s.add_stress(5.0)
			Crew.say(s, "mouse", "alert")
	for g in main.groups:
		if not is_instance_valid(g) or g.takeout or g.kind == "inspector" or g.saw_mouse:
			continue
		if not g.state in ["waiting", "to_table", "seated", "ordered", "eating", "paying", "complaining"]:
			continue
		for mem in g.members:
			if is_instance_valid(mem) and mem.position.distance_to(m.position) <= Data.MOUSE_SEEN_TILES * Data.TILE:
				g.saw_mouse = true
				GameState.today["mouse_seen"] += 1
				if g.state in ["waiting", "to_table", "seated", "ordered"] and randf() < Data.MOUSE_LEAVE:
					GameState.toast.emit("%s saw a mouse and walked out!" % g.label(), "bad")
					g.leave(1.5, "a mouse!", false)
				else:
					g.extra_hits["a mouse!"] = Data.MOUSE_REVIEW
				break


func remove_mouse(m) -> void:
	mice.erase(m)
	if is_instance_valid(m):
		m.queue_free()


# ------------------------------------------------------------------ the inspector

## What the inspector notices beyond the floors and the kitchen:
## [points off, [notes]].
func inspection_extra() -> Array:
	var off := 0.0
	var notes: Array = []
	var lot = main.lot
	var ts: Array = toilets()
	if ts.is_empty():
		off += 6.0
		notes.append("no customer restroom")
	else:
		var grime := 0.0
		for t in ts:
			grime = maxf(grime, t.grime)
		if grime >= 0.4:
			off += 8.0 + grime * 6.0
			notes.append("a dirty restroom")
	if lot.of_type("handsink").is_empty():
		off += 8.0
		notes.append("no hand sink")
	var skips: int = GameState.today.get("handwash_skipped", 0)
	var caught := false
	for s in Crew.present():
		if s.dirty_hands and s.job != null and s.job.type in ["cook", "serve"]:
			caught = true
	if caught:
		off += 15.0
		notes.append("someone handling food with dirty hands")
	elif skips > 0:
		off += minf(12.0, skips * 3.0)
		notes.append("staff skipping hand-washing")
	var full := overflowing().size()
	if full > 0:
		off += 10.0 * full
		notes.append("overflowing trash")
	if not mice.is_empty() or last_mouse_day >= GameState.day - 2:
		off += 25.0
		notes.append("signs of mice")
	if GameState.last_allergy_day >= GameState.day - 3:
		off += 8.0
		notes.append("a reported allergic reaction")
	return [off, notes]


func save_data() -> Dictionary:
	var fills := []
	var grimes := []
	if main != null:
		for f in main.lot.furniture:
			if f.type == "bin":
				fills.append([f.cell.x, f.cell.y, f.fill])
			elif f.type == "toilet":
				grimes.append([f.cell.x, f.cell.y, f.grime])
	return {"last_mouse_day": last_mouse_day, "bins": fills, "toilets": grimes}


func load_data(d: Dictionary) -> void:
	reset()
	last_mouse_day = int(d.get("last_mouse_day", -99))
	if main == null:
		return
	for e in d.get("bins", []):
		var f = main.lot.furniture_at(Vector2i(int(e[0]), int(e[1])))
		if f != null and f.type == "bin":
			f.fill = float(e[2])
			if f.fill >= Data.BIN_EMPTY_AT:
				JobBoard.post("clean", "trash", {"furniture": f})
	for e in d.get("toilets", []):
		var f = main.lot.furniture_at(Vector2i(int(e[0]), int(e[1])))
		if f != null and f.type == "toilet":
			f.grime = float(e[2])
			if f.grime >= Data.TOILET_SCRUB_AT:
				JobBoard.post("clean", "scrub", {"furniture": f})
