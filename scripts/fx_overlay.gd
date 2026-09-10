class_name FxOverlay
extends Node2D

## Nicht-additive Overlay-Effekte: ziehende Wolkenschatten, Regenschauer und
## der herabstürzende Meteor mit wachsendem Schatten.
##
## Diese Ebene liegt *unter* der Lightmap, wird also nachts korrekt mit
## abgedunkelt — Wolkenschatten bei Nacht wären sonst hellgraue Flecken.
##
## Der Regen bestand vorher aus 40 pro Bild neu gewürfelten Linien: das
## flimmerte und war reine Verschwendung. Jetzt fallen echte Tropfen mit
## eigener Geschwindigkeit, deren Anzahl das Grafikprofil bestimmt.

const CULL_MARGIN := 120.0

var sim: Simulation
var quality: Quality

var _clouds: Array = []
var _drops := {}
var _view := Rect2()


func _init(sim_ref: Simulation, quality_ref: Quality) -> void:
	sim = sim_ref
	quality = quality_ref
	z_index = 10
	z_as_relative = false


func _ready() -> void:
	if quality != null:
		quality.changed.connect(_sync_clouds)
	_sync_clouds()
	sim.rain_ended.connect(func(id: int): _drops.erase(id))


func particle_count() -> int:
	var count := 0
	for id in _drops:
		count += _drops[id].size()
	return count


func cloud_count() -> int:
	return _clouds.size()


func _sync_clouds() -> void:
	var wanted: int = quality.get_value("cloud_count", 7) if quality != null else 7
	var size := Vector2(Terrain.W, Terrain.H) * Terrain.TILE
	while _clouds.size() > wanted:
		_clouds.pop_back()
	while _clouds.size() < wanted:
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
			"radius": 94.0,
		})


func _process(delta: float) -> void:
	_view = _view_rect()
	var drift := 0.2 + sim.speed
	var size := Vector2(Terrain.W, Terrain.H) * Terrain.TILE
	for c in _clouds:
		c.pos += c.vel * delta * drift
		c.pos.x = wrapf(c.pos.x, -160.0, size.x + 160.0)
		c.pos.y = wrapf(c.pos.y, -120.0, size.y + 120.0)
	_update_rain(delta)
	queue_redraw()


func _view_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2(Vector2.ZERO, Vector2(1280, 720))
	var transform := viewport.get_canvas_transform()
	var scale := transform.get_scale()
	return Rect2(-transform.origin / scale, viewport.get_visible_rect().size / scale).grow(CULL_MARGIN)


## Ein Tropfenfeld pro Regengebiet — sichtbare Gebiete bekommen das volle
## Budget, unsichtbare gar keines.
func _update_rain(delta: float) -> void:
	var budget: int = quality.get_value("rain_particles", 48) if quality != null else 48
	var live := {}
	for area in sim.rain_areas:
		var id: int = area.id
		live[id] = true
		var radius: float = area.radius
		var visible_area := _view.intersects(Rect2(area.pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
		if not visible_area:
			_drops.erase(id)
			continue
		var drops: Array = _drops.get(id, [])
		while drops.size() > budget:
			drops.pop_back()
		while drops.size() < budget:
			drops.append(_new_drop(radius))
		for d in drops:
			d.y += d.speed * delta
			if d.y > d.fall:
				d.y = 0.0
				d.off = _random_in_disc(radius)
				d.speed = randf_range(190.0, 300.0)
		_drops[id] = drops
	for id in _drops.keys():
		if not live.has(id):
			_drops.erase(id)


func _new_drop(radius: float) -> Dictionary:
	return {
		"off": _random_in_disc(radius),
		"y": randf_range(0.0, 60.0),
		"fall": randf_range(45.0, 70.0),
		"speed": randf_range(190.0, 300.0),
	}


func _random_in_disc(radius: float) -> Vector2:
	var angle := randf() * TAU
	return Vector2.from_angle(angle) * sqrt(randf()) * radius


func _draw() -> void:
	for c in _clouds:
		if not _view.intersects(Rect2(c.pos - Vector2(c.radius, c.radius), Vector2(c.radius, c.radius) * 2.0)):
			continue
		for b in c.blobs:
			draw_circle(c.pos + b.off, b.r, Palette.CLOUD)
	for area in sim.rain_areas:
		_draw_rain(area)
	for m in sim.meteors:
		_draw_meteor(m)


func _draw_rain(area: Dictionary) -> void:
	var pos: Vector2 = area.pos
	var radius: float = area.radius
	if not _view.intersects(Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0)):
		return
	draw_circle(pos + Vector2(0, -radius * 0.4), radius * 0.7, Palette.RAIN_CLOUD)
	var lighter := Palette.RAIN_CLOUD
	lighter.a *= 0.8
	draw_circle(pos + Vector2(radius * 0.3, -radius * 0.5), radius * 0.5, lighter)
	var drops: Array = _drops.get(area.id, [])
	for d in drops:
		var start: Vector2 = pos + d.off + Vector2(0, d.y - d.fall)
		draw_line(start, start + Vector2(1.6, 8.0), Palette.RAIN_DROP, 1.0)


func _draw_meteor(m: Dictionary) -> void:
	var progress: float = 1.0 - float(m.ttl) / Simulation.METEOR_FALL_TICKS
	progress = clampf(progress, 0.0, 1.0)
	var target: Vector2 = m.pos
	draw_circle(target, 8.0 + 20.0 * progress, Color(0.0, 0.0, 0.0, 0.22 * progress))
	var fireball: Vector2 = target + Vector2(280.0, -460.0) * (1.0 - progress)
	draw_line(fireball, fireball + Vector2(46.0, -76.0), Color(1.0, 0.6, 0.2, 0.55), 3.0)
	draw_circle(fireball, 5.0, Color(1.0, 0.75, 0.3, 0.9))
	draw_circle(fireball, 2.5, Color(1.0, 0.95, 0.7, 1.0))
