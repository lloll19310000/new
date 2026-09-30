extends Node
## Things that happen during the day.
##
## From day 2 there are one or two events a day at random times while you're
## open. Some just happen (a festival, a grease fire); others pause the game
## and ask you to choose (a tour bus: welcome them or not?). Some days are
## rainy, which changes the whole day.
##
## Each event has up to three functions here: can_<id>() says whether it can
## happen right now, start_<id>() sets it up (and may ask you something), and
## choose_<id>() applies your answer. The numbers live in Data.EVENTS.

signal ask(ev: Dictionary)         # the HUD shows the choice card
signal answered

var main                            # set by main.gd
var schedule: Array = []            # game minutes when today's events happen
var current: Dictionary = {}        # the event waiting for your answer
var auto_choice := -1               # tests: -1 = ask you, 0+ = always that option, -2 = at random
var forced := ""                    # tests: this event happens next
var raining := false
var power_off_until := -1.0         # game minute the power comes back, or -1
var festival_from := -1.0
var buzz_until_day := 0             # a celebrity loved it: more customers until this day
var spawns: Array = []              # customers on their way: [{"at", "kind"}]
var today: Array = []               # [icon, colour, text] lines for the day's report
var calm := {}                      # rival pairs told to cool off today
var queue: Array = []               # questions waiting their turn (two people calling in sick...)


func reset() -> void:
	buzz_until_day = 0
	reset_day()


func reset_day() -> void:
	schedule = []
	current = {}
	queue = []
	raining = false
	power_off_until = -1.0
	festival_from = -1.0
	spawns = []
	today = []
	calm = {}


func crowd_mult() -> float:
	var m := 1.0
	if raining:
		m *= Data.RAIN_CROWD
	if festival_from >= 0.0 and GameState.minute >= festival_from:
		m *= Data.FESTIVAL_CROWD
	if GameState.day <= buzz_until_day:
		m *= Data.BUZZ_CROWD
	return m


func takeout_mult() -> float:
	return 2.0 if raining else 1.0


func powered() -> bool:
	return power_off_until < 0.0 or GameState.minute >= power_off_until


## Called when the diner opens: is it raining, and when will things happen?
func plan_day() -> void:
	reset_day()
	if GameState.day < 2:
		return
	raining = randf() < Data.RAIN_CHANCE
	if raining:
		GameState.toast.emit("It's raining today: fewer people walk in, but more order takeout.", "")
		note("info", "#6aa6d9", "A rainy day: fewer walk-ins, more takeout.")
	var n := randi_range(Data.EVENTS_PER_DAY.x, Data.EVENTS_PER_DAY.y)
	var from := GameState.open_min() + 30.0
	var to := maxf(from + 60.0, GameState.close_min() - 120.0)
	for i in n:
		schedule.append(randf_range(from, to))
	schedule.sort()
	for i in range(1, schedule.size()):
		schedule[i] = maxf(schedule[i], schedule[i - 1] + 90.0)


func tick(_minutes: float) -> void:
	if GameState.phase != GameState.Phase.SERVICE or main == null:
		return
	for sp in spawns.duplicate():
		if GameState.minute >= sp["at"]:
			spawns.erase(sp)
			if GameState.minute < Data.LAST_SEAT_MIN:
				main.spawn_group(sp["kind"], -1)
	if power_off_until >= 0.0 and GameState.minute >= power_off_until:
		power_off_until = -1.0
		GameState.toast.emit("The power's back on.", "good")
		Sfx.play("repair", -4.0)
	if not current.is_empty():
		return
	if forced != "":
		var id := forced
		forced = ""
		fire(id)
		return
	if not schedule.is_empty() and GameState.minute >= schedule[0]:
		schedule.pop_front()
		fire(pick())


func pick() -> String:
	var options: Array = []
	var total := 0.0
	for id in Data.EVENTS:
		var e: Dictionary = Data.EVENTS[id]
		if e["weight"] <= 0.0 or GameState.day < e["min_day"] or not call("can_" + id):
			continue
		options.append(id)
		total += e["weight"]
	var roll := randf() * total
	for id in options:
		roll -= Data.EVENTS[id]["weight"]
		if roll <= 0.0:
			return id
	return ""


func fire(id: String) -> void:
	if id == "" or not has_method("start_" + id) or not call("can_" + id):
		return
	call("start_" + id)


## Pauses the game and asks you to choose. options: [{"label", "desc"}].
## If you're already being asked something, it waits its turn.
func ask_player(id: String, title: String, text: String, options: Array, data: Dictionary = {}) -> void:
	var ev := {"id": id, "title": title, "text": text, "options": options, "data": data}
	if auto_choice == -1:
		if not current.is_empty():
			queue.append(ev)
			return
		current = ev
		Sfx.play("critic", -4.0)
		ask.emit(current)
	else:
		current = ev
		choose(auto_choice if auto_choice >= 0 else randi() % options.size())


func choose(i: int) -> void:
	if current.is_empty():
		return
	var ev := current
	current = {}
	call("choose_" + ev["id"], clampi(i, 0, ev["options"].size() - 1), ev["data"])
	answered.emit()
	if current.is_empty() and not queue.is_empty():
		current = queue.pop_front()
		ask.emit(current)


func note(icon: String, color: String, text: String) -> void:
	today.append([icon, color, text])


func valid_group(g) -> bool:
	return g != null and is_instance_valid(g) and not g.state in ["leaving", "gone"]


func valid_staff(s) -> bool:
	return s != null and is_instance_valid(s) and GameState.staff.has(s)


# ------------------------------------------------------------------ tour bus

func can_tour_bus() -> bool:
	return GameState.minute < GameState.close_min() - 150.0 and not main.lot.tables().is_empty()


func start_tour_bus() -> void:
	var n := randi_range(Data.TOUR_BUS_GROUPS.x, Data.TOUR_BUS_GROUPS.y)
	ask_player("tour_bus", "Tour bus!",
		"A tour bus driver calls ahead: about %d hungry tourists will be here in 20 minutes. Tourists tip well, but can your kitchen keep up?" % (n * 3),
		[{"label": "Welcome them", "desc": "%d groups arrive over half an hour." % n},
		{"label": "Tell them you're full", "desc": "They'll find somewhere else to eat."}], {"n": n})


func choose_tour_bus(i: int, d: Dictionary) -> void:
	if i == 0:
		for k in d["n"]:
			spawns.append({"at": GameState.minute + 20.0 + k * 30.0 / d["n"], "kind": "tourist"})
		GameState.toast.emit("The tour bus is on its way!", "rush")
		note("people", "#6cc3a0", "A tour bus brought %d groups of tourists." % d["n"])
	else:
		note("people", "#b9a797", "You turned a tour bus away.")


# ------------------------------------------------------------------ power cut

func can_power_cut() -> bool:
	return GameState.minute < GameState.close_min() - 90.0 and powered()


func start_power_cut() -> void:
	power_off_until = GameState.minute + 600.0
	Sfx.play("error")
	ask_player("power_cut", "Power cut!",
		"The lights flicker and die. Nothing in the kitchen works until the power's back.",
		[{"label": "Call an electrician ($%d)" % int(Data.ELECTRICIAN_COST), "desc": "Back on in about 10 minutes."},
		{"label": "Wait it out", "desc": "It usually comes back within the hour."}])


func choose_power_cut(i: int, _d: Dictionary) -> void:
	if i == 0 and GameState.spend(Data.ELECTRICIAN_COST):
		power_off_until = GameState.minute + 10.0
		note("energy", "#f2c14e", "The power went out. An electrician had it back in 10 minutes ($%d)." % int(Data.ELECTRICIAN_COST))
	else:
		power_off_until = GameState.minute + randf_range(35.0, 50.0)
		note("energy", "#e75a4e", "The power went out for about 40 minutes.")


# ------------------------------------------------------------------ rowdy table

func rowdy_group():
	var best = null
	for g in main.groups:
		if not valid_group(g) or g.takeout or g.table == null or not g.state in ["seated", "ordered", "eating"]:
			continue
		if g.kind in ["critic", "inspector", "celebrity"] or g.members.size() < 2:
			continue
		if g.kind == "student":
			return g
		if best == null:
			best = g
	return best


func can_rowdy() -> bool:
	return rowdy_group() != null


func start_rowdy() -> void:
	var g = rowdy_group()
	var who := "A table of students" if g.kind == "student" else ("A family" if g.kind == "family" else "A group at one of your tables")
	ask_player("rowdy", "Rowdy table",
		"%s is getting loud and throwing fries. The other customers are staring." % who,
		[{"label": "Ask them to leave", "desc": "They won't pay, but the room calms down."},
		{"label": "Let it slide", "desc": "They'll make a mess, and nearby tables will grumble."}], {"g": g})


func choose_rowdy(i: int, d: Dictionary) -> void:
	var g = d["g"]
	if not valid_group(g):
		return
	if i == 0:
		g.kicked_out()
		note("walkout", "#f2c14e", "You asked a rowdy table to leave.")
		return
	var c: Vector2i = g.table.cell
	for y in range(-2, 3):
		for x in range(-2, 3):
			if main.lot.in_lot(c + Vector2i(x, y)):
				main.lot.add_dirt(c + Vector2i(x, y), randf_range(0.1, 0.35))
	for o in Crew.groups_near(g.table.center_px(), 5.0):
		if o != g:
			o.note_trouble("rowdy customers", 0.3)
	note("walkout", "#e75a4e", "A rowdy table made a mess, and their neighbours weren't happy.")


# ------------------------------------------------------------------ celebrity

const CELEBRITIES := ["a famous TV chef", "a movie star", "a pro wrestler", "a pop singer", "a radio host", "an Olympic swimmer"]


func can_celebrity() -> bool:
	return GameState.minute < GameState.close_min() - 150.0 and not main.lot.tables().is_empty()


func start_celebrity() -> void:
	var who: String = CELEBRITIES.pick_random()
	main.spawn_group("celebrity", -1)
	GameState.toast.emit("Word is %s just walked in! Their review counts three times, and a great one gets people talking." % who, "critic")
	Sfx.play("critic", -2.0)
	note("star", "#f2c14e", "%s came to eat." % (who.substr(0, 1).to_upper() + who.substr(1)))


## Called by the celebrity's group when they leave.
func celebrity_review(score: float) -> void:
	if score >= 4.5:
		buzz_until_day = GameState.day + Data.BUZZ_DAYS
		GameState.toast.emit("The celebrity loved it! Expect more customers for the next %d days." % Data.BUZZ_DAYS, "good")
		note("star", "#6cc3a0", "The celebrity gave you %.1f stars: more customers for %d days." % [score, Data.BUZZ_DAYS])
	else:
		GameState.toast.emit("The celebrity gave you %.1f stars. That counts three times." % score, "bad" if score < 3.0 else "")
		note("star", "#e75a4e" if score < 3.0 else "#f2c14e", "The celebrity gave you %.1f stars." % score)


# ------------------------------------------------------------------ a short delivery

## Called by the morning delivery (see autoload/stock.gd) when something's
## missing. Fired by hand (tests), it takes half of an ingredient away.
func spoil_options() -> Array:
	return Data.ING_ORDER.filter(func(ing): return GameState.stock.get(ing, 0) >= 10)


func can_short_delivery() -> bool:
	return not spoil_options().is_empty()


func start_short_delivery(ing: String = "", missing: int = 0) -> void:
	if ing == "":
		ing = spoil_options().pick_random()
		missing = Stock.lose(ing, GameState.stock[ing] / 2, "short delivery")
	var cost := ceilf(missing * Stock.unit_cost(ing) * 2.0)
	var name_: String = Data.INGREDIENTS[ing]["name"].to_lower()
	ask_player("short_delivery", "The delivery is short",
		"The driver shrugs: only half the %s you ordered came. That's %d portions missing." % [name_, missing],
		[{"label": "Buy an emergency top-up ($%d)" % int(cost), "desc": "Double the usual price, dropped off in minutes."},
		{"label": "Make do", "desc": "Dishes that need it may sell out today."}], {"ing": ing, "lost": missing, "cost": cost})


func choose_short_delivery(i: int, d: Dictionary) -> void:
	var name_: String = Data.INGREDIENTS[d["ing"]]["name"].to_lower()
	if i == 0 and GameState.spend(d["cost"]):
		Stock.add(d["ing"], d["lost"], Stock.unit_cost(d["ing"]) * 2.0)
		GameState.today["delivery_cost"] = GameState.today.get("delivery_cost", 0.0) + d["cost"]
		note("supplies", "#f2c14e", "The delivery was short on %s: you paid $%d for an emergency top-up." % [name_, int(d["cost"])])
	else:
		note("supplies", "#e75a4e", "The delivery was short on %s: %d portions missing." % [name_, d["lost"]])


# ------------------------------------------------------------------ grease fire

func burning_station():
	for f in main.lot.furniture:
		if f.type in ["grill", "fryer", "griddle"] and f.user != null and is_instance_valid(f.user) and f.cooking != "" and not f.broken:
			return f
	return null


func can_grease_fire() -> bool:
	return burning_station() != null


func start_grease_fire() -> void:
	var f = burning_station()
	var cook = f.user
	var what: String = f.info()["name"].to_lower()
	f.broken = true
	f.broke_by = cook
	f.wear = maxf(f.wear, 0.6)
	GameState.today["breakdowns"] += 1
	if not JobBoard.has_open("repair", "furniture", f):
		JobBoard.post("fix", "repair", {"furniture": f})
	cook.stress = minf(100.0, cook.stress + 15.0)
	for y in range(-1, 2):
		for x in range(-1, 3):
			if main.lot.in_lot(f.cell + Vector2i(x, y)):
				main.lot.add_dirt(f.cell + Vector2i(x, y), 0.2)
	main.lot.fx.add(f.center_px(), "Fire!", Color("ff6a3d"))
	Crew.say(cook, "", "alert")
	Sfx.play("error")
	GameState.toast.emit("Grease fire at the %s! %s put it out, but it needs a repair." % [what, cook.person_name], "bad")
	Crew.log_line("Grease fire at the %s! %s put it out." % [what, cook.person_name], "alert", [cook])
	note("fix", "#e75a4e", "A grease fire at the %s." % what)
	main.lot.queue_redraw()


# ------------------------------------------------------------------ staff blow-up

const GRIPES := ["never cleans up", "hogs the grill", "is always late back from break", "sings off-key all day", "keeps moving things", "takes the easy tables"]


func rival_pair() -> Array:
	var t := Crew.present()
	for i in t.size():
		for j in range(i + 1, t.size()):
			var a = t[i]
			var b = t[j]
			if Crew.label(a, b) == "rivals" and not calm.has(Crew.pair_key(a, b)) and not a.on_break and not b.on_break:
				return [a, b]
	return []


func can_staff_blowup() -> bool:
	return not rival_pair().is_empty()


func start_staff_blowup() -> void:
	var p := rival_pair()
	var a = p[0]
	var b = p[1]
	a.pause_left = 2.0
	b.pause_left = 2.0
	Crew.say(a, "bicker", "storm")
	Crew.say(b, "bicker", "storm")
	for g in Crew.groups_near(a.position, 5.0):
		g.note_trouble("staff arguing", Data.BICKER_REVIEW)
	var gripes := GRIPES.duplicate()
	gripes.shuffle()
	ask_player("staff_blowup", "Shouting in the kitchen",
		"%s and %s are at it again, in front of everyone. %s says %s %s. %s says %s %s. They're both looking at you." % [
			a.person_name, b.person_name, a.person_name, b.person_name, gripes[0], b.person_name, a.person_name, gripes[1]],
		[{"label": "Side with %s" % a.person_name, "desc": "%s calms down. %s takes it badly." % [a.person_name, b.person_name]},
		{"label": "Side with %s" % b.person_name, "desc": "%s calms down. %s takes it badly." % [b.person_name, a.person_name]},
		{"label": "Tell them both to cool off", "desc": "Nobody wins, but they'll keep it down for the rest of the day."}], {"a": a, "b": b})


func choose_staff_blowup(i: int, d: Dictionary) -> void:
	var a = d["a"]
	var b = d["b"]
	if not valid_staff(a) or not valid_staff(b):
		return
	if i == 2:
		a.stress = minf(100.0, a.stress + 5.0)
		b.stress = minf(100.0, b.stress + 5.0)
		calm[Crew.pair_key(a, b)] = true
		Crew.log_line("You told %s and %s to cool off." % [a.person_name, b.person_name], "storm", [a, b])
		note("storm", "#f2c14e", "%s and %s had a shouting match. You told them to cool off." % [a.person_name, b.person_name])
		return
	var won = a if i == 0 else b
	var lost = b if i == 0 else a
	won.stress = maxf(0.0, won.stress - 15.0)
	lost.stress = minf(100.0, lost.stress + 20.0)
	Crew.add(lost, won, "blowup")
	Crew.say(lost, "bicker", "storm")
	Crew.log_line("%s and %s had a shouting match. You took %s's side, and %s is fuming." % [a.person_name, b.person_name, won.person_name, lost.person_name], "storm", [a, b])
	note("storm", "#e75a4e", "%s and %s had a shouting match. You sided with %s." % [a.person_name, b.person_name, won.person_name])


# ------------------------------------------------------------------ asking for a raise

func raise_candidate():
	var t := Crew.present()
	t.shuffle()
	for s in t:
		var since: int = GameState.day - s.last_raise_day
		var better: int = s.cooking + s.service - s.start_skill
		if since >= 5 and (better >= 2 or since >= 10):
			return s
	return null


func can_raise() -> bool:
	return raise_candidate() != null


func start_raise() -> void:
	var s = raise_candidate()
	var better: int = s.cooking + s.service - s.start_skill
	var amount := clampi(4 + 2 * better, Data.RAISE_AMOUNT.x, Data.RAISE_AMOUNT.y)
	var why := "\"I've gotten a lot better since I started. I think I've earned it.\"" if better >= 2 else "\"I've been here a while now, and rent keeps going up.\""
	ask_player("raise", "%s wants a raise" % s.person_name,
		"%s catches you by the fridge. %s They're asking for $%d more a shift (they get $%d now)." % [s.person_name, why, amount, s.wage],
		[{"label": "Give the raise (+$%d a shift)" % amount, "desc": "They'll be happy, and less stressed."},
		{"label": "Not right now", "desc": "They'll be stressed, and say no twice and they'll look for another job."}], {"s": s, "amount": amount})


func choose_raise(i: int, d: Dictionary) -> void:
	var s = d["s"]
	if not valid_staff(s):
		return
	s.last_raise_day = GameState.day
	if i == 0:
		s.wage += d["amount"]
		s.stress = maxf(0.0, s.stress - 25.0)
		s.start_skill = s.cooking + s.service
		s.raise_refused = 0
		Crew.say(s, "thanks", "heart")
		Crew.log_line("%s got a raise: $%d a shift now." % [s.person_name, s.wage], "money", [s])
		note("money", "#6cc3a0", "You gave %s a raise of $%d a shift." % [s.person_name, d["amount"]])
	else:
		s.stress = minf(100.0, s.stress + 20.0)
		s.raise_refused += 1
		Crew.log_line("%s asked for a raise and didn't get it." % s.person_name, "money", [s])
		note("money", "#e75a4e", "%s asked for a raise and you said no." % s.person_name)
		if s.raise_refused >= 2:
			GameState.toast.emit("%s is looking for another job." % s.person_name, "bad")
	GameState.staff_changed.emit()


# ------------------------------------------------------------------ a day off

func day_off_candidate():
	var t := Crew.present()
	if GameState.staff.size() < 3:
		return null
	t.shuffle()
	for s in t:
		if s.away_day < GameState.day:
			return s
	return null


func can_day_off() -> bool:
	return day_off_candidate() != null


func start_day_off() -> void:
	var s = day_off_candidate()
	var city: String = s.origin.get("city", "home")
	var why: String = ["%s's cousin is getting married back in %s.", "%s's grandmother is visiting from %s, for one day only.",
		"%s's oldest friend from %s is in town tomorrow.", "%s's little brother has a big game back in %s."].pick_random() % [s.person_name, city]
	ask_player("day_off", "Can %s have tomorrow off?" % s.person_name, why + " Can they have tomorrow off?",
		[{"label": "Of course, have fun", "desc": "They'll be away tomorrow and come back fresh."},
		{"label": "Sorry, we need you", "desc": "They'll be upset."}], {"s": s})


func choose_day_off(i: int, d: Dictionary) -> void:
	var s = d["s"]
	if not valid_staff(s):
		return
	if i == 0:
		s.away_day = GameState.day + 1
		s.stress = maxf(0.0, s.stress - 10.0)
		Crew.say(s, "thanks", "heart")
		Crew.log_line("%s has tomorrow off." % s.person_name, "sun", [s])
		note("sun", "#6cc3a0", "You gave %s tomorrow off." % s.person_name)
	else:
		s.stress = minf(100.0, s.stress + 25.0)
		Crew.log_line("%s asked for a day off and didn't get it." % s.person_name, "sun", [s])
		note("sun", "#e75a4e", "%s asked for a day off and you said no." % s.person_name)
	GameState.staff_changed.emit()


# ------------------------------------------------------------------ a complaint (no manager on shift)

## An unhappy table wants to speak to the manager, and there isn't one on shift.
func ask_complaint(g) -> void:
	var what: String = g.complaint_what if g.complaint_what != "" else "the whole visit"
	var said: String = ["\"We need to talk about %s.\"", "\"Is the manager here? It's about %s.\"", "\"I'm not happy about %s.\""].pick_random() % what
	ask_player("complaint", "%s wants the manager" % g.label(),
		"%s With no manager on shift, it's up to you." % said,
		[{"label": "Apologise", "desc": "They'll feel heard, and review you a little better."},
		{"label": "Their meal's on the house ($%d)" % int(g.bill), "desc": "It costs you the bill, but they'll leave a lot happier."},
		{"label": "Stand your ground", "desc": "You keep the money. They won't like it."}], {"g": g})


func choose_complaint(i: int, d: Dictionary) -> void:
	var g = d["g"]
	if not valid_group(g):
		return
	g.resolve_complaint(["apologise", "comp", "firm"][i])
	note("alert", "#f2c14e", "%s asked for the manager. You %s." % [g.label(), ["apologised", "gave them the meal on the house", "stood your ground"][i]])


# ------------------------------------------------------------------ a sick call (see autoload/shifts.gd)

func choose_sick(i: int, d: Dictionary) -> void:
	Shifts.sick_choice(d["s"], i == 1)


# ------------------------------------------------------------------ street festival

func can_festival() -> bool:
	return GameState.minute < GameState.close_min() - 270.0 and festival_from < 0.0


func start_festival() -> void:
	festival_from = GameState.close_min() - 240.0
	GameState.toast.emit("There's a street festival tonight! Expect a crowd from %s." % DayTimeline.clock(festival_from), "rush")
	note("rush", "#e2703a", "A street festival brought an evening crowd.")
