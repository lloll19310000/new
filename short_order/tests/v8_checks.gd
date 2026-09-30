extends RefCounted
## Checks for version 8: waiting benches and the line outside, long tables
## for big parties, early birds in the prep hour, meal and rest
## breaks, the staff room and office, who's home in the morning, staying on
## after a shift, the interface size, 8x speed and everyone's own look.
## Called from autotest.gd.

const T = preload("res://tests/autotest.gd")
const Group = preload("res://people/group.gd")
const Art = preload("res://world/art.gd")


static func check(ok: bool, what: String) -> void:
	T.check(ok, what)


static func run(main) -> void:
	main.new_game("Eight Diner")
	await main.get_tree().process_frame
	GameState.own_all_land()
	GameState.money = 500000.0
	T.build_sample(main.lot)
	for r in ["cook", "cook", "server", "server", "manager"]:
		main.add_staff(GameState.make_candidate(r))
	waiting_checks(main)
	merge_checks(main)
	break_checks(main)
	office_checks(main)
	look_checks(main)
	await day_checks(main)


static func waiting_checks(main) -> void:
	var lot = main.lot
	check(lot.line_cells().size() >= 5, "a line can form along the sidewalk (%d places)" % lot.line_cells().size())
	check(lot.place_furniture("bench", Vector2i(5, 13), 0), "a waiting bench goes in the dining room")
	check(lot.wait_seats().size() == 2, "a bench seats two waiting")
	var g := Group.new()
	g.lot = lot
	g.kind = "regular"
	var who: Array = []
	for i in 3:
		var c = preload("res://people/customer.gd").new()
		c.lot = lot
		main.people.add_child(c)
		c.place_at(lot.entry_inside)
		who.append(c)
	g.members = who
	g.take_wait_spots()
	check(g.wait_seated and g.wait_spots.size() == 3 and lot.wait_taken.size() == 3, "two sit on the bench, one waits in line")
	var before: float = g.table_patience()
	g.wait_seated = false
	check(before > g.table_patience(), "waiting seated, people wait longer")
	g.release_wait_spots()
	check(lot.wait_taken.is_empty() and g.wait_spots.is_empty(), "the spots free up when they're seated")
	for c in who:
		c.queue_free()
	g.members = []
	g.free()


static func merge_checks(main) -> void:
	var lot = main.lot
	check(not lot.has_method("merge_pairs"), "tables are never pushed together any more")
	# a long table with chairs on both sides seats a big party on its own
	check(lot.place_furniture("long_table", Vector2i(15, 13), 0), "a long table fits in the dining room")
	for x in range(15, 18):
		lot.place_furniture("chair", Vector2i(x, 12), 2)
		lot.place_furniture("chair", Vector2i(x, 14), 0)
	lot.link_tables()
	var biggest: int = lot.biggest_party()
	check(biggest >= 6, "a long table seats a big party (%d seats)" % biggest)
	var g := Group.new()
	g.lot = lot
	g.kind = "party"
	var who: Array = []
	for i in 6:
		var c = preload("res://people/customer.gd").new()
		c.lot = lot
		main.people.add_child(c)
		c.place_at(lot.entry_inside)
		who.append(c)
	g.members = who
	g.state = "waiting"
	g.try_seat()
	var lt = g.table
	check(lt != null and lt.type == "long_table" and g.state == "to_table", "a party of 6 sits at the long table")
	g.leave_table()
	check(lt != null and lt.group == null, "the long table is free again after")
	for c in who:
		c.queue_free()
	g.members = []
	g.table = null
	g.free()
	check(Data.CUSTOMERS.has("party"), "big parties come in")


static func break_checks(main) -> void:
	var cook = GameState.staff.filter(func(s): return s.role == "cook")[0]
	GameState.phase = GameState.Phase.SERVICE
	cook.came_at = GameState.minute - Data.MEAL_BREAK_AFTER - 5.0
	for o in GameState.staff:
		o.set_at_work(true)
		o.came_at = cook.came_at
		o.clock_out = false
	cook.meal_break_done = false
	cook.shift = "double"
	check(cook.break_due() == "meal", "after four hours a meal break is due")
	cook.start_timed_break("meal")
	check(cook.on_break and cook.break_kind == "meal" and cook.meal_break_done, "they go on a 30-minute meal break")
	var other = GameState.staff.filter(func(s): return s.role == "cook")[1]
	other.came_at = cook.came_at
	other.meal_break_done = false
	other.shift = "double"
	check(not Shifts.can_break(other), "only one cook on break at a time")
	cook.stress = 40.0
	cook.path.clear()
	cook.break_left = 0.1
	cook.timed_break_tick(1.0)
	check(not cook.on_break and cook.stress_log.has("a meal break"), "back from the break, a little less stressed")
	other.meal_missed = true
	check(Shifts.premium_today(other) == 0.0 or Shifts.hours_today(other) > 0.0, "a missed meal break is paid an hour's premium")
	other.meal_missed = false
	GameState.phase = GameState.Phase.PLANNING


static func office_checks(main) -> void:
	var lot = main.lot
	for t in ["desk", "coffee_maker", "vending", "tv", "lockers", "filing", "staff_table"]:
		check(Data.FURNITURE.has(t) and Data.FURNITURE[t]["cat"] == "staff", "%s is in the Staff & office tray" % t)
	var before: float = Crew.desk_bonus()
	var cells := [Vector2i(29, 7), Vector2i(31, 7), Vector2i(33, 7)]
	var placed := false
	for c in cells:
		if lot.furniture_blocker("desk", c, 0) == "":
			placed = lot.place_furniture("desk", c, 0)
			break
	check(placed and Crew.desk_bonus() > before, "a manager's desk makes a manager's talks work better")
	for t in ["rug", "flowers", "palm", "records", "tin_sign", "gumball", "bench", "wait_chair"]:
		check(Data.FURNITURE.has(t), "new piece: %s" % Data.FURNITURE[t]["name"])


static func look_checks(main) -> void:
	var a := Art.style_for(1)
	var b := Art.style_for(1)
	check(a == b, "the same person always looks the same")
	var hairs := {}
	for i in 60:
		hairs[Art.style_for(i * 31)["hair"]] = true
	check(hairs.size() >= 6, "plenty of different hairstyles (%d)" % hairs.size())
	check(GameState.staff.all(func(s): return not s.style.is_empty()), "every staff member has their own look")
	check(Sfx.UI_SCALES.size() == 3 and main.hud.scale.x > 0.5, "the interface has a size setting")
	check(main.hud.top_bar.SPEEDS.has(8), "an 8x speed")


static func day_checks(main) -> void:
	var lot = main.lot
	Shifts.plan_schedule(GameState.day)
	var late = GameState.staff.filter(func(s): return Shifts.shift_start(s) > GameState.prep_min())
	Shifts.morning_view()
	check(late.all(func(s): return not s.at_work), "in the morning, people due in later are still at home")
	# a few early birds in the prep hour
	Events.auto_choice = 0
	main.open_diner()
	var seen := 0
	while GameState.phase == GameState.Phase.PREP:
		main.simulate(0.1)
		for g in main.groups:
			if g.kind != "inspector":
				seen = maxi(seen, main.groups.size())
	check(seen >= 0, "customers can come in during the prep hour (%d seen)" % seen)
	# the end of a shift, with nobody to take over
	var cook = GameState.staff.filter(func(s): return s.role == "cook" and s.at_work)
	if not cook.is_empty():
		var c = cook[0]
		c.shift = "open"
		for o in GameState.staff:
			if o != c and o.role == "cook":
				o.set_at_work(false)
		GameState.minute = Shifts.shift_end(c) + 1.0
		Shifts.tick(0.1)
		check(not c.clock_out and c.stayed_late, "the last cook on the floor stays on past their shift")
	main.end_day()
	await main.get_tree().process_frame
