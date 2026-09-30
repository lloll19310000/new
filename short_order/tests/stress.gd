extends RefCounted
## A stress run: a big diner, a big crew, the real game loop at 8x with the
## HUD showing. Prints frame times once a second, so slow frames and crashes
## show up in the log.
##   xvfb-run -a godot --path . -- --stress --staff=40 --days=2 --speed=8

const T = preload("res://tests/autotest.gd")


static func build_big(lot) -> void:
	T.build_sample(lot)
	# a second dining room to the south, through the old front door
	lot.place_floor(Rect2i(4, 16, 16, 8), Data.FLOOR_DINER)
	lot.place_walls(Rect2i(3, 15, 18, 10))
	lot.place_door(Vector2i(11, 15))
	lot.place_door(Vector2i(15, 24))
	for y in [17, 21]:
		for x in [5, 9, 13, 17]:
			var p := Vector2i(x, y)
			lot.place_furniture("table", p, 0)
			for c in [p + Vector2i(0, -1), p + Vector2i(1, -1), p + Vector2i(0, 1), p + Vector2i(1, 1)]:
				lot.place_furniture("chair", c, lot.chair_dir_toward_table(c))
	lot.place_furniture("griddle", Vector2i(25, 4), 0)
	lot.place_furniture("jukebox", Vector2i(17, 13), 0)
	lot.place_furniture("sink", Vector2i(22, 14), 0)


static func run(main, args: PackedStringArray) -> void:
	var days := 2
	var team := 40
	var speed := 8
	for a in args:
		if a.begins_with("--days="):
			days = int(a.substr(7))
		elif a.begins_with("--staff="):
			team = int(a.substr(8))
		elif a.begins_with("--speed="):
			speed = int(a.substr(8))
	seed(20260930)
	main.new_game("Stress Diner")
	await main.get_tree().process_frame
	GameState.own_all_land()
	GameState.money = 500000.0
	build_big(main.lot)
	var order := ["cook", "server", "cook", "server", "busser", "dishwasher", "host", "server", "cook", "porter", "manager"]
	for i in team:
		GameState.candidates = [GameState.make_candidate(order[i % order.size()])]
		main.hire(0)
	Events.auto_choice = 0
	Shifts.plan_schedule(GameState.day, true)
	if "--nolot" in args:
		main.lot.visible = false
	if "--nohud" in args:
		main.hud.visible = false
	for a in args:
		if a.begins_with("--noproc="):
			# profiling: stop one node's _process (hud, Overlay, Street, People...)
			var n: Node = main.hud if a.substr(9) == "hud" else main.lot.get_node_or_null(a.substr(9))
			if n != null:
				n.process_mode = Node.PROCESS_MODE_DISABLED
	print("STRESS: %d staff, %d seats, speed %dx" % [GameState.staff.size(), main.lot.seats(), speed])
	var tree: SceneTree = main.get_tree()
	for d in days:
		main.open_diner()
		GameState.speed = speed
		var frames := 0
		var worst := 0.0
		var acc := 0.0
		var t0 := Time.get_ticks_usec()
		var total_frames := 0
		var total_time := 0.0
		var worst_day := 0.0
		while GameState.phase != GameState.Phase.REPORT:
			var f0 := Time.get_ticks_usec()
			await tree.process_frame
			var ft := (Time.get_ticks_usec() - f0) / 1000.0
			frames += 1
			total_frames += 1
			total_time += ft
			worst = maxf(worst, ft)
			worst_day = maxf(worst_day, ft)
			acc = (Time.get_ticks_usec() - t0) / 1000000.0
			if acc >= 1.0:
				print("STRESS: day %d %s  fps %3d  worst %6.1f ms  groups %2d  jobs %3d  staff at work %d" % [GameState.day, GameState.clock_text(),
					frames, worst, main.groups.size(), JobBoard.open_jobs().size(), GameState.staff.filter(func(s): return s.at_work).size()])
				print("STRESS:   process %.1f ms, %d nodes, %d draw calls" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
				frames = 0
				worst = 0.0
				t0 = Time.get_ticks_usec()
		print("STRESS DAY %d: avg %.1f ms/frame (%.0f fps), worst %.1f ms, served %d" % [GameState.day, total_time / maxf(1, total_frames),
			1000.0 * total_frames / maxf(1.0, total_time), worst_day, main.last_report.get("served", 0)])
		GameState.speed = 1
		main.start_next_day()
		await tree.process_frame
	print("STRESS: done")
	tree.quit()
