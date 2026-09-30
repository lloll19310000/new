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

var diner_name := ""               # what you called your diner (shown on saves)
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
var next_inspection_day: int = 5  # the inspector's next visit (they don't say exactly when)
var supplier: String = "standard"  # see Data.SUPPLIERS
var special: String = ""           # today's special dish, or ""
var owned: Array = ["start"]       # plots of land you own (Data.PLOTS ids)
var rep_level: int = 0             # index into Data.REP_LEVELS
var staff_meal := false            # everyone eats together before opening
var hours := {"breakfast": false, "lunch": true, "dinner": true}   # which services you open for (Data.SERVICES)
var seats := 16                    # seats in the dining room (kept up to date by main.gd)
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
	next_inspection_day = randi_range(Data.FIRST_INSPECTION.x, Data.FIRST_INSPECTION.y)
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
		"wrong_orders": 0, "allergies": 0, "cold_plates": 0, "no_plates": 0.0, "best": {}, "worst": {},
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


## The day report's snapshots: the happiest and the unhappiest table today.
## who: "A trucker", "Priya"; what: the dishes or the complaint.
func note_moment(score: float, who: String, what: String, left: bool = false) -> void:
	var b: Dictionary = today.get("best", {})
	if not left and (b.is_empty() or score > b["score"]):
		today["best"] = {"score": score, "who": who, "what": what, "at": clock_text()}
	var w: Dictionary = today.get("worst", {})
	var ws := 0.5 if left else score
	if (left or score < 3.5) and (w.is_empty() or ws < w["score"]):
		today["worst"] = {"score": ws, "who": who, "what": what, "at": clock_text(), "left": left}


## How many groups arrive per hour right now: rating, rush hour and health grade.
func groups_per_hour() -> float:
	# 1 star brings about 1.5 groups an hour, 3 stars about 3.3, 5 stars about 5.
	var base := 1.5 + (rating - 1.0) * 0.9
	var rush := current_rush()
	if not rush.is_empty():
		base *= rush["mult"]
	if day <= Data.NEW_DINER_RAMP.size():
		base *= Data.NEW_DINER_RAMP[day - 1]
	base *= level_info()["mult"] * price_demand() * Events.crowd_mult() * seat_demand()
	return base * Data.GRADE_EFFECT.get(grade, 1.0)


## A bigger dining room draws more people.
func seat_demand() -> float:
	return clampf(pow(maxf(1.0, seats) / Data.DEMAND_SEATS, Data.DEMAND_SEAT_POWER), Data.DEMAND_SEAT_RANGE.x, Data.DEMAND_SEAT_RANGE.y)


func set_grade(g: String) -> void:
	grade = g
	last_inspection_day = day
	next_inspection_day = day + randi_range(Data.INSPECTION_DAYS.x, Data.INSPECTION_DAYS.y)
	today["inspection"] = g
	if g == "A":
		totals["grade_a"] += 1
	grade_changed.emit(g)


## Someone reported a reaction to the food: the health department follows up soon.
func report_allergy() -> void:
	last_allergy_day = day
	next_inspection_day = mini(next_inspection_day, day + randi_range(Data.FOLLOW_UP_INSPECTION.x, Data.FOLLOW_UP_INSPECTION.y))


# ---------------------------------------------------------------- hiring

## Skill ranges [cooking, service] for people looking for each kind of job.
const ROLE_SKILLS := {
	"cook": [Vector2i(3, 9), Vector2i(1, 6)], "server": [Vector2i(1, 5), Vector2i(3, 9)], "host": [Vector2i(1, 5), Vector2i(3, 9)],
	"busser": [Vector2i(1, 5), Vector2i(2, 7)], "dishwasher": [Vector2i(1, 6), Vector2i(1, 6)], "porter": [Vector2i(2, 6), Vector2i(3, 7)],
	"manager": [Vector2i(4, 9), Vector2i(5, 9)],
}


## New people looking for work this morning: a few of every kind, so you can
## always fill a shift. Hire as many as you like.
func roll_candidates() -> void:
	candidates = []
	var roles: Array = ["cook", "cook", "server", "server", "host", "busser", "dishwasher", ["manager", "porter", "cook", "server"].pick_random()]
	for i in Data.CANDIDATES_PER_DAY - roles.size():
		roles.append(Data.ROLE_ORDER.pick_random())
	for r in roles.slice(0, Data.CANDIDATES_PER_DAY):
		candidates.append(make_candidate(r))


## A job ad for one role: a few more people for it come by today.
func post_job_ad(role: String) -> bool:
	if not Data.ROLES.has(role) or not spend(Data.JOB_AD_COST):
		return false
	for i in Data.JOB_AD_PEOPLE:
		candidates.append(make_candidate(role))
	toast.emit("Your ad for a %s is up: %d people came by." % [Data.ROLES[role]["name"].to_lower(), Data.JOB_AD_PEOPLE], "good")
	staff_changed.emit()
	return true


func make_candidate(role: String) -> Dictionary:
	var used := {}
	for s in staff:
		used[s.person_name] = true
	for c in candidates:
		used[c["name"]] = true
	var origin: Dictionary = Data.random_origin(used)
	var pname: String = origin["name"]
	origin.erase("name")
	var sk: Array = ROLE_SKILLS.get(role, ROLE_SKILLS["server"])
	var cooking := randi_range(sk[0].x, sk[0].y)
	var service := randi_range(sk[1].x, sk[1].y)
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
	# hourly pay, as asked for this role (never under the minimum wage)
	var wage: float = Data.role_pay(role, cooking, service, traits) + snappedf(randf_range(-0.5, 0.5), 0.25)
	return {"name": pname, "role": role, "cooking": cooking, "service": service, "wage": maxf(Data.MIN_WAGE, wage),
		"skin": Data.SKIN.pick_random(), "hair": Data.HAIR.pick_random(), "traits": traits,
		"origin": origin, "bio": Data.write_bio(origin, cooking, service, traits)}


## Starting priorities for someone in this role (see Data.ROLES).
func default_priorities(role: String) -> Dictionary:
	return Data.ROLES.get(role, Data.ROLES["server"])["priorities"].duplicate()


## The role that fits someone from an older save best, from their priorities.
func guess_role(priorities: Dictionary, manager: bool) -> String:
	if manager:
		return "manager"
	for pair in [["cook", "cook"], ["serve", "server"], ["host", "host"], ["wash", "dishwasher"], ["clean", "busser"], ["fix", "porter"]]:
		if priorities.get(pair[0], 0) == 1:
			return pair[1]
	return "server"


## Tonight's pay: each person's hours today, with overtime past 8 (see Shifts).
func wages() -> float:
	var total := 0.0
	for s in staff:
		total += Shifts.pay_today(s)
	return total
