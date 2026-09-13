class_name CameraController
extends Camera2D

## Kamera mit *festen* Zoomstufen (100 % / 85 % / 70 %). Kein stufenloses
## Herauszoomen mehr — damit bleiben Pixelgrösse, Trefferflächen und UI-Bezug
## auf jeder Stufe berechenbar.
##
## Bewegt wird ausschliesslich über Actions (`move_up` …), nie über feste
## Tasten: die Belegung kommt aus dem Steuerungs-Menü.

## 100 % = 1 Pixel Welt auf 1 Pixel Bildschirm.
const ZOOM_STEPS: Array[float] = [1.0, 0.85, 0.7]
const PAN_SPEED := 620.0
const SPRINT_FACTOR := 2.2
const SHAKE_DAMPING := 9.0

signal zoom_changed(percent: int)

var zoom_index := 0
var _dragging := false
var _shake := 0.0


func _ready() -> void:
	_apply_zoom(false)


func set_map_limits(size_px: Vector2) -> void:
	limit_left = -96
	limit_top = -96
	limit_right = int(size_px.x) + 96
	limit_bottom = int(size_px.y) + 96


func zoom_percent() -> int:
	return int(round(ZOOM_STEPS[zoom_index] * 100.0))


func set_zoom_index(index: int, toward_mouse: bool = true) -> void:
	var clamped := clampi(index, 0, ZOOM_STEPS.size() - 1)
	if clamped == zoom_index:
		return
	zoom_index = clamped
	_apply_zoom(toward_mouse)


func _apply_zoom(toward_mouse: bool) -> void:
	var target := ZOOM_STEPS[zoom_index]
	if toward_mouse and is_inside_tree():
		# Der Punkt unter dem Mauszeiger bleibt beim Zoomen stehen.
		var viewport_size := get_viewport_rect().size
		var mouse := get_viewport().get_mouse_position()
		var offset_from_center := mouse - viewport_size * 0.5
		var world := position + offset_from_center / zoom.x
		position = world - offset_from_center / target
	zoom = Vector2(target, target)
	zoom_changed.emit(zoom_percent())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		set_zoom_index(zoom_index - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("zoom_out"):
		set_zoom_index(zoom_index + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_drag"):
		_dragging = true
	elif event.is_action_released("camera_drag"):
		_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom.x


func _process(delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if dir != Vector2.ZERO:
		var speed := PAN_SPEED
		if Input.is_action_pressed("sprint"):
			speed *= SPRINT_FACTOR
		position += dir.normalized() * speed * delta / zoom.x
	if _shake > 0.05:
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = lerpf(_shake, 0.0, SHAKE_DAMPING * delta)
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO
		_shake = 0.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)
