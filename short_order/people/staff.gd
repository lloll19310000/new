extends "res://people/pawn.gd"
## A staff member. Picks the best job from the job board by their priorities
## (1 = do first, 0 = never), breaks it into small steps and works through them.
## Gets tired while working and takes breaks (faster on a sofa in the staff room),
## and gets better at cooking and serving with practice.
## How they get along with coworkers lives in the Crew autoload; this script
## tells it what happened (a dropped plate, a repair) and sometimes sneaks a
## look at the phone.

signal leveled_up(skill: String, level: int)

const JobClass = preload("res://people/job.gd")

var person_name := ""
var role := "server"            # what they were hired to do (Data.ROLES)
var wage := 17.0                # dollars an hour
var raises := 0.0               # raises you've given them, kept if their role changes
var cooking := 5                # 1-10: faster cooking, better food
var service := 5                # 1-10: faster walking and serving
var traits: Array = []          # keys of Data.TRAITS
var xp := {"cooking": 0.0, "service": 0.0}
var priorities := {"cook": 2, "serve": 2, "host": 4, "wash": 3, "clean": 3, "fix": 3}
var energy := 100.0
var job = null
var steps: Array = []
var status := "Idle"
var think_timer := 0.0
var reserved := {}              # things to give back if a job is dropped
var on_break := false
var rest_sofa = null            # the sofa they're resting on, if any
var rest_cell := Vector2i(-1, -1)

# who they are (hometown and life story are flavour only)
var id := 0                     # permanent, used by the Crew opinions
var origin: Dictionary = {}     # {country, city, dish, place}
var bio := ""
var manager: bool:
	get:
		return role == "manager"
var warnings := 0
var caught_days: Array = []     # days you caught them on the phone (this week)
# phones, arguments and mood (see autoload/crew.gd)
var on_phone := false
var phone_left := 0.0
var phone_seen := {}            # who already reacted to this phone session
var pause_left := 0.0           # minutes left standing still, arguing
var mood := "okay"              # "cheerful", "okay" or "fed_up"
var crew_speed := 1.0           # faster near a friend, slower near a rival
var last_bad := -9999.0         # game time of the last bad thing that happened to them
var last_good := -9999.0
var _friend_factor := 1.0
var _near_rival := false
# stress and what's at stake (see autoload/crew.gd and autoload/events.gd)
var stress := 0.0               # 0-100; sets the mood, causes mistakes, and too much means they quit
var burnout_warned := false     # ended a day burned out (see burnout_nights)
var burnout_nights := 0         # nights in a row they ended burned out; at Data.BURNOUT_QUIT_NIGHTS they quit
var raise_refused := 0          # times you said no to a raise
var start_skill := 0            # cooking + service when hired (or at their last raise)
var last_raise_day := 1
var away_day := -1              # a day off they asked for
var sched_off := -1             # a day off the schedule gave them
var streak := 0                 # days in a row they've worked
var shift_locked := false       # you set their shift by hand: the schedule leaves it alone
var break_asked := false        # a manager told them to take a break after this job
var away := false               # having that day off right now
var _burnt_day := -1
# the morning
var dirty_hands := false        # after the restroom or the trash, until they wash up
var _toilet_first := false      # this break starts with a trip to the restroom
# shifts (see autoload/shifts.gd)
var shift := "double"           # "open", "close" or "double"
var at_work := true             # in the building today (walking in counts)
var arriving := false           # walking in from the street
var heading_home := false       # walking out at the end of their shift
var clock_out := false          # their shift is over: finish up and go home
var arrive_at := -1.0           # game minute they're due in today
var came_at := -1.0             # when they actually got here
var left_at := -1.0             # when they left
var late_by := 0.0
var no_show := false
var sick_days := 0              # days of being ill left
var sick_at_work := false       # came in sick today
var exposure := 0.0             # minutes spent near someone sick today
var closed_late := false        # stayed late closing last night: tired this morning
var trainer_id := 0             # who's training them (a Crew id), or 0
var training_days := 0
var train_today := 0.0          # minutes spent working beside their trainer today
var _training := false          # training someone right now (slows them a little)
var tips_today := 0.0           # tips they take home tonight
var tips_earned := 0.0          # tips from tables they served (before any sharing)
var worked_today := false
var jobs_today := 0              # jobs finished today, for the day's MVP
var meal_left := 0.0            # minutes of staff meal left
var meal_seat = null            # the dining chair they eat at, or null
var ate_today := false


func setup(d: Dictionary, lot_ref) -> void:
	lot = lot_ref
	person_name = d["name"]
	role = str(d.get("role", ""))
	if not Data.ROLES.has(role):
		role = GameState.guess_role(d.get("priorities", {}), bool(d.get("manager", false)))
	wage = float(d["wage"])
	raises = float(d.get("raises", 0.0))
	cooking = d["cooking"]
	service = d["service"]
	skin = d["skin"]
	hair = d["hair"]
	traits = d.get("traits", []).duplicate()
	id = int(d.get("id", 0))
	origin = d.get("origin", {}).duplicate()
	if origin.is_empty():
		origin = Data.random_origin()
		origin.erase("name")
	bio = d.get("bio", "")
	if bio == "":
		bio = Data.write_bio(origin, cooking, service, traits)
	stress = float(d.get("stress", 0.0))
	burnout_warned = bool(d.get("burnout_warned", false))
	burnout_nights = int(d.get("burnout_nights", 1 if burnout_warned else 0))
	sched_off = int(d.get("sched_off", -1))
	streak = int(d.get("streak", 0))
	shift_locked = bool(d.get("shift_locked", false))
	raise_refused = int(d.get("raise_refused", 0))
	start_skill = int(d.get("start_skill", cooking + service))
	last_raise_day = int(d.get("last_raise_day", GameState.day))
	away_day = int(d.get("away_day", -1))
	shift = d.get("shift", "double") if d.get("shift", "double") in Data.SHIFT_ORDER else "double"
	sick_days = int(d.get("sick_days", 0))
	closed_late = bool(d.get("closed_late", false))
	trainer_id = int(d.get("trainer_id", 0))
	training_days = int(d.get("training_days", 0))
	warnings = int(d.get("warnings", 0))
	caught_days = []
	for day in d.get("caught_days", []):
		caught_days.append(int(day))
	if d.has("xp"):
		xp = {"cooking": float(d["xp"].get("cooking", 0.0)), "service": float(d["xp"].get("service", 0.0))}
	priorities = GameState.default_priorities(role)
	if d.has("priorities"):
		for k in d["priorities"]:
			priorities[k] = int(d["priorities"][k])
	dress()
	is_staff = true
	customer_nav = false
	mess = 2.0 if has_trait("clumsy") else (0.5 if has_trait("tidy") else 1.0)
	name = "Staff_" + person_name


## Their uniform goes with their role.
func dress() -> void:
	shirt = Data.ROLE_UNIFORM.get(role, Data.UNIFORM)
	look = "role:" + role
	queue_redraw()


func has_trait(t: String) -> bool:
	return traits.has(t)


## At work and not walking in or out: part of today's crew right now.
func is_here() -> bool:
	return at_work and not away and not arriving and not heading_home


func set_at_work(on: bool) -> void:
	if not on:
		drop_job()
	at_work = on
	visible = on and not away


func energy_factor() -> float:
	return 0.7 + 0.3 * energy / 100.0


## Very stressed people slow down.
func stress_factor() -> float:
	return 0.9 if stress > Data.STRESS_MISTAKES else 1.0


func add_stress(v: float) -> void:
	stress = clampf(stress + v, 0.0, 100.0)


## Off today: a day they asked for, or one the schedule gave them.
func day_off_today() -> bool:
	return away_day == GameState.day or sched_off == GameState.day


## A day off: gone from the diner for the day, back fresh the next morning.
func set_away(on: bool) -> void:
	if on:
		drop_job()
	var was := away
	away = on
	visible = at_work and not on
	if was and not on:
		stress = 0.0
		energy = 100.0


func work_speed(for_cooking: bool) -> float:
	var skill := cooking if for_cooking else service
	var s := (0.75 + skill * 0.05) * energy_factor() * crew_speed * stress_factor()
	if has_trait("slow"):
		s *= 0.85
	if sick_at_work:
		s *= Data.SICK_SPEED
	if _training:
		s *= Data.TRAIN_TRAINER_SPEED
	return s


func tick(dt: float, minutes: float) -> void:
	# walking in from the street, or home at the end of a shift
	if arriving or heading_home:
		speed_mult = 1.0
		status = "Arriving" if arriving else "Heading home"
		move_tick(dt)
		if not is_moving():
			if arriving:
				arriving = false
				status = "Idle"
			else:
				Shifts.left_work(self)
		return
	if clock_out and job == null:
		go_home()
		return
	speed_mult = (0.85 + service * 0.035) * energy_factor() * crew_speed * stress_factor()
	if has_trait("speedy"):
		speed_mult *= 1.2
	if has_trait("slow"):
		speed_mult *= 0.85
	var active := GameState.is_active()
	if on_break:
		rest_tick(minutes)
	elif active:
		var drain := Data.ENERGY_WORK if job != null else Data.ENERGY_IDLE
		if has_trait("tireless"):
			drain *= 0.5
		energy = maxf(0.0, energy - minutes * drain)
	# on the phone or in the middle of an argument: everything waits
	if on_phone:
		phone_left -= minutes
		status = "On the phone"
		if phone_left <= 0.0 or GameState.phase != GameState.Phase.SERVICE:
			end_phone()
		return
	if pause_left > 0.0:
		pause_left -= minutes
		status = "Arguing"
		return
	if GameState.phase == GameState.Phase.SERVICE and not on_break:
		maybe_phone(minutes)
		if on_phone:
			return
	if job != null:
		practice(minutes)
	if job == null and not on_break:
		if (energy < Data.BREAK_AT or break_asked) and active:
			break_asked = false
			start_break()
		else:
			think_timer -= dt
			if think_timer <= 0.0:
				think_timer = 0.3
				choose_job()
			if job == null and not is_moving():
				status = "Idle"
				if randf() < 0.004:
					wander()
	if job != null:
		run_steps(minutes)
	move_tick(dt)
	wears_hat = false
	# a bag of trash carried through the dining room: customers notice
	if carry.has("trash") and lot.floor_at(current_cell()) == Data.FLOOR_DINER:
		for g in Crew.groups_near(position, 3.0):
			g.note_trouble("trash carried past tables", Data.TRASH_PAST_TABLES)


# ------------------------------------------------------------------ phones

func is_working() -> bool:
	return job != null and not on_phone and pause_left <= 0.0 and not on_break


func is_idle() -> bool:
	return job == null and not on_break and not on_phone


## Idle people sometimes sneak a look at their phone. Fed-up people might
## even do it in the middle of a job. On a break, phones are fine.
func maybe_phone(minutes: float) -> void:
	var p := 0.0
	if job == null:
		p = Data.PHONE_CHANCE * (2.0 if mood == "fed_up" else 1.0)
	elif mood == "fed_up":
		p = Data.PHONE_CHANCE_WORKING
	if p > 0.0 and randf() < p * minutes:
		start_phone()


func start_phone() -> void:
	on_phone = true
	phone_left = randf_range(Data.PHONE_MINUTES.x, Data.PHONE_MINUTES.y)
	phone_seen = {}
	status = "On the phone"
	queue_redraw()


func end_phone() -> void:
	on_phone = false
	phone_left = 0.0
	queue_redraw()


func _draw() -> void:
	super()
	var f := facing.normalized() if facing.length() > 0.01 else Vector2.DOWN
	var side := Vector2(-f.y, f.x)
	if manager:
		# a little gold badge on the shirt
		var b := f * 2.5 + side * 4.0
		draw_circle(b, 2.6, Color("f2c14e"))
		draw_arc(b, 2.6, 0, TAU, 12, Color("8a6414"), 0.8, true)
	if on_phone:
		var p := f * 8.0 - Vector2(0, 2)
		draw_rect(Rect2(p - Vector2(3, 4), Vector2(6, 8)), Color("25252b"))
		draw_rect(Rect2(p - Vector2(2, 3), Vector2(4, 5.5)), Color("8fd3ff"))


## Shift over: walk out to the street.
func go_home() -> void:
	if on_break:
		end_break()
	end_phone()
	clock_out = false
	heading_home = true
	status = "Heading home"
	if not go_to(lot.spawn_cells().pick_random()):
		Shifts.left_work(self)


func wander() -> void:
	var here := current_cell()
	for i in 6:
		var c := here + Vector2i(randi_range(-4, 4), randi_range(-4, 4))
		if lot.in_lot(c) and lot.indoors(c) and lot.walkable(c):
			go_to(c)
			return


# ------------------------------------------------------------------ skills

func practice(minutes: float) -> void:
	var skill := ""
	if job.type == "cook":
		skill = "cooking"
	elif job.type == "serve":
		skill = "service"
	if skill == "":
		return
	var level: int = get(skill)
	if level >= 10:
		return
	var mult := 2.0 if has_trait("learner") else 1.0
	# working beside a better trainer: twice the practice, and they get on
	var tr = Shifts.trainer_near(self)
	if tr != null and tr.get(skill) >= level + 2:
		mult *= Data.TRAIN_XP
		Crew.add(self, tr, "trained", 0.05 * minutes, 3.0)
	xp[skill] += minutes * mult
	var need := Data.xp_needed(level)
	if xp[skill] >= need:
		xp[skill] -= need
		set(skill, level + 1)
		leveled_up.emit(skill, level + 1)
		GameState.toast.emit("%s got better at %s (%d)." % [person_name, skill, level + 1], "good")
		GameState.staff_changed.emit()


# ------------------------------------------------------------------ breaks

func start_break() -> void:
	# now and then a break starts with a trip to the restroom (then wash up!)
	if not _toilet_first and randf() < 0.3 and not Health.toilets().is_empty():
		var t = Health.free_toilet(current_cell())
		if t != null:
			_toilet_first = true
			restroom_visit(t)
			return
	_toilet_first = false
	on_break = true
	status = "Taking a break"
	rest_sofa = null
	var best_d := 1 << 30
	var here := current_cell()
	for f in lot.of_type("sofa"):
		var c = f.free_rest_cell()
		if c == null:
			continue
		var d: int = lot.distance(here, c)
		if d < best_d and not lot.find_path(here, c).is_empty():
			best_d = d
			rest_sofa = f
			rest_cell = c
	if rest_sofa != null:
		rest_sofa.resters[rest_cell] = self
		go_to(rest_cell)
	elif not lot.of_type("sofa").is_empty():
		var others: Array = []
		for f in lot.of_type("sofa"):
			for c in f.resters:
				if f.resters[c] != null:
					others.append(f.resters[c])
		Crew.sofa_full(self, others)


## The staff meal before opening: sit down together and eat.
func start_meal(seat) -> void:
	drop_job()
	on_break = true
	ate_today = true
	meal_left = Data.STAFF_MEAL_MINUTES
	meal_seat = seat
	rest_sofa = null
	status = "Staff meal"
	if seat != null and not go_to(seat.cell):
		meal_seat = null


func meal_tick(minutes: float) -> void:
	if meal_seat != null and not lot.furniture.has(meal_seat):
		meal_seat = null
		sitting = false
	if is_moving():
		return
	if meal_seat != null and not sitting:
		sitting = true
		place_at(meal_seat.cell)
		if meal_seat.table != null:
			face_toward(meal_seat.table.center_px())
		queue_redraw()
	status = "Staff meal"
	meal_left -= minutes
	energy = minf(100.0, energy + minutes * 0.5)
	if meal_left <= 0.0:
		meal_left = 0.0
		meal_seat = null
		add_stress(Data.STAFF_MEAL_STRESS)
		if Crew.main != null:
			Crew.main.end_staff_meal(self)
		end_break()


func rest_tick(minutes: float) -> void:
	if meal_left > 0.0:
		meal_tick(minutes)
		return
	if rest_sofa != null and not lot.furniture.has(rest_sofa):
		rest_sofa = null
		sitting = false
	if is_moving():
		return
	if rest_sofa != null:
		if not sitting:
			sitting = true
			place_at(rest_cell)
			facing = Vector2(rest_sofa.facing())
			queue_redraw()
		status = "Resting on the sofa"
		energy = minf(100.0, energy + minutes * Data.REST_SOFA)
	else:
		status = "Taking a break (no sofa)"
		energy = minf(100.0, energy + minutes * Data.REST_STANDING)
	if energy >= Data.BREAK_UNTIL:
		end_break()


func end_break() -> void:
	on_break = false
	sitting = false
	meal_left = 0.0
	meal_seat = null
	if rest_sofa != null and lot.furniture.has(rest_sofa):
		rest_sofa.resters.erase(rest_cell)
	rest_sofa = null
	status = "Idle"
	queue_redraw()


# ------------------------------------------------------------------ choosing a job

func choose_job() -> void:
	if clock_out:
		return
	var here := current_cell()
	var best = null
	var best_score := INF
	for j in JobBoard.open_jobs():
		var pr: int = job_priority(j)
		if pr <= 0 or not can_take(j):
			continue
		var loc := job_cell(j)
		var score: float = pr * 10000.0 + lot.distance(here, loc) * 10.0 + j.created * 0.5
		if j.kind == "prep" and GameState.is_open():
			score += 4000.0   # once the doors are open, orders come before prep
		elif j.kind in ["till", "check"]:
			score -= 3000.0   # people waiting to pay come first: it frees tables and brings in the money
		elif j.kind == "greet":
			score -= 2000.0   # a quick hello at the door keeps people from walking off
		elif j.kind == "wash" and GameState.plates_clean < Data.PLATES_LOW and GameState.is_open():
			score -= 6000.0   # "we need plates!": the kitchen can't send anything out without them
		if score < best_score:
			best_score = score
			best = j
	if best != null:
		start_job(best)


## Paying can be handled from the Host or the Serve column (whichever they
## rank higher); complaints go to managers only.
func job_priority(j) -> int:
	match j.kind:
		"till", "check":
			var a: int = priorities.get("host", 0)
			var b: int = priorities.get("serve", 0)
			if a == 0:
				return b
			if b == 0:
				return a
			return mini(a, b)
		"complaint", "mediate", "checkin":
			return 1 if manager else 0
	return priorities.get(j.type, 0)


func group_ok(g) -> bool:
	return g != null and is_instance_valid(g) and g.state != "leaving" and g.state != "gone"


func plates_for(j) -> int:
	if group_ok(j.group) and j.group.takeout:
		return 0
	var plated := 0
	for d in j.items:
		if Data.DISHES[d]["plate"]:
			plated += 1
	return plated


func can_take(j) -> bool:
	match j.kind:
		"take_order":
			if not group_ok(j.group) or j.group.state != "seated":
				return false
			# a regular's favourite gets a few minutes' head start
			if j.pref != null and j.pref != self and is_instance_valid(j.pref) and GameState.staff.has(j.pref) \
					and j.pref.is_here() and GameState.minute - j.created < 3.0:
				return false
			return true
		"greet":
			return group_ok(j.group) and j.group.state == "waiting" and not j.group.greeted and not lot.of_type("host").is_empty()
		"till":
			return group_ok(j.group) and j.group.state == "paying" and j.furniture != null and lot.furniture.has(j.furniture)
		"check":
			return group_ok(j.group) and j.group.state == "paying" and j.group.table != null
		"complaint":
			return manager and group_ok(j.group) and j.group.state == "complaining" and j.group.table != null
		"mediate":
			return manager and j.who != self and j.who2 != self and Crew.valid_here(j.who) and Crew.valid_here(j.who2)
		"checkin":
			return manager and j.who != self and Crew.valid_here(j.who)
		"cook":
			if not group_ok(j.group) or not Events.powered():
				return false
			if free_station(j.station) == null or lot.of_type("pass").is_empty():
				return false
			var needs_fridge := false
			for d in Stock.raw_part(j.items):
				if not Data.DISHES[d]["needs"].is_empty():
					needs_fridge = true
			if needs_fridge and lot.of_type("fridge").is_empty():
				return false
			if needs_ice(j.items) and lot.of_type("ice").is_empty():
				return false
			if GameState.plates_clean < plates_for(j):
				return false
			return GameState.has_items(j.items)
		"prep":
			if free_station("prep") == null or not GameState.dish_on(j.dish):
				return false
			if lot.of_type("fridge").is_empty() and not Data.DISHES[j.dish]["needs"].is_empty():
				return false
			return GameState.has_raw([j.dish])
		"deliver":
			return group_ok(j.group) and pass_with_items(j.group) != null
		"scrub":
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.grime >= 0.2 \
				and (j.furniture.occupant == null or not is_instance_valid(j.furniture.occupant))
		"trash":
			var at_least := 0.05 if GameState.phase == GameState.Phase.CLEANUP else 0.3
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.fill >= at_least
		"restock":
			return j.furniture != null and lot.furniture.has(j.furniture) and not j.furniture.stocked and j.furniture.user == null
		"bus":
			return j.furniture != null and lot.furniture.has(j.furniture) and \
				((j.furniture.dirty_plates > 0 and not lot.of_type("sink").is_empty()) or j.furniture.cash > 0.0)
		"collect":
			return j.furniture != null and lot.furniture.has(j.furniture) and j.furniture.cash > 0.0
		"wash":
			return j.furniture != null and j.furniture.dirty > 0 and lot.furniture.has(j.furniture)
		"sweep":
			# while open, little spills are for whoever's job is cleaning and everyone
			# else only sweeps real mess; at closing everyone mops the lot
			var dirt: float = lot.dirt[lot.idx(j.cell)]
			if dirt < Data.DIRT_JOB and priorities.get("clean", 0) != 1 and GameState.phase != GameState.Phase.CLEANUP:
				return false
			return dirt >= Data.DIRT_SHOW and lot.walkable(j.cell)
		"repair":
			return j.furniture != null and j.furniture.broken and lot.furniture.has(j.furniture) and j.furniture.user == null and GameState.can_afford(Data.REPAIR_COST)
		"service":
			return j.furniture != null and lot.furniture.has(j.furniture) and not j.furniture.broken and j.furniture.user == null \
				and j.furniture.wear >= Data.SERVICE_AT * 0.5 and GameState.can_afford(Data.SERVICE_COST)
	return false


static func needs_ice(items: Array) -> bool:
	for d in items:
		if Data.DISHES[d].get("ice", false):
			return true
	return false


func job_cell(j) -> Vector2i:
	if j.kind == "sweep":
		return j.cell
	if j.kind == "greet":
		var hs = nearest("host", lot.entry_inside)
		return hs.cell if hs != null else lot.entry_inside
	if j.kind in ["mediate", "checkin"] and Crew.valid_here(j.who):
		return j.who.current_cell()
	if j.furniture != null:
		return j.furniture.cell
	if group_ok(j.group) and j.group.table != null:
		return j.group.table.cell
	return current_cell()


func free_station(type: String):
	var best = null
	var best_d := 1 << 30
	for f in lot.of_type(type):
		if f.user == null and not f.broken:
			var d: int = lot.distance(current_cell(), f.cell)
			if d < best_d:
				best_d = d
				best = f
	return best


func nearest(type: String, near: Vector2i):
	var best = null
	var best_d := 1 << 30
	for f in lot.of_type(type):
		var d: int = lot.distance(near, f.cell)
		if d < best_d:
			best_d = d
			best = f
	return best


func pass_with_items(g):
	for f in lot.of_type("pass"):
		for it in f.items:
			if it["group"] == g:
				return f
	return null


# ------------------------------------------------------------------ steps

func start_job(j) -> void:
	JobBoard.claim(j, self)
	job = j
	reserved = {}
	steps = []
	match j.kind:
		"take_order": plan_take_order(j)
		"cook": plan_cook(j, batch_extra(j))
		"prep": plan_prep(j)
		"greet": plan_greet(j)
		"till": plan_till(j)
		"check": plan_check(j)
		"complaint": plan_complaint(j)
		"mediate": plan_mediate(j)
		"checkin": plan_checkin(j)
		"scrub": plan_scrub(j)
		"trash": plan_trash(j)
		"restock": plan_restock(j)
		"deliver": plan_deliver(j)
		"bus": plan_bus(j)
		"wash": plan_wash(j)
		"sweep": plan_sweep(j)
		"repair": plan_repair(j)
		"service": plan_service(j)
		"collect": plan_collect(j)


func go_step(cells: Array, label: String) -> Dictionary:
	return {"do": "go", "cells": cells, "label": label}


func work_step(minutes: float, label: String, cooking_work: bool, face: Vector2) -> Dictionary:
	return {"do": "work", "min": minutes, "label": label, "cook": cooking_work, "face": face}


func call_step(f: Callable) -> Dictionary:
	return {"do": "call", "f": f}


func run_steps(minutes: float) -> void:
	var guard := 0
	while job != null and not steps.is_empty() and guard < 12:
		guard += 1
		var s: Dictionary = steps[0]
		match s["do"]:
			"go":
				if not s.has("started"):
					s["started"] = true
					s["tries"] = s.get("tries", 0) + 1
					status = s["label"]
					if not go_to_any(s["cells"]):
						abort()
						return
				if is_moving():
					return
				if current_cell() in s["cells"]:
					steps.pop_front()
					continue
				if s["tries"] < 3:
					s.erase("started")
					continue
				abort()
				return
			"work":
				if not s.has("left"):
					s["left"] = s["min"]
					status = s["label"]
					if s["face"] != Vector2.ZERO:
						face_toward(s["face"])
				if s["cook"] and not Events.powered():
					status = "Waiting for the power"
					return
				status = s["label"]
				s["left"] -= minutes * work_speed(s["cook"])
				minutes = 0.0
				if s["left"] > 0.0:
					return
				steps.pop_front()
			"wait":
				if s["cond"].call():
					steps.pop_front()
					continue
				status = s["label"]
				s["waited"] = s.get("waited", 0.0) + minutes
				if s["waited"] > s.get("max", 60.0):
					abort()
				return
			"call":
				steps.pop_front()
				var ok = s["f"].call()
				if ok is bool and ok == false:
					abort()
					return
	if job != null and steps.is_empty():
		JobBoard.finish(job)
		jobs_today += 1
		job = null
		reserved = {}
		status = "Idle"
		if _toilet_first:
			start_break()


func abort() -> void:
	if reserved.has("prepped"):
		Stock.give_back_prepped(reserved["prepped"])
	if reserved.get("prep_n", 0) > 0 and job != null:
		# the ingredients were already out: call it prepped
		Stock.prepped[job.dish] = Stock.ready_portions(job.dish) + reserved["prep_n"]
	if reserved.has("station"):
		var st = reserved["station"]
		if st.user == self:
			st.user = null
			st.cooking = ""
		lot.queue_redraw()
	GameState.plates_clean += reserved.get("plate", 0)
	if reserved.get("wash", 0) > 0:
		var sink = job.furniture
		if sink != null and lot.furniture.has(sink):
			sink.dirty += reserved["wash"]
		else:
			GameState.plates_clean += reserved["wash"]
	if not carry.is_empty() and not reserved.has("plate"):
		for c in carry:
			if c == "dirty" or (not carry_bag and Data.DISHES.has(c) and Data.DISHES[c]["plate"]):
				GameState.plates_clean += 1
		carry = []
		carry_bag = false
		queue_redraw()
	for k in reserved.get("batch", []):
		JobBoard.release(k, 2.0)
	if job != null:
		JobBoard.release(job, 2.0)
	job = null
	steps = []
	reserved = {}
	path.clear()
	status = "Idle"


func drop_job() -> void:
	## Called when a staff member is let go or the day ends mid-task.
	end_phone()
	pause_left = 0.0
	if job != null:
		abort()
	if on_break:
		end_break()


# ------------------------------------------------------------------ job plans

func plan_take_order(j) -> void:
	var t = j.group.table
	var talk := 1.6 if has_trait("chatty") else 1.0
	steps = [
		go_step(lot.access_cells(t), "Going to take an order"),
		call_step(func(): return group_ok(j.group) and j.group.state == "seated"),
		work_step(1.0 * talk, "Taking an order", false, t.center_px()),
		call_step(func():
			if not group_ok(j.group):
				return false
			j.group.place_order(self)
			return true),
	]


## The host says hello at the stand by the door. Greeted customers wait longer
## for a table, and like being welcomed.
func plan_greet(j) -> void:
	var hs = nearest("host", lot.entry_inside)
	steps = [
		go_step(lot.access_cells(hs), "Going to the host stand"),
		call_step(func(): return group_ok(j.group) and j.group.state == "waiting"),
		work_step(0.3, "Greeting guests", false, j.group.members[0].position if not j.group.members.is_empty() else hs.center_px()),
		call_step(func():
			if not group_ok(j.group):
				return false
			j.group.greeted = true
			if randf() < 0.5:
				Crew.say(self, "greet", "host")
			return true),
	]


## Ringing up a bill at the till.
func plan_till(j) -> void:
	var till = j.furniture
	steps = [
		go_step(lot.access_cells(till), "Going to the till"),
		work_step(0.4, "Ringing up a bill", false, till.center_px()),
		call_step(func():
			if not group_ok(j.group) or j.group.state != "paying":
				return false
			j.group.settle()
			return true),
	]


## No till: bring the check to the table and take payment there.
func plan_check(j) -> void:
	var t = j.group.table
	steps = [
		go_step(lot.access_cells(t), "Bringing the check"),
		work_step(0.5, "Taking payment", false, t.center_px()),
		call_step(func():
			if not group_ok(j.group) or j.group.state != "paying":
				return false
			j.group.settle()
			return true),
	]


## A manager goes to talk to an unhappy table. How it goes depends on their mood.
func plan_complaint(j) -> void:
	var t = j.group.table
	steps = [
		go_step(lot.access_cells(t), "Going to an unhappy table"),
		work_step(1.0, "Listening to a complaint", false, t.center_px()),
		call_step(func():
			var g = j.group
			if not group_ok(g) or g.state != "complaining":
				return false
			if mood == "fed_up" and randf() < 0.5:
				Crew.say(self, "argue", "storm")
				add_stress(5.0)
				g.resolve_complaint("argue", self)
			elif g.complaint_what in Data.FOOD_COMPLAINTS:
				Crew.say(self, "sorry_table", "heart")
				g.resolve_complaint("comp", self)
			else:
				Crew.say(self, "sorry_table", "chat")
				g.resolve_complaint("apologise", self)
			return true),
	]


## A manager sits two people down and gets them to talk it out.
func plan_mediate(j) -> void:
	var a = j.who
	var b = j.who2
	steps = [
		go_step(lot.access_cells_near(a.current_cell()), "Going to settle an argument"),
		call_step(func():
			if not Crew.valid_here(a) or not Crew.valid_here(b):
				return false
			a.pause_left = maxf(a.pause_left, 1.5)
			b.pause_left = maxf(b.pause_left, 1.5)
			face_toward(a.position)
			Crew.say(self, "mediate", "chat")
			return true),
		work_step(1.5, "Talking it out with %s and %s" % [a.person_name, b.person_name], false, Vector2.ZERO),
		call_step(func():
			if Crew.valid_here(a) and Crew.valid_here(b):
				Crew.mediate(self, a, b)
			return true),
	]


## A manager checks on someone having a rough shift, and sends them on a break if they're worn out.
func plan_checkin(j) -> void:
	var t = j.who
	steps = [
		go_step(lot.access_cells_near(t.current_cell()), "Checking on %s" % t.person_name),
		call_step(func():
			if not Crew.valid_here(t):
				return false
			face_toward(t.position)
			return true),
		work_step(0.8, "Checking on %s" % t.person_name, false, Vector2.ZERO),
		call_step(func():
			if Crew.valid_here(t):
				Crew.check_in(self, t)
			return true),
	]


## Other tables' orders for the same station that can be cooked together
## with this one (up to Data.BATCH_MAX items). Claims them.
func batch_extra(j) -> Array:
	var out: Array = []
	var all_items: Array = j.items.duplicate()
	var plates := plates_for(j)
	for k in JobBoard.open_jobs():
		if k == j or k.kind != "cook" or k.station != j.station or not group_ok(k.group):
			continue
		if all_items.size() + k.items.size() > Data.BATCH_MAX:
			continue
		var trial: Array = all_items + k.items
		if not GameState.has_items(trial) or GameState.plates_clean < plates + plates_for(k):
			continue
		JobBoard.claim(k, self)
		out.append(k)
		all_items = trial
		plates += plates_for(k)
	return out


func plan_cook(j, extra: Array = []) -> void:
	var st = free_station(j.station)
	st.user = self
	reserved["station"] = st
	reserved["batch"] = extra
	var batch: Array = [j] + extra
	var all_items: Array = []
	for b in batch:
		all_items.append_array(b.items)
	var is_takeout: bool = group_ok(j.group) and j.group.takeout
	# prepped portions first: no trip to the fridge for those, and they cook faster
	var from_prep: Array = Stock.take_prepped(all_items)
	reserved["prepped"] = from_prep
	var raw: Array = all_items.duplicate()
	for d in from_prep:
		raw.erase(d)
	var needs_fridge := false
	var longest := 0.0
	for d in all_items:
		longest = maxf(longest, Data.DISHES[d]["minutes"])
	for d in raw:
		if not Data.DISHES[d]["needs"].is_empty():
			needs_fridge = true
	var plate_counts: Array = batch.map(func(b): return plates_for(b))
	var plated := 0
	for c in plate_counts:
		plated += c
	GameState.plates_clean -= plated
	reserved["plate"] = plated
	var n: int = all_items.size()
	var pass_counter = nearest("pass", st.cell)
	var cook_min: float = longest * (1.0 + Data.BATCH_EXTRA * (n - 1)) * (1.3 - cooking * 0.05)
	cook_min *= 1.0 - (1.0 - Data.PREP_SPEED) * from_prep.size() / float(n)
	if st.tier > 0:
		cook_min /= Data.PRO_SPEED
	var what: String = Data.DISHES[all_items[0]]["name"].to_lower() if n == 1 else "%d items" % n
	steps = []
	if needs_fridge:
		var fridge = nearest("fridge", current_cell())
		steps.append(go_step(lot.access_cells(fridge), "Getting ingredients"))
		steps.append(work_step(0.4, "Getting ingredients", false, fridge.center_px()))
		steps.append(call_step(func():
			if GameState.take_items(raw):
				return true
			GameState.toast.emit("Out of ingredients for an order. Raise the amounts in Supplies.", "bad")
			for b in batch:
				if group_ok(b.group):
					b.group.item_failed("", b.items.size())
				JobBoard.finish(b)
			reserved.erase("batch")
			release_reservations()
			job = null
			steps = []
			return true))
	# cold drinks: a scoop of ice on the way
	if needs_ice(all_items):
		var ice = nearest("ice", current_cell())
		if ice != null:
			steps.append(go_step(lot.access_cells(ice), "Getting ice"))
			steps.append(work_step(0.2, "Scooping ice", false, ice.center_px()))
	steps.append(go_step(lot.access_cells(st), "Going to the " + st.info()["name"].to_lower()))
	# nobody restocked it last night: set it up first
	if not st.stocked:
		steps.append(work_step(Data.SETUP_MINUTES, "Setting up the " + st.info()["name"].to_lower(), false, st.center_px()))
		steps.append(call_step(func():
			st.stocked = true
			return true))
	steps.append(call_step(func():
		if st.broken:
			return false
		st.cooking = all_items[0]
		lot.queue_redraw()
		return true))
	steps.append(work_step(cook_min, "Cooking " + what, true, st.center_px()))
	steps.append(call_step(func():
		st.cooking = ""
		st.user = null
		reserved.erase("station")
		GameState.today["prep_used"] += from_prep.size()
		reserved.erase("prepped")
		carry = all_items.duplicate()
		carry_bag = is_takeout
		var q := 0.3 + cooking * 0.07 + randf() * 0.1 + GameState.food_bonus()
		if stress > Data.STRESS_MISTAKES and randf() < 0.08:
			q -= 0.3
			lot.fx.add(position + Vector2(0, -18), "Burnt!", Color("ff8f7a"))
			if _burnt_day != GameState.day:
				_burnt_day = GameState.day
				Crew.log_line("%s burnt an order. Too stressed to focus." % person_name, "alert", [self])
		reserved["quality"] = clampf(q, 0.0, 1.0)
		lot.add_dirt(nearest_floor_near(st), 0.06 * mess)
		Health.add_trash(nearest_floor_near(st), Data.TRASH_PER_ITEM * n)
		wear_out(st)
		lot.queue_redraw()
		return true))
	# a server who poured the drinks takes them straight to the table
	var direct: bool = j.station == "drinks" and extra.is_empty() and priorities.get("serve", 0) > 0 and group_ok(j.group) and not j.group.takeout
	if direct:
		steps.append(call_step(func():
			if not group_ok(j.group) or j.group.table == null:
				carry = []
				return false
			steps.insert(0, go_step(lot.access_cells(j.group.table), "Bringing drinks"))
			return true))
		steps.append(work_step(0.2, "Serving drinks", false, Vector2.ZERO))
		steps.append(call_step(func():
			var qs: Array = []
			for d in all_items:
				qs.append(reserved.get("quality", 0.6))
			if group_ok(j.group):
				j.group.receive(all_items.duplicate(), qs, self, [self])
			carry = []
			reserved.erase("plate")
			queue_redraw()
			return true))
		return
	steps.append(go_step(lot.access_cells(pass_counter), "Taking food to the pass"))
	steps.append({"do": "wait", "label": "Waiting for room on the pass", "max": 90.0,
		"cond": func(): return pass_counter.pass_free_slots() >= n})
	steps.append(call_step(func():
		carry_bag = false
		for i in batch.size():
			var b = batch[i]
			if not group_ok(b.group):
				# these customers left while we were cooking: their plates go back
				GameState.plates_clean += plate_counts[i]
				continue
			var take_away: bool = b.group.takeout
			for d in b.items:
				pass_counter.items.append({"dish": d, "group": b.group, "q": reserved.get("quality", 0.6),
					"plated": not take_away and Data.DISHES[d]["plate"], "takeout": take_away, "cook": self, "t": GameState.minute})
			if not JobBoard.has_unclaimed("deliver", "group", b.group):
				JobBoard.post("serve", "deliver", {"group": b.group})
		for k in extra:
			JobBoard.finish(k)
		reserved.erase("batch")
		carry = []
		reserved.erase("plate")
		Sfx.play("bell", -8.0)
		lot.queue_redraw()
		queue_redraw()
		return true))


## Morning prep: fetch the ingredients, then chop, mix and portion at the
## prep counter. Prepped portions wait there for the cooks.
func plan_prep(j) -> void:
	var st = free_station("prep")
	st.user = self
	reserved["station"] = st
	var dish: String = j.dish
	var name_: String = Data.DISHES[dish]["name"].to_lower()
	steps = []
	if not Data.DISHES[dish]["needs"].is_empty():
		var fridge = nearest("fridge", current_cell())
		steps.append(go_step(lot.access_cells(fridge), "Getting ingredients for prep"))
		steps.append(work_step(0.4, "Getting ingredients for prep", false, fridge.center_px()))
	steps.append(call_step(func():
		var n: int = j.count
		while n > 0 and not GameState.has_raw(_repeat(dish, n)):
			n -= 1
		if n <= 0:
			return false
		GameState.take_items(_repeat(dish, n))
		reserved["prep_n"] = n
		return true))
	steps.append(go_step(lot.access_cells(st), "Going to the prep counter"))
	steps.append(call_step(func():
		st.cooking = dish
		lot.queue_redraw()
		steps.insert(0, work_step(reserved.get("prep_n", 0) * Data.PREP_MINUTES_EACH * (1.3 - cooking * 0.05), "Prepping %s" % name_, true, st.center_px()))
		return true))
	steps.append(call_step(func():
		var n: int = reserved.get("prep_n", 0)
		Stock.prepped[dish] = Stock.ready_portions(dish) + n
		GameState.today["prepped"] += n
		Health.add_trash(nearest_floor_near(st), Data.TRASH_PER_PREP * n)
		reserved.erase("prep_n")
		st.cooking = ""
		st.user = null
		reserved.erase("station")
		lot.add_dirt(nearest_floor_near(st), 0.04 * mess)
		lot.queue_redraw()
		return true))


## Food quality after waiting on the pass this many minutes.
static func cooled(q: float, age: float) -> float:
	if age > Data.PASS_HOT:
		q -= minf(0.35, (age - Data.PASS_HOT) * Data.PASS_COOL_PER_MIN)
	return maxf(0.0, q)


static func _repeat(d: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(d)
	return out


## After the restroom or the trash: go and wash up at a hand sink (or don't).
func wash_up() -> Dictionary:
	return call_step(func():
		dirty_hands = true
		if Health.will_wash(self):
			var hs = nearest("handsink", current_cell())
			if hs != null:
				steps.insert(0, call_step(func():
					dirty_hands = false
					return true))
				steps.insert(0, work_step(Data.HANDWASH_MINUTES, "Washing hands", false, hs.center_px()))
				steps.insert(0, go_step(lot.access_cells(hs), "Going to wash hands"))
		return true)


## A quick trip to the restroom before a break. Not on the job board: it's personal.
func restroom_visit(t) -> void:
	drop_job()
	var pj = JobClass.new()
	pj.type = "clean"
	pj.kind = "restroom"
	pj.furniture = t
	job = pj
	reserved = {}
	steps = [
		go_step([t.cell], "Going to the restroom"),
		{"do": "wait", "label": "Waiting for the restroom", "max": 4.0,
			"cond": func(): return t.occupant == null or t.occupant == self or not is_instance_valid(t.occupant)},
		call_step(func():
			t.occupant = self
			return true),
		work_step(1.5, "In the restroom", false, Vector2.ZERO),
		call_step(func():
			if t.occupant == self:
				t.occupant = null
			Health.used_toilet(t)
			return true),
		wash_up(),
	]


## Closing duty: top up a station for tomorrow.
func plan_restock(j) -> void:
	var st = j.furniture
	steps = [
		go_step(lot.access_cells(st), "Going to restock the " + st.info()["name"].to_lower()),
		work_step(0.5, "Restocking the " + st.info()["name"].to_lower(), false, st.center_px()),
		call_step(func():
			if not lot.furniture.has(st):
				return false
			st.stocked = true
			GameState.today["restocked"] = GameState.today.get("restocked", 0) + 1
			return true),
	]


func plan_scrub(j) -> void:
	var t = j.furniture
	steps = [
		go_step(lot.access_cells(t), "Going to clean the restroom"),
		work_step(1.2, "Scrubbing the restroom", false, t.center_px()),
		call_step(func():
			if not lot.furniture.has(t):
				return false
			t.grime = 0.0
			lot.queue_redraw()
			return true),
		wash_up(),
	]


## Bag the trash and take it out: to the dumpster, or out the front door.
func plan_trash(j) -> void:
	var bin = j.furniture
	steps = [
		go_step(lot.access_cells(bin), "Going to the trash"),
		work_step(0.4, "Bagging the trash", false, bin.center_px()),
		call_step(func():
			if not lot.furniture.has(bin):
				return false
			bin.fill = 0.0
			lot.queue_redraw()
			var spot: Array = Health.trash_spot()
			if spot.is_empty():
				return true
			carry = ["trash"]
			queue_redraw()
			steps.insert(0, go_step(spot, "Taking out the trash"))
			return true),
		work_step(0.2, "Dumping the trash", false, Vector2.ZERO),
		call_step(func():
			carry = []
			queue_redraw()
			GameState.today["trash_runs"] += 1
			return true),
		wash_up(),
	]


## Every batch wears a station a little. Worn stations sometimes break.
func wear_out(st) -> void:
	st.wear = minf(1.0, st.wear + randf_range(Data.WEAR_PER_COOK.x, Data.WEAR_PER_COOK.y) * (Data.PRO_WEAR if st.tier > 0 else 1.0))
	if randf() < st.wear * st.wear * Data.BREAK_CHANCE:
		st.broken = true
		st.broke_by = self
		GameState.today["breakdowns"] += 1
		GameState.toast.emit("The %s broke down! Someone with Repair on will fix it ($%d in parts)." % [st.info()["name"].to_lower(), int(Data.REPAIR_COST)], "bad")
		Sfx.play("error")
		if not JobBoard.has_open("repair", "furniture", st):
			JobBoard.post("fix", "repair", {"furniture": st})


func release_reservations() -> void:
	if reserved.has("prepped"):
		Stock.give_back_prepped(reserved["prepped"])
	if reserved.has("station"):
		var st = reserved["station"]
		if st.user == self:
			st.user = null
			st.cooking = ""
	GameState.plates_clean += reserved.get("plate", 0)
	reserved = {}
	lot.queue_redraw()


func nearest_floor_near(f) -> Vector2i:
	var cells: Array = lot.access_cells(f)
	return cells[0] if not cells.is_empty() else f.cell


func plan_deliver(j) -> void:
	var pc = pass_with_items(j.group)
	steps = [
		go_step(lot.access_cells(pc), "Picking up food"),
		call_step(func():
			if not group_ok(j.group):
				return false
			var mine: Array = []
			var qualities: Array = []
			var cooks: Array = []
			for it in pc.items.duplicate():
				if it["group"] == j.group and mine.size() < 4:
					mine.append(it["dish"])
					# food left waiting on the pass goes cold
					var age: float = GameState.minute - it.get("t", GameState.minute)
					if age > Data.PASS_COLD and not j.group.takeout:
						j.group.extra_hits["cold food"] = 0.2
						GameState.today["cold_plates"] += 1
					qualities.append(cooled(it["q"], age))
					if it.get("cook") != null and not cooks.has(it["cook"]):
						cooks.append(it["cook"])
					pc.items.erase(it)
			reserved["cooks"] = cooks
			if mine.is_empty():
				return false
			carry = mine
			carry_bag = j.group.takeout
			reserved["q"] = qualities
			if pass_with_items(j.group) != null and not JobBoard.has_unclaimed("deliver", "group", j.group):
				JobBoard.post("serve", "deliver", {"group": j.group})
			lot.queue_redraw()
			queue_redraw()
			return true),
		call_step(func():
			if not group_ok(j.group) or j.group.table == null:
				return false
			var label := "Handing over takeout" if j.group.takeout else "Serving food"
			steps.insert(0, go_step(lot.access_cells(j.group.table), label))
			return true),
		work_step(0.3, "Serving food", false, Vector2.ZERO),
		call_step(func():
			if not group_ok(j.group):
				return false
			j.group.receive(carry.duplicate(), reserved.get("q", []), self, reserved.get("cooks", []))
			carry = []
			carry_bag = false
			queue_redraw()
			return true),
	]


## A table left the money for the bill on it: go and pick it up.
func plan_collect(j) -> void:
	var t = j.furniture
	steps = [
		go_step(lot.access_cells(t), "Picking up a check"),
		work_step(0.25, "Picking up a check", false, t.center_px()),
		call_step(func(): return Books.collect_table(t, self)),
	]


func plan_bus(j) -> void:
	var t = j.furniture
	steps = [
		go_step(lot.access_cells(t), "Going to clear a table"),
		work_step(0.8, "Clearing a table", false, t.center_px()),
		call_step(func():
			# any money left on the table goes in the till on the way
			var got: bool = Books.collect_table(t, self)
			var n: int = t.dirty_plates
			if n <= 0:
				if got:
					steps.clear()
				return got
			t.dirty_plates = 0
			carry = []
			for i in n:
				carry.append("dirty")
			lot.queue_redraw()
			queue_redraw()
			return true),
		call_step(func():
			var sink = nearest("sink", current_cell())
			if sink == null:
				return false
			reserved["sink"] = sink
			steps.insert(0, go_step(lot.access_cells(sink), "Taking dishes to the sink"))
			return true),
		work_step(0.3, "Dropping off dishes", false, Vector2.ZERO),
		call_step(func():
			var sink = reserved.get("sink")
			if sink == null or not lot.furniture.has(sink):
				return false
			sink.dirty += carry.size()
			Health.add_trash(sink.cell, Data.TRASH_PER_PLATE * carry.size())
			carry = []
			if not JobBoard.has_open("wash", "furniture", sink):
				JobBoard.post("wash", "wash", {"furniture": sink})
			lot.queue_redraw()
			queue_redraw()
			return true),
	]


func plan_wash(j) -> void:
	var sink = j.furniture
	var n: int = mini(sink.dirty, 6)
	sink.dirty -= n
	reserved["wash"] = n
	lot.queue_redraw()
	steps = [
		go_step(lot.access_cells(sink), "Going to the sink"),
		work_step(0.5 * n, "Washing dishes", false, sink.center_px()),
		call_step(func():
			var back := n
			var clumsy_drop := has_trait("clumsy") and randf() < 0.08
			var stressed_drop := not clumsy_drop and stress > Data.STRESS_MISTAKES and randf() < 0.05
			if clumsy_drop or stressed_drop:
				back -= 1
				GameState.plates_total -= 1
				GameState.toast.emit("%s dropped a plate. Crash! (%s)" % [person_name, "Clumsy" if clumsy_drop else "stressed"], "")
				Sfx.play("plate_break", -4.0)
				Crew.plate_dropped(self)
			GameState.plates_clean += back
			reserved.erase("wash")
			if sink.dirty > 0 and not JobBoard.has_open("wash", "furniture", sink):
				JobBoard.post("wash", "wash", {"furniture": sink})
			return true),
	]


func plan_sweep(j) -> void:
	var radius := 2 if has_trait("tidy") else 1
	steps = [
		go_step([j.cell], "Going to sweep"),
		work_step(0.7, "Sweeping", false, Vector2.ZERO),
		call_step(func():
			lot.clean_cell(j.cell, radius)
			Sfx.play("sweep", -14.0)
			return true),
	]


## Closing duty: service a worn station (clean it, tighten it, swap a part) so it doesn't break.
func plan_service(j) -> void:
	var st = j.furniture
	st.user = self
	reserved["station"] = st
	var what: String = st.info()["name"].to_lower()
	steps = [
		go_step(lot.access_cells(st), "Going to service the " + what),
		work_step(Data.SERVICE_MINUTES, "Servicing the " + what, false, st.center_px()),
		call_step(func():
			if not lot.furniture.has(st) or not GameState.spend(Data.SERVICE_COST):
				return false
			st.wear = minf(st.wear, 0.05)
			st.user = null
			reserved.erase("station")
			GameState.today["serviced"] = GameState.today.get("serviced", 0) + 1
			lot.queue_redraw()
			return true),
	]


func plan_repair(j) -> void:
	var st = j.furniture
	st.user = self
	reserved["station"] = st
	steps = [
		go_step(lot.access_cells(st), "Going to fix the " + st.info()["name"].to_lower()),
		work_step(6.0, "Repairing the " + st.info()["name"].to_lower(), false, st.center_px()),
		call_step(func():
			if not GameState.spend(Data.REPAIR_COST):
				return false
			st.broken = false
			st.wear = 0.0
			st.user = null
			reserved.erase("station")
			Crew.fixed(self, st.broke_by, st.info()["name"].to_lower())
			st.broke_by = null
			GameState.toast.emit("%s fixed the %s." % [person_name, st.info()["name"].to_lower()], "good")
			Sfx.play("repair", -4.0)
			lot.queue_redraw()
			return true),
	]
