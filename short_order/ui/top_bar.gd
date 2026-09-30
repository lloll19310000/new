extends PanelContainer
## The bar along the top: cash, day, clock, rating, health grade, the Open
## button and game speed. It listens to GameState and updates itself, and
## tells the HUD when a button is pressed (signals up, calls down).

signal open_pressed
signal speed_chosen(speed: int)
signal help_pressed
signal menu_pressed

const SPEEDS := [0, 1, 2, 4]
const SOUND_ON := preload("res://ui/icons/sound_on.svg")
const SOUND_OFF := preload("res://ui/icons/sound_off.svg")
const ICON_SUN := preload("res://ui/icons/sun.svg")
const ICON_OPEN := preload("res://ui/icons/open.svg")
const ICON_RUSH := preload("res://ui/icons/rush.svg")
const ICON_MOON := preload("res://ui/icons/moon.svg")
const GRADE_COLORS := {"A": Color("6cc3a0"), "B": Color("f2c14e"), "C": Color("e75a4e")}

@onready var money: Label = %Money
@onready var day: Label = %Day
@onready var clock: Label = %Clock
@onready var phase_chip: PanelContainer = %PhaseChip
@onready var phase_icon: TextureRect = %PhaseIcon
@onready var phase_label: Label = %PhaseLabel
@onready var stars: StarRating = %Stars
@onready var rating: Label = %Rating
@onready var grade_chip: PanelContainer = %GradeChip
@onready var grade: Label = %Grade
@onready var level_chip: PanelContainer = %LevelChip
@onready var level: Label = %Level
@onready var open_button: Button = %OpenButton
@onready var speed_buttons: Array = [%Pause, %Play, %Fast, %Faster]
@onready var sound_button: Button = %SoundButton
@onready var help_button: Button = %HelpButton

var _last_money := 0.0
var today_label: Label
var _clock_t := 0.0
var _chip_style: StyleBoxFlat


func _ready() -> void:
	_chip_style = (phase_chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	phase_chip.add_theme_stylebox_override("panel", _chip_style)
	GameState.money_changed.connect(_on_money_changed)
	GameState.rating_changed.connect(func(_r): refresh())
	GameState.phase_changed.connect(func(_p): refresh())
	GameState.grade_changed.connect(func(_g): refresh())
	GameState.level_changed.connect(func(_l): refresh())
	open_button.pressed.connect(open_pressed.emit)
	for i in speed_buttons.size():
		var b: Button = speed_buttons[i]
		b.pressed.connect(speed_chosen.emit.bind(SPEEDS[i]))
	sound_button.set_pressed_no_signal(not Sfx.sound_on)
	sound_button.icon = SOUND_OFF if not Sfx.sound_on else SOUND_ON
	sound_button.toggled.connect(func(muted: bool):
		Sfx.set_sound_on(not muted)
		sound_button.icon = SOUND_OFF if muted else SOUND_ON)
	help_button.pressed.connect(help_pressed.emit)
	# the pause menu: save, load, settings, main menu
	var menu_button := Button.new()
	menu_button.name = "MenuButton"
	menu_button.theme_type_variation = help_button.theme_type_variation
	menu_button.icon = UiKit.icon("bars")
	menu_button.tooltip_text = "Menu: save, load, settings (Esc)"
	menu_button.custom_minimum_size = help_button.custom_minimum_size
	menu_button.pressed.connect(menu_pressed.emit)
	help_button.get_parent().add_child(menu_button)
	Sfx.settings_changed.connect(func():
		sound_button.set_pressed_no_signal(not Sfx.sound_on)
		sound_button.icon = SOUND_OFF if not Sfx.sound_on else SOUND_ON)
	# today's takings, beside the cash
	today_label = UiKit.label("", 11, Color("8ae596"), &"SmallLabel")
	today_label.tooltip_text = "Sales so far today (tips go to the staff)."
	money.get_parent().add_child(today_label)
	_last_money = GameState.money
	refresh()


func show_speed(v: int) -> void:
	for i in speed_buttons.size():
		speed_buttons[i].set_pressed_no_signal(SPEEDS[i] == v)


func _process(delta: float) -> void:
	_clock_t -= delta
	if _clock_t > 0.0:
		return
	_clock_t = 0.2
	clock.text = GameState.clock_text()
	var rev: float = GameState.today.get("revenue", 0.0)
	today_label.visible = GameState.phase != GameState.Phase.PLANNING and rev >= 1.0
	today_label.text = "+$%s today" % format_int(int(rev))
	refresh_phase()


func _on_money_changed(v: float) -> void:
	refresh()
	# a quick green or red flash when cash goes up or down
	var diff := v - _last_money
	_last_money = v
	if absf(diff) < 0.5:
		return
	var tw := money.create_tween()
	money.modulate = Color("8ae596") if diff > 0 else Color("ff8f7a")
	tw.tween_property(money, "modulate", Color.WHITE, 0.6)


func refresh() -> void:
	var m := GameState.money
	money.text = ("-$" if m < 0 else "$") + format_int(int(absf(m)))
	money.add_theme_color_override("font_color", Color("ff8f7a") if m < 0 else Color("f5ecdf"))
	var days := Books.days_to_bills()
	money.tooltip_text = "Cash. Weekly bills (about $%d) are due %s." % [int(Books.bills_week()), "tonight" if days == 0 else "in %d day%s" % [days, "" if days == 1 else "s"]]
	day.text = "Day %d" % GameState.day
	clock.text = GameState.clock_text()
	stars.value = GameState.rating
	rating.text = "%.1f" % GameState.rating
	stars.tooltip_text = "Your rating: %.1f out of 5, the average of the last %d reviews. Higher ratings bring more customers." % [GameState.rating, Data.REVIEW_WINDOW]
	var g := GameState.grade
	grade.text = g if g != "" else "?"
	grade.add_theme_color_override("font_color", GRADE_COLORS.get(g, Color("b9a797")))
	grade_chip.tooltip_text = "Health grade: %s.\nThe inspector comes unannounced, soon after you open and then two to four times a year. A brings more customers, C scares them off." % (g if g != "" else "not inspected yet")
	var lv: Dictionary = GameState.level_info()
	var wide := get_viewport_rect().size.x >= 1400.0 or GameState.phase != GameState.Phase.PLANNING
	level.text = lv["name"] if wide else "Level %d" % (GameState.rep_level + 1)
	var tip := "Reputation: %s (level %d of %d). Customers: +%d%%." % [lv["name"], GameState.rep_level + 1, Data.REP_LEVELS.size(), int(round((lv["mult"] - 1.0) * 100))]
	if GameState.rep_level + 1 < Data.REP_LEVELS.size():
		var nxt: Dictionary = Data.REP_LEVELS[GameState.rep_level + 1]
		tip += "\nNext: %s. Serve %d customers in all (%d so far) and end a day rated %.1f or better.%s" % [
			nxt["name"], nxt["served"], GameState.totals["served"], nxt["rating"], " Tourists start coming." if GameState.rep_level + 1 == 2 else ""]
	level_chip.tooltip_text = tip
	open_button.visible = GameState.phase == GameState.Phase.PLANNING or GameState.phase == GameState.Phase.PREP
	if GameState.phase == GameState.Phase.PREP:
		open_button.text = "Open the doors"
		open_button.tooltip_text = "Skip the rest of prep and let customers in now. Prep that isn't done yet carries on between orders."
	else:
		open_button.text = "Start the day"
		open_button.tooltip_text = "Staff come in at %s to prep and eat, and the doors open at %s. Building stops until tomorrow morning." % [
			DayTimeline.clock(GameState.prep_min()), DayTimeline.clock(GameState.open_min())]
	refresh_phase()


func refresh_phase() -> void:
	var text := ""
	var icon: Texture2D = ICON_SUN
	var col := Color("4a3c34")
	match GameState.phase:
		GameState.Phase.PLANNING:
			text = "Morning"
			icon = ICON_SUN
		GameState.Phase.PREP:
			text = "Prep"
			icon = ICON_SUN
			col = Color("6b5a2e")
		GameState.Phase.SERVICE:
			var r: Dictionary = GameState.current_rush()
			if r.is_empty():
				text = "Open"
				icon = ICON_OPEN
				col = Color("2f6b52")
			elif r["mult"] > 1.0:
				text = r["name"]
				icon = ICON_RUSH
				col = Color("a8452a")
			else:
				text = r["name"]
				icon = ICON_OPEN
				col = Color("3d5a78")
		GameState.Phase.CLEANUP:
			text = "Tidying up"
			icon = ICON_MOON
		GameState.Phase.REPORT:
			text = "Day over"
			icon = ICON_MOON
	phase_chip.tooltip_text = {GameState.Phase.PLANNING: "Morning: build and plan. Time stands still until you start the day.",
		GameState.Phase.PREP: "Before opening: staff prep ingredients, eat together and take the delivery. The doors open at %s." % DayTimeline.clock(GameState.open_min()),
		GameState.Phase.CLEANUP: "Closed: the staff are tidying up before going home."}.get(GameState.phase, text)
	if phase_label.text != text:
		phase_label.text = text
		phase_icon.texture = icon
		_chip_style.bg_color = col


static func format_int(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
