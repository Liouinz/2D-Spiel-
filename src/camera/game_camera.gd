class_name GameCamera
extends Camera2D
## Folgt dem Spieler weich und verlässt nie die Weltgrenzen (§6).

var target: Node2D

## Wie weit die Kamera ueber der Figur steht.
##
## Acht Bildpunkte nach oben: von schraeg oben gesehen steht die Figur damit
## etwas unterhalb der Bildmitte, und man sieht mehr von dem, worauf man zulaeuft.
##
## Diese Zahl steht genau EINMAL. Vorher rechnete `_process` sie ein und
## `snap_to_target` nicht — nach jedem Setzen der Kamera (Weltaufbau, jeder
## Sprung im Selbsttest) korrigierte sie sich im naechsten Bild um acht Punkte
## nach. Ein sichtbarer Ruck aus einer Zahl an einer Stelle zu viel.
const LOOK_AHEAD := Vector2(0.0, -8.0)

func setup(world_size: Vector2i) -> void:
	apply_zoom()
	Settings.changed.connect(apply_zoom)
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
		global_position = target.global_position + LOOK_AHEAD
		reset_smoothing()

func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Nur folgen. Gerundet wird hier nichts mehr: das Projekt stellt
	# `snap_2d_transforms_to_pixel` ein, und alle Zoomstufen sind ganzzahlig —
	# die frühere Rasterrechnung war seit der Umstellung auf 2/4/6 ein Nulleffekt.
	global_position = target.global_position + LOOK_AHEAD

## Setzt die gewählte Zoomstufe. Ganzzahlig — siehe Config.ZOOM_STEPS.
func apply_zoom() -> void:
	var z := Config.zoom_of(Settings.zoom)
	if not is_equal_approx(zoom.x, z):
		zoom = Vector2(z, z)

## Eine Stufe näher heran oder weiter weg. Die Grenzen sind hart: es gibt genau
## die drei Stufen und nichts dazwischen.
func step_zoom(delta: int) -> void:
	var want := clampi(Settings.zoom + delta, 0, Config.ZOOM_STEPS.size() - 1)
	if want == Settings.zoom:
		return
	Settings.zoom = want
	Settings.changed_and_save()

## Sichtbarer Weltausschnitt — für sparsames Zeichnen der Wasser-Effekte.
func visible_world_rect() -> Rect2:
	var vp := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - vp * 0.5, vp)
