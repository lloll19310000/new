extends Node
## The diner's shared numbers: money, clock, phase, rating, menu, stock
## and the health grade. Other scripts read these and listen to the
## signals to update themselves.

signal money_changed(value: float)
signal phase_changed(phase: int)
signal rating_changed(rating: float)
signal stock_changed
signal staff_changed
signal menu_changed
signal toast(text: String, kind: String)
signal grade_changed(grade: String)
signal land_changed
signal level_changed(level: int)

## PREP comes last in the list so older code that stored numbers still lines up:
## the day goes PLANNING -> PREP (staff in, doors shut) -> SERVICE -> CLEANUP -> REPORT.
enum Phase { PLANNING, SERVICE, CLEANUP, REPORT, PREP }

var phase: int = Phase.PLANNING
var day: int = 1
var minute: float = 540.0
var speed: int = 1                 # 0 = paused, 1, 2 or 4
var sim_time: float = 0.0          # seconds of simulated time, keeps running while planning
var money: float = 0.0
var reviews: Array = []            # recent review scores (1.0 to 5.0)
var review_count: int = 0          # every review ever
var rating: float = 3.0
var menu: Dictionary = {}          # dish -> {"on": bool, "price": float}
var stock: Dictionary = {}         # ingredient -> int
var target: Dictionary = {}        # ingredient -> int, topped up every night
var plates_total: int = 0
var plates_clean: int = 0
var staff: Array = []              # Staff nodes currently hired
var candidates: Array = []         # people you can hire today
var today: Dictionary = {}
var totals: Dictionary = {}
var next_id: int = 1
var grade: String = ""             # health grade: "", "A", "B" or "C"
var last_inspection_day: int = 0
var supplier: String = "standard"  # see Data.SUPPLIERS
var special: String = ""           # today's special dish, or ""
var owned: Array = ["start"]       # plots of land you own (Data.PLOTS ids)
var rep_level: int = 0             # index into Data.REP_LEVELS
var staff_meal := false            # everyone eats together before opening
var hours := {"breakfast": false, "lunch": true, "dinner": true}   # which services you open for (Data.SERVICES)
var last_allergy_day := -99        # the last day a customer had an allergic reaction (the inspector hears about it)


func _ready() -> void:
	reset()


func reset() -> void:
	phase = Phase.PLANNING
	day = 1
	hours = {"breakfast": false, "lunch": true, "dinner": true}
	minute = prep_min()
	speed = 1
	staff_meal = false
	last_allergy_day = -99
	money = Data.START_MONEY
	reviews = []
	review_count = 0
	rating = 3.0
	menu = {}
	for d in Data.DISH_ORDER:
		menu[d] = {"on": true, "price": Data.DISHES[d]["price"]}
	stock = Data.START_STOCK.duplicate()
	target = Data.START_STOCK.duplicate()
	plates_total = Data.START_PLATES
	plates_clean = Data.START_PLATES
	staff = []
	candidates = []
	next_id = 1
	totals = {"served": 0, "earned": 0.0, "reviews": 0, "grade_a": 0, "critic": 0, "best_sales": 0.0,
		"best_end_rating": 0.0, "best_busy_rating": 0.0}
	grade = ""
	last_inspection_day = 0
	supplier = "standard"
	special = ""
	owned = ["start"]
	rep_level = 0
	Stock.reset()
	reset_today()
	roll_candidates()


func reset_today() -> void:
	today = {"groups": 0, "served": 0, "left": 0, "revenue": 0.0, "tips": 0.0, "scores": [], "complaints": {},
		"takeout": 0, "critic": -1.0, "inspection": "", "breakdowns": 0, "types": {}, "dishes": {},
		"food_used": 0.0, "waste": 0.0, "waste_items": [], "prepped": 0, "prep_used": 0, "delivery_cost": 0.0,
		"staff_meal": 0.0, "sold_out": [], "used": {},
		"regulars": 0, "bookings": 0, "no_shows": 0, "app_orders": 0, "app_done": 0, "app_fees": 0.0, "app_cancelled": 0, "app_missed": 0,
		"comped": 0.0, "complaints_raised": 0, "dashes": 0, "dash_lost": 0.0, "paid_at_till": 0,
		"wrong_orders": 0, "allergies": 0, "cold_plates": 0, "no_plates": 0.0,
		"restroom_uses": 0, "dirty_restroom": 0, "trash_runs": 0, "handwash_skipped": 0, "mice": 0, "mice_caught": 0, "mouse_seen": 0}


func new_id() -> int:
	next_id += 1
	return next_id


# ---------------------------------------------------------------- money

func add_money(amount: float) -> void:
	money += amount
	money_changed.emit(money)


func can_afford(amount: float) -> bool:
	return money >= amount


func spend(amount: float) -> bool:
	if money < amount:
		toast.emit("Not enough cash: that costs $%d." % int(ceil(amount)), "bad")
		return false
	add_money(-amount)
	return true


# ---------------------------------------------------------------- clock

func sim_speed() -> float:
	if phase == Phase.REPORT:
		return 0.0
	return float(speed)


func clock_text() -> String:
	var m := int(minute) % (24 * 60)
	return "%02d:%02d" % [floori(m / 60.0), m % 60]


func set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func is_building_allowed() -> bool:
	return phase == Phase.PLANNING


func is_open() -> bool:
	return phase == Phase.SERVICE


## The clock is running and staff are at work: prep, service or tidying up.
func is_active() -> bool:
	return phase == Phase.PREP or phase == Phase.SERVICE or phase == Phase.CLEANUP


## Today's hours: when the doors open and close, and when prep starts.
## The services you're open for always join up (see set_service).
func open_min() -> float:
	for s in Data.SERVICES:
		if hours.get(s["key"], false):
			return float(s["from"])
	return float(Data.OPEN_MIN)


func close_min() -> float:
	var last := -1.0
	for s in Data.SERVICES:
		if hours.get(s["key"], false):
			last = float(s["to"])
	return last if last > 0.0 else float(Data.CLOSE_MIN)


## Turns a service on or off, keeping the day in one piece: breakfast and
## dinner means lunch too, and something always stays on.
func set_service(key: String, on: bool) -> void:
	hours[key] = on
	var keys: Array = Data.SERVICES.map(func(s): return s["key"])
	var first := -1
	var last := -1
	for i in keys.size():
		if hours.get(keys[i], false):
			if first < 0:
				first = i
			last = i
	if first < 0:
		hours[key] = true
		return
	for i in range(first, last + 1):
		hours[keys[i]] = true
	if phase == Phase.PLANNING:
		minute = prep_min()


func last_seat_min() -> float:
	return close_min() - 30.0


func prep_min() -> float:
	return open_min() - Data.PREP_MINUTES


## The rush or quiet spell happening right now, or {} if it's a normal hour.
func current_rush() -> Dictionary:
	if phase != Phase.SERVICE:
		return {}
	return Data.rush_at(minute)


# ---------------------------------------------------------------- menu and stock

func dish_on(dish: String) -> bool:
	return menu.has(dish) and menu[dish]["on"]


func price(dish: String) -> float:
	return menu[dish]["price"]


func has_ingredients(dish: String, count: int = 1) -> bool:
	var needs: Dictionary = Data.DISHES[dish]["needs"]
	for ing in needs:
		if stock.get(ing, 0) < needs[ing] * count:
			return false
	return true


## Raw ingredients for several dishes at once (one cook's batch), not counting prep.
func has_raw(items: Array) -> bool:
	var total := {}
	for d in items:
		var needs: Dictionary = Data.DISHES[d]["needs"]
		for ing in needs:
			total[ing] = total.get(ing, 0) + needs[ing]
	for ing in total:
		if stock.get(ing, 0) < total[ing]:
			return false
	return true


## Can these dishes be made, using prepped portions first and raw ingredients for the rest?
func has_items(items: Array) -> bool:
	return has_raw(Stock.raw_part(items))


## Takes raw ingredients for these dishes (prepped portions are taken separately).
func take_items(items: Array) -> bool:
	if not has_raw(items):
		return false
	var total := {}
	for d in items:
		var needs: Dictionary = Data.DISHES[d]["needs"]
		for ing in needs:
			total[ing] = total.get(ing, 0) + needs[ing]
	for ing in total:
		Stock.use(ing, total[ing])
	stock_changed.emit()
	return true


## Roughly what tonight's order will cost (it's paid when it arrives in the morning).
func reorder_cost() -> float:
	return Stock.order_cost(Stock.plan_order())


## How much better (or worse) food is from today's supplier.
func food_bonus() -> float:
	return Data.SUPPLIERS[supplier]["quality"]


# ---------------------------------------------------------------- prices

## Menu prices against the usual ones, averaged over dishes that are on (1.0 = usual).
func price_level() -> float:
	var sum := 0.0
	var n := 0
	for d in Data.DISH_ORDER:
		if menu[d]["on"]:
			sum += menu[d]["price"] / Data.DISHES[d]["price"]
			n += 1
	return sum / n if n > 0 else 1.0


## Pricey menus keep people away; cheap ones draw a crowd.
func price_demand() -> float:
	return clampf(1.0 - Data.PRICE_DEMAND * (price_level() - 1.0), Data.PRICE_DEMAND_RANGE.x, Data.PRICE_DEMAND_RANGE.y)


# ---------------------------------------------------------------- land and reputation

func plot(id: String) -> Dictionary:
	for p in Data.PLOTS:
		if p["id"] == id:
			return p
	return {}


func plot_at(c: Vector2i) -> Dictionary:
	for p in Data.PLOTS:
		if (p["rect"] as Rect2i).has_point(c):
			return p
	return {}


func owns(c: Vector2i) -> bool:
	var p := plot_at(c)
	return not p.is_empty() and owned.has(p["id"])


func buy_plot(id: String) -> bool:
	var p := plot(id)
	if p.is_empty() or owned.has(id):
		return false
	if not spend(p["cost"]):
		return false
	owned.append(id)
	toast.emit("You bought the %s for $%d. Build away!" % [p["name"].to_lower(), p["cost"]], "good")
	land_changed.emit()
	return true


func own_all_land() -> void:
	owned = []
	for p in Data.PLOTS:
		owned.append(p["id"])
	land_changed.emit()


func level_info(i: int = -1) -> Dictionary:
	return Data.REP_LEVELS[clampi(rep_level if i < 0 else i, 0, Data.REP_LEVELS.size() - 1)]


## Checked each night: served enough people and ended the day rated well enough?
func check_level_up() -> bool:
	var up := false
	while rep_level + 1 < Data.REP_LEVELS.size():
		var nxt: Dictionary = Data.REP_LEVELS[rep_level + 1]
		if totals["served"] < nxt["served"] or rating < nxt["rating"]:
			break
		rep_level += 1
		up = true
		level_changed.emit(rep_level)
	return up


# ---------------------------------------------------------------- reviews

## weight > 1 makes a review count several times (a food critic counts 5 times).
func add_review(score: float, complaint: String, weight: int = 1) -> void:
	for i in weight:
		reviews.append(score)
	while reviews.size() > Data.REVIEW_WINDOW:
		reviews.pop_front()
	var sum := 0.0
	for r in reviews:
		sum += r
	rating = sum / reviews.size()
	review_count += 1
	today["scores"].append(score)
	totals["reviews"] += 1
	if complaint != "":
		today["complaints"][complaint] = today["complaints"].get(complaint, 0) + 1
	rating_changed.emit(rating)


## How many groups arrive per hour right now: rating, rush hour and health grade.
func groups_per_hour() -> float:
	# 1 star brings about 1.5 groups an hour, 3 stars about 3.3, 5 stars about 5.
	var base := 1.5 + (rating - 1.0) * 0.9
	var rush := current_rush()
	if not rush.is_empty():
		base *= rush["mult"]
	if day <= Data.NEW_DINER_RAMP.size():
		base *= Data.NEW_DINER_RAMP[day - 1]
	base *= level_info()["mult"] * price_demand() * Events.crowd_mult()
	return base * Data.GRADE_EFFECT.get(grade, 1.0)


func set_grade(g: String) -> void:
	grade = g
	last_inspection_day = day
	today["inspection"] = g
	if g == "A":
		totals["grade_a"] += 1
	grade_changed.emit(g)


# ---------------------------------------------------------------- hiring

func roll_candidates() -> void:
	candidates = []
	var used := {}
	for s in staff:
		used[s.person_name] = true
	for i in 3:
		var origin: Dictionary = Data.random_origin(used)
		var pname: String = origin["name"]
		origin.erase("name")
		used[pname] = true
		var cooking := randi_range(2, 9)
		var service := randi_range(2, 9)
		var traits: Array = []
		var r := randf()
		var count := 0 if r < 0.35 else (1 if r < 0.85 else 2)
		var keys: Array = Data.TRAITS.keys()
		keys.shuffle()
		for k in keys:
			if traits.size() >= count:
				break
			if k == "slow" and traits.has("speedy") or k == "speedy" and traits.has("slow"):
				continue
			if k == "friendly" and traits.has("grumpy") or k == "grumpy" and traits.has("friendly"):
				continue
			traits.append(k)
		# wages are per 8-hour shift
		var wage := Data.WAGE_BASE + (cooking + service) * 2 + randi_range(-3, 3)
		for t in traits:
			wage += int(round(Data.TRAITS[t]["wage"] * Data.TRAIT_WAGE_SHARE))
		candidates.append({"name": pname, "cooking": cooking, "service": service, "wage": maxi(wage, 20),
			"skin": Data.SKIN.pick_random(), "hair": Data.HAIR.pick_random(), "traits": traits,
			"origin": origin, "bio": Data.write_bio(origin, cooking, service, traits)})


## Starting priorities for a new hire: their best skill first, everything else after.
func default_priorities(cooking: int, service: int) -> Dictionary:
	return {"cook": 1 if cooking >= service else 2, "serve": 1 if service > cooking else 2,
		"host": 3 if service > cooking else 4, "wash": 3, "clean": 3, "fix": 3}


## Tonight's pay: each person's hours today, with overtime past 8 (see Shifts).
func wages() -> float:
	var total := 0.0
	for s in staff:
		total += Shifts.pay_today(s)
	return total
