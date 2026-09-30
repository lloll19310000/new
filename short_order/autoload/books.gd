extends Node
## The money side of running a diner:
##   - weekly bills: rent (more land, more rent) and utilities (every grill
##     and fridge uses gas or power)
##   - a bank loan, paid back a little each week
##   - tips, which belong to the staff: servers keep their own, or share
##     them with the kitchen. Either way it changes who's happy.
##   - the numbers owners watch: food cost, staff cost and profit margin,
##     each as a share of sales

var main                               # set by main.gd
var tip_policy := "keep"               # "keep" or "share"
var loan := {}                         # {"amount", "owed", "weekly", "interest"} or {} with no loan
var pool := 0.0                        # tips shared today, split at night


func _ready() -> void:
	reset()


func reset() -> void:
	tip_policy = "keep"
	loan = {}
	pool = 0.0


# ------------------------------------------------------------------ bills

func rent_week() -> float:
	var r := 0.0
	for p in Data.PLOTS:
		if GameState.owned.has(p["id"]):
			r += p.get("rent", 0)
	return r


func utilities_week() -> float:
	var u := float(Data.UTILITIES_BASE)
	if main != null:
		for f in main.lot.furniture:
			u += Data.UTILITIES.get(f.type, 0)
	return u


func loan_week() -> float:
	if loan.is_empty():
		return 0.0
	return minf(loan["weekly"], loan["owed"])


func bills_week() -> float:
	return rent_week() + utilities_week() + loan_week()


## 0 means tonight.
func days_to_bills() -> int:
	return (Data.BILL_EVERY - GameState.day % Data.BILL_EVERY) % Data.BILL_EVERY


## Called every night. On bill nights it pays rent, utilities and the loan,
## and returns what was paid: {"rent", "utilities", "loan", "paid_off"}.
func nightly_bills() -> Dictionary:
	if days_to_bills() != 0:
		return {}
	var out := {"rent": rent_week(), "utilities": utilities_week(), "loan": loan_week(), "paid_off": false}
	GameState.add_money(-(out["rent"] + out["utilities"] + out["loan"]))
	out["contracts"] = Biz.weekly()
	out["sister"] = Biz.sister_week()
	out["benefits"] = Books.benefits_week() if has_method("benefits_week") else 0.0
	if not loan.is_empty():
		loan["owed"] -= out["loan"]
		if loan["owed"] <= 0.5:
			loan = {}
			out["paid_off"] = true
	return out


# ------------------------------------------------------------------ the loan

func take_loan(amount: int) -> bool:
	var terms: Dictionary = Data.loan_terms(amount)
	if not loan.is_empty() or terms.is_empty():
		return false
	var owed: float = amount * (1.0 + terms["interest"])
	loan = {"amount": float(amount), "owed": owed, "weekly": owed / terms["weeks"], "interest": terms["interest"]}
	GameState.add_money(amount)
	GameState.toast.emit("The bank lent you $%s. You'll pay back $%d with each week's bills." % [UiKit.thousands(amount), int(ceil(loan["weekly"]))], "good")
	Crew.log_line("You took out a $%s loan." % UiKit.thousands(amount), "money")
	return true


## Paying it all back early skips the interest still to come.
func payoff_cost() -> float:
	if loan.is_empty():
		return 0.0
	return loan["owed"] / (1.0 + loan.get("interest", 0.12))


func pay_off() -> bool:
	if loan.is_empty():
		return false
	var cost := payoff_cost()
	if not GameState.spend(cost):
		return false
	loan = {}
	GameState.toast.emit("You paid off the loan ($%s)." % UiKit.thousands(int(ceil(cost))), "good")
	return true


# ------------------------------------------------------------------ tips

## A table left a tip. Their own server (who took the order) gets most of it,
## and whoever ran food to the table splits the rest. With "keep", each person
## takes home what they earned; with "share", it all goes in the pot that's
## split between everyone at night.
func add_tip(amount: float, servers: Array, main_server = null) -> void:
	if amount <= 0.0:
		return
	GameState.today["tips"] += amount
	var ok := func(s): return s != null and is_instance_valid(s) and GameState.staff.has(s)
	var runners: Array = servers.filter(ok)
	var shares := {}
	if ok.call(main_server):
		shares[main_server] = amount * (Data.TIP_SERVER_SHARE if not runners.is_empty() else 1.0)
		for s in runners:
			shares[s] = shares.get(s, 0.0) + amount * (1.0 - Data.TIP_SERVER_SHARE) / runners.size()
	else:
		for s in runners:
			shares[s] = shares.get(s, 0.0) + amount / runners.size()
	if shares.is_empty():
		pool += amount
		return
	for s in shares:
		s.tips_earned += shares[s]
		if tip_policy == "keep":
			s.tips_today += shares[s]
	if tip_policy == "share":
		pool += amount


## Someone picked up the money a table left: the bill goes in the till and the
## tip to the table's servers. Returns true if there was any.
func collect_table(t, _by = null) -> bool:
	if t == null or t.cash <= 0.0:
		return false
	var bill: float = t.cash - t.cash_tip
	GameState.add_money(bill)
	GameState.today["revenue"] += bill
	GameState.totals["earned"] += bill
	add_tip(t.cash_tip, t.cash_servers, t.cash_server)
	if main != null:
		main.lot.fx.money(t.center_px() + Vector2(0, -8), bill, false, t.cash_tip)
	Sfx.play("cash", -6.0)
	t.cash = 0.0
	t.cash_tip = 0.0
	t.cash_server = null
	t.cash_servers = []
	if main != null:
		main.lot.queue_redraw()
	return true


## At night: the shared pot is split, and tips (or the lack of them) change moods.
## Returns lines for the report.
func settle_tips() -> Array:
	var worked: Array = GameState.staff.filter(func(s): return is_instance_valid(s) and s.worked_today)
	var out: Array = []
	if worked.is_empty():
		pool = 0.0
		return out
	if pool > 0.0:
		for s in worked:
			s.tips_today += pool / worked.size()
	var total := 0.0
	for s in worked:
		total += s.tips_today
	pool = 0.0
	if total < 1.0:
		return out
	# good tips make a day better
	for s in worked:
		s.add_stress(-minf(Data.TIP_STRESS_MAX, Data.TIP_STRESS * s.tips_today / maxf(1.0, Shifts.pay_today(s))), "good tips")
	if tip_policy == "keep":
		# each server takes home what their tables left them
		var earners: Array = worked.filter(func(s): return s.tips_today >= 1.0)
		earners.sort_custom(func(a, b): return a.tips_today > b.tips_today)
		var bits: Array = earners.map(func(s): return "%s $%d" % [s.person_name, int(round(s.tips_today))])
		out.append(["money", "#6cc3a0", "Tips, each server keeps their own: [b]%s[/b]." % ", ".join(bits)])
		# people who never serve a table (the kitchen, the dish pit) see the servers walk off with them
		var top = earners[0] if not earners.is_empty() else null
		var grumbles: Array = []
		if top != null and top.tips_today >= 40.0:
			for s in worked:
				if s.tips_earned < 1.0 and s.tips_today < 1.0:
					Crew.add(s, top, "tips_keep")
					s.add_stress(2.0, "no tips")
					grumbles.append(s.person_name)
		if not grumbles.is_empty():
			Crew.log_line("%s got no tips today and noticed who did." % Crew.and_list(grumbles), "money", [top])
			out.append(["money", "#f2c14e", "%s got no tips and grumbled a little. Sharing tips keeps the kitchen happier." % Crew.and_list(grumbles)])
	else:
		# sharing: the kitchen's grateful, big earners feel a little short-changed
		var share: float = total / worked.size()
		for s in worked:
			if s.tips_earned - share >= 20.0:
				s.add_stress(2.0, "sharing their tips")
			elif s.tips_earned < share * 0.5:
				for o in worked:
					if o != s and o.tips_earned > share:
						Crew.add(s, o, "tips_share")
		out.append(["money", "#6cc3a0", "Tips were shared: [b]$%d[/b] each for %d people." % [int(share), worked.size()]])
	return out


## Everyone's tips start at zero each morning.
func reset_tips() -> void:
	pool = 0.0
	for s in GameState.staff:
		if is_instance_valid(s):
			s.tips_today = 0.0
			s.tips_earned = 0.0
			s.worked_today = false


# ------------------------------------------------------------------ the numbers

## Food cost, staff cost and profit, each as a share of sales. bills: the week's
## rent and utilities spread over its days.
func numbers(sales: float, food: float, staff: float, other: float = 0.0) -> Dictionary:
	var bills := (rent_week() + utilities_week()) / Data.BILL_EVERY
	var profit := sales - food - staff - bills - other
	var s := maxf(sales, 1.0)
	return {"food": food / s, "staff": staff / s, "profit": profit, "margin": profit / s, "bills": bills}


# ------------------------------------------------------------------ saves

func save_data() -> Dictionary:
	return {"tip_policy": tip_policy, "loan": loan}


func load_data(d: Dictionary) -> void:
	reset()
	tip_policy = d.get("tip_policy", "keep") if d.get("tip_policy", "keep") in ["keep", "share"] else "keep"
	var l: Dictionary = d.get("loan", {})
	if l.has("owed"):
		loan = {"amount": float(l.get("amount", 0.0)), "owed": float(l["owed"]), "weekly": float(l.get("weekly", 0.0)), "interest": float(l.get("interest", 0.12))}
