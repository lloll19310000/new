extends ScrollContainer
## The Office page: how the day starts (the staff meal), the money side
## (weekly bills, tips, a bank loan), the front of house and your regulars.
## Built in code, one section at a time.

var main
var _t := 0.0
var morning_note: Label
var meal_switch: CheckButton
var service_buttons := {}
var shifts_note: Label
var bills_note: Label
var tip_buttons := {}
var tip_note: Label
var loan_note: Label
var loan_buttons: Array = []
var payoff_button: Button
var host_note: Label
var bookings_switch: CheckButton
var bookings_note: Label
var apps_switch: CheckButton
var apps_note: Label
var regulars_box: VBoxContainer
var town_note: Label
var loyalty_switch: CheckButton
var match_switch: CheckButton
var rival_box: VBoxContainer
var huddle_buttons := {}
var huddle_note: Label
var benefit_switches := {}
var catering_box: VBoxContainer
var supplier_box: VBoxContainer
var second_box: VBoxContainer
var second_name: LineEdit
var second_note: Label
var _biz_key := ""
var _regulars_key := ""

@onready var box: VBoxContainer = %Box


func _ready() -> void:
	# ---- opening hours and shifts
	header("Opening hours", "clock")
	var hours_row := GridContainer.new()
	hours_row.columns = 2
	hours_row.add_theme_constant_override("h_separation", 6)
	hours_row.add_theme_constant_override("v_separation", 4)
	for sv in Data.SERVICES:
		var b := Button.new()
		b.text = "%s\n%s–%s" % [sv["name"], DayTimeline.clock(sv["from"]), DayTimeline.clock(sv["to"])]
		b.theme_type_variation = &"SmallButton"
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		var key: String = sv["key"]
		b.toggled.connect(func(on: bool):
			GameState.set_service(key, on)
			GameState.staff_changed.emit()
			refresh())
		hours_row.add_child(b)
		service_buttons[key] = b
	box.add_child(hours_row)
	morning_note = note("")
	shifts_note = note("", false)
	# ---- the town: the date, the weather, holidays, events, the rival
	header("Around town", "calendar")
	town_note = note("", false)
	rival_box = VBoxContainer.new()
	box.add_child(rival_box)
	var keep := box
	box = rival_box
	loyalty_switch = toggle("Loyalty cards",
		"Regulars get a stamp card: %d%% off their bill, and the rival across the street can't lure them away so easily. Also takes a quarter off the trade the rival takes." % int(Data.LOYALTY_CARD_COST * 100),
		func(on: bool): Town.loyalty_cards = on)
	match_switch = toggle("Match their prices",
		"Take %d%% off every price while they're open: they take half as much of your trade, but each plate makes less." % int(Data.PRICE_MATCH_CUT * 100),
		func(on: bool):
			Town.price_match = on
			GameState.menu_changed.emit())
	box = keep
	Town.changed.connect(refresh)
	# ---- before opening
	header("Before opening", "sun")
	var hl := UiKit.label("Morning huddle: today's focus", 13, UiKit.INK, &"BodyLabel")
	box.add_child(hl)
	var hrow := GridContainer.new()
	hrow.columns = 3
	hrow.add_theme_constant_override("h_separation", 4)
	hrow.add_theme_constant_override("v_separation", 4)
	for h in [["", "None"], ["speed", "Speed"], ["upsell", "Upselling"], ["clean", "Clean"], ["team", "Teamwork"]]:
		var hb := Button.new()
		hb.text = h[1]
		hb.toggle_mode = true
		hb.theme_type_variation = &"SmallButton"
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hk: String = h[0]
		hb.pressed.connect(func():
			Career.set_huddle(hk)
			refresh())
		hrow.add_child(hb)
		huddle_buttons[hk] = hb
	box.add_child(hrow)
	huddle_note = note("")
	meal_switch = toggle("Staff meal before opening",
		"Everyone sits down and eats together for %d minutes: about $%d a person in food. They start the day calmer and like each other a little more." % [int(Data.STAFF_MEAL_MINUTES), int(Data.STAFF_MEAL_COST)],
		func(on: bool): GameState.staff_meal = on)
	# ---- money
	header("Money", "money")
	bills_note = note("", false)
	var tips_label := Label.new()
	tips_label.text = "Tips"
	tips_label.theme_type_variation = &"StatLabel"
	box.add_child(tips_label)
	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for k in ["keep", "share"]:
		var b := Button.new()
		b.text = "Servers keep them" if k == "keep" else "Share with the kitchen"
		b.theme_type_variation = &"SmallButton"
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Books.tip_policy = k
			refresh())
		tip_row.add_child(b)
		tip_buttons[k] = b
	box.add_child(tip_row)
	tip_note = note("")
	var loan_label := Label.new()
	loan_label.text = "Bank loan"
	loan_label.theme_type_variation = &"StatLabel"
	box.add_child(loan_label)
	loan_note = note("")
	var loan_row := GridContainer.new()
	loan_row.columns = 3
	loan_row.add_theme_constant_override("h_separation", 6)
	loan_row.add_theme_constant_override("v_separation", 6)
	for terms in Data.LOANS:
		var amount: int = terms["amount"]
		var b := Button.new()
		b.text = "$%dk" % int(amount / 1000.0)
		b.tooltip_text = "Borrow $%s now. You pay back $%s a week for %d weeks (%d%% on top in all)." % [UiKit.thousands(amount),
			UiKit.thousands(int(ceil(amount * (1.0 + terms["interest"]) / terms["weeks"]))), terms["weeks"], int(round(terms["interest"] * 100))]
		b.theme_type_variation = &"SmallButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			if Books.take_loan(amount):
				Sfx.play("cash")
			refresh())
		loan_row.add_child(b)
		loan_buttons.append(b)
	box.add_child(loan_row)
	payoff_button = Button.new()
	payoff_button.theme_type_variation = &"SmallButton"
	payoff_button.pressed.connect(func():
		Books.pay_off()
		refresh())
	box.add_child(payoff_button)
	# ---- front of house
	header("Front of house", "host")
	host_note = note("")
	bookings_switch = toggle("Take bookings",
		"The host answers the phone: parties book a table for later, and it's held for them 20 minutes before. Now and then a booking doesn't show.",
		func(on: bool): Front.take_bookings = on)
	bookings_note = note("")
	apps_switch = toggle("Delivery apps",
		"Orders come in over the apps and drivers pick them up at the takeout window. More orders, but the app keeps %d%% of each bill." % int(Data.APP_SHARE * 100),
		func(on: bool): Front.apps_on = on)
	apps_note = note("")
	# ---- benefits
	header("Staff benefits", "heart")
	for k in Data.BENEFITS:
		var b: Dictionary = Data.BENEFITS[k]
		var cost := ("$%d a person a week" % int(b["per_person"])) if b.has("per_person") else ("%d%% of the weekly payroll" % int(b["payroll"] * 100))
		var kk: String = k
		benefit_switches[k] = toggle("%s (%s)" % [b["name"], cost], b["desc"], func(on: bool): Career.set_benefit(kk, on))
	# ---- catering
	header("Catering", "van")
	note("Now and then someone asks you to cater a wedding, a banquet or a party. The cooks prep it that morning (you need a prep counter) and the van collects it at noon: you're paid for what's ready.")
	catering_box = VBoxContainer.new()
	catering_box.add_theme_constant_override("separation", 4)
	box.add_child(catering_box)
	# ---- suppliers
	header("Suppliers", "supplies")
	note("Pay on time and your suppliers like you: a little cheaper, never short, the odd free box. A contract takes %d%% off their prices for $%d a week." % [int(Data.CONTRACT_DISCOUNT * 100), int(Data.CONTRACT_FEE)])
	supplier_box = VBoxContainer.new()
	supplier_box.add_theme_constant_override("separation", 4)
	box.add_child(supplier_box)
	Biz.changed.connect(func():
		_biz_key = ""
		refresh())
	# ---- expansion
	header("A second diner", "structure")
	second_note = note("")
	second_box = VBoxContainer.new()
	box.add_child(second_box)
	second_name = LineEdit.new()
	second_name.placeholder_text = "Name the new diner"
	second_box.add_child(second_name)
	var open_b := Button.new()
	open_b.text = "Open it ($%s)" % UiKit.thousands(int(Data.SECOND_COST))
	open_b.theme_type_variation = &"PrimaryButton"
	open_b.pressed.connect(func():
		var n := second_name.text.strip_edges()
		if main != null and main.open_second_location(n if n != "" else Data.DINER_NAMES.pick_random()):
			main.hud.refresh_all())
	second_box.add_child(open_b)
	# ---- regulars
	header("Regulars", "heart")
	note("Locals who keep coming back. They have a usual order and a favourite server. Treat them well and they tip more; let them down too often and they stop coming.")
	regulars_box = VBoxContainer.new()
	regulars_box.add_theme_constant_override("separation", 4)
	box.add_child(regulars_box)
	GameState.phase_changed.connect(func(_p): refresh())
	visibility_changed.connect(refresh)
	refresh()


# ------------------------------------------------------------------ building blocks

func header(text: String, icon: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if box.get_child_count() > 1:
		var sep := HSeparator.new()
		box.add_child(sep)
	row.add_child(UiKit.icon_rect(icon, 16, UiKit.GOLD))
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"HeaderLabel"
	row.add_child(l)
	box.add_child(row)


func note(text: String, muted: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"MutedLabel" if muted else &"BodyLabel"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(100, 0)
	box.add_child(l)
	return l


## A switch with a line under it saying what it does.
func toggle(text: String, desc: String, on_change: Callable) -> CheckButton:
	var b := CheckButton.new()
	b.text = text
	b.toggled.connect(func(on: bool):
		on_change.call(on)
		refresh())
	box.add_child(b)
	var d := note(desc)
	d.add_theme_font_size_override("font_size", 12)
	return b


# ------------------------------------------------------------------ refreshing

func refresh() -> void:
	if not is_node_ready():
		return
	refresh_biz()
	for k in huddle_buttons:
		huddle_buttons[k].set_pressed_no_signal(Career.huddle == k)
	huddle_note.text = {"": "No huddle: everyone just gets on with it.", "speed": "Speed: everyone works 6% faster today.", "upsell": "Upselling: servers push the pie and shakes.",
		"clean": "Clean: 30% less mess tracked around.", "team": "Teamwork: people warm to each other faster."}[Career.huddle] + (" A manager on shift makes it count half as much again." if Career.huddle != "" else "")
	for k in benefit_switches:
		benefit_switches[k].set_pressed_no_signal(Career.has_benefit(k))
	var tl: Array = Town.today_lines()
	tl.append("Tomorrow: %s." % Town.weather_name(Town.forecast).to_lower())
	town_note.text = "\n".join(tl)
	rival_box.visible = Town.rival_open()
	loyalty_switch.set_pressed_no_signal(Town.loyalty_cards)
	match_switch.set_pressed_no_signal(Town.price_match)
	morning_note.text = "Doors open %s to %s. Openers come in at %s to prep and take the delivery. You can only change the hours in the morning." % [
		DayTimeline.clock(GameState.open_min()), DayTimeline.clock(GameState.close_min()), DayTimeline.clock(GameState.prep_min())]
	for k in service_buttons:
		service_buttons[k].set_pressed_no_signal(GameState.hours.get(k, false))
		service_buttons[k].disabled = not GameState.is_building_allowed()
	var lines: Array = []
	for sh in Data.SHIFT_ORDER:
		var people: Array = GameState.staff.filter(func(s): return is_instance_valid(s) and s.shift == sh)
		if people.is_empty():
			continue
		lines.append("%s %s: %s" % [Data.SHIFTS[sh]["name"], Shifts.hours_text(people[0]), ", ".join(people.map(func(s): return s.person_name))])
	shifts_note.text = ("Shifts today (see Staff > Schedule):\n" + "\n".join(lines)) if not lines.is_empty() else "Hire some staff: the schedule gives them their shifts (Staff > Schedule)."
	shifts_note.add_theme_font_size_override("font_size", 12)
	meal_switch.set_pressed_no_signal(GameState.staff_meal)
	# money
	var days := Books.days_to_bills()
	bills_note.text = "Weekly bills: rent $%d and utilities $%d%s, due %s." % [int(Books.rent_week()), int(Books.utilities_week()),
		(", plus $%d for the loan" % int(ceil(Books.loan_week()))) if not Books.loan.is_empty() else "",
		"tonight" if days == 0 else ("in %d day%s (the night of day %d)" % [days, "" if days == 1 else "s", GameState.day + days])]
	bills_note.tooltip_text = "Rent grows with the land you own. Utilities are gas, power and water: every station, fridge and freezer adds some."
	for k in tip_buttons:
		tip_buttons[k].set_pressed_no_signal(Books.tip_policy == k)
	tip_note.text = ("Tips go to whoever brought the food. Servers love it; cooks and dishwashers who see nothing of it grumble."
		if Books.tip_policy == "keep" else
		"All tips go in one pot and are split evenly between everyone who worked that day. The kitchen's happier; your best servers take home a bit less.")
	var has_loan := not Books.loan.is_empty()
	for b in loan_buttons:
		b.visible = not has_loan
	payoff_button.visible = has_loan
	if has_loan:
		var weeks := int(ceil(Books.loan["owed"] / Books.loan["weekly"]))
		loan_note.text = "You owe $%d. $%d comes out with each week's bills (%d more week%s)." % [int(ceil(Books.loan["owed"])), int(ceil(Books.loan["weekly"])), weeks, "" if weeks == 1 else "s"]
		payoff_button.text = "Pay it all back now ($%d, no more interest)" % int(ceil(Books.payoff_cost()))
		payoff_button.disabled = GameState.money < Books.payoff_cost()
	else:
		loan_note.text = "Borrow now and pay it back with your weekly bills: small loans over 10 weeks, the biggest over three years. Hover a button for its terms."
	# front of house
	var has_stand: bool = main != null and main.lot.has_type("host")
	var has_window: bool = main != null and main.lot.has_type("takeout")
	host_note.text = ("A host stand is up. Anyone with Host switched on greets people, keeps a waitlist (so fewer walk past) and rings up bills at a till."
		if has_stand else "Build a host stand (Dining) by the door and switch Host on for someone: greeted customers wait longer, and a waitlist means fewer walk past.")
	host_note.add_theme_color_override("font_color", UiKit.MUTED if has_stand else UiKit.GOLD)
	bookings_switch.set_pressed_no_signal(Front.take_bookings)
	bookings_switch.disabled = not has_stand
	var left: Array = Front.bookings_left()
	if not has_stand:
		bookings_note.text = "Needs a host stand."
	elif GameState.is_active() and not Front.bookings.is_empty():
		var bits: Array = []
		for b in Front.bookings:
			bits.append("%s %s (%d)%s" % [DayTimeline.clock(b["at"]), b["name"], b["size"], {"seated": " ✓", "no_show": " ✗", "arrived": ""}.get(b["state"], "")])
		bookings_note.text = "Today: " + ", ".join(bits)
	else:
		bookings_note.text = "Bookings come in each morning." if Front.take_bookings else ""
	bookings_note.visible = bookings_note.text != ""
	apps_switch.set_pressed_no_signal(Front.apps_on)
	apps_switch.disabled = not has_window
	apps_note.text = "Needs a takeout window." if not has_window else ""
	apps_note.visible = apps_note.text != ""
	refresh_regulars()


func refresh_biz() -> void:
	var key := "%d|%s|%s" % [GameState.day, str(Biz.catering), str(Biz.reps)]
	if key != _biz_key:
		_biz_key = key
		for c in catering_box.get_children():
			c.queue_free()
		var any := false
		for job in Biz.catering:
			if not job["state"] in ["offer", "accepted", "done", "short"]:
				continue
			any = true
			var row := VBoxContainer.new()
			var dishes: Array = []
			for d in job["dishes"]:
				dishes.append("%d %s" % [job["dishes"][d], Data.DISHES[d]["name"].to_lower()])
			var t := UiKit.label("%s, %s: %s. $%d" % [job["client"].capitalize(), Town.date_text(int(job["day"])), ", ".join(dishes), int(job["pay"])], 12, UiKit.INK, &"BodyLabel")
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.custom_minimum_size = Vector2(100, 0)
			row.add_child(t)
			if job["state"] == "offer":
				var br := HBoxContainer.new()
				var yes := Button.new()
				yes.text = "Accept"
				yes.theme_type_variation = &"SmallButton"
				var id: int = job["id"]
				yes.pressed.connect(func(): Biz.accept(id, true))
				var no := Button.new()
				no.text = "Decline"
				no.theme_type_variation = &"SmallButton"
				no.pressed.connect(func(): Biz.accept(id, false))
				br.add_child(yes)
				br.add_child(no)
				row.add_child(br)
			else:
				row.add_child(UiKit.label({"accepted": "Accepted: the cooks prep it that morning.", "done": "Delivered in full.", "short": "Delivered short."}[job["state"]], 11, UiKit.MINT if job["state"] != "short" else UiKit.GOLD, &"SmallLabel"))
			catering_box.add_child(row)
		if not any:
			catering_box.add_child(UiKit.label("No requests right now." if GameState.rep_level >= 1 else "Requests start once you're a Local spot.", 12, UiKit.MUTED, &"MutedLabel"))
		for c in supplier_box.get_children():
			c.queue_free()
		for k in Data.SUPPLIER_REPS:
			var r: Dictionary = Biz.reps.get(k, {"rel": 50.0, "contract": false})
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", -2)
			col.add_child(UiKit.label(Data.SUPPLIER_REPS[k]["name"], 12, UiKit.INK, &"BodyLabel"))
			var items: Array = Data.SUPPLIER_REPS[k]["items"].map(func(i): return Data.INGREDIENTS[i]["name"].to_lower())
			var mood: String = "loves you" if r["rel"] >= 80.0 else ("likes you" if r["rel"] >= 55.0 else ("wary" if r["rel"] < 30.0 else "fine"))
			col.add_child(UiKit.label("%s · %s" % [", ".join(items), mood], 11, UiKit.MUTED, &"SmallLabel"))
			row.add_child(col)
			var hearts := HBoxContainer.new()
			for i in 5:
				hearts.add_child(UiKit.icon_rect("heart", 10, Color("e27fa8") if i < int(round(r["rel"] / 20.0)) else UiKit.FAINT))
			row.add_child(hearts)
			var cb := CheckButton.new()
			cb.text = "Contract"
			cb.add_theme_font_size_override("font_size", 11)
			cb.set_pressed_no_signal(r["contract"])
			var kk: String = k
			cb.toggled.connect(func(on: bool): Biz.set_contract(kk, on))
			row.add_child(cb)
			supplier_box.add_child(row)
	second_box.visible = Biz.can_open_second()
	if not Biz.sister.is_empty():
		second_note.text = "Your other diner, %s, makes about $%d a week without you; it comes in with the bills. Open it from the main menu to run it yourself." % [Biz.sister["name"], int(Biz.sister.get("weekly", 0.0))]
	elif Biz.can_open_second():
		second_note.text = "You're famous enough for a second diner. $%s goes across to get it started; this one keeps running under its crew, and its weekly takings come in with the new one's bills." % UiKit.thousands(int(Data.SECOND_COST))
	else:
		second_note.text = "Once you're a Destination diner with $%s to spare, you can open a second diner." % UiKit.thousands(int(Data.SECOND_COST))


func refresh_regulars() -> void:
	var key := ""
	for r in Front.known():
		key += "%s%d%d%s%d%d|" % [r["name"], int(r["loyalty"]), r["fav"], r["gone"], r.get("beats", 0), Front.days_to_birthday(r)]
	if key == _regulars_key:
		return
	_regulars_key = key
	for c in regulars_box.get_children():
		c.queue_free()
	for r in Front.known():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := Label.new()
		n.text = r["name"] + ("  (stopped coming)" if r["gone"] else "")
		n.theme_type_variation = &"BodyLabel"
		n.add_theme_color_override("font_color", UiKit.FAINT if r["gone"] else UiKit.INK)
		col.add_child(n)
		var fav = Front.fav_staff(r)
		var usual: Array = r["usual"].map(func(d): return Data.DISHES[d]["name"].to_lower())
		var sub := Label.new()
		var bday: int = Front.days_to_birthday(r)
		sub.text = "Usual: %s  ·  sits at the %s%s%s" % [" and ".join(usual), r.get("seat", "table"), ("  ·  likes %s" % fav.person_name) if fav != null else "",
			"  ·  birthday today!" if bday == 0 else ("  ·  birthday in %d day%s" % [bday, "" if bday == 1 else "s"] if bday <= 14 else "")]
		sub.theme_type_variation = &"SmallLabel"
		sub.add_theme_color_override("font_color", UiKit.MUTED)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(80, 0)
		col.add_child(sub)
		if str(r.get("beat_text", "")) != "":
			var story := Label.new()
			story.text = "“%s”" % r["beat_text"]
			story.theme_type_variation = &"SmallLabel"
			story.add_theme_color_override("font_color", Color("e27fa8"))
			story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			story.custom_minimum_size = Vector2(80, 0)
			col.add_child(story)
		var beats: int = r.get("beats", 0)
		var next_hint := ""
		if beats < Data.REGULAR_BEAT_AT.size():
			var need: Array = Data.REGULAR_BEAT_AT[beats]
			next_hint = "\nTheir story moves on at %d loyalty and %d visits." % [int(need[0]), need[1]]
		col.tooltip_text = "%s: %s\nComes in about every %d day%s, %s to %s. %d visit%s so far. Story: %d of %d.%s" % [r["name"], r["blurb"], r["every"], "" if r["every"] == 1 else "s",
			DayTimeline.clock(r["hours"][0] * 60.0), DayTimeline.clock(r["hours"][1] * 60.0), r["visits"], "" if r["visits"] == 1 else "s",
			beats, Front.stories(r).size(), next_hint]
		col.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(col)
		var hearts := HBoxContainer.new()
		hearts.add_theme_constant_override("separation", 1)
		var full := int(round(r["loyalty"] / 20.0))
		for i in 5:
			hearts.add_child(UiKit.icon_rect("heart", 11, Color("e27fa8") if i < full else UiKit.FAINT))
		hearts.tooltip_text = "Loyalty %d of 100" % int(r["loyalty"])
		hearts.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(hearts)
		regulars_box.add_child(row)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not is_visible_in_tree():
		return
	_t = 0.5
	refresh()
