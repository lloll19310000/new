extends RefCounted
## Draws every piece of furniture that has a front, in all four directions, and
## every wall piece on all four walls, then saves screenshots. Handy after
## changing world/art.gd:
##   godot --path . -- --art
## The pictures land in the user data folder as art_*.png.

const PAIRS := [["kitchen", ["oven", "fridge", "freezer", "sink", "drinks", "ice", "handsink"]], ["diner", ["host", "till", "jukebox"]]]


static func run(main, _args: PackedStringArray) -> void:
	var lot = main.lot
	main.hud.visible = false
	GameState.own_all_land()
	# a kitchen on top, a dining room below, one wall between them
	lot.place_floor(Rect2i(2, 1, 19, 11), Data.FLOOR_KITCHEN)
	lot.place_floor(Rect2i(2, 13, 19, 11), Data.FLOOR_DINER)
	lot.place_walls(Rect2i(1, 0, 21, 13))
	lot.place_walls(Rect2i(1, 12, 21, 13))
	lot.place_door(Vector2i(10, 24))
	GameState.diner_name = "Rosie's Diner"
	GameState.rep_level = 2
	# each machine in a column, turned 0, 1, 2 and 3 quarter turns down the column
	var x := 3
	for pair in PAIRS:
		var y0: int = 2 if pair[0] == "kitchen" else 14
		for t in pair[1]:
			for d in 4:
				lot.add_furniture(t, Vector2i(x, y0 + d * 2), d)
			x += 2
			if x > 19:
				x = 3
	# wall pieces on every wall of the dining room
	lot.add_furniture("wall_art", Vector2i(4, 24), 0)
	lot.add_furniture("neon", Vector2i(6, 24), 0)
	lot.add_furniture("takeout", Vector2i(13, 24), 0)
	lot.add_furniture("wall_art", Vector2i(1, 16), 0)
	lot.add_furniture("neon", Vector2i(1, 19), 0)
	lot.add_furniture("takeout", Vector2i(1, 22), 0)
	lot.add_furniture("wall_art", Vector2i(21, 16), 0)
	lot.add_furniture("neon", Vector2i(21, 19), 0)
	lot.add_furniture("takeout", Vector2i(21, 22), 0)
	lot.add_furniture("neon", Vector2i(16, 0), 0)
	lot.add_furniture("wall_art", Vector2i(18, 0), 0)
	# the pass in the kitchen wall, with food on it
	var ps = lot.add_furniture("pass", Vector2i(12, 12), 0)
	for i in 8:
		ps.items.append({"dish": Data.DISH_ORDER[i % Data.DISH_ORDER.size()], "group": null, "q": 1.0, "plated": true, "t": 0.0})
	var ps2 = lot.add_furniture("pass", Vector2i(21, 4), 1)
	for i in 5:
		ps2.items.append({"dish": Data.DISH_ORDER[i], "group": null, "q": 1.0, "plated": true, "t": 0.0})
	# tables with food and money on them
	var tb = lot.add_furniture("table", Vector2i(12, 16), 0)
	for c in [Vector2i(12, 15), Vector2i(13, 15), Vector2i(12, 17), Vector2i(13, 17)]:
		lot.add_furniture("chair", c, lot.chair_dir_toward_table(c))
	var st = lot.add_furniture("table_small", Vector2i(16, 16), 0)
	lot.add_furniture("chair", Vector2i(16, 17), 0)
	var tb2 = lot.add_furniture("table", Vector2i(12, 20), 1)
	for c in [Vector2i(11, 20), Vector2i(11, 21), Vector2i(13, 20), Vector2i(13, 21)]:
		lot.add_furniture("chair", c, lot.chair_dir_toward_table(c))
	# a booth, and a counter with stools
	lot.add_furniture("table", Vector2i(17, 20), 1)
	for c in [Vector2i(16, 20), Vector2i(16, 21), Vector2i(18, 20), Vector2i(18, 21)]:
		lot.add_furniture("booth", c, lot.chair_dir_toward_table(c))
	for cx in range(3, 8):
		lot.add_furniture("counter", Vector2i(cx, 22), 0)
		lot.add_furniture("stool", Vector2i(cx, 21), 2)
	lot.refresh()
	tb.food_on_table = ["burger", "fries", "milkshake", "pancakes", "coffee", "pie", "soda", "icedtea"]
	st.food_on_table = ["meatloaf", "icedtea"]
	tb2.food_on_table = ["omelette", "coffee", "burger", "soda"]
	tb2.cash = 42.0
	st.cash = 18.0
	lot.queue_redraw()
	GameState.phase = GameState.Phase.SERVICE
	GameState.minute = 21 * 60.0
	var tree: SceneTree = main.get_tree()
	for area in [["kitchen", Rect2(Vector2(1, 0), Vector2(21, 13))], ["diner", Rect2(Vector2(1, 12), Vector2(21, 13))]]:
		var view: Vector2 = main.get_viewport().get_visible_rect().size
		var world: Rect2 = Rect2(area[1].position * Data.TILE, area[1].size * Data.TILE)
		var z := minf(view.x / world.size.x, view.y / world.size.y) * 0.98
		main.cam.zoom = Vector2(z, z)
		main.cam.position = world.get_center()
		for i in 6:
			await tree.process_frame
		main.get_viewport().get_texture().get_image().save_png("user://art_%s.png" % area[0])
	print("ART done")
	tree.quit()
