extends VBoxContainer
## The build menu in the bottom left. Pick a category to open its tray of
## items, then pick an item to build it. Inspect and Remove are tools too.
## The categories and their items come from Data.BUILD_MENU.

signal tool_chosen(tool: String)

const BuildCard = preload("res://ui/build_card.tscn")

@onready var hint_panel: PanelContainer = %HintPanel
@onready var hint: Label = %Hint
@onready var tray: PanelContainer = %Tray
@onready var tray_title: Label = %TrayTitle
@onready var cards: HBoxContainer = %Cards
@onready var categories: HBoxContainer = %Categories
@onready var inspect_button: Button = %Inspect
@onready var remove_button: Button = %Remove

var category_buttons := {}      # category key -> Button
var card_buttons := {}          # item key -> build card, for the open tray
var open_category := ""
var current_tool := "select"


func _ready() -> void:
	for c in Data.BUILD_MENU:
		var b := Button.new()
		b.theme_type_variation = &"CategoryButton"
		b.toggle_mode = true
		b.text = c["name"]
		b.icon = load("res://ui/icons/%s.svg" % c["icon"])
		var names: Array = c["items"].map(func(k): return Data.item_name(k))
		b.set_meta("tip", "%s: %s" % [c["name"], ", ".join(names)])
		b.tooltip_text = b.get_meta("tip")
		b.pressed.connect(toggle_category.bind(c["key"]))
		categories.add_child(b)
		categories.move_child(b, remove_button.get_index())
		category_buttons[c["key"]] = b
	inspect_button.pressed.connect(func():
		close_tray()
		tool_chosen.emit("select"))
	remove_button.pressed.connect(func():
		close_tray()
		tool_chosen.emit("remove"))
	GameState.phase_changed.connect(func(_p): refresh_phase())
	GameState.menu_changed.connect(refresh_cards)
	refresh_phase()
	set_current("select")


func toggle_category(key: String) -> void:
	if open_category == key:
		close_tray()
	else:
		open_tray(key)


func open_tray(key: String) -> void:
	open_category = key
	for c in cards.get_children():
		c.queue_free()
	card_buttons = {}
	for c in Data.BUILD_MENU:
		if c["key"] != key:
			continue
		tray_title.text = c["name"]
		for item in c["items"]:
			var card = BuildCard.instantiate()
			card.setup(item)
			if c["items"].size() > 11:
				card.custom_minimum_size.x = 80   # a long tray: narrower cards so it still fits
			card.chosen.connect(func(k: String): tool_chosen.emit(k))
			cards.add_child(card)
			card_buttons[item] = card
	tray.visible = true
	set_current(current_tool)


func close_tray() -> void:
	open_category = ""
	tray.visible = false
	for k in category_buttons:
		category_buttons[k].set_pressed_no_signal(false)


## Called by the HUD whenever the build tool changes, to highlight the right button.
func set_current(tool: String) -> void:
	current_tool = tool
	inspect_button.set_pressed_no_signal(tool == "select")
	remove_button.set_pressed_no_signal(tool == "remove")
	for k in category_buttons:
		category_buttons[k].set_pressed_no_signal(k == open_category)
	for k in card_buttons:
		if is_instance_valid(card_buttons[k]):
			card_buttons[k].set_pressed_no_signal(k == tool)
	var text := ""
	match tool:
		"select":
			text = ""
		"remove":
			text = "Drag a box to remove things: furniture first, then walls and doors, then floor. You get half the price back."
		_:
			text = Data.item_desc(tool)
			if Data.FURNITURE.has(tool):
				text += "  R turns it."
			text += "  Esc stops building."
	hint.text = text
	hint_panel.visible = text != ""


func refresh_cards() -> void:
	for k in card_buttons:
		if is_instance_valid(card_buttons[k]):
			card_buttons[k].refresh()


func refresh_phase() -> void:
	var can := GameState.is_building_allowed()
	for k in category_buttons:
		var b: Button = category_buttons[k]
		b.disabled = not can
		b.tooltip_text = b.get_meta("tip") if can else "Building only works in the morning, before you open."
	remove_button.disabled = not can
	if not can:
		close_tray()
		if current_tool != "select":
			tool_chosen.emit("select")


## Picks a tool as if its button were clicked (used by the automatic UI test).
func choose(tool: String) -> void:
	for c in Data.BUILD_MENU:
		if tool in c["items"] and open_category != c["key"]:
			open_tray(c["key"])
	if card_buttons.has(tool):
		card_buttons[tool].pressed.emit()
	elif tool == "select":
		inspect_button.pressed.emit()
	elif tool == "remove":
		remove_button.pressed.emit()
