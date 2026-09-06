extends Node
## Autoload: Spieleinstellungen, persistent in user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

var music_volume: float = 0.6
var fullscreen: bool = false
var show_hints: bool = true

## Belegung der Felder der Bau-Leiste. Leer = Standardbelegung.
var build_loadout: Array = []

## Leistungsanzeige. Bewusst NICHT gespeichert: sie soll bei jedem Start aus
## sein und nur für die laufende Sitzung eingeschaltet werden können.
var show_perf: bool = false

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = clampf(cfg.get_value("audio", "music", music_volume), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	show_hints = bool(cfg.get_value("ui", "hints", show_hints))
	build_loadout = Array(cfg.get_value("ui", "loadout", build_loadout))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("ui", "hints", show_hints)
	cfg.set_value("ui", "loadout", build_loadout)
	cfg.save(PATH)

## Wendet die Einstellungen auf Fenster und Audio an und meldet die Änderung.
func apply() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		# Headless / kein Fenstersystem — Videoeinstellung überspringen.
		changed.emit()
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	changed.emit()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	changed.emit()

