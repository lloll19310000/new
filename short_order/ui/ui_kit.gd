class_name UiKit
extends RefCounted
## Small helpers shared by the interface scripts: icons, colours and
## little pieces (trait chips, icon + number rows) built in code.

const INK := Color("f5ecdf")
const MUTED := Color("b9a797")
const FAINT := Color("7d6d61")
const GOLD := Color("f2c14e")
const MINT := Color("6cc3a0")
const CHERRY := Color("e75a4e")
const SKY := Color("6aa6d9")

## Priority colours: 1 is hot (do first), 4 is cool (do last), 0 is off.
const PRIORITY_COLORS := {1: Color("ff7a6b"), 2: Color("f5a445"), 3: Color("e9d58f"), 4: Color("9fb6cc"), 0: Color("6d5f55")}

const JOB_ICONS := {"cook": "cook", "serve": "serve", "host": "host", "wash": "wash", "clean": "clean", "fix": "fix"}

static var _icons := {}


static func icon(n: String) -> Texture2D:
	if not _icons.has(n):
		_icons[n] = load("res://ui/icons/%s.svg" % n)
	return _icons[n]


static func icon_rect(n: String, px: float = 16.0, tint: Color = INK) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(n)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.self_modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func trait_chip(key: String) -> Control:
	var info: Dictionary = Data.TRAITS[key]
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.tooltip_text = "%s: %s" % [info["name"], info["desc"]]
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(icon_rect("sparkle", 10, MINT if info["good"] else CHERRY))
	var l := Label.new()
	l.text = info["name"]
	l.theme_type_variation = &"SmallLabel"
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", MINT if info["good"] else CHERRY)
	row.add_child(l)
	return chip


## A small coloured label with an icon, like a trait chip (Manager, warnings).
static func tag_chip(text: String, icon_name: String, color: Color, tip: String = "") -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.tooltip_text = tip
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(icon_rect(icon_name, 10, color))
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"SmallLabel"
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	row.add_child(l)
	return chip


static func fill_traits(box: Container, traits: Array) -> void:
	for c in box.get_children():
		c.queue_free()
	for t in traits:
		if Data.TRAITS.has(t):
			box.add_child(trait_chip(t))


static func priority_text(p: int) -> String:
	return str(p) if p > 0 else "–"


static func money(v: float) -> String:
	return ("-$" if v < 0 else "$") + str(int(round(absf(v))))


## 12500 -> "12,500"
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
