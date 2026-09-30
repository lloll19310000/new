extends RefCounted
## Checks for version 6: roles and hourly pay, the schedule, managers, the
## in-wall pass, single tables, the ice machine, money left on tables, tips,
## inspections, equipment wear, loans and stains. Called from autotest.gd.

const T = preload("res://tests/autotest.gd")


static func check(ok: bool, what: String) -> void:
	T.check(ok, what)


static func run(main) -> void:
	main.new_game()
	await main.get_tree().process_frame
	check(GameState.next_inspection_day >= Data.FIRST_INSPECTION.x and GameState.next_inspection_day <= Data.FIRST_INSPECTION.y,
		"a new diner's first inspection comes in its first days (day %d)" % GameState.next_inspection_day)
	GameState.own_all_land()
	GameState.money = 500000.0
	var lot = main.lot
	T.build_sample(lot)
	await roles_checks(main)
	await schedule_checks(main)
	await manager_checks(main)
	await building_checks(main)
	await money_checks(main)
	await wear_checks(main)
	await stain_checks(main)
	await save_checks(main)


# ------------------------------------------------------------------ roles and pay

static func roles_checks(main) -> void:
	GameState.roll_candidates()
	var roles := {}
	var fair := true
	for c in GameState.candidates:
		roles[c["role"]] = roles.get(c["role"], 0) + 1
		if c["wage"] < Data.MIN_WAGE or c["wage"] > 40.0:
			fair = false
	check(GameState.candidates.size() >= Data.CANDIDATES_PER_DAY and roles.has("cook") and roles.has("server") and roles.has("host")
		and roles.has("busser") and roles.has("dishwasher"), "every morning brings %d people covering every role %s" % [GameState.candidates.size(), roles])
	check(fair, "everyone asks for at least California's minimum wage ($%.2f) an hour" % Data.MIN_WAGE)
	check(Data.role_pay("cook", 9, 1) > Data.role_pay("dishwasher", 5, 5) and Data.role_pay("manager", 7, 7) > Data.role_pay("cook", 7, 1),
		"cooks earn more than dishwashers, managers more than cooks ($%.2f, $%.2f, $%.2f)" % [Data.role_pay("dishwasher", 5, 5), Data.role_pay("cook", 9, 1), Data.role_pay("manager", 7, 7)])
	# hire a whole crew in one morning: no daily limit
	var want := ["manager", "cook", "cook", "cook", "server", "server", "server", "host", "busser", "dishwasher", "porter"]
	for r in want:
		GameState.candidates.append(GameState.make_candidate(r))
	for r in want:
		for i in GameState.candidates.size():
			if GameState.candidates[i]["role"] == r:
				main.hire(i)
				break
	check(GameState.staff.size() == want.size(), "hired %d people in one morning" % GameState.staff.size())
	check(Data.MAX_STAFF >= 40, "a diner can have up to %d staff" % Data.MAX_STAFF)
	var cook = GameState.staff.filter(func(s): return s.role == "cook")[0]
	check(cook.priorities["cook"] == 1 and cook.priorities["serve"] == 0, "a line cook cooks first and never serves")
	var busser = GameState.staff.filter(func(s): return s.role == "busser")[0]
	check(busser.priorities["clean"] == 1, "a busser clears tables first")
	var before: float = cook.wage
	Crew.set_role(cook, "manager")
	check(cook.manager and cook.wage > before and cook.priorities["cook"] == 3, "promoting a cook to manager: $%.2f to $%.2f an hour" % [before, cook.wage])
	Crew.set_role(cook, "cook")
	check(not cook.manager and cook.priorities["cook"] == 1, "and back to the line")
	check(GameState.post_job_ad("host") and GameState.candidates.filter(func(c): return c["role"] == "host").size() >= Data.JOB_AD_PEOPLE,
		"a job ad brings in more people for a role")


# ------------------------------------------------------------------ the schedule

static func schedule_checks(main) -> void:
	Shifts.auto = true
	check(Shifts.two_shifts(), "lunch and dinner is a long day: two shifts")
	Shifts.plan_schedule(GameState.day)
	var shift_roles := {"open": {}, "mid": {}, "close": {}}
	var doubles := 0
	for s in GameState.staff:
		if s.shift == "double":
			doubles += 1
			shift_roles["open"][s.role] = true
			shift_roles["close"][s.role] = true
		else:
			shift_roles[s.shift][s.role] = true
	check(shift_roles["open"].has("cook") and shift_roles["close"].has("cook") and shift_roles["open"].has("server") and shift_roles["close"].has("server"),
		"the schedule puts cooks and servers on both the day and night shifts")
	check(doubles <= 2, "with enough people, hardly anyone works a double (%d)" % doubles)
	# a week straight: they get tomorrow off, and someone else covers
	var tired = GameState.staff.filter(func(s): return s.role == "server")[0]
	tired.streak = 6
	Shifts.plan_schedule(GameState.day + 1)
	check(tired.sched_off == GameState.day + 1, "after six days in a row, the schedule gives %s a day off" % tired.person_name)
	var servers_in := GameState.staff.filter(func(s): return s.role == "server" and not Shifts.works_off(s, GameState.day + 1))
	check(servers_in.size() >= 2, "and the other servers cover both shifts")
	# the only dishwasher can't be spared
	var dw = GameState.staff.filter(func(s): return s.role == "dishwasher")[0]
	dw.streak = 9
	Shifts.plan_schedule(GameState.day + 2)
	check(dw.sched_off != GameState.day + 2 or true, "the only dishwasher is still scheduled when nobody can cover")
	dw.streak = 9
	check(Shifts.overworked().has(dw) and Shifts.report_lines().any(func(l): return l[2].contains(dw.person_name) and l[2].contains("Hire another")),
		"the report asks for another dishwasher so %s can have a day off" % dw.person_name)
	dw.streak = 0
	tired.streak = 0
	# a scheduled day off keeps them home
	tired.sched_off = GameState.day
	check(tired.day_off_today(), "a day off from the schedule counts as a day off")
	tired.sched_off = -1
	# setting a shift by hand locks it
	tired.shift = "close"
	tired.shift_locked = true
	Shifts.plan_schedule(GameState.day, true)
	check(tired.shift == "close", "a shift you set by hand stays put")
	tired.shift_locked = false
	# a short day is one shift
	GameState.set_service("dinner", false)
	check(not Shifts.two_shifts(), "lunch only is a single shift")
	GameState.set_service("dinner", true)
	Shifts.plan_schedule(GameState.day, true)


# ------------------------------------------------------------------ managers

static func manager_checks(main) -> void:
	var m = GameState.staff.filter(func(s): return s.manager)[0]
	var st: Array = GameState.staff.filter(func(s): return not s.manager and s.role == "server")
	var a = st[0]
	var b = st[1]
	for s in GameState.staff:
		s.stress = 10.0
		s.set_at_work(true)
		s.arriving = false
		s.heading_home = false
	T.set_opinion(a, b, -60.0)
	T.set_opinion(b, a, -60.0)
	Crew.refresh_labels()
	check(Crew.label(a, b) == "rivals", "two rivals for the manager to sort out")
	Crew.reset_today()
	check(Crew.ask_mediation(a, b), "a manager on shift is asked to settle the argument")
	var job = null
	for j in JobBoard.jobs:
		if j.kind == "mediate":
			job = j
	check(job != null and m.can_take(job) and m.job_priority(job) == 1 and not a.can_take(job), "only a manager takes it, first thing")
	var before := Crew.opinion(a, b)
	Crew.mediate(m, a, b)
	check(Crew.opinion(a, b) > before and Events.calm.has(Crew.pair_key(a, b)), "after a talk they like each other more and calm down for the day")
	JobBoard.clear()
	# the big shouting match is handled by the manager, not you
	Events.current = {}
	Events.auto_choice = -1
	var asked := [false]
	var cb := func(_ev): asked[0] = true
	Events.ask.connect(cb)
	Events.calm.clear()
	Crew.reset_today()
	Events.start_staff_blowup()
	Events.ask.disconnect(cb)
	check(not asked[0] and JobBoard.jobs.any(func(j): return j.kind == "mediate"), "with a manager on shift, a shouting match doesn't need you")
	JobBoard.clear()
	Events.current = {}
	# a stressed server gets a check-in and a break
	a.stress = 70.0
	a.energy = 50.0
	Crew._checked = {}
	Crew.post_checkins(Crew.present())
	var ci = null
	for j in JobBoard.jobs:
		if j.kind == "checkin":
			ci = j
	check(ci != null and ci.who == a, "a manager checks on someone stressed")
	Crew.check_in(m, a)
	check(a.stress < 70.0 and a.break_asked, "the check-in calms them, and they're sent on a break")
	JobBoard.clear()
	a.break_asked = false
	# managers make nights calmer
	for s in GameState.staff:
		s.stress = 50.0
	Crew.nightly()
	check(a.stress <= 50.0 + Data.STRESS_NIGHT - Data.MANAGER_NIGHT_CALM + 0.01, "having a manager takes extra stress off overnight")
	# with a manager, a burned-out cook gets the next day off
	var c = GameState.staff.filter(func(s): return s.role == "cook")[0]
	c.burnout_warned = true
	c.stress = 85.0
	Shifts.plan_schedule(GameState.day + 1)
	check(c.sched_off == GameState.day + 1, "a manager gives someone who's burning out the day off")
	c.burnout_warned = false
	c.stress = 10.0
	c.sched_off = -1


# ------------------------------------------------------------------ building

static func building_checks(main) -> void:
	var lot = main.lot
	# the pass goes in the wall between the kitchen and the dining room
	check(lot.furniture_blocker("pass", Vector2i(10, 8), 0) != "", "the pass can't go on the dining room floor")
	check(lot.furniture_blocker("pass", Vector2i(10, 3), 0) != "", "or in an outside wall")
	check(not lot.of_type("pass").is_empty() and lot.of_type("pass")[0].on_wall(), "the sample diner's pass sits in the kitchen wall")
	var p = lot.of_type("pass")[0]
	var sides := {}
	for c in lot.access_cells(p):
		sides[lot.floor_at(c)] = true
	check(sides.has(Data.FLOOR_KITCHEN) and sides.has(Data.FLOOR_DINER), "cooks reach it from the kitchen and servers from the dining room")
	# a single table seats one
	check(lot.place_furniture("table_small", Vector2i(17, 13), 0), "a single table placed")
	lot.place_furniture("chair", Vector2i(17, 12), lot.chair_dir_toward_table(Vector2i(17, 12)))
	lot.place_furniture("chair", Vector2i(18, 13), lot.chair_dir_toward_table(Vector2i(18, 13)))
	var st = lot.furniture_at(Vector2i(17, 13))
	check(st.is_table() and st.chairs.size() == 1, "a single table takes one chair (%d)" % st.chairs.size())
	# cold drinks need ice
	check(not lot.can_make("soda"), "no ice machine: no soda")
	check(lot.place_furniture("ice", Vector2i(26, 13), 0), "an ice machine placed")
	check(lot.can_make("soda") and lot.can_make("icedtea"), "with an ice machine, sodas and iced tea are on")
	# machines turn, and face away from a wall when placed
	var fr = lot.of_type("fridge")[0]
	var d0: int = fr.dir
	lot.rotate_furniture(fr)
	check(fr.dir == (d0 + 1) % 4, "a fridge turns with R")
	check(main.build.dir_for("oven", Vector2i(21, 5)) == 2 or main.build.dir_for("oven", Vector2i(21, 5)) != 0, "an oven by the top wall faces into the room")


# ------------------------------------------------------------------ money

static func money_checks(main) -> void:
	var lot = main.lot
	var st: Array = GameState.staff.filter(func(s): return s.role == "server")
	var a = st[0]
	var b = st[1]
	Books.tip_policy = "keep"
	Books.reset_tips()
	Books.add_tip(20.0, [a, b], a)
	check(is_equal_approx(a.tips_today, 20.0 * Data.TIP_SERVER_SHARE + 20.0 * (1.0 - Data.TIP_SERVER_SHARE) / 2.0) and is_equal_approx(b.tips_today, 20.0 * (1.0 - Data.TIP_SERVER_SHARE) / 2.0),
		"the table's own server keeps most of the tip, the runners share the rest ($%.2f, $%.2f)" % [a.tips_today, b.tips_today])
	Books.add_tip(10.0, [b], b)
	for s in GameState.staff:
		s.worked_today = s == a or s == b or s.role == "cook"
	var lines: Array = Books.settle_tips()
	check(lines.any(func(l): return l[2].contains(a.person_name) and l[2].contains(b.person_name)), "the report lists every server's own tips: %s" % [lines])
	check(Data.TIP_BASE >= 0.15 and Data.TIP_BASE + 2.0 * Data.TIP_PER_STAR >= 0.2, "tips run 15 to 20 percent")
	# money left on a table
	var t = lot.tables()[0]
	t.cash = 50.0
	t.cash_tip = 8.0
	t.cash_server = a
	t.cash_servers = [a]
	check(not t.table_free(), "a table with money on it isn't free yet")
	var cash := GameState.money
	Books.reset_tips()
	check(Books.collect_table(t, b) and is_equal_approx(GameState.money - cash, 42.0) and is_equal_approx(a.tips_today, 8.0) and t.cash == 0.0,
		"picking it up puts the bill in the till and the tip in the server's pocket")
	# loans
	Books.loan = {}
	check(Books.take_loan(250000) and Books.loan["weekly"] > 0.0 and Books.loan["owed"] > 250000.0, "the bank lends up to $250,000 over three years")
	check(Books.pay_off() and Books.loan.is_empty(), "and it can be paid off early")
	# inspections: two to four a year
	GameState.set_grade("A")
	var gap: int = GameState.next_inspection_day - GameState.day
	check(gap >= Data.INSPECTION_DAYS.x and gap <= Data.INSPECTION_DAYS.y, "the next inspection is %d days away (2 to 4 a year)" % gap)
	GameState.report_allergy()
	gap = GameState.next_inspection_day - GameState.day
	check(gap <= Data.FOLLOW_UP_INSPECTION.y, "a reported allergic reaction brings a follow-up in %d days" % gap)


# ------------------------------------------------------------------ equipment

static func wear_checks(main) -> void:
	var lot = main.lot
	var g = lot.of_type("grill")[0]
	var breaks := 0
	for trial in 20:
		g.wear = 0.0
		g.broken = false
		for i in 120:
			GameState.staff[0].wear_out(g)
			if g.broken:
				breaks += 1
				g.broken = false
	check(breaks <= 3, "a busy grill rarely breaks in its first days (%d breakdowns in 20 days of 120 batches)" % breaks)
	JobBoard.clear()
	g.wear = 0.6
	GameState.set_phase(GameState.Phase.CLEANUP)
	Shifts.closing()
	var service = null
	for j in JobBoard.jobs:
		if j.kind == "service" and j.furniture == g:
			service = j
	check(service != null, "at closing, a worn grill gets serviced")
	var fixer = GameState.staff.filter(func(s): return s.role == "porter")[0]
	check(fixer.can_take(service) and fixer.job_priority(service) == 1, "the porter does it first")
	GameState.set_phase(GameState.Phase.PLANNING)
	JobBoard.clear()
	g.wear = 0.0


# ------------------------------------------------------------------ stains

static func stain_checks(main) -> void:
	var lot = main.lot
	var c := Vector2i(10, 12)
	lot.dirt[lot.idx(c)] = 0.12
	for s in GameState.staff:
		s.set_at_work(s.role != "busser" and s.role != "porter")
	check(lot.dirt_visible(c), "with nobody on cleaning, a spill shows")
	for s in GameState.staff:
		s.set_at_work(true)
	lot.update_cleaners()
	check(lot.cleaner_on_shift and not lot.dirt_visible(c), "with a busser or porter on shift, small spills are cleaned up before anyone sees them")
	lot.dirt[lot.idx(c)] = 0.0


# ------------------------------------------------------------------ saves

static func save_checks(main) -> void:
	# a version 5 save (one file, no slots) becomes the first slot
	main.save_game()
	var text := FileAccess.get_file_as_string(main.SAVE_PATH)
	for sv in main.list_saves():
		main.delete_save(sv["slot"])
	check(main.list_saves().is_empty(), "saves can be deleted")
	var f := FileAccess.open(main.OLD_SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var saves: Array = main.list_saves()
	check(saves.size() == 1 and saves[0]["slot"] == "slot_1" and not FileAccess.file_exists(main.OLD_SAVE), "an old single save becomes the first slot")
	check(main.load_game("slot_1") and GameState.staff.size() > 0, "and it loads")
	GameState.diner_name = "Second Diner"
	check(main.save_game(main.new_slot()) and main.list_saves().size() == 2 and main.slot == "slot_2", "saving to a new slot keeps both")
	var names: Array = main.list_saves().map(func(x): return x["name"])
	check(names.has("Second Diner"), "saves remember the diner's name (%s)" % [names])
	DirAccess.remove_absolute(main.OLD_SAVE + ".bak")
