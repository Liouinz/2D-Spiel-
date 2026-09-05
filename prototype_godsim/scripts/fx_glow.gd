class_name FxGlow
extends Node2D

## Additiv gezeichnete Leucht-Effekte: Blitze, Einschlags-Flammen, Lagerfeuer,
## Wasser-Glitzern, Lava-Glut und Segen-Funken.

const FLASH_TTL := 0.35
const IMPACT_TTL := 0.6
const MAX_SPARKLES := 400

var sim: Simulation
var terrain: Terrain

var _flashes: Array = []
var _impacts: Array = []
var _sparkles: Array = []
var _blessings: Array = []


func _init(sim_ref: Simulation) -> void:
	sim = sim_ref
	terrain = sim_ref.terrain
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func add_flash(world_pos: Vector2) -> void:
	var points := PackedVector2Array()
	var cursor := world_pos + Vector2(randf_range(-30.0, 30.0), -280.0)
	points.append(cursor)
	while cursor.y < world_pos.y - 10.0:
		cursor += Vector2(randf_range(-14.0, 14.0), randf_range(20.0, 40.0))
		points.append(cursor)
	points.append(world_pos)
	_flashes.append({"points": points, "ttl": FLASH_TTL})


func add_impact(world_pos: Vector2) -> void:
	_impacts.append({"pos": world_pos, "ttl": IMPACT_TTL})


func add_blessing(world_pos: Vector2) -> void:
	for i in 24:
		_blessings.append({
			"pos": world_pos + Vector2(randf_range(-16.0, 16.0), randf_range(-6.0, 6.0)),
			"vel": Vector2(randf_range(-6.0, 6.0), randf_range(-34.0, -14.0)),
			"ttl": randf_range(0.6, 1.3),
		})


func _process(delta: float) -> void:
	for f in _flashes:
		f.ttl -= delta
	_flashes = _flashes.filter(func(f): return f.ttl > 0.0)
	for imp in _impacts:
		imp.ttl -= delta
	_impacts = _impacts.filter(func(i): return i.ttl > 0.0)
	for b in _blessings:
		b.ttl -= delta
		b.pos += b.vel * delta
	_blessings = _blessings.filter(func(b): return b.ttl > 0.0)
	_spawn_ambient_sparkles()
	for sp in _sparkles:
		sp.ttl -= delta
	_sparkles = _sparkles.filter(func(s): return s.ttl > 0.0)
	queue_redraw()


func _spawn_ambient_sparkles() -> void:
	if _sparkles.size() >= MAX_SPARKLES:
		return
	for i in 6:
		var cell := terrain.random_cell()
		var t := terrain.get_type(cell)
		var pos := terrain.map_to_local(cell) + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		if Terrain.is_water(t) and randf() < 0.35:
			_sparkles.append({"pos": pos, "ttl": 0.5, "color": Color(0.75, 0.88, 1.0, 0.7), "size": 1.0})
		elif t == Terrain.T_LAVA:
			_sparkles.append({"pos": pos, "ttl": 0.35, "color": Color(1.0, 0.62, 0.18, 0.8), "size": 1.6})


func _draw() -> void:
	var time := Time.get_ticks_msec() * 0.001
	for v in sim.villages:
		if not v.fallen:
			_draw_fire(v.center_pos, time, float(v.id))
	for sp in _sparkles:
		var c: Color = sp.color
		c.a *= clampf(sp.ttl / 0.5, 0.0, 1.0)
		draw_circle(sp.pos, sp.size, c)
	for b in _blessings:
		var fade: float = clampf(b.ttl, 0.0, 1.0)
		draw_circle(b.pos, 1.4, Color(1.0, 0.9, 0.45, fade))
	for f in _flashes:
		var a: float = clampf(f.ttl / FLASH_TTL, 0.0, 1.0)
		draw_polyline(f.points, Color(1.0, 1.0, 0.85, a), 2.0)
		draw_circle(f.points[f.points.size() - 1], 9.0 * a, Color(1.0, 1.0, 0.7, a * 0.5))
	for imp in _impacts:
		var a: float = clampf(imp.ttl / IMPACT_TTL, 0.0, 1.0)
		var radius: float = 20.0 + (1.0 - a) * 70.0
		draw_circle(imp.pos, radius, Color(1.0, 0.55, 0.2, a * 0.5))
		draw_circle(imp.pos, radius * 0.5, Color(1.0, 0.85, 0.5, a * 0.7))


func _draw_fire(c: Vector2, time: float, phase: float) -> void:
	var flicker := sin(time * 11.0 + phase * 2.7) * 0.8
	draw_circle(c + Vector2(0, -3), 10.0, Color(1.0, 0.55, 0.2, 0.10))
	draw_circle(c + Vector2(0, -3), 3.4 + flicker, Color(1.0, 0.55, 0.15, 0.75))
	draw_circle(c + Vector2(0, -4), 1.8 + flicker * 0.5, Color(1.0, 0.85, 0.4, 0.9))
