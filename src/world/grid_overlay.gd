class_name GridOverlay
extends Node2D
## Zeichnet Block- und Chunk-Raster über die Karte.
##
## Das Raster ist im fertigen Spiel unsichtbar — hier wird es absichtlich
## gezeigt, damit sich planen lässt, wie viele Blöcke ein Objekt belegt.
## Rot = einzelne Blöcke, Gelb = Chunk-Grenzen mit Nummer.
##
## Umschalten mit G. Gezeichnet wird nur der sichtbare Ausschnitt.

const BLOCK_LINE := Color(0.90, 0.20, 0.22, 0.30)
const CHUNK_LINE := Color(1.00, 0.85, 0.25, 0.80)
const CHUNK_TEXT := Color(1.00, 0.90, 0.45, 0.60)
const PLAYER_FILL := Color(1.00, 0.35, 0.35, 0.22)
const PLAYER_LINE := Color(1.00, 0.55, 0.45, 0.95)
const CURSOR_LINE := Color(1.00, 1.00, 1.00, 0.90)
const BORDER := Color(1.00, 0.45, 0.20, 0.85)

var camera: GameCamera
var player: Node2D
var cursor_block := Vector2i(-1, -1)   ## Vorschau der Bau-Leiste, -1 = aus

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

## Der Chunk, in dem ein Block liegt.
static func chunk_of(block: Vector2i) -> Vector2i:
	return Vector2i(floori(float(block.x) / Config.CHUNK), floori(float(block.y) / Config.CHUNK))

## Position des Blocks innerhalb seines Chunks (0 .. CHUNK-1).
static func block_in_chunk(block: Vector2i) -> Vector2i:
	return Vector2i(posmod(block.x, Config.CHUNK), posmod(block.y, Config.CHUNK))

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

	# Blocklinien
	for bx in range(x0, x1 + 1):
		if bx % Config.CHUNK != 0:
			draw_line(Vector2(bx * t, y0 * t), Vector2(bx * t, y1 * t), BLOCK_LINE, 1.0)
	for by in range(y0, y1 + 1):
		if by % Config.CHUNK != 0:
			draw_line(Vector2(x0 * t, by * t), Vector2(x1 * t, by * t), BLOCK_LINE, 1.0)

	# Chunk-Grenzen darüber
	var cs := Config.CHUNK
	for bx in range(x0 - x0 % cs, x1 + cs, cs):
		draw_line(Vector2(bx * t, y0 * t), Vector2(bx * t, y1 * t), CHUNK_LINE, 3.0)
	for by in range(y0 - y0 % cs, y1 + cs, cs):
		draw_line(Vector2(x0 * t, by * t), Vector2(x1 * t, by * t), CHUNK_LINE, 3.0)

	_draw_chunk_numbers(t, x0, y0, x1, y1)

	# Weltrand: hier steht die unsichtbare Wand
	var size := Config.world_size_px()
	draw_rect(Rect2(t, t, size.x - 2 * t, size.y - 2 * t), BORDER, false, 3.0)

	# Block unter der Spielfigur
	if is_instance_valid(player):
		var b := block_at(player.global_position)
		var cell := Rect2(b.x * t, b.y * t, t, t)
		draw_rect(cell, PLAYER_FILL, true)
		draw_rect(cell, PLAYER_LINE, false, 2.0)

	# Block unter dem Mauszeiger (Bau-Vorschau)
	if cursor_block.x >= 0:
		draw_rect(Rect2(cursor_block.x * t, cursor_block.y * t, t, t), CURSOR_LINE, false, 3.0)

## Chunk-Nummer in die obere linke Ecke jedes sichtbaren Chunks.
##
## In der Mitte wäre sie meistens unsichtbar: ein Chunk ist 512 Pixel hoch, der
## Bildausschnitt bei Zoom 1,5 aber nur rund 480 — die Mitte liegt also oft
## ausserhalb. An der Ecke steht die Nummer direkt am gelben Kreuz.
func _draw_chunk_numbers(t: float, x0: int, y0: int, x1: int, y1: int) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var cs := Config.CHUNK
	var cx0 := floori(float(x0) / cs)
	var cy0 := floori(float(y0) / cs)
	var cx1 := floori(float(x1) / cs)
	var cy1 := floori(float(y1) / cs)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if cx < 0 or cy < 0 or cx * cs >= Config.MAP_W or cy * cs >= Config.MAP_H:
				continue
			var pos := Vector2(cx * cs * t + 8.0, cy * cs * t + 26.0)
			draw_string(font, pos, "Chunk %d | %d" % [cx, cy],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CHUNK_TEXT)
