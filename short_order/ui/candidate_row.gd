extends PanelContainer
## Someone looking for work, as a compact row: face, name, the job they want,
## their skills, traits, hourly pay and a Hire button. Hover for their life
## story and how they'd get on with your crew.

signal hire_requested(index: int)

var data: Dictionary = {}
var index := 0
var hire_button: Button
var bio_label: Label
var origin_label: Label


func setup(d: Dictionary, i: int) -> void:
	data = d
	index = i


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.row_style(Color("2a221d")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var p := Portrait.new()
	p.custom_minimum_size = Vector2(32, 32)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.show_person(data)
	row.add_child(p)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var n := UiKit.label(data["name"], 14, UiKit.INK, &"StatLabel")
	mid.add_child(n)
	var role: String = data.get("role", "server")
	var rc: Color = UiKit.ROLE_COLORS.get(role, UiKit.MUTED)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	mid.add_child(line)
	line.add_child(UiKit.icon_rect(Data.ROLES[role]["icon"], 11, rc))
	line.add_child(UiKit.label(Data.ROLES[role]["name"], 11, rc, &"SmallLabel"))
	var skills := UiKit.label(" · cook %d · serve %d" % [data["cooking"], data["service"]], 11, UiKit.MUTED, &"SmallLabel")
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var traits: Array = data.get("traits", [])
	if not traits.is_empty():
		var names: Array = traits.map(func(t): return Data.TRAITS[t]["name"])
		skills.text += " · " + ", ".join(names)
	skills.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	skills.clip_text = true
	line.add_child(skills)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 1)
	row.add_child(right)
	hire_button = Button.new()
	hire_button.text = "Hire"
	hire_button.icon = UiKit.icon("plus")
	hire_button.theme_type_variation = &"SmallButton"
	hire_button.custom_minimum_size = Vector2(64, 22)
	hire_button.add_theme_font_size_override("font_size", 12)
	hire_button.pressed.connect(func(): hire_requested.emit(index))
	right.add_child(hire_button)
	var w := UiKit.label(Data.hourly(data["wage"]), 11, UiKit.GOLD, &"SmallLabel")
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(w)
	# the life story and clash hints live in the tooltip (and these labels, for tests and screen readers)
	var origin: Dictionary = data.get("origin", {})
	origin_label = Label.new()
	origin_label.text = ("From " + Data.hometown(origin)) if not origin.is_empty() else ""
	origin_label.visible = false
	add_child(origin_label)
	bio_label = Label.new()
	bio_label.text = data.get("bio", "") + ((" Signature dish: %s." % origin.get("dish", "")) if not origin.is_empty() else "")
	bio_label.visible = false
	add_child(bio_label)
	var tips: Array = [("%s, from %s. %s" % [data["name"], Data.hometown(origin), bio_label.text]) if not origin.is_empty() else "%s. %s" % [data["name"], bio_label.text]]
	for t in traits:
		tips.append("%s: %s" % [Data.TRAITS[t]["name"], Data.TRAITS[t]["desc"]])
	tips.append_array(Crew.clash_hints(traits))
	tips.append("Hire as a %s for $%.2f an hour (time and a half past 8 hours, double time past 12)." % [Data.ROLES[role]["name"].to_lower(), data["wage"]])
	tooltip_text = "\n".join(tips)
	hire_button.tooltip_text = tips[-1]
