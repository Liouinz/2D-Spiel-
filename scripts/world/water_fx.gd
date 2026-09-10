class_name WaterFx
extends Node2D

## Macht aus der Wasserfläche eine lebendige Oberfläche — ohne echte
## Flüssigkeitssimulation.
##
## Drei Bausteine:
##   1. Ein Shader auf den beiden Wasser-Ebenen lässt die Fläche wandern und
##      glitzern. Kosten: ein Fragment-Shader auf ohnehin gezeichneten Tiles.
##   2. Wellenringe entstehen dort, wo etwas das Wasser berührt (watende
##      Siedler, Regen, Einschläge) und laufen weich aus.
##   3. Optionale Fische, die nur im sichtbaren Bereich leben und beim
##      Abtauchen selbst kleine Wellen erzeugen.
##
## Alles ist über das Grafikprofil abschaltbar und in der Anzahl gedeckelt.

const RIPPLE_TTL := 1.5
const RIPPLE_MAX_RADIUS := 22.0

const SHADER_CODE := """
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float speed : hint_range(0.0, 4.0) = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = TIME * speed;
	float w = sin(world_pos.x * 0.055 + t * 1.15) * 0.50
		+ sin(world_pos.y * 0.071 - t * 0.83) * 0.35
		+ sin((world_pos.x + world_pos.y) * 0.031 + t * 0.55) * 0.30;
	float shimmer = smoothstep(0.40, 0.95, w);
	float trough = smoothstep(0.40, 0.95, -w);
	c.rgb += vec3(0.10, 0.13, 0.14) * shimmer * strength * c.a;
	c.rgb -= vec3(0.03, 0.04, 0.05) * trough * strength * c.a;
	COLOR = c;
}
"""

var terrain: Terrain
var sim: Simulation
var quality: Quality

var _ripples: Array = []
var _fish: Array = []
var _material: ShaderMaterial
var _fish_timer := 0.0
var _had_content := false


func _init(terrain_ref: Terrain, sim_ref: Simulation, quality_ref: Quality) -> void:
	terrain = terrain_ref
	sim = sim_ref
	quality = quality_ref
	z_index = 4
	z_as_relative = false


func _ready() -> void:
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	terrain.water_layer.material = _material
	terrain.deep_layer.material = _material
	sim.water_disturbed.connect(add_ripple)
	quality.changed.connect(_apply_quality)
	_apply_quality()


func _apply_quality() -> void:
	var animate: bool = quality.get_value("water_animation")
	_material.set_shader_parameter("strength", 1.0 if animate else 0.0)
	_material.set_shader_parameter("speed", 1.0)
	var wanted: int = quality.get_value("fish_count")
	while _fish.size() > wanted:
		_fish.pop_back()


func ripple_count() -> int:
	return _ripples.size()


func fish_count() -> int:
	return _fish.size()


## Wellenring an einer Weltposition. Wird von der Simulation ausgelöst.
func add_ripple(world_pos: Vector2, strength: float = 1.0) -> void:
	if not quality.get_value("water_ripples"):
		return
	var budget: int = quality.get_value("water_ripple_budget")
	if _ripples.size() >= budget:
		return
	if not Terrain.is_water(terrain.get_type(terrain.local_to_map(world_pos))):
		return
	_ripples.append({
		"pos": world_pos,
		"age": 0.0,
		"ttl": RIPPLE_TTL * clampf(strength + 0.4, 0.4, 1.4),
		"strength": clampf(strength, 0.1, 1.4),
	})


func _process(delta: float) -> void:
	var alive: Array = []
	for r in _ripples:
		r.age += delta
		if r.age < r.ttl:
			alive.append(r)
	_ripples = alive
	_update_fish(delta)
	var has_content := not _ripples.is_empty() or not _fish.is_empty()
	# Ein letztes Neuzeichnen, wenn gerade das letzte Element verschwunden ist —
	# danach bleibt die Ebene still, statt jedes Bild leer neu zu zeichnen.
	if has_content or _had_content:
		queue_redraw()
	_had_content = has_content


# --- Fische -----------------------------------------------------------------

## Fische leben nur im sichtbaren Ausschnitt. Verlässt einer das Bild, wird er
## nicht simuliert, sondern beim nächsten Nachrücken neu gesetzt — die Kosten
## hängen damit am Bildschirm, nicht an der Kartengrösse.
func _update_fish(delta: float) -> void:
	var wanted: int = quality.get_value("fish_count")
	var view := View.world_rect(self)
	_fish_timer -= delta
	if _fish.size() < wanted and _fish_timer <= 0.0:
		_fish_timer = 0.35
		var spot := _random_water_spot(view)
		if spot != Vector2.INF:
			_fish.append({
				"pos": spot,
				"dir": Vector2.from_angle(randf() * TAU),
				"speed": randf_range(6.0, 16.0),
				"turn": randf_range(-0.8, 0.8),
				"life": randf_range(6.0, 14.0),
				"size": randf_range(1.4, 2.4),
			})
	for i in range(_fish.size() - 1, -1, -1):
		var f: Dictionary = _fish[i]
		f.life -= delta
		f.dir = f.dir.rotated(f.turn * delta)
		var next: Vector2 = f.pos + f.dir * f.speed * delta
		if not Terrain.is_water(terrain.get_type(terrain.local_to_map(next))):
			# Am Ufer abdrehen statt an Land schwimmen.
			f.dir = f.dir.rotated(PI * 0.6)
			f.turn = -f.turn
		else:
			f.pos = next
		if f.life <= 0.0 or not view.grow(48.0).has_point(f.pos):
			if randf() < 0.4:
				add_ripple(f.pos, 0.25)
			_fish.remove_at(i)


func _random_water_spot(view: Rect2) -> Vector2:
	for attempt in 8:
		var point := view.position + Vector2(randf() * view.size.x, randf() * view.size.y)
		var cell := terrain.local_to_map(point)
		if terrain.get_type(cell) == Terrain.T_WATER_DEEP:
			return terrain.cell_center(cell)
	return Vector2.INF


# --- Zeichnen ---------------------------------------------------------------

func _draw() -> void:
	for r in _ripples:
		var t: float = r.age / r.ttl
		var fade: float = (1.0 - t) * (1.0 - t)
		var radius: float = 2.0 + RIPPLE_MAX_RADIUS * r.strength * sqrt(t)
		var color := Palette.WATER_FOAM
		color.a = 0.42 * fade * r.strength
		draw_arc(r.pos, radius, 0.0, TAU, 14, color, 1.0)
		if r.strength > 0.4:
			color.a *= 0.55
			draw_arc(r.pos, radius * 0.55, 0.0, TAU, 12, color, 1.0)
	for f in _fish:
		var body := Palette.shade(Palette.WATER_DEEP, -0.06)
		body.a = 0.75
		var tail: Vector2 = f.pos - f.dir * (f.size + 1.5)
		draw_line(f.pos, tail, body, f.size)
		draw_circle(f.pos, f.size * 0.6, body)
