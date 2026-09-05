class_name WaterFx
extends Node2D
## Animiertes Wasser: Glitzern und Uferschaum.
##
## Zwei Sparmaßnahmen halten das billig:
## 1. Die Uferkanten werden einmal beim Weltaufbau ermittelt, nicht pro Bild.
## 2. Der Schaum wird in Segmenten statt pro Pixel gezeichnet, und das ganze
##    Bild wird nur rund 24-mal pro Sekunde neu gezeichnet.

const T := Config.TILE
const FOAM_SEG := 4          ## Segmentbreite des Schaums in Pixeln
const REDRAW_HZ := 24.0

## Bits der Uferrichtungen je Kachel
const UP := 1
const DOWN := 2
const LEFT := 4
const RIGHT := 8

var camera: GameCamera
var prims: int = 0           ## gezeichnete Rechtecke im letzten Bild (nur Messung)

var _map: MapData
var _shore := PackedByteArray()
var _time: float = 0.0
var _accum: float = 0.0

## Muss vor dem ersten Zeichnen aufgerufen werden.
func setup(map: MapData) -> void:
	_map = map
	_shore.resize(Config.MAP_W * Config.MAP_H)
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			if not map.is_water(x, y):
				continue
			var mask := 0
			if map.in_bounds(x, y - 1) and not map.is_water(x, y - 1):
				mask |= UP
			if map.in_bounds(x, y + 1) and not map.is_water(x, y + 1):
				mask |= DOWN
			if map.in_bounds(x - 1, y) and not map.is_water(x - 1, y):
				mask |= LEFT
			if map.in_bounds(x + 1, y) and not map.is_water(x + 1, y):
				mask |= RIGHT
			_shore[y * Config.MAP_W + x] = mask

func _process(delta: float) -> void:
	_time += delta
	_accum += delta
	if _accum >= 1.0 / REDRAW_HZ:
		_accum = 0.0
		queue_redraw()

func _draw() -> void:
	if _map == null:
		return
	prims = 0
	var rect: Rect2
	if is_instance_valid(camera):
		rect = camera.visible_world_rect().grow(T)
	else:
		rect = Rect2(Vector2.ZERO, Config.world_size_px())
	var x0 := maxi(int(rect.position.x / T), 0)
	var y0 := maxi(int(rect.position.y / T), 0)
	var x1 := mini(int(rect.end.x / T) + 1, Config.MAP_W)
	var y1 := mini(int(rect.end.y / T) + 1, Config.MAP_H)

	for y in range(y0, y1):
		var row := y * Config.MAP_W
		for x in range(x0, x1):
			if not _map.is_water(x, y):
				continue
			_glint(x, y)
			var mask := _shore[row + x]
			if mask != 0:
				_foam(x, y, mask)

func _glint(x: int, y: int) -> void:
	var h := (x * 73856093) ^ (y * 19349663)
	var phase := float(h % 1000) / 1000.0
	var pulse := sin((_time * 0.9 + phase) * TAU)
	if pulse < 0.55:
		return
	var a: float = (pulse - 0.55) / 0.45 * 0.55
	var ox := float(h % 7)
	var oy := float((h / 7) % 11)
	var w := 3.0 + float((h / 3) % 3)
	draw_rect(Rect2(x * T + ox, y * T + oy, w, 1.0), Color(Palette.WATER_FOAM, a), true)
	prims += 1
	if (h % 5) == 0:
		draw_rect(Rect2(x * T + ox + 1, y * T + oy + 2, w - 1.0, 1.0), Color(Palette.WATER_LIGHT, a * 0.8), true)
		prims += 1

## Zeichnet den Schaum in Segmenten unterschiedlicher Höhe — die Kachelkante
## bleibt dadurch unsichtbar, kostet aber nur ein Viertel der Rechenzeit.
func _foam(tx: int, ty: int, mask: int) -> void:
	var segments := T / FOAM_SEG
	for i in segments:
		var world_i := tx * T + ty * T + i * FOAM_SEG
		var wave := sin(_time * 1.7 + world_i * 0.31) * 0.5 + 0.5
		var h := 1.0 + roundf(wave * 2.0)
		var col := Color(Palette.WATER_FOAM, 0.34 + wave * 0.34)
		var ox := float(tx * T + i * FOAM_SEG)
		var oy := float(ty * T + i * FOAM_SEG)
		if mask & UP:
			draw_rect(Rect2(ox, ty * T, FOAM_SEG, h), col, true)
			prims += 1
		if mask & DOWN:
			draw_rect(Rect2(ox, ty * T + T - h, FOAM_SEG, h), col, true)
			prims += 1
		if mask & LEFT:
			draw_rect(Rect2(tx * T, oy, h, FOAM_SEG), col, true)
			prims += 1
		if mask & RIGHT:
			draw_rect(Rect2(tx * T + T - h, oy, h, FOAM_SEG), col, true)
			prims += 1
