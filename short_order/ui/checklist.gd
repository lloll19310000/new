extends PanelContainer
## "Before you open": what's still missing before you can open the doors.
## Shown in the morning only. After the first day it starts folded into a
## small pill ("6 of 8 ready"); click it to open the full list.

var main
var collapsed := false
var _last_day := -1
var pinned := false          # you opened it yourself, so it doesn't fold itself away

@onready var count: Label = %Count
@onready var bar: ProgressBar = %Bar
@onready var items: VBoxContainer = %Items
@onready var footer: Label = %Footer
@onready var fold: Button = %Fold


func _ready() -> void:
	fold.pressed.connect(toggle)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent):
		if collapsed and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			toggle()
			accept_event())


func toggle() -> void:
	collapsed = not collapsed
	pinned = not collapsed   # opened by hand: it stays open
	refresh()


func refresh() -> void:
	if main == null:
		return
	visible = GameState.phase == GameState.Phase.PLANNING
	if GameState.day != _last_day:
		# a new morning: the full list on day one, a pill after that
		_last_day = GameState.day
		collapsed = GameState.day > 1
	var list: Array = main.lot.checklist()
	var done := 0
	var needed := 0
	for it in list:
		if it.size() > 2 and it[2]:
			continue
		needed += 1
		if it[1]:
			done += 1
	count.text = "%d of %d" % [done, needed]
	bar.value = 100.0 * done / needed
	fold.icon = UiKit.icon("chevron_right" if collapsed else "chevron_left")
	var title: Label = $Box/Header/Title
	title.text = ("Ready to open" if done == needed else "Before you open") if not collapsed else ("All %d ready" % needed if done == needed else "%d of %d ready" % [done, needed])
	title.theme_type_variation = &"StatLabel" if collapsed else &"HeaderLabel"
	count.visible = not collapsed
	custom_minimum_size.x = 170.0 if collapsed else 300.0
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tooltip_text = "Click to see what's left to do before you open." if collapsed else ""
	fold.tooltip_text = "Show the list" if collapsed else "Fold the list into a pill"
	($Box/Header/Icon as TextureRect).self_modulate = UiKit.MINT if done == needed else UiKit.GOLD
	for c in items.get_children():
		c.queue_free()
	items.visible = not collapsed
	footer.visible = not collapsed
	for it in list:
		var optional: bool = it.size() > 2 and it[2]
		if optional and it[1]:
			continue   # recommended and already done: no need to show it
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var ic := "check" if it[1] else ("info" if optional else "plus")
		row.add_child(UiKit.icon_rect(ic, 15, UiKit.MINT if it[1] else (UiKit.GOLD if optional else UiKit.FAINT)))
		var l := Label.new()
		l.text = ("Recommended: " if optional else "") + it[0]
		l.theme_type_variation = &"BodyLabel"
		l.add_theme_color_override("font_color", UiKit.INK if it[1] else (UiKit.GOLD if optional else UiKit.MUTED))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(200, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		items.add_child(row)
	if done == needed:
		footer.text = "Ready! Press Start the day."
		footer.add_theme_color_override("font_color", UiKit.MINT)
	else:
		footer.text = "Build inside your lot (the outlined land). Buy more with Buy land. Hover over the build buttons for tips."
		footer.add_theme_color_override("font_color", UiKit.MUTED)
