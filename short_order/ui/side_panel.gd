extends Control
## The panel on the right with Staff, Menu, Supplies, Crew and Office pages.
## Click an icon on the rail to open that page; click it again (or the
## arrow, or press Tab) to slide the panel away and see more of the diner.

signal hire_requested(index: int)
signal fire_requested(who)

const PAGES := {
	"staff": {"title": "Staff", "icon": "staff"},
	"menu": {"title": "Menu", "icon": "menu"},
	"supplies": {"title": "Supplies", "icon": "supplies"},
	"crew": {"title": "Crew", "icon": "crew"},
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
	close_button.pressed.connect(close)
	Crew.big_moment.connect(func():
		if not (is_open and current == "crew"):
			crew_badge.visible = true)
	show_page(current)


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
	if is_open and current == key:
		close()
	else:
		open(key)


func show_page(key: String) -> void:
	current = key
	for k in pages:
		pages[k].visible = k == key
		tabs[k].set_pressed_no_signal(is_open and k == key)
	title.text = PAGES[key]["title"]
	# a page with something wide could have stretched the panel; snap it back
	panel.offset_right = panel.offset_left + PANEL_W
	title_icon.texture = UiKit.icon(PAGES[key]["icon"])
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
