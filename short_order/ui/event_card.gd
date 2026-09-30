extends Control
## The card that pops up when an event needs you to choose (see autoload/events.gd).
## The game pauses while it's open; each option is a button with a line
## under it saying what will happen.

signal chosen(index: int)

@onready var title: Label = %Title
@onready var body: Label = %Body
@onready var options: VBoxContainer = %Options
@onready var card: PanelContainer = %Card


func show_event(ev: Dictionary) -> void:
	title.text = ev["title"]
	body.text = ev["text"]
	for c in options.get_children():
		c.queue_free()
	for i in ev["options"].size():
		var o: Dictionary = ev["options"][i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var b := Button.new()
		b.text = o["label"]
		b.theme_type_variation = &"PrimaryButton" if i == 0 else &"SmallButton"
		b.custom_minimum_size = Vector2(0, 34)
		b.pressed.connect(func():
			visible = false
			chosen.emit(i))
		row.add_child(b)
		var d := Label.new()
		d.text = o.get("desc", "")
		d.theme_type_variation = &"MutedLabel"
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(300, 0)
		row.add_child(d)
		options.add_child(row)
	visible = true
	card.pivot_offset = card.size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).from(Vector2(0.94, 0.94)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.18).from(0.0)


## Tests and the balance run press buttons through this.
func option_buttons() -> Array:
	var out: Array = []
	for row in options.get_children():
		if not row.is_queued_for_deletion():
			out.append(row.get_child(0))
	return out
