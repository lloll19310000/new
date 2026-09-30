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
}
const SLIDE := 0.22
const PANEL_W := 358.0

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
	pages["staff"].hire_requested.connect(func(i: int): hire_requested.emit(i))
	pages["staff"].fire_requested.connect(func(w): fire_requested.emit(w))
	for k in tabs:
		tabs[k].pressed.connect(toggle.bind(k))
	close_button.pressed.connect(close)
	Crew.big_moment.connect(func():
		if not (is_open and current == "crew"):
			crew_badge.visible = true)
	show_page(current)


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
