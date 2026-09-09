class_name Quality
extends RefCounted
## Grafikprofile und was der Rechner davon verträgt.
##
## ## Nicht alles auf „niedrig"
##
## Ein Profil, das jeden Regler nach unten schiebt, ist keine Anpassung,
## sondern Aufgeben. Die Systeme kosten sehr unterschiedlich, und das ist
## gemessen, nicht geschätzt (Renderzeit des Viewports, llvmpipe, 1280 x 720):
##
##   Tönung des Tageslichts .......  ±0,0 ms       — gratis
##   Bewuchs am Boden .............  ±0,0 ms       — eine Kachelschicht
##   Schein um die Figur ..........  +2,0 ms GPU   — eine durchsichtige Fläche
##   Sichtgrenze am Bildrand ......  +2,8 ms GPU   — eine zweite
##
## Deshalb behält auch die niedrigste Stufe den vollen Tagesverlauf und den
## Bewuchs: beides kostet nichts und macht den grössten Teil des Eindrucks.
## Weggenommen wird, was Füllrate frisst.
##
## ## Der Vorschlag ist ein Vorschlag
##
## `suggest()` rät aus der Hardware. Raten ist es deshalb, weil kein
## Spielprogramm die Leistung eines Rechners aus seinem Namen ablesen kann —
## es gibt keine verlässliche Liste. Die Zahlen, die Godot liefert (Bauart der
## Grafikkarte, Kerne, Arbeitsspeicher), reichen für eine erste Einordnung und
## für nicht mehr. Korrigiert wird sie danach durch Messung: die Automatik
## schaut auf die tatsächliche Bildzeit und regelt nach.

enum Level { NIEDRIG, MITTEL, HOCH }

const NAMES := ["Niedrig", "Mittel", "Hoch"]

## Was ein Profil an welchem System einstellt. Jede Zeile ist ein Feld in
## `Settings`; was hier nicht steht, rührt kein Profil an.
const PROFILES := {
	Level.NIEDRIG: {
		"light": 1,          # Tönung ja, die beiden Flächen nein
		"water_detail": 0,   # ruhige Fläche statt Glitzern
		"wind": 0,
		"particles": 0,
		"decor": 1,          # eine Kachelschicht — praktisch gratis
		"shadows": false,
		"render_range": 0,   # 3 x 3 Chunks
	},
	Level.MITTEL: {
		"light": 2,          # mit Schein, ohne Sichtgrenze
		"water_detail": 1,
		"wind": 1,
		"particles": 1,
		"decor": 2,
		"shadows": true,
		"render_range": 1,   # 5 x 5
	},
	Level.HOCH: {
		"light": 3,
		"water_detail": 2,
		"wind": 2,
		"particles": 2,
		"decor": 2,
		"shadows": true,
		"render_range": 2,   # 7 x 7
	},
}

## Reihenfolge, in der die Automatik Qualität WEGNIMMT — teuerstes zuerst.
##
## Das ist keine Geschmacksfrage, sondern die Messreihe von oben, von unten
## gelesen. Wer Leistung braucht, soll zuerst das verlieren, was am meisten
## kostet, und nicht das, was am ehesten auffällt.
const GIVE_UP := [
	# Zuerst das echte 2D-Licht. Es ist mit weitem Abstand der teuerste Posten
	# im ganzen Spiel: gemessen +16,80 ms Bildzeit gegenueber dem additiven
	# Schein, also mehr als alles andere zusammen. Wer die Stufe eingestellt
	# hat, bekommt sie zurueck, sobald wieder Luft ist — aber wenn es klemmt,
	# geht sie als erste.
	["light", 3],            # echtes Licht weg
	["light", 2],            # Sichtgrenze weg
	["particles", 0],        # Staub weg
	["light", 1],            # Schein weg
	["wind", 0],             # Bewegung weg
	["water_detail", 0],     # Wasserwirkung weg
	["render_range", 0],     # Sichtweite herunter
]

# --- Was für ein Rechner ist das? ---------------------------------------------

## Alles, was Godot verlässlich über die Maschine sagen kann.
##
## Bewusst NICHT dabei: Auslastung in Prozent, Taktraten, Grafikspeicher der
## Karte insgesamt. Das liefert die Engine nicht, und geraten wäre es wertlos.
static func hardware() -> Dictionary:
	var mem := OS.get_memory_info()
	return {
		"cpu": OS.get_processor_name(),
		"cores": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_type": RenderingServer.get_video_adapter_type(),
		"ram": int(mem.get("physical", -1)),
		"screen": DisplayServer.screen_get_size(),
	}

## Die Bauart der Grafikkarte in Worten.
static func gpu_kind(type: int) -> String:
	match type:
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: return "eigene Grafikkarte"
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU: return "eingebaute Grafik"
		RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU: return "virtuelle Grafik"
		RenderingDevice.DEVICE_TYPE_CPU: return "ohne Grafikkarte"
	return "unbekannt"

## Erster Vorschlag aus der Hardware.
##
## Und hier ist eine ehrliche Einschränkung: **im GL-Compatibility-Renderer
## meldet Godot die Bauart der Grafikkarte gar nicht.** `get_video_adapter_type()`
## liefert dort „unbekannt", auch auf einem Rechner mit eigener Karte. Auf der
## Testmaschine sieht man das direkt: „4 Kerne, llvmpipe, unbekannt".
##
## „Unbekannt" wird deshalb NICHT bestraft — sonst bekäme jeder Spieler
## dauerhaft die mittlere Stufe vorgeschlagen, egal was in seinem Rechner
## steckt. Sicher erkennen lässt sich am Namen nur der eine Fall, der wirklich
## eine Stufe nach unten gehört: ein Software-Rasterizer, also gar keine
## Grafikkarte.
##
## Der Rest ist eine grobe Einordnung nach Kernen und Arbeitsspeicher. Sie ist
## der ANFANGSWERT, nicht die Antwort: die eigentliche Entscheidung trifft die
## Automatik anhand der gemessenen Bildzeit, und die weiss mehr als jede Liste
## von Gerätenamen.
static func suggest() -> int:
	var hw := hardware()
	var gpu := String(hw["gpu"]).to_lower()
	for soft: String in ["llvmpipe", "softpipe", "swrast", "software"]:
		if gpu.contains(soft):
			return Level.NIEDRIG
	var score := 0
	match int(hw["gpu_type"]):
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: score += 3
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU: score += 1
		_: score += 1                      # unbekannt — siehe oben
	var cores := int(hw["cores"])
	if cores >= 8:
		score += 2
	elif cores >= 4:
		score += 1
	var ram := int(hw["ram"])
	if ram >= 12 * 1073741824:
		score += 2
	elif ram >= 8 * 1073741824:
		score += 1
	# Ein sehr grosser Bildschirm bedeutet mehr Bildpunkte für dieselbe Karte.
	if (hw["screen"] as Vector2i).y > 1440:
		score -= 1
	if score >= 5:
		return Level.HOCH
	if score >= 3:
		return Level.MITTEL
	return Level.NIEDRIG

# --- Profile anwenden und erkennen --------------------------------------------

## Schreibt ein Profil in die Einstellungen. Speichert und meldet selbst nicht —
## das macht der Aufrufer, damit auch mehrere Änderungen zusammen greifen.
static func apply(level: int) -> void:
	var p: Dictionary = PROFILES.get(clampi(level, 0, Level.size() - 1), {})
	for key: String in p:
		Settings.set(key, p[key])

## Welches Profil gilt gerade — oder -1, wenn die Einstellungen zu keinem
## passen. Das ist absichtlich zustandslos: eine gespeicherte „aktuelle Stufe"
## würde irgendwann behaupten, „Hoch" sei eingestellt, während drei Regler
## längst von Hand verstellt sind.
static func current() -> int:
	for level: int in PROFILES:
		var p: Dictionary = PROFILES[level]
		var match_all := true
		for key: String in p:
			if Settings.get(key) != p[key]:
				match_all = false
				break
		if match_all:
			return level
	return -1

## Ein Schritt nach unten: nimmt genau EINE teure Wirkung weg und meldet, ob
## noch etwas übrig war. Mehr als eine je Schritt wäre ein Sprung, den man
## sieht — und man wüsste hinterher nicht, was geholfen hat.
static func step_down() -> String:
	for entry: Array in GIVE_UP:
		var key: String = entry[0]
		var want: int = entry[1]
		if int(Settings.get(key)) > want:
			Settings.set(key, want)
			return key
	return ""

## Ein Schritt zurück nach oben, in umgekehrter Reihenfolge: zuletzt
## weggenommen, zuerst zurückgegeben.
static func step_up(ceiling: Dictionary) -> String:
	for i in range(GIVE_UP.size() - 1, -1, -1):
		var key: String = GIVE_UP[i][0]
		var max_value := int(ceiling.get(key, 0))
		if int(Settings.get(key)) < max_value:
			Settings.set(key, int(Settings.get(key)) + 1)
			return key
	return ""
