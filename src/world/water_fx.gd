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
	if not map.is_water(x, y - 1) and map.in_bounds(x, y - 1):
		_foam_edge(x, y, true, 0)
	if not map.is_water(x, y + 1) and map.in_bounds(x, y + 1):
		_foam_edge(x, y, true, 1)
	if not map.is_water(x - 1, y) and map.in_bounds(x - 1, y):
		_foam_edge(x, y, false, 0)
	if not map.is_water(x + 1, y) and map.in_bounds(x + 1, y):
		_foam_edge(x, y, false, 1)

## Zeichnet den Schaum pixelweise mit wechselnder Höhe — der Rand bleibt lebendig
## und die harte Kachelkante verschwindet.
func _foam_edge(tx: int, ty: int, horizontal: bool, far_side: int) -> void:
	for i in T:
		var world_i := (tx * T + i) if horizontal else (ty * T + i)
		var wave := sin(_time * 1.7 + world_i * 0.35 + (tx + ty)) * 0.5 + 0.5
		var h := 1.0 + roundf(wave * 2.0)
		var a := 0.34 + wave * 0.34
		var col := Color(Palette.WATER_FOAM, a)
		if horizontal:
			var y: float = float(ty * T) if far_side == 0 else float(ty * T + T) - h
			draw_rect(Rect2(tx * T + i, y, 1.0, h), col, true)
		else:
			var x: float = float(tx * T) if far_side == 0 else float(tx * T + T) - h
			draw_rect(Rect2(x, ty * T + i, h, 1.0), col, true)
