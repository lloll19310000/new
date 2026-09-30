extends VBoxContainer
## Little messages in the bottom left that slide in and fade away.
## kind picks the colour and icon: "", "good", "bad", "crew", "critic" or "rush".

const Toast = preload("res://ui/toast.tscn")
const MAX_SHOWN := 4
const KINDS := {
	"": {"color": Color("6aa6d9"), "icon": "info", "life": 4.5},
	"good": {"color": Color("6cc3a0"), "icon": "check", "life": 4.5},
	"bad": {"color": Color("e75a4e"), "icon": "alert", "life": 6.0},
	"crew": {"color": Color("e27fa8"), "icon": "heart", "life": 7.0},
	"critic": {"color": Color("b58be0"), "icon": "critic", "life": 7.0},
	"rush": {"color": Color("e2703a"), "icon": "rush", "life": 6.0},
}


func show_toast(text: String, kind: String = "") -> void:
	var k: Dictionary = KINDS.get(kind, KINDS[""])
	var t: PanelContainer = Toast.instantiate()
	add_child(t)
	t.get_node("%Text").text = text
	var icon: TextureRect = t.get_node("%Icon")
	icon.texture = UiKit.icon(k["icon"])
	icon.self_modulate = k["color"]
	var style := (t.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	style.border_color = k["color"]
	t.add_theme_stylebox_override("panel", style)
	while get_child_count() > MAX_SHOWN:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()
	if kind in ["", "good", "rush"]:
		Sfx.play("pop", -14.0)
	# slide in from the left and fade in, wait, then fade out
	t.modulate.a = 0.0
	var inner: Control = t.get_node("Row")
	var tw := t.create_tween()
	tw.set_parallel(true)
	tw.tween_property(t, "modulate:a", 1.0, 0.18).from(0.0)
	tw.tween_property(inner, "position:x", 0.0, 0.25).from(-24.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(k["life"])
	tw.chain().tween_property(t, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(t.queue_free)
