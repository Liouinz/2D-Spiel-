class_name LightManager
extends Node2D

## Tag/Nacht-Zyklus: CanvasModulate tönt die Welt (Tag → warmes Abendlicht →
## blaue Nacht), Lagerfeuer und Hütten bekommen nachts echte 2D-Lichter.

const MAX_LIGHTS := 48
const NIGHT_COLOR := Color(0.30, 0.36, 0.58)
const DUSK_COLOR := Color(1.0, 0.82, 0.64)

var sim: Simulation

var _modulate := CanvasModulate.new()
var _lights: Array[PointLight2D] = []
var _light_texture: GradientTexture2D


func _init(sim_ref: Simulation) -> void:
	sim = sim_ref
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.7, 1.0),
		Color(1.0, 0.8, 0.5, 0.35),
		Color(1.0, 0.8, 0.5, 0.0),
	])
	_light_texture = GradientTexture2D.new()
	_light_texture.gradient = gradient
	_light_texture.fill = GradientTexture2D.FILL_RADIAL
	_light_texture.fill_from = Vector2(0.5, 0.5)
	_light_texture.fill_to = Vector2(0.5, 0.0)
	_light_texture.width = 128
	_light_texture.height = 128


func _ready() -> void:
	add_child(_modulate)


func _process(_delta: float) -> void:
	var nf := sim.night_factor()
	_modulate.color = Color.WHITE.lerp(DUSK_COLOR, clampf(nf * 2.0, 0.0, 1.0)) \
		.lerp(NIGHT_COLOR, clampf(nf * 2.0 - 1.0, 0.0, 1.0))
	_sync_lights(nf)


func _sync_lights(night: float) -> void:
	var wanted: Array = []
	for v in sim.villages:
		if not v.fallen:
			wanted.append({"pos": v.center_pos + Vector2(0, -3), "energy": 1.5, "scale": 0.9})
		for hut in v.huts:
			if wanted.size() >= MAX_LIGHTS:
				break
			wanted.append({
				"pos": Vector2(hut) * Terrain.TILE + Vector2(8, 10),
				"energy": 0.7,
				"scale": 0.55,
			})
	while _lights.size() < wanted.size() and _lights.size() < MAX_LIGHTS:
		var light := PointLight2D.new()
		light.texture = _light_texture
		add_child(light)
		_lights.append(light)
	for i in _lights.size():
		var light := _lights[i]
		if i < wanted.size() and night > 0.05:
			light.enabled = true
			light.position = wanted[i].pos
			light.energy = wanted[i].energy * night
			light.texture_scale = wanted[i].scale
		else:
			light.enabled = false
