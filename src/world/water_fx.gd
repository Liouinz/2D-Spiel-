class_name WaterFx
extends Node2D
## Animiertes Wasser: Glitzern und Uferschaum. Zeichnet nur den sichtbaren
## Ausschnitt — dadurch praktisch kostenlos.

const T := Config.TILE

var map: MapData
var camera: GameCamera
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if map == null:
		return
	var rect: Rect2
	if is_instance_valid(camera):
		rect = camera.visible_world_rect().grow(T * 2)
	else:
		rect = Rect2(Vector2.ZERO, Config.world_size_px())
	var x0 := maxi(int(rect.position.x / T), 0)
	var y0 := maxi(int(rect.position.y / T), 0)
	var x1 := mini(int(rect.end.x / T) + 1, Config.MAP_W)
	var y1 := mini(int(rect.end.y / T) + 1, Config.MAP_H)

	for y in range(y0, y1):
		for x in range(x0, x1):
			if not map.is_water(x, y):
				continue
			_glint(x, y)
			_foam(x, y)

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
	if (h % 5) == 0:
		draw_rect(Rect2(x * T + ox + 1, y * T + oy + 2, w - 1.0, 1.0), Color(Palette.WATER_LIGHT, a * 0.8), true)

func _foam(x: int, y: int) -> void:
	var wave := sin(_time * 1.6 + (x + y) * 0.5) * 0.5 + 0.5
	var a := 0.30 + wave * 0.35
	var col := Color(Palette.WATER_FOAM, a)
	if not map.is_water(x, y - 1) and map.in_bounds(x, y - 1):
		draw_rect(Rect2(x * T, y * T, T, 1.0 + wave), col, true)
	if not map.is_water(x, y + 1) and map.in_bounds(x, y + 1):
		draw_rect(Rect2(x * T, y * T + T - 1.0 - wave, T, 1.0 + wave), col, true)
	if not map.is_water(x - 1, y) and map.in_bounds(x - 1, y):
		draw_rect(Rect2(x * T, y * T, 1.0 + wave, T), col, true)
	if not map.is_water(x + 1, y) and map.in_bounds(x + 1, y):
		draw_rect(Rect2(x * T + T - 1.0 - wave, y * T, 1.0 + wave, T), col, true)
