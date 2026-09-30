extends VBoxContainer
## The message ticker: news slides in just under the top bar, a couple at a
## time, and fades away. Every message is also kept in the inbox (the bell in
## the top bar), so nothing is lost if you blink.
## kind picks the colour and icon: "", "good", "bad", "crew", "critic" or "rush".

signal history_changed

const Toast = preload("res://ui/toast.tscn")
const MAX_SHOWN := 2
const MAX_HISTORY := 80
const KINDS := {
	"": {"color": Color("6aa6d9"), "icon": "info", "life": 4.0},
	"good": {"color": Color("6cc3a0"), "icon": "check", "life": 4.0},
	"bad": {"color": Color("e75a4e"), "icon": "alert", "life": 6.0},
	"crew": {"color": Color("e27fa8"), "icon": "heart", "life": 5.5},
	"critic": {"color": Color("b58be0"), "icon": "critic", "life": 6.0},
	"rush": {"color": Color("e2703a"), "icon": "rush", "life": 5.0},
}

## Newest last: {text, kind, day, time}
var history: Array = []
var unread := 0


func show_toast(text: String, kind: String = "") -> void:
	history.append({"text": text, "kind": kind, "day": GameState.day, "time": GameState.clock_text()})
	if history.size() > MAX_HISTORY:
		history = history.slice(history.size() - MAX_HISTORY)
	unread += 1
	history_changed.emit()
	var k: Dictionary = KINDS.get(kind, KINDS[""])
	var t: PanelContainer = Toast.instantiate()
	t.custom_minimum_size = Vector2(380, 0)
	add_child(t)
	move_child(t, 0)   # newest on top, right under the bar
	var lbl: Label = t.get_node("%Text")
	lbl.text = text
	lbl.custom_minimum_size = Vector2(330, 0)
	var icon: TextureRect = t.get_node("%Icon")
	icon.texture = UiKit.icon(k["icon"])
	icon.self_modulate = k["color"]
	var style := (t.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	style.border_color = k["color"]
	style.border_width_left = 4
	t.add_theme_stylebox_override("panel", style)
	while get_child_count() > MAX_SHOWN:
		var old := get_child(get_child_count() - 1)
		remove_child(old)
		old.queue_free()
	if kind in ["", "good", "rush"]:
		Sfx.play("pop", -14.0)
	# drop in from the bar and fade in, wait, then fade out
	t.modulate.a = 0.0
	var inner: Control = t.get_node("Row")
	var tw := t.create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "modulate:a", 1.0, 0.18).from(0.0)
	tw.tween_property(inner, "position:y", inner.position.y, 0.25).from(inner.position.y - 10.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(k["life"])
	tw.chain().tween_property(t, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(t.queue_free)


func mark_read() -> void:
	unread = 0
	history_changed.emit()


func clear_history() -> void:
	history.clear()
	unread = 0
	history_changed.emit()
