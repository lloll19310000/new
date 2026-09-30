extends Node
## The front of house:
##   - the host stand: a host greets people, keeps a waitlist and takes bookings
##   - bookings: a table is held for them, and some never show up
##   - regulars: named locals with a usual order and a favourite server
##   - delivery apps: orders come in over the app and a driver picks them up
##   - complaints: when the owner has to step in (no manager on shift)
## group.gd and staff.gd do the walking and talking; this keeps the lists.

var main                               # set by main.gd
var take_bookings := false             # the host takes bookings by phone
var apps_on := false                   # signed up to the delivery apps
var bookings: Array = []               # today's: {"name", "size", "kind", "at", "arrive", "no_show", "state", "table", "group"}
var regulars: Array = []               # {"name", "blurb", "usual", "hours", "party", "every", "loyalty", "fav", "fav_counts", "visits", "next_day", "known", "gone", "skin", "hair", "shirt"}
var visits: Array = []                 # today's regular visits still to come: {"at", "r"}
var cards_today := 0                   # complaints you've been asked to handle today
var _app_acc := 0.0
var _next_app := 30.0


func _ready() -> void:
	reset()


func reset() -> void:
	take_bookings = false
	apps_on = false
	bookings = []
	visits = []
	cards_today = 0
	regulars = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1981   # the same town every game: the same people, the same faces
	for i in Data.REGULARS.size():
		var t: Dictionary = Data.REGULARS[i]
		regulars.append({"name": t["name"], "blurb": t["blurb"], "usual": t["usual"].duplicate(), "hours": t["hours"].duplicate(),
			"party": t["party"], "every": t["every"], "loyalty": 50.0, "fav": 0, "fav_counts": {}, "visits": 0,
			"next_day": 1 + rng.randi_range(0, t["every"] - 1), "known": i < Data.REGULAR_START, "gone": false,
			"skin": Data.SKIN[rng.randi() % Data.SKIN.size()], "hair": Data.HAIR[rng.randi() % Data.HAIR.size()],
			"shirt": Data.CLOTHES[rng.randi() % Data.CLOTHES.size()],
			"seat": Data.REGULAR_SEATS.get(t["name"], "table"), "birthday": 1 + rng.randi_range(0, Data.YEAR_DAYS - 1), "beats": 0, "beat_text": ""})


func valid_group(g) -> bool:
	return g != null and is_instance_valid(g) and not g.state in ["leaving", "gone"]


# ------------------------------------------------------------------ the host

## A host stand, and someone at work today with Host switched on.
func host_working() -> bool:
	if main == null or main.lot.of_type("host").is_empty():
		return false
	for s in Crew.present():
		if s.priorities.get("host", 0) > 0:
			return true
	return false


# ------------------------------------------------------------------ the day

## When the day starts: today's bookings and which regulars will come by.
func plan_day() -> void:
	bookings = []
	visits = []
	cards_today = 0
	_app_acc = 0.0
	_next_app = randf_range(10.0, 40.0)
	var o := GameState.open_min()
	var c := GameState.close_min()
	if take_bookings and main != null and not main.lot.of_type("host").is_empty() and not main.lot.tables().is_empty():
		var biggest := 1
		for t in main.lot.tables():
			biggest = maxi(biggest, t.chairs.size())
		var n := randi_range(Data.BOOKINGS_PER_DAY.x, Data.BOOKINGS_PER_DAY.y) + GameState.rep_level / 2
		var names: Array = Data.BOOKING_NAMES.duplicate()
		names.shuffle()
		for i in n:
			var at := snappedf(randf_range(o + 60.0, c - 90.0), 15.0)
			var kinds := ["family", "regular", "regular", "family"]
			if GameState.rep_level >= 2:
				kinds.append("tourist")
			bookings.append({"name": names[i % names.size()], "size": mini(randi_range(2, 4), biggest), "kind": kinds.pick_random(),
				"at": at, "arrive": at + randf_range(-5.0, 12.0), "no_show": randf() < Data.BOOKING_NO_SHOW,
				"state": "booked", "table": null, "group": null})
		bookings.sort_custom(func(a, b): return a["at"] < b["at"])
	for r in regulars:
		if not r["known"] or r["gone"] or r["next_day"] > GameState.day:
			continue
		r["next_day"] = GameState.day + r["every"] + (1 if randf() < 0.3 else 0)
		var from := maxf(r["hours"][0] * 60.0, o)
		var to := minf(r["hours"][1] * 60.0, c - 45.0)
		if to <= from:
			# they came by when you weren't open
			r["loyalty"] = maxf(0.0, r["loyalty"] - 3.0)
			continue
		visits.append({"at": randf_range(from, to), "r": r})


func tick(minutes: float) -> void:
	if main == null or GameState.phase != GameState.Phase.SERVICE:
		return
	var now := GameState.minute
	for v in visits.duplicate():
		if now >= v["at"]:
			visits.erase(v)
			if now < GameState.last_seat_min() and main.lot.has_entry() and not main.lot.tables().is_empty():
				var size: int = v["r"]["party"] + (1 if is_birthday(v["r"]) else 0)
				main.spawn_group("regular", mini(size, 6), null, {"regular": v["r"]})
	for b in bookings:
		match b["state"]:
			"booked", "held":
				if b["state"] == "booked" and now >= b["at"] - Data.BOOKING_HOLD:
					hold_table(b)
				if b["no_show"]:
					if now >= b["at"] + 20.0:
						release(b)
						b["state"] = "no_show"
						GameState.today["no_shows"] += 1
						Crew.log_line("The %s booking for %s (%d) didn't show up." % [DayTimeline.clock(b["at"]), b["name"], b["size"]], "day")
				elif now >= b["arrive"]:
					b["state"] = "arrived"
					main.spawn_group(b["kind"], b["size"], null, {"booking": b})
	app_tick(minutes)


## Holds the smallest free table that fits them.
func hold_table(b: Dictionary) -> void:
	var best = null
	for t in main.lot.tables():
		if t.chairs.size() < b["size"] or not t.table_free() or t.reserved != null:
			continue
		if best == null or t.chairs.size() < best.chairs.size():
			best = t
	if best != null:
		best.reserved = b
		b["table"] = best
		b["state"] = "held"
		main.lot.queue_redraw()


func release(b: Dictionary) -> void:
	var t = b.get("table")
	if t != null and t.reserved == b:
		t.reserved = null
	b["table"] = null
	if main != null:
		main.lot.queue_redraw()


func bookings_left() -> Array:
	return bookings.filter(func(b): return b["state"] in ["booked", "held"])


# ------------------------------------------------------------------ delivery apps

func app_window():
	if main == null:
		return null
	return main.free_takeout_window()


func app_tick(minutes: float) -> void:
	if not apps_on or main == null or main.lot.of_type("takeout").is_empty():
		return
	_app_acc += minutes
	if _app_acc < _next_app:
		return
	_app_acc = 0.0
	var rate := Data.APP_PER_HOUR * (0.6 + 0.2 * GameState.rating) * (1.5 if Events.raining else 1.0)
	var rush: Dictionary = GameState.current_rush()
	if not rush.is_empty():
		rate *= rush["mult"]
	_next_app = 60.0 / rate * randf_range(0.6, 1.4)
	if GameState.minute >= GameState.last_seat_min():
		return
	var w = app_window()
	if w == null:
		GameState.today["app_missed"] += 1
		return
	main.spawn_group("driver", 1, w)


# ------------------------------------------------------------------ regulars

func by_name(n: String) -> Dictionary:
	for r in regulars:
		if r["name"] == n:
			return r
	return {}


func known() -> Array:
	return regulars.filter(func(r): return r["known"])


## Their story so far: the beats they've reached.
func stories(r: Dictionary) -> Array:
	return Data.REGULAR_STORIES.get(r["name"], Data.REGULAR_STORY_GENERIC)


func is_birthday(r: Dictionary) -> bool:
	return r.get("birthday", 0) == Moments.day_of_year(GameState.day)


func days_to_birthday(r: Dictionary) -> int:
	return posmod(int(r.get("birthday", 1)) - Moments.day_of_year(GameState.day), Data.YEAR_DAYS)


## A regular who's warmed up enough reaches the next beat of their story.
func check_story(r: Dictionary, server) -> void:
	var i: int = r.get("beats", 0)
	var list: Array = stories(r)
	if i >= list.size() or i >= Data.REGULAR_BEAT_AT.size():
		return
	var need: Array = Data.REGULAR_BEAT_AT[i]
	if r["loyalty"] < need[0] or r["visits"] < need[1]:
		return
	var beat: Dictionary = list[i]
	r["beats"] = i + 1
	var text: String = str(beat["text"]).replace("{r}", r["name"]).replace("{s}", server.person_name if server != null else "the crew")
	r["beat_text"] = text
	if beat.has("party"):
		r["party"] = maxi(int(r["party"]), int(beat["party"]))
	if beat.has("gift"):
		GameState.add_money(float(beat["gift"]))
		GameState.today["revenue"] += float(beat["gift"])
		text += " (+$%d)" % int(beat["gift"])
	if beat.get("rep", false):
		GameState.add_review(5.0, "")
	Crew.log_line(text, "heart", [server] if server != null else [])
	GameState.toast.emit(text, "crew")
	Moments.note_scrapbook("regular", r["name"], text)
	if server != null:
		server.add_stress(-4.0, "a regular's story")


## After a regular's visit: loyalty, their favourite server, and a line in the log.
func after_visit(r: Dictionary, score: float, servers: Array) -> void:
	r["visits"] += 1
	var delta := 8.0 if score >= 4.5 else (4.0 if score >= 3.5 else (-4.0 if score >= 2.5 else -12.0))
	r["loyalty"] = clampf(r["loyalty"] + delta, 0.0, 100.0)
	var server = null
	for s in servers:
		if s != null and is_instance_valid(s) and GameState.staff.has(s):
			server = s
			break
	if server != null:
		var k := str(server.id)
		r["fav_counts"][k] = r["fav_counts"].get(k, 0) + (2 if score >= 4.0 else 1)
		var best := ""
		var best_n := 0
		for id in r["fav_counts"]:
			if r["fav_counts"][id] > best_n:
				best_n = r["fav_counts"][id]
				best = id
		r["fav"] = int(best)
	var who: Array = [server] if server != null else []
	if r["loyalty"] <= 0.0:
		r["gone"] = true
		Crew.log_line(line("gone", r, server), "walkout", who)
		GameState.toast.emit("%s has stopped coming in." % r["name"], "bad")
	elif score >= 4.5 and server != null:
		if randf() < 0.5:
			Crew.log_line(line("great", r, server), "heart", who)
		server.add_stress(-3.0, "a happy regular")
	elif score < 2.5:
		Crew.log_line(line("bad", r, server), "alert", who)
	if not r["gone"] and score >= 3.5:
		check_story(r, server)
	if r["loyalty"] >= 100.0 and not GameState.totals.get("heart_full", false):
		GameState.totals["heart_full"] = true


func line(kind: String, r: Dictionary, s = null) -> String:
	var l: String = Data.REGULAR_LINES[kind].pick_random()
	return l.replace("{r}", r["name"]).replace("{b}", r["blurb"].to_lower().trim_suffix(".")).replace("{s}", s.person_name if s != null else "the staff")


## At night: now and then a new regular starts coming in.
func nightly() -> void:
	var limit := Data.REGULAR_START + 2 * GameState.rep_level
	var k := known().filter(func(r): return not r["gone"]).size()
	if k < limit and randf() < Data.REGULAR_NEW_CHANCE:
		for r in regulars:
			if not r["known"]:
				r["known"] = true
				r["next_day"] = GameState.day + 1
				Crew.log_line(line("new", r), "people")
				break


func fav_staff(r: Dictionary):
	if r.get("fav", 0) <= 0:
		return null
	return Crew.by_id(r["fav"])


# ------------------------------------------------------------------ saves

func save_data() -> Dictionary:
	var regs: Array = []
	for r in regulars:
		regs.append({"name": r["name"], "loyalty": r["loyalty"], "fav": r["fav"], "fav_counts": r["fav_counts"], "visits": r["visits"],
			"next_day": r["next_day"], "known": r["known"], "gone": r["gone"], "beats": r["beats"], "beat_text": r["beat_text"], "party": r["party"]})
	return {"take_bookings": take_bookings, "apps_on": apps_on, "regulars": regs}


func load_data(d: Dictionary) -> void:
	reset()
	take_bookings = bool(d.get("take_bookings", false))
	apps_on = bool(d.get("apps_on", false))
	for rd in d.get("regulars", []):
		var r := by_name(str(rd.get("name", "")))
		if r.is_empty():
			continue
		r["loyalty"] = float(rd.get("loyalty", 50.0))
		r["fav"] = int(rd.get("fav", 0))
		r["fav_counts"] = {}
		for k in rd.get("fav_counts", {}):
			r["fav_counts"][str(k)] = int(rd["fav_counts"][k])
		r["visits"] = int(rd.get("visits", 0))
		r["next_day"] = int(rd.get("next_day", 1))
		r["known"] = bool(rd.get("known", false))
		r["gone"] = bool(rd.get("gone", false))
		r["beats"] = int(rd.get("beats", 0))
		r["beat_text"] = str(rd.get("beat_text", ""))
		r["party"] = int(rd.get("party", r["party"]))
	if not d.has("regulars"):
		# an older diner: its regulars start coming from tomorrow
		for r in regulars:
			r["next_day"] = maxi(r["next_day"], GameState.day)
