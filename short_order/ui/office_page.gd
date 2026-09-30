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
var _regulars_key := ""

@onready var box: VBoxContainer = %Box


func _ready() -> void:
	# ---- opening hours and shifts
	header("Opening hours", "clock")
	var hours_row := HBoxContainer.new()
	hours_row.add_theme_constant_override("separation", 6)
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
	# ---- before opening
	header("Before opening", "sun")
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
	var loan_row := HBoxContainer.new()
	loan_row.add_theme_constant_override("separation", 6)
	for amount in Data.LOAN_OPTIONS:
		var b := Button.new()
		b.text = "$%s" % UiKit.thousands(amount)
		b.tooltip_text = "Borrow $%s now. You pay back $%d a week for %d weeks." % [UiKit.thousands(amount), int(ceil(amount * (1.0 + Data.LOAN_INTEREST) / Data.LOAN_WEEKS)), Data.LOAN_WEEKS]
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
	shifts_note.text = ("Shifts (change them on each staff card):\n" + "\n".join(lines)) if not lines.is_empty() else "Hire some staff, then set their shifts on their cards."
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
		loan_note.text = "Borrow now and pay it back over %d weeks with your bills, plus %d%% interest." % [Data.LOAN_WEEKS, int(Data.LOAN_INTEREST * 100)]
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


func refresh_regulars() -> void:
	var key := ""
	for r in Front.known():
		key += "%s%d%d%s|" % [r["name"], int(r["loyalty"]), r["fav"], r["gone"]]
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
		sub.text = "Usual: %s%s" % [" and ".join(usual), ("  ·  likes %s" % fav.person_name) if fav != null else ""]
		sub.theme_type_variation = &"SmallLabel"
		sub.add_theme_color_override("font_color", UiKit.MUTED)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(80, 0)
		col.add_child(sub)
		col.tooltip_text = "%s: %s\nComes in about every %d day%s, %s to %s. %d visit%s so far." % [r["name"], r["blurb"], r["every"], "" if r["every"] == 1 else "s",
			DayTimeline.clock(r["hours"][0] * 60.0), DayTimeline.clock(r["hours"][1] * 60.0), r["visits"], "" if r["visits"] == 1 else "s"]
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
