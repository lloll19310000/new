extends Camera2D
## Right-drag or middle-drag to pan, scroll to zoom, WASD or arrows to move.

const MIN_ZOOM := 0.45
const MAX_ZOOM := 2.6
const KEY_SPEED := 700.0

var dragging := false


func _ready() -> void:
	var lot_size := Vector2(Data.LOT_W, Data.LOT_H) * Data.TILE
	position = lot_size / 2.0
	var view := get_viewport_rect().size
	# the top bar, build menu and side panel cover parts of the screen,
	# so fit the lot into the space that's left and centre it there
	var free := Rect2(Vector2(0, 64), view - Vector2(430, 64 + 70))
	var z := minf(free.size.x / (lot_size.x + 40), free.size.y / (lot_size.y + 20))
	zoom = Vector2.ONE * clampf(z, MIN_ZOOM, MAX_ZOOM)
	position += (view / 2.0 - free.get_center()) / zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(1.12)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(1.0 / 1.12)
	elif event is InputEventMouseMotion and dragging:
		position -= (event as InputEventMouseMotion).relative / zoom
		clamp_position()


func zoom_at(factor: float) -> void:
	var before := get_global_mouse_position()
	var z := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(z, z)
	force_update_scroll()
	var after := get_global_mouse_position()
	position += before - after
	clamp_position()


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1
	if move != Vector2.ZERO:
		position += move.normalized() * KEY_SPEED * delta / zoom.x
		clamp_position()


func clamp_position() -> void:
	var lot_size := Vector2(Data.LOT_W, Data.LOT_H) * Data.TILE
	position = position.clamp(Vector2(-200, -200), lot_size + Vector2(200, 200))
