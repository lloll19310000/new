extends PanelContainer
## "Before you open": what's still missing before you can open the doors.
## Shown in the morning only. Click the arrow to fold it away.

var main
var collapsed := false

@onready var count: Label = %Count
@onready var bar: ProgressBar = %Bar
@onready var items: VBoxContainer = %Items
@onready var footer: Label = %Footer
@onready var fold: Button = %Fold


func _ready() -> void:
	fold.pressed.connect(func():
		collapsed = not collapsed
		refresh())


func refresh() -> void:
	if main == null:
		return
	visible = GameState.phase == GameState.Phase.PLANNING
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
