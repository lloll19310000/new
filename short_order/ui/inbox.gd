extends PanelContainer
## Every message of the last few days, newest first, under the bell in the
## top bar. Filter to just the crew, the bad news or the good.

var toasts
var list: VBoxContainer
var filter := ""
var filter_buttons := {}
const FILTERS := [["", "All"], ["bad", "Problems"], ["crew", "Crew"], ["good", "Good news"]]


func _ready() -> void:
	theme_type_variation = &"Card"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiKit.label("Messages", 16, UiKit.INK, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.icon = UiKit.icon("close")
	close.theme_type_variation = &"FlatButton"
	close.tooltip_text = "Close"
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	var group := ButtonGroup.new()
	for f in FILTERS:
		var b := Button.new()
		b.text = f[1]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = &"SmallButton"
		b.button_pressed = f[0] == ""
		b.pressed.connect(func():
			filter = f[0]
			refresh())
		row.add_child(b)
		filter_buttons[f[0]] = b
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(400, 360)
	box.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()
		toasts.mark_read()


func refresh() -> void:
	if list == null or toasts == null:
		return
	for c in list.get_children():
		c.queue_free()
	var shown := 0
	var last_day := -1
	for i in range(toasts.history.size() - 1, -1, -1):
		var m: Dictionary = toasts.history[i]
		var kind: String = m["kind"]
		if filter == "crew" and kind != "crew":
			continue
		if filter == "bad" and kind not in ["bad", "critic"]:
			continue
		if filter == "good" and kind not in ["good", "rush"]:
			continue
		if m["day"] != last_day:
			last_day = m["day"]
			list.add_child(UiKit.label("Day %d" % last_day, 12, UiKit.GOLD, &"SmallLabel"))
		var k: Dictionary = toasts.KINDS.get(kind, toasts.KINDS[""])
		var r := PanelContainer.new()
		r.add_theme_stylebox_override("panel", UiKit.row_style(Color("2a221d"), k["color"].darkened(0.4), 5))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		r.add_child(h)
		h.add_child(UiKit.icon_rect(k["icon"], 14, k["color"]))
		var t := UiKit.label(m["time"], 11, UiKit.FAINT, &"SmallLabel")
		t.custom_minimum_size = Vector2(52, 0)
		h.add_child(t)
		var l := UiKit.label(m["text"], 12, UiKit.INK, &"BodyLabel")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(250, 0)
		h.add_child(l)
		list.add_child(r)
		shown += 1
	if shown == 0:
		list.add_child(UiKit.label("Nothing here yet.", 12, UiKit.MUTED, &"MutedLabel"))
