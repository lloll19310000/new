extends ScrollContainer
## The review wall: what people wrote about your diner, newest first, with a
## picture of what they ate. Reply to each one: a thank-you, an apology with
## a free pie, or an argument. How you reply shapes how people see you online.

var box: VBoxContainer
var mood_label: Label
var _key := ""


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	visibility_changed.connect(refresh)
	GameState.rating_changed.connect(func(_r): refresh())


func refresh() -> void:
	if box == null or not is_visible_in_tree():
		return
	var key := "%d|%d|%s" % [GameState.review_feed.size(), int(GameState.reply_mood * 10), str(GameState.review_feed.map(func(r): return r["reply"] != ""))]
	if key == _key:
		return
	_key = key
	for c in box.get_children():
		c.queue_free()
	mood_label = UiKit.label("", 12, UiKit.MUTED, &"MutedLabel")
	mood_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mood_label.custom_minimum_size = Vector2(100, 0)
	var m := GameState.reply_mood
	mood_label.text = "What people write about you online. %s" % ("Your replies go down well: a few more people come in." if m >= 1.0 else
		("Your replies are putting people off: fewer come in." if m <= -1.0 else "Reply to reviews: kind replies bring people in, arguments drive them away."))
	box.add_child(mood_label)
	if GameState.review_feed.is_empty():
		box.add_child(UiKit.label("No reviews yet.", 12, UiKit.MUTED, &"MutedLabel"))
		return
	for i in range(GameState.review_feed.size() - 1, -1, -1):
		box.add_child(_card(GameState.review_feed[i]))


func _card(r: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var photo := ArtIcon.new()
	photo.what = "dish:" + str(r["dish"]) if Data.DISHES.has(str(r["dish"])) else "dish:coffee"
	photo.custom_minimum_size = Vector2(34, 34)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(photo)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", -2)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(UiKit.label(str(r["who"]), 13, UiKit.INK, &"StatLabel"))
	var st := StarRating.new()
	st.value = float(r["score"])
	st.custom_minimum_size = Vector2(70, 13)
	who.add_child(st)
	head.add_child(who)
	head.add_child(UiKit.label(Town.date_text(int(r["day"])), 11, UiKit.FAINT, &"SmallLabel"))
	var t := UiKit.label("“%s”" % r["text"], 12, UiKit.INK, &"BodyLabel")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(100, 0)
	v.add_child(t)
	if str(r["reply"]) != "":
		var rep := UiKit.label("Owner: " + str(r["reply"]), 11, UiKit.GOLD, &"SmallLabel")
		rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rep.custom_minimum_size = Vector2(100, 0)
		v.add_child(rep)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var id := int(r["id"])
		for opt in [["thank", "Thank them"], ["sorry", "Make it right ($%d pie)" % int(Data.REPLY_FREE_PIE) if float(r["score"]) < 3.5 else "Apologise"], ["argue", "Argue"]]:
			var b := Button.new()
			b.text = opt[1]
			b.theme_type_variation = &"SmallButton"
			b.add_theme_font_size_override("font_size", 11)
			var how: String = opt[0]
			b.pressed.connect(func():
				GameState.reply_review(id, how)
				_key = ""
				refresh())
			row.add_child(b)
		v.add_child(row)
	return card
