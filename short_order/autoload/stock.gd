extends Node
## Ingredients and the morning routine in the kitchen:
##   - what's in the fridge, the freezer and on the dry shelves, and when it goes off
##   - the order you place at night and the delivery that brings it next morning
##   - morning prep: portions chopped and mixed ahead, so dishes cook faster
##   - dishes that sell out ("86'd") when the ingredients run out
##   - what gets thrown away, and what the food you used cost
##
## GameState.stock still holds the totals the interface shows. Everything here
## keeps them in step; if something writes GameState.stock directly (an old
## save, a test), reconcile() quietly adjusts the batches to match.

signal delivered

var main                               # set by main.gd
var batches := {}                      # ing -> [[count, day it arrived, cost each], ...] oldest first
var prep_par := {}                     # dish -> portions to prep each morning
var prepped := {}                      # dish -> portions prepped and ready right now
var pending := {}                      # ing -> amount on order for the next morning
var pending_cost := 0.0
var delivery_at := -1.0                # game minute today's delivery arrives, or -1
var delivery_late := false
var sold_out := {}                     # dish -> true while it's off because nothing's left
var yesterday := {}                    # dish -> how many were ordered yesterday
var used_yesterday := {}               # ing -> how much the kitchen used yesterday
var van_until := -1.0                  # the delivery van is parked out front until this minute
var short_fit := {}                    # ing -> amount that didn't fit in storage tonight


func _ready() -> void:
	reset()


func reset() -> void:
	batches = {}
	for ing in Data.ING_ORDER:
		batches[ing] = []
		var n: int = Data.START_STOCK.get(ing, 0)
		if n > 0:
			batches[ing].append([n, 1, Data.INGREDIENTS[ing]["cost"]])
	prep_par = Data.START_PREP.duplicate()
	prepped = {}
	pending = {}
	pending_cost = 0.0
	delivery_at = -1.0
	delivery_late = false
	sold_out = {}
	yesterday = {}
	used_yesterday = {}
	van_until = -1.0
	short_fit = {}


# ------------------------------------------------------------------ batches

func unit_cost(ing: String) -> float:
	return Data.INGREDIENTS[ing]["cost"] * Data.SUPPLIERS[GameState.supplier]["cost"]


func total(ing: String) -> int:
	var n := 0
	for b in batches.get(ing, []):
		n += b[0]
	return n


## If someone changed GameState.stock directly, match the batches to it.
func reconcile() -> void:
	for ing in Data.ING_ORDER:
		if not batches.has(ing):
			batches[ing] = []
		var want: int = GameState.stock.get(ing, 0)
		var have := total(ing)
		if want > have:
			batches[ing].append([want - have, GameState.day, Data.INGREDIENTS[ing]["cost"]])
		elif want < have:
			_remove(ing, have - want)


func sync(ing: String) -> void:
	GameState.stock[ing] = total(ing)


## Takes n from the oldest batches first. Returns what they cost.
func _remove(ing: String, n: int) -> float:
	var cost := 0.0
	var list: Array = batches[ing]
	while n > 0 and not list.is_empty():
		var b: Array = list[0]
		var k := mini(n, b[0])
		b[0] -= k
		n -= k
		cost += k * b[2]
		if b[0] <= 0:
			list.pop_front()
	return cost


func add(ing: String, n: int, cost_each: float = -1.0) -> void:
	if n <= 0:
		return
	reconcile()
	batches[ing].append([n, GameState.day, unit_cost(ing) if cost_each < 0.0 else cost_each])
	sync(ing)
	GameState.stock_changed.emit()


## Uses ingredients for cooking or prep: counted as food used today.
func use(ing: String, n: int) -> void:
	reconcile()
	var cost := _remove(ing, n)
	GameState.today["food_used"] = GameState.today.get("food_used", 0.0) + cost
	var u: Dictionary = GameState.today.get("used", {})
	u[ing] = u.get(ing, 0) + n
	GameState.today["used"] = u
	sync(ing)


## Ingredients lost some other way (a bad batch): counted as waste.
func lose(ing: String, n: int, why: String) -> int:
	reconcile()
	n = mini(n, total(ing))
	var cost := _remove(ing, n)
	waste(cost, "%d %s (%s)" % [n, Data.INGREDIENTS[ing]["name"].to_lower(), why])
	sync(ing)
	GameState.stock_changed.emit()
	return n


func waste(cost: float, what: String) -> void:
	GameState.today["waste"] = GameState.today.get("waste", 0.0) + cost
	GameState.today["waste_items"].append(what)


## How many of this ingredient go off tonight.
func expiring(ing: String) -> int:
	reconcile()
	var life: int = Data.INGREDIENTS[ing]["life"]
	var n := 0
	for b in batches[ing]:
		if GameState.day - b[1] + 1 >= life:
			n += b[0]
	return n


## At night: anything past its days is thrown out. Returns the lines for the report.
func spoil() -> Array:
	reconcile()
	var out: Array = []
	for ing in Data.ING_ORDER:
		var life: int = Data.INGREDIENTS[ing]["life"]
		var gone := 0
		var cost := 0.0
		for b in batches[ing].duplicate():
			if GameState.day - b[1] + 1 >= life:
				gone += b[0]
				cost += b[0] * b[2]
				batches[ing].erase(b)
		if gone > 0:
			waste(cost, "%d %s went off" % [gone, Data.INGREDIENTS[ing]["name"].to_lower()])
			out.append([ing, gone, cost])
		sync(ing)
	GameState.stock_changed.emit()
	return out


# ------------------------------------------------------------------ storage

## How much the fridges ("fridge") or freezers ("freezer") hold. Dry shelves have no limit.
func capacity(space: String) -> int:
	if space == "dry" or main == null:
		return 1 << 20
	var n := 0
	for f in main.lot.furniture:
		n += Data.STORAGE.get(f.type, {}).get(space, 0)
	return n


func used(space: String) -> int:
	var n := 0
	for ing in Data.ING_ORDER:
		if Data.INGREDIENTS[ing]["store"] == space:
			n += GameState.stock.get(ing, 0)
	return n


# ------------------------------------------------------------------ ordering and the delivery

## What tonight's order would be: up to the Keep amounts, as far as the space allows.
## Returns {ing: amount}.
func plan_order() -> Dictionary:
	reconcile()
	var want := {}
	for ing in Data.ING_ORDER:
		want[ing] = maxi(0, GameState.target.get(ing, 0) - GameState.stock.get(ing, 0))
	short_fit = {}
	for space in ["fridge", "freezer"]:
		var room := maxi(0, capacity(space) - used(space))
		var asked := 0
		for ing in want:
			if Data.INGREDIENTS[ing]["store"] == space:
				asked += want[ing]
		if asked <= room or asked == 0:
			continue
		# not everything fits: cut each ingredient back by the same share
		var share := float(room) / asked
		for ing in want:
			if Data.INGREDIENTS[ing]["store"] == space:
				var fit := int(floor(want[ing] * share))
				if fit < want[ing]:
					short_fit[ing] = want[ing] - fit
				want[ing] = fit
	return want


func order_cost(order: Dictionary) -> float:
	var c := 0.0
	for ing in order:
		c += order[ing] * unit_cost(ing)
	return c


## Called at night: places tomorrow's order. You pay when it arrives.
func place_order() -> void:
	pending = plan_order()
	pending_cost = order_cost(pending)


## Called when the day starts: when will the van come?
func schedule_delivery() -> void:
	delivery_at = -1.0
	delivery_late = false
	var n := 0
	for ing in pending:
		n += pending[ing]
	if n <= 0:
		return
	var start: float = GameState.prep_min()
	if randf() < Data.DELIVERY_LATE:
		delivery_late = true
		delivery_at = GameState.open_min() + randf_range(30.0, 90.0)
	else:
		delivery_at = start + randf_range(8.0, 30.0)


func tick(_minutes: float) -> void:
	if delivery_at >= 0.0 and GameState.minute >= delivery_at:
		delivery_at = -1.0
		arrive()


## The van is here: pay for the order and put it away. Sometimes something's missing.
func arrive() -> void:
	var cost := order_cost(pending)
	if cost <= 0.0:
		pending = {}
		return
	if GameState.money < cost:
		GameState.toast.emit("The delivery driver won't unload: the bill is $%d and you can't pay it." % int(ceil(cost)), "bad")
		GameState.today["delivery_refused"] = true
		pending = {}
		pending_cost = 0.0
		return
	GameState.add_money(-cost)
	GameState.today["delivery_cost"] = GameState.today.get("delivery_cost", 0.0) + cost
	var short_ing := ""
	if randf() < Data.DELIVERY_SHORT:
		var options: Array = pending.keys().filter(func(i): return pending[i] >= 8)
		if not options.is_empty():
			short_ing = options.pick_random()
	for ing in pending:
		var n: int = pending[ing]
		if ing == short_ing:
			n = n / 2
		add(ing, n)
	var missing := 0
	if short_ing != "":
		missing = pending[short_ing] - pending[short_ing] / 2
		# you don't pay for what didn't come
		var refund := missing * unit_cost(short_ing)
		GameState.add_money(refund)
		GameState.today["delivery_cost"] -= refund
	pending = {}
	pending_cost = 0.0
	van_until = GameState.minute + 8.0
	Sfx.play("door", -6.0)
	if delivery_late:
		GameState.toast.emit("The delivery finally turned up, $%d." % int(ceil(cost)), "")
		Crew.log_line("The delivery came late, after opening.", "supplies")
	else:
		GameState.toast.emit("The morning delivery is here ($%d)." % int(ceil(cost)), "")
	delivered.emit()
	if short_ing != "":
		Events.start_short_delivery(short_ing, missing)


# ------------------------------------------------------------------ morning prep

func is_preppable(dish: String) -> bool:
	return Data.DISHES[dish].get("prep", false)


func ready_portions(dish: String) -> int:
	return prepped.get(dish, 0)


## When the day starts: jobs to prep each dish up to its Prep amount.
func post_prep_jobs() -> void:
	if main == null or main.lot.of_type("prep").is_empty():
		return
	for d in Data.DISH_ORDER:
		if not is_preppable(d) or not GameState.dish_on(d):
			continue
		var want: int = prep_par.get(d, 0) - ready_portions(d)
		while want > 0:
			var n := mini(want, Data.PREP_BATCH)
			JobBoard.post("cook", "prep", {"dish": d, "count": n, "items": []})
			want -= n


## At night: prepped food doesn't keep. Returns portions thrown out.
func toss_prep() -> int:
	var n := 0
	var bits: Array = []
	var cost := 0.0
	for d in prepped:
		var k: int = prepped[d]
		if k <= 0:
			continue
		n += k
		bits.append("%d %s" % [k, Data.DISHES[d]["name"].to_lower()])
		for ing in Data.DISHES[d]["needs"]:
			cost += k * Data.DISHES[d]["needs"][ing] * unit_cost(ing)
	prepped = {}
	if n > 0:
		waste(cost, "prepped %s left over" % ", ".join(bits))
	return n


## Which of these items will cook from prepped portions (without taking them).
func prepped_part(items: Array) -> Array:
	var left := prepped.duplicate()
	var out: Array = []
	for d in items:
		if left.get(d, 0) > 0:
			left[d] -= 1
			out.append(d)
	return out


## The items still needing raw ingredients once prepped portions are used.
func raw_part(items: Array) -> Array:
	var raw := items.duplicate()
	for d in prepped_part(items):
		raw.erase(d)
	return raw


## Takes prepped portions for these items. Returns the ones it took.
func take_prepped(items: Array) -> Array:
	var took := prepped_part(items)
	for d in took:
		prepped[d] -= 1
	return took


func give_back_prepped(items: Array) -> void:
	for d in items:
		prepped[d] = prepped.get(d, 0) + 1


# ------------------------------------------------------------------ sold out

## A dish on the menu that can't be made now because the ingredients ran out.
func is_sold_out(dish: String) -> bool:
	if not GameState.dish_on(dish):
		return false
	return ready_portions(dish) <= 0 and not GameState.has_ingredients(dish)


## Checked every so often while open: tells you when something runs out.
func check_sold_out() -> void:
	for d in Data.DISH_ORDER:
		var out := is_sold_out(d)
		if out and not sold_out.has(d):
			sold_out[d] = true
			var name_: String = Data.DISHES[d]["name"].to_lower()
			GameState.toast.emit("We're out of %s! It's off the menu until more comes in." % name_, "bad")
			Crew.log_line("86 on %s: the kitchen ran out." % name_, "supplies")
			GameState.today["sold_out"].append(d)
			GameState.menu_changed.emit()
		elif not out and sold_out.has(d):
			sold_out.erase(d)
			GameState.menu_changed.emit()


# ------------------------------------------------------------------ saves

func save_data() -> Dictionary:
	return {"batches": batches, "prep_par": prep_par, "pending": pending, "yesterday": yesterday, "used_yesterday": used_yesterday}


func load_data(d: Dictionary) -> void:
	reset()
	for ing in Data.ING_ORDER:
		batches[ing] = []      # older saves: reconcile() makes a fresh batch from the stock
	if d.has("batches"):
		for ing in Data.ING_ORDER:
			batches[ing] = []
			for b in d["batches"].get(ing, []):
				batches[ing].append([int(b[0]), int(b[1]), float(b[2])])
	for k in d.get("prep_par", {}):
		if Data.DISHES.has(k):
			prep_par[k] = int(d["prep_par"][k])
	for k in d.get("pending", {}):
		if Data.INGREDIENTS.has(k):
			pending[k] = int(d["pending"][k])
	pending_cost = order_cost(pending)
	for k in d.get("yesterday", {}):
		yesterday[k] = int(d["yesterday"][k])
	for k in d.get("used_yesterday", {}):
		used_yesterday[k] = int(d["used_yesterday"][k])
