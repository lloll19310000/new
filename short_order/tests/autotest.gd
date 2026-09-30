extends RefCounted
const V6 = preload("res://tests/v6_checks.gd")
const V7 = preload("res://tests/v7_checks.gd")
const V8 = preload("res://tests/v8_checks.gd")
## Automatic tests. Run from a terminal in the project folder:
##   godot --headless --path . -- --autotest     plays two days as fast as possible
##   godot --path . -- --uitest                  clicks through the interface like a player
##   godot --headless --path . -- --balance      plays 7 days and prints how the crew gets along
## Add --shot to the first (without --headless) to also save screenshots.


static func check(ok: bool, what: String) -> void:
	print(("TEST ok   " if ok else "TEST FAIL ") + what)


## Starts the day and plays through the prep hour until the doors open.
static func start_day(main) -> void:
	main.open_diner()
	var guard := 0
	while GameState.phase == GameState.Phase.PREP and guard < 20000:
		guard += 1
		main.simulate(0.1)


static func build_sample(lot) -> void:
	lot.place_floor(Rect2i(4, 4, 16, 11), Data.FLOOR_DINER)
	lot.place_floor(Rect2i(20, 4, 8, 11), Data.FLOOR_KITCHEN)
	lot.place_walls(Rect2i(3, 3, 26, 13))
	lot.place_door(Vector2i(11, 15))
	for p in [Vector2i(6, 6), Vector2i(10, 6), Vector2i(14, 6), Vector2i(6, 10), Vector2i(10, 10), Vector2i(14, 10)]:
		lot.place_furniture("table", p, 0)
		for c in [p + Vector2i(0, -1), p + Vector2i(1, -1), p + Vector2i(0, 1), p + Vector2i(1, 1)]:
			lot.place_furniture("chair", c, lot.chair_dir_toward_table(c))
	# a wall between the dining room and the kitchen, with a door for the staff and the pass in it
	lot.place_walls(Rect2i(20, 4, 1, 11))
	lot.place_door(Vector2i(20, 12))
	lot.place_furniture("pass", Vector2i(20, 8), 1)
	lot.place_furniture("grill", Vector2i(21, 4), 0)
	lot.place_furniture("grill", Vector2i(21, 7), 0)
	lot.place_furniture("fryer", Vector2i(24, 4), 0)
	lot.place_furniture("drinks", Vector2i(27, 8), 0)
	lot.place_furniture("fridge", Vector2i(27, 11), 0)
	lot.place_furniture("sink", Vector2i(24, 14), 0)
	lot.place_furniture("plant", Vector2i(4, 4), 0)
	lot.place_furniture("plant", Vector2i(18, 4), 0)
	lot.place_furniture("lamp", Vector2i(4, 14), 0)
	lot.place_furniture("wall_art", Vector2i(8, 3), 0)
	# a staff room next to the kitchen
	lot.place_floor(Rect2i(29, 4, 5, 5), Data.FLOOR_STAFF)
	lot.place_walls(Rect2i(28, 3, 7, 7))
	lot.place_door(Vector2i(28, 6))
	lot.place_furniture("sofa", Vector2i(30, 5), 2)
	lot.place_furniture("oven", Vector2i(27, 5), 0)
	lot.place_furniture("prep", Vector2i(21, 11), 0)
	lot.place_furniture("freezer", Vector2i(27, 13), 0)
	lot.place_furniture("fridge", Vector2i(26, 11), 0)
	lot.place_furniture("host", Vector2i(13, 14), 0)
	lot.place_furniture("till", Vector2i(9, 13), 0)
	# a restroom off the dining room, a bin and a trap in the kitchen, a back door to the dumpster
	lot.place_floor(Rect2i(1, 5, 2, 5), Data.FLOOR_RESTROOM)
	lot.place_walls(Rect2i(0, 4, 4, 7))
	lot.place_door(Vector2i(3, 7))
	lot.place_furniture("toilet", Vector2i(1, 6), 1)
	lot.place_furniture("handsink", Vector2i(1, 8), 0)
	lot.place_furniture("bin", Vector2i(21, 14), 0)
	lot.place_furniture("handsink", Vector2i(25, 14), 0)
	lot.place_furniture("trap", Vector2i(25, 12), 0)
	lot.place_door(Vector2i(23, 3))
	lot.place_furniture("dumpster", Vector2i(22, 1), 0)


static func run(main, args: PackedStringArray) -> void:
	# a fixed seed, so a run's customers and mishaps are the same every time
	seed(20260930)
	var lot = main.lot
	var shot := "--shot" in args
	print("AUTOTEST: start")
	GameState.reset()
	Events.auto_choice = 0
	Shifts.no_surprises = true
	check(GameState.money == Data.START_MONEY and Data.START_MONEY == 25000.0, "a new game starts with $25,000")
	# land: you start with one plot and buy the rest
	GameState.money = 50000.0
	check(not lot.place_floor(Rect2i(1, 12, 3, 3), Data.FLOOR_DINER), "you can't build on land you don't own")
	check(lot.place_floor(Rect2i(8, 12, 3, 3), Data.FLOOR_DINER), "you can build on your own lot")
	var cash_before := GameState.money
	check(GameState.buy_plot("west") and GameState.money == cash_before - 4000.0 and lot.place_floor(Rect2i(1, 12, 3, 3), Data.FLOOR_DINER),
		"buying the west lot ($4,000) lets you build there")
	lot.init_grid()
	GameState.own_all_land()
	GameState.money = 50000.0
	build_sample(lot)
	check(lot.furniture_blocker("griddle", Vector2i(25, 4), 0) == "", "the griddle can be built on day 1 (no goals, no locks)")
	check(lot.furniture_blocker("grill", Vector2i(8, 12), 0) != "", "a grill can't go on the diner floor")
	check(lot.furniture_blocker("table", Vector2i(22, 10), 0) != "", "a table can't go in the kitchen")
	check(lot.has_entry(), "customers have a way in")
	# chairs face their tables, and turn when asked
	var ch = lot.furniture_at(Vector2i(6, 5))
	check(ch != null and ch.dir == 2 and ch.table != null, "a chair above a table faces down at it")
	var before_dir: int = ch.dir
	lot.rotate_furniture(ch)
	check(ch.dir == (before_dir + 1) % 4, "rotating a chair turns it")
	lot.rotate_furniture(ch)
	lot.rotate_furniture(ch)
	lot.rotate_furniture(ch)
	check(ch.dir == before_dir and ch.table != null, "four turns bring it back, still at its table")
	check(lot.place_furniture("griddle", Vector2i(25, 4), 0), "griddle placed")
	check(not lot.of_type("oven").is_empty(), "an oven placed")
	check(lot.place_furniture("takeout", Vector2i(22, 15), 0), "takeout window placed in the kitchen wall")
	check(lot.window_outside(lot.of_type("takeout")[0]).x >= 0, "the takeout window has an outside spot")
	check(lot.place_furniture("jukebox", Vector2i(17, 13), 0), "jukebox placed")
	check(lot.place_furniture("neon", Vector2i(14, 3), 0), "neon sign placed on a wall")
	check(not lot.place_furniture("neon", Vector2i(15, 8), 0), "neon sign refused off a wall")
	print("AUTOTEST: built, furniture=%d, entry=%s inside=%s, seats=%d, money=%d" % [lot.furniture.size(), lot.entry_door, lot.entry_inside, lot.seats(), GameState.money])
	check(lot.find_path(Vector2i(0, Data.SIDEWALK_Y), Vector2i(22, 8), true).is_empty(), "customers can't walk into the kitchen")
	check(not lot.find_path(Vector2i(0, Data.SIDEWALK_Y), Vector2i(22, 8), false).is_empty(), "staff can walk into the kitchen")
	for i in 3:
		main.hire(0)
	GameState.roll_candidates()
	main.hire(0)
	var pr := [
		{"cook": 1, "serve": 3, "host": 0, "wash": 4, "clean": 4, "fix": 2},
		{"cook": 3, "serve": 1, "host": 2, "wash": 3, "clean": 2, "fix": 0},
		{"cook": 4, "serve": 2, "host": 3, "wash": 1, "clean": 1, "fix": 3},
		{"cook": 2, "serve": 1, "host": 3, "wash": 3, "clean": 2, "fix": 3},
	]
	for i in GameState.staff.size():
		GameState.staff[i].priorities = pr[i]
	# these checks play whole days with everyone in all day; the schedule has its own checks
	Shifts.auto = false
	for s in GameState.staff:
		s.shift = "double"
	for s in GameState.staff:
		print("AUTOTEST: staff %s (%s) cook=%d serve=%d wage=$%.2f/hr traits=%s" % [s.person_name, s.role, s.cooking, s.service, s.wage, s.traits])
	check(lot.ready_to_open(), "checklist complete")
	GameState.special = "meatloaf"
	GameState.staff_meal = true
	Front.take_bookings = true
	Front.apps_on = true
	var cash_meal := GameState.money
	main.open_diner()
	check(GameState.phase == GameState.Phase.PREP and is_equal_approx(GameState.minute, GameState.prep_min()) and GameState.prep_min() == 9 * 60.0,
		"starting the day brings the staff in at 09:00 to prep, with the doors still shut")
	check(is_equal_approx(cash_meal - GameState.money, Data.STAFF_MEAL_COST * GameState.staff.size()), "the staff meal costs $%d a person" % int(Data.STAFF_MEAL_COST))
	var ate := 0
	var meal_seen := false
	var prep_jobs: int = JobBoard.jobs.filter(func(j): return j.kind == "prep").size()
	var guard_prep := 0
	var early := false
	while GameState.phase == GameState.Phase.PREP and guard_prep < 20000:
		guard_prep += 1
		main.simulate(0.1)
		for s in GameState.staff:
			if s.meal_left > 0.0 and s.sitting:
				meal_seen = true
		# a few early birds may come in during the last 45 minutes of prep, never before
		if GameState.phase == GameState.Phase.PREP and GameState.minute < GameState.open_min() - 46.0 and main.groups.size() > 0:
			early = true
	for s in GameState.staff:
		if s.ate_today:
			ate += 1
	var meal_ops := 0
	for k in Crew.opinions:
		if Crew.opinions[k]["hist"].has("meal"):
			meal_ops += 1
	check(meal_seen and ate == GameState.staff.size() and meal_ops >= GameState.staff.size(), "everyone sat down for the staff meal, and they like each other a little more (%d opinions)" % meal_ops)
	check(Front.bookings.size() >= Data.BOOKINGS_PER_DAY.x and not Front.visits.is_empty(), "the host took %d bookings for today, and %d regulars will come by" % [Front.bookings.size(), Front.visits.size()])
	check(prep_jobs > 0 and GameState.today["prepped"] >= 20, "cooks prepped before opening (%d jobs, %d portions)" % [prep_jobs, GameState.today["prepped"]])
	check(GameState.phase == GameState.Phase.SERVICE and GameState.minute < GameState.open_min() + 0.5 and not early,
		"the doors open by themselves at 10:00 (%s), and only a few early birds came in before that" % GameState.clock_text())
	main.critic_at = 12.5 * 60.0
	main.inspect_at = 15.0 * 60.0
	check(GameState.phase == GameState.Phase.SERVICE, "the diner opened")
	var last_hour := -1
	var safety := 0
	var shots_done := {}
	var breaks_seen := {}
	var max_break := 0
	var broke := false
	var sofa_used := false
	var jukebox_heard := false
	var sizzle_heard := false
	var tired_nudge := false
	var peak_stress := {}
	var greeted_seen := 0
	var till_seen := false
	var washed := false
	var scrubbed := false
	var on_toilet := false
	var long_wait := false
	var booked_seated := false
	var fav_regulars := 0
	while GameState.phase != GameState.Phase.REPORT and safety < 40000:
		# quiet days can pass without anyone getting tired enough for a break;
		# at noon, make sure one person is ready for one
		if not tired_nudge and GameState.minute >= 12.0 * 60.0:
			tired_nudge = true
			GameState.staff[0].energy = Data.BREAK_AT - 5.0
		safety += 1
		main.simulate(0.1)
		var on_break := 0
		for s in GameState.staff:
			peak_stress[s.person_name] = maxf(peak_stress.get(s.person_name, 0.0), s.stress)
			if s.on_break:
				on_break += 1
				breaks_seen[s.person_name] = true
				if s.rest_sofa != null and s.sitting:
					sofa_used = true
		max_break = maxi(max_break, on_break)
		for f in lot.furniture:
			if f.broken:
				broke = true
		for s in GameState.staff:
			if s.status == "Washing hands":
				washed = true
			if s.status == "Scrubbing the restroom":
				scrubbed = true
		for g in main.groups:
			if is_instance_valid(g):
				for m in g.members:
					if is_instance_valid(m) and m.get("errand") == "using":
						on_toilet = true
				if g.greeted:
					greeted_seen += 1
				if g.state == "waiting" and g.waited > 3.0:
					long_wait = true
				if g.state == "paying" and g.pay_spot != null:
					till_seen = true
				if g.booking != null and g.booking.get("state", "") == "seated":
					booked_seated = true
		if safety % 50 == 0:
			var loops: Array = main.update_loops()
			if loops[1]:
				jukebox_heard = true
			if loops[0]:
				sizzle_heard = true
		var hour := int(GameState.minute / 60.0)
		if hour != last_hour:
			last_hour = hour
			var jobs := JobBoard.count_by_type()
			var sts := []
			for s in GameState.staff:
				sts.append("%s:%s(%d%%)" % [s.person_name, s.status, int(s.energy)])
			var dirty := 0
			for i in lot.dirt.size():
				if lot.dirt[i] >= Data.DIRT_SHOW:
					dirty += 1
			var kinds := {}
			for g in main.groups:
				kinds[g.kind] = kinds.get(g.kind, 0) + 1
			print("AUTOTEST %s rush=%s groups=%s served=%d left=%d money=%d rating=%.2f plates=%d dirty_tiles=%d jobs=%s | %s" % [
				GameState.clock_text(), GameState.current_rush().get("name", "-"), kinds, GameState.today["served"], GameState.today["left"],
				GameState.money, GameState.rating, GameState.plates_clean, dirty, jobs, ", ".join(sts)])
		if shot:
			var want := ""
			if not shots_done.has("service") and GameState.minute >= 13 * 60:
				want = "service"
			for g in main.groups:
				if g.kind == "inspector" and g.state == "inspecting" and not shots_done.has("inspector"):
					want = "inspector"
				if g.kind == "critic" and g.state == "ordered" and not shots_done.has("critic"):
					want = "critic"
				if g.takeout and g.state == "ordered" and not shots_done.has("takeout"):
					want = "takeout"
			if broke and not shots_done.has("broken"):
				want = "broken"
			if not shots_done.has("evening") and GameState.minute >= 20.75 * 60:
				want = "evening"
			if want != "":
				shots_done[want] = true
				main.hud.side_panel.close()
				main.cam.position = Vector2(19, 10) * Data.TILE
				main.cam.zoom = Vector2(1.25, 1.25) if want != "evening" else Vector2(0.95, 0.95)
				await main.get_tree().create_timer(0.4).timeout
				main.get_viewport().get_texture().get_image().save_png("user://shot_%s.png" % want)
	var r: Dictionary = main.last_report
	print("AUTOTEST: report ", r)
	print("AUTOTEST: complaints ", GameState.today["complaints"])
	print("AUTOTEST: grade=", GameState.grade, " critic=", r.get("critic"))
	check(r.get("served", 0) > 20, "served a good number of customers (%d)" % r.get("served", 0))
	check(r.get("prep_used", 0) >= 10, "prepped portions went into orders (%d of %d)" % [r.get("prep_used", 0), r.get("prepped", 0)])
	var fr: Dictionary = r.get("front", {})
	check(greeted_seen > 0 or not long_wait, "the host greeted customers waiting at the door")
	check(till_seen, "customers walked up to the till to pay")
	check(fr.get("bookings", 0) + fr.get("no_shows", 0) >= 1 and (booked_seated or fr.get("bookings", 0) == 0), "bookings came in (%d, %d no-shows) and sat at their held table" % [fr.get("bookings", 0), fr.get("no_shows", 0)])
	check(fr.get("regulars", 0) >= 1, "named regulars came in (%d visits)" % fr.get("regulars", 0))
	check(fr.get("app_done", 0) >= 1 and fr.get("app_fees", 0.0) > 0.0, "delivery app drivers picked up %d orders, and the app kept $%d" % [fr.get("app_done", 0), int(fr.get("app_fees", 0.0))])
	var hl: Dictionary = r.get("health", {})
	check(on_toilet and hl.get("restroom_uses", 0) >= 3, "customers (and staff) used the restroom (%d visits)" % hl.get("restroom_uses", 0))
	check(hl.get("trash_runs", 0) >= 1, "the kitchen bin filled up and someone took the trash out (%d runs)" % hl.get("trash_runs", 0))
	check(washed, "staff washed their hands at the hand sink (%d skipped)" % hl.get("handwash_skipped", 0))
	print("AUTOTEST: health today ", hl, " scrubbed=", scrubbed)
	check(r.get("order", 0.0) > 0.0 and not Stock.pending.is_empty(), "tomorrow's delivery is ordered at night ($%d)" % int(r.get("order", 0.0)))
	var dishes: Dictionary = GameState.today["dishes"]
	print("AUTOTEST: dishes ordered ", dishes)
	check(dishes.get("pie", 0) > 0 and dishes.get("omelette", 0) > 0 and dishes.get("meatloaf", 0) > 0, "apple pie, omelettes and meatloaf get ordered")
	check(dishes.get("meatloaf", 0) > dishes.get("burger", 0), "today's special (meatloaf) is ordered more than burgers (%d vs %d)" % [dishes.get("meatloaf", 0), dishes.get("burger", 0)])
	check(r["tips"] >= r["revenue"] * 0.08, "tips are a real share of sales ($%d on $%d)" % [int(r["tips"]), int(r["revenue"])])
	var peak := 0.0
	for k in peak_stress:
		peak = maxf(peak, peak_stress[k])
	check(peak > 5.0, "a day's work builds up some stress (peaks: %s)" % [peak_stress.values().map(func(x): return int(x))])
	check(r.get("types", {}).size() >= 3, "several kinds of customer came (%s)" % [r.get("types", {})])
	check(r.get("takeout", 0) > 0, "takeout orders were handed out (%d)" % r.get("takeout", 0))
	check(GameState.grade != "", "the inspector gave a grade (%s)" % GameState.grade)
	check(r.get("critic", -1.0) >= 0.0, "the critic left a review (%.1f)" % r.get("critic", -1.0))
	check(not breaks_seen.is_empty(), "staff took breaks (%s, most at once %d)" % [breaks_seen.keys(), max_break])
	check(sofa_used, "someone rested on the sofa")
	check(jukebox_heard, "the jukebox played while open")
	check(sizzle_heard, "the grill sizzled while cooking")
	var dirty_left := 0
	for i in lot.dirt.size():
		if lot.dirt[i] >= Data.DIRT_JOB:
			dirty_left += 1
	check(dirty_left <= 3, "floors swept by the end of the day (%d dirty tiles left)" % dirty_left)
	print("AUTOTEST: a station broke today: ", broke, ", breakdowns=", r.get("breakdowns"))
	for s in GameState.staff:
		print("AUTOTEST: %s cook=%d (%.0f xp) serve=%d (%.0f xp)" % [s.person_name, s.cooking, s.xp["cooking"], s.service, s.xp["service"]])
	if shot:
		for i in 4:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png("user://shot_report.png")
	main.hud.report.visible = false
	crew_day_checks(main)
	await crew_checks(main)
	money_checks(main)
	stock_checks(main)
	books_checks(main)
	await front_checks(main)
	await kitchen_checks(main)
	await health_checks(main)
	# a broken station must survive a save
	var grill = lot.of_type("grill")[0]
	main.start_next_day()
	GameState.speed = 0   # nobody walks over and fixes it while we look
	grill.broken = true
	grill.wear = 0.7
	var chair_dirs := []
	for f in lot.of_type("chair"):
		chair_dirs.append(f.dir)
	GameState.supplier = "fresh"
	GameState.special = "pie"
	lot.of_type("grill")[1].tier = 1
	main.save_game()
	check(FileAccess.file_exists(main.SAVE_PATH), "saved")
	var furn: int = lot.furniture.size()
	var team := GameState.staff.size()
	var cash := int(GameState.money)
	var traits_before: Array = GameState.staff.map(func(s): return s.traits)
	var crew_before := crew_snapshot()
	var log_before: int = Crew.entries.size()
	var ok: bool = main.load_game()
	GameState.speed = 0
	await main.get_tree().process_frame
	lot = main.lot
	var chair_dirs2 := []
	for f in lot.of_type("chair"):
		chair_dirs2.append(f.dir)
	check(ok and lot.furniture.size() == furn and GameState.staff.size() == team and int(GameState.money) == cash,
		"load gives back the same diner (furniture %d/%d, staff %d/%d, cash %d/%d)" % [lot.furniture.size(), furn, GameState.staff.size(), team, int(GameState.money), cash])
	check(chair_dirs == chair_dirs2, "chairs keep their facing after loading")
	check(GameState.staff.map(func(s): return s.traits) == traits_before, "staff keep their traits")
	var crew_after := crew_snapshot()
	if crew_after != crew_before:
		for k in crew_after:
			if str(crew_after[k]) != str(crew_before.get(k)):
				print("AUTOTEST: save diff %s:\n  before %s\n  after  %s" % [k, crew_before.get(k), crew_after[k]])
	check(crew_after == crew_before, "hometowns, stories, managers, stress, opinions, supplier, special, land, prep, tips and loans survive a save")
	check(main.lot.of_type("grill")[1].tier == 1, "a Pro grill stays Pro")
	check(Crew.entries.size() == log_before, "the staff log survives a save (%d lines)" % Crew.entries.size())
	await old_save_check(main)
	lot = main.lot
	check(lot.of_type("grill")[0].broken, "a broken grill stays broken")
	check(JobBoard.count_by_type()["fix"] == 1, "and there's a repair job for it")
	GameState.speed = 1
	start_day(main)
	main.critic_at = -1.0
	var broken_grill = lot.of_type("grill")[0]
	var repaired := false
	for i in 1500:
		main.simulate(0.1)
		if not broken_grill.broken:
			repaired = true
		if i % 300 == 0:
			var sts := []
			for s in GameState.staff:
				sts.append("%s:%s" % [s.person_name, s.status])
			print("AUTOTEST day2 %s groups=%d served=%d left=%d jobs=%s plates=%d | %s" % [GameState.clock_text(), main.groups.size(), GameState.today["served"], GameState.today["left"], JobBoard.count_by_type(), GameState.plates_clean, ", ".join(sts)])
	for f in lot.furniture:
		if f.is_station():
			print("AUTOTEST: %s at %s wear=%.2f broken=%s" % [f.type, f.cell, f.wear, f.broken])
	check(repaired, "the grill got repaired on day 2")
	check(GameState.today["delivery_cost"] > 0.0 and Stock.pending.is_empty(), "the morning delivery came and was paid for ($%d)" % int(GameState.today["delivery_cost"]))
	await event_checks(main)
	await stress_checks(main)
	await shift_checks(main)
	print("AUTOTEST: day 2 at %s served=%d left=%d money=%d rating=%.2f" % [GameState.clock_text(), GameState.today["served"], GameState.today["left"], GameState.money, GameState.rating])
	if shot:
		main.cam.position = Vector2(16, 10) * Data.TILE
		main.cam.zoom = Vector2(1.0, 1.0)
		for i in 6:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png("user://shot_day2.png")
	await V6.run(main)
	await V7.run(main)
	await V8.run(main)
	await flavour_check(main)
	print("AUTOTEST: done")
	Sfx.quit_game()


# ------------------------------------------------------------------ the crew

## After day 1: people who worked side by side warmed up, and everyone has a story.
static func crew_day_checks(main) -> void:
	var best_work := 0.0
	for k in Crew.opinions:
		best_work = maxf(best_work, Crew.opinions[k]["hist"].get("work", 0.0))
	check(best_work >= 1.0 and best_work <= Data.REL_WORK_DAY_CAP, "coworkers warmed up working side by side (best %.1f of at most %.0f a day)" % [best_work, Data.REL_WORK_DAY_CAP])
	var stories := true
	for s in GameState.staff:
		if s.origin.get("city", "") == "" or s.bio.length() < 30 or s.id <= 0:
			stories = false
		print("AUTOTEST: %s from %s: %s" % [s.person_name, Data.hometown(s.origin), s.bio])
	check(stories, "everyone has an id, a hometown and a life story")
	var ops := 0
	for a in GameState.staff:
		for b in GameState.staff:
			if a != b and Crew.opinions.has(Crew.key(a, b)):
				ops += 1
	var n := GameState.staff.size()
	check(ops == n * (n - 1), "every person has an opinion of every coworker (%d)" % ops)
	print("AUTOTEST: crew today ", Crew.today)
	for e in Crew.entries.slice(maxi(0, Crew.entries.size() - 12)):
		print("AUTOTEST: log day %d %s" % [e["day"], e["text"]])
	for l in main.last_report.get("crew", []):
		print("AUTOTEST: report line ", l[2])


## A stand-in customer group at a spot, to see whether customers notice things.
static func fake_group(main, at: Vector2):
	var g = main.Group.new()
	g.kind = "regular"
	g.state = "seated"
	var m := Node2D.new()
	m.position = at
	g.members = [m]
	main.groups.append(g)
	return g


static func drop_fake_group(main, g) -> void:
	main.groups.erase(g)
	for m in g.members:
		m.free()
	g.members = []
	g.free()


static func set_opinion(a, b, v: float) -> void:
	var rec: Dictionary = Crew.ensure(a, b)
	rec["hist"]["test"] = 0.0
	rec["hist"]["test"] = v - Crew.opinion(a, b)


static func crew_checks(main) -> void:
	var lot = main.lot
	var st: Array = GameState.staff
	var a = st[0]
	var b = st[1]
	var c = st[2]
	var d = st[3]
	var saved_traits: Array = st.map(func(s): return s.traits.duplicate())
	for s in st:
		s.drop_job()
		s.on_break = false
		s.energy = 90.0
		s.mood = "okay"
	# history fades 5% a night
	var rec: Dictionary = Crew.ensure(a, b)
	rec["hist"]["chat"] = 20.0
	var before_fade: Dictionary = rec["hist"].duplicate()
	Crew.nightly()
	check(absf(rec["hist"]["chat"] - 19.0) < 0.01, "a night's fade turns +20 of history into +19")
	for k in before_fade:
		rec["hist"][k] = before_fade[k]
	# a dropped plate: a Tidy witness minds twice as much
	a.place_at(Vector2i(22, 10))
	b.place_at(Vector2i(23, 10))
	c.place_at(Vector2i(24, 10))
	d.place_at(Vector2i(8, 12))
	b.traits = ["tidy"]
	c.traits = []
	var ob := Crew.opinion(b, a)
	var oc := Crew.opinion(c, a)
	Crew.plate_dropped(a)
	check(is_equal_approx(Crew.opinion(b, a), ob - 8.0) and is_equal_approx(Crew.opinion(c, a), oc - 4.0),
		"a dropped plate costs 4 with each witness, 8 with a Tidy one")
	# friends side by side work faster
	var Job = load("res://people/job.gd")
	set_opinion(a, b, 60.0)
	set_opinion(b, a, 60.0)
	set_opinion(a, c, 0.0)
	set_opinion(c, a, 0.0)
	set_opinion(b, c, 0.0)
	set_opinion(c, b, 0.0)
	a.job = Job.new()
	b.job = Job.new()
	var slow: float = a.work_speed(true)
	Crew.minute_step()
	check(Crew.label(a, b) == "friends" and is_equal_approx(a.crew_speed, Data.FRIEND_SPEED) and is_equal_approx(a.work_speed(true), slow * Data.FRIEND_SPEED),
		"friends within 4 tiles work 8%% faster (%.2f)" % a.crew_speed)
	b.place_at(Vector2i(8, 6))
	Crew.minute_step()
	check(is_equal_approx(a.crew_speed, 1.0), "apart again, back to normal speed")
	a.job = null
	b.job = null
	# rivals bicker, and a table that sees it loses stars
	set_opinion(c, d, -60.0)
	set_opinion(d, c, -60.0)
	c.place_at(Vector2i(9, 12))
	var g = fake_group(main, lot.cell_center(Vector2i(10, 11)))
	var fights: int = Crew.today["bickers"]
	for i in 600:
		Crew.minute_step()
		if Crew.today["bickers"] > fights:
			break
	check(Crew.label(c, d) == "rivals" and Crew.today["bickers"] > fights, "rivals placed together bicker")
	check(g.staff_trouble.has("staff arguing"), "a table that sees an argument marks it down")
	# a manager nearby breaks it up instead
	c.pause_left = 0.0
	d.pause_left = 0.0
	Crew.set_manager(b, true)
	b.place_at(Vector2i(8, 11))
	b.mood = "okay"
	var breakups: int = Crew.today["breakups"]
	Crew.bicker(c, d)
	check(Crew.today["breakups"] == breakups + 1 and c.pause_left <= 0.0, "a manager breaks up an argument")
	# phones: a coworker who isn't a friend minds, customers notice, a manager steps in
	b.place_at(Vector2i(30, 12))
	set_opinion(a, d, 0.0)
	set_opinion(d, a, 0.0)
	a.place_at(Vector2i(8, 10))
	a.job = Job.new()
	d.start_phone()
	Crew.watch_phone(d, Crew.team())
	var slack := false
	for r in Crew.reasons(a, d):
		if r[0] == Data.REL_EVENTS["phone"]["reason"]:
			slack = true
	check(slack, "a coworker who sees someone on the phone thinks less of them")
	check(g.staff_trouble.has("staff on their phone"), "customers notice staff on their phones")
	a.job = null
	set_opinion(b, d, -60.0)
	b.place_at(Vector2i(10, 12))
	b.mood = "fed_up"
	d.phone_seen = {}
	var reps: int = Crew.today["reprimands"]
	Crew.watch_phone(d, Crew.team())
	check(not d.on_phone and Crew.today["reprimands"] == reps + 1,
		"a fed-up manager who dislikes them tells them to put the phone away")
	var told := false
	for r in Crew.reasons(d, b):
		if r[0] == Data.REL_EVENTS["told_off"]["reason"]:
			told = true
	check(told, "being told off lowers their opinion of the manager")
	drop_fake_group(main, g)
	# you can catch them too; three times in a week earns a warning
	var warn: int = c.warnings
	for i in 3:
		c.start_phone()
		Crew.owner_caught(c)
	check(not c.on_phone and c.warnings == warn + 1, "caught on the phone three times in a week: a warning")
	# clicking them with the Inspect tool catches them
	d.start_phone()
	main.build.set_tool("select")
	main.build.selection = main.build.pick(d.position)
	if main.build.selection is Node and main.build.selection.get("on_phone") == true:
		Crew.owner_caught(main.build.selection)
	check(not d.on_phone, "clicking someone on their phone catches them")
	# the hiring cards warn about clashes
	a.traits = ["tidy"]
	var hints: Array = Crew.clash_hints(["clumsy"])
	check(not hints.is_empty() and hints[0].contains(a.person_name), "hiring cards warn about clashes (%s)" % [hints])
	for i in st.size():
		st[i].traits = saved_traits[i]
	Crew.refresh_labels()
	print("AUTOTEST: crew log after checks:")
	for e in Crew.entries.slice(maxi(0, Crew.entries.size() - 10)):
		print("AUTOTEST:   ", e["text"])


## Suppliers, prices and reputation.
static func money_checks(main) -> void:
	var saved_supplier: String = GameState.supplier
	for ing in Data.ING_ORDER:
		GameState.stock[ing] = 0
	GameState.supplier = "standard"
	var std := GameState.reorder_cost()
	GameState.supplier = "fresh"
	var fresh := GameState.reorder_cost()
	GameState.supplier = "budget"
	var cheap := GameState.reorder_cost()
	check(is_equal_approx(fresh, std * 1.5) and is_equal_approx(cheap, std * 0.75) and GameState.food_bonus() < 0.0,
		"suppliers change the delivery bill (budget $%d, standard $%d, farm fresh $%d) and the food" % [int(cheap), int(std), int(fresh)])
	GameState.supplier = saved_supplier
	for ing in Data.ING_ORDER:
		GameState.stock[ing] = GameState.target[ing]
	var saved_menu: Dictionary = GameState.menu.duplicate(true)
	for d in GameState.menu:
		GameState.menu[d]["price"] = Data.DISHES[d]["price"] * 1.3
	var pricey := GameState.price_demand()
	for d in GameState.menu:
		GameState.menu[d]["price"] = Data.DISHES[d]["price"] * 0.8
	var cheap_menu := GameState.price_demand()
	GameState.menu = saved_menu
	check(pricey < 0.9 and cheap_menu > 1.05, "prices change how many come (30%% up: x%.2f, 20%% down: x%.2f)" % [pricey, cheap_menu])
	var saved_served: int = GameState.totals["served"]
	var saved_rating: float = GameState.rating
	var saved_level: int = GameState.rep_level
	GameState.rep_level = 0
	GameState.totals["served"] = 150
	GameState.rating = 3.6
	check(GameState.check_level_up() and GameState.rep_level == 1 and GameState.level_info()["name"] == "Local spot", "150 customers at 3.6 stars: the diner becomes a Local spot")
	var tourists_before := false
	for i in 400:
		if main.pick_kind() == "tourist":
			tourists_before = true
	GameState.totals["served"] = 320
	GameState.rating = 3.9
	GameState.check_level_up()
	var tourists_after := false
	GameState.minute = 12.0 * 60.0
	for i in 400:
		if main.pick_kind() == "tourist":
			tourists_after = true
	check(not tourists_before and tourists_after and GameState.rep_level == 2, "tourists only come once you're a Town favourite")
	GameState.totals["served"] = saved_served
	GameState.rating = saved_rating
	GameState.rep_level = saved_level


## Health: restrooms, trash, mice, hand-washing, and what the inspector makes of it.
static func health_checks(main) -> void:
	var lot = main.lot
	var st: Array = GameState.staff
	var far := Vector2i(31, 6)
	for s in st:
		s.drop_job()
		s.place_at(far)
	# a clean kitchen doesn't get mice; a filthy one with a full bin does
	var saved_dirt: PackedFloat32Array = lot.dirt.duplicate()
	for i in lot.dirt.size():
		lot.dirt[i] = 0.0
	var saved_plates := {}
	for t in lot.tables():
		saved_plates[t] = t.dirty_plates
		t.dirty_plates = 0
	check(Health.mouse_risk() == 0.0, "a clean kitchen doesn't attract mice")
	for t in saved_plates:
		t.dirty_plates = saved_plates[t]
	for i in lot.dirt.size():
		if lot.floor_type[i] == Data.FLOOR_KITCHEN:
			lot.dirt[i] = 0.3
	var bin = lot.of_type("bin")[0]
	bin.fill = 1.2
	check(Health.mouse_risk() > 0.3 and Health.overflowing().size() == 1, "a filthy kitchen with an overflowing bin does (risk %.2f an hour)" % Health.mouse_risk())
	var grade_clean: String = lot.inspection()["grade"]
	# a mouse runs into the dining room; the table next to it sees it
	GameState.phase = GameState.Phase.SERVICE
	Health.spawn_mouse()
	var m = Health.mice[-1] if not Health.mice.is_empty() else null
	main.spawn_group("family", 2)
	var g = main.groups[-1]
	g.state = "eating"
	g.table = lot.tables()[0]
	for mem in g.members:
		mem.place_at(Vector2i(8, 12))
	m.place_at(Vector2i(9, 12))
	Health.mouse_minute(m)
	check(g.saw_mouse and g.extra_hits.has("a mouse!") and GameState.today["mouse_seen"] >= 1, "customers who see a mouse mark you down hard")
	var r: Dictionary = lot.inspection()
	check(r["notes"].has("signs of mice") and r["notes"].has("overflowing trash"), "the inspector notices the mice and the trash (%s)" % [r["notes"]])
	g.remove_now()
	# a trap by the mouse catches it (sooner or later)
	m.place_at(Vector2i(25, 13))
	var caught := false
	for i in 30:
		if not is_instance_valid(m) or m.is_queued_for_deletion() or not Health.mice.has(m):
			caught = true
			break
		Health.mouse_minute(m)
	check(caught and GameState.today["mice_caught"] >= 1, "a mouse trap catches a mouse")
	# the owner can chase one out with a click too
	Health.spawn_mouse()
	var m2 = Health.mice[-1]
	main.build.set_tool("select")
	main.build.selection = main.build.pick(m2.position)
	check(main.build.selection == m2 and m2.get("is_mouse") == true, "you can click a mouse")
	Health.remove_mouse(m2)
	GameState.phase = GameState.Phase.REPORT
	bin.fill = 0.0
	lot.dirt = saved_dirt
	Health.last_mouse_day = -99
	# no hand sink, no restroom: the inspector marks both down
	var toilet = lot.of_type("toilet")[0]
	var sinks: Array = lot.of_type("handsink")
	var with_them: float = lot.inspection()["score"]
	lot.furniture.erase(toilet)
	for hs in sinks:
		lot.furniture.erase(hs)
	r = lot.inspection()
	check(r["notes"].has("no hand sink") and r["notes"].has("no customer restroom") and r["score"] < with_them - 10.0, "no hand sink and no restroom cost inspection points")
	lot.furniture.append(toilet)
	lot.furniture.append_array(sinks)
	# a dirty toilet gets a scrub job
	toilet.grime = 0.0
	for i in 8:
		Health.used_toilet(toilet)
	check(toilet.grime >= Data.TOILET_SCRUB_AT and JobBoard.has_open("scrub", "furniture", toilet), "a well-used toilet gets a cleaning job")
	# Tidy people always wash their hands
	var tidy = st[0]
	var saved_traits: Array = tidy.traits.duplicate()
	tidy.traits = ["tidy"]
	var always := true
	for i in 50:
		if not Health.will_wash(tidy):
			always = false
	check(always, "Tidy people always wash their hands")
	tidy.traits = saved_traits
	await main.get_tree().process_frame


## The kitchen: sold-out dishes, wrong orders, allergies and cold plates.
static func kitchen_checks(main) -> void:
	var lot = main.lot
	var st: Array = GameState.staff
	var server = st[1]
	var cook = st[0]
	# a wrong dish goes back, and the right one is made
	main.spawn_group("regular", 1)
	var g = main.groups[-1]
	g.table = lot.tables()[1]
	g.state = "ordered"
	g.ordered_items = ["burger"]
	g.expected = 1
	g.order_taker = server
	g.mixups = [["meatloaf", "burger"]]
	var wrongs: int = GameState.today["wrong_orders"]
	var before := Crew.opinion(cook, server)
	g.receive(["meatloaf"], [0.7], server, [cook])
	var remake = null
	for j in JobBoard.jobs:
		if j.group == g and j.kind == "cook" and j.remake:
			remake = j
	check(g.received.is_empty() and g.remakes == 1 and remake != null and remake.items == ["burger"] and GameState.today["wrong_orders"] == wrongs + 1,
		"a wrong dish is sent back and the right one goes on a new ticket")
	check(Crew.opinion(cook, server) < before and g.extra_hits.has("a wrong order"), "the cook isn't pleased with the server, and the table marks it down")
	g.receive(["burger"], [0.7], server, [cook])
	check(g.received == ["burger"] and g.state == "eating", "then the right burger arrives")
	JobBoard.cancel_for_group(g)
	g.remove_now()
	# somebody who can't eat dairy never orders it
	var safe := true
	for i in 30:
		main.spawn_group("family", 3)
		g = main.groups[-1]
		g.allergy = "dairy"
		g.table = lot.tables()[1]
		g.state = "seated"
		g.place_order(server)
		for d in g.allergic_items:
			if Data.DISHES[d]["needs"].has("dairy"):
				safe = false
		JobBoard.cancel_for_group(g)
		g.remove_now()
	check(safe, "customers with a dairy allergy don't order dairy")
	# if nobody flags it, the kitchen slips up sooner or later
	var reacted := false
	for i in 60:
		main.spawn_group("regular", 1)
		g = main.groups[-1]
		g.table = lot.tables()[1]
		g.state = "ordered"
		g.allergy = "bread"
		g.allergy_flagged = false
		g.ordered_items = ["burger"]
		g.allergic_items = ["burger"]
		g.expected = 1
		g.receive(["burger"], [0.7], server, [cook])
		if g.state == "leaving" and GameState.today["allergies"] > 0:
			reacted = true
		JobBoard.cancel_for_group(g)
		g.remove_now()
		if reacted:
			break
	check(reacted and GameState.last_allergy_day == GameState.day, "an unflagged allergy leads to a reaction sooner or later")
	# sold out: a trucker who wants a burger settles for something else, and minds
	var saved_meat: int = GameState.stock["meat"]
	GameState.stock["meat"] = 0
	Stock.reconcile()
	Stock.prepped = {}
	var disappointed := false
	for i in 40:
		main.spawn_group("trucker", 1)
		g = main.groups[-1]
		g.table = lot.tables()[1]
		g.state = "seated"
		g.place_order(server)
		var bad: bool = g.ordered_items.has("burger") or g.ordered_items.has("meatloaf")
		if g.sold_out_hits > 0 and g.extra_hits.has("their first choice was sold out") and not bad:
			disappointed = true
		JobBoard.cancel_for_group(g)
		g.remove_now()
		if disappointed:
			break
	check(disappointed, "when burgers are sold out, a trucker picks something else and is let down")
	GameState.stock["meat"] = saved_meat
	Stock.reconcile()
	# food cools on the pass
	var Staff = load("res://people/staff.gd")
	check(is_equal_approx(Staff.cooled(0.8, 2.0), 0.8) and Staff.cooled(0.8, 12.0) < 0.6, "food left on the pass goes cold (0.80 hot, %.2f after 12 minutes)" % Staff.cooled(0.8, 12.0))
	for x in main.groups.duplicate():
		if not is_instance_valid(x) or x.state == "gone":
			main.groups.erase(x)
	await main.get_tree().process_frame


## The front of house: dine and dash, complaints, favourite servers.
static func front_checks(main) -> void:
	var lot = main.lot
	var st: Array = GameState.staff
	var far := Vector2i(31, 6)
	for s in st:
		s.drop_job()
		s.place_at(far)
	# nobody watching a table that wants to pay: sooner or later they walk out
	main.spawn_group("student", 2)
	var g = main.groups[-1]
	g.state = "paying"
	g.bill = 30.0
	g.pay_wait = 10.0
	var dashes: int = GameState.today["dashes"]
	for i in 600:
		g.try_dash(1.0)
		if g.state != "paying":
			break
	check(GameState.today["dashes"] == dashes + 1 and GameState.today["dash_lost"] >= 30.0, "students left alone at the till walk out without paying")
	g.remove_now()
	# ...but not with someone right there
	main.spawn_group("student", 2)
	g = main.groups[-1]
	g.state = "paying"
	g.pay_wait = 10.0
	st[0].place_at(lot.to_cell(g.members[0].position))
	for i in 600:
		g.try_dash(1.0)
	check(g.state == "paying", "nobody dashes with a staff member watching")
	g.remove_now()
	st[0].place_at(far)
	# a complaint: a manager comps the meal when it's about the food
	var m = st[2]
	Crew.set_manager(m, true)
	main.spawn_group("regular", 1)
	g = main.groups[-1]
	g.table = lot.tables()[0]
	g.received = ["burger"]
	g.bill = 16.0
	g.state = "eating"
	g.start_complaint("the food")
	var job = null
	for j in JobBoard.jobs:
		if j.kind == "complaint" and j.group == g:
			job = j
	check(job != null and m.can_take(job) and not st[0].can_take(job), "an unhappy table asks for the manager, and only a manager goes")
	var revenue: float = GameState.today["revenue"]
	g.resolve_complaint("comp", m)
	check(g.comped and g.state == "leaving" and is_equal_approx(GameState.today["revenue"], revenue) and GameState.today["comped"] >= 16.0,
		"the manager gives them the meal on the house")
	JobBoard.cancel_for_group(g)
	g.remove_now()
	Crew.set_manager(m, false)
	# no manager on shift: you're asked
	var managers: Array = st.filter(func(s): return s.manager)
	for s in managers:
		s.role = "server"
	Events.auto_choice = 0
	main.spawn_group("regular", 1)
	g = main.groups[-1]
	g.table = lot.tables()[0]
	g.state = "eating"
	Front.cards_today = 0
	g.start_complaint("a slow order")
	check(g.review_bonus >= 0.5 and g.state != "complaining", "with no manager on shift, you choose: an apology")
	g.remove_now()
	for s in managers:
		s.role = "manager"
	# a regular's favourite server
	var r: Dictionary = Front.regulars[0]
	Front.after_visit(r, 5.0, [st[1]])
	Front.after_visit(r, 4.8, [st[1]])
	check(Front.fav_staff(r) == st[1] and r["loyalty"] > 50.0, "%s comes to like %s after two great visits" % [r["name"], st[1].person_name])
	# greeted customers wait longer
	main.spawn_group("family", 2)
	g = main.groups[-1]
	var plain: float = g.table_patience()
	g.greeted = true
	check(g.table_patience() > plain * 1.5, "greeted customers wait longer for a table")
	g.remove_now()
	for x in main.groups.duplicate():
		if is_instance_valid(x) and x.state == "gone":
			main.groups.erase(x)
	await main.get_tree().process_frame


## The books: tips belong to the staff, bills come weekly, loans get paid back.
static func books_checks(main) -> void:
	var r: Dictionary = main.last_report
	var staff_tips := 0.0
	for s in GameState.staff:
		staff_tips += s.tips_today
	check(r["tips"] > 20.0 and absf(staff_tips - r["tips"]) < 0.5, "the day's tips went to the staff, not the till ($%d of $%d)" % [int(staff_tips), int(r["tips"])])
	check(r.has("numbers") and r["numbers"]["food"] > 0.05 and r["numbers"]["staff"] > 0.05, "the report works out food cost (%d%%) and staff cost (%d%%)" % [int(r["numbers"]["food"] * 100), int(r["numbers"]["staff"] * 100)])
	var n: Dictionary = Books.numbers(1000.0, 300.0, 250.0)
	check(is_equal_approx(n["food"], 0.3) and is_equal_approx(n["staff"], 0.25) and n["margin"] < 0.45, "food and staff cost are shares of sales (30%, 25%)")
	# sharing tips: the pot is split evenly between everyone who worked
	var saved_policy: String = Books.tip_policy
	Books.reset_tips()
	for s in GameState.staff:
		s.worked_today = true
	Books.tip_policy = "share"
	Books.add_tip(40.0, [GameState.staff[0]])
	Books.settle_tips()
	var even := true
	for s in GameState.staff:
		if absf(s.tips_today - 40.0 / GameState.staff.size()) > 0.01:
			even = false
	check(even, "shared tips are split evenly between everyone who worked ($%d each)" % int(40.0 / GameState.staff.size()))
	# keeping tips: the kitchen notices
	Books.reset_tips()
	for s in GameState.staff:
		s.worked_today = true
	Books.tip_policy = "keep"
	var server = GameState.staff[0]
	var cook = GameState.staff[1]
	Books.add_tip(60.0, [server])
	var before := Crew.opinion(cook, server)
	var lines: Array = Books.settle_tips()
	check(is_equal_approx(server.tips_today, 60.0) and Crew.opinion(cook, server) < before and not lines.is_empty(),
		"when servers keep their tips, the kitchen grumbles (%+.1f)" % (Crew.opinion(cook, server) - before))
	Books.tip_policy = saved_policy
	# weekly bills: rent grows with the land, utilities with the kitchen
	var saved_day: int = GameState.day
	var saved_owned: Array = GameState.owned.duplicate()
	GameState.owned = ["start"]
	var rent_small := Books.rent_week()
	GameState.owned = saved_owned
	check(rent_small == 350.0 and Books.rent_week() > rent_small, "rent is $350 a week for the first lot, more with more land ($%d)" % int(Books.rent_week()))
	check(Books.utilities_week() > Data.UTILITIES_BASE + 200, "every grill, fridge and freezer adds to the utilities ($%d a week)" % int(Books.utilities_week()))
	GameState.day = 5
	check(Books.days_to_bills() == 2 and Books.nightly_bills().is_empty(), "no bills on day 5; they're due in 2 days")
	# a loan, paid back with the bills
	var cash := GameState.money
	check(Books.take_loan(10000) and is_equal_approx(GameState.money, cash + 10000.0), "the bank lends you $10,000")
	check(not Books.take_loan(5000), "one loan at a time")
	GameState.day = 7
	var owed: float = Books.loan["owed"]
	var cash2 := GameState.money
	var paid: Dictionary = Books.nightly_bills()
	check(not paid.is_empty() and is_equal_approx(cash2 - GameState.money, paid["rent"] + paid["utilities"] + paid["loan"]) and Books.loan["owed"] < owed,
		"on the night of day 7, rent, utilities and a loan payment go out ($%d)" % int(cash2 - GameState.money))
	var payoff := Books.payoff_cost()
	check(payoff < Books.loan["owed"] and Books.pay_off() and Books.loan.is_empty(), "paying the loan off early skips the interest ($%d instead of $%d)" % [int(payoff), int(owed - paid["loan"])])
	GameState.day = saved_day


## Ingredients: what goes off, what fits, prep that's thrown out, dishes that sell out.
static func stock_checks(main) -> void:
	var saved_stock: Dictionary = GameState.stock.duplicate()
	var saved_batches: Dictionary = Stock.batches.duplicate(true)
	var saved_target: Dictionary = GameState.target.duplicate()
	var saved_day: int = GameState.day
	var waste_before: float = GameState.today["waste"]
	# veg lasts two days: a batch from yesterday goes off tonight, one from today doesn't
	Stock.batches["veg"] = [[10, GameState.day - 1, 0.4], [7, GameState.day, 0.4]]
	Stock.sync("veg")
	check(Stock.expiring("veg") == 10, "yesterday's salad veg goes off tonight (%d of 17)" % Stock.expiring("veg"))
	Stock.spoil()
	check(GameState.stock["veg"] == 7 and GameState.today["waste"] >= waste_before + 3.99, "at night it's thrown out, and counted as waste ($%.2f)" % (GameState.today["waste"] - waste_before))
	# storage: two fridges hold 280 chilled portions, and the order stops there
	check(Stock.capacity("fridge") == 2 * Data.STORAGE["fridge"]["fridge"] and Stock.capacity("freezer") == Data.STORAGE["freezer"]["freezer"] + 2 * Data.STORAGE["fridge"]["freezer"],
		"fridges and freezers set the space (%d chilled, %d frozen)" % [Stock.capacity("fridge"), Stock.capacity("freezer")])
	for ing in Data.ING_ORDER:
		GameState.target[ing] = 400
	var order := Stock.plan_order()
	var chilled := 0
	for ing in order:
		if Data.INGREDIENTS[ing]["store"] == "fridge":
			chilled += order[ing]
	check(chilled + Stock.used("fridge") <= Stock.capacity("fridge") and not Stock.short_fit.is_empty(), "a huge order is cut down to what fits (%d chilled ordered)" % chilled)
	GameState.target = saved_target
	# prepped food doesn't keep
	var w := float(GameState.today["waste"])
	Stock.prepped = {"burger": 3}
	check(Stock.toss_prep() == 3 and GameState.today["waste"] > w, "leftover prep is thrown out at night")
	# sold out: no meat and no prepped burgers means no burgers
	GameState.stock["meat"] = 0
	Stock.reconcile()
	Stock.prepped = {}
	GameState.phase = GameState.Phase.SERVICE
	Stock.sold_out = {}
	Stock.check_sold_out()
	check(Stock.is_sold_out("burger") and Stock.sold_out.has("meatloaf") and GameState.today["sold_out"].has("burger"), "with no meat left, burgers and meatloaf sell out")
	Stock.prepped = {"burger": 2}
	check(not Stock.is_sold_out("burger") and GameState.has_items(["burger", "burger"]) and not GameState.has_items(["burger", "burger", "burger"]),
		"prepped burgers can still be served when the meat's gone (2, but not 3)")
	GameState.phase = GameState.Phase.REPORT
	Stock.prepped = {}
	Stock.sold_out = {}
	GameState.today["sold_out"].clear()
	GameState.stock = saved_stock
	Stock.batches = saved_batches
	GameState.day = saved_day
	Stock.reconcile()


## Every event, forced one by one while open on day 2.
static func event_checks(main) -> void:
	var lot = main.lot
	var st: Array = GameState.staff
	# a tour bus you welcome brings tourists
	var before: int = GameState.today["types"].get("tourist", 0)
	Events.auto_choice = 0
	Events.forced = "tour_bus"
	await sim_minutes(main, 60.0)
	check(GameState.today["types"].get("tourist", 0) >= before + 4, "a welcomed tour bus brings groups of tourists (%d)" % (GameState.today["types"].get("tourist", 0) - before))
	# a power cut: nothing cooks until it's back
	Events.auto_choice = 1
	Events.forced = "power_cut"
	await sim_minutes(main, 2.0)
	var dark := not Events.powered()
	var can_cook := false
	for s in st:
		for j in JobBoard.jobs:
			if j.kind == "cook" and s.can_take(j):
				can_cook = true
	await sim_minutes(main, 60.0)
	check(dark and not can_cook and Events.powered(), "a power cut stops the kitchen, and the power comes back")
	# a bad batch, bought back
	Events.auto_choice = 0
	var bread: int = GameState.stock["bread"]
	var cash := GameState.money
	Events.fire("short_delivery")
	check(GameState.money < cash and Events.today[-1][2].contains("emergency"), "a bad batch of ingredients can be bought back at double price")
	# a celebrity
	var celebs: int = GameState.today["types"].get("celebrity", 0)
	Events.fire("celebrity")
	check(GameState.today["types"].get("celebrity", 0) == celebs + 1, "a celebrity walks in")
	# a rowdy table asked to leave
	var rowdy = Events.rowdy_group()
	if rowdy != null:
		Events.fire("rowdy")
		check(rowdy.state in ["leaving", "gone"], "a rowdy table asked to leave goes")
	else:
		print("AUTOTEST: (no table to get rowdy right now)")
	# a shouting match between rivals: telling them to cool off stops their bickering today
	var a = st[0]
	var b = st[1]
	for x in [a, b]:
		x.set_at_work(true)
		if x.on_break:
			x.end_break()
	set_opinion(a, b, -70.0)
	set_opinion(b, a, -70.0)
	Crew.refresh_labels()
	Events.auto_choice = 2
	Events.fire("staff_blowup")
	check(Events.calm.has(Crew.pair_key(a, b)), "rivals told to cool off stop bickering for the day")
	Events.auto_choice = 0
	Events.calm.clear()
	var a_stress: float = a.stress
	var b_stress: float = b.stress
	Events.fire("staff_blowup")
	check(a.stress < a_stress and b.stress > b_stress, "siding with one rival calms them and upsets the other")
	set_opinion(a, b, 0.0)
	set_opinion(b, a, 0.0)
	Crew.refresh_labels()
	# a raise
	var c = st[2]
	c.last_raise_day = GameState.day - 12
	var wage: float = c.wage
	var raise_asked := false
	for i in 20:
		if Events.raise_candidate() == c:
			raise_asked = true
			break
	Events.auto_choice = 0
	for s in st:
		if s != c:
			s.last_raise_day = GameState.day
	Events.fire("raise")
	check(raise_asked and c.wage > wage and c.raises > 0.0, "someone who's been here a while asks for a raise, and gets it ($%.2f to $%.2f an hour)" % [wage, c.wage])
	Events.auto_choice = 1
	c.last_raise_day = GameState.day - 12
	var refused_stress: float = c.stress
	Events.fire("raise")
	check(c.raise_refused == 1 and c.stress > refused_stress, "saying no to a raise stresses them out")
	# a day off
	Events.auto_choice = 0
	var d = st[3]
	for s in st:
		s.away_day = GameState.day + 5 if s != d else -1
	Events.fire("day_off")
	check(d.away_day == GameState.day + 1, "a day off is granted for tomorrow")
	for s in st:
		if s != d:
			s.away_day = -1
	# a grease fire needs a station in use
	var fired := false
	for i in 200:
		if Events.can_grease_fire():
			Events.fire("grease_fire")
			fired = true
			break
		main.simulate(0.1)
	var broken := false
	for f in lot.furniture:
		if f.broken:
			broken = true
	check(not fired or broken, "a grease fire breaks the station")
	# a festival
	Events.fire("festival")
	check(Events.festival_from >= 0.0 or GameState.minute >= 17.5 * 60.0, "a festival brings an evening crowd")
	for l in Events.today:
		print("AUTOTEST: event line ", l[2])


static func sim_minutes(main, m: float) -> void:
	var until := GameState.minute + m
	var guard := 0
	while GameState.minute < until and GameState.phase == GameState.Phase.SERVICE and guard < 20000:
		guard += 1
		main.simulate(0.1)


## Stress: burnout warns, then they quit; days off; the report says so.
static func stress_checks(main) -> void:
	Events.schedule = []
	# the one who asked for a day off is away tomorrow, then back refreshed
	var d = null
	for s in GameState.staff:
		if s.away_day == GameState.day + 1:
			d = s
	var safety := 0
	while GameState.phase != GameState.Phase.REPORT and safety < 60000:
		safety += 1
		main.simulate(0.1)
	main.hud.report.visible = false
	main.start_next_day()
	start_day(main)
	check(d != null and d.away and not d.visible, "on their day off they stay home")
	d.stress = 70.0
	await sim_minutes(main, 30.0)
	var others_at_work := GameState.staff.filter(func(s): return not s.away).size()
	safety = 0
	while GameState.phase != GameState.Phase.REPORT and safety < 60000:
		safety += 1
		main.simulate(0.1)
	check(not d.away and d.stress <= 1.0 and others_at_work == GameState.staff.size() - 1, "and come back the next day with no stress")
	main.hud.report.visible = false
	# burnout: one warning, then they quit, and their friends feel it
	var v = GameState.staff[0]
	var pal = GameState.staff[1]
	set_opinion(v, pal, 60.0)
	set_opinion(pal, v, 60.0)
	Crew.refresh_labels()
	var n: int = GameState.staff.size()
	v.stress = 95.0
	Crew.nightly()
	check(v.burnout_warned and GameState.staff.size() == n, "burning out gets a warning first")
	v.stress = 95.0
	Crew.nightly()
	check(GameState.staff.has(v) and v.burnout_nights == 2, "a second bad night is another warning, not a quit")
	v.stress = 95.0
	pal.stress = 50.0
	Crew.nightly()
	check(not GameState.staff.has(v) and GameState.staff.size() == n - 1, "burning out a third night in a row, they quit")
	check(Crew.report_lines().any(func(l): return l[2].contains("quit")), "the day's report says who quit")
	check(pal.stress >= 50.0 + Data.STRESS_FRIEND_QUIT + Data.STRESS_NIGHT - 0.01, "a friend quitting is hard on their friends (%d)" % int(pal.stress))


## Opening hours, shifts, pay, closing up, sick days and training.
static func shift_checks(main) -> void:
	# opening hours join up, and something always stays open
	GameState.set_service("breakfast", true)
	check(GameState.open_min() == 7 * 60.0 and GameState.prep_min() == 6 * 60.0, "opening for breakfast means doors at 07:00 and prep at 06:00")
	GameState.set_service("lunch", false)
	check(GameState.hours["lunch"], "you can't close for lunch between breakfast and dinner")
	GameState.set_service("breakfast", false)
	GameState.set_service("dinner", false)
	check(GameState.hours["lunch"] and GameState.close_min() == 16 * 60.0, "lunch only: close at 16:00")
	GameState.set_service("lunch", false)
	check(GameState.hours["lunch"], "something always stays open")
	GameState.set_service("dinner", true)
	check(GameState.open_min() == 10 * 60.0 and GameState.close_min() == 22 * 60.0, "lunch and dinner: 10:00 to 22:00, like before")
	# a day with an opener, a closer and doubles
	main.hud.report.visible = false
	main.start_next_day()
	while GameState.staff.size() < 4:
		if GameState.candidates.is_empty():
			GameState.roll_candidates()
		main.hire(0)
	var st: Array = GameState.staff
	for s in st:
		s.priorities = {"cook": 1, "serve": 1, "host": 2, "wash": 2, "clean": 2, "fix": 3}
		s.stress = 0.0
		s.sick_days = 0
		s.away_day = -1
		s.closed_late = false
	var opener = st[0]
	var closer = st[1]
	var dbl = st[2]
	opener.shift = "open"
	closer.shift = "close"
	dbl.shift = "double"
	st[3].shift = "double"
	check(Shifts.hours_text(opener) == "09:00–17:00" and Shifts.hours_text(closer) == "14:45–close", "shift hours: opening %s, closing %s" % [Shifts.hours_text(opener), Shifts.hours_text(closer)])
	Events.auto_choice = 0
	main.open_diner()
	check(opener.at_work and dbl.at_work and not closer.at_work and not closer.visible, "the opener and doubles come in for prep; the closer is still at home")
	await sim_until(main, 15.25 * 60.0)
	check(closer.at_work and closer.came_at >= 14.5 * 60.0, "the closer walks in at %s" % DayTimeline.clock(closer.came_at))
	await sim_until(main, 17.75 * 60.0)
	check(not opener.at_work and opener.left_at >= 17 * 60.0 and opener.left_at < 17.75 * 60.0, "the opener goes home after 8 hours (left %s)" % DayTimeline.clock(opener.left_at))
	var safety := 0
	while GameState.phase != GameState.Phase.REPORT and safety < 60000:
		safety += 1
		main.simulate(0.1)
	var all_stocked := true
	for f in main.lot.furniture:
		if f.is_station() and not f.stocked:
			all_stocked = false
	var unstocked: Array = main.lot.furniture.filter(func(f): return f.is_station() and not f.stocked).map(func(f): return f.type)
	check(all_stocked and GameState.today.get("restocked", 0) >= 5, "closing duties: every station restocked before the day ends (%d, left %s, ended %s, crew %s)" % [GameState.today.get("restocked", 0), unstocked,
		GameState.clock_text(), GameState.staff.map(func(x): return "%s:%s:%s" % [x.role, x.at_work, x.left_at])])
	var open_pay := Shifts.pay_today(opener)
	var dbl_pay := Shifts.pay_today(dbl)
	check(open_pay >= opener.wage * 7.9 and open_pay <= opener.wage * 9.6, "an opener's 8 hours pay about 8 hours at their rate ($%d at $%.2f/hr)" % [int(open_pay), opener.wage])
	var dh: float = Shifts.hours_today(dbl)
	check(dbl_pay > dbl.wage * dh * 1.1, "a double pays overtime: $%d for %.1f hours at $%.2f an hour" % [int(dbl_pay), dh, dbl.wage])
	var expect: float = dbl.wage * (8.0 + 1.5 * clampf(dh - 8.0, 0.0, 4.0) + 2.0 * maxf(0.0, dh - 12.0))
	check(is_equal_approx(dbl_pay, expect), "California overtime: time and a half past 8 hours, double time past 12 ($%d for %.1f hours)" % [int(dbl_pay), dh])
	check(is_equal_approx(Shifts.pay_for_hours(20.0, 14.0), 20.0 * (8.0 + 1.5 * 4.0 + 2.0 * 2.0)), "14 hours at $20 is $%d" % int(Shifts.pay_for_hours(20.0, 14.0)))
	check(closer.closed_late and not opener.closed_late, "the closer stayed late; the opener didn't")
	check(main.last_report["crew"].any(func(l): return l[2].contains("overtime")), "the report mentions the overtime")
	# closing then opening: a rough morning. And today someone doesn't show, and someone's late.
	main.hud.report.visible = false
	main.start_next_day()
	closer.shift = "open"
	var skipper = st[3]
	var saved_warnings: int = skipper.warnings
	skipper.warnings = 100
	skipper.mood = "okay"
	opener.shift = "double"
	for s in [opener, skipper, closer]:
		s.sick_days = 0
		s.away_day = -1
		s.set_away(false)
	Shifts.force_no_show = {skipper.id: true}
	Shifts.force_late = {opener.id: 25}
	main.open_diner()
	print("AUTOTEST: opener %s: at work %s, arrive %.0f, came %.0f, late %.0f, sick %d, away %s" % [opener.person_name, opener.at_work, opener.arrive_at, opener.came_at, opener.late_by, opener.sick_days, opener.away])
	Shifts.force_late = {}
	Shifts.force_no_show = {}
	check(is_equal_approx(closer.energy, Data.CLOPEN_ENERGY) and Shifts.today["clopen"].has(closer.person_name), "closing then opening starts them tired (%d%% energy)" % int(closer.energy))
	check(skipper.no_show and not skipper.at_work and skipper.warnings == 101 and Shifts.today["no_show"].has(skipper.person_name), "someone with a lot of warnings doesn't show up, and gets another")
	check(not opener.at_work and is_equal_approx(opener.arrive_at, GameState.prep_min() + 25.0), "someone running 25 minutes late isn't in yet")
	await sim_until(main, GameState.prep_min() + 30.0)
	check(opener.at_work and opener.came_at >= GameState.prep_min() + 25.0, "they turn up late (%s)" % DayTimeline.clock(opener.came_at))
	var grudge_before: float = Crew.ensure(closer, skipper)["hist"].get("noshow", 0.0)
	Shifts.night()
	check(Crew.ensure(closer, skipper)["hist"].get("noshow", 0.0) < grudge_before, "whoever worked is annoyed with the no-show")
	skipper.warnings = saved_warnings
	skipper.no_show = false
	skipper.set_at_work(true)
	skipper.place_at(Vector2i(22, 9))
	# sick: stay home, or come in and spread it
	var sicko = st[3]
	var mate = dbl
	Shifts.sick_choice(sicko, true)
	sicko.set_at_work(true)
	sicko.arriving = false
	sicko.heading_home = false
	mate.away = false
	sicko.away = false
	mate.set_at_work(true)
	mate.arriving = false
	mate.heading_home = false
	sicko.clock_out = false
	mate.clock_out = false
	sicko.place_at(Vector2i(22, 10))
	mate.place_at(Vector2i(23, 10))
	mate.exposure = 0.0
	GameState.phase = GameState.Phase.SERVICE
	Shifts.tick(10.0)
	if mate.exposure < 10.0:
		print("AUTOTEST: sick debug sicko at_work=%s away=%s no_show=%s sick=%s here=%s | mate here=%s dist=%.1f present=%s phase=%d" % [sicko.at_work, sicko.away, sicko.no_show, sicko.sick_at_work, sicko.is_here(), mate.is_here(), Crew.tile_dist(sicko, mate), Crew.present().map(func(x): return x.person_name), GameState.phase])
	check(sicko.sick_at_work and mate.exposure >= 10.0, "working sick, they expose whoever's nearby (%d minutes)" % int(mate.exposure))
	var slow_sick: float = sicko.work_speed(true)
	sicko.sick_at_work = false
	check(slow_sick < sicko.work_speed(true), "sick people work slower")
	Shifts.sick_choice(sicko, false)
	check(sicko.away and Shifts.today["sick_home"].has(sicko.person_name), "or they stay home")
	sicko.away = false
	sicko.sick_days = 0
	# training: working beside a better trainer, a new hire learns twice as fast
	var trainee = st[2]
	var trainer = st[0]
	trainee.cooking = 3
	trainer.cooking = 8
	trainee.set_at_work(true)
	trainer.set_at_work(true)
	trainee.arriving = false
	trainer.arriving = false
	trainee.heading_home = false
	trainer.heading_home = false
	trainee.clock_out = false
	trainer.clock_out = false
	for s in [trainee, trainer]:
		s.end_break()
		s.end_phone()
		s.pause_left = 0.0
	var Job = load("res://people/job.gd")
	var cj = Job.new()
	cj.type = "cook"
	trainee.job = cj
	trainer.job = Job.new()
	trainee.place_at(Vector2i(22, 12))
	trainer.place_at(Vector2i(23, 12))
	check(Shifts.possible_trainers(trainee).has(trainer), "someone 2+ points better can train them")
	trainee.xp["cooking"] = 0.0
	var xp0: float = trainee.xp["cooking"]
	trainee.practice(1.0)
	var alone: float = trainee.xp["cooking"] - xp0
	Shifts.set_trainer(trainee, trainer)
	var before := Crew.opinion(trainee, trainer)
	xp0 = trainee.xp["cooking"]
	trainee.practice(1.0)
	var paired: float = trainee.xp["cooking"] - xp0
	check(Shifts.trainer_near(trainee) == trainer and is_equal_approx(paired, alone * Data.TRAIN_XP), "working beside their trainer, they learn twice as fast (%.1f vs %.1f)" % [paired, alone])
	check(Crew.opinion(trainee, trainer) > before, "and they like their trainer a little more")
	trainee.job = null
	trainer.job = null
	Shifts.set_trainer(trainee, null)
	GameState.phase = GameState.Phase.PREP
	for s in st:
		s.shift = "double"
	var guard := 0
	while GameState.phase != GameState.Phase.REPORT and guard < 60000:
		guard += 1
		main.simulate(0.1)
	await main.get_tree().process_frame


static func sim_until(main, minute: float) -> void:
	var guard := 0
	while GameState.minute < minute and GameState.phase != GameState.Phase.REPORT and guard < 40000:
		guard += 1
		main.simulate(0.1)
	await main.get_tree().process_frame


## Everything about the crew that a save should keep, as plain data.
static func crew_snapshot() -> Dictionary:
	var out := {}
	for s in GameState.staff:
		var ops := {}
		for o in GameState.staff:
			if o != s:
				ops[o.id] = snappedf(Crew.opinion(s, o), 0.01)
		out[s.id] = {"name": s.person_name, "origin": s.origin, "bio": s.bio, "manager": s.manager, "warnings": s.warnings, "ops": ops,
			"stress": snappedf(s.stress, 0.01), "raise_refused": s.raise_refused, "start_skill": s.start_skill,
			"shift": s.shift, "trainer": s.trainer_id, "sick": s.sick_days}
	out["game"] = {"supplier": GameState.supplier, "special": GameState.special, "owned": GameState.owned.duplicate(), "level": GameState.rep_level,
		"books": Books.save_data(), "prep": Stock.prep_par.duplicate(), "meal": GameState.staff_meal, "pending": Stock.pending.duplicate(),
		"hours": GameState.hours.duplicate()}
	return out


## A save from version 2 (no hometowns, no crew) still loads.
static func old_save_check(main) -> void:
	var f := FileAccess.open(main.SAVE_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data["version"] = 2
	data.erase("crew")
	for sd in data["staff"]:
		for k in ["id", "origin", "bio", "manager", "warnings", "caught_days"]:
			sd.erase(k)
	for cd in data["candidates"]:
		cd.erase("origin")
		cd.erase("bio")
	data["goals"] = ["serve10", "serve40"]
	f = FileAccess.open(main.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var ok: bool = main.load_game()
	GameState.speed = 0
	await main.get_tree().process_frame
	var fine: bool = ok and not GameState.staff.is_empty()
	for s in GameState.staff:
		if s.origin.get("city", "") == "" or s.bio == "" or s.id <= 0:
			fine = false
	for c in GameState.candidates:
		if not c.has("origin"):
			fine = false
	var n := GameState.staff.size()
	check(fine and Crew.opinions.size() == n * (n - 1), "a version 2 save loads, and everyone gets a hometown and first impressions")
	check(GameState.owned.size() == Data.PLOTS.size() and GameState.stock.has("eggs") and GameState.target["fruit"] > 0,
		"an old save owns all its land and gets eggs and fruit on order")
	main.save_game()


## Hometowns are flavour: two diners that differ only in where people are from
## play out exactly the same.
static func flavour_check(main) -> void:
	var results: Array = []
	for variant in 2:
		main.new_game()
		await main.get_tree().process_frame
		GameState.own_all_land()
		GameState.money = 50000.0
		GameState.sim_time = 0.0
		main.prune_timer = 0.0
		build_sample(main.lot)
		seed(4242)
		for i in 4:
			var o: Dictionary = Data.ORIGINS[(i + variant * 7) % Data.ORIGINS.size()]
			var origin := {"country": o["country"], "city": o["cities"][0], "dish": o["dishes"][0], "place": o["places"][0]}
			var sd := {"name": ["Ann", "Ben", "Cat", "Dan"][i], "wage": 18.0, "cooking": 4 + i, "service": 7 - i,
				"skin": Data.SKIN[i], "hair": Data.HAIR[i], "traits": [["tidy"], ["clumsy"], ["chatty"], ["grumpy"]][i],
				"origin": origin, "bio": "A story."}
			main.add_staff(sd)
		for s in GameState.staff:
			s.priorities = {"cook": 1, "serve": 1, "wash": 2, "clean": 2, "fix": 3}
		seed(777)
		start_day(main)
		main.critic_at = -1.0
		main.inspect_at = -1.0
		for i in 1300:
			main.simulate(0.1)
		var ops: Array = []
		for s in GameState.staff:
			for o in GameState.staff:
				if s != o:
					ops.append(snappedf(Crew.opinion(s, o), 0.001))
		results.append({"served": GameState.today["served"], "money": snappedf(GameState.money, 0.01), "ops": ops,
			"log": Crew.entries.size(), "clock": GameState.clock_text()})
		print("AUTOTEST: flavour run %d: %s" % [variant, results[-1]])
	check(results[0]["served"] > 0 and results[0] == results[1], "hometowns are flavour only: same seed, different hometowns, same day (%d served)" % results[0]["served"])


# ------------------------------------------------------------------ balance
## A small first diner on the starting lot: 4 tables, a grill, a fryer, drinks.
static func build_starter(lot) -> void:
	lot.place_floor(Rect2i(8, 16, 10, 8), Data.FLOOR_DINER)
	lot.place_floor(Rect2i(18, 16, 6, 8), Data.FLOOR_KITCHEN)
	lot.place_walls(Rect2i(7, 15, 18, 10))
	lot.place_door(Vector2i(12, 24))
	for p in [Vector2i(9, 18), Vector2i(13, 18), Vector2i(9, 21), Vector2i(13, 21)]:
		lot.place_furniture("table", p, 0)
		for c in [p + Vector2i(0, -1), p + Vector2i(1, -1), p + Vector2i(0, 1), p + Vector2i(1, 1)]:
			lot.place_furniture("chair", c, lot.chair_dir_toward_table(c))
	lot.place_walls(Rect2i(18, 16, 1, 8))
	lot.place_door(Vector2i(18, 22))
	lot.place_furniture("pass", Vector2i(18, 18), 1)
	lot.place_furniture("grill", Vector2i(19, 16), 0)
	lot.place_furniture("fryer", Vector2i(22, 16), 0)
	lot.place_furniture("drinks", Vector2i(23, 18), 0)
	lot.place_furniture("fridge", Vector2i(23, 20), 0)
	lot.place_furniture("sink", Vector2i(21, 23), 0)
	lot.place_furniture("bin", Vector2i(20, 23), 0)
	lot.place_furniture("handsink", Vector2i(23, 23), 0)
	lot.place_furniture("plant", Vector2i(8, 16), 0)


## godot --headless --path . -- --balance
## Plays 7 days with 5 staff and prints how the crew gets along.
static func run_balance(main, args: PackedStringArray) -> void:
	var days := 7
	for a in args:
		if a.begins_with("--days="):
			days = int(a.substr(7))
	GameState.reset()
	Events.auto_choice = -2
	var starter := "--starter" in args
	var team := 5
	if starter:
		# a first diner on the starting lot and the starting money, with two people
		build_starter(main.lot)
		team = 2
	else:
		GameState.own_all_land()
		GameState.money = 50000.0
		build_sample(main.lot)
		main.lot.place_furniture("griddle", Vector2i(25, 4), 0)
		main.lot.place_furniture("jukebox", Vector2i(17, 13), 0)
	for a in args:
		if a.begins_with("--staff="):
			team = int(a.substr(8))
	print("BALANCE: built for $%d, cash left $%d, checklist %s" % [int(Data.START_MONEY - GameState.money), int(GameState.money), main.lot.checklist().filter(func(c): return not c[1]).map(func(c): return c[0])])
	# hire a sensible mix of roles, in this order
	var order := ["cook", "server", "cook", "server", "cook", "busser", "dishwasher", "manager", "host", "server", "cook", "busser",
		"porter", "server", "cook", "dishwasher", "host", "server", "cook", "manager"]
	for a in args:
		if a.begins_with("--roles="):
			order = Array(a.substr(8).split(","))
	for i in team:
		GameState.candidates = [GameState.make_candidate(order[i % order.size()])]
		main.hire(0)
	Front.take_bookings = true
	Front.apps_on = "--apps" in args
	GameState.staff_meal = true
	# the schedule writes itself, unless --shifts=odocc gives each person a shift by hand
	Shifts.plan_schedule(GameState.day, true)
	for a in args:
		if a.begins_with("--shifts="):
			var mix := a.substr(9)
			var letters := {"o": "open", "c": "close", "d": "double"}
			Shifts.auto = false
			for i in GameState.staff.size():
				GameState.staff[i].shift = letters.get(mix.substr(i, 1), "double")
	for s in GameState.staff:
		print("BALANCE: %s the %s (%s) %s cook=%d serve=%d shift=%s $%.2f/hr" % [s.person_name, s.role, Data.hometown(s.origin), s.traits, s.cooking, s.service, s.shift, s.wage])
	var totals := {"bickers": 0, "phones": 0, "friends": 0, "rivals": 0}
	var start_cash := GameState.money
	GameState.toast.connect(func(t: String, _k: String):
		if t.begins_with("Health inspection") or t.begins_with("Out of clean"):
			print("BALANCE: TOAST day %d %s %s" % [GameState.day, GameState.clock_text(), t]))
	var bin0 = main.lot.of_type("bin")[0]
	var spot0: Array = Health.trash_spot()
	var p0: Array = main.lot.find_path(main.lot.access_cells(bin0)[0], spot0[0], false) if not spot0.is_empty() else []
	print("BALANCE: trash walk %d tiles from %s to %s" % [p0.size(), main.lot.access_cells(bin0)[0], spot0])
	for day in days:
		# like a sensible owner: keep a bit more than yesterday used, and prep about a third of yesterday's orders
		var ran_out := {}
		for d in main.last_report.get("sold_out", []):
			for ing in Data.DISHES[d]["needs"]:
				ran_out[ing] = true
		for ing in Stock.used_yesterday:
			var want := int(Stock.used_yesterday[ing] * (2.0 if ran_out.has(ing) else 1.3))
			GameState.target[ing] = maxi(Data.START_STOCK[ing], want)
		# the kitchen waited on plates yesterday: buy a couple of packs
		if main.last_report.get("kitchen", {}).get("no_plates", 0) >= 5 and GameState.spend(Data.PLATE_COST * 12):
			GameState.plates_total += 12
			GameState.plates_clean += 12
		for d in Stock.yesterday:
			if Stock.prep_par.has(d):
				Stock.prep_par[d] = maxi(Data.START_PREP[d], int(Stock.yesterday[d] * 0.4))
		start_day(main)
		var safety := 0
		var peak := {}
		var in_state := {}     # group state -> minutes summed over groups
		var seen := {}         # group -> true
		var doing := {}        # what staff spent their time on (minutes)
		var gone_from := {}    # the state groups were in when they walked out
		var prev_state := {}
		while GameState.phase != GameState.Phase.REPORT and safety < 60000:
			safety += 1
			var m0 := GameState.minute
			main.simulate(0.1)
			var dm := maxf(0.0, GameState.minute - m0)
			for s in GameState.staff:
				peak[s.person_name] = maxf(peak.get(s.person_name, 0.0), s.stress)
				if GameState.phase == GameState.Phase.SERVICE and s.at_work and not s.away:
					var what: String = "break" if s.on_break else ("phone" if s.on_phone else (s.job.kind if s.job != null else "idle"))
					doing[what] = doing.get(what, 0.0) + dm
			for g in main.groups:
				if is_instance_valid(g) and not g.takeout and g.kind != "inspector":
					seen[g] = true
					in_state[g.state] = in_state.get(g.state, 0.0) + dm
					if g.state == "leaving" and prev_state.get(g, "") not in ["", "leaving", "paying", "eating"]:
						gone_from[prev_state[g]] = gone_from.get(prev_state[g], 0) + 1
					prev_state[g] = g.state
		var per := {}
		for k in in_state:
			per[k] = snappedf(in_state[k] / maxf(1.0, seen.size()), 0.1)
		var dsum := 0.0
		for k in doing:
			dsum += doing[k]
		var dshare := {}
		for k in doing:
			if doing[k] / dsum >= 0.01:
				dshare[k] = int(100.0 * doing[k] / dsum)
		print("BALANCE: day %d groups %d, minutes per group by state %s | walked out while %s" % [GameState.day, seen.size(), per, gone_from])
		print("BALANCE: day %d staff time %% (open hours) %s | trash runs %d (%.1f min each), restroom %d, staff minutes %d" % [GameState.day, dshare, GameState.today["trash_runs"], doing.get("trash", 0.0) / maxf(1, GameState.today["trash_runs"]), GameState.today["restroom_uses"], int(dsum)])
		print("BALANCE: day %d stress peaks %s | cash %d (tips %d on sales %d) | events %s | quits %s burnout %s | complaints %s" % [GameState.day,
			peak.values().map(func(x): return int(x)), int(GameState.money), int(GameState.today["tips"]), int(GameState.today["revenue"]),
			Events.today.map(func(l): return l[2]), Crew.today["quits"], Crew.today["burnout"], GameState.today["complaints"]])
		var rr: Dictionary = main.last_report
		print("BALANCE: day %d kitchen: delivery $%d, food used $%d, waste $%d %s, prepped %d used %d, sold out %s, order $%d won't fit %s | dishes %s" % [GameState.day,
			int(rr.get("supplies", 0)), int(rr.get("food_used", 0)), int(rr.get("waste", 0)), rr.get("waste_items", []), rr.get("prepped", 0), rr.get("prep_used", 0),
			rr.get("sold_out", []), int(rr.get("order", 0)), rr.get("short_fit", {}), GameState.today["dishes"]])
		# like a sensible owner: replace anyone who quit with someone for the same kind of job
		var have := {}
		for s in GameState.staff:
			have[s.role] = have.get(s.role, 0) + 1
		var want_roles := {}
		for i in team:
			want_roles[order[i % order.size()]] = want_roles.get(order[i % order.size()], 0) + 1
		for r in want_roles:
			while have.get(r, 0) < want_roles[r]:
				GameState.candidates = [GameState.make_candidate(r)]
				main.hire(0)
				have[r] = have.get(r, 0) + 1
		var t: Dictionary = Crew.today
		var labels := {}
		for k in Crew.labels:
			labels[Crew.labels[k]] = labels.get(Crew.labels[k], 0) + 1
		var phone_starts := 0
		for e in Crew.entries:
			if e["day"] == GameState.day and e["icon"] == "phone":
				phone_starts += 1
		totals["bickers"] += t["bickers"]
		totals["phones"] += phone_starts
		print("BALANCE: day %d front %s | numbers %s | kitchen %s" % [GameState.day, rr.get("front", {}), rr.get("numbers", {}), rr.get("kitchen", {})])
		var hs: Dictionary = GameState.today.get("hit_sum", {})
		var nrev: int = GameState.today["scores"].size()
		var hs2 := {}
		for k in hs:
			hs2[k] = snappedf(hs[k] / maxf(1, nrev), 0.01)
		print("BALANCE: day %d shifts late %s no-show %s sick home %s sick in %s days off %s" % [GameState.day, Shifts.today["late"], Shifts.today["no_show"], Shifts.today["sick_home"], Shifts.today["sick_in"], GameState.staff.filter(func(s): return s.away_day == GameState.day).map(func(s): return s.person_name)])
		print("BALANCE: day %d stars lost per review (%d reviews): %s" % [GameState.day, nrev, hs2])
		var nb: Dictionary = rr.get("numbers", {})
		var on_days := GameState.staff.filter(func(s): return s.came_at >= 0.0).size()
		print("SUMMARY day %2d | served %3d left %3d | sales $%5d payroll $%5d (%2d%%) food %2d%% | profit $%6d | cash $%6d | rating %.2f | %d staff, %d came in, %d off | quits %s breakdowns %d" % [
			GameState.day, rr.get("served", 0), rr.get("left", 0), int(rr.get("revenue", 0.0)), int(rr.get("wages", 0.0)), int(nb.get("staff", 0.0) * 100),
			int(nb.get("food", 0.0) * 100), int(nb.get("profit", 0.0)), int(GameState.money), GameState.rating, GameState.staff.size(), on_days,
			GameState.staff.size() - on_days, Crew.today["quits"], rr.get("breakdowns", 0)])
		print("BALANCE: day %d served=%d left=%d rating=%.2f | labels=%s bickers=%d breakups=%d phone-lines=%d new friends=%s new rivals=%s" % [
			GameState.day, GameState.today["served"], GameState.today["left"], GameState.rating, labels,
			t["bickers"], t["breakups"], phone_starts, t["new_friends"], t["new_rivals"]])
		main.hud.report.visible = false
		main.start_next_day()
	var labels := {}
	for k in Crew.labels:
		labels[Crew.labels[k]] = labels.get(Crew.labels[k], 0) + 1
	print("BALANCE: after %d days: labels=%s, bickers=%d, phone log lines=%d, log=%d lines" % [days, labels, totals["bickers"], totals["phones"], Crew.entries.size()])
	for s in GameState.staff:
		var bits: Array = []
		for o in GameState.staff:
			if o != s:
				bits.append("%s %+d" % [o.person_name, int(Crew.opinion(s, o))])
		print("BALANCE: %s thinks: %s" % [s.person_name, ", ".join(bits)])
	for e in Crew.entries.slice(maxi(0, Crew.entries.size() - 25)):
		print("BALANCE: log day %d %02d:%02d %s" % [e["day"], int(e["min"]) / 60, int(e["min"]) % 60, e["text"]])
	if "--shots" in args:
		# one more morning and lunchtime, with the Crew page open, for screenshots
		main.hud.side_panel.open("crew")
		for i in 6:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png("user://balance_crew.png")
		start_day(main)
		while GameState.minute < 12.5 * 60.0:
			main.simulate(0.1)
		main.hud.side_panel.open("staff")
		main.cam.position = Vector2(20, 9) * Data.TILE
		main.cam.zoom = Vector2(1.6, 1.6)
		for i in 6:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png("user://balance_lunch.png")
	Sfx.quit_game()


# ------------------------------------------------------------------ UI test
## Clicks through the interface the way a player would:
##   godot --path . -- --uitest
## Add --shots=name to save screenshots as user://name_*.png

## Where a cell is in real window pixels (the window may be scaled up or down).
static func screen_of(main, cell: Vector2i) -> Vector2:
	var vp: Viewport = main.get_viewport()
	return vp.get_screen_transform() * (vp.get_canvas_transform() * main.lot.cell_center(cell))


static func mouse(main, cell: Vector2i, pressed: bool) -> void:
	var p := screen_of(main, cell)
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	Input.parse_input_event(mv)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = p
	mb.global_position = p
	Input.parse_input_event(mb)
	Input.flush_buffered_events()
	await main.get_tree().process_frame


static func move_to(main, cell: Vector2i) -> void:
	var p := screen_of(main, cell)
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mv)
	Input.flush_buffered_events()
	await main.get_tree().process_frame


static func drag(main, a: Vector2i, b: Vector2i) -> void:
	await mouse(main, a, true)
	await move_to(main, b)
	await mouse(main, b, false)


## A click at a point in the world (not a tile), for clicking people.
static func click_world(main, p: Vector2) -> void:
	var vp: Viewport = main.get_viewport()
	var sp: Vector2 = vp.get_screen_transform() * (vp.get_canvas_transform() * p)
	for pressed in [true, false]:
		var mv := InputEventMouseMotion.new()
		mv.position = sp
		mv.global_position = sp
		Input.parse_input_event(mv)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = sp
		mb.global_position = sp
		Input.parse_input_event(mb)
		Input.flush_buffered_events()
		await main.get_tree().process_frame


static func click(main, c: Vector2i) -> void:
	await mouse(main, c, true)
	await mouse(main, c, false)


static func key(main, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await main.get_tree().process_frame


static func find_buttons(node: Node, text: String) -> Array:
	var out := []
	for c in node.get_children():
		if c is Button and c.text.begins_with(text) and c.is_visible_in_tree():
			out.append(c)
		out.append_array(find_buttons(c, text))
	return out


static func snap(main, name: String, prefix: String) -> void:
	for i in 4:
		await main.get_tree().process_frame
	if prefix != "":
		main.get_viewport().get_texture().get_image().save_png("user://%s_%s.png" % [prefix, name])


## Checks that nothing in the interface pokes out of the window.
static func check_fits(main, what: String) -> void:
	var view: Vector2 = main.get_viewport().get_visible_rect().size / main.hud.scale.x
	var bad := []
	for n in [main.hud.top_bar, main.hud.build_menu, main.hud.side_panel, main.hud.checklist, main.hud.today_card, main.hud.tickets_card, main.hud.inspect_card]:
		if not n.is_visible_in_tree():
			continue
		var r: Rect2 = n.get_global_rect()
		if r.position.x < -1 or r.position.y < -1 or r.end.x > view.x + 1 or r.end.y > view.y + 1:
			bad.append("%s %s" % [n.name, r])
	check(bad.is_empty(), "everything fits on screen %s at %s %s" % [what, view, bad])


## Puts the camera so cells (4..21, 5..14) sit in the open middle of the
## screen, clear of the checklist, the side panel and the build tray.
static func frame_build_area(main) -> void:
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	var free := Rect2(Vector2(330, 64), Vector2(view.x - 330 - 440, view.y - 64 - 290))
	var world := Rect2(Vector2(8, 13) * Data.TILE, Vector2(18, 10) * Data.TILE)
	var z := minf(free.size.x / world.size.x, free.size.y / world.size.y) * 0.95
	main.cam.zoom = Vector2(z, z)
	main.cam.position = world.get_center() - (free.get_center() - view / 2.0) / z


static func run_ui(main, args: PackedStringArray) -> void:
	var tree: SceneTree = main.get_tree()
	var prefix := ""
	for a in args:
		if a.begins_with("--shots="):
			prefix = a.substr(8)
	var hud = main.hud
	print("UITEST: start, window %s, view %s" % [main.get_window().size, main.get_viewport().get_visible_rect().size])
	check(hud.start.visible, "the main menu shows")
	await snap(main, "start", prefix)
	hud.start.new_button.pressed.emit()
	await tree.process_frame
	check(hud.start.pages["new"].visible, "New diner asks what it's called")
	hud.start.name_edit.text = "Test Kitchen"
	await snap(main, "start_new", prefix)
	hud.start.start_button.pressed.emit()
	await tree.process_frame
	check(hud.help.visible and GameState.diner_name == "Test Kitchen" and main.slot != "" and FileAccess.file_exists(main.SAVE_PATH),
		"a new diner opens, with its name, in its own save slot (%s)" % main.slot)
	await snap(main, "help", prefix)
	find_buttons(hud.help, "Got it")[0].pressed.emit()
	check(not hud.help.visible, "help closes")
	Input.use_accumulated_input = false
	check(GameState.money == Data.START_MONEY, "a new game starts with $%d" % int(Data.START_MONEY))
	check(hud.top_bar.level.text != "", "the top bar shows the diner's reputation (%s)" % hud.top_bar.level.text)
	# buy the east lot with the Buy land tool
	hud.build_menu.choose("land")
	main.cam.zoom = Vector2(0.8, 0.8)
	main.cam.position = main.lot.cell_center(Vector2i(33, 18))
	await tree.process_frame
	await snap(main, "land", prefix)
	var before_land := GameState.money
	await click(main, Vector2i(33, 18))
	check(GameState.owned.has("east") and GameState.money == before_land - 8000.0, "the Buy land tool buys the east lot for $8,000")
	# or just click a plot for sale and buy it from the card
	hud.build_menu.choose("select")
	main.cam.position = main.lot.cell_center(Vector2i(3, 18))
	await tree.process_frame
	await click(main, Vector2i(3, 18))
	await tree.process_frame
	check(hud.inspect_card.visible and hud.inspect_card.buy_button.visible and not hud.inspect_card.buy_button.disabled,
		"clicking land for sale offers to buy it (%s)" % hud.inspect_card.buy_button.text)
	await snap(main, "land_click", prefix)
	var before_west := GameState.money
	hud.inspect_card.buy_button.pressed.emit()
	check(GameState.owned.has("west") and GameState.money == before_west - 4000.0 and not hud.inspect_card.buy_button.visible, "and the Buy button buys it")
	frame_build_area(main)
	await tree.process_frame
	check_fits(main, "in the morning")
	hud.build_menu.choose("floor_diner")
	check(main.build.tool == "floor_diner", "picked Diner floor from the Structure tray")
	await drag(main, Vector2i(9, 14), Vector2i(18, 21))
	hud.build_menu.choose("floor_kitchen")
	await drag(main, Vector2i(19, 14), Vector2i(24, 21))
	hud.build_menu.choose("wall")
	await drag(main, Vector2i(8, 13), Vector2i(25, 22))
	hud.build_menu.choose("door")
	await click(main, Vector2i(13, 22))
	print("UITEST: after walls money=%d entry=%s" % [GameState.money, main.lot.entry_door])
	check(main.lot.has_entry(), "door built through the mouse")
	hud.build_menu.choose("table")
	for p in [Vector2i(10, 16), Vector2i(14, 16), Vector2i(10, 19), Vector2i(14, 19)]:
		await click(main, p)
	hud.build_menu.choose("chair")
	for p in [Vector2i(10, 15), Vector2i(11, 15), Vector2i(10, 17), Vector2i(11, 17), Vector2i(14, 15), Vector2i(15, 15), Vector2i(14, 17), Vector2i(15, 17),
			Vector2i(10, 20), Vector2i(11, 20), Vector2i(14, 20), Vector2i(15, 20)]:
		await click(main, p)
	var c1 = main.lot.furniture_at(Vector2i(10, 15))
	var c2 = main.lot.furniture_at(Vector2i(10, 17))
	check(c1 != null and c1.dir == 2 and c2 != null and c2.dir == 0, "chairs placed with the mouse face their tables")
	hud.build_menu.choose("grill")
	await click(main, Vector2i(20, 14))
	hud.build_menu.choose("fryer")
	await click(main, Vector2i(22, 14))
	hud.build_menu.choose("drinks")
	await click(main, Vector2i(23, 14))
	hud.build_menu.choose("fridge")
	await click(main, Vector2i(24, 17))
	hud.build_menu.choose("sink")
	await click(main, Vector2i(24, 21))
	hud.build_menu.choose("oven")
	await click(main, Vector2i(24, 15))
	check(not main.lot.of_type("oven").is_empty(), "an oven placed with the mouse")
	await snap(main, "build_kitchen", prefix)
	check_fits(main, "with the kitchen tray open")
	# a wall between the dining room and the kitchen, a door for the staff, and the pass in the wall
	hud.build_menu.choose("wall")
	await drag(main, Vector2i(19, 14), Vector2i(19, 21))
	hud.build_menu.choose("door")
	await click(main, Vector2i(19, 20))
	hud.build_menu.choose("pass")
	await click(main, Vector2i(19, 16))
	check(not main.lot.of_type("pass").is_empty() and main.lot.of_type("pass")[0].rotated, "the pass counter goes in the kitchen wall, lined up with it")
	hud.build_menu.choose("plant")
	await click(main, Vector2i(9, 14))
	hud.build_menu.choose("host")
	await click(main, Vector2i(11, 21))
	hud.build_menu.choose("till")
	await click(main, Vector2i(16, 21))
	check(main.lot.has_type("host") and main.lot.has_type("till"), "a host stand and a till placed with the mouse")
	hud.build_menu.choose("bin")
	await click(main, Vector2i(21, 20))
	check(main.lot.has_type("bin"), "a trash can placed in the kitchen")
	hud.build_menu.choose("toilet")
	check(main.build.tool == "toilet" and hud.build_menu.tray_title.text == "Restroom", "the Restroom tray has toilets")
	await snap(main, "build_restroom", prefix)
	check_fits(main, "with the Restroom tray open")
	hud.build_menu.choose("griddle")
	check(main.build.tool == "griddle", "the griddle can be picked on day 1 (no locks)")
	# a mistake to undo: an extra table, then remove it
	hud.build_menu.choose("table")
	await click(main, Vector2i(16, 19))
	var before: int = main.lot.furniture.size()
	hud.build_menu.choose("remove")
	await drag(main, Vector2i(16, 19), Vector2i(17, 19))
	check(main.lot.furniture.size() == before - 1, "Remove took the extra table away")
	hud.build_menu.choose("select")
	# inspect a chair and turn it with the Turn button
	await click(main, Vector2i(11, 15))
	check(hud.inspect_card.visible and hud.inspect_card.thing != null, "clicking a chair shows it in the inspect card")
	var chair = main.lot.furniture_at(Vector2i(11, 15))
	if chair == null:
		print("UITEST: no chair at (7, 7), stopping")
		Sfx.quit_game()
		return
	var d0: int = chair.dir
	hud.inspect_card.rotate_button.pressed.emit()
	check(chair.dir == (d0 + 1) % 4, "the Turn button turns the chair")
	await key(main, KEY_R)
	await key(main, KEY_R)
	await key(main, KEY_R)
	check(chair.dir == d0, "R turns the selected chair too")
	await snap(main, "inspect_chair", prefix)
	# upgrade the grill to Pro from its inspect card
	await click(main, Vector2i(20, 14))
	var grill = main.lot.furniture_at(Vector2i(20, 14))
	var cash_up := GameState.money
	check(hud.inspect_card.upgrade_button.visible, "a station's inspect card offers an upgrade")
	hud.inspect_card.upgrade_button.pressed.emit()
	check(grill.tier == 1 and GameState.money == cash_up - int(Data.FURNITURE["grill"]["cost"] * Data.UPGRADE_COST), "upgrading makes the grill Pro")
	await snap(main, "inspect_pro", prefix)
	# hire a cook and a server from the Hire tab, picking the role first
	var staff_page = hud.side_panel.pages["staff"]
	staff_page.show_tab("hire")
	await tree.process_frame
	check(staff_page.candidates_box.get_child_count() >= Data.CANDIDATES_PER_DAY, "the Hire tab lists %d people" % staff_page.candidates_box.get_child_count())
	await snap(main, "hire", prefix)
	for r in ["cook", "server"]:
		staff_page.filter_buttons[r].pressed.emit()
		await tree.process_frame
		await tree.process_frame
		var hires := find_buttons(staff_page.candidates_box, "Hire")
		check(not hires.is_empty() and staff_page.candidates_box.get_children().all(func(c): return not c.has_method("setup") or c.data["role"] == r),
			"the Hire tab shows only %ss when you pick that role" % r)
		hires[0].pressed.emit()
		await tree.process_frame
		await tree.process_frame
	check(GameState.staff.size() == 2 and GameState.staff[0].role == "cook" and GameState.staff[1].role == "server", "hired a cook and a server with the Hire buttons")
	staff_page.filter_buttons[""].pressed.emit()
	await tree.process_frame
	await tree.process_frame
	var cand_cards: Array = staff_page.candidates_box.get_children().filter(func(c): return c.has_method("setup"))
	check(not cand_cards.is_empty() and cand_cards[0].bio_label.text.length() > 30 and cand_cards[0].origin_label.text.begins_with("From ")
		and cand_cards[0].tooltip_text.contains(cand_cards[0].bio_label.text.substr(0, 20)), "hiring rows show a hometown and a life story on hover")
	staff_page.show_tab("crew")
	await tree.process_frame
	await tree.process_frame
	var a = staff_page.cards[GameState.staff[0]]
	var b = staff_page.cards[GameState.staff[1]]
	check(not a.details.visible, "staff rows start closed and compact")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	a.gui_input.emit(click)
	await tree.process_frame
	check(a.details.visible, "clicking a row opens the details")
	b.set_open(true)
	await tree.process_frame
	check(b.details.visible and not a.details.visible, "only one row is open at a time")
	check(a.who.priorities["cook"] == 1 and b.who.priorities["serve"] == 1 and a.who.priorities["serve"] == 0, "a line cook cooks, a server serves, straight away")
	while b.who.priorities["host"] != 1:
		b.priority_buttons["host"].pressed.emit()
	check(b.priority_buttons.size() == 6 and b.who.priorities["host"] == 1, "staff rows have a Host priority too")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	var was: int = b.who.priorities["wash"]
	b.priority_buttons["wash"].gui_input.emit(right)
	check(b.who.priorities["wash"] == (was + 4) % 5, "right-click lowers a priority")
	a.set_open(true)
	await tree.process_frame
	check(a.priority_buttons["cook"].text == "1", "priority buttons show their number")
	check(a.bars["stress"][0].is_visible_in_tree(), "staff rows show a stress bar")
	check(a.who.shift == "double" and a.shift_button.text == "Double", "the only cook works a double (%s)" % a.shift_button.text)
	a.shift_button.pressed.emit()
	await tree.process_frame
	check(a.who.shift == "open" and a.who.shift_locked and a.shift_button.text == "Day" and a.shift_button.tooltip_text.contains("09:00–17:00"),
		"the shift button sets them to the day shift, 09:00–17:00, by hand")
	a.shift_button.pressed.emit()
	a.shift_button.pressed.emit()
	a.shift_button.pressed.emit()
	check(a.who.shift == "double" and a.who.shift_locked, "then mid, night and double")
	a.shift_button.pressed.emit()
	check(not a.who.shift_locked and a.who.shift == "double", "and once more hands it back to the schedule")
	check(a.train_button.visible, "staff rows have a training button")
	check(a.origin_label.text.contains(Data.hometown(a.who.origin)) and a.origin_label.text.contains(a.who.bio), "staff rows show the hometown and life story")
	var wage_before: float = a.who.wage
	a.manager_button.button_pressed = true
	await tree.process_frame
	check(a.who.manager and a.who.wage > wage_before, "the Make manager button promotes them ($%.2f to $%.2f an hour)" % [wage_before, a.who.wage])
	a.role_button.select(Data.ROLE_ORDER.find("cook"))
	a.role_button.item_selected.emit(Data.ROLE_ORDER.find("cook"))
	await tree.process_frame
	check(a.who.role == "cook" and a.who.priorities["cook"] == 1, "the role list puts them back on the line")
	await snap(main, "staff", prefix)
	staff_page.show_tab("schedule")
	await tree.process_frame
	await tree.process_frame
	check(staff_page.board.get_child_count() >= 2 and staff_page.auto_switch.button_pressed, "the Schedule tab shows today's shifts")
	await snap(main, "schedule", prefix)
	staff_page.show_tab("crew")
	# menu, supplies and goals pages
	hud.side_panel.tabs["menu"].pressed.emit()
	await tree.process_frame
	var menu_page = hud.side_panel.pages["menu"]
	menu_page.rows["burger"].price.value = 20.0
	menu_page.rows["coffee"].on_switch.button_pressed = false
	check(GameState.menu["burger"]["price"] == 20.0 and not GameState.menu["coffee"]["on"], "menu price and switch work")
	check(not menu_page.rows["pancakes"].on_switch.disabled, "pancakes are on the menu from day 1")
	menu_page.rows["meatloaf"].special_button.button_pressed = true
	await tree.process_frame
	check(GameState.special == "meatloaf" and menu_page.rows["meatloaf"].note.text == "Today's special", "the star makes meatloaf today's special")
	check(menu_page.price_note.text.contains("above usual"), "the menu says how prices affect customers (%s)" % menu_page.price_note.text)
	await snap(main, "menu", prefix)
	menu_page.scroll_vertical = 100000
	await tree.process_frame
	menu_page.prep_rows["burger"]["spin"].value = 9
	check(Stock.prep_par["burger"] == 9, "the Menu page sets how many burgers to prep each morning")
	await snap(main, "menu_prep", prefix)
	menu_page.scroll_vertical = 0
	hud.side_panel.tabs["supplies"].pressed.emit()
	await tree.process_frame
	var sup = hud.side_panel.pages["supplies"]
	sup.rows["meat"].set_keep(70)
	sup.rows["bread"].set_keep(120)
	sup.rows["bread"].more.pressed.emit()
	check(GameState.target["bread"] == 125 and sup.rows["bread"].amount.text == "125", "the + button keeps 5 more")
	sup.rows["bread"].less.pressed.emit()
	var plates_before := GameState.plates_total
	sup.buy_plates.pressed.emit()
	check(GameState.target["meat"] == 70 and GameState.plates_total == plates_before + 6, "supplies target and plate buying work")
	await tree.process_frame
	check(sup.space_labels["fridge"].text.contains("of %d" % Data.STORAGE["fridge"]["fridge"]), "the Supplies page shows fridge space (%s)" % sup.space_labels["fridge"].text)
	var bill_std := GameState.reorder_cost()
	sup.supplier_buttons["fresh"].pressed.emit()
	await tree.process_frame
	check(GameState.supplier == "fresh" and GameState.reorder_cost() > bill_std, "choosing a Farm fresh supplier raises the delivery bill")
	sup.supplier_buttons["standard"].pressed.emit()
	await snap(main, "supplies", prefix)
	hud.side_panel.tabs["office"].pressed.emit()
	await tree.process_frame
	var office = hud.side_panel.pages["office"]
	office.meal_switch.button_pressed = true
	check(office.visible and GameState.staff_meal, "the Office page turns on the staff meal")
	office.service_buttons["breakfast"].button_pressed = true
	check(GameState.open_min() == 7 * 60.0 and GameState.minute == 6 * 60.0, "opening for breakfast from the Office page moves the day earlier")
	await snap(main, "office_hours", prefix)
	office.service_buttons["breakfast"].button_pressed = false
	check(GameState.open_min() == 10 * 60.0, "and back to 10:00")
	office.tip_buttons["share"].pressed.emit()
	check(Books.tip_policy == "share", "the Office page switches tips to shared")
	var cash_loan := GameState.money
	office.loan_buttons[0].pressed.emit()
	await tree.process_frame
	check(not Books.loan.is_empty() and GameState.money == cash_loan + Data.LOANS[0]["amount"] and office.payoff_button.visible, "a loan from the Office page")
	await snap(main, "office", prefix)
	office.payoff_button.pressed.emit()
	office.tip_buttons["keep"].pressed.emit()
	check(Books.loan.is_empty(), "and it can be paid straight back")
	office.bookings_switch.button_pressed = true
	check(Front.take_bookings, "the Office page takes bookings once there's a host stand")
	check(office.regulars_box.get_child_count() == Data.REGULAR_START, "the Office page lists your regulars (%d)" % office.regulars_box.get_child_count())
	office.scroll_vertical = 100000
	await tree.process_frame
	await snap(main, "office_front", prefix)
	hud.side_panel.open("goals")
	await tree.process_frame
	check(hud.side_panel.pages["goals"].visible and hud.side_panel.pages["goals"].cards.size() == Data.GOALS.size(), "the Goals tab shows the board")
	await snap(main, "goals", prefix)
	check_fits(main, "with the Goals tab open")
	office.scroll_vertical = 0
	hud.side_panel.tabs["crew"].pressed.emit()
	await tree.process_frame
	var crew_page = hud.side_panel.pages["crew"]
	check(crew_page.visible and crew_page.grid.visible and crew_page.log_text.get_parsed_text().contains("joined the crew"),
		"the Crew tab shows who gets along and the staff log")
	await snap(main, "crew_morning", prefix)
	hud.side_panel.tabs["crew"].pressed.emit()
	await tree.process_frame
	check(not hud.side_panel.is_open, "clicking the open tab again hides the panel")
	await tree.create_timer(0.4).timeout
	await snap(main, "panel_closed", prefix)
	await key(main, KEY_TAB)
	check(hud.side_panel.is_open, "Tab brings the panel back")
	hud.side_panel.tabs["staff"].pressed.emit()
	print("UITEST: checklist ", main.lot.checklist().map(func(i): return i[1]))
	check(main.lot.ready_to_open(), "ready to open")
	await snap(main, "built", prefix)
	hud.top_bar.open_button.pressed.emit()
	await tree.process_frame
	check(GameState.phase == GameState.Phase.PREP and hud.top_bar.open_button.visible and hud.top_bar.open_button.text == "Open the doors",
		"Start the day brings the staff in to prep, and offers to open the doors early")
	hud.top_bar.open_button.pressed.emit()
	await tree.process_frame
	check(GameState.phase == GameState.Phase.SERVICE and not hud.top_bar.open_button.visible, "Open the doors lets customers in")
	check(hud.build_menu.categories.get_child(1).disabled, "building is off while open")
	hud.top_bar.speed_buttons[3].pressed.emit()
	check(GameState.speed == 4, "fastest speed button works")
	while GameState.minute < 13.0 * 60.0:
		main.simulate(0.1)
	await tree.create_timer(0.35).timeout
	check(hud.today_card.visible, "the Today card shows while open")
	var tickets: Array = hud.tickets_card.open_tickets()
	check(hud.tickets_card.visible == not tickets.is_empty(), "the ticket rail shows the %d open orders" % tickets.size())
	# click a staff member to inspect them
	if not GameState.staff.is_empty():
		var s = GameState.staff[0]
		main.build.selection = main.build.pick(s.position)
		hud.show_selection(main.build.selection)
	main.cam.zoom = Vector2(1.3, 1.3)
	main.cam.position = Vector2(12, 10) * Data.TILE
	# an event pauses the game and asks you to choose
	Events.forced = "tour_bus"
	for i in 30:
		main.simulate(0.1)
		if hud.event_card.visible:
			break
	await tree.process_frame
	check(hud.event_card.visible and GameState.speed == 0, "an event pauses the game and asks what to do")
	await snap(main, "event", prefix)
	var opts: Array = hud.event_card.option_buttons()
	opts[0].pressed.emit()
	await tree.process_frame
	check(not hud.event_card.visible and GameState.speed > 0 and not Events.spawns.is_empty(), "choosing an answer carries on (the tour bus is coming)")
	# someone sneaks onto their phone; click them to catch them
	var sneak = GameState.staff[1]
	sneak.start_phone()
	sneak.phone_left = 60.0
	for o in GameState.staff:
		sneak.phone_seen[o.id] = true     # nobody else reacts, so only your click can end it
	hud.build_menu.choose("select")
	main.cam.position = sneak.position + Vector2(-60, 0)
	await tree.process_frame
	await snap(main, "phone", prefix)
	await click_world(main, sneak.position)
	var caught_line := false
	for e in Crew.entries.slice(maxi(0, Crew.entries.size() - 6)):
		if e["text"].contains("caught %s" % sneak.person_name):
			caught_line = true
	check(not sneak.on_phone and caught_line, "clicking someone on their phone catches them")
	Crew.say(GameState.staff[0], "chat", "chat")
	Crew.say(sneak, "sorry", "phone")
	await snap(main, "service", prefix)
	check_fits(main, "while open")
	for m in ["dirt", "traffic", "waits", "wear"]:
		hud.overlay_buttons[m].button_pressed = true
		await tree.process_frame
		check(main.heatmap.mode == m and main.heatmap.visible and hud.overlay_legend.visible, "the %s overlay switches on" % m)
		if m == "waits" or m == "traffic":
			await snap(main, "overlay_" + m, prefix)
	hud.overlay_buttons["wear"].button_pressed = false
	check(main.heatmap.mode == "" and not main.heatmap.visible and not hud.overlay_legend.visible, "and off again")
	# the printed menu: a price chip and what each plate makes
	var mrow = menu_page.rows["burger"]
	var before_price: float = GameState.price("burger")
	mrow.plus_button.pressed.emit()
	check(is_equal_approx(GameState.price("burger"), before_price + 0.5) and mrow.profit_label.text.begins_with("+$"), "the + chip raises the price; profit per plate shows (%s)" % mrow.profit_label.text)
	mrow.minus_button.pressed.emit()
	check(not menu_page.rows["waffles"].on_switch.get_parent().visible and menu_page.rows["waffles"].lock_label.visible, "locked recipes say how to unlock them")
	print("UITEST: %s served=%d left=%d rating=%.2f" % [GameState.clock_text(), GameState.today["served"], GameState.today["left"], GameState.rating])
	Events.auto_choice = 0   # answer anything else that comes up this afternoon
	while GameState.minute < 20.5 * 60 and GameState.phase == GameState.Phase.SERVICE:
		main.simulate(0.1)
	await snap(main, "evening", prefix)
	var safety := 0
	while GameState.phase != GameState.Phase.REPORT and safety < 20000:
		safety += 1
		main.simulate(0.1)
	check(GameState.phase == GameState.Phase.REPORT and hud.report.visible, "the day ends with a report")
	check(GameState.today["paid_at_till"] > 0, "customers paid at the till (%d)" % GameState.today["paid_at_till"])
	await tree.create_timer(0.35).timeout
	await snap(main, "report", prefix)
	# a busy day's report still fits on screen (the notes scroll)
	var busy: Dictionary = main.last_report.duplicate(true)
	for i in 14:
		busy["events"].append(["alert", "#f2c14e", "Something happened, number %d, described in a sentence long enough to wrap onto a second line." % i])
	hud.show_report(busy)
	for i in 6:
		await tree.process_frame
	var view: Vector2 = main.get_viewport().get_visible_rect().size / hud.scale.x
	var cr: Rect2 = hud.report.card.get_global_rect()
	check(cr.position.y >= 0 and cr.end.y <= view.y, "a busy day's report still fits on screen (%s in %s)" % [cr, view])
	await snap(main, "report_busy", prefix)
	hud.side_panel.open("crew")
	await tree.process_frame
	await snap(main, "crew_evening", prefix)
	check_fits(main, "with the Crew tab open")
	hud.side_panel.open("staff")
	hud.report.next_button.pressed.emit()
	await tree.process_frame
	check(GameState.day == 2 and FileAccess.file_exists(main.SAVE_PATH), "next day starts and the game saved")
	check(hud.checklist.collapsed and hud.checklist.size.x < 200.0, "on day 2 the checklist starts as a small pill (%s)" % hud.checklist.size)
	hud.checklist.toggle()
	await tree.process_frame
	check(not hud.checklist.collapsed and hud.checklist.items.visible, "clicking the pill opens the list")
	hud.checklist.toggle()
	check(hud.toasts.history.size() > 3 and hud.top_bar.unread_badge.visible, "messages are kept, with an unread count on the bell (%d)" % hud.toasts.history.size())
	hud.top_bar.inbox_button.pressed.emit()
	await tree.process_frame
	check(hud.inbox.visible and hud.inbox.list.get_child_count() > 3 and not hud.top_bar.unread_badge.visible, "the bell opens the message inbox and marks it read")
	await snap(main, "inbox", prefix)
	await key(main, KEY_ESCAPE)
	check(not hud.inbox.visible and not hud.game_menu.visible, "Esc closes the inbox")
	# let someone go (two clicks), then load from the start screen
	var n_staff := GameState.staff.size()
	var fire_btn: Button = staff_page.cards.values()[0].fire_button
	fire_btn.pressed.emit()
	check(GameState.staff.size() == n_staff, "one click on x only asks")
	fire_btn.pressed.emit()
	await tree.process_frame
	check(GameState.staff.size() == n_staff - 1, "a second click lets them go")
	# the pause menu: Esc first lets go of what's selected, then opens the menu, which saves to a new slot
	main.build.set_tool("select")
	main.build.selection = GameState.staff[0]
	await key(main, KEY_ESCAPE)
	check(main.build.selection == null and not hud.game_menu.visible, "Esc lets go of the selection first")
	await key(main, KEY_ESCAPE)
	check(hud.game_menu.visible and GameState.speed == 0, "Esc opens the pause menu, and the game waits")
	await snap(main, "pause", prefix)
	var saves_before: int = main.list_saves().size()
	var first_slot: String = main.slot
	hud.game_menu.save_button.pressed.emit()
	await tree.process_frame
	await snap(main, "pause_save", prefix)
	hud.game_menu.save_list.new_slot_picked.emit()
	await tree.process_frame
	check(main.list_saves().size() == saves_before + 1 and not hud.game_menu.visible, "Save in a new slot adds a save (%d)" % main.list_saves().size())
	main.slot = first_slot
	# the main menu: Continue loads the diner as it was this morning
	hud.show_start()
	await tree.process_frame
	await snap(main, "start_again", prefix)
	hud.start.load_button.pressed.emit()
	await tree.process_frame
	check(hud.start.pages["load"].visible and hud.start.save_list.get_child_count() >= 2, "Load a diner lists your saves")
	await snap(main, "load", prefix)
	hud.start.load_requested.emit(first_slot)
	await tree.process_frame
	check(GameState.staff.size() == n_staff and not hud.start.visible and GameState.diner_name == "Test Kitchen", "loading brings the diner back as it was this morning")
	print("UITEST: after continue staff=%d furniture=%d day=%d" % [GameState.staff.size(), main.lot.furniture.size(), GameState.day])
	print("UITEST: done")
	Sfx.quit_game()
