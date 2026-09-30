extends Node
## The business side beyond the dining room:
##   suppliers: the farmer, the baker, the dairy and the butcher each know you.
##     Pay on time and they like you (a little cheaper, never short, the odd
##     free box); a weekly contract takes 10% off for a small fee.
##   catering: now and then someone asks you to cater a wedding or a team
##     banquet. Accept it, and the cooks prep the order that morning; the van
##     picks it up at noon and you're paid for what's ready.

signal changed

var reps: Dictionary = {}        # rep key -> {"rel": 0..100, "contract": bool}
var catering: Array = []         # {"id", "client", "day", "dishes": {dish: n}, "pay", "state"}
var next_id := 1


func reset() -> void:
	reps = {}
	for k in Data.SUPPLIER_REPS:
		reps[k] = {"rel": 50.0, "contract": false}
	catering = []
	next_id = 1


# ------------------------------------------------------------------ suppliers

func rep_for(ing: String) -> String:
	for k in Data.SUPPLIER_REPS:
		if ing in Data.SUPPLIER_REPS[k]["items"]:
			return k
	return ""


## Their price for this ingredient: a contract takes 10% off; they're dearer
## when they don't trust you, and a touch cheaper when they like you.
func cost_mult(ing: String) -> float:
	var k := rep_for(ing)
	if k == "" or not reps.has(k):
		return 1.0
	var r: Dictionary = reps[k]
	var m := 1.0
	if r["contract"]:
		m *= 1.0 - Data.CONTRACT_DISCOUNT
	if r["rel"] < 30.0:
		m *= 1.1
	elif r["rel"] >= 80.0:
		m *= 0.97
	return m


## A supplier who likes you never leaves you short.
func never_short(ing: String) -> bool:
	var k := rep_for(ing)
	return k != "" and reps.has(k) and reps[k]["rel"] >= 80.0


## After the morning delivery: paid on time, or turned away.
func after_delivery(paid: bool, items: Array) -> void:
	var seen := {}
	for ing in items:
		var k := rep_for(ing)
		if k == "" or seen.has(k):
			continue
		seen[k] = true
		reps[k]["rel"] = clampf(reps[k]["rel"] + (Data.REP_PAID if paid else -Data.REP_UNPAID), 0.0, 100.0)
		# a supplier who likes you slips in something extra now and then
		if paid and reps[k]["rel"] >= 85.0 and randf() < 0.12:
			var ing2: String = Data.SUPPLIER_REPS[k]["items"].pick_random()
			Stock.add(ing2, 6, 0.0)
			Crew.log_line("%s threw in a free box of %s. \"For my favourite diner.\"" % [Data.SUPPLIER_REPS[k]["name"], Data.INGREDIENTS[ing2]["name"].to_lower()], "supplies")
	changed.emit()


## With the weekly bills: contract fees, and each rep's visit for coffee.
func weekly() -> float:
	var fees := 0.0
	for k in reps:
		if reps[k]["contract"]:
			fees += Data.CONTRACT_FEE
		var feel: float = (GameState.rating - 3.3) * 4.0 + (3.0 if GameState.grade == "A" else 0.0)
		reps[k]["rel"] = clampf(reps[k]["rel"] + feel, 0.0, 100.0)
	var k2: String = reps.keys().pick_random() if not reps.is_empty() else ""
	if k2 != "":
		Crew.log_line("%s came by for coffee and a chat about the orders." % Data.SUPPLIER_REPS[k2]["name"], "supplies")
	if fees > 0.0:
		GameState.add_money(-fees)
	changed.emit()
	return fees


func set_contract(k: String, on: bool) -> void:
	if reps.has(k):
		reps[k]["contract"] = on
		changed.emit()


# ------------------------------------------------------------------ catering

## Now and then, a catering job is offered for a day or two from now.
func nightly() -> void:
	for c in catering:
		if c["state"] == "offer" and int(c["day"]) <= GameState.day + 1:
			c["state"] = "expired"
	catering = catering.filter(func(c): return c["state"] in ["offer", "accepted"] or int(c["day"]) >= GameState.day - 7)
	var open_offers := catering.filter(func(c): return c["state"] == "offer").size()
	if GameState.rep_level >= 1 and open_offers < 2 and randf() < Data.CATERING_CHANCE:
		var dishes: Array = Data.DISH_ORDER.filter(func(d): return Stock.is_preppable(d) and GameState.dish_known(d))
		dishes.shuffle()
		var order := {}
		var pay := 0.0
		for d in dishes.slice(0, randi_range(2, 3)):
			var n := randi_range(12, 30)
			order[d] = n
			pay += n * Data.DISHES[d]["price"] * Data.CATERING_PAY
		var client: String = Data.CATERING_CLIENTS.pick_random()
		catering.append({"id": next_id, "client": client, "day": GameState.day + randi_range(2, 4), "dishes": order, "pay": snappedf(pay, 10.0), "state": "offer"})
		next_id += 1
		GameState.toast.emit("A catering request: %s, $%d. See the Office." % [client, int(pay)], "good")
	changed.emit()


func accept(id: int, yes: bool) -> void:
	for c in catering:
		if c["id"] == id and c["state"] == "offer":
			c["state"] = "accepted" if yes else "declined"
			if yes:
				Crew.log_line("You took the catering job: %s on %s." % [c["client"], Town.date_text(int(c["day"]))], "van")
	changed.emit()


func today_job() -> Dictionary:
	for c in catering:
		if c["state"] == "accepted" and int(c["day"]) == GameState.day:
			return c
	return {}


## The morning of a catering job: the cooks prep the whole order.
func post_prep() -> void:
	var c := today_job()
	if c.is_empty() or Crew.main == null or Crew.main.lot.of_type("prep").is_empty():
		return
	for d in c["dishes"]:
		var want: int = c["dishes"][d]
		while want > 0:
			var n := mini(want, Data.PREP_BATCH)
			JobBoard.post("cook", "prep", {"dish": d, "count": n, "items": []})
			want -= n


## At noon the van comes for it: paid for what's ready.
func tick(_minutes: float) -> void:
	var c := today_job()
	if c.is_empty() or GameState.minute < Data.CATERING_PICKUP:
		return
	var total := 0
	var ready := 0
	for d in c["dishes"]:
		var n: int = c["dishes"][d]
		total += n
		var have := mini(n, Stock.ready_portions(d))
		Stock.prepped[d] = Stock.ready_portions(d) - have
		ready += have
	var share := float(ready) / maxf(1.0, total)
	var paid: float = c["pay"] * share
	GameState.add_money(paid)
	GameState.today["revenue"] += paid
	GameState.today["catering"] = paid
	c["state"] = "done" if share >= 0.99 else "short"
	if share >= 0.99:
		GameState.toast.emit("The catering van picked up %s: all %d plates. +$%d." % [c["client"], total, int(paid)], "good")
		Moments.note_scrapbook("catering", "Catered %s" % c["client"], "%d plates, all ready on time." % total)
	else:
		GameState.toast.emit("The catering van picked up %s, but only %d of %d plates were ready. +$%d." % [c["client"], ready, total, int(paid)], "bad")
	Crew.log_line("Catering for %s: %d of %d plates ready." % [c["client"], ready, total], "van")
	changed.emit()


# ------------------------------------------------------------------ saves

func save_data() -> Dictionary:
	return {"reps": reps, "catering": catering, "next_id": next_id}


func load_data(d: Dictionary) -> void:
	reset()
	for k in d.get("reps", {}):
		if reps.has(k):
			reps[k] = {"rel": float(d["reps"][k].get("rel", 50.0)), "contract": bool(d["reps"][k].get("contract", false))}
	for c in d.get("catering", []):
		var dishes := {}
		for k in c.get("dishes", {}):
			if Data.DISHES.has(k):
				dishes[k] = int(c["dishes"][k])
		catering.append({"id": int(c["id"]), "client": str(c["client"]), "day": int(c["day"]), "dishes": dishes, "pay": float(c["pay"]), "state": str(c["state"])})
	next_id = int(d.get("next_id", 1))
