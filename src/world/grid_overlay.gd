class_name GridOverlay
extends Node2D
## Zeichnet das Blockraster der Welt in Rot über die Karte.
##
## Das Raster ist im fertigen Spiel unsichtbar — hier wird es absichtlich
## gezeigt, damit sich planen lässt, wie viele Blöcke ein Objekt belegt.
## Ein Haus über drei Blöcke Breite und zwei Blöcke Höhe ist dann abzählbar.
##
## Umschalten mit G. Gezeichnet wird nur der sichtbare Ausschnitt.

const MINOR := Color(0.90, 0.20, 0.22, 0.30)
const MAJOR := Color(1.00, 0.30, 0.30, 0.65)
const PLAYER_FILL := Color(1.00, 0.35, 0.35, 0.22)
const PLAYER_LINE := Color(1.00, 0.55, 0.45, 0.95)
const BORDER := Color(1.00, 0.45, 0.20, 0.85)

var camera: GameCamera
var player: Node2D

func _init() -> void:
	z_index = 500          ## über allem, auch über Bäumen
	visible = Config.SHOW_BLOCK_GRID

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_grid"):
		return
	visible = not visible
	queue_redraw()
	get_viewport().set_input_as_handled()

## Der Block, auf dem eine Weltposition liegt.
static func block_at(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / Config.TILE)), int(floor(pos.y / Config.TILE)))

func _draw() -> void:
	var t := float(Config.TILE)
	var rect: Rect2
	if is_instance_valid(camera):
		rect = camera.visible_world_rect().grow(t)
	else:
		rect = Rect2(Vector2.ZERO, Config.world_size_px())
	var x0 := maxi(int(rect.position.x / t), 0)
	var y0 := maxi(int(rect.position.y / t), 0)
	var x1 := mini(int(rect.end.x / t) + 1, Config.MAP_W)
	var y1 := mini(int(rect.end.y / t) + 1, Config.MAP_H)

	# Senkrechte Linien
	for bx in range(x0, x1 + 1):
		var major := bx % Config.GRID_MAJOR == 0
		draw_line(Vector2(bx * t, y0 * t), Vector2(bx * t, y1 * t),
			MAJOR if major else MINOR, 2.0 if major else 1.0)
	# Waagerechte Linien
	for by in range(y0, y1 + 1):
		var major := by % Config.GRID_MAJOR == 0
		draw_line(Vector2(x0 * t, by * t), Vector2(x1 * t, by * t),
			MAJOR if major else MINOR, 2.0 if major else 1.0)

	# Weltrand: hier steht die unsichtbare Wand
	var size := Config.world_size_px()
	draw_rect(Rect2(t, t, size.x - 2 * t, size.y - 2 * t), BORDER, false, 3.0)

	# Block unter der Spielfigur hervorheben
	if is_instance_valid(player):
		var b := block_at(player.global_position)
		var cell := Rect2(b.x * t, b.y * t, t, t)
		draw_rect(cell, PLAYER_FILL, true)
		draw_rect(cell, PLAYER_LINE, false, 2.0)
