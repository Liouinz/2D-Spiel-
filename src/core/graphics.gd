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

## Beleuchtung in Stufen, weil die drei Bestandteile sehr unterschiedlich
## kosten. Gemessen (Renderzeit des Viewports, llvmpipe, 1280 x 720; die
## Aufschläge gelten gegenüber „Aus"):
##
##   Einfach   nur die Tönung ............  CPU -0,10 ms   GPU -0,09 ms
##   Mittel    + Schein um die Figur ......  CPU -0,15 ms   GPU +2,03 ms
##   Hoch      + Sichtgrenze am Bildrand ..  CPU +2,32 ms   GPU +4,14 ms
##
## Die Tönung ist der Teil, der die Stimmung macht, und sie ist GRATIS: ein
## `CanvasModulate` ist ein Multiplizieren, egal wie viele Kacheln im Bild
## liegen. Wer auf einem schwachen Rechner spielt, bekommt mit „Einfach" also
## den ganzen Tagesverlauf, ohne irgendetwas dafür zu bezahlen.
##
## Die beiden oberen Stufen kosten Füllrate — zwei grosse durchsichtige
## Flächen über dem Bild. Deshalb stehen sie einzeln zur Wahl und nicht in
## einem Schalter zusammengefasst.
const LIGHT := ["Aus", "Einfach", "Mittel", "Hoch"]

## Läuft die Zeit? Das ist eine Frage des Spielgefühls, keine der Leistung —
## ein stehender Tag kostet genauso viel wie ein laufender. Deshalb eine
## eigene Zeile statt einer weiteren Lichtstufe.
const DAY := ["Fest", "Verlauf"]

## --- Automatische Anpassung --------------------------------------------------
##
## Ziel sind 60 Bilder je Sekunde. Wird es dauerhaft langsamer, nimmt die
## Automatik EINE teure Wirkung weg; ist wieder Luft, gibt sie eine zurück.
## Immer nur eine je Schritt: mehrere gleichzeitig wären ein sichtbarer Sprung,
## und hinterher wüsste niemand, was geholfen hat.
const TARGET_MS := 1000.0 / 60.0
const DOWN_MS := TARGET_MS * 1.35     ## ab hier wird weggenommen (rund 44 FPS)
const UP_MS := TARGET_MS * 0.80       ## ab hier ist wieder Luft (rund 75 FPS)
const HOLD := 4.0                     ## so lange muss es anhalten

## Setzt Main beim Betreten und Verlassen der Welt. Im Menü wird nicht
## geregelt: dort ist das Bild ohnehin billig, und die Automatik würde
## fröhlich hochregeln, was in der Welt gleich wieder klemmt.
var in_world: bool = false

var _slow: float = 0.0
var _fast: float = 0.0
## Wohin darf wieder hochgeregelt werden? Das ist der Stand, den der Mensch
## eingestellt hat — die Automatik darf abnehmen, aber nie mehr geben, als
## gewollt war.
var _ceiling: Dictionary = {}

func _ready() -> void:
	Settings.changed.connect(apply)
	_remember_ceiling()
	apply()

func _process(delta: float) -> void:
	if not (Settings.auto_quality and in_world):
		return
	var ms := Perf.smooth_ms()
	if ms > DOWN_MS:
		_slow += delta
		_fast = 0.0
	elif ms < UP_MS:
		_fast += delta
		_slow = 0.0
	else:
		_slow = 0.0
		_fast = 0.0
	if _slow >= HOLD:
		_slow = 0.0
		var gave: String = Quality.step_down()
		if gave != "":
			print("Automatik: %s heruntergesetzt (%.1f ms je Bild)" % [gave, ms])
			Settings.changed_and_save()
	elif _fast >= HOLD * 2.0:
		# Nach oben vorsichtiger als nach unten: ein Ruckler ist schlimmer als
		# eine Wirkung, die eine Weile fehlt.
		_fast = 0.0
		var back: String = Quality.step_up(_ceiling)
		if back != "":
			print("Automatik: %s wieder erhöht (%.1f ms je Bild)" % [back, ms])
			Settings.changed_and_save()

## Merkt sich den vom Menschen gewählten Stand als Obergrenze.
func _remember_ceiling() -> void:
	_ceiling = {}
	for entry: Array in Quality.GIVE_UP:
		var key: String = entry[0]
		_ceiling[key] = maxi(int(_ceiling.get(key, 0)), int(Settings.get(key)))

## Wird gerufen, wenn ein Mensch eine Grafikeinstellung von Hand ändert: dann
## gilt sein Stand als neue Obergrenze.
func set_ceiling_from_settings() -> void:
	_remember_ceiling()

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

## Wie dicht Büschel, Blumen und Kiesel stehen — als Promille der Felder.
##
## Auf Gras deutlich dichter als auf Sand: eine Wiese ist bewachsen, ein Strand
## ist überwiegend leer, und ein gleichmässig bestreuter Strand sähe falsch aus.
func decor_chance(tile: int) -> int:
	var step := clampi(Settings.decor, 0, 2)
	if step == 0:
		return 0
	match tile:
		MapData.Tile.GRASS:
			return 70 if step == 1 else 150
		MapData.Tile.SAND:
			return 25 if step == 1 else 55
	return 0

## Beleuchtungsstufe: 0 aus, 1 nur Tönung, 2 mit Schein, 3 mit Sichtgrenze.
##
## Auf Stufe 0 hängt sich der LightManager komplett ab — kein Tönen, kein
## Schein, keine Sichtgrenze, kein Prozessschritt. Eine Einstellung „Aus", die
## trotzdem jeden Bildpunkt anfasst, wäre eine Lüge.
func light_mode() -> int:
	return clampi(Settings.light, 0, LIGHT.size() - 1)

## Läuft die Tageszeit weiter? Bei „Fest" bleibt es heller Vormittag.
func day_cycle() -> bool:
	return Settings.day_cycle

## Schattenwurf der Figur.
func shadows_on() -> bool:
	return Settings.shadows
