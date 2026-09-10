class_name Quality
extends Node

## Erkennt die Hardware, wählt daraus ein Grafikprofil (HOCH / MITTEL / NIEDRIG)
## und regelt bei anhaltendem FPS-Einbruch gezielt einzelne teure Effekte
## herunter — nicht pauschal alles. Erholt sich die Bildrate wieder, wird die
## Qualität vorsichtig und mit Hysterese zurückgenommen.

signal changed

enum Profile { LOW, MEDIUM, HIGH }

const PROFILE_NAMES := {
	Profile.LOW: "NIEDRIG",
	Profile.MEDIUM: "MITTEL",
	Profile.HIGH: "HOCH",
}

## Basisprofile. Jeder Wert steuert genau ein System — so lässt sich die
## Qualität feinkörnig senken, statt "alles auf LOW" zu schalten.
const PROFILES := {
	Profile.LOW: {
		"rain_shading": false,
		"light_hz": 10.0,
		"light_cells_per_tile": 1,
		"light_max_sources": 24,
		"light_margin": 4,
		"entity_shadows": false,
		"cloud_count": 4,
		"sparkle_budget": 40,
		"rain_particles": 26,
		"water_animation": false,
		"water_ripples": true,
		"water_ripple_budget": 12,
		"fish_count": 0,
		"glow_effects": true,
		"minimap_interval": 1.2,
		"render_scale": 0.85,
	},
	Profile.MEDIUM: {
		"rain_shading": true,
		"light_hz": 15.0,
		"light_cells_per_tile": 1,
		"light_max_sources": 48,
		"light_margin": 5,
		"entity_shadows": true,
		"cloud_count": 7,
		"sparkle_budget": 90,
		"rain_particles": 48,
		"water_animation": true,
		"water_ripples": true,
		"water_ripple_budget": 28,
		"fish_count": 8,
		"glow_effects": true,
		"minimap_interval": 0.7,
		"render_scale": 1.0,
	},
	Profile.HIGH: {
		"rain_shading": true,
		"light_hz": 24.0,
		"light_cells_per_tile": 2,
		"light_max_sources": 96,
		"light_margin": 6,
		"entity_shadows": true,
		"cloud_count": 10,
		"sparkle_budget": 170,
		"rain_particles": 80,
		"water_animation": true,
		"water_ripples": true,
		"water_ripple_budget": 48,
		"fish_count": 16,
		"glow_effects": true,
		"minimap_interval": 0.5,
		"render_scale": 1.0,
	},
}

## Reihenfolge der dynamischen Sparstufen: teuerste Kosmetik zuerst.
const DYNAMIC_STEPS := 4
const TARGET_FPS := 60.0
const WINDOW_SECONDS := 1.5
const DOWN_WINDOWS := 2
const UP_WINDOWS := 5

var profile: int = Profile.MEDIUM
var dynamic_enabled := true
var dynamic_step := 0
var settings: Dictionary = {}
var hardware: Dictionary = {}
## Vom Spieler im Einstellungsmenü gesetzte Ausnahmen. Sie werden *nach* dem
## Profil und *nach* der Dynamikstufe angewandt und gewinnen damit immer.
var user_overrides: Dictionary = {}
var auto_profile := true

var _base_viewport := Vector2i(1280, 720)
var _window_time := 0.0
var _window_frames := 0
var _bad_windows := 0
var _good_windows := 0
var _last_window_fps := 0.0
var _render_scale_applied := 1.0


func _ready() -> void:
	var win := get_window()
	if win != null and win.content_scale_size != Vector2i.ZERO:
		_base_viewport = win.content_scale_size
	else:
		_base_viewport = Vector2i(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
			ProjectSettings.get_setting("display/window/size/viewport_height", 720)
		)
	hardware = _detect_hardware()


## Nur einmal beim Start: Profil aus der Hardware ableiten.
func auto_select() -> void:
	auto_profile = true
	set_profile(_score_to_profile(_hardware_score()))


func set_override(key: String, value: Variant) -> void:
	user_overrides[key] = value
	_rebuild()


func clear_override(key: String) -> void:
	user_overrides.erase(key)
	_rebuild()


func set_profile(value: int, manual: bool = false) -> void:
	if manual:
		auto_profile = false
	profile = clampi(value, Profile.LOW, Profile.HIGH)
	dynamic_step = 0
	_bad_windows = 0
	_good_windows = 0
	_rebuild()


func set_dynamic_enabled(value: bool) -> void:
	dynamic_enabled = value
	if not value and dynamic_step != 0:
		dynamic_step = 0
		_rebuild()


func profile_name() -> String:
	return PROFILE_NAMES[profile]


func get_value(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func render_scale() -> float:
	return _render_scale_applied


func last_window_fps() -> float:
	return _last_window_fps


# --- Dynamische Anpassung ---------------------------------------------------

func _process(delta: float) -> void:
	if not dynamic_enabled:
		return
	_window_time += delta
	_window_frames += 1
	if _window_time < WINDOW_SECONDS:
		return
	_last_window_fps = _window_frames / _window_time
	_window_time = 0.0
	_window_frames = 0
	if _last_window_fps < TARGET_FPS * 0.90:
		_good_windows = 0
		_bad_windows += 1
		if _bad_windows >= DOWN_WINDOWS and dynamic_step < DYNAMIC_STEPS - 1:
			_bad_windows = 0
			dynamic_step += 1
			_rebuild()
	elif _last_window_fps > TARGET_FPS * 1.05:
		_bad_windows = 0
		_good_windows += 1
		if _good_windows >= UP_WINDOWS and dynamic_step > 0:
			_good_windows = 0
			dynamic_step -= 1
			_rebuild()
	else:
		_bad_windows = 0
		_good_windows = 0


## Effektive Einstellungen = Basisprofil, um die aktive Sparstufe reduziert.
func _rebuild() -> void:
	var base: Dictionary = PROFILES[profile]
	var s := base.duplicate()
	if dynamic_step >= 1:
		# Stufe 1: reine Kosmetik am Rand des Blickfelds.
		s.sparkle_budget = int(s.sparkle_budget * 0.4)
		s.cloud_count = maxi(2, s.cloud_count - 3)
		s.fish_count = 0
	if dynamic_step >= 2:
		# Stufe 2: Licht gröber und seltener — bleibt sichtbar, kostet weniger.
		s.light_cells_per_tile = 1
		s.light_hz = maxf(8.0, s.light_hz * 0.7)
		s.light_max_sources = maxi(16, int(s.light_max_sources * 0.6))
		s.rain_particles = int(s.rain_particles * 0.5)
	if dynamic_step >= 3:
		# Stufe 3: letzter Ausweg — Auflösung und Wasseranimation.
		s.water_animation = false
		s.entity_shadows = false
		s.render_scale = minf(s.render_scale, 0.80)
	for key in user_overrides:
		s[key] = user_overrides[key]
	settings = s
	_apply_render_scale(float(s.render_scale))
	changed.emit()


func _apply_render_scale(scale: float) -> void:
	scale = clampf(scale, 0.5, 1.0)
	if is_equal_approx(scale, _render_scale_applied):
		return
	_render_scale_applied = scale
	var win := get_window()
	if win == null:
		return
	win.content_scale_size = Vector2i(
		maxi(320, int(round(_base_viewport.x * scale))),
		maxi(180, int(round(_base_viewport.y * scale)))
	)


# --- Hardware ---------------------------------------------------------------

func _detect_hardware() -> Dictionary:
	var mem := OS.get_memory_info()
	var info := {
		"os": OS.get_name(),
		"engine": "Godot %s" % Engine.get_version_info().get("string", "?"),
		"cpu": OS.get_processor_name(),
		"cores": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"gpu_type": _adapter_type_name(RenderingServer.get_video_adapter_type()),
		"driver": ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
		"ram_physical": mem.get("physical", -1),
		"ram_available": mem.get("available", -1),
	}
	if DisplayServer.get_name() != "headless":
		info["screen"] = DisplayServer.screen_get_size()
		var hz := DisplayServer.screen_get_refresh_rate()
		info["refresh_hz"] = hz if is_finite(hz) and hz > 0.0 else 0.0
	return info


func _adapter_type_name(type: int) -> String:
	match type:
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			return "dedizierte GPU"
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			return "integrierte GPU"
		RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
			return "virtuelle GPU"
		RenderingDevice.DEVICE_TYPE_CPU:
			return "Software (CPU)"
	return "unbekannt"


const _WEAK_GPU_MARKERS := [
	"llvmpipe", "softpipe", "swiftshader", "software", "microsoft basic",
	"intel(r) hd graphics", "intel(r) uhd graphics", "gma", "mesa offscreen",
]
const _STRONG_GPU_MARKERS := [
	"rtx", "gtx 1", "gtx 2", "geforce rtx", "radeon rx", "radeon pro",
	"arc a", "arc b", "quadro", "apple m",
]


func _hardware_score() -> int:
	var score := 0
	var cores: int = hardware.get("cores", 4)
	if cores >= 12:
		score += 3
	elif cores >= 8:
		score += 2
	elif cores >= 4:
		score += 1
	var ram: int = hardware.get("ram_physical", -1)
	if ram > 0:
		var gb := ram / 1073741824.0
		if gb >= 15.0:
			score += 2
		elif gb >= 7.0:
			score += 1
		elif gb < 4.0:
			score -= 1
	var gpu: String = String(hardware.get("gpu", "")).to_lower()
	for marker in _STRONG_GPU_MARKERS:
		if gpu.contains(marker):
			score += 3
			break
	for marker in _WEAK_GPU_MARKERS:
		if gpu.contains(marker):
			score -= 4
			break
	match hardware.get("gpu_type", ""):
		"dedizierte GPU":
			score += 1
		"Software (CPU)":
			score -= 4
	var screen: Variant = hardware.get("screen")
	if screen is Vector2i and (screen as Vector2i).x >= 2560:
		score -= 1
	return score


func _score_to_profile(score: int) -> int:
	if score >= 5:
		return Profile.HIGH
	if score >= 2:
		return Profile.MEDIUM
	return Profile.LOW


## Menschenlesbare Zusammenfassung für das Entwickler-Overlay.
func hardware_lines() -> Array[String]:
	var ram: int = hardware.get("ram_physical", -1)
	var ram_text := "n/v"
	if ram > 0:
		ram_text = "%.1f GB" % (ram / 1073741824.0)
	var out: Array[String] = [
		"CPU   %s (%d Kerne)" % [hardware.get("cpu", "?"), hardware.get("cores", 0)],
		"GPU   %s" % hardware.get("gpu", "?"),
		"      %s · %s" % [hardware.get("gpu_type", "?"), hardware.get("gpu_api", "?")],
		"RAM   %s gesamt" % ram_text,
	]
	if hardware.has("screen"):
		var screen: Vector2i = hardware["screen"]
		var hz: float = hardware.get("refresh_hz", 0.0)
		var hz_text := "%.0f Hz" % hz if hz > 0.0 and is_finite(hz) else "Hz n/v"
		out.append("Bild  %dx%d @ %s" % [screen.x, screen.y, hz_text])
	return out
