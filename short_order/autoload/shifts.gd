extends Node
## Who works when, and the everyday ups and downs of a crew:
##   - shifts: Opening (in for prep, home 8 hours later), Closing (in for the
##     second half, stays to close up) or a Double (all day, with overtime)
##   - pay by the hour: a wage is for an 8-hour shift, anything past that is
##     time and a half, and anyone who comes in gets at least 4 hours
##   - lateness and no-shows, rolled each morning
##   - sick days: a call in the morning, and colds that spread
##   - training: a new hire paired with someone better learns faster
##   - closing duties: restocking stations and taking out the trash at night;
##     whoever closes late starts the next day tired
## staff.gd does the walking in and out; this decides when.

var main                               # set by main.gd
var today := {}                        # lines for the report
var no_surprises := false              # tests: nobody's late, skips a shift or falls ill
var force_late := {}                   # tests: staff id -> minutes late tomorrow morning
var force_no_show := {}                # tests: staff id -> true: they skip tomorrow's shift


func _ready() -> void:
	reset_today()


func reset_today() -> void:
	today = {"late": [], "no_show": [], "sick_home": [], "sick_in": [], "clopen": [], "overtime": 0.0, "trained": [], "trained_done": []}


# ------------------------------------------------------------------ shift times

## When this person's shift starts today.
func shift_start(s) -> float:
	var start: float = GameState.prep_min()
	if s.shift == "close":
		var close_end: float = GameState.close_min() + Data.CLOSE_EXTRA
		return maxf(start, snappedf(close_end - Data.SHIFT_HOURS * 60.0, 15.0))
	return start


## When they go home, or -1 if they stay until everything's closed up.
func shift_end(s) -> float:
	if s.shift == "open":
		var end: float = GameState.prep_min() + Data.SHIFT_HOURS * 60.0
		# a short day: an opener is there all day anyway
		if end >= GameState.close_min():
			return -1.0
		return end
	return -1.0


## "09:00–17:00", "15:00 to close"
func hours_text(s) -> String:
	var a := DayTimeline.clock(shift_start(s))
	var e := shift_end(s)
	return "%s–%s" % [a, DayTimeline.clock(e)] if e >= 0.0 else "%s–close" % a


# ------------------------------------------------------------------ the morning

## When the day starts: who's coming in, when, and in what state.
func morning() -> void:
	reset_today()
	for s in GameState.staff:
		s.came_at = -1.0
		s.left_at = -1.0
		s.clock_out = false
		s.heading_home = false
		s.arriving = false
		s.late_by = 0.0
		s.no_show = false
		s.exposure = 0.0
		s.sick_at_work = false
		s.train_today = 0.0
		s._training = false
		# tired from closing last night, and worse if they're opening now
		var start := shift_start(s)
		s.energy = 100.0
		if s.closed_late:
			s.energy = Data.CLOSED_LATE_ENERGY
			if start <= GameState.prep_min() and not s.away and s.sick_days <= 0:
				s.energy = Data.CLOPEN_ENERGY
				s.add_stress(Data.CLOPEN_STRESS)
				today["clopen"].append(s.person_name)
				Crew.log_line("%s closed last night and is opening this morning. Running on empty." % s.person_name, "energy", [s])
		s.closed_late = false
		if s.away:
			s.set_at_work(false)
			continue
		if s.sick_days > 0:
			# they call in sick; you decide
			s.set_at_work(false)
			s.arrive_at = -1.0
			ask_sick(s)
			continue
		# no-shows and lateness
		var skip := false
		var late := 0.0
		if not no_surprises and GameState.day >= 2:
			var p_no: float = Data.NO_SHOW_CHANCE + (0.02 if s.mood == "fed_up" else 0.0) + (0.04 if s.burnout_warned else 0.0) + 0.01 * s.warnings
			skip = randf() < p_no
			var p_late: float = Data.LATE_CHANCE + (0.06 if s.mood == "fed_up" else 0.0) + (0.05 if s.energy < Data.CLOSED_LATE_ENERGY else 0.0) + (0.03 if s.has_trait("slow") else 0.0)
			if randf() < p_late:
				late = float(randi_range(Data.LATE_MINUTES.x, Data.LATE_MINUTES.y))
		if force_no_show.has(s.id):
			skip = true
			force_no_show.erase(s.id)
		if force_late.has(s.id):
			late = float(force_late[s.id])
			force_late.erase(s.id)
		if skip:
			s.no_show = true
			s.warnings += 1
			s.set_at_work(false)
			today["no_show"].append(s.person_name)
			Crew.log_line("%s didn't show up for their shift, and didn't call." % s.person_name, "walkout", [s])
			GameState.toast.emit("%s didn't show up and didn't call. That's a warning." % s.person_name, "bad")
			continue
		s.late_by = late
		s.arrive_at = start + s.late_by
		if s.arrive_at <= GameState.prep_min():
			s.set_at_work(true)
			s.came_at = GameState.prep_min()
		else:
			s.set_at_work(false)
		if s.late_by > 0.0:
			today["late"].append([s.person_name, int(s.late_by)])
			GameState.toast.emit("%s is running %d minutes late." % [s.person_name, int(s.late_by)], "")
	warn_gaps()


## A quick heads-up if a shift has nobody to cook or serve.
func warn_gaps() -> void:
	for half in ["open", "close"]:
		var cook := false
		var serve := false
		var anyone := false
		for s in GameState.staff:
			if s.away or s.no_show or s.sick_days > 0:
				continue
			if s.shift != half and s.shift != "double":
				continue
			anyone = true
			if s.priorities.get("cook", 0) > 0:
				cook = true
			if s.priorities.get("serve", 0) > 0:
				serve = true
		var when: String = "the opening shift" if half == "open" else "the closing shift"
		if not anyone:
			GameState.toast.emit("Nobody's on %s today!" % when, "bad")
		elif not cook or not serve:
			GameState.toast.emit("Nobody on %s can %s." % [when, "cook" if not cook else "serve"], "bad")


func ask_sick(s) -> void:
	var what: String = ["a fever and a sore throat", "a stomach bug", "a streaming cold", "a pounding headache and chills"].pick_random()
	Events.ask_player("sick", "%s called in sick" % s.person_name,
		"%s calls before the shift: %s. They sound awful." % [s.person_name, what],
		[{"label": "Stay home and rest", "desc": "They're off today, unpaid, and back once they're better."},
		{"label": "Ask them to come in anyway", "desc": "They'll be slow and miserable, the inspector won't like it, and it can spread."}], {"s": s})


## Your answer to a sick call (Events calls this).
func sick_choice(s, come_in: bool) -> void:
	if not is_instance_valid(s) or not GameState.staff.has(s):
		return
	if come_in:
		s.sick_at_work = true
		s.add_stress(15.0)
		s.arrive_at = maxf(GameState.minute, shift_start(s)) + 20.0
		today["sick_in"].append(s.person_name)
		Crew.log_line("%s came in sick." % s.person_name, "sick", [s])
	else:
		s.away = true
		today["sick_home"].append(s.person_name)
		Crew.log_line("%s is off sick." % s.person_name, "sick", [s])
	GameState.staff_changed.emit()


# ------------------------------------------------------------------ during the day

func tick(minutes: float) -> void:
	if main == null or not GameState.is_active():
		return
	var now := GameState.minute
	for s in GameState.staff:
		if not is_instance_valid(s) or s.away or s.no_show:
			continue
		# someone due in walks in from the street
		if not s.at_work and s.came_at < 0.0 and s.arrive_at >= 0.0 and now >= s.arrive_at and GameState.phase != GameState.Phase.CLEANUP:
			arrive(s)
			continue
		if not s.at_work:
			continue
		# an opener's shift is over: they finish what they're doing and go home
		var end := shift_end(s)
		if end >= 0.0 and now >= end and not s.clock_out:
			s.clock_out = true
		# a long day gets harder after 10 hours
		if s.came_at >= 0.0 and now - s.came_at > 600.0:
			s.add_stress(Data.LONG_DAY_STRESS * minutes)
		# sick people spread it to whoever's close
		if s.sick_at_work:
			for o in Crew.present():
				if o != s and Crew.tile_dist(o, s) <= 3.0:
					o.exposure += minutes
	# training: a trainee near their trainer learns faster; the trainer slows a little
	for s in GameState.staff:
		s._training = false
	for s in Crew.present():
		var tr = trainer_near(s)
		if tr != null:
			tr._training = true
			s.train_today += minutes


func arrive(s) -> void:
	var lot = main.lot
	var from: Vector2i = lot.spawn_cells().pick_random()
	s.set_at_work(true)
	s.came_at = GameState.minute
	s.place_at(from)
	s.arriving = true
	var goal: Vector2i = lot.entry_inside if lot.has_entry() else lot.nearest_walkable(Vector2i(lot.W / 2, lot.H / 2))
	if not s.go_to(goal):
		s.place_at(goal)
		s.arriving = false
	if s.late_by > 0.0:
		Crew.log_line("%s turned up %d minutes late." % [s.person_name, int(s.late_by)], "clock", [s])
		for o in Crew.present():
			if o != s and s.late_by > 20.0:
				Crew.add(o, s, "late")


## They've walked off the lot: off the clock.
func left_work(s) -> void:
	s.heading_home = false
	s.clock_out = false
	s.left_at = GameState.minute
	s.set_at_work(false)


## The trainer beside this trainee right now, if they're both working close together.
func trainer_near(s):
	if s.trainer_id <= 0 or not s.is_working():
		return null
	var tr = Crew.by_id(s.trainer_id)
	if tr == null or not tr.is_here() or not tr.is_working():
		return null
	if Crew.tile_dist(s, tr) > Data.TRAIN_TILES:
		return null
	if main.lot.floor_at(s.current_cell()) != main.lot.floor_at(tr.current_cell()):
		return null
	return tr


## Who could train this person: anyone at least 2 points better at cooking or serving.
func possible_trainers(s) -> Array:
	return GameState.staff.filter(func(o): return o != s and is_instance_valid(o) and \
		(o.cooking >= s.cooking + 2 or o.service >= s.service + 2))


func set_trainer(s, tr) -> void:
	if tr == null:
		if s.trainer_id > 0:
			Crew.log_line("%s stopped training." % s.person_name, "school", [s])
		s.trainer_id = 0
		s.training_days = 0
	else:
		s.trainer_id = tr.id
		s.training_days = 0
		Crew.log_line("%s is training %s." % [tr.person_name, s.person_name], "school", [tr, s])
		GameState.toast.emit("%s is training %s. Give them the same shift and jobs so they work side by side." % [tr.person_name, s.person_name], "good")
	GameState.staff_changed.emit()


# ------------------------------------------------------------------ closing up

## The doors are shut: restock the stations and take out every bin.
func closing() -> void:
	if main == null:
		return
	for f in main.lot.furniture:
		if f.is_station():
			f.stocked = false
			if not JobBoard.has_open("restock", "furniture", f):
				JobBoard.post("cook", "restock", {"furniture": f})
		elif f.type == "bin" and f.fill > 0.05 and not JobBoard.has_open("trash", "furniture", f):
			JobBoard.post("clean", "trash", {"furniture": f})


## Closing jobs still waiting that someone here can do.
func closing_left() -> bool:
	var here: Array = Crew.present()
	for j in JobBoard.jobs:
		if j.done or not j.kind in ["restock", "trash"]:
			continue
		if j.claimed_by != null:
			return true
		for s in here:
			if s.job_priority(j) > 0 and s.can_take(j):
				return true
	return false


# ------------------------------------------------------------------ the night

## Hours worked today, and what that pays (with overtime).
func hours_today(s) -> float:
	if s.came_at < 0.0:
		return 0.0
	var out: float = s.left_at if s.left_at >= 0.0 else GameState.minute
	return maxf(0.0, (out - s.came_at) / 60.0)


func pay_today(s) -> float:
	var h := hours_today(s)
	if h <= 0.0:
		return 0.0
	h = maxf(h, Data.MIN_PAID_HOURS)
	var rate: float = s.wage / Data.SHIFT_HOURS
	return rate * (minf(h, Data.SHIFT_HOURS) + Data.OVERTIME * maxf(0.0, h - Data.SHIFT_HOURS))


## Everyone goes home. Late closers are tired tomorrow; colds spread; training
## moves on; no-shows are remembered.
func night() -> void:
	var now := GameState.minute
	for s in GameState.staff:
		if not is_instance_valid(s):
			continue
		if s.at_work and s.left_at < 0.0:
			s.left_at = now
		if s.came_at >= 0.0 and s.left_at > GameState.close_min() + 30.0:
			s.closed_late = true
		today["overtime"] += maxf(0.0, hours_today(s) - Data.SHIFT_HOURS)
		# sick days count down at home; working through it doesn't help
		if s.sick_days > 0 and s.away and not s.sick_at_work:
			s.sick_days -= 1
			if s.sick_days <= 0:
				Crew.log_line("%s is feeling better." % s.person_name, "sick", [s])
		# catching a cold
		elif s.sick_days <= 0 and not no_surprises:
			var p := Data.SICK_CHANCE
			if s.stress > 70.0:
				p += 0.02
			if s.burnout_warned:
				p += 0.03
			p += minf(0.3, s.exposure / 60.0 * Data.SICK_SPREAD)
			if randf() < p:
				s.sick_days = randi_range(Data.SICK_DAYS.x, Data.SICK_DAYS.y)
		# the day off from a sick call is over
		if s.sick_at_work:
			s.sick_at_work = false
		# training
		if s.trainer_id > 0:
			var tr = Crew.by_id(s.trainer_id)
			if tr == null:
				s.trainer_id = 0
				continue
			if s.train_today >= 30.0:
				s.training_days += 1
				today["trained"].append("%s with %s" % [s.person_name, tr.person_name])
			var caught_up: bool = s.cooking >= tr.cooking - 1 and s.service >= tr.service - 1
			if caught_up or s.training_days >= Data.TRAIN_DAYS:
				today["trained_done"].append("%s with %s" % [s.person_name, tr.person_name])
				Crew.log_line("%s finished training with %s." % [s.person_name, tr.person_name], "school", [s, tr])
				s.trainer_id = 0
				s.training_days = 0
	# a no-show left everyone else short
	for n in today["no_show"]:
		var who = null
		for s in GameState.staff:
			if s.person_name == n:
				who = s
		if who == null:
			continue
		for o in GameState.staff:
			if o != who and o.came_at >= 0.0:
				Crew.add(o, who, "noshow")


## Lines for the report: [icon, colour, text].
func report_lines() -> Array:
	var out: Array = []
	for n in today["no_show"]:
		out.append(["walkout", "#e75a4e", "[b]%s[/b] didn't show up, and got a warning." % n])
	for l in today["late"]:
		out.append(["clock", "#f2c14e", "%s was %d minutes late." % [l[0], l[1]]])
	for n in today["sick_home"]:
		out.append(["sick", "#6aa6d9", "%s was off sick." % n])
	for n in today["sick_in"]:
		out.append(["sick", "#e75a4e", "%s worked sick. Colds spread to people nearby." % n])
	for n in today["clopen"]:
		out.append(["energy", "#f2c14e", "%s closed last night and opened today, and started out tired." % n])
	if today["overtime"] >= 0.5:
		out.append(["money", "#f2c14e", "%d hours of overtime today, paid at time and a half. Opening and closing shifts instead of doubles would save most of it." % int(round(today["overtime"]))])
	for t in today["trained_done"]:
		out.append(["school", "#6cc3a0", "[b]%s[/b] finished training." % t])
	return out
