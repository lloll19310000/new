extends Node
## The town around the diner:
##   the calendar: day 1 is the 1st of March; seasons change what people order
##     and what produce costs; holidays bring their own crowds
##   the weather: sunny, rain, storms, snow in winter, heatwaves in summer
##   the events board: the county fair, Friday-night football, roadwork
##     out front, the farmers' market, a marathon...
##   the rival: once you're a Town favourite, a diner opens across the street
## Everything here only nudges numbers the rest of the game already uses
## (how many people come, what they order, what things cost).

signal changed

const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const START_DOY := 59              # day 1 is the 1st of March (day of year 60)

var weather := "clear"             # "clear", "rain", "storm", "snow", "heat"
var forecast := "clear"            # tomorrow's
var events: Array = []             # town events on now: {"key", "until"}
var rival: Dictionary = {}         # {"name", "strength", "since", "good_days", "closed"}
var loyalty_cards := false
var price_match := false


func reset() -> void:
	weather = "clear"
	forecast = "clear"
	events = []
	rival = {}
	loyalty_cards = false
	price_match = false


# ------------------------------------------------------------------ the calendar

## Day of the year (1..365) for a game day.
func doy(day: int = -1) -> int:
	if day < 0:
		day = GameState.day
	return posmod(START_DOY + day - 1, 365) + 1


func date(day: int = -1) -> Dictionary:
	if day < 0:
		day = GameState.day
	var d := doy(day)
	var m := 0
	while d > MONTH_DAYS[m]:
		d -= MONTH_DAYS[m]
		m += 1
	return {"month": m + 1, "dom": d, "weekday": posmod(day - 1, 7), "year": 1 + int((START_DOY + day - 1) / 365.0)}


func date_text(day: int = -1) -> String:
	var dt := date(day)
	return "%s, %s %d" % [WEEKDAYS[dt["weekday"]].substr(0, 3), MONTHS[dt["month"] - 1].substr(0, 3), dt["dom"]]


func season(day: int = -1) -> String:
	var m: int = date(day)["month"]
	if m == 12 or m <= 2:
		return "winter"
	if m <= 5:
		return "spring"
	if m <= 8:
		return "summer"
	return "fall"


## Today's holiday (from Data.HOLIDAYS), or {}.
func holiday(day: int = -1) -> Dictionary:
	var dt := date(day)
	for h in Data.HOLIDAYS:
		if h.has("dom") and h["month"] == dt["month"] and h["dom"] == dt["dom"]:
			return h
		if h.has("nth") and h["month"] == dt["month"] and h["weekday"] == dt["weekday"] and int((dt["dom"] - 1) / 7) + 1 == h["nth"]:
			return h
	return {}


# ------------------------------------------------------------------ the weather

func roll_weather() -> String:
	var odds: Dictionary = Data.WEATHER_ODDS[season()]
	var r := randf()
	for k in odds:
		r -= odds[k]
		if r <= 0.0:
			return k
	return "clear"


## Each morning: today's weather (yesterday's forecast, mostly) and tomorrow's.
func morning() -> void:
	weather = forecast if randf() < 0.8 else roll_weather()
	if GameState.day <= 1:
		weather = "clear"
	forecast = roll_weather()
	var h := holiday()
	if not h.is_empty():
		GameState.toast.emit("Today is %s. %s" % [h["name"], h["note"]], "rush")
	for e in events:
		if int(e["from"]) == GameState.day:
			var info: Dictionary = Data.TOWN_EVENTS[e["key"]]
			GameState.toast.emit("Around town: %s. %s" % [info["name"], info["note"]], "")
	changed.emit()


func weather_name(w: String = "") -> String:
	return {"clear": "Sunny", "rain": "Rain", "storm": "Storm", "snow": "Snow", "heat": "Heatwave"}.get(w if w != "" else weather, "Sunny")


func weather_icon(w: String = "") -> String:
	return {"clear": "sun", "rain": "storm", "storm": "storm", "snow": "sparkle", "heat": "sun"}.get(w if w != "" else weather, "sun")


# ------------------------------------------------------------------ town events

func event_on(key: String) -> bool:
	for e in events:
		if e["key"] == key and GameState.day >= int(e["from"]) and GameState.day <= int(e["until"]):
			return true
	return false


## Friday-night football runs every Friday in the fall, by itself.
func football_tonight() -> bool:
	return season() == "fall" and date()["weekday"] == 4


## Now and then something happens around town, announced a day or two ahead.
func nightly() -> void:
	events = events.filter(func(e): return int(e["until"]) >= GameState.day + 1)
	if events.size() < 2 and randf() < Data.TOWN_EVENT_CHANCE:
		var keys: Array = Data.TOWN_EVENTS.keys().filter(func(k): return not event_on(k) and (Data.TOWN_EVENTS[k].get("season", "") == "" or Data.TOWN_EVENTS[k]["season"] == season(GameState.day + 2)))
		if not keys.is_empty():
			var k: String = keys.pick_random()
			var info: Dictionary = Data.TOWN_EVENTS[k]
			var from := GameState.day + randi_range(1, 3)
			events.append({"key": k, "from": from, "until": from + randi_range(info["days"][0], info["days"][1]) - 1})
			Crew.log_line("On the town board: %s from %s. %s" % [info["name"], date_text(from), info["note"]], "calendar")
	rival_nightly()
	changed.emit()


# ------------------------------------------------------------------ the rival

func rival_open() -> bool:
	return not rival.is_empty() and not rival.get("closed", false)


func rival_nightly() -> void:
	if rival.is_empty():
		if GameState.rep_level >= Data.RIVAL_AT_LEVEL and randf() < 0.25:
			rival = {"name": Data.RIVAL_NAMES.pick_random(), "strength": Data.RIVAL_START, "since": GameState.day + 1, "good_days": 0, "closed": false}
			GameState.toast.emit("A new diner, %s, is opening across the street tomorrow. They'll be after your customers." % rival["name"], "bad")
			Crew.log_line("%s is opening across the street." % rival["name"], "alert")
		return
	if rival["closed"]:
		return
	# they grow while you're average, and give up if you stay excellent
	var today_rating: float = GameState.rating
	if today_rating >= Data.RIVAL_BEAT_RATING:
		rival["good_days"] += 1
	else:
		rival["good_days"] = maxi(0, rival["good_days"] - 1)
	rival["strength"] = clampf(rival["strength"] + (Data.RIVAL_GROW if today_rating < 4.0 else -Data.RIVAL_GROW), 0.03, Data.RIVAL_MAX)
	if rival["good_days"] >= Data.RIVAL_BEAT_DAYS:
		rival["closed"] = true
		GameState.toast.emit("%s has closed. Their regulars are coming to you now." % rival["name"], "good")
		Crew.log_line("%s across the street closed down. You won." % rival["name"], "star")
		GameState.totals["rival_beaten"] = int(GameState.totals.get("rival_beaten", 0)) + 1
		return
	# now and then they make a move
	if randf() < Data.RIVAL_MOVE_CHANCE:
		rival_move()


func rival_move() -> void:
	var moves := ["price_war", "poach", "steal_regular"]
	var m: String = moves.pick_random()
	match m:
		"price_war":
			if not price_match:
				rival["strength"] = minf(Data.RIVAL_MAX, rival["strength"] + 0.04)
				GameState.toast.emit("%s is running a two-for-one special. Some of your customers are trying it." % rival["name"], "bad")
		"poach":
			var cands: Array = GameState.staff.filter(func(s): return s.cooking + s.service >= 11)
			if not cands.is_empty():
				Events.ask_poach(cands.pick_random(), rival["name"])
		"steal_regular":
			var regs: Array = Front.known().filter(func(r): return not r["gone"])
			if not regs.is_empty():
				var r: Dictionary = regs.pick_random()
				var hit := 5.0 if loyalty_cards else 15.0
				r["loyalty"] = maxf(0.0, r["loyalty"] - hit)
				Crew.log_line("%s tried %s across the street.%s" % [r["name"], rival["name"], " Their loyalty card kept them coming back." if loyalty_cards else ""], "people")


## How much of your trade the rival takes (0 = none).
func rival_pull() -> float:
	if not rival_open() or GameState.day < int(rival["since"]):
		return 0.0
	var p: float = rival["strength"]
	if price_match:
		p *= 0.5
	if loyalty_cards:
		p *= 0.75
	return p


# ------------------------------------------------------------------ effects

## How many people come, right now, compared with an ordinary day.
func crowd_mult() -> float:
	var m: float = Data.SEASON_CROWD.get(season(), 1.0)
	var h := holiday()
	if not h.is_empty():
		m *= h.get("crowd", 1.0)
	m *= Data.WEATHER_CROWD.get(weather, 1.0)
	var hour := GameState.minute / 60.0
	for e in events:
		if GameState.day < int(e["from"]) or GameState.day > int(e["until"]):
			continue
		var info: Dictionary = Data.TOWN_EVENTS[e["key"]]
		m *= info.get("crowd", 1.0)
		if info.has("hours") and hour >= info["hours"][0] and hour < info["hours"][1]:
			m *= info.get("hours_crowd", 1.0)
	if football_tonight() and hour >= 21.0:
		m *= Data.FOOTBALL_CROWD
	return m * (1.0 - rival_pull())


## What people fancy: seasonal dishes, holiday favourites, iced drinks in a heatwave.
func dish_mult(d: String) -> float:
	var m: float = Data.SEASON_DISHES[season()].get(d, 1.0)
	var h := holiday()
	if not h.is_empty():
		m *= h.get("dishes", {}).get(d, 1.0)
	if weather == "heat" and d in ["soda", "icedtea", "milkshake"]:
		m *= 1.6
	if weather in ["snow", "storm"] and d in ["soup", "chili", "coffee"]:
		m *= 1.5
	return m


## Who comes: families on Mother's Day, truckers stuck in a storm...
func kind_mult(k: String) -> float:
	var m := 1.0
	var h := holiday()
	if not h.is_empty():
		m *= h.get("kinds", {}).get(k, 1.0)
	if weather in ["storm", "snow"] and k == "trucker":
		m *= 3.0
	if football_tonight() and k == "student" and GameState.minute >= 21.0 * 60.0:
		m *= 3.0
	return m


func tip_mult() -> float:
	var h := holiday()
	return h.get("tips", 1.0) if not h.is_empty() else 1.0


## Produce is cheap in summer and dear in winter; the farmers' market helps.
func price_mult(ing: String) -> float:
	var m: float = Data.SEASON_PRICES[season()].get(ing, 1.0)
	if event_on("market") and ing in ["veg", "fruit", "eggs"]:
		m *= 0.7
	return m


func takeout_mult() -> float:
	var h := holiday()
	var m: float = h.get("takeout", 1.0) if not h.is_empty() else 1.0
	if weather in ["rain", "storm", "snow"]:
		m *= 1.5
	return m


## Lines for the report and the Office: what's going on in town today.
func today_lines() -> Array:
	var out: Array = []
	out.append("%s, %s. %s%s." % [date_text(), season().capitalize(), weather_name(), " (a quieter street)" if weather in ["storm", "snow"] else ""])
	var h := holiday()
	if not h.is_empty():
		out.append("%s: %s" % [h["name"], h["note"]])
	for e in events:
		var info: Dictionary = Data.TOWN_EVENTS[e["key"]]
		if GameState.day >= int(e["from"]) and GameState.day <= int(e["until"]):
			out.append("%s (until %s): %s" % [info["name"], date_text(int(e["until"])), info["note"]])
		else:
			out.append("Coming up on %s: %s." % [date_text(int(e["from"])), info["name"]])
	if football_tonight():
		out.append("Friday-night football: the crowd comes by after the game, around 21:00.")
	if rival_open():
		out.append("%s across the street is taking about %d%% of your trade." % [rival["name"], int(round(rival_pull() * 100))])
	return out


# ------------------------------------------------------------------ saves

func save_data() -> Dictionary:
	return {"weather": weather, "forecast": forecast, "events": events, "rival": rival, "loyalty_cards": loyalty_cards, "price_match": price_match}


func load_data(d: Dictionary) -> void:
	reset()
	weather = str(d.get("weather", "clear"))
	forecast = str(d.get("forecast", "clear"))
	events = d.get("events", [])
	rival = d.get("rival", {})
	loyalty_cards = bool(d.get("loyalty_cards", false))
	price_match = bool(d.get("price_match", false))
