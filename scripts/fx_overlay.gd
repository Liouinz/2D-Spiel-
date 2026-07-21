class_name FxOverlay
extends Node2D

## Normale (nicht-additive) Overlay-Effekte: ziehende Wolkenschatten,
## Regenschauer und der herabstürzende Meteor mit wachsendem Schatten.

const CLOUD_COUNT := 9

var sim: Simulation
var _clouds: Array = []


func _init(sim_ref: Simulation) -> void:
	sim = sim_ref
	var size := Vector2(Terrain.W, Terrain.H) * Terrain.TILE
	for i in CLOUD_COUNT:
		var blobs: Array = []
		for j in randi_range(4, 6):
			blobs.append({
				"off": Vector2(randf_range(-52.0, 52.0), randf_range(-20.0, 20.0)),
				"r": randf_range(18.0, 42.0),
			})
		_clouds.append({
			"pos": Vector2(randf() * size.x, randf() * size.y),
			"vel": Vector2(randf_range(3.0, 8.0), randf_range(0.3, 1.4)),
			"blobs": blobs,
		})


func _process(delta: float) -> void:
	var drift := 0.2 + sim.speed
	var size := Vector2(Terrain.W, Terrain.H) * Terrain.TILE
	for c in _clouds:
		c.pos += c.vel * delta * drift
		c.pos.x = wrapf(c.pos.x, -160.0, size.x + 160.0)
		c.pos.y = wrapf(c.pos.y, -120.0, size.y + 120.0)
	queue_redraw()


func _draw() -> void:
	for c in _clouds:
		for b in c.blobs:
			draw_circle(c.pos + b.off, b.r, Color(1.0, 1.0, 1.0, 0.07))
	for area in sim.rain_areas:
		_draw_rain(area)
	for m in sim.meteors:
		_draw_meteor(m)


func _draw_rain(area: Dictionary) -> void:
	var pos: Vector2 = area.pos
	var radius: float = area.radius
	draw_circle(pos + Vector2(0, -radius * 0.4), radius * 0.7, Color(0.35, 0.38, 0.45, 0.22))
	draw_circle(pos + Vector2(radius * 0.3, -radius * 0.5), radius * 0.5, Color(0.35, 0.38, 0.45, 0.18))
	for i in 40:
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * radius
		if offset.length() > radius:
			continue
		var start := pos + offset - Vector2(0, randf_range(10.0, 60.0))
		draw_line(start, start + Vector2(2.0, 9.0), Color(0.65, 0.78, 0.95, 0.4), 1.0)
	for i in 8:
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * radius
		if offset.length() <= radius:
			draw_circle(pos + offset, 1.0, Color(0.75, 0.85, 1.0, 0.35))


func _draw_meteor(m: Dictionary) -> void:
	var progress: float = 1.0 - float(m.ttl) / Simulation.METEOR_FALL_TICKS
	progress = clampf(progress, 0.0, 1.0)
	var target: Vector2 = m.pos
	draw_circle(target, 8.0 + 20.0 * progress, Color(0.0, 0.0, 0.0, 0.22 * progress))
	var fireball: Vector2 = target + Vector2(280.0, -460.0) * (1.0 - progress)
	draw_line(fireball, fireball + Vector2(46.0, -76.0), Color(1.0, 0.6, 0.2, 0.55), 3.0)
	draw_circle(fireball, 5.0, Color(1.0, 0.75, 0.3, 0.9))
	draw_circle(fireball, 2.5, Color(1.0, 0.95, 0.7, 1.0))
