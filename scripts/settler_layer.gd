class_name SettlerLayer
extends Node2D

## Zeichnet Siedler, Hütten und Blitz-Effekte in einem einzigen _draw()-Pass —
## kein Node pro Einheit (Daten-orientiert, Masterplan §5).

const BODY_COLOR := Color8(240, 220, 190)
const TUNIC_COLOR := Color8(150, 96, 60)
const HUT_WALL := Color8(122, 84, 54)
const HUT_ROOF := Color8(90, 58, 38)
const FLASH_TTL := 0.35

var sim: Simulation
var _flashes: Array = []


func _init(sim_ref: Simulation) -> void:
	sim = sim_ref


func _process(delta: float) -> void:
	for f in _flashes:
		f.ttl -= delta
	_flashes = _flashes.filter(func(f): return f.ttl > 0.0)
	queue_redraw()


func add_flash(world_pos: Vector2) -> void:
	var points := PackedVector2Array()
	var cursor := world_pos + Vector2(randf_range(-30.0, 30.0), -260.0)
	points.append(cursor)
	while cursor.y < world_pos.y - 10.0:
		cursor += Vector2(randf_range(-14.0, 14.0), randf_range(20.0, 40.0))
		points.append(cursor)
	points.append(world_pos)
	_flashes.append({"points": points, "ttl": FLASH_TTL})


func _draw() -> void:
	for hut in sim.huts:
		var p := Vector2(hut) * Terrain.TILE
		draw_rect(Rect2(p + Vector2(2, 6), Vector2(12, 9)), HUT_WALL)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(1, 7),
			p + Vector2(8, 1),
			p + Vector2(15, 7),
		]), HUT_ROOF)
	for s in sim.settlers:
		draw_rect(Rect2(s.pos + Vector2(-2, -3), Vector2(4, 5)), TUNIC_COLOR)
		draw_rect(Rect2(s.pos + Vector2(-1, -6), Vector2(3, 3)), BODY_COLOR)
	for f in _flashes:
		var a: float = clampf(f.ttl / FLASH_TTL, 0.0, 1.0)
		draw_polyline(f.points, Color(1.0, 1.0, 0.8, a), 2.0)
		draw_circle(f.points[f.points.size() - 1], 8.0 * a, Color(1.0, 1.0, 0.7, a * 0.5))
