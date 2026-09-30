extends ScrollContainer
## The Goals board: optional milestones pinned to a cork board. Each card
## shows how far along you are and what it unlocks; reached ones get a stamp.
## There's no end: keep going as long as you like.

var box: VBoxContainer
var cards := {}          # goal key -> {"card", "bar", "count", "stamp"}


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cork := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("a8794a")
	st.border_color = Color("6a4a2c")
	st.set_border_width_all(4)
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	cork.add_theme_stylebox_override("panel", st)
	cork.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cork.draw.connect(func():
		# cork speckles
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in int(cork.size.x * cork.size.y / 180.0):
			var p := Vector2(rng.randf() * cork.size.x, rng.randf() * cork.size.y)
			cork.draw_circle(p, rng.randf_range(0.6, 1.6), Color(0.35, 0.22, 0.1, 0.25) if i % 2 == 0 else Color(1, 0.9, 0.7, 0.15)))
	add_child(cork)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	cork.add_child(box)
	var intro := UiKit.label("Goals for your diner. None of them are required and the game never ends; each one reached unlocks something new.", 12, Color("fff4e0"), &"BodyLabel")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(100, 0)
	box.add_child(intro)
	var i := 0
	for g in Data.GOALS:
		box.add_child(_card(g, i))
		i += 1
	Goals.changed.connect(refresh)
	visibility_changed.connect(refresh)
	refresh()


func _card(g: Dictionary, i: int) -> Control:
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("f6f1e6")
	st.set_corner_radius_all(2)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 12
	st.content_margin_bottom = 8
	st.shadow_color = Color(0, 0, 0, 0.3)
	st.shadow_size = 3
	st.shadow_offset = Vector2(1, 2)
	card.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiKit.label(g["name"], 15, Color("3a2e26"), &"StatLabel")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var count := UiKit.label("", 12, Color("7a6a5a"), &"SmallLabel")
	head.add_child(count)
	var d := UiKit.label(g["desc"], 12, Color("5a4a3c"), &"BodyLabel")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(100, 0)
	v.add_child(d)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.theme_type_variation = &"GoalBar"
	v.add_child(bar)
	var rw := HBoxContainer.new()
	rw.add_theme_constant_override("separation", 4)
	v.add_child(rw)
	var r: Dictionary = g["reward"]
	rw.add_child(UiKit.icon_rect("cook" if r.has("dish") else ("decor" if r.has("decor") else "money"), 13, Color("b23a2e")))
	rw.add_child(UiKit.label(Goals.reward_text(g), 12, Color("b23a2e"), &"SmallLabel"))
	var stamp := UiKit.label("", 13, Color("2f7d55"), &"StatLabel")
	stamp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rw.add_child(stamp)
	# a push pin, and a slight tilt of the card's paper
	card.draw.connect(func():
		var c := Vector2(card.size.x / 2.0, 3.0)
		card.draw_circle(c + Vector2(1, 1.5), 4.5, Color(0, 0, 0, 0.3))
		card.draw_circle(c, 4.5, [Color("d23b30"), Color("3f86c6"), Color("f2c14e"), Color("4f9a45")][i % 4])
		card.draw_circle(c + Vector2(-1.3, -1.3), 1.4, Color(1, 1, 1, 0.6)))
	cards[g["key"]] = {"card": card, "bar": bar, "count": count, "stamp": stamp}
	return card


func refresh() -> void:
	if not is_visible_in_tree() and not cards.is_empty() and box.get_child_count() > 1 and _refreshed_once:
		return
	_refreshed_once = true
	for g in Data.GOALS:
		var k: String = g["key"]
		var c: Dictionary = cards[k]
		var p: Array = Goals.progress(k)
		var reached := Goals.is_done(k)
		c["bar"].max_value = p[1]
		c["bar"].value = p[1] if reached else p[0]
		c["count"].text = "done" if reached else ("%d / %d" % [p[0], p[1]] if k != "five_star" else "best %.1f / 4.8" % (p[0] / 10.0))
		c["stamp"].text = ("✓ Reached on day %d" % Goals.done[k]) if reached else ""
		c["card"].modulate = Color(1, 1, 1, 1.0 if not reached else 0.85)


var _refreshed_once := false
