extends RefCounted
## Checks for version 7: unlockable recipes and the hometown dish, coffee
## refills, stress with reasons, crew moments (birthdays, milestones), the
## employee of the month, regulars' stories and birthdays, the Goals board,
## the day report's snapshots and saving all of it. Called from autotest.gd.

const T = preload("res://tests/autotest.gd")
const Group = preload("res://people/group.gd")


static func check(ok: bool, what: String) -> void:
	T.check(ok, what)


static func run(main) -> void:
	main.new_game("Check Diner")
	await main.get_tree().process_frame
	GameState.own_all_land()
	GameState.money = 500000.0
	T.build_sample(main.lot)
	recipe_checks(main)
	refill_checks(main)
	stress_checks(main)
	moment_checks(main)
	regular_checks(main)
	goal_checks(main)
	report_checks(main)
	save_checks(main)


static func recipe_checks(main) -> void:
	check(not GameState.dish_known("waffles") and not GameState.dish_on("waffles") and GameState.dish_on("burger"), "locked recipes start off the menu")
	check(not Stock.sold_out.has("waffles"), "a locked dish is never reported sold out")
	GameState.rep_level = 1
	GameState.unlock_by_rep()
	check(GameState.dish_on("soup") and not GameState.dish_known("club"), "reaching Local spot unlocks the soup of the day, not the club yet")
	GameState.rep_level = 0
	var cook = main.add_staff(GameState.make_candidate("cook"))
	cook.role = "cook"
	cook.origin["dish"] = "pierogi"
	cook.origin["city"] = "Kraków"
	cook.worked_today = true
	check(Moments.teach_dish(cook) and GameState.dish_on("hometown"), "a cook can teach the kitchen their hometown dish")
	check(Data.DISHES["hometown"]["name"] == "%s's pierogi" % cook.person_name.split(" ")[0], "and it's named after them (%s)" % Data.DISHES["hometown"]["name"])
	check(not Moments.teach_dish(cook), "only one hometown dish")


static func refill_checks(main) -> void:
	var g := Group.new()
	g.lot = main.lot
	g.state = "eating"
	g.table = main.lot.tables()[0]
	g.received = ["coffee", "pie"]
	g.eat_left = 15.0
	g.refill_in = 0.1
	g.refill_tick(1.0)
	check(g.wants_refill and JobBoard.has_open("refill", "group", g), "a coffee drinker asks for a refill a few minutes in")
	var cafe = main.add_staff(GameState.make_candidate("server"))
	check(cafe.can_take(JobBoard.jobs.filter(func(j): return j.kind == "refill")[0]) or main.lot.of_type("drinks").is_empty(), "staff can take the refill job")
	g.got_refill(cafe)
	check(g.refills == 1 and not g.wants_refill and is_equal_approx(g.review_bonus, Data.REFILL_REVIEW), "a refill lifts the review")
	g.wants_refill = true
	g.miss_refill()
	check(g.extra_hits.has("no coffee refill"), "leaving without a wanted refill is a small grumble")
	JobBoard.prune(main.lot)
	g.table = null
	g.free()


static func stress_checks(main) -> void:
	var s = GameState.staff[0]
	s.stress = 30.0
	s.stress_log = {}
	s.add_stress(8.0, "closed then opened")
	s.add_stress(-6.0, "the manager checked in")
	s.add_stress(2.0, "closed then opened")
	var r: Array = s.stress_reasons()
	check(r.size() == 2 and r[0][0] == "closed then opened" and is_equal_approx(r[0][1], 10.0), "stress keeps its reasons (%s)" % [r])
	check(s.stress_reasons_text().contains("+10 closed then opened") and s.stress_reasons_text().contains("-6 the manager checked in"), "and says them: %s" % s.stress_reasons_text())
	Crew.update_stress(s, 2.0)
	check(s.stress_log.has("being swamped"), "a rush shows up as a reason")


static func moment_checks(main) -> void:
	var s = GameState.staff[0]
	s.birthday = Moments.day_of_year(GameState.day)
	var before: float = s.stress
	Moments.morning()
	check(Moments.cake_for == s.person_name and s.stress < before and s.stress_log.has("birthday cake"), "a birthday brings cake to the staff room")
	s.shifts_worked = 9
	s.worked_today = true
	Moments.nightly()
	check(s.shifts_worked == 10 and Moments.today_lines.any(func(l): return l[2].contains("10th")), "the 10th shift is a milestone")
	check(Moments.ordinal(1) == "1st" and Moments.ordinal(12) == "12th" and Moments.ordinal(23) == "23rd", "ordinals")
	# employee of the month
	for o in GameState.staff:
		o.jobs_month = 5
	s.jobs_month = 40
	var wage: float = s.wage
	Moments.pick_eotm()
	check(Moments.eotm.get("name", "") == s.person_name and is_equal_approx(s.wage, wage + Data.EOTM_RAISE) and s.eotm_count == 1, "employee of the month: the photo, a raise")
	check(GameState.staff.all(func(o): return o.jobs_month == 0), "and the count starts again")
	for x in range(4, 27):
		if main.lot.furniture_blocker("eotm", Vector2i(x, 3), 0) == "":
			main.lot.place_furniture("eotm", Vector2i(x, 3), 0)
			break
	check(main.lot.has_type("eotm"), "the employee of the month frame hangs on a wall")


static func regular_checks(main) -> void:
	var r: Dictionary = Front.by_name("Mrs. Albright")
	check(r.has("seat") and r["seat"] == "booth" and r.has("birthday"), "regulars have a favourite seat and a birthday")
	r["loyalty"] = 70.0
	r["visits"] = 3
	var s = GameState.staff[0]
	Front.after_visit(r, 5.0, [s])
	check(r["beats"] == 1 and str(r["beat_text"]).contains("1958"), "a regular who warms up tells you their story (%s)" % r["beat_text"])
	r["loyalty"] = 80.0
	r["visits"] = 6
	Front.after_visit(r, 5.0, [s])
	check(r["beats"] == 2 and r["party"] == 3, "Mrs. Albright brings the grandkids")
	var g := Group.new()
	g.lot = main.lot
	g.regular = r
	var booth_table = null
	for t in main.lot.tables():
		booth_table = t
	check(booth_table == null or g.likes_seat(booth_table) == (booth_table.chairs.any(func(c): return c.type == "booth")), "a regular prefers their own kind of seat")
	g.free()


static func goal_checks(main) -> void:
	check(Goals.progress("breakfast")[1] == 60, "goals have targets")
	GameState.totals["breakfast_served"] = 60
	var got: Array = Goals.check(true)
	check(Goals.is_done("breakfast") and GameState.dish_on("waffles"), "a goal's reward unlocks waffles")
	check(not got.is_empty() and Goals.check(true).is_empty(), "goals are only reached once")
	check(not GameState.item_unlocked("aquarium") and not main.lot.place_furniture("aquarium", Vector2i(6, 13), 0), "reward decor is locked until its goal")
	GameState.totals["last_quit_day"] = GameState.day - 31
	Goals.check(true)
	check(GameState.item_unlocked("aquarium"), "30 days with nobody quitting unlocks the fish tank")


static func report_checks(main) -> void:
	GameState.note_moment(4.9, "Big Jim", "burger")
	GameState.note_moment(1.5, "A family", "slow food")
	GameState.note_moment(0.0, "A trucker", "no free table", true)
	check(GameState.today["best"]["who"] == "Big Jim" and GameState.today["worst"]["left"], "the day keeps its best and worst moments")
	var tip := preload("res://ui/report.gd").tomorrow_tip({"complaint": "slow food"})
	check(tip.contains("cook"), "one clear tip for tomorrow (%s)" % tip)


static func save_checks(main) -> void:
	main.save_game()
	var name_before: String = Data.DISHES["hometown"]["name"]
	var eotm_before: String = Moments.eotm.get("name", "")
	var beats: int = Front.by_name("Mrs. Albright")["beats"]
	check(main.load_game(main.slot), "a v7 diner loads")
	check(GameState.dish_on("hometown") and Data.DISHES["hometown"]["name"] == name_before and GameState.dish_on("waffles"), "recipes and the hometown dish are saved")
	check(Moments.eotm.get("name", "") == eotm_before and Goals.is_done("breakfast") and Front.by_name("Mrs. Albright")["beats"] == beats, "the employee of the month, goals and regulars' stories are saved")
	check(GameState.staff.any(func(s): return s.shifts_worked == 10), "shifts worked are saved")
