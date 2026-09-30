extends ScrollContainer
## The Menu page: one row per dish (see dish_row.tscn), then the morning
## prep list: how many portions of each dish to prep before opening.

const DishRow = preload("res://ui/dish_row.tscn")

var main
var rows := {}
var price_note: Label
var prep_note: Label
var prep_rows := {}          # dish -> {"spin": SpinBox, "info": Label}
var paper: PanelContainer
var paper_title: Label
var _t := 0.0

@onready var rows_box: VBoxContainer = %Rows


func _ready() -> void:
	price_note = Label.new()
	price_note.theme_type_variation = &"SmallLabel"
	price_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	price_note.custom_minimum_size = Vector2(100, 0)
	rows_box.add_child(price_note)
	# the dishes, printed on a menu card, section by section
	paper = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("f4ecd8")
	st.border_color = Color("c8372d")
	st.set_border_width_all(3)
	st.set_corner_radius_all(10)
	st.content_margin_left = 10
	st.content_margin_right = 8
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	paper.add_theme_stylebox_override("panel", st)
	rows_box.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	paper.add_child(col)
	paper_title = UiKit.label("", 18, Color("c8372d"), &"HeaderLabel")
	paper_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(paper_title)
	var kind := ""
	for d in Data.DISH_ORDER:
		var k: String = Data.DISHES[d]["kind"]
		if k != kind:
			kind = k
			var h := UiKit.label("~ %s ~" % Data.MENU_SECTIONS.get(k, k.capitalize()), 13, Color("b23a2e"), &"StatLabel")
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.custom_minimum_size.y = 26
			h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			col.add_child(h)
		var row = DishRow.instantiate()
		row.setup(d)
		col.add_child(row)
		rows[d] = row
	build_prep_list()
	GameState.menu_changed.connect(refresh)
	visibility_changed.connect(refresh)


func build_prep_list() -> void:
	rows_box.add_child(HSeparator.new())
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(UiKit.icon_rect("prep", 16, UiKit.GOLD))
	var t := Label.new()
	t.text = "Morning prep"
	t.theme_type_variation = &"HeaderLabel"
	head.add_child(t)
	rows_box.add_child(head)
	prep_note = Label.new()
	prep_note.theme_type_variation = &"MutedLabel"
	prep_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prep_note.custom_minimum_size = Vector2(100, 0)
	rows_box.add_child(prep_note)
	for d in Data.DISH_ORDER:
		if not Data.DISHES[d].get("prep", false):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var ic := ArtIcon.new()
		ic.what = "dish:" + d
		ic.custom_minimum_size = Vector2(26, 26)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := Label.new()
		n.text = Data.DISHES[d]["name"]
		n.theme_type_variation = &"BodyLabel"
		col.add_child(n)
		var info := Label.new()
		info.theme_type_variation = &"SmallLabel"
		info.add_theme_color_override("font_color", UiKit.MUTED)
		col.add_child(info)
		row.add_child(col)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 40
		spin.step = 1
		spin.custom_minimum_size = Vector2(84, 0)
		spin.tooltip_text = "Portions of %s to prep each morning." % Data.DISHES[d]["name"].to_lower()
		spin.value = Stock.prep_par.get(d, 0)
		spin.value_changed.connect(func(v: float):
			Stock.prep_par[d] = int(v)
			refresh())
		row.add_child(spin)
		rows_box.add_child(row)
		prep_rows[d] = {"spin": spin, "info": info}


func refresh() -> void:
	paper_title.text = (GameState.diner_name if GameState.diner_name != "" else "Menu")
	var lvl := GameState.price_level()
	var pct := int(round((lvl - 1.0) * 100.0))
	var effect := int(round((GameState.price_demand() - 1.0) * 100.0))
	if absi(pct) < 3:
		price_note.text = "Your prices are about usual. The star makes a dish today's special."
		price_note.add_theme_color_override("font_color", UiKit.MUTED)
	elif pct > 0:
		price_note.text = "Your prices are %d%% above usual: about %d%% fewer customers come, and they'll grumble about value." % [pct, -effect]
		price_note.add_theme_color_override("font_color", UiKit.GOLD)
	else:
		price_note.text = "Your prices are %d%% below usual: about %d%% more customers come." % [-pct, effect]
		price_note.add_theme_color_override("font_color", UiKit.MINT)
	for d in rows:
		if rows[d].is_node_ready():
			rows[d].refresh(main.lot if main != null else null)
	refresh_prep()


func refresh_prep() -> void:
	if prep_note == null:
		return
	var has_counter: bool = main != null and main.lot.has_type("prep")
	if not has_counter:
		prep_note.text = "Build a prep counter (Kitchen) and cooks will prep these before opening. Prepped dishes cook 40% faster."
		prep_note.add_theme_color_override("font_color", UiKit.GOLD)
	else:
		prep_note.text = "Cooks prep these before the doors open. Prepped dishes cook 40% faster, but whatever's left at night is thrown out."
		prep_note.add_theme_color_override("font_color", UiKit.MUTED)
	for d in prep_rows:
		var r: Dictionary = prep_rows[d]
		r["spin"].set_value_no_signal(Stock.prep_par.get(d, 0))
		var bits: Array = []
		if Stock.yesterday.has(d):
			bits.append("%d ordered yesterday" % Stock.yesterday[d])
		if GameState.is_active():
			bits.append("%d ready now" % Stock.ready_portions(d))
		r["info"].text = " · ".join(bits) if not bits.is_empty() else "No orders yet"
		r["info"].visible = true


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not is_visible_in_tree():
		return
	_t = 0.5
	refresh_prep()
