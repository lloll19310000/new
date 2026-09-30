extends Node2D
## Handles the mouse on the lot: inspecting, and building while the diner is closed.
## Drag tools (floors, walls, remove) use a box; the rest are single clicks.
## R turns what you're about to place (or the selected piece when inspecting).

const Art = preload("res://world/art.gd")
const Furniture = preload("res://world/furniture.gd")
const DRAG_TOOLS := ["floor_diner", "floor_kitchen", "floor_staff", "floor_restroom", "wall", "remove"]

signal selected(thing)
signal tool_changed(tool: String)

var lot
var tool: String = "select"
var rot := 0                 # 0 up, 1 right, 2 down, 3 left
var rot_touched := false     # chairs face the nearest table until you press R
var hover := Vector2i(-1, -1)
var drag_from := Vector2i(-1, -1)
var dragging := false
var mouse_world := Vector2.ZERO
var selection = null


func set_tool(t: String) -> void:
	tool = t
	dragging = false
	rot_touched = false
	tool_changed.emit(t)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		# where the mouse is on the lot, taking the camera into account
		var p: Vector2 = (make_input_local(event) as InputEventMouse).position
		var c: Vector2i = lot.to_cell(p)
		if c != hover:
			hover = c
			queue_redraw()
		mouse_world = p
	if event is InputEventMouseMotion:
		return
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if tool == "select":
				selection = pick(mouse_world)
				# clicking someone who's on their phone catches them
				if selection is Node and selection.get("on_phone") == true:
					Crew.owner_caught(selection)
				# clicking a mouse chases it out
				if selection is Node and selection.get("is_mouse") == true:
					Health.remove_mouse(selection)
					GameState.toast.emit("You chased the mouse out.", "")
					Sfx.play("pop", -6.0)
					selection = null
				selected.emit(selection)
				return
			if not GameState.is_building_allowed():
				GameState.toast.emit("You can only build in the morning, before you open.", "bad")
				Sfx.play("error")
				return
			if tool in DRAG_TOOLS:
				dragging = true
				drag_from = hover
			else:
				apply_click(hover)
			get_viewport().set_input_as_handled()
		elif dragging:
			dragging = false
			apply_rect(rect_between(drag_from, hover))
			queue_redraw()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_R:
			rotate_pressed()
		elif k == KEY_ESCAPE:
			if tool != "select":
				set_tool("select")
			else:
				selection = null
				selected.emit(null)


func rotate_pressed() -> void:
	if tool == "select":
		if selection is RefCounted and selection != null and selection.get("type") != null:
			if lot.rotate_furniture(selection):
				Sfx.play("place", -8.0)
				selected.emit(selection)
		return
	rot = (dir_for(tool, hover) + 1) % 4
	rot_touched = true
	queue_redraw()


## Which way a piece will face if placed at c.
## Until you press R: chairs face the nearest table, the pass lines up with
## the wall it's in, and kitchen machines turn their backs to the wall.
func dir_for(t: String, c: Vector2i) -> int:
	if rot_touched:
		return rot
	if t == "chair":
		var auto: int = lot.chair_dir_toward_table(c)
		if auto >= 0:
			return auto
	elif t == "pass":
		return 1 if lot.wall_runs_vertical(c) else 0
	elif t in Art.TURNS:
		var away: int = lot.dir_away_from_wall(c)
		if away >= 0:
			return away
	return rot


func rect_between(a: Vector2i, b: Vector2i) -> Rect2i:
	var p := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var q := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(p, q - p + Vector2i.ONE)


func apply_rect(r: Rect2i) -> void:
	var ok := false
	match tool:
		"floor_diner", "floor_kitchen", "floor_staff", "floor_restroom":
			ok = lot.place_floor(r, Data.BUILD[tool]["floor"])
		"wall":
			ok = lot.place_walls(r)
		"remove":
			var back: float = lot.remove_rect(r)
			if back > 0:
				GameState.toast.emit("Removed. $%d back." % int(back), "")
				Sfx.play("remove")
			return
	Sfx.play("place" if ok else "error", -4.0 if ok else -8.0)


func apply_click(c: Vector2i) -> void:
	if tool == "land":
		var p := GameState.plot_at(c)
		if p.is_empty() or GameState.owned.has(p["id"]):
			GameState.toast.emit("Click a plot marked For sale to buy it.", "")
			Sfx.play("error", -8.0)
		elif GameState.buy_plot(p["id"]):
			Sfx.play("cash")
			lot.queue_redraw()
		return
	var ok := false
	if tool == "door":
		if not lot.can_place_door(c):
			GameState.toast.emit("A door needs an empty tile or a wall.", "bad")
		else:
			ok = lot.place_door(c)
	elif Data.FURNITURE.has(tool):
		ok = lot.place_furniture(tool, c, dir_for(tool, c))
	Sfx.play("place" if ok else "error", -4.0 if ok else -8.0)


func pick(p: Vector2):
	var best = null
	var best_d := 14.0
	for pawn in get_tree().get_nodes_in_group("pawns"):
		var d: float = pawn.position.distance_to(p)
		if d < best_d:
			best_d = d
			best = pawn
	if best != null:
		return best
	var c: Vector2i = lot.to_cell(p)
	var f = lot.furniture_at(c)
	if f != null:
		return f
	return c


func cost_preview() -> Array:
	# [text, ok]
	if dragging:
		var r := rect_between(drag_from, hover)
		match tool:
			"floor_diner", "floor_kitchen", "floor_staff", "floor_restroom":
				var c1: int = lot.floor_cost(r, Data.BUILD[tool]["floor"])
				return ["$%d" % c1, GameState.can_afford(c1)]
			"wall":
				var c3: int = lot.wall_cells(r).size() * Data.BUILD["wall"]["cost"]
				return ["$%d" % c3, GameState.can_afford(c3)]
			"remove":
				return ["Remove", true]
	if tool == "land":
		var p := GameState.plot_at(hover)
		if p.is_empty():
			return ["", true]
		if GameState.owned.has(p["id"]):
			return ["Already yours", false]
		return ["Buy the %s: $%d" % [p["name"].to_lower(), p["cost"]], GameState.can_afford(p["cost"])]
	if tool == "door":
		var ok: bool = lot.can_place_door(hover) and GameState.can_afford(Data.BUILD["door"]["cost"])
		return ["$%d" % Data.BUILD["door"]["cost"], ok]
	if Data.FURNITURE.has(tool):
		var cost: int = Data.FURNITURE[tool]["cost"]
		var why: String = lot.furniture_blocker(tool, hover, dir_for(tool, hover))
		return [("$%d" % cost) if why == "" else why, why == "" and GameState.can_afford(cost)]
	return ["", true]


func _draw() -> void:
	if tool == "select" or not lot.in_lot(hover):
		if lot.in_lot(hover) and tool == "select":
			draw_rect(Rect2(Vector2(hover) * Data.TILE, Vector2.ONE * Data.TILE), Color(1, 1, 1, 0.35), false, 1.5)
		if selection is RefCounted and selection != null and selection.get("type") != null and lot.furniture.has(selection):
			draw_rect(selection.rect_px().grow(2), Color("f2c14e"), false, 2.0)
		return
	var t := float(Data.TILE)
	var info := cost_preview()
	var ok: bool = info[1]
	var tint := Color(0.3, 0.85, 0.45, 0.35) if ok else Color(0.95, 0.3, 0.25, 0.35)
	if dragging:
		var r := rect_between(drag_from, hover)
		if tool == "wall":
			for c in lot.wall_cells(r):
				draw_rect(Rect2(Vector2(c) * t, Vector2(t, t)), Color(0.36, 0.3, 0.26, 0.75))
		draw_rect(Rect2(Vector2(r.position) * t, Vector2(r.size) * t), tint)
		draw_rect(Rect2(Vector2(r.position) * t, Vector2(r.size) * t), tint.lightened(0.4), false, 2.0)
	elif tool == "land":
		var p := GameState.plot_at(hover)
		if not p.is_empty():
			var pr: Rect2i = p["rect"]
			var rr := Rect2(Vector2(pr.position) * t, Vector2(pr.size) * t)
			draw_rect(rr, tint)
			draw_rect(rr, tint.lightened(0.4), false, 3.0)
	elif Data.FURNITURE.has(tool):
		var d := dir_for(tool, hover)
		var ghost := Furniture.new()
		ghost.type = tool
		ghost.cell = hover
		ghost.dir = d
		ghost.size = lot.furniture_size(tool, d)
		Art.furniture(self, ghost, lot.inside_dir(ghost) if ghost.on_wall() else -1)
		draw_rect(ghost.rect_px(), tint)
		# a small arrow showing which way it faces
		if tool in ["chair", "sofa"] or tool in Art.TURNS:
			var c := ghost.center_px()
			var f := Vector2(Data.DIRS[d])
			var side := Vector2(-f.y, f.x)
			draw_colored_polygon(PackedVector2Array([c + f * 16, c + f * 9 + side * 5, c + f * 9 - side * 5]), Color(1, 1, 1, 0.85))
	else:
		draw_rect(Rect2(Vector2(hover) * t, Vector2(t, t)), tint)
	var text: String = info[0]
	if text != "":
		var font := Art.font()
		var p := Vector2(hover) * t + Vector2(t + 6, -4)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.05, 0.05, 0.07, 0.9))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE if ok else Color("ffb3a8"))
