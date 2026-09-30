extends ScrollContainer
## The scrapbook: your diner's story in snapshots. Opening day, the first
## critic, each promotion and employee of the month, catering jobs, goals,
## regulars' big moments, and any photo you take (press P).

var grid: GridContainer
var _count := -1


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var top := HBoxContainer.new()
	var intro := UiKit.label("Your diner's story. Big moments are added by themselves; press P (or the camera) to take your own.", 12, UiKit.MUTED, &"MutedLabel")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(100, 0)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(intro)
	var cam := Button.new()
	cam.icon = UiKit.icon("camera")
	cam.tooltip_text = "Take a photo (P)"
	cam.theme_type_variation = &"SmallButton"
	cam.pressed.connect(func():
		if Crew.main != null:
			Crew.main.take_photo()
			await get_tree().create_timer(0.3).timeout
			_count = -1
			refresh())
	top.add_child(cam)
	box.add_child(top)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	visibility_changed.connect(refresh)


func refresh() -> void:
	if grid == null or not is_visible_in_tree() or GameState.scrapbook.size() == _count:
		return
	_count = GameState.scrapbook.size()
	for c in grid.get_children():
		c.queue_free()
	if GameState.scrapbook.is_empty():
		grid.add_child(UiKit.label("Nothing yet.", 12, UiKit.MUTED, &"MutedLabel"))
		return
	for i in range(GameState.scrapbook.size() - 1, -1, -1):
		grid.add_child(_page(GameState.scrapbook[i]))


func _page(p: Dictionary) -> Control:
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("f6f1e6")
	st.set_corner_radius_all(2)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", st)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(130, 74)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path: String = p.get("img", "")
	if path != "" and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			pic.texture = ImageTexture.create_from_image(img)
	if pic.texture == null:
		var ph := ColorRect.new()
		ph.color = Color("3a2e26")
		ph.custom_minimum_size = Vector2(130, 74)
		var ic := UiKit.icon_rect({"opening": "open", "critic": "critic", "eotm": "star", "goal": "star", "catering": "van", "promotion": "school", "regular": "heart", "dish": "cook", "level": "star", "rival": "storm", "photo": "camera"}.get(p["kind"], "sparkle"), 30, Color("f2c14e"))
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		ph.add_child(ic)
		v.add_child(ph)
	else:
		v.add_child(pic)
	var t := UiKit.label(str(p["title"]), 12, Color("3a2e26"), &"StatLabel")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(60, 0)
	v.add_child(t)
	var d := UiKit.label("Day %d. %s" % [int(p["day"]), p["text"]], 10, Color("6a5a4c"), &"SmallLabel")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(60, 0)
	v.add_child(d)
	return card
