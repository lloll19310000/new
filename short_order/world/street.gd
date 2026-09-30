extends Node2D
## Life on the street, just for looks: cars going both ways, a bus that stops
## at the bus stop, and people strolling past on the far pavement. More of
## them in the rushes, fewer late at night.

const Art = preload("res://world/art.gd")
const CAR_COLORS := [Color("c8403a"), Color("3f7fc0"), Color("f2c14e"), Color("2f9a78"), Color("e8e4dc"), Color("3b4b5a"), Color("8a5cc2")]

var cars: Array = []        # {"x", "lane", "speed", "color", "bus", "stop_t", "len"}
var walkers: Array = []     # {"x", "dir", "speed", "shirt", "skin", "hair", "step"}
var _car_t := 0.0
var _walk_t := 0.0
var bus_stop_x := 36


func _ready() -> void:
	z_index = 1


func busy() -> float:
	if GameState.phase == GameState.Phase.PLANNING:
		return 0.6
	var r: Dictionary = Data.rush_at(GameState.minute)
	var m: float = r.get("mult", 1.0)
	if GameState.minute > 21.5 * 60.0:
		m *= 0.4
	return m


func _process(delta: float) -> void:
	var sp := maxf(GameState.sim_speed(), 0.0) if GameState.phase != GameState.Phase.PLANNING else 1.0
	var dt := delta * sp
	if dt <= 0.0:
		return
	var w := Data.LOT_W * Data.TILE
	_car_t -= dt
	if _car_t <= 0.0:
		_car_t = randf_range(1.6, 4.5) / busy()
		var lane := randi() % 2
		var is_bus := randf() < 0.12 and not cars.any(func(c): return c["bus"])
		cars.append({"x": -80.0 if lane == 0 else w + 80.0, "lane": lane, "speed": randf_range(90.0, 150.0) * (0.7 if is_bus else 1.0),
			"color": Color("f2c14e") if is_bus else CAR_COLORS.pick_random(), "bus": is_bus, "stop_t": 0.0, "len": 88.0 if is_bus else 50.0})
	for c in cars:
		var dir := 1.0 if c["lane"] == 0 else -1.0
		# the bus pulls in at its stop for a moment
		if c["bus"] and c["stop_t"] >= 0.0 and absf(c["x"] - bus_stop_x * Data.TILE) < 6.0:
			c["stop_t"] += dt
			if c["stop_t"] > 3.0:
				c["stop_t"] = -1.0
			continue
		# don't drive into the car in front
		var gap := 9999.0
		for o in cars:
			if o != c and o["lane"] == c["lane"]:
				var d: float = (o["x"] - c["x"]) * dir
				if d > 0.0:
					gap = minf(gap, d - (o["len"] + c["len"]) / 2.0)
		if gap > 12.0:
			c["x"] += dir * c["speed"] * dt
	cars = cars.filter(func(c): return c["x"] > -120.0 and c["x"] < w + 120.0)
	_walk_t -= dt
	if _walk_t <= 0.0:
		_walk_t = randf_range(2.5, 7.0) / busy()
		var d := 1 if randf() < 0.5 else -1
		walkers.append({"x": -20.0 if d == 1 else w + 20.0, "dir": d, "speed": randf_range(30.0, 50.0), "shirt": Data.CLOTHES.pick_random(),
			"skin": Data.SKIN.pick_random(), "hair": Data.HAIR.pick_random(), "step": 0.0})
	for p in walkers:
		p["x"] += p["dir"] * p["speed"] * dt
		p["step"] += dt * 9.0
	walkers = walkers.filter(func(p): return p["x"] > -40.0 and p["x"] < w + 40.0)
	queue_redraw()


func _draw() -> void:
	var t := float(Data.TILE)
	# the bus stop on the far side of the road
	var bs := Vector2(bus_stop_x * t + 16, (Data.LOT_H - 0.2) * t)
	draw_line(bs, bs + Vector2(0, -22), Color("5b5f66"), 2.0)
	Art.rbox(self, Rect2(bs + Vector2(-9, -34), Vector2(18, 13)), Color("2f6db0"), Color("1f4a7a"), 2, 1)
	draw_string(Art.font(), bs + Vector2(-7, -24), "BUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("fbfbf5"))
	for c in cars:
		var y: float = (Data.SIDEWALK_Y + 1.45 + c["lane"] * 1.1) * t
		Art.car(self, Vector2(c["x"], y), 1 if c["lane"] == 0 else -1, c["color"], c["bus"])
	for p in walkers:
		var pos := Vector2(p["x"], (Data.LOT_H - 0.25) * t)
		Art.person(self, pos, Vector2(p["dir"], 0), p["shirt"], p["skin"], p["hair"], p["step"], false, false, false, "", 0.8)
