extends Control
## The end-of-day report: customers, money, reviews and what happened today.

signal next_pressed

const ADVICE := {
	"slow food": "Hire another cook, raise Cook priorities, or add a second station.",
	"a slow order": "Put more people on Serve.",
	"a long wait for a table": "Add tables and chairs, or speed up service so tables free up.",
	"a dirty floor": "Put someone on Clean at priority 1 or 2.",
	"high prices": "Your prices are well above the usual ones.",
	"the food": "Better cooks make better food, and skills grow with practice.",
	"missing items": "Keep more ingredients in Supplies.",
	"a plain, bare room": "Plants, lamps and pictures near tables cheer customers up.",
	"a bad health grade": "Keep the kitchen spotless for the next inspection.",
	"Nobody took our order": "Put more people on Serve.",
	"The food never came": "The kitchen is overwhelmed: more cooks or stations.",
	"No free table": "Add tables, or serve faster so tables free up.",
	"Out of stock": "Keep more ingredients in Supplies.",
	"staff arguing": "Two of your staff don't get along. Give them different jobs so they work apart, or make someone a manager.",
	"staff on their phone": "Click people on their phones to catch them, or make someone a manager.",
	"rowdy customers": "When a table gets rowdy, asking them to leave keeps everyone else happy.",
	"a slow check": "Build a till by the door, and put someone on Host or Serve to ring people up.",
	"nobody came to listen": "Make someone a manager: they handle unhappy tables.",
	"argued with the manager": "A fed-up manager argues with customers. Keep their stress down.",
	"our booked table wasn't ready": "Booked tables are held 20 minutes ahead; more tables means fewer clashes.",
	"their usual wasn't on": "Keep your regulars' favourite dishes on the menu and in stock.",
	"their first choice was sold out": "Keep more of what your popular dishes need, and the fridge space for it.",
	"a wrong order": "Tired, stressed or new servers make mistakes. Breaks, a sofa and training help.",
	"cold food": "Food waited too long on the pass: put more people on Serve.",
	"an allergic reaction": "Servers must flag allergies. Experienced, calm servers remember; keep the kitchen clean.",
	"a dirty restroom": "Put someone on Clean: they scrub the restroom when it needs it.",
	"no restroom": "Build a restroom: Restroom floor, walls, a door, and a toilet.",
	"a mouse!": "Keep the kitchen floor clean and the bins emptied. Mouse traps help.",
	"trash carried past tables": "Build a dumpster outside and a back door, so trash doesn't go past your tables.",
}

@onready var card: PanelContainer = %Card
@onready var title: Label = %Title
@onready var customers: GridContainer = %Customers
@onready var money: GridContainer = %Money
@onready var stars: StarRating = %Stars
@onready var rating: Label = %Rating
@onready var reviews: Label = %Reviews
@onready var notes: RichTextLabel = %Notes
@onready var next_button: Button = %NextButton
var numbers_row: HBoxContainer
var number_labels := {}


func _ready() -> void:
	next_button.pressed.connect(func():
		visible = false
		next_pressed.emit())
	# the three numbers owners watch, under the columns
	numbers_row = HBoxContainer.new()
	numbers_row.add_theme_constant_override("separation", 10)
	var cols: Control = money.get_parent().get_parent()
	cols.get_parent().add_child(numbers_row)
	cols.get_parent().move_child(numbers_row, cols.get_index() + 1)
	for k in ["food", "staff", "margin"]:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"Well"
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		var big := Label.new()
		big.theme_type_variation = &"BigLabel"
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var small := Label.new()
		small.theme_type_variation = &"SmallLabel"
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.add_theme_color_override("font_color", UiKit.MUTED)
		v.add_child(big)
		v.add_child(small)
		chip.add_child(v)
		numbers_row.add_child(chip)
		number_labels[k] = [big, small, chip]


func row(grid: GridContainer, what: String, value: String, color: Color = UiKit.INK, bold: bool = false) -> void:
	var a := Label.new()
	a.text = what
	a.theme_type_variation = &"BodyLabel" if not bold else &"StatLabel"
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(a)
	var b := Label.new()
	b.text = value
	b.theme_type_variation = &"StatLabel"
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_color_override("font_color", color)
	grid.add_child(b)


func show_report(r: Dictionary) -> void:
	for g in [customers, money]:
		for c in g.get_children():
			c.queue_free()
	title.text = "Day %d is over" % r["day"]
	row(customers, "Groups that came in", str(r["groups"]))
	row(customers, "Customers served", str(r["served"]), UiKit.MINT)
	row(customers, "Walked out unhappy", str(r["left"]), UiKit.CHERRY if r["left"] > 0 else UiKit.INK)
	if r.get("takeout", 0) > 0:
		row(customers, "Takeout orders", str(r["takeout"]))
	row(customers, "Tips (for your staff)", "$%d" % int(r["tips"]), UiKit.GOLD)
	row(money, "Sales", "+$%d" % int(r["revenue"]), UiKit.MINT)
	row(money, "Wages", "-$%d" % int(r["wages"]), UiKit.CHERRY)
	var bills: Dictionary = r.get("bills", {})
	if not bills.is_empty():
		row(money, "Rent (weekly)", "-$%d" % int(bills["rent"]), UiKit.CHERRY)
		row(money, "Utilities (weekly)", "-$%d" % int(bills["utilities"]), UiKit.CHERRY)
		if bills.get("loan", 0.0) > 0.0:
			row(money, "Loan payment", "-$%d" % int(ceil(bills["loan"])), UiKit.CHERRY)
	if r.get("supplies", 0.0) > 0.0:
		row(money, "Delivery (this morning)", "-$%d" % int(r["supplies"]), UiKit.CHERRY)
	if r.get("staff_meal", 0.0) > 0.0:
		row(money, "Staff meal", "-$%d" % int(r["staff_meal"]), UiKit.CHERRY)
	var net: float = r["net"]
	row(money, "Today", ("+$%d" if net >= 0 else "-$%d") % int(absf(net)), UiKit.MINT if net >= 0 else UiKit.CHERRY, true)
	row(money, "Cash now", UiKit.money(r["money"]), UiKit.GOLD, true)
	var nums: Dictionary = r.get("numbers", {})
	numbers_row.visible = not nums.is_empty() and r["revenue"] > 0.0
	if numbers_row.visible:
		set_number("food", nums["food"], "Food cost", Data.TARGET_FOOD_COST, true,
			"Ingredients used and thrown out today, as a share of sales. Owners aim for about %d%%." % int(Data.TARGET_FOOD_COST * 100))
		set_number("staff", nums["staff"], "Staff cost", Data.TARGET_STAFF_COST, true,
			"Wages as a share of sales. With California wages, owners aim for about %d%%." % int(Data.TARGET_STAFF_COST * 100))
		set_number("margin", nums["margin"], "Profit margin", 0.0, false,
			"What's left of each dollar of sales after food, wages and a day's share of the weekly bills ($%d)." % int(nums["bills"]))
	stars.value = r["rating"]
	rating.text = "%.1f" % r["rating"]
	reviews.text = ("Today's reviews averaged %.1f from %d customers." % [r["avg"], r["reviews"]]) if r["reviews"] > 0 else "No reviews today."
	notes.fit_content = true
	notes.scroll_active = false
	notes.custom_minimum_size.y = 0
	notes.text = build_notes(r)
	_fit_notes.call_deferred()
	visible = true
	card.pivot_offset = card.size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.25).from(Vector2(0.94, 0.94)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.2).from(0.0)
	next_button.text = "Start day %d" % (int(r["day"]) + 1)
	Sfx.play("day_end", -6.0)


## On a busy day the notes can run long: past a point they scroll instead
## of pushing the card off the screen.
func _fit_notes() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var room := get_viewport_rect().size.y - (card.size.y - notes.size.y) - 40.0
	room = maxf(room, 90.0)
	if notes.get_content_height() > room:
		notes.fit_content = false
		notes.custom_minimum_size.y = room
		notes.scroll_active = true
	card.pivot_offset = card.size / 2.0


func set_number(key: String, v: float, what: String, target: float, lower_is_better: bool, tip: String) -> void:
	var big: Label = number_labels[key][0]
	var small: Label = number_labels[key][1]
	big.text = "%d%%" % int(round(v * 100))
	var col := UiKit.INK
	if lower_is_better:
		col = UiKit.MINT if v <= target + 0.03 else (UiKit.GOLD if v <= target + 0.1 else UiKit.CHERRY)
		small.text = "%s (aim ~%d%%)" % [what, int(target * 100)]
	else:
		col = UiKit.MINT if v >= 0.1 else (UiKit.GOLD if v >= 0.0 else UiKit.CHERRY)
		small.text = what
	big.add_theme_color_override("font_color", col)
	number_labels[key][2].tooltip_text = tip


func line(icon: String, color: String, text: String) -> String:
	return "[img width=16 height=16 color=%s]res://ui/icons/%s.svg[/img]  %s\n" % [color, icon, text]


func build_notes(r: Dictionary) -> String:
	var t := ""
	var bills: Dictionary = r.get("bills", {})
	if not bills.is_empty():
		t += line("money", "#f2c14e", "Weekly bills paid tonight: rent $%d, utilities $%d%s." % [int(bills["rent"]), int(bills["utilities"]),
			(", loan $%d" % int(ceil(bills["loan"]))) if bills.get("loan", 0.0) > 0.0 else ""])
		if bills.get("paid_off", false):
			t += line("star", "#6cc3a0", "That was the last loan payment: [b]the loan is paid off[/b].")
	else:
		var days: int = r.get("bills_in", 0)
		t += line("money", "#b9a797", "Weekly bills (about $%d: rent, utilities%s) are due in %d day%s." % [int(r.get("bills_next", 0.0)),
			" and the loan" if not r.get("loan", {}).is_empty() else "", days, "" if days == 1 else "s"])
	for c in r.get("tip_lines", []):
		t += line(c[0], c[1], c[2])
	var kt: Dictionary = r.get("kitchen", {})
	if kt.get("allergies", 0) > 0:
		t += line("alert", "#e75a4e", "[b]%d allergic reaction%s.[/b] Servers have to flag allergies on the ticket; green, stressed or chatty ones forget. A dirty kitchen makes slip-ups likelier too." % [kt["allergies"], "" if kt["allergies"] == 1 else "s"])
	if kt.get("wrong_orders", 0) > 0:
		t += line("fix", "#f2c14e", "%d wrong order%s went back to the kitchen. Tired, stressed or new servers write things down wrong." % [kt["wrong_orders"], "" if kt["wrong_orders"] == 1 else "s"])
	if kt.get("no_plates", 0) >= 5:
		t += line("wash", "#e75a4e", "The kitchen sat waiting for clean plates for %d minutes. More people on Wash (or more plates, in Supplies) would fix it." % kt["no_plates"])
	if kt.get("cold_plates", 0) > 0:
		t += line("ticket", "#6aa6d9", "%d plate%s went out cold after sitting on the pass. More people on Serve would help." % [kt["cold_plates"], "" if kt["cold_plates"] == 1 else "s"])
	var hl: Dictionary = r.get("health", {})
	if not hl.is_empty():
		if hl["mice"] > 0:
			t += line("mouse", "#e75a4e", "[b]%d mouse sighting%s[/b]%s. Keep the kitchen floor clean and the bins emptied; traps help." % [hl["mice"], "" if hl["mice"] == 1 else "s",
				(" (customers saw %d, a trap caught %d)" % [hl["mouse_seen"], hl["mice_caught"]]) if hl["mouse_seen"] > 0 or hl["mice_caught"] > 0 else ""])
		if hl["handwash_skipped"] > 0:
			t += line("alert", "#f2c14e", "Staff skipped washing their hands %d time%s. The inspector notices, and it spreads colds." % [hl["handwash_skipped"], "" if hl["handwash_skipped"] == 1 else "s"])
		if hl["dirty_restroom"] > 0:
			t += line("restroom", "#f2c14e", "%d customer%s found the restroom dirty. Someone with Clean on scrubs it." % [hl["dirty_restroom"], "" if hl["dirty_restroom"] == 1 else "s"])
		elif not hl["has_toilet"]:
			t += line("restroom", "#b9a797", "No restroom yet: customers who need one mark you down.")
	var fr: Dictionary = r.get("front", {})
	if not fr.is_empty():
		if fr["regulars"] > 0:
			t += line("heart", "#e27fa8", "%d visit%s from your regulars." % [fr["regulars"], "" if fr["regulars"] == 1 else "s"])
		if fr["bookings"] > 0 or fr["no_shows"] > 0:
			t += line("day", "#b9a797", "Bookings: %d came in%s." % [fr["bookings"], (", %d didn't show" % fr["no_shows"]) if fr["no_shows"] > 0 else ""])
		if fr["app_orders"] > 0 or fr["app_missed"] > 0:
			var bits: Array = ["%d app order%s picked up" % [fr["app_done"], "" if fr["app_done"] == 1 else "s"]]
			if fr["app_fees"] > 0.0:
				bits.append("the app kept $%d" % int(fr["app_fees"]))
			if fr["app_cancelled"] > 0:
				bits.append("%d cancelled" % fr["app_cancelled"])
			if fr["app_missed"] > 0:
				bits.append("%d missed (the window was busy)" % fr["app_missed"])
			t += line("van", "#6aa6d9", "Delivery apps: " + ", ".join(bits) + ".")
		if fr["complaints_raised"] > 0:
			t += line("alert", "#f2c14e", "%d table%s asked for the manager%s." % [fr["complaints_raised"], "" if fr["complaints_raised"] == 1 else "s",
				(" ($%d in meals on the house)" % int(fr["comped"])) if fr["comped"] > 0.0 else ""])
		if fr["dashes"] > 0:
			t += line("walkout", "#e75a4e", "[b]%d dine and dash%s[/b]: $%d walked out the door. Keep someone near the tables, or build a till." % [fr["dashes"], "" if fr["dashes"] == 1 else "es", int(fr["dash_lost"])])
	if r.get("level_up", "") != "":
		t += line("star", "#f2c14e", "Your diner is now a [b]%s[/b]! More customers will come." % r["level_up"])
	for c in r.get("events", []):
		t += line(c[0], c[1], c[2])
	for c in r.get("crew", []):
		t += line(c[0], c[1], c[2])
	if r.get("inspection", "") != "":
		var g: String = r["inspection"]
		var col: String = {"A": "#6cc3a0", "B": "#f2c14e", "C": "#e75a4e"}.get(g, "#f5ecdf")
		t += line("inspector", col, "The health inspector gave you a [b][color=%s]%s[/color][/b]." % [col, g])
	if r.get("critic", -1.0) >= 0.0:
		var c: float = r["critic"]
		t += line("critic", "#b58be0", "A food critic gave you [b]%.1f stars[/b]." % c)
	if r.get("breakdowns", 0) > 0:
		t += line("fix", "#e75a4e", "%d breakdown%s in the kitchen." % [r["breakdowns"], "" if r["breakdowns"] == 1 else "s"])
	if r["complaint"] != "":
		var advice: String = ADVICE.get(r["complaint"], "")
		t += line("alert", "#f2c14e", "Most common complaint: [b]%s[/b]. %s" % [r["complaint"], advice])
	if r.get("delivery_refused", false):
		t += line("supplies", "#e75a4e", "The delivery driver wouldn't unload this morning: you couldn't pay the bill.")
	if r.get("prepped", 0) > 0:
		t += line("prep", "#6cc3a0", "The kitchen prepped %d portions this morning and used %d of them." % [r["prepped"], r.get("prep_used", 0)])
	var outs: Array = r.get("sold_out", []).map(func(d): return Data.DISHES[d]["name"].to_lower())
	if not outs.is_empty():
		t += line("supplies", "#e75a4e", "Sold out: [b]%s[/b]. Keep more of what %s in Supplies (and the space for it)." % [Crew.and_list(outs), "it needs" if outs.size() == 1 else "they need"])
	if r.get("waste", 0.0) >= 1.0:
		var items: Array = r.get("waste_items", [])
		t += line("trash", "#f2c14e", "Food thrown out: [b]$%d[/b] (%s)." % [int(r["waste"]), "; ".join(items.slice(0, 4)) + ("…" if items.size() > 4 else "")])
	if r.get("order", 0.0) > 0.0:
		var fit: Dictionary = r.get("short_fit", {})
		var extra := ""
		if not fit.is_empty():
			var bits: Array = []
			for ing in fit:
				bits.append("%d %s" % [fit[ing], Data.INGREDIENTS[ing]["name"].to_lower()])
			extra = " Not everything fit: %s stayed at the supplier. More fridge or freezer space would help." % ", ".join(bits)
		t += line("van", "#b9a797", "Tomorrow's delivery is ordered: about [b]$%d[/b], paid when it arrives.%s" % [int(r["order"]), extra])
	var types: Dictionary = r.get("types", {})
	if not types.is_empty():
		var bits: Array = []
		for k in types:
			if k != "regular" and k != "driver" and Data.CUSTOMERS.has(k):
				bits.append("%s %d" % [Data.CUSTOMERS[k]["name"].replace("A ", "").to_lower(), types[k]])
		if not bits.is_empty():
			t += line("people", "#b9a797", "Besides locals: " + ", ".join(bits) + ".")
	return t.strip_edges()
