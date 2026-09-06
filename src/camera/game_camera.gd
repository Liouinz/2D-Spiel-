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
	if not is_instance_valid(target):
		return
	# Weich folgen, dann auf ein Raster runden, das sauber auf Bildpunkte
	# abbildet.
	#
	# Bei Zoom 1,5 wird ein Weltpixel zu 1,5 Bildpunkten. Nur wenn die Kamera
	# auf GERADEN Weltpixeln steht, landet jede Kachelkante auf einem ganzen
	# Bildpunkt (2 Welt → 3 Bild). Ohne das wandert die Kante beim Laufen
	# zwischen zwei Bildpunkten hin und her, und die Kacheln flimmern an den
	# Rändern — das sah aus wie unsaubere Kanten.
	var want := target.global_position + Vector2(0, -8)
	var step := pixel_step()
	global_position = (want / step).round() * step

## Rasterweite, auf die die Kamera gerundet wird: der kleinste Weltabstand, der
## bei diesem Zoom auf ganze Bildpunkte fällt.
func pixel_step() -> float:
	var z := zoom.x
	if is_equal_approx(z, roundf(z)):
		return 1.0                      # ganzzahliger Zoom: jeder Weltpixel passt
	if is_equal_approx(z * 2.0, roundf(z * 2.0)):
		return 2.0                      # halber Zoom (1,5 / 2,5 …): gerade Pixel
	return 4.0

## Sichtbarer Weltausschnitt — für sparsames Zeichnen der Wasser-Effekte.
func visible_world_rect() -> Rect2:
	var vp := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - vp * 0.5, vp)
