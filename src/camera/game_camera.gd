class_name GameCamera
extends Camera2D
## Folgt dem Spieler weich und verlässt nie die Weltgrenzen (§6).

var target: Node2D

func setup(world_size: Vector2i) -> void:
	zoom = Vector2(Config.CAMERA_ZOOM, Config.CAMERA_ZOOM)
	limit_left = 0
	limit_top = 0
	limit_right = world_size.x
	limit_bottom = world_size.y
	limit_smoothed = true
	position_smoothing_enabled = true
	position_smoothing_speed = Config.CAMERA_SMOOTH
	ignore_rotation = true
	make_current()

func snap_to_target() -> void:
	if target:
		global_position = target.global_position
		reset_smoothing()

func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -8)

## Sichtbarer Weltausschnitt — für sparsames Zeichnen der Wasser-Effekte.
func visible_world_rect() -> Rect2:
	var vp := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - vp * 0.5, vp)
