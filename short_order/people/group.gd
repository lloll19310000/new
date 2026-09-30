extends Node
## A group of customers going through one visit:
## arriving -> waiting -> to_table -> seated -> ordered -> eating -> paying -> leaving -> gone
## (an unhappy table may stop at "complaining" on the way to paying)
##
## kind (see Data.CUSTOMERS) changes their patience, what they order and how
## fussy they are. Some kinds work differently:
## - "takeout" goes to the takeout window, orders, waits, pays and leaves.
## - "driver" is a delivery app driver: the order comes in over the app as
##   they set off, and they pick it up at the takeout window.
## - "inspector" walks around the kitchen and gives the diner a health grade.
## A group can also be a booking (a table is held for them) or one of your
## named regulars (see autoload/front.gd).

const Customer = preload("res://people/customer.gd")

var lot
var kind := "regular"
var members: Array = []
var state := "arriving"
var table = null           # the table they sit at, or the takeout window
var takeout := false
var app := false           # a delivery app order
var waited := 0.0          # minutes waiting for a table
var order_wait := 0.0      # minutes seated before the order is taken
var food_wait := 0.0       # minutes from ordering to the last dish arriving
var eat_left := 0.0
var t_table := 0.0
var t_order := 0.0
var t_food := 0.0
var expected := 0
var missing := 0
var ordered_items: Array = []
var received: Array = []
var qualities: Array = []
var bill := 0.0
var exit_cell := Vector2i.ZERO
var chatty_service := false
var cooked_by: Array = []  # staff who cooked for this group
var served_by: Array = []  # staff who brought the food
var staff_trouble := {}    # things they saw staff do: "staff arguing" -> stars lost
var stops: Array = []      # inspector: furniture still to look at
var stop_wait := 0.0
# the front of house
var greeted := false       # a host said hello: they wait longer for a table
var booking = null         # the booking they made (a Dictionary in Front.bookings), or null
var regular = null         # one of your named regulars (a Dictionary in Front.regulars), or null
var fav_served := false    # their favourite server took the order
var pay_wait := 0.0        # minutes waiting to pay
var pay_spot = null        # the till they're paying at, or null (paying at the table)
var comped := false        # the meal's on the house
var complaint_wait := 0.0
var complaint_what := ""
var review_bonus := 0.0    # a manager apologised, the meal was comped...
var extra_hits := {}       # other things that went wrong: reason -> stars
# the kitchen
var order_taker = null     # the server who wrote the order down
var mixups: Array = []     # [wrong dish on the ticket, the dish they wanted]
var remakes := 0           # dishes being made again after going back
var sold_out_hits := 0     # people whose first choice had sold out
var allergy := ""          # an ingredient one of them can't eat (Data.ALLERGENS), or ""
var allergy_flagged := false   # the server put it on the ticket
var allergic_items: Array = [] # that person's dishes not served yet
# health
var restroom_in := -1.0    # minutes until one of them goes to the restroom, or -1
var saw_mouse := false


func info() -> Dictionary:
	return Data.CUSTOMERS[kind]


func start(lot_ref, size: int, parent: Node, kind_: String = "regular", window = null, extra: Dictionary = {}) -> void:
	lot = lot_ref
	kind = kind_
	app = kind == "driver"
	takeout = kind == "takeout" or app
	booking = extra.get("booking")
	regular = extra.get("regular")
	var spawns: Array = lot.spawn_cells()
	var from: Vector2i = spawns.pick_random()
	exit_cell = spawns.pick_random()
	for i in size:
		var c := Customer.new()
		c.setup(lot, self, i)
		parent.add_child(c)
		c.place_at(from)
		members.append(c)
	if regular != null and not members.is_empty():
		members[0].skin = regular["skin"]
		members[0].hair = regular["hair"]
		members[0].shirt = regular["shirt"]
		members[0].queue_redraw()
	if booking != null:
		booking["group"] = self
	if Data.DASH_KIND.has(kind) or kind in ["takeout", "driver", "critic", "celebrity"]:
		if randf() < Data.ALLERGY_CHANCE:
			allergy = Data.ALLERGENS.keys().pick_random()
	if kind != "inspector":
		GameState.today["groups"] += 1
		GameState.today["types"][kind] = GameState.today["types"].get(kind, 0) + 1
		if regular != null:
			GameState.today["regulars"] += 1
		if booking != null:
			GameState.today["bookings"] += 1
	var goal: Vector2i = lot.entry_inside
	if takeout:
		table = window
		table.group = self
		goal = lot.window_outside(window)
	if app:
		# the order comes in over the app while the driver is on the way
		place_order()
		GameState.today["app_orders"] += 1
	for m in members:
		if not m.go_to(goal):
			leave(0.0, "", false)
			return


func tick(minutes: float) -> void:
	var patience: float = info()["patience"]
	match state:
		"arriving":
			if not anyone_moving():
				if kind == "inspector":
					begin_inspection()
				elif takeout:
					state = "seated"
					JobBoard.post("serve", "take_order", {"group": self})
				else:
					state = "waiting"
					Sfx.play("door", -6.0)
		"waiting":
			waited += minutes
			if not greeted and Front.host_working() and not JobBoard.has_open("greet", "group", self):
				JobBoard.post("host", "greet", {"group": self})
			try_seat()
			if state == "waiting" and waited > table_patience():
				GameState.today["complaints"]["No free table"] = GameState.today["complaints"].get("No free table", 0) + 1
				lot.fx.add(members[0].position, "No table, leaving", Color("ff8f7a"))
				# a critic writes about it anyway
				leave(2.0 if kind == "critic" else 0.0, "No free table", false)
			redraw_members()
		"to_table":
			waited += minutes
			if not anyone_moving():
				sit_down()
		"seated":
			order_wait += minutes
			if order_wait > Data.ORDER_PATIENCE * patience:
				leave(1.5, "Nobody took our order", false)
			redraw_members()
		"ordered":
			food_wait += minutes
			restroom_tick(minutes)
			if food_wait > Data.FOOD_PATIENCE * patience:
				if app:
					cancel_app()
				else:
					leave(1.0, "The food never came", false)
			redraw_members()
		"pickup":
			# an app order is bagged and waiting at the window for the driver
			if not anyone_moving():
				pay_app()
		"eating":
			eat_left -= minutes
			restroom_tick(minutes)
			if eat_left <= 0.0:
				finish_meal()
		"complaining":
			complaint_wait += minutes
			if complaint_wait > Data.COMPLAINT_WAIT:
				extra_hits["nobody came to listen"] = 0.3
				start_paying()
			redraw_members()
		"paying":
			pay_wait += minutes
			try_dash(minutes)
			if state == "paying" and pay_wait > Data.PAY_GIVE_UP:
				# they give up waiting: the money goes on the table (or the till's counter) and they go
				if pay_spot == null:
					leave_cash()
				else:
					settle()
			redraw_members()
		"inspecting":
			inspect_tick(minutes)
		"leaving":
			if not anyone_moving():
				for m in members:
					m.queue_free()
				members.clear()
				state = "gone"
				queue_free()
	for m in members:
		if is_instance_valid(m) and m.get("errand") != null and m.errand != "":
			m.errand_tick(minutes)


## Someone needs the restroom: off they go (or they mind that there isn't one).
func restroom_tick(minutes: float) -> void:
	if restroom_in < 0.0:
		return
	restroom_in -= minutes
	if restroom_in > 0.0:
		return
	restroom_in = -1.0
	if Health.toilets().is_empty():
		extra_hits["no restroom"] = Data.NO_RESTROOM
		return
	var m = members.pick_random()
	var t = Health.free_toilet(m.current_cell())
	if t == null:
		t = Health.toilets().pick_random()
	if not m.start_restroom(t):
		extra_hits["no restroom"] = Data.NO_RESTROOM


func table_patience() -> float:
	var p: float = Data.TABLE_PATIENCE * info()["patience"]
	if greeted:
		p *= Data.GREET_PATIENCE
	if booking != null:
		p *= 1.5
	return p


func anyone_moving() -> bool:
	for m in members:
		if m.is_moving():
			return true
	return false


func redraw_members() -> void:
	for m in members:
		m.queue_redraw()


## 1 = full patience, 0 = about to leave, -1 = not waiting for anything.
func patience_left() -> float:
	var p: float = info()["patience"]
	match state:
		"waiting": return 1.0 - waited / table_patience()
		"seated": return 1.0 - order_wait / (Data.ORDER_PATIENCE * p)
		"ordered": return 1.0 - food_wait / (Data.FOOD_PATIENCE * p)
		"complaining": return 1.0 - complaint_wait / Data.COMPLAINT_WAIT
		"paying": return 1.0 - pay_wait / Data.PAY_GIVE_UP
	return -1.0


## Dishes ordered that haven't arrived yet (for the order bubble).
func waiting_for() -> Array:
	var left := ordered_items.duplicate()
	for d in received:
		left.erase(d)
	return left


## "Table 3", "Takeout", "App order", for tickets and the log.
func label() -> String:
	if app:
		return "App order"
	if takeout:
		return "Takeout"
	if table != null and table.is_table():
		return "Table %d" % lot.table_number(table)
	return Data.CUSTOMERS[kind]["name"]


# ------------------------------------------------------------------ seating

func try_seat() -> void:
	var best = null
	# a booked table waits for them
	if booking != null and booking.get("table") != null and lot.furniture.has(booking["table"]):
		var bt = booking["table"]
		if bt.group == null and bt.dirty_plates == 0 and bt.chairs.size() >= members.size():
			best = bt
	if best == null:
		for t in lot.tables():
			if not t.table_free() or t.chairs.size() < members.size():
				continue
			if t.reserved != null and t.reserved != booking:
				continue
			if best == null or t.chairs.size() < best.chairs.size() or (t.chairs.size() == best.chairs.size() and \
					(int(likes_seat(t)) > int(likes_seat(best)) or (likes_seat(t) == likes_seat(best) and lot.distance(t.cell, lot.entry_inside) < lot.distance(best.cell, lot.entry_inside)))):
				best = t
	if best == null:
		if booking != null and waited > 8.0:
			extra_hits["our booked table wasn't ready"] = 0.5
		return
	table = best
	table.group = self
	if likes_seat(best):
		review_bonus += Data.SEAT_LIKED_REVIEW
	if booking != null:
		Front.release(booking)
		if waited < 4.0:
			review_bonus += Data.BOOKING_REVIEW
		booking["state"] = "seated"
	for i in members.size():
		var ch = table.chairs[i]
		ch.occupant = members[i]
		members[i].seat = ch
		members[i].offset = Vector2.ZERO
		if not members[i].go_to(ch.cell):
			leave(1.0, "Couldn't reach the table", false)
			return
	t_table = waited
	state = "to_table"


## Couples and families love a booth; people on their own (truckers, regulars) like the counter.
func likes_seat(t) -> bool:
	if t == null:
		return false
	if members.size() == 1 and kind in Data.COUNTER_KINDS:
		return t.is_counter()
	if members.size() >= 2:
		var booths := 0
		for ch in t.chairs:
			if ch.type == "booth":
				booths += 1
		return booths >= mini(members.size(), t.chairs.size())
	return false


func sit_down() -> void:
	for m in members:
		m.sitting = true
		m.place_at(m.seat.cell)
		m.face_toward(table.center_px())
	state = "seated"
	var j = JobBoard.post("serve", "take_order", {"group": self})
	# a regular's favourite server gets first go at their table
	if regular != null:
		var fav = Front.fav_staff(regular)
		if fav != null and fav.is_here() and fav.priorities.get("serve", 0) > 0:
			j.pref = fav


# ------------------------------------------------------------------ ordering and eating

func makeable(d: String) -> bool:
	return GameState.dish_on(d) and lot.can_make(d) and (Stock.ready_portions(d) > 0 or GameState.has_ingredients(d))


## Picks one dish: favourites (likes) and today's special are likelier.
func pick(options: Array) -> String:
	var likes: Array = info()["likes"]
	var breakfast := GameState.minute < 10.5 * 60.0
	var bag: Array = []
	for d in options:
		bag.append(d)
		if d in likes:
			bag.append(d)
			bag.append(d)
		if breakfast and d in Data.BREAKFAST_LIKES:
			bag.append(d)
			bag.append(d)
		if d == GameState.special:
			for i in Data.SPECIAL_PICKS - 1:
				bag.append(d)
	return bag.pick_random()


## Called when a server finishes taking the order (server is null for app
## orders, which come in over the app).
func place_order(server = null) -> void:
	if state != "seated" and not (app and state == "arriving"):
		return
	t_order = order_wait
	order_taker = server
	if server != null and regular != null and Front.fav_staff(regular) == server:
		fav_served = true
	var chances: Array = info()["order"]
	var courses := ["main", "side", "drink", "dessert"]
	var wanted: Array = []   # on the menu with a working station, sold out or not
	var can: Array = []      # what the kitchen can actually make right now
	for k in courses:
		wanted.append(Data.DISH_ORDER.filter(func(d): return Data.DISHES[d]["kind"] == k and GameState.dish_on(d) and lot.can_make(d)))
		can.append(Data.DISH_ORDER.filter(func(d): return Data.DISHES[d]["kind"] == k and makeable(d)))
	var order: Array = []
	for i in members.size():
		var mine: Array = []
		# the one with the allergy steers clear of it
		var safe := func(d): return i != 0 or allergy == "" or not Data.DISHES[d]["needs"].has(allergy)
		# a regular (the first of their party) has their usual
		if i == 0 and regular != null:
			for d in regular["usual"]:
				if makeable(d) and safe.call(d):
					mine.append(d)
				else:
					extra_hits["their usual wasn't on"] = 0.4
		if mine.is_empty():
			for c in courses.size():
				if c >= chances.size() or randf() >= chances[c]:
					continue
				var w: Array = wanted[c].filter(safe)
				if w.is_empty():
					continue
				var d: String = pick(w)
				if not makeable(d):
					# their first choice has sold out: they settle for something else
					sold_out_hits += 1
					var alt: Array = can[c].filter(safe)
					if alt.is_empty():
						continue
					d = pick(alt)
				mine.append(d)
		if i == 0 and allergy != "":
			allergic_items = mine.duplicate()
		order.append_array(mine)
	if sold_out_hits > 0:
		extra_hits["their first choice was sold out"] = minf(0.5, Data.SOLD_OUT_REVIEW * sold_out_hits)
	if order.is_empty():
		if app:
			cancel_app()
		else:
			leave(1.0, "Nothing on the menu they could get", false)
		return
	ordered_items = order.duplicate()
	for d in order:
		GameState.today["dishes"][d] = GameState.today["dishes"].get(d, 0) + 1
	# the server writes it down, and now and then gets a dish wrong
	var ticket: Array = order.duplicate()
	if server != null and randf() < wrong_chance(server):
		var idxs: Array = range(ticket.size())
		idxs.shuffle()
		for idx in idxs:
			var right: String = ticket[idx]
			var k: String = Data.DISHES[right]["kind"]
			var alts: Array = Data.DISH_ORDER.filter(func(d): return d != right and Data.DISHES[d]["kind"] == k and makeable(d))
			if alts.is_empty():
				continue
			ticket[idx] = alts.pick_random()
			mixups.append([ticket[idx], right])
			break
	if allergy != "":
		allergy_flagged = server == null or randf() >= allergy_miss(server)
	if not takeout and randf() < Data.RESTROOM_CHANCE:
		restroom_in = randf_range(3.0, 25.0)
	# everything for this table made at the same station is cooked together
	var by_station := {}
	for d in ticket:
		var st: String = Data.DISHES[d]["station"]
		if not by_station.has(st):
			by_station[st] = []
		by_station[st].append(d)
	for st in by_station:
		var items: Array = by_station[st]
		JobBoard.post(Data.job_type_for(st), "cook", {"group": self, "dish": items[0], "items": items, "count": items.size(), "station": st})
	expected = ticket.size()
	state = "ordered"


## How likely this server is to write a dish down wrong.
static func wrong_chance(s) -> float:
	var p: float = Data.WRONG_BASE + (10 - s.service) * Data.WRONG_PER_SKILL
	if s.stress >= Data.STRESS_FED_UP:
		p += Data.WRONG_STRESSED
	if s.energy < Data.BREAK_AT:
		p += Data.WRONG_TIRED
	return p


## How likely they are to forget to put an allergy on the ticket.
static func allergy_miss(s) -> float:
	var p: float = Data.ALLERGY_MISS + (10 - s.service) * 0.01
	if s.stress >= Data.STRESS_FED_UP:
		p += 0.05
	if s.has_trait("chatty"):
		p += 0.03
	return p


func item_failed(_dish: String, count: int = 1) -> void:
	expected -= count
	missing += count
	check_all_served()


func receive(dishes: Array, qs: Array, server = null, cooks: Array = []) -> void:
	if state != "ordered":
		return
	if server != null and server.has_trait("chatty"):
		chatty_service = true
	if server != null and not served_by.has(server):
		served_by.append(server)
	for c in cooks:
		if not cooked_by.has(c):
			cooked_by.append(c)
	for i in dishes.size():
		var d: String = dishes[i]
		var pair = take_mixup(d)
		if pair != null:
			send_back(d, pair[1], cooks)
			continue
		if allergy != "" and d in allergic_items:
			allergic_items.erase(d)
			var risk: float = (Data.ALLERGY_RISK_FLAGGED + lot.kitchen_dirt() * 0.2) if allergy_flagged else Data.ALLERGY_RISK_MISSED
			if randf() < risk:
				allergic_reaction(d, cooks)
				return
		received.append(d)
		if not takeout:
			table.food_on_table.append(d)
		bill += GameState.price(d)
		if i < qs.size():
			qualities.append(qs[i])
	lot.queue_redraw()
	check_all_served()


## If this dish is one the server wrote down wrong (and nobody else at the
## table wanted it), returns [wrong, right] and forgets the mix-up.
func take_mixup(d: String):
	for pair in mixups:
		if pair[0] == d and not waiting_for().has(d):
			mixups.erase(pair)
			return pair
	return null


## "That's not what I ordered." The dish goes back and the right one is made.
func send_back(wrong: String, right: String, cooks: Array) -> void:
	var cost := 0.0
	for ing in Data.DISHES[wrong]["needs"]:
		cost += Data.DISHES[wrong]["needs"][ing] * Stock.unit_cost(ing)
	Stock.waste(cost, "a wrong %s sent back" % Data.DISHES[wrong]["name"].to_lower())
	if not takeout and table != null and Data.DISHES[wrong]["plate"]:
		table.dirty_plates += 1
		if not JobBoard.has_open("bus", "furniture", table):
			JobBoard.post("clean", "bus", {"furniture": table})
	remakes += 1
	extra_hits["a wrong order"] = Data.WRONG_REVIEW
	GameState.today["wrong_orders"] += 1
	var job = JobBoard.post(Data.job_type_for(Data.DISHES[right]["station"]), "cook", {"group": self, "dish": right, "items": [right], "count": 1, "station": Data.DISHES[right]["station"]})
	job.remake = true
	var taker = order_taker if order_taker != null and is_instance_valid(order_taker) and GameState.staff.has(order_taker) else null
	var text := "%s got %s instead of %s." % [label(), Data.DISHES[wrong]["name"].to_lower(), Data.DISHES[right]["name"].to_lower()]
	if taker != null:
		text += " %s took the order down wrong." % taker.person_name
		for c in cooks:
			if c != null and is_instance_valid(c) and c != taker and GameState.staff.has(c):
				Crew.add(c, taker, "remake")
				Crew.say(c, "remake", "alert")
	Crew.log_line(text, "alert", [taker] if taker != null else [])
	lot.fx.add(where(), "Wrong order!", Color("ff8f7a"))


## Someone ate what they can't: they're ill, they leave, and it's serious.
func allergic_reaction(d: String, cooks: Array) -> void:
	GameState.today["allergies"] += 1
	GameState.report_allergy()
	var what: String = Data.ALLERGENS[allergy]
	var how := "It was flagged on the ticket, but there was %s in it anyway." % what if allergy_flagged else "Nobody flagged it on the ticket."
	GameState.toast.emit("A customer at %s had an allergic reaction to %s in the %s! They left without paying. %s" % [label().to_lower(), what, Data.DISHES[d]["name"].to_lower(), how], "bad")
	Crew.log_line("Allergic reaction at %s: %s in the %s. %s" % [label().to_lower(), what, Data.DISHES[d]["name"].to_lower(), how], "alert")
	Sfx.play("bad_review")
	if order_taker != null and is_instance_valid(order_taker):
		order_taker.add_stress(15.0)
	for c in cooks:
		if c != null and is_instance_valid(c):
			c.add_stress(10.0)
	GameState.add_review(1.0, "an allergic reaction", 2)
	leave(0.0, "", false)


func check_all_served() -> void:
	if state != "ordered":
		return
	if expected <= 0:
		if app:
			cancel_app()
		else:
			leave(1.5, "Out of stock", false)
		return
	if received.size() >= expected:
		t_food = food_wait
		if app:
			if anyone_moving():
				state = "pickup"
			else:
				pay_app()
			return
		if takeout:
			pay_and_go()
			return
		eat_left = randf_range(15.0, 25.0)
		state = "eating"


## Asked to leave (a rowdy table): they go without paying or reviewing,
## and they don't count as unhappy walk-outs.
func kicked_out() -> void:
	var n := members.size()
	leave(0.0, "", false)
	GameState.today["left"] -= n


## Staff misbehaving in front of them (an argument, someone on their phone)
## comes off their review, once for each kind of thing.
func note_trouble(what: String, stars: float) -> void:
	if not staff_trouble.has(what):
		staff_trouble[what] = stars


## The share of the bill a table tips for this score.
static func tip_rate(score: float) -> float:
	if score >= 3.0:
		return Data.TIP_BASE + Data.TIP_PER_STAR * (score - 3.0)
	return maxf(0.0, Data.TIP_BASE - Data.TIP_LOW_PER_STAR * (3.0 - score))


## The table's own server: whoever wrote the order down, if they still work here.
func main_server():
	if order_taker != null and is_instance_valid(order_taker) and GameState.staff.has(order_taker):
		return order_taker
	return null


## Pays the bill. on_table: they leave the money on the table for the staff to
## pick up (see leave_cash); otherwise it goes straight in the till.
func pay(on_table: bool = false) -> float:
	var result := review()
	var score: float = result[0]
	if score >= 4.75:
		Crew.teamwork(cooked_by, served_by)
	var charged := 0.0 if comped else bill
	var tip: float = bill * tip_rate(score) * info()["tip"]
	if regular != null and regular["loyalty"] >= Data.REGULAR_LOYAL:
		tip *= 1.4
	if comped:
		GameState.today["comped"] += bill
	GameState.today["served"] += members.size()
	GameState.totals["served"] += members.size()
	var at: Vector2 = where()
	if on_table and table != null and not takeout:
		table.cash += charged + tip
		table.cash_tip += tip
		table.cash_server = main_server()
		table.cash_servers = served_by.duplicate()
		GameState.today["cash_left"] = GameState.today.get("cash_left", 0) + 1
		if not JobBoard.has_open("collect", "furniture", table):
			JobBoard.post("serve", "collect", {"furniture": table})
		return score
	# the bill is yours; the tip belongs to the staff
	GameState.add_money(charged)
	Books.add_tip(tip, served_by, main_server())
	GameState.today["revenue"] += charged
	GameState.totals["earned"] += charged
	if comped:
		lot.fx.add(at, "On the house", Color("8ae596"))
	else:
		lot.fx.money(at, charged, false, tip)
	Sfx.play("cash", -4.0)
	return score


## Where money and stars float up from.
func where() -> Vector2:
	if pay_spot != null:
		return pay_spot.center_px() + Vector2(0, -8)
	if table != null:
		return table.center_px() + Vector2(0, -8)
	return members[0].position if not members.is_empty() else Vector2.ZERO


func pay_and_go() -> void:
	GameState.today["takeout"] += 1
	var score := pay()
	leave(score, review()[1], true)


## The driver picks up the bag. The app keeps its share, and nobody leaves
## a review of the diner.
func pay_app() -> void:
	var fee := bill * Data.APP_SHARE
	GameState.add_money(bill - fee)
	GameState.today["revenue"] += bill - fee
	GameState.today["app_fees"] += fee
	GameState.today["app_done"] += 1
	GameState.totals["earned"] += bill - fee
	lot.fx.money(where(), bill - fee)
	Sfx.play("cash", -8.0)
	leave(0.0, "", true)


## The app order took too long (or couldn't be made): the driver gives up.
func cancel_app() -> void:
	GameState.today["app_cancelled"] += 1
	Crew.log_line("An app order was cancelled: the driver couldn't wait any longer.", "van")
	var n := members.size()
	leave(0.0, "", false)
	GameState.today["left"] -= n


## Done eating. An unhappy table may ask for the manager first; then they pay.
func finish_meal() -> void:
	var pre := review(false)
	if pre[0] < Data.COMPLAINT_BELOW and Data.DASH_KIND.has(kind) and randf() < Data.COMPLAINT_CHANCE:
		start_complaint(pre[1])
		return
	start_paying()


## Plates to the bus tub, crumbs on the floor, chairs free: they're done with the table.
func leave_table() -> void:
	if table == null or takeout:
		return
	var plates := 0
	for d in received:
		if Data.DISHES[d]["plate"]:
			plates += 1
	table.food_on_table.clear()
	table.dirty_plates += plates
	if plates > 0 and not JobBoard.has_open("bus", "furniture", table):
		JobBoard.post("clean", "bus", {"furniture": table})
	for ch in table.chairs:
		lot.add_dirt(ch.cell, randf_range(0.05, 0.25))
		if ch.occupant in members:
			ch.occupant = null
	if table.group == self:
		table.group = null
	lot.queue_redraw()


# ------------------------------------------------------------------ paying

## With a till they walk up and pay on the way out (and the table frees up);
## without one, someone brings the check to the table.
func start_paying() -> void:
	if comped:
		settle()
		return
	state = "paying"
	pay_wait = 0.0
	var till = nearest_till()
	# some people just leave the money on the table rather than queue at the till
	if till != null and table != null and not takeout and randf() < Data.CASH_ON_TABLE * Data.CASH_KIND.get(kind, 0.8):
		leave_cash()
		return
	if till != null:
		pay_spot = till
		leave_table()
		var spots: Array = lot.access_cells(till).filter(func(c): return lot.walkable_c(c))
		for m in members:
			if m.has_method("cancel_errand"):
				m.cancel_errand()
			m.sitting = false
			m.offset = Vector2(randf_range(-6, 6), randf_range(-5, 5))
			if not m.go_to_any(spots):
				m.path.clear()
		JobBoard.post("host", "till", {"group": self, "furniture": till})
	else:
		JobBoard.post("serve", "check", {"group": self})


func nearest_till():
	var best = null
	var best_d := 1 << 30
	var here: Vector2i = table.cell if table != null else lot.entry_inside
	for f in lot.of_type("till"):
		var spots: Array = lot.access_cells(f).filter(func(c): return lot.walkable_c(c))
		if spots.is_empty():
			continue
		var d: int = lot.distance(here, f.cell)
		if d < best_d:
			best_d = d
			best = f
	return best


## Paid: at the till, at the table, or by leaving the money when nobody came.
func settle() -> void:
	if state in ["leaving", "gone"]:
		return
	if pay_wait > Data.PAY_SLOW:
		extra_hits["a slow check"] = clampf((pay_wait - Data.PAY_SLOW) / 12.0, 0.0, 0.6)
	var result := review()
	pay()
	if pay_spot == null:
		leave_table()
	else:
		GameState.today["paid_at_till"] += 1
	leave(result[0], result[1], true)


## They put the money for the bill (and a tip) on the table and go. Whoever
## clears the table or comes by picks it up; the tip goes to their servers.
func leave_cash() -> void:
	if state in ["leaving", "gone"]:
		return
	if table == null or takeout:
		settle()
		return
	if pay_wait > Data.PAY_SLOW:
		extra_hits["a slow check"] = clampf((pay_wait - Data.PAY_SLOW) / 12.0, 0.0, 0.6)
	var result := review()
	var t = table
	pay(true)
	leave_table()
	# they're gone, but the table stays theirs until the money's picked up
	leave(result[0], result[1], true)
	if is_instance_valid(t):
		t.group = null


## Nobody's watching and they've waited a while to pay: some just walk out.
func try_dash(minutes: float) -> void:
	if pay_wait < Data.PAY_SLOW or not Data.DASH_KIND.has(kind) or members.is_empty():
		return
	var p: Vector2 = members[0].position
	for s in Crew.present():
		if not s.on_break and s.position.distance_to(p) <= Data.DASH_WATCH_TILES * Data.TILE:
			return
	if randf() >= Data.DASH_CHANCE * Data.DASH_KIND[kind] * minutes:
		return
	GameState.today["dashes"] += 1
	GameState.today["dash_lost"] += bill
	var who := "A table of students" if kind == "student" else ("A family" if kind == "family" else ("A group" if members.size() > 1 else "A customer"))
	GameState.toast.emit("%s walked out without paying ($%d)! Nobody was watching." % [who, int(bill)], "bad")
	Crew.log_line("Dine and dash: %s walked out without paying $%d." % [who.to_lower(), int(bill)], "walkout")
	if pay_spot == null:
		leave_table()
	leave(0.0, "", true)


# ------------------------------------------------------------------ complaints

## "I'd like to speak to the manager." A manager on shift comes over;
## otherwise you're asked what to do (twice a day at most).
func start_complaint(what: String) -> void:
	state = "complaining"
	complaint_what = what
	complaint_wait = 0.0
	GameState.today["complaints_raised"] += 1
	for s in Crew.present():
		if s.manager:
			JobBoard.post("serve", "complaint", {"group": self})
			return
	if Front.cards_today < 2:
		Front.cards_today += 1
		Events.ask_complaint(self)
		return
	extra_hits["nobody came to listen"] = 0.3
	start_paying()


## What the manager (or you) did about it: "apologise", "comp" or "argue".
func resolve_complaint(how: String, by = null) -> void:
	if state != "complaining":
		return
	var who: String = by.person_name if by != null else "You"
	match how:
		"apologise":
			review_bonus += 0.5
			Crew.log_line("%s apologised to %s about %s." % [who, label().to_lower(), complaint_what if complaint_what != "" else "their visit"], "chat", [by] if by != null else [])
		"comp":
			comped = true
			review_bonus += 1.0
			Crew.log_line("%s gave %s their meal on the house ($%d)." % [who, label().to_lower(), int(bill)], "money", [by] if by != null else [])
		"argue":
			review_bonus -= 0.5
			extra_hits["argued with the manager"] = 0.5
			Crew.log_line("%s argued with an unhappy table. It didn't go well." % who, "storm", [by] if by != null else [])
		"firm":
			review_bonus -= 0.3
	start_paying()


var _review_cache: Array = []

## [score from 1 to 5, the biggest complaint or ""]. Worked out once, when they
## pay (final); a look before that (final = false) doesn't fix it.
func review(final: bool = true) -> Array:
	if not _review_cache.is_empty():
		return _review_cache
	var fussy: float = info().get("picky", 1.0)
	var s := 5.0
	var hits := {}
	if not takeout:
		hits["a long wait for a table"] = clampf((t_table - 5.0) / 10.0, 0.0, 1.5)
	hits["a slow order"] = clampf((t_order - 5.0) / 10.0, 0.0, 1.0)
	hits["slow food"] = clampf((t_food - (15.0 if takeout else 25.0)) / 20.0, 0.0, 1.5)
	var spot: Vector2i = table.cell if table != null else lot.entry_inside
	if not takeout:
		hits["a dirty floor"] = clampf(lot.dirt_near(spot, 4) * 3.0 * fussy, 0.0, 1.0 * fussy)
	var ratio := 0.0
	for d in received:
		ratio += GameState.price(d) / Data.DISHES[d]["price"]
	ratio = ratio / received.size() if received.size() > 0 else 1.0
	hits["high prices"] = clampf((ratio - 1.0) * 2.0 * info()["price"], 0.0, 1.5)
	hits["missing items"] = 0.5 * missing
	var q := 0.6
	if not qualities.is_empty():
		q = 0.0
		for v in qualities:
			q += v
		q /= qualities.size()
	hits["the food"] = maxf(0.0, (0.55 - q) * 1.5 * fussy)
	if GameState.grade == "C":
		hits["a bad health grade"] = 0.35
	for k in staff_trouble:
		hits[k] = staff_trouble[k]
	for k in extra_hits:
		hits[k] = extra_hits[k]
	if not takeout:
		var beauty: int = lot.beauty_near(spot)
		if beauty == 0:
			hits["a plain, bare room"] = 0.2
		s += beauty * 0.1
		if lot.music_near(spot) and GameState.is_open():
			s += 0.15
	for k in hits:
		s -= hits[k]
	s += (q - 0.5) * 0.6
	if ratio < 0.9:
		s += minf(0.5, 0.25 * info()["price"])
	if chatty_service:
		s += 0.25
	if GameState.special != "" and GameState.special in received:
		s += Data.SPECIAL_REVIEW
	if GameState.grade == "A":
		s += 0.1
	if greeted:
		s += Data.GREET_REVIEW
	if fav_served:
		s += 0.3
	s += review_bonus
	s = clampf(s, 1.0, 5.0)
	var worst := ""
	var worst_v := 0.3
	for k in hits:
		if hits[k] > worst_v:
			worst_v = hits[k]
			worst = k
	var out := [s, worst]
	if final:
		_review_cache = out
		if Events.auto_choice == -2:
			# balance runs: add up what's costing stars
			var hs: Dictionary = GameState.today.get("hit_sum", {})
			for k in hits:
				if hits[k] > 0.0:
					hs[k] = hs.get(k, 0.0) + hits[k]
			GameState.today["hit_sum"] = hs
	return out


# ------------------------------------------------------------------ the health inspector

func begin_inspection() -> void:
	state = "inspecting"
	GameState.toast.emit("The health inspector is looking around. Hope the kitchen is clean!", "")
	Sfx.play("inspector")
	stops = []
	for t in ["sink", "grill", "fryer", "griddle", "fridge", "pass"]:
		var fs: Array = lot.of_type(t)
		if not fs.is_empty():
			stops.append(fs.pick_random())
	var ts: Array = lot.tables()
	if not ts.is_empty():
		stops.append(ts.pick_random())
	stops.shuffle()
	stops = stops.slice(0, 4)
	stop_wait = -1.0
	next_stop()


func next_stop() -> void:
	while not stops.is_empty():
		var f = stops[0]
		if lot.furniture.has(f) and members[0].go_to_any(lot.access_cells(f)):
			stop_wait = 1.5
			return
		stops.pop_front()
	grade_diner()


func inspect_tick(minutes: float) -> void:
	if members.is_empty():
		return
	if members[0].is_moving():
		return
	if stops.is_empty():
		grade_diner()
		return
	members[0].face_toward(stops[0].center_px())
	stop_wait -= minutes
	if stop_wait <= 0.0:
		stops.pop_front()
		next_stop()


func grade_diner() -> void:
	if state != "inspecting":
		return
	var r: Dictionary = lot.inspection()
	GameState.set_grade(r["grade"])
	var text := "Health inspection: grade %s." % r["grade"]
	if not r["notes"].is_empty():
		text += " They noted " + ", ".join(r["notes"]) + "."
	elif r["grade"] == "A":
		text += " Spotless!"
	GameState.toast.emit(text, "good" if r["grade"] == "A" else ("bad" if r["grade"] == "C" else ""))
	Sfx.play("good_review" if r["grade"] == "A" else ("bad_review" if r["grade"] == "C" else "pop"))
	lot.queue_redraw()
	leave(0.0, "", true)


# ------------------------------------------------------------------ leaving

func leave(score: float, complaint: String, paid: bool) -> void:
	if state == "leaving" or state == "gone":
		return
	if score > 0.0:
		var weight: int = info().get("review_weight", 1)
		GameState.add_review(score, complaint, weight)
		var p: Vector2 = members[0].position if not members.is_empty() else Vector2.ZERO
		lot.fx.stars(p, score)
		if kind == "celebrity":
			Events.celebrity_review(score)
		if kind == "critic":
			GameState.today["critic"] = score
			if score >= 4.0:
				GameState.totals["critic"] = GameState.totals.get("critic", 0) + 1
				GameState.toast.emit("The food critic loved it: %.1f stars! That review counts five times." % score, "good")
				Sfx.play("good_review")
			else:
				GameState.toast.emit("The food critic gave you %.1f stars%s. That review counts five times." % [score, (", mostly for " + complaint) if complaint != "" else ""], "bad" if score < 3.0 else "")
				Sfx.play("bad_review" if score < 3.0 else "pop")
		elif score < 2.0:
			Sfx.play("bad_review", -10.0)
		if regular != null:
			Front.after_visit(regular, score, served_by)
	elif regular != null and not paid:
		# a regular who walked out unhappy
		Front.after_visit(regular, 1.5, served_by)
	if not paid:
		GameState.today["left"] += members.size()
	if booking != null:
		Front.release(booking)
	if table != null:
		if table.group == self:
			table.group = null
		if not paid and not table.food_on_table.is_empty():
			# half-eaten food still leaves dirty plates behind
			var plated := 0
			for d in table.food_on_table:
				if Data.DISHES[d]["plate"]:
					plated += 1
			table.food_on_table.clear()
			if plated > 0:
				table.dirty_plates += plated
				JobBoard.post("clean", "bus", {"furniture": table})
		for ch in table.chairs:
			if ch.occupant in members:
				ch.occupant = null
	# food still waiting on the pass for us goes back as clean plates
	for f in lot.of_type("pass"):
		for it in f.items.duplicate():
			if it["group"] == self:
				f.items.erase(it)
				if it.get("plated", false):
					GameState.plates_clean += 1
	JobBoard.cancel_for_group(self)
	lot.queue_redraw()
	state = "leaving"
	for m in members:
		if m.has_method("cancel_errand"):
			m.cancel_errand()
		m.sitting = false
		m.customer_nav = kind != "inspector"
		m.offset = Vector2(randf_range(-6, 6), randf_range(-5, 5))
		if not m.go_to(exit_cell):
			m.customer_nav = false
			if not m.go_to(exit_cell):
				m.path.clear()


func remove_now() -> void:
	## End of day: anyone still inside simply goes home.
	if state != "leaving":
		leave(0.0, "", false)
	for m in members:
		m.queue_free()
	members.clear()
	state = "gone"
	queue_free()
