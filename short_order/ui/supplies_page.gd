extends ScrollContainer
## The Supplies page: the supplier, fridge and freezer space, ingredient
## stock (and what goes off tonight), tonight's order and plates.

const SupplyRow = preload("res://ui/supply_row.tscn")
const PLATE_PACK := 6

var rows := {}
var _t := 0.0
var supplier_buttons := {}
var supplier_note: Label
var space_labels := {}
var space_bars := {}

@onready var rows_box: VBoxContainer = %Rows
@onready var delivery: Label = %Delivery
@onready var plates: Label = %Plates
@onready var plate_bar: ProgressBar = %PlateBar
@onready var buy_plates: Button = %BuyPlates


func _ready() -> void:
	# who delivers: cheaper or better ingredients
	var box: VBoxContainer = rows_box.get_parent()
	var head := Label.new()
	head.text = "Supplier"
	head.theme_type_variation = &"HeaderLabel"
	box.add_child(head)
	box.move_child(head, rows_box.get_index())
	var row_box := HBoxContainer.new()
	row_box.add_theme_constant_override("separation", 6)
	box.add_child(row_box)
	box.move_child(row_box, rows_box.get_index())
	var group := ButtonGroup.new()
	for k in Data.SUPPLIER_ORDER:
		var b := Button.new()
		b.text = Data.SUPPLIERS[k]["name"]
		b.theme_type_variation = &"SmallButton"
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s: %s\nDelivery costs x%.2f." % [Data.SUPPLIERS[k]["name"], Data.SUPPLIERS[k]["desc"], Data.SUPPLIERS[k]["cost"]]
		b.pressed.connect(func():
			GameState.supplier = k
			GameState.stock_changed.emit())
		row_box.add_child(b)
		supplier_buttons[k] = b
	supplier_note = Label.new()
	supplier_note.theme_type_variation = &"MutedLabel"
	supplier_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	supplier_note.custom_minimum_size = Vector2(100, 0)
	box.add_child(supplier_note)
	box.move_child(supplier_note, rows_box.get_index())
	# fridge and freezer space
	var space_head := Label.new()
	space_head.text = "Storage"
	space_head.theme_type_variation = &"HeaderLabel"
	box.add_child(space_head)
	box.move_child(space_head, rows_box.get_index())
	for space in ["fridge", "freezer"]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var l := Label.new()
		l.theme_type_variation = &"SmallLabel"
		l.custom_minimum_size = Vector2(150, 0)
		r.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(bar)
		box.add_child(r)
		box.move_child(r, rows_box.get_index())
		space_labels[space] = l
		space_bars[space] = bar
	var ing_head := Label.new()
	ing_head.text = "Ingredients"
	ing_head.theme_type_variation = &"HeaderLabel"
	box.add_child(ing_head)
	box.move_child(ing_head, rows_box.get_index())
	for ing in Data.ING_ORDER:
		var row = SupplyRow.instantiate()
		row.setup(ing)
		rows_box.add_child(row)
		rows[ing] = row
	buy_plates.text = "Buy %d  ($%d)" % [PLATE_PACK, int(Data.PLATE_COST * PLATE_PACK)]
	buy_plates.pressed.connect(func():
		if GameState.spend(Data.PLATE_COST * PLATE_PACK):
			GameState.plates_total += PLATE_PACK
			GameState.plates_clean += PLATE_PACK
			refresh())
	GameState.stock_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for ing in rows:
		if rows[ing].is_node_ready():
			rows[ing].refresh()
	var order := Stock.plan_order()
	var lines: Array = []
	if Stock.delivery_at >= 0.0 and GameState.is_active():
		lines.append("This morning's delivery ($%d) is on its way%s." % [int(ceil(Stock.pending_cost)), ", running late" if Stock.delivery_late else ""])
	elif GameState.phase == GameState.Phase.PLANNING and Stock.pending_cost > 0.0:
		lines.append("The van comes after you start the day: $%d, paid on delivery." % int(ceil(Stock.pending_cost)))
	lines.append("Tonight's order: about $%d, delivered tomorrow morning." % int(ceil(Stock.order_cost(order))))
	if not Stock.short_fit.is_empty():
		var bits: Array = []
		for ing in Stock.short_fit:
			bits.append("%d %s" % [Stock.short_fit[ing], Data.INGREDIENTS[ing]["name"].to_lower()])
		lines.append("Won't fit: %s. Build another fridge or freezer, or keep less." % ", ".join(bits))
	delivery.text = "\n".join(lines)
	delivery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delivery.custom_minimum_size = Vector2(100, 0)
	for space in space_labels:
		var cap := Stock.capacity(space)
		var used := Stock.used(space)
		space_labels[space].text = "%s  %d of %d" % [Data.STORE_NAMES[space], used, cap]
		space_labels[space].add_theme_color_override("font_color", UiKit.CHERRY if cap == 0 or used > cap else UiKit.INK)
		space_bars[space].max_value = maxf(1.0, maxf(cap, used))
		space_bars[space].value = used
		space_bars[space].theme_type_variation = &"WarnBar" if used > cap else &"ProgressBar"
		space_labels[space].tooltip_text = "Fridges hold %d chilled portions each (and %d frozen); freezers hold %d frozen." % [
			Data.STORAGE["fridge"]["fridge"], Data.STORAGE["fridge"]["freezer"], Data.STORAGE["freezer"]["freezer"]]
	for k in supplier_buttons:
		supplier_buttons[k].set_pressed_no_signal(GameState.supplier == k)
	var sp: Dictionary = Data.SUPPLIERS[GameState.supplier]
	supplier_note.text = "%s Deliveries cost %s, and food comes out %s." % [sp["desc"],
		"the usual" if sp["cost"] == 1.0 else ("%d%% more" % int(round((sp["cost"] - 1.0) * 100)) if sp["cost"] > 1.0 else "%d%% less" % int(round((1.0 - sp["cost"]) * 100))),
		"as usual" if sp["quality"] == 0.0 else ("better" if sp["quality"] > 0.0 else "worse")]
	plates.text = "%d clean of %d" % [GameState.plates_clean, GameState.plates_total]
	plate_bar.max_value = maxf(1.0, GameState.plates_total)
	plate_bar.value = GameState.plates_clean
	plate_bar.theme_type_variation = &"WarnBar" if GameState.plates_clean < 6 else &"ProgressBar"


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not is_visible_in_tree():
		return
	_t = 0.3
	refresh()
