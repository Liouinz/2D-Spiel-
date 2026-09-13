class_name FxGlow
extends Node2D

## Additiv gezeichnete Leucht-Effekte: Blitze, Einschlags-Flammen, Lagerfeuer,
## Fackelflammen, Wasser-Glitzern, Lava-Glut und Segen-Funken.
##
## Diese Ebene liegt bewusst *über* der Lightmap — Feuer und Blitze sollen die
## Nacht durchschneiden, nicht von ihr abgedunkelt werden.
##
## Funken entstehen nur noch im sichtbaren Ausschnitt (vorher wurden sie über
## die ganze Karte gestreut, also grösstenteils unsichtbar berechnet), und ihr
## Budget kommt aus dem Grafikprofil.

const FLASH_TTL := 0.35
const IMPACT_TTL := 0.6
const SPARKLE_TTL := 0.5

var sim: Simulation
var terrain: Terrain
var quality: Quality

var _flashes: Array = []
var _impacts: Array = []
var _sparkles: Array = []
var _blessings: Array = []
var _view := Rect2()


func _init(sim_ref: Simulation, quality_ref: Quality) -> void:
	sim = sim_ref
	terrain = sim_ref.terrain
	quality = quality_ref
	z_index = 95
	z_as_relative = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func particle_count() -> int:
	return _sparkles.size() + _blessings.size() + _flashes.size() + _impacts.size()


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
	_view = View.world_rect(self)
	_advance(_flashes, delta)
	_advance(_impacts, delta)
	_advance(_sparkles, delta)
	for i in range(_blessings.size() - 1, -1, -1):
		var b: Dictionary = _blessings[i]
		b.ttl -= delta
		b.pos += b.vel * delta
		if b.ttl <= 0.0:
			_blessings.remove_at(i)
	_spawn_ambient_sparkles()
	queue_redraw()


func _advance(list: Array, delta: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		list[i].ttl -= delta
		if list[i].ttl <= 0.0:
			list.remove_at(i)


## Funken werden nur im Blickfeld gewürfelt — dadurch ist die Trefferquote
## nahe 100 %, statt über eine 192×112-Karte zu streuen.
func _spawn_ambient_sparkles() -> void:
	var budget: int = quality.get_value("sparkle_budget")
	if budget <= 0 or _sparkles.size() >= budget:
		return
	for i in 6:
		var point := _view.position + Vector2(randf() * _view.size.x, randf() * _view.size.y)
		var cell := terrain.local_to_map(point)
		var t := terrain.get_type(cell)
		if Terrain.is_water(t) and randf() < 0.35:
			_sparkles.append({"pos": point, "ttl": SPARKLE_TTL, "color": Palette.SPARK_WATER, "size": 1.0})
		elif t == Terrain.T_LAVA:
			_sparkles.append({"pos": point, "ttl": 0.35, "color": Palette.SPARK_LAVA, "size": 1.6})


func _draw() -> void:
	var time := Time.get_ticks_msec() * 0.001
	var night := sim.night_factor()
	for v in sim.villages:
		if not v.fallen and _view.has_point(v.center_pos):
			_draw_fire(v.center_pos + Vector2(0, -3), time, float(v.id), 1.0)
	for torch in sim.torches:
		if _view.has_point(torch.pos):
			_draw_fire(torch.pos + Vector2(0, -8), time, torch.phase, 0.55)
	for sp in _sparkles:
		var c: Color = sp.color
		c.a *= clampf(sp.ttl / SPARKLE_TTL, 0.0, 1.0)
		draw_circle(sp.pos, sp.size, c)
	for b in _blessings:
		var fade: float = clampf(b.ttl, 0.0, 1.0)
		var col := Palette.BLESSING
		col.a = fade
		draw_circle(b.pos, 1.4, col)
	for f in _flashes:
		var a: float = clampf(f.ttl / FLASH_TTL, 0.0, 1.0)
		var col := Palette.FLASH
		col.a = a
		draw_polyline(f.points, col, 2.0)
		col.a = a * 0.5
		draw_circle(f.points[f.points.size() - 1], 9.0 * a, col)
	for imp in _impacts:
		var a: float = clampf(imp.ttl / IMPACT_TTL, 0.0, 1.0)
		var radius: float = 20.0 + (1.0 - a) * 70.0
		var outer := Palette.IMPACT_OUTER
		outer.a = a * 0.5
		draw_circle(imp.pos, radius, outer)
		var inner := Palette.IMPACT_INNER
		inner.a = a * 0.7
		draw_circle(imp.pos, radius * 0.5, inner)
	# Nachts glimmt zusätzlich jede Lavazelle im Blickfeld.
	if night > 0.1:
		for cell in sim.lava_cells():
			var p := terrain.cell_center(cell)
			if _view.has_point(p):
				var glow := Palette.LIGHT_LAVA
				glow.a = 0.18 * night
				draw_circle(p, 7.0, glow)


func _draw_fire(c: Vector2, time: float, phase: float, scale: float) -> void:
	var flicker := sin(time * 11.0 + phase * 2.7) * 0.8 * scale
	var halo := Palette.LIGHT_FIRE
	halo.a = 0.10
	draw_circle(c, 10.0 * scale, halo)
	var body := Color(1.0, 0.55, 0.15, 0.75)
	draw_circle(c, (3.4 + flicker) * scale, body)
	var core := Color(1.0, 0.85, 0.4, 0.9)
	draw_circle(c + Vector2(0, -1), (1.8 + flicker * 0.5) * scale, core)
