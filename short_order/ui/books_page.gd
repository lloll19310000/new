extends ScrollContainer
## The Books: how the diner's been doing, night by night. Profit and the
## rating over the last four weeks, the busiest hours, the best-selling
## dishes and a week's profit and loss.

var box: VBoxContainer
var summary: Label
var profit_chart: BarChart
var served_chart: BarChart
var hours_chart: BarChart
var dish_chart: BarChart
var pnl: GridContainer


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	summary = UiKit.label("", 12, UiKit.INK, &"BodyLabel")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(100, 0)
	box.add_child(summary)
	_head("Profit each night (the line is your rating)")
	profit_chart = BarChart.new()
	box.add_child(profit_chart)
	_head("Customers served each night")
	served_chart = BarChart.new()
	served_chart.bar_color = Color("6aa6d9")
	served_chart.fmt = "%d"
	box.add_child(served_chart)
	_head("Busiest hours (the last 7 days)")
	hours_chart = BarChart.new()
	hours_chart.bar_color = Color("ef8a3a")
	hours_chart.fmt = "%d"
	box.add_child(hours_chart)
	_head("Best sellers (the last 7 days)")
	dish_chart = BarChart.new()
	dish_chart.horizontal = true
	dish_chart.bar_color = Color("e27fa8")
	box.add_child(dish_chart)
	_head("The last 7 days")
	pnl = GridContainer.new()
	pnl.columns = 2
	box.add_child(pnl)
	visibility_changed.connect(refresh)


func _head(t: String) -> void:
	box.add_child(UiKit.label(t, 13, UiKit.GOLD, &"StatLabel"))


func refresh() -> void:
	if box == null or not is_visible_in_tree():
		return
	var h: Array = GameState.history
	var last28: Array = h.slice(maxi(0, h.size() - 28))
	var last7: Array = h.slice(maxi(0, h.size() - 7))
	profit_chart.set_data(last28.map(func(x): return float(x["net"])), last28.map(func(x): return "d%d" % int(x["day"])), last28.map(func(x): return float(x["rating"])))
	served_chart.set_data(last28.map(func(x): return float(x["served"])), last28.map(func(x): return "d%d" % int(x["day"])))
	var hours := {}
	var dishes := {}
	var t := {"revenue": 0.0, "wages": 0.0, "food": 0.0, "bills": 0.0, "net": 0.0, "served": 0, "tips": 0.0, "upsells": 0, "combos": 0}
	for x in last7:
		for k in x.get("by_hour", {}):
			hours[int(k)] = hours.get(int(k), 0) + int(x["by_hour"][k])
		for d in x.get("dishes", {}):
			dishes[d] = dishes.get(d, 0) + int(x["dishes"][d])
		for k in t:
			t[k] += x.get(k, 0)
	var hk: Array = hours.keys()
	hk.sort()
	var from: int = hk[0] if not hk.is_empty() else 7
	var to: int = hk[-1] if not hk.is_empty() else 22
	var hv: Array = []
	var hl: Array = []
	for hr in range(from, to + 1):
		hv.append(float(hours.get(hr, 0)) / maxf(1.0, last7.size()))
		hl.append("%d" % (hr % 24))
	hours_chart.set_data(hv, hl)
	var dk: Array = dishes.keys()
	dk.sort_custom(func(a, b): return dishes[a] > dishes[b])
	dk = dk.slice(0, 8)
	dish_chart.set_data(dk.map(func(d): return float(dishes[d])), dk.map(func(d): return Data.DISHES[d]["name"] if Data.DISHES.has(d) else d))
	for c in pnl.get_children():
		c.queue_free()
	for row in [["Sales", t["revenue"], true], ["Wages", -t["wages"], false], ["Food and waste", -t["food"], false], ["Bills", -t["bills"], false], ["Profit", t["net"], true]]:
		pnl.add_child(UiKit.label(row[0], 12, UiKit.INK, &"BodyLabel"))
		var v: float = row[1]
		var l := UiKit.label(("+$%s" if v >= 0 else "-$%s") % UiKit.thousands(int(absf(v))), 12, UiKit.MINT if v >= 0 else UiKit.CHERRY, &"StatLabel")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pnl.add_child(l)
	if h.is_empty():
		summary.text = "The books fill in night by night, once you've had a day open."
	else:
		var n := maxf(1.0, last7.size())
		summary.text = "Over the last %d night%s: about $%s in sales and $%s profit a night, %d customers a night, %d combos and %d upsells. Tips to the staff: $%s." % [
			last7.size(), "" if last7.size() == 1 else "s", UiKit.thousands(int(t["revenue"] / n)), UiKit.thousands(int(t["net"] / n)), int(t["served"] / n), t["combos"], t["upsells"], UiKit.thousands(int(t["tips"]))]
