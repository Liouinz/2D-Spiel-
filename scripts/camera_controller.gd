class_name CameraController
extends Camera2D

## Kamera: Zoomen (Mausrad, Richtung Mauszeiger), Schwenken (mittlere Maustaste
## oder WASD/Pfeiltasten), Screenshake für "Juice" bei Katastrophen.

const ZOOM_MIN := 0.5
const ZOOM_MAX := 8.0
const ZOOM_STEP := 1.2
const PAN_SPEED := 600.0

var _dragging := false
var _shake := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_step(ZOOM_STEP)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_step(1.0 / ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	position += dir.normalized() * PAN_SPEED * delta / zoom.x
	if _shake > 0.05:
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = lerpf(_shake, 0.0, 10.0 * delta)
	else:
		offset = Vector2.ZERO
		_shake = 0.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _zoom_step(factor: float) -> void:
	var viewport_size := get_viewport_rect().size
	var mouse := get_viewport().get_mouse_position()
	var new_zoom := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	var world := position + (mouse - viewport_size * 0.5) / zoom.x
	position = world - (mouse - viewport_size * 0.5) / new_zoom
	zoom = Vector2(new_zoom, new_zoom)
