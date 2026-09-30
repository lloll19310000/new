extends Control
## The panel on the right. Five buttons on the rail (Staff, Menu, Office,
## Goals, Reviews); pages that belong together share one, with a row of
## sub-tabs at the top (Staff: Team and Crew; Menu: Menu and Supplies;
## Office: Office, Books and Scrapbook). Click a rail button again (or the
## arrow, or press Tab) to slide the panel away and see more of the diner.

signal hire_requested(index: int)
signal fire_requested(who)

## Rail button -> the pages under it, first one shown by default.
const GROUPS := {
	"staff": ["staff", "crew"],
	"menu": ["menu", "supplies"],
	"office": ["office", "books", "scrapbook"],
	"goals": ["goals"],
	"reviews": ["reviews"],
}
const SUBTAB_NAMES := {"staff": "Team", "crew": "Morale", "menu": "Menu", "supplies": "Supplies", "office": "Office",
	"books": "Books", "scrapbook": "Scrapbook"}
const PAGES := {
	"staff": {"title": "Staff", "icon": "staff"},
	"menu": {"title": "Menu", "icon": "menu"},
	"supplies": {"title": "Supplies", "icon": "supplies"},
	"crew": {"title": "Morale", "icon": "crew"},
	"office": {"title": "Office", "icon": "office"},
	"goals": {"title": "Goals", "icon": "star"},
	"reviews": {"title": "Reviews", "icon": "chat"},
	"books": {"title": "Books", "icon": "money"},
	"scrapbook": {"title": "Scrapbook", "icon": "camera"},
}
const SLIDE := 0.22
const PANEL_W := 330.0

var main
var is_open := true
var current := "staff"
var _tween: Tween
var subtabs: HBoxContainer

@onready var panel: PanelContainer = %Panel
@onready var title: Label = %Title
@onready var title_icon: TextureRect = %TitleIcon
@onready var close_button: Button = %Close
@onready var pages := {"staff": %StaffPage, "menu": %MenuPage, "supplies": %SuppliesPage, "crew": %CrewPage, "office": %OfficePage}
@onready var tabs := {"staff": %StaffTab, "menu": %MenuTab, "supplies": %SuppliesTab, "crew": %CrewTab, "office": %OfficeTab}
@onready var crew_badge: Label = %CrewBadge


func setup(m) -> void:
	main = m
	pages["menu"].main = m
	pages["office"].main = m


func _ready() -> void:
	# the Goals board: a page and a rail button, built here
	var gp := preload("res://ui/goals_page.gd").new()
	gp.name = "GoalsPage"
	gp.visible = false
	pages["office"].get_parent().add_child(gp)
	pages["goals"] = gp
	var office_tab: Button = tabs["office"]
	var gt := office_tab.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION) as Button
	gt.name = "GoalsTab"
	gt.icon = UiKit.icon("star")
	gt.tooltip_text = "Goals: milestones for your diner, with rewards"
	gt.set_pressed_no_signal(false)
	office_tab.get_parent().add_child(gt)
	tabs["goals"] = gt
	_add_page("reviews", preload("res://ui/reviews_page.gd").new(), "chat", "Reviews: what people write about you, and your replies")
	_add_page("books", preload("res://ui/books_page.gd").new(), "money", "Books: profit, customers, busiest hours and best sellers over time")
	_add_page("scrapbook", preload("res://ui/scrapbook_page.gd").new(), "camera", "Scrapbook: your diner's story in snapshots (P takes a photo)")
	Goals.changed.connect(func():
		if not (is_open and current == "goals"):
			gt.modulate = Color(1.4, 1.25, 0.8))
	pages["staff"].hire_requested.connect(func(i: int): hire_requested.emit(i))
	pages["staff"].fire_requested.connect(func(w): fire_requested.emit(w))
	for k in tabs:
		tabs[k].pressed.connect(toggle.bind(k))
		# only the first page of each group keeps its button on the rail
		tabs[k].visible = GROUPS.has(k)
	# the rail in order: Staff, Menu, Office, Goals, Reviews
	var rail: Node = tabs["staff"].get_parent()
	var order := 0
	for g in GROUPS:
		rail.move_child(tabs[g], order)
		order += 1
	# crew news shows on the Staff button now
	crew_badge.reparent(tabs["staff"], false)
	subtabs = HBoxContainer.new()
	subtabs.name = "SubTabs"
	subtabs.add_theme_constant_override("separation", 4)
	var box: Node = title.get_parent().get_parent()
	box.add_child(subtabs)
	box.move_child(subtabs, title.get_parent().get_index() + 1)
	close_button.pressed.connect(close)
	Crew.big_moment.connect(func():
		if not (is_open and current == "crew"):
			crew_badge.visible = true)
	show_page(current)


## The rail button a page lives under.
static func group_of(key: String) -> String:
	for g in GROUPS:
		if key in GROUPS[g]:
			return g
	return key


func _build_subtabs(key: String) -> void:
	for c in subtabs.get_children():
		c.queue_free()
	var g := group_of(key)
	var list: Array = GROUPS.get(g, [key])
	subtabs.visible = list.size() > 1
	if list.size() < 2:
		return
	for k in list:
		var b := Button.new()
		b.text = SUBTAB_NAMES.get(k, PAGES[k]["title"])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.theme_type_variation = &"CategoryButton"
		b.set_pressed_no_signal(k == key)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_page.bind(k))
		subtabs.add_child(b)


## A page built in code, with its own button on the rail.
func _add_page(key: String, page: Control, icon_name: String, tip: String) -> void:
	page.name = key.capitalize() + "Page"
	page.visible = false
	pages["office"].get_parent().add_child(page)
	pages[key] = page
	var office_tab: Button = tabs["office"]
	var t := office_tab.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION) as Button
	t.name = key.capitalize() + "Tab"
	t.icon = UiKit.icon(icon_name)
	t.tooltip_text = tip
	t.set_pressed_no_signal(false)
	office_tab.get_parent().add_child(t)
	tabs[key] = t   # (connected with the others in _ready)


func toggle(key: String) -> void:
	if is_open and (current == key or (GROUPS.has(key) and group_of(current) == key)):
		close()
	else:
		open(key)


func show_page(key: String) -> void:
	current = key
	var g := group_of(key)
	for k in pages:
		pages[k].visible = k == key
		tabs[k].set_pressed_no_signal(is_open and k == g)
	title.text = PAGES[g]["title"] if GROUPS.has(g) else PAGES[key]["title"]
	if subtabs != null:
		_build_subtabs(key)
	# a page with something wide could have stretched the panel; snap it back
	panel.offset_right = panel.offset_left + PANEL_W
	title_icon.texture = UiKit.icon(PAGES[g]["icon"] if GROUPS.has(g) else PAGES[key]["icon"])
	if key == "crew":
		crew_badge.visible = false
	if key == "goals":
		tabs["goals"].modulate = Color.WHITE


func open(key: String) -> void:
	var was_open := is_open
	is_open = true
	show_page(key)
	if was_open:
		return
	panel.visible = true
	_slide(0.0, 1.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	for k in tabs:
		tabs[k].set_pressed_no_signal(false)
	_slide(60.0, 0.0)
	_tween.tween_callback(func(): panel.visible = is_open)


func _slide(x: float, alpha: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if alpha > 0.5:
		panel.position.x = 60.0
		panel.modulate.a = 0.0
	_tween.tween_property(panel, "position:x", x, SLIDE)
	_tween.tween_property(panel, "modulate:a", alpha, SLIDE)
	_tween.chain()
