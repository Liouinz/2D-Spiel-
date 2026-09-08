extends Node
## Autoload: was der Spieler eingestellt hat — nur Daten, sonst nichts.
##
## Diese Datei speichert und lädt, sie WENDET nichts an. Das macht `Graphics`
## für Bild und Leistung und `Audio` für den Ton. Vorher hing beides hier
## zusammen; dadurch musste jeder, der einen Wert lesen wollte, die Datei
## anfassen, die ihn auch anwendet.
##
## Wer etwas ändert, meldet es über `changed`. Alles, was daran hängt, zieht
## nach — deshalb wirken Einstellungen sofort und nicht erst beim Neustart.

signal changed

const PATH := "user://settings.cfg"

# --- Allgemein ---------------------------------------------------------------

var show_hints: bool = true
var build_loadout: Array = []      ## Belegung der Bauleiste

# --- Bild --------------------------------------------------------------------

var fullscreen: bool = false
var vsync: bool = true
var render_range: int = 1          ## Index in Graphics.RANGE_*
var water_detail: int = 2          ## Index in Graphics.DETAIL
var wind: int = 2                  ## Index in Graphics.STEPS — Bewegung im Boden
var particles: int = 2             ## Index in Graphics.STEPS — Staub in der Luft
var decor: int = 2                 ## Index in Graphics.STEPS — Bewuchs am Boden
var shadows: bool = true

# --- Leistung ----------------------------------------------------------------

var fps_limit: int = 1             ## Index in Graphics.FPS_*

## Leistungsanzeige. Bewusst NICHT gespeichert: sie soll bei jedem Start aus
## sein und nur für die laufende Sitzung eingeschaltet werden können.
var show_perf: bool = false

# --- Ton ---------------------------------------------------------------------

var music_volume: float = 0.6

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = clampf(cfg.get_value("audio", "music", music_volume), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	render_range = int(cfg.get_value("video", "range", render_range))
	water_detail = int(cfg.get_value("video", "water", water_detail))
	wind = int(cfg.get_value("video", "wind", wind))
	particles = int(cfg.get_value("video", "particles", particles))
	decor = int(cfg.get_value("video", "decor", decor))
	shadows = bool(cfg.get_value("video", "shadows", shadows))
	fps_limit = int(cfg.get_value("perf", "fps", fps_limit))
	show_hints = bool(cfg.get_value("ui", "hints", show_hints))
	build_loadout = Array(cfg.get_value("ui", "loadout", build_loadout))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "range", render_range)
	cfg.set_value("video", "water", water_detail)
	cfg.set_value("video", "wind", wind)
	cfg.set_value("video", "particles", particles)
	cfg.set_value("video", "decor", decor)
	cfg.set_value("video", "shadows", shadows)
	cfg.set_value("perf", "fps", fps_limit)
	cfg.set_value("ui", "hints", show_hints)
	cfg.set_value("ui", "loadout", build_loadout)
	cfg.save(PATH)

## Meldet eine Änderung und sichert sie. Jede Einstellung läuft hier durch —
## dadurch kann keine vergessen werden zu speichern.
func changed_and_save() -> void:
	changed.emit()
	save_settings()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	changed.emit()
