extends Node
## Autoload: übersetzt die Bild- und Leistungseinstellungen in das, was Engine
## und Welt wirklich brauchen — und wendet sie an.
##
## Hier liegen auch die Auswahllisten für das Einstellungsmenü. Damit gibt es
## für jede Stufe genau eine Wahrheit: dieselbe Liste beschriftet die Oberfläche
## UND liefert den Wert, mit dem gerechnet wird. Eine Beschriftung, hinter der
## kein Wert steht, kann so gar nicht erst entstehen.
##
## Grundsatz: Was hier nicht angewendet wird, steht auch nicht im Menü. Ein
## Schalter ohne Wirkung ist schlimmer als kein Schalter.

## Wird nach jeder Anwendung gemeldet. Welt und Figur ziehen daran nach.
signal applied

# --- Auswahllisten -----------------------------------------------------------

const FPS_LABELS := ["30", "60", "90", "120", "144", "165", "Unbegrenzt"]
const FPS_VALUES := [30, 60, 90, 120, 144, 165, 0]

## Sichtweite als Kantenlänge des geladenen Chunk-Quadrats. Der Radius ist die
## Zahl, mit der der ChunkStreamer rechnet; die Kantenlänge ist die, die man
## sich vorstellen kann.
const RANGE_LABELS := ["3 × 3", "5 × 5", "7 × 7", "9 × 9"]
const RANGE_RADIUS := [1, 2, 3, 4]

const OFF_ON := ["Aus", "An"]
const DETAIL := ["Einfach", "Mittel", "Hoch"]
const STEPS := ["Aus", "Reduziert", "Voll"]

func _ready() -> void:
	Settings.changed.connect(apply)
	apply()

## Setzt alles, was sofort wirken kann. Wird bei jeder Änderung aufgerufen.
func apply() -> void:
	Engine.max_fps = fps_limit()
	Config.LOAD_RADIUS = chunk_radius()
	_apply_window()
	applied.emit()

## Fenstermodus und Bildsynchronisierung. Ohne Fenstersystem (headless im
## Selbsttest) gibt es beides nicht — dann wird es übersprungen statt zu stürzen.
func _apply_window() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if Settings.fullscreen \
		else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Settings.vsync
		else DisplayServer.VSYNC_DISABLED)

# --- Abgeleitete Werte -------------------------------------------------------
# Wer etwas braucht, fragt hier — niemand rechnet einen Index selbst aus.

## Bildratenbegrenzung. 0 heisst unbegrenzt; das ist auch Godots eigene
## Schreibweise für `Engine.max_fps`.
##
## Bewusst KEINE Mindest-Bildrate: die kann kein Spiel versprechen. Was hier
## eingestellt wird, ist eine Obergrenze — sie hält die Bildabstände gleichmässig
## und den Rechner ruhig, statt so viele Bilder wie möglich zu erzeugen.
func fps_limit() -> int:
	return int(FPS_VALUES[clampi(Settings.fps_limit, 0, FPS_VALUES.size() - 1)])

## Wie viele Chunks ringsum geladen bleiben.
func chunk_radius() -> int:
	return int(RANGE_RADIUS[clampi(Settings.render_range, 0, RANGE_RADIUS.size() - 1)])

## Wie oft die Wasserwirkung neu gezeichnet wird (Bilder je Sekunde).
func water_redraw_hz() -> float:
	match clampi(Settings.water_detail, 0, 2):
		0: return 8.0
		1: return 16.0
		_: return 24.0

## Zeichnet das Wasser Glitzern und Brandung? Auf der einfachsten Stufe bleibt
## die Fläche ruhig — das spart den grössten Teil der Zeichenarbeit.
func water_animated() -> bool:
	return Settings.water_detail > 0

## Wie stark sich Gras und Wasser bewegen. 0 heisst: gar nicht.
func wind_strength() -> float:
	match clampi(Settings.wind, 0, 2):
		0: return 0.0
		1: return 0.45
		_: return 1.0

## Wie viele Staubpunkte gleichzeitig in der Luft sind.
##
## Die Zahl ist absichtlich klein: sie leben nur im sichtbaren Ausschnitt, und
## mehr als eine Handvoll wirkt nicht lebendiger, sondern schmutzig.
func particle_count() -> int:
	match clampi(Settings.particles, 0, 2):
		0: return 0
		1: return 18
		_: return 42

## Schattenwurf der Figur.
func shadows_on() -> bool:
	return Settings.shadows
