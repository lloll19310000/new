extends PanelContainer
## The ticket rail: every order the kitchen is working on, oldest first.
## Each ticket shows who it's for (the table number, takeout or an app
## order), the dishes still to come, and how long they've been waiting:
## green, then gold, then red. A red ! means an allergy on the ticket,
## and a wrench means a dish is being made again after a mix-up.

const MAX_ROWS := 6
const ArtIconScript = preload("res://ui/widgets/art_icon.gd")

var main
var _t := 0.0
var _key := ""
var rows_box: VBoxContainer
var count_label: Label


func _ready() -> void:
	theme = load("res://ui/theme.tres")
	custom_minimum_size = Vector2(240, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Kitchen tickets: orders being made, oldest first. Green is fresh, gold is getting slow, red is about to walk out."
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(UiKit.icon_rect("ticket", 18, UiKit.GOLD))
	var title := Label.new()
	title.text = "Tickets"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	count_label = Label.new()
	count_label.theme_type_variation = &"SmallLabel"
	count_label.add_theme_color_override("font_color", UiKit.MUTED)
	head.add_child(count_label)
	box.add_child(head)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 2)
	box.add_child(rows_box)
	visible = false


## Orders still being made: [group, dishes still to come], oldest first.
func open_tickets() -> Array:
	var out: Array = []
	if main == null:
		return out
	for g in main.groups:
		if not is_instance_valid(g) or g.state != "ordered":
			continue
		var left: Array = g.waiting_for()
		if left.is_empty():
			continue
		out.append([g, left])
	out.sort_custom(func(a, b): return a[0].food_wait > b[0].food_wait)
	return out


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	refresh()


func refresh() -> void:
	var tickets := open_tickets()
	visible = GameState.is_active() and not tickets.is_empty()
	if not visible:
		return
	count_label.text = "%d open" % tickets.size()
	# rebuild the rows only when the set of tickets changes; times update every refresh
	var key := ""
	for tk in tickets.slice(0, MAX_ROWS):
		key += "%d:%s:%s:%s|" % [tk[0].get_instance_id(), ",".join(tk[1]), tk[0].allergy_flagged, tk[0].remakes]
	key += str(tickets.size())
	if key != _key:
		_key = key
		for c in rows_box.get_children():
			c.queue_free()
		for tk in tickets.slice(0, MAX_ROWS):
			rows_box.add_child(make_row(tk[0], tk[1]))
		if tickets.size() > MAX_ROWS:
			var more := Label.new()
			more.text = "+ %d more" % (tickets.size() - MAX_ROWS)
			more.theme_type_variation = &"SmallLabel"
			more.add_theme_color_override("font_color", UiKit.MUTED)
			rows_box.add_child(more)
	for c in rows_box.get_children():
		if c.is_queued_for_deletion() or not c.has_meta("group"):
			continue
		var g = c.get_meta("group")
		if not is_instance_valid(g):
			continue
		var mins := int(g.food_wait)
		var time: Label = c.get_meta("time")
		time.text = "%dm" % mins
		time.add_theme_color_override("font_color", UiKit.MINT if mins < 12 else (UiKit.GOLD if mins < 25 else UiKit.CHERRY))


func make_row(g, left: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.set_meta("group", g)
	var who := Label.new()
	var lbl: String = g.label()
	who.text = lbl.replace("Table ", "T").replace("Takeout", "To go").replace("App order", "App")
	who.theme_type_variation = &"SmallLabel"
	who.custom_minimum_size = Vector2(40, 0)
	row.add_child(who)
	for d in left.slice(0, 5):
		var ic = ArtIconScript.new()
		ic.what = "dish:" + d
		ic.custom_minimum_size = Vector2(20, 20)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	if left.size() > 5:
		var more := Label.new()
		more.text = "+%d" % (left.size() - 5)
		more.theme_type_variation = &"SmallLabel"
		row.add_child(more)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var tips: Array = ["%s: waiting for %s." % [lbl, ", ".join(left.map(func(d): return Data.DISHES[d]["name"].to_lower()))]]
	if g.allergy != "" and g.allergy_flagged:
		row.add_child(UiKit.icon_rect("alert", 14, UiKit.CHERRY))
		tips.append("Allergy: no %s." % Data.ALLERGENS[g.allergy])
	if g.remakes > 0:
		row.add_child(UiKit.icon_rect("fix", 14, UiKit.GOLD))
		tips.append("A dish went back and is being made again.")
	var time := Label.new()
	time.theme_type_variation = &"SmallLabel"
	time.custom_minimum_size = Vector2(30, 0)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(time)
	row.set_meta("time", time)
	row.tooltip_text = "\n".join(tips)
	return row
