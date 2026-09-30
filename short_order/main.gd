extends Node2D
## Runs the game: builds the world and UI, moves time forward, spawns customers,
## ends each day with the numbers, and saves at the start of every morning.

const Lot = preload("res://world/lot.gd")
const BuildTool = preload("res://world/build_tool.gd")
const Cam = preload("res://world/camera.gd")
const Fx = preload("res://world/fx.gd")
const Overlay = preload("res://world/overlay.gd")
const Staff = preload("res://people/staff.gd")
const Group = preload("res://people/group.gd")
const HudScene = preload("res://ui/hud.tscn")
const Autotest = preload("res://tests/autotest.gd")
const ArtPreview = preload("res://tests/art_preview.gd")
var save_dir := "user://saves"                   # the tests use their own folder
var OLD_SAVE := "user://short_order_save.json"   # version 5 and earlier kept one save here
const SAVE_VERSION := 6

## Each diner lives in its own save slot ("slot_1", "slot_2"...) and saves
## itself there every morning. You can also save to another slot from the menu.
var slot := ""
var SAVE_PATH: String:
	get:
		return save_path(slot if slot != "" else "slot_1")

var lot
var people: Node2D
var build
var cam
var hud
var overlay
var groups: Array = []
var spawn_acc := 0.0
var next_spawn := 3.0
var last_report: Dictionary = {}
var prune_timer := 0.0
var slow_timer := 0.0
var critic_at := -1.0              # game minute a food critic arrives today, or -1
var inspect_at := -1.0             # game minute the health inspector arrives today, or -1
var rush_name := ""
var heatmap


func _ready() -> void:
	randomize()
	lot = Lot.new()
	lot.name = "Lot"
	add_child(lot)
	people = Node2D.new()
	people.name = "People"
	lot.add_child(people)
	build = BuildTool.new()
	build.name = "BuildTool"
	build.lot = lot
	lot.add_child(build)
	var street := preload("res://world/street.gd").new()
	street.name = "Street"
	lot.add_child(street)
	heatmap = preload("res://world/heatmap.gd").new()
	heatmap.name = "Heatmap"
	heatmap.lot = lot
	heatmap.visible = false
	lot.add_child(heatmap)
	var fx := Fx.new()
	fx.name = "Fx"
	lot.add_child(fx)
	lot.fx = fx
	overlay = Overlay.new()
	overlay.name = "Overlay"
	overlay.main = self
	lot.add_child(overlay)
	cam = Cam.new()
	cam.name = "Camera"
	add_child(cam)
	hud = HudScene.instantiate()
	hud.main = self
	add_child(hud)
	build.selected.connect(hud.show_selection)
	build.tool_changed.connect(hud.on_tool_changed)
	GameState.toast.connect(hud.show_toast)
	Crew.main = self
	Events.main = self
	Stock.main = self
	Books.main = self
	Front.main = self
	Health.main = self
	Shifts.main = self
	Crew.big_moment.connect(func(): Sfx.play("fanfare", -10.0))
	lot.layout_changed.connect(hud.refresh_checklist)
	lot.layout_changed.connect(func(): GameState.seats = lot.seats())
	GameState.land_changed.connect(lot.queue_redraw)
	# the storefront shows OPEN or CLOSED, whether you're hiring, and lights up at night
	GameState.staff_changed.connect(lot.queue_redraw)
	GameState.phase_changed.connect(func(_p): lot.queue_redraw())
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args or "--shot" in args or "--uitest" in args or "--balance" in args or "--art" in args:
		# the tests never touch your real saves
		save_dir = "user://test_saves"
		OLD_SAVE = "user://test_old_save.json"
	if "--autotest" in args or "--shot" in args:
		_run_autotest.call_deferred(args)
		return
	if "--art" in args:
		(func(): await ArtPreview.run(self, args)).call_deferred()
		return
	if "--balance" in args:
		(func(): await Autotest.run_balance(self, args)).call_deferred()
		return
	hud.show_start()
	if "--uitest" in args:
		_run_uitest.call_deferred(args)
		return


func _run_uitest(args: PackedStringArray) -> void:
	await Autotest.run_ui(self, args)


func _run_autotest(args: PackedStringArray) -> void:
	await Autotest.run(self, args)


func _process(delta: float) -> void:
	# at high speed, break the frame into steps of at most ~1/15 of a game minute
	var steps := clampi(int(ceil(delta * GameState.sim_speed() / 0.07)), 1, 8)
	for i in steps:
		simulate(delta / steps)
	slow_timer -= delta
	if slow_timer <= 0.0:
		slow_timer = 0.25
		update_loops()


## The grill sizzles while anything is cooking; the jukebox plays while you're open.
## Returns [sizzling, music] so the tests can check it.
func update_loops() -> Array:
	var cooking := false
	for f in lot.furniture:
		if f.cooking != "":
			cooking = true
			break
	var playing := GameState.sim_speed() > 0.0
	var sizzle := cooking and playing
	var music: bool = GameState.is_open() and playing and lot.has_type("jukebox")
	if GameState.is_active() and GameState.minute >= 18.0 * 60.0 and int(GameState.minute) % 10 == 0:
		lot.queue_redraw()   # the sign warms up as it gets dark
	Sfx.set_loops(sizzle, music)
	return [sizzle, music]


func _exit_tree() -> void:
	# furniture, groups and jobs point at each other; untangle them so nothing leaks
	JobBoard.clear()
	for f in lot.furniture:
		f.chairs = []
		f.table = null
		f.group = null
		f.occupant = null
		f.user = null
		f.items = []
		f.resters = {}
		f.broke_by = null


func simulate(real_dt: float) -> void:
	var sp := GameState.sim_speed()
	if sp <= 0.0:
		return
	var dt := real_dt * sp
	var minutes := dt / Data.MINUTE_SEC
	GameState.sim_time += dt
	var phase := GameState.phase
	if GameState.is_active():
		GameState.minute += minutes
		Stock.tick(minutes)
		Health.tick(minutes)
		Shifts.tick(minutes)
		if phase == GameState.Phase.PREP:
			# a few early birds wander in while the crew preps
			if GameState.minute >= GameState.open_min() - 45.0:
				spawn_tick(minutes * Data.PREP_WALKINS)
				kitchen_tick(minutes)
			if GameState.minute >= GameState.open_min():
				open_doors()
		elif phase == GameState.Phase.SERVICE:
			spawn_tick(minutes)
			rush_tick()
			kitchen_tick(minutes)
			Biz.tick(minutes)
			Front.tick(minutes)
			if GameState.minute >= GameState.close_min():
				GameState.set_phase(GameState.Phase.CLEANUP)
				GameState.toast.emit("%s. The doors are closed. Staff will tidy up before going home." % GameState.clock_text(), "")
				Sfx.play("day_end", -4.0)
				lot.post_closing_sweeps()
				Shifts.closing()
		elif GameState.minute >= maxf(Data.END_MIN, GameState.close_min() + 120.0) or (groups.is_empty() and GameState.minute >= GameState.close_min() + 20 and not cleaning_left() and not Shifts.closing_left()):
			end_day()
			return
	for g in groups.duplicate():
		if is_instance_valid(g):
			g.tick(minutes)
	groups = groups.filter(func(g): return is_instance_valid(g) and g.state != "gone")
	prune_timer -= dt
	if prune_timer <= 0.0:
		prune_timer = 1.0
		JobBoard.prune(lot)
		lot.update_cleaners()
	for s in GameState.staff:
		if s.at_work and not s.away:
			s.tick(dt, minutes)
	Crew.tick(minutes)
	Events.tick(minutes)
	for m in Health.mice.duplicate():
		if is_instance_valid(m):
			m.tick(dt, minutes)
	for g in groups:
		for m in g.members:
			if is_instance_valid(m):
				m.move_tick(dt)


## After closing, the day ends once the floors are swept and the dishes done
## (or at midnight). Only jobs someone still here can actually do count.
func cleaning_left() -> bool:
	var here: Array = Crew.present()
	for j in JobBoard.jobs:
		if j.done or not j.type in ["clean", "wash"]:
			continue
		if j.claimed_by != null:
			return true
		for s in here:
			if s.job_priority(j) > 0 and s.can_take(j):
				return true
	return false


## Once a game minute while open: notice dishes that just sold out.
var _kitchen_acc := 0.0
var _plates_warned := false
func kitchen_tick(minutes: float) -> void:
	_kitchen_acc += minutes
	if _kitchen_acc < 1.0:
		return
	_kitchen_acc = 0.0
	Stock.check_sold_out()
	# out of clean plates while orders wait: the kitchen stalls until someone washes up
	if GameState.plates_clean <= 0 and JobBoard.jobs.any(func(j): return j.kind == "cook" and j.claimed_by == null and not j.done):
		GameState.today["no_plates"] += 1.0
		if not _plates_warned:
			_plates_warned = true
			GameState.toast.emit("Out of clean plates! Orders are waiting on the sink: put more people on Wash, or buy plates in Supplies.", "bad")
			Crew.log_line("The kitchen ran out of clean plates.", "alert")
	# an order the kitchen can no longer make (the last portion went to someone
	# else): the server tells the table, rather than leaving them waiting
	for j in JobBoard.jobs.duplicate():
		if j.kind != "cook" or j.claimed_by != null or j.done or j.group == null or not is_instance_valid(j.group):
			continue
		if GameState.has_items(j.items):
			continue
		var failed := 0
		while not j.items.is_empty() and not GameState.has_items(j.items):
			j.items.pop_back()
			failed += 1
		j.count = j.items.size()
		if j.items.is_empty():
			JobBoard.finish(j)
		else:
			j.dish = j.items[0]
		lot.fx.add(j.group.where(), "Sorry, we're out!", Color("ff8f7a"))
		j.group.item_failed("", failed)


func rush_tick() -> void:
	var r: Dictionary = GameState.current_rush()
	var n: String = r.get("name", "")
	if n == rush_name:
		return
	rush_name = n
	if r.is_empty():
		return
	if r["mult"] > 1.0:
		GameState.toast.emit("%s! Expect a lot more customers until %02d:00." % [n, int(r["to"] / 60)], "rush")
	else:
		GameState.toast.emit("%s. A good moment to catch up on dishes and sweeping." % n, "")


# ------------------------------------------------------------------ customers

func spawn_tick(minutes: float) -> void:
	if GameState.minute >= GameState.last_seat_min() or not lot.has_entry():
		return
	if critic_at >= 0.0 and GameState.minute >= critic_at and not lot.tables().is_empty():
		critic_at = -1.0
		spawn_group("critic", 1)
		GameState.toast.emit("A food critic just walked in! Their review counts five times.", "critic")
		Sfx.play("critic", -2.0)
	if inspect_at >= 0.0 and GameState.minute >= inspect_at:
		inspect_at = -1.0
		spawn_group("inspector", 1)
	spawn_acc += minutes
	if spawn_acc < next_spawn:
		return
	spawn_acc = 0.0
	next_spawn = 60.0 / GameState.groups_per_hour() * randf_range(0.6, 1.4)
	var window = free_takeout_window()
	if window != null and randf() < Data.TAKEOUT_SHARE * Events.takeout_mult():
		spawn_group("takeout", 1, window)
		return
	var stall = free_stall()
	if stall != null and randf() < Data.CARHOP_SHARE:
		spawn_group("carhop", randi_range(1, 3), stall)
		return
	if lot.tables().is_empty():
		return
	var queued := 0
	for g in groups:
		if g.state == "waiting" or (g.state == "arriving" and not g.takeout and g.kind != "inspector"):
			queued += 1
	# a host keeps a waitlist: people put their name down instead of walking past
	# free waiting seats keep people from walking past a line
	var free_seats: int = lot.wait_seats().size() - lot.wait_taken.size()
	if queued >= (Data.QUEUE_LIMIT_HOST if Front.host_working() else Data.QUEUE_LIMIT) + maxi(0, free_seats / 2):
		return   # they see the line at the door and keep walking
	spawn_group(pick_kind(), -1)


func free_stall():
	for f in lot.of_type("stall"):
		if f.group == null and lot.window_outside(f).x >= 0:
			return f
	return null


func free_takeout_window():
	for f in lot.of_type("takeout"):
		if f.group == null and lot.window_outside(f).x >= 0:
			return f
	return null


func pick_kind() -> String:
	var hour := GameState.minute / 60.0
	var options: Array = []
	var total := 0.0
	for k in Data.CUSTOMERS:
		var c: Dictionary = Data.CUSTOMERS[k]
		if c["weight"] <= 0.0 or hour < c["hours"][0] or hour >= c["hours"][1]:
			continue
		if GameState.rep_level < c.get("min_level", 0):
			continue
		if c.get("min_seats", 0) > 0 and not lot.tables().any(func(t): return t.chairs.size() >= c["min_seats"] and t.table_free()):
			continue   # a big party only comes in if a long table is free
		options.append(k)
		total += c["weight"] * Town.kind_mult(k)
	var roll := randf() * total
	for k in options:
		roll -= Data.CUSTOMERS[k]["weight"] * Town.kind_mult(k)
		if roll <= 0.0:
			return k
	return "regular"


func spawn_group(kind: String, size: int, window = null, extra: Dictionary = {}) -> void:
	if size < 0:
		var range_: Array = Data.CUSTOMERS[kind]["size"]
		if kind == "regular":
			var r := randf()
			size = 1 if r < 0.25 else (2 if r < 0.65 else (3 if r < 0.85 else 4))
		else:
			size = randi_range(range_[0], range_[1])
		size = mini(size, maxi(lot.biggest_party(), 1))
	var g := Group.new()
	g.name = "Group"
	add_child(g)
	groups.append(g)
	g.start(lot, size, people, kind, window, extra)


# ------------------------------------------------------------------ the day

## "Start the day": staff come in an hour before opening to prep, eat and
## take the delivery. The doors open on their own at opening time.
func open_diner() -> void:
	if GameState.phase != GameState.Phase.PLANNING:
		return
	for item in lot.checklist():
		if item[1] or item.size() > 2 and item[2]:
			continue
		GameState.toast.emit("Not ready yet: " + item[0].to_lower() + ".", "bad")
		Sfx.play("error")
		return
	build.undo_stack.clear()
	if GameState.day == 1 and GameState.scrapbook.is_empty():
		scrapbook_add("opening", "Opening day", "%s opens its doors for the very first time." % GameState.diner_name)
	# a new day's list of what stressed people (last night's is kept until now)
	for s in GameState.staff:
		s.stress_log = {}
	GameState.minute = GameState.prep_min()
	spawn_acc = 0.0
	next_spawn = 3.0
	rush_name = ""
	critic_at = -1.0
	inspect_at = -1.0
	var o := GameState.open_min()
	var c := GameState.close_min()
	if GameState.day >= 2 and randf() < Data.CRITIC_CHANCE:
		critic_at = randf_range(o + 60.0, c - 120.0)
	if GameState.day >= GameState.next_inspection_day:
		inspect_at = randf_range(o + 60.0, maxf(o + 90.0, c - 120.0))
	for s in GameState.staff:
		s.set_away(s.day_off_today())
		if s.away:
			Crew.log_line("%s has the day off." % s.person_name, "sun", [s])
	_meal_chairs = {}
	_plates_warned = false
	Books.reset_tips()
	Health.reset_day()
	for s in GameState.staff:
		s.dirty_hands = false
	# who's in, when, and who called in sick
	Shifts.morning()
	Events.plan_day()
	Front.plan_day()
	Stock.schedule_delivery()
	Stock.post_prep_jobs()
	Biz.post_prep()
	GameState.set_phase(GameState.Phase.PREP)
	start_staff_meal()
	GameState.toast.emit("The staff are in. Doors open at %s." % clock_of(o), "good")
	Sfx.play("door", -6.0)


## Prep time is over (or you skipped it): the doors open.
func open_doors() -> void:
	if GameState.phase != GameState.Phase.PREP:
		return
	GameState.minute = maxf(GameState.minute, GameState.open_min())
	GameState.set_phase(GameState.Phase.SERVICE)
	var n := 0
	for d in Stock.prepped:
		n += Stock.prepped[d]
	GameState.toast.emit("Open! Customers are on their way.%s" % ((" %d portions prepped." % n) if n > 0 else ""), "good")
	Sfx.play("door")


static func clock_of(m: float) -> String:
	return "%02d:%02d" % [int(m / 60.0) % 24, int(m) % 60]


# ------------------------------------------------------------------ the staff meal

var _meal_chairs := {}

## Before opening, everyone sits down and eats together: it costs a little
## food and brings people closer.
func start_staff_meal() -> void:
	if not GameState.staff_meal:
		return
	var here: Array = Crew.present()
	if here.size() < 2:
		return
	var cost := Data.STAFF_MEAL_COST * here.size()
	GameState.add_money(-cost)
	GameState.today["staff_meal"] = cost
	GameState.today["food_used"] += cost
	for s in here:
		s.start_meal(free_meal_seat(s))
	Crew.log_line("Staff meal: %s ate together before opening." % Crew.and_list(here.map(func(s): return s.person_name)), "heart", here)


## A dining chair nobody's using for the staff meal (or null: they eat standing).
func free_meal_seat(s):
	var best = null
	var best_d := 1 << 30
	for ch in lot.furniture:
		if not ch.is_seat() or ch.table == null or _meal_chairs.has(ch) or ch.occupant != null:
			continue
		var d: int = lot.distance(s.current_cell(), ch.cell)
		if d < best_d:
			best_d = d
			best = ch
	if best != null:
		_meal_chairs[best] = s
	return best


## Everyone who ate together likes each other a little more.
func end_staff_meal(s) -> void:
	for ch in _meal_chairs.keys():
		if _meal_chairs[ch] == s:
			_meal_chairs.erase(ch)
	for o in Crew.present():
		if o != s and o.ate_today:
			Crew.add(s, o, "meal", Data.REL_EVENTS["meal"]["points"], Data.REL_EVENTS["meal"]["points"])


func end_day() -> void:
	for g in groups:
		if is_instance_valid(g):
			g.remove_now()
	groups.clear()
	lot.wait_taken.clear()
	for p in lot.of_type("pass"):
		for it in p.items:
			if it.get("plated", false):
				GameState.plates_clean += 1
		p.items.clear()
	for s in GameState.staff:
		s.drop_job()
	# money still sitting on a table is picked up when the lights go off
	for t in lot.furniture:
		if t.is_table() and t.cash > 0.0:
			Books.collect_table(t)
	for m in Health.mice.duplicate():
		Health.remove_mouse(m)
	# everyone clocks out: hours, overtime, colds, training
	Shifts.night()
	for s in GameState.staff:
		s.worked_today = s.came_at >= 0.0
	var wages := GameState.wages()
	GameState.add_money(-wages)
	var tip_lines: Array = Books.settle_tips()
	var bills: Dictionary = Books.nightly_bills()
	# the kitchen at night: prep is thrown out, old stock goes off, tomorrow's order goes in
	Stock.toss_prep()
	Stock.spoil()
	Stock.place_order()
	Stock.yesterday = GameState.today["dishes"].duplicate()
	Stock.used_yesterday = GameState.today["used"].duplicate()
	var t: Dictionary = GameState.today
	GameState.totals["best_sales"] = maxf(GameState.totals.get("best_sales", 0.0), t["revenue"])
	if t["scores"].size() >= 5:
		GameState.totals["best_end_rating"] = maxf(float(GameState.totals.get("best_end_rating", 0.0)), GameState.rating)
	for s in GameState.staff.duplicate():
		if s.away:
			if s.away_day == GameState.day:
				Crew.log_line("%s is back tomorrow, well rested." % s.person_name, "sun", [s])
			s.set_away(false)
		if not s.at_work:
			# they went home: tomorrow morning they're shown inside again
			var inside: Vector2i = lot.entry_inside if lot.has_entry() else lot.nearest_walkable(Vector2i(lot.W / 2, lot.H / 2))
			s.place_at(inside)
		s.set_at_work(true)
	Crew.nightly()
	Front.nightly()
	Moments.nightly()
	Town.nightly()
	Biz.nightly()
	GameState.reply_mood *= 0.9
	Career.nightly()
	Goals.check()
	lot.fade_scuffs()
	# tomorrow's schedule: days off and who works days or nights
	Shifts.plan_schedule(GameState.day + 1)
	var level_up := GameState.check_level_up()
	GameState.unlock_by_rep()
	if level_up:
		var lv: Dictionary = GameState.level_info()
		GameState.toast.emit("Your diner is now a %s! More customers are coming%s." % [lv["name"], ", including tourists" if GameState.rep_level == 2 else ""], "good")
		scrapbook_add("level", "Now a %s" % lv["name"], "%s is moving up in the world." % GameState.diner_name)
		Crew.log_line("The diner is now a %s!" % lv["name"], "star")
		Sfx.play("fanfare", -2.0)
	var scores: Array = t["scores"]
	var avg := 0.0
	for s in scores:
		avg += s
	avg = avg / scores.size() if scores.size() > 0 else 0.0
	var worst := ""
	var worst_n := 0
	for k in t["complaints"]:
		if t["complaints"][k] > worst_n:
			worst_n = t["complaints"][k]
			worst = k
	last_report = {
		"day": GameState.day, "groups": t["groups"], "served": t["served"], "left": t["left"],
		"revenue": t["revenue"], "tips": t["tips"], "wages": wages, "bills": bills, "tip_lines": tip_lines,
		"bills_in": Books.days_to_bills(), "bills_next": Books.bills_week(), "loan": Books.loan.duplicate(), "tip_policy": Books.tip_policy,
		"numbers": Books.numbers(t["revenue"] + t["app_fees"], t["food_used"] + t["waste"], wages, t["app_fees"]),
		"kitchen": {"wrong_orders": t["wrong_orders"], "allergies": t["allergies"], "cold_plates": t["cold_plates"], "no_plates": int(t["no_plates"])},
		"health": {"restroom_uses": t["restroom_uses"], "dirty_restroom": t["dirty_restroom"], "trash_runs": t["trash_runs"],
			"handwash_skipped": t["handwash_skipped"], "mice": t["mice"], "mice_caught": t["mice_caught"], "mouse_seen": t["mouse_seen"],
			"has_toilet": lot.has_type("toilet")},
		"front": {"regulars": t["regulars"], "bookings": t["bookings"], "no_shows": t["no_shows"], "app_orders": t["app_orders"], "app_done": t["app_done"],
			"app_fees": t["app_fees"], "app_cancelled": t["app_cancelled"], "app_missed": t["app_missed"], "comped": t["comped"],
			"complaints_raised": t["complaints_raised"], "dashes": t["dashes"], "dash_lost": t["dash_lost"]},
		"supplies": t["delivery_cost"], "order": Stock.pending_cost, "short_fit": Stock.short_fit.duplicate(),
		"delivery_refused": t.get("delivery_refused", false), "staff_meal": t["staff_meal"],
		"waste": t["waste"], "waste_items": t["waste_items"].duplicate(), "food_used": t["food_used"],
		"prepped": t["prepped"], "prep_used": t["prep_used"], "sold_out": t["sold_out"].duplicate(),
		"avg": avg, "reviews": scores.size(), "rating": GameState.rating, "complaint": worst, "money": GameState.money,
		"takeout": t["takeout"], "critic": t["critic"], "inspection": t["inspection"], "crew": Crew.report_lines() + Shifts.report_lines() + Moments.today_lines, "events": Events.today.duplicate(),
		"overtime": Shifts.today["overtime"],
		"level_up": GameState.level_info()["name"] if level_up else "",
		"breakdowns": t["breakdowns"], "types": t["types"].duplicate(),
		"best": t["best"].duplicate(), "worst": t["worst"].duplicate(), "mvp": mvp(),
		"combos": t.get("combos", 0), "upsells": t.get("upsells", 0), "catering": t.get("catering", 0.0), "town": Town.today_lines().slice(0, 2),
	}
	var bills_paid: float = bills.get("rent", 0.0) + bills.get("utilities", 0.0) + bills.get("loan", 0.0) + bills.get("contracts", 0.0) + bills.get("benefits", 0.0) - bills.get("sister", 0.0)
	last_report["net"] = t["revenue"] - wages - bills_paid - last_report["supplies"] - t["staff_meal"]
	# the Books: a line for tonight
	GameState.history.append({"day": GameState.day, "revenue": t["revenue"], "wages": wages, "food": t["food_used"] + t["waste"], "bills": bills_paid,
		"net": last_report["net"], "served": t["served"], "left": t["left"], "rating": GameState.rating, "by_hour": t.get("by_hour", {}).duplicate(),
		"dishes": t["dishes"].duplicate(), "tips": t["tips"], "upsells": t.get("upsells", 0), "combos": t.get("combos", 0)})
	if GameState.history.size() > Data.HISTORY_DAYS:
		GameState.history = GameState.history.slice(GameState.history.size() - Data.HISTORY_DAYS)
	GameState.set_phase(GameState.Phase.REPORT)
	hud.show_report(last_report)


## Who did the most today (jobs finished, with a nudge for good cooking and
## tips): {name, role, jobs, look...} for the day report, or {}.
func mvp() -> Dictionary:
	var best = null
	var best_v := 0.0
	for s in GameState.staff:
		var v: float = s.jobs_today + s.tips_today * 0.05
		if v > best_v:
			best_v = v
			best = s
	if best == null:
		return {}
	return {"name": best.person_name, "role": best.role, "jobs": best.jobs_today, "skin": best.skin, "hair": best.hair, "shirt": best.shirt, "look": best.look}


func start_next_day() -> void:
	GameState.day += 1
	GameState.minute = GameState.prep_min()
	GameState.reset_today()
	Crew.reset_today()
	Town.morning()
	Moments.morning()
	for s in GameState.staff:
		s.energy = 100.0
		s.jobs_today = 0
		s.upsells_today = 0
	GameState.roll_candidates()
	GameState.set_phase(GameState.Phase.PLANNING)
	Shifts.morning_view()
	GameState.staff_changed.emit()
	save_game()
	if GameState.money < 0:
		GameState.toast.emit("You're in debt. Raise prices, cut staff or sell furniture with Remove.", "bad")


# ------------------------------------------------------------------ staff

func hire(i: int) -> void:
	if i < 0 or i >= GameState.candidates.size():
		return
	if GameState.staff.size() >= Data.MAX_STAFF:
		GameState.toast.emit("That's the most staff this diner can hold.", "bad")
		return
	var c: Dictionary = GameState.candidates[i]
	GameState.candidates.remove_at(i)
	var s = add_staff(c)
	Moments.welcome(s)
	Shifts.replan()
	GameState.toast.emit("%s joined as a %s at $%.2f an hour." % [s.person_name, Data.ROLES[s.role]["name"].to_lower(), s.wage], "good")
	Crew.log_line("%s from %s joined the crew." % [s.person_name, Data.hometown(s.origin)], "staff", [s])


func add_staff(d: Dictionary):
	var s := Staff.new()
	s.setup(d, lot)
	people.add_child(s)
	var start: Vector2i = lot.entry_inside if lot.has_entry() else lot.spawn_cells()[0]
	s.place_at(start)
	if not lot.walkable(start):
		s.place_at(lot.nearest_walkable(start))
	GameState.staff.append(s)
	Crew.register(s)
	GameState.staff_changed.emit()
	lot.layout_changed.emit()
	return s


## Someone quit (see Crew.quit): they leave without the usual goodbye toast.
func lose_staff(s) -> void:
	if not GameState.staff.has(s):
		return
	s.drop_job()
	Crew.forget(s)
	GameState.staff.erase(s)
	s.queue_free()
	Shifts.replan()
	GameState.staff_changed.emit()
	lot.layout_changed.emit()


func fire(s) -> void:
	if not GameState.staff.has(s):
		return
	s.drop_job()
	Crew.log_line("%s left the diner." % s.person_name, "walkout", [s])
	Crew.forget(s)
	GameState.staff.erase(s)
	s.queue_free()
	Shifts.replan()
	GameState.staff_changed.emit()
	lot.layout_changed.emit()
	GameState.toast.emit("%s has left the diner." % s.person_name, "")


# ------------------------------------------------------------------ saving

func save_path(s: String) -> String:
	return "%s/%s.json" % [save_dir, s]


## The first free slot name.
func new_slot() -> String:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var i := 1
	while FileAccess.file_exists(save_path("slot_%d" % i)):
		i += 1
	return "slot_%d" % i


## A save from before save slots becomes the first slot.
func migrate_old_save() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	if FileAccess.file_exists(OLD_SAVE) and not FileAccess.file_exists(save_path("slot_1")):
		var text := FileAccess.get_file_as_string(OLD_SAVE)
		var f := FileAccess.open(save_path("slot_1"), FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()
			DirAccess.rename_absolute(OLD_SAVE, OLD_SAVE + ".bak")


## Every save, newest first: {"slot", "name", "day", "money", "rating", "staff", "time", "when"}.
func list_saves() -> Array:
	migrate_old_save()
	var out: Array = []
	var d := DirAccess.open(save_dir)
	if d == null:
		return out
	for fname in d.get_files():
		if not fname.ends_with(".json"):
			continue
		var sl := fname.get_basename()
		var data = JSON.parse_string(FileAccess.get_file_as_string(save_path(sl)))
		if typeof(data) != TYPE_DICTIONARY or not data.has("floor"):
			continue
		var reviews: Array = data.get("reviews", [])
		var rating := 3.0
		if not reviews.is_empty():
			rating = 0.0
			for r in reviews:
				rating += float(r)
			rating /= reviews.size()
		out.append({"slot": sl, "name": str(data.get("name", "")) if str(data.get("name", "")) != "" else "My diner",
			"day": int(data.get("day", 1)), "money": float(data.get("money", 0.0)), "rating": rating,
			"staff": (data.get("staff", []) as Array).size(), "time": FileAccess.get_modified_time(save_path(sl)),
			"when": str(data.get("saved_at", ""))})
	out.sort_custom(func(a, b): return a["time"] > b["time"])
	return out


func delete_save(sl: String) -> void:
	if FileAccess.file_exists(save_path(sl)):
		DirAccess.remove_absolute(save_path(sl))
	if sl == slot:
		slot = ""


## Saves this diner (to its own slot, or to `to`). Only mornings are saved:
## the game saves itself at the start of every day.
func save_game(to: String = "") -> bool:
	if to != "":
		slot = to
	if slot == "":
		slot = new_slot()
	DirAccess.make_dir_recursive_absolute(save_dir)
	# keep the sister diner's idea of how this one's doing up to date
	if not Biz.sister.is_empty() and str(Biz.sister.get("slot", "")) != slot:
		_patch_sister(str(Biz.sister["slot"]), {"name": GameState.diner_name, "slot": slot, "weekly": GameState.weekly_profit() * Data.SISTER_SHARE})
	var furn := []
	for f in lot.furniture:
		furn.append({"type": f.type, "x": f.cell.x, "y": f.cell.y, "dir": f.dir, "wear": f.wear, "broken": f.broken, "tier": f.tier})
	var team := []
	for s in GameState.staff:
		team.append({"name": s.person_name, "role": s.role, "wage": s.wage, "raises": s.raises, "cooking": s.cooking, "service": s.service,
			"skin": s.skin.to_html(), "hair": s.hair.to_html(), "priorities": s.priorities,
			"traits": s.traits, "xp": s.xp, "id": s.id, "origin": s.origin, "bio": s.bio, "manager": s.manager,
			"warnings": s.warnings, "caught_days": s.caught_days, "stress": s.stress, "burnout_warned": s.burnout_warned,
			"raise_refused": s.raise_refused, "start_skill": s.start_skill, "last_raise_day": s.last_raise_day, "away_day": s.away_day,
			"shift": s.shift, "shift_locked": s.shift_locked, "sched_off": s.sched_off, "streak": s.streak, "burnout_nights": s.burnout_nights, "sick_days": s.sick_days, "closed_late": s.closed_late, "trainer_id": s.trainer_id, "training_days": s.training_days,
			"birthday": s.birthday, "hired_day": s.hired_day, "shifts_worked": s.shifts_worked, "jobs_month": s.jobs_month, "eotm_count": s.eotm_count,
			"rank": s.rank, "perks": s.perks, "requested_off": s.requested_off, "avail": s.avail})
	var plates := GameState.plates_clean
	for f in lot.furniture:
		plates += f.dirty_plates + f.dirty
	var data := {
		"version": SAVE_VERSION, "name": GameState.diner_name, "saved_at": Time.get_datetime_string_from_system(false, true), "day": GameState.day, "money": GameState.money, "reviews": GameState.reviews,
		"review_count": GameState.review_count,
		"menu": GameState.menu, "stock": GameState.stock, "target": GameState.target,
		"unlocked": GameState.unlocked, "hometown": GameState.hometown, "combos": GameState.combos, "kids_menu": GameState.kids_menu, "playlist": GameState.playlist, "radio": GameState.radio, "review_feed": GameState.review_feed, "reply_mood": GameState.reply_mood, "moments": Moments.save_data(), "goals": Goals.save_data(), "town": Town.save_data(), "biz": Biz.save_data(), "history": GameState.history, "scrapbook": GameState.scrapbook, "career": Career.save_data(),
		"plates_total": GameState.plates_total, "plates": plates, "totals": GameState.totals,
		"grade": GameState.grade, "crew": Crew.save_data(),
		"supplier": GameState.supplier, "special": GameState.special, "owned": GameState.owned, "rep_level": GameState.rep_level,
		"buzz_until": Events.buzz_until_day, "last_inspection": GameState.last_inspection_day, "next_inspection": GameState.next_inspection_day,
		"kitchen": Stock.save_data(), "staff_meal": GameState.staff_meal, "books": Books.save_data(), "schedule_auto": Shifts.auto, "front": Front.save_data(), "health": Health.save_data(), "hours": GameState.hours,
		"floor": Array(lot.floor_type), "wall": Array(lot.wall), "dirt": Array(lot.dirt), "scuff": Array(lot.scuff), "furniture": furn, "staff": team,
		"candidates": GameState.candidates.map(func(c):
			var d: Dictionary = c.duplicate()
			d["skin"] = c["skin"].to_html()
			d["hair"] = c["hair"].to_html()
			return d),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		GameState.toast.emit("Couldn't save the game.", "bad")
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


## Loads a save (this diner's own slot, or `from`).
func load_game(from: String = "") -> bool:
	if from != "":
		slot = from
	elif slot == "":
		var saves := list_saves()
		if saves.is_empty():
			return false
		slot = saves[0]["slot"]
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("floor"):
		return false
	var version := int(data.get("version", 1))
	clear_world()
	GameState.reset()
	GameState.diner_name = str(data.get("name", ""))
	GameState.day = int(data["day"])
	GameState.money = float(data["money"])
	GameState.reviews = data["reviews"]
	GameState.review_count = int(data.get("review_count", GameState.reviews.size()))
	if not GameState.reviews.is_empty():
		var sum := 0.0
		for r in GameState.reviews:
			sum += r
		GameState.rating = sum / GameState.reviews.size()
	GameState.kids_menu = bool(data.get("kids_menu", false))
	GameState.playlist = str(data.get("playlist", "oldies")) if Data.PLAYLISTS.has(str(data.get("playlist", ""))) else "oldies"
	GameState.radio = str(data.get("radio", "hits")) if Data.RADIO.has(str(data.get("radio", ""))) else "hits"
	GameState.review_feed = data.get("review_feed", [])
	GameState.reply_mood = float(data.get("reply_mood", 0.0))
	for k in data.get("combos", {}):
		GameState.combos[str(k)] = bool(data["combos"][k])
	for d in data.get("unlocked", []):
		if Data.DISHES.has(str(d)):
			GameState.unlocked.append(str(d))
	var ht: Dictionary = data.get("hometown", {})
	if not ht.is_empty():
		GameState.set_hometown(str(ht.get("cook", "")), str(ht.get("dish", "")))
	for d in data["menu"]:
		if GameState.menu.has(d):
			GameState.menu[d] = {"on": bool(data["menu"][d]["on"]), "price": float(data["menu"][d]["price"])}
	for ing in Data.ING_ORDER:
		GameState.stock[ing] = int(data["stock"].get(ing, Data.START_STOCK[ing]))
		GameState.target[ing] = int(data["target"].get(ing, Data.START_STOCK[ing]))
	Stock.load_data(data.get("kitchen", {}))
	Books.load_data(data.get("books", {}))
	Front.load_data(data.get("front", {}))
	Moments.load_data(data.get("moments", {}))
	Town.load_data(data.get("town", {}))
	Biz.load_data(data.get("biz", {}))
	Career.load_data(data.get("career", {}))
	GameState.history = data.get("history", [])
	GameState.scrapbook = data.get("scrapbook", [])
	# very old saves kept a list of tutorial goals under "goals": ignore that
	var gd = data.get("goals", {})
	Goals.load_data(gd if gd is Dictionary else {})
	Stock.reconcile()
	GameState.staff_meal = bool(data.get("staff_meal", false))
	Shifts.auto = bool(data.get("schedule_auto", true))
	for k in data.get("hours", {}):
		if GameState.hours.has(k):
			GameState.hours[k] = bool(data["hours"][k])
	GameState.minute = GameState.prep_min()
	GameState.supplier = data.get("supplier", "standard") if Data.SUPPLIERS.has(data.get("supplier", "")) else "standard"
	GameState.special = data.get("special", "") if Data.DISHES.has(data.get("special", "")) else ""
	GameState.rep_level = int(data.get("rep_level", 0))
	Events.buzz_until_day = int(data.get("buzz_until", 0))
	if version >= 4:
		GameState.owned = data.get("owned", ["start"])
	else:
		GameState.own_all_land()   # older diners were built before land had to be bought
	GameState.plates_total = int(data["plates_total"])
	GameState.plates_clean = int(data["plates"])
	var totals: Dictionary = data.get("totals", {})
	for k in totals:
		GameState.totals[k] = totals[k]
	GameState.totals["served"] = int(GameState.totals["served"])
	GameState.grade = data.get("grade", "")
	GameState.last_inspection_day = int(data.get("last_inspection", 0))
	if data.has("next_inspection"):
		GameState.next_inspection_day = int(data["next_inspection"])
	elif GameState.last_inspection_day > 0:
		# older saves: the next routine visit is a few months after the last one
		GameState.next_inspection_day = GameState.last_inspection_day + randi_range(Data.INSPECTION_DAYS.x, Data.INSPECTION_DAYS.y)
	# version 1 and 2 saves have no crew yet: everyone gets a hometown and fresh first impressions
	Crew.load_data(data.get("crew", {}) if version >= 3 else {})
	for i in lot.floor_type.size():
		lot.floor_type[i] = int(data["floor"][i])
		lot.wall[i] = int(data["wall"][i])
		if data.has("dirt"):
			lot.dirt[i] = float(data["dirt"][i])
		if data.has("scuff"):
			lot.scuff[i] = float(data["scuff"][i])
	for fd in data["furniture"]:
		if not Data.FURNITURE.has(fd["type"]):
			continue
		var dir := int(fd["dir"]) if fd.has("dir") else (1 if fd.get("rot", false) else 0)
		var piece = lot.add_furniture(fd["type"], Vector2i(int(fd["x"]), int(fd["y"])), dir)
		piece.wear = float(fd.get("wear", 0.0))
		piece.broken = bool(fd.get("broken", false))
		piece.tier = int(fd.get("tier", 0))
		if piece.broken:
			JobBoard.post("fix", "repair", {"furniture": piece})
	lot.refresh()
	Health.load_data(data.get("health", {}))
	for sd in data["staff"]:
		var d: Dictionary = sd.duplicate()
		d["skin"] = Color(sd["skin"])
		d["hair"] = Color(sd["hair"])
		d["wage"] = float(sd["wage"])
		if version < 5:
			d["shift"] = "double"
		if version < 6:
			# pay used to be a made-up amount per shift; now it's California's
			# going rate by the hour for their role
			var role: String = GameState.guess_role(sd.get("priorities", {}), bool(sd.get("manager", false)))
			d["role"] = role
			d["wage"] = Data.role_pay(role, int(sd["cooking"]), int(sd["service"]), sd.get("traits", []))
		d["cooking"] = int(sd["cooking"])
		d["service"] = int(sd["service"])
		add_staff(d)
	if data.has("candidates"):
		GameState.candidates = []
		for cd in data["candidates"]:
			var c: Dictionary = cd.duplicate()
			c["skin"] = Color(cd["skin"])
			c["hair"] = Color(cd["hair"])
			c["traits"] = cd.get("traits", [])
			if not c.has("origin"):
				c["origin"] = Data.random_origin()
				c["origin"].erase("name")
				c["bio"] = Data.write_bio(c["origin"], int(cd["cooking"]), int(cd["service"]), c["traits"])
			for k in ["cooking", "service"]:
				c[k] = int(cd[k])
			c["wage"] = float(cd["wage"])
			if not Data.ROLES.has(str(c.get("role", ""))):
				c["role"] = "cook" if c["cooking"] >= c["service"] else "server"
				c["wage"] = Data.role_pay(c["role"], c["cooking"], c["service"], c["traits"])
			GameState.candidates.append(c)
	for y in lot.H:
		for x in lot.W:
			if lot.dirt[lot.idx(Vector2i(x, y))] >= Data.DIRT_JOB:
				lot.post_sweep(Vector2i(x, y))
	GameState.set_phase(GameState.Phase.PLANNING)
	Shifts.morning_view()
	GameState.money_changed.emit(GameState.money)
	GameState.rating_changed.emit(GameState.rating)
	GameState.grade_changed.emit(GameState.grade)
	GameState.staff_changed.emit()
	GameState.stock_changed.emit()
	GameState.menu_changed.emit()
	return true


## A fresh diner in a new save slot.
## Opens a second diner: $100,000 goes across to get it started; this diner
## keeps running under its crew, and its weekly profit comes in with the other
## one's bills (and the other way round).
## A page in the scrapbook, with a snapshot of the diner right now (when
## there's a screen to take it from).
func scrapbook_add(kind: String, title: String, text: String) -> void:
	var page := {"day": GameState.day, "kind": kind, "title": title, "text": text, "img": ""}
	GameState.scrapbook.append(page)
	if GameState.scrapbook.size() > Data.SCRAPBOOK_MAX:
		GameState.scrapbook = GameState.scrapbook.slice(GameState.scrapbook.size() - Data.SCRAPBOOK_MAX)
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	# a clean picture: the interface steps out of the way for a moment
	var was: bool = hud.visible
	hud.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.visible = was
	if img == null or img.is_empty():
		return
	img.resize(320, int(320.0 * img.get_height() / maxf(1.0, img.get_width())), Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(save_dir + "/scrapbook")
	var path := "%s/scrapbook/%s_%d_%d.png" % [save_dir, slot if slot != "" else "new", GameState.day, Time.get_ticks_msec()]
	if img.save_png(path) == OK:
		page["img"] = path


## Photo mode: P takes a picture for the scrapbook.
func take_photo() -> void:
	scrapbook_add("photo", "A snapshot", "%s, %s." % [Town.date_text(), GameState.clock_text()])
	Sfx.play("pop")
	GameState.toast.emit("Snap! It's in the scrapbook.", "good")


func open_second_location(new_name: String) -> bool:
	if not Biz.can_open_second():
		return false
	var old_name := GameState.diner_name
	var weekly := GameState.weekly_profit() * Data.SISTER_SHARE
	GameState.add_money(-Data.SECOND_COST)
	save_game()
	var old_slot := slot
	new_game(new_name)
	GameState.money = Data.SECOND_COST
	GameState.money_changed.emit(GameState.money)
	Biz.sister = {"name": old_name, "slot": old_slot, "weekly": weekly}
	save_game()
	_patch_sister(old_slot, {"name": GameState.diner_name, "slot": slot, "weekly": 0.0})
	GameState.toast.emit("%s is open! %s keeps running without you; its weekly takings come in with the bills here." % [GameState.diner_name, old_name], "good")
	return true


## Writes a sister diner's details into another diner's save.
func _patch_sister(other_slot: String, sister: Dictionary) -> void:
	var path := save_path(other_slot)
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var b: Dictionary = data.get("biz", {})
	b["sister"] = sister
	data["biz"] = b
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


func new_game(diner_name: String = "") -> void:
	clear_world()
	GameState.reset()
	GameState.diner_name = diner_name if diner_name.strip_edges() != "" else Data.DINER_NAMES.pick_random()
	slot = new_slot()
	lot.init_grid()
	GameState.money_changed.emit(GameState.money)
	GameState.rating_changed.emit(GameState.rating)
	GameState.grade_changed.emit(GameState.grade)
	GameState.staff_changed.emit()
	GameState.stock_changed.emit()
	GameState.menu_changed.emit()
	GameState.set_phase(GameState.Phase.PLANNING)


func clear_world() -> void:
	for g in groups:
		if is_instance_valid(g):
			g.remove_now()
	groups.clear()
	for s in GameState.staff:
		s.queue_free()
	GameState.staff = []
	Crew.reset()
	Events.reset()
	Books.reset()
	Front.reset()
	Health.reset()
	Shifts.reset()
	Moments.reset()
	Goals.reset()
	Town.reset()
	Biz.reset()
	Career.reset()
	JobBoard.clear()
	lot.init_grid()
