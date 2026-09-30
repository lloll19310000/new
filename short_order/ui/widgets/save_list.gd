class_name SaveList
extends VBoxContainer
## Your saved diners, newest first: name, day, cash, rating and crew, when it
## was saved, and a button to load it (or to save over it). The x deletes a
## save (click twice to be sure). Used by the main menu and the pause menu.

signal picked(slot: String)
signal deleted(slot: String)
signal new_slot_picked

var mode := "load"            # "load" or "save"
var current := ""             # the slot you're playing (marked, and saved to by default)
var _armed := {}              # button -> seconds left to confirm


func _init() -> void:
	add_theme_constant_override("separation", 6)


## saves: from main.list_saves().
func fill(saves: Array, how: String = "load", playing: String = "") -> void:
	mode = how
	current = playing
	_armed = {}
	for c in get_children():
		c.queue_free()
	if mode == "save":
		var fresh := Button.new()
		fresh.text = "Save in a new slot"
		fresh.icon = UiKit.icon("plus")
		fresh.theme_type_variation = &"PrimaryButton"
		fresh.pressed.connect(new_slot_picked.emit)
		add_child(fresh)
	if saves.is_empty():
		var l := Label.new()
		l.text = "No saved diners yet."
		l.theme_type_variation = &"MutedLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)
		return
	for s in saves:
		add_child(_row(s))


func _row(s: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var title := Label.new()
	title.theme_type_variation = &"StatLabel"
	title.text = s["name"] + ("  (playing)" if s["slot"] == current else "")
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(title)
	var info := Label.new()
	info.theme_type_variation = &"SmallLabel"
	info.text = "Day %d  ·  $%s  ·  %.1f stars  ·  %d staff" % [s["day"], UiKit.thousands(int(s["money"])), s["rating"], s["staff"]]
	col.add_child(info)
	if s.get("when", "") != "":
		var when := Label.new()
		when.theme_type_variation = &"MutedLabel"
		when.add_theme_font_size_override("font_size", 11)
		when.text = "Saved " + str(s["when"]).replace("T", " ").substr(0, 16)
		col.add_child(when)
	var go := Button.new()
	go.theme_type_variation = &"SmallButton"
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if mode == "load":
		go.text = "Load"
		go.icon = UiKit.icon("play")
		go.pressed.connect(func(): picked.emit(s["slot"]))
	else:
		go.text = "Save here"
		go.icon = UiKit.icon("save")
		go.tooltip_text = "Save over this one (click twice)"
		go.pressed.connect(func():
			if s["slot"] == current or _confirm(go, "Overwrite?"):
				picked.emit(s["slot"]))
	row.add_child(go)
	var del := Button.new()
	del.theme_type_variation = &"FlatButton"
	del.icon = UiKit.icon("trash")
	del.tooltip_text = "Delete this save (click twice)"
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del.pressed.connect(func():
		if _confirm(del, "Delete?"):
			deleted.emit(s["slot"]))
	row.add_child(del)
	return card


## First click arms the button for a few seconds; the second one goes ahead.
func _confirm(b: Button, ask: String) -> bool:
	if _armed.has(b):
		_armed.erase(b)
		return true
	_armed[b] = 3.0
	b.set_meta("was", b.text)
	b.text = ask
	b.modulate = Color("ff8f7a")
	return false


func _process(delta: float) -> void:
	for b in _armed.keys():
		_armed[b] -= delta
		if _armed[b] <= 0.0 or not is_instance_valid(b):
			_armed.erase(b)
			if is_instance_valid(b):
				b.text = b.get_meta("was", "")
				b.modulate = Color.WHITE
