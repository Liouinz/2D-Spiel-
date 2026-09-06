class_name Config
extends RefCounted
## Zentrale Konstanten. Keine hart codierten Werte im restlichen Code (§11).

## Kachelgröße in Bildpunkten. 32 statt 16: bei halbem Kamerazoom bleibt das
## Sichtfeld gleich, aber jede Kachel hat die vierfache Pixelfläche für Details.
const TILE := 32
const WORLD_SEED := 20260904          ## fester Seed -> reproduzierbare Welt

## Weltgröße in Blöcken. Sie hängt vom Modus ab, deshalb statisch statt
## konstant.
##
## Aufbaumodus: 128 x 128 Chunks = 2048 x 2048 Blöcke = 4,2 Millionen Kacheln.
## Das geht nur, weil chunkweise geladen wird; im Speicher liegt davon allein
## die Karte selbst (4,2 MB).
##
## Insel: bleibt bei 96 x 80. src/world/layout.gd setzt Dorf, Brunnen und Zäune
## auf feste Koordinaten — auf einer 2048er Karte stünde das Dorf in der Ecke,
## und die Inselerzeugung über 4,2 Millionen Zellen wäre unbrauchbar langsam.
const BUILD_CHUNKS := Vector2i(128, 128)
const ISLAND_BLOCKS := Vector2i(96, 80)

## Aufbaumodus. true = leere Karte mit sichtbarem Blockraster; damit lässt sich
## planen, welches Objekt später wie viele Blöcke belegt. Auf false entsteht
## wieder die komplette Insel mit Dorf, Wald, Wegen und Küste — der Code dafür
## bleibt vollständig erhalten.
const EMPTY_WORLD := true

## Blockraster beim Start sichtbar. Im Spiel mit G umschaltbar.
const SHOW_BLOCK_GRID := true

## Kantenlänge eines Chunks in Blöcken — dieselbe Größe wie in Minecraft.
const CHUNK := 16

static var MAP_W: int = (BUILD_CHUNKS.x * CHUNK) if EMPTY_WORLD else ISLAND_BLOCKS.x
static var MAP_H: int = (BUILD_CHUNKS.y * CHUNK) if EMPTY_WORLD else ISLAND_BLOCKS.y

## Wie viele Chunks ringsum geladen bleiben. Der Bildausschnitt ist bei Zoom 1,5
## nur rund 27 x 15 Blöcke groß; Radius 2 lässt also ringsum mindestens einen
## ganzen Chunk Puffer. Notfalls hier heruntersetzen, nicht die Weltgröße.
const LOAD_RADIUS := 2

## Höchstens so viele Chunks werden je Bild nachgeladen. Ein Chunk kostet ein
## paar Millisekunden — auf mehrere Bilder verteilt merkt man davon nichts.
const CHUNK_BUDGET := 2

const PLAYER_SPEED := 124.0           ## Gehen (px/s)
const PLAYER_RUN_SPEED := 216.0       ## Rennen (px/s)
const PLAYER_ACCEL := 1800.0
const PLAYER_FRICTION := 2200.0
const PLAYER_HITBOX := Vector2(18, 12)  ## Fußkollision (halbe Größe)

## Sprung. Von oben gesehen ist er reine Darstellung: die Figur hebt ab, der
## Schatten bleibt am Boden. Die Kollision bleibt unverändert — über Wände
## oder Wasser kommt man nicht.
const JUMP_TIME := 0.45               ## Dauer eines Sprungs in Sekunden
const JUMP_HEIGHT := 14.0             ## Scheitelhöhe in Bildpunkten

## Schwimmen. Im flachen Wasser kommt man durch, aber langsamer als an Land —
## rund 55 % der Gehgeschwindigkeit. Gerannt und gesprungen wird nicht.
const SWIM_SPEED := 68.0

## Ab dieser Sprunghöhe kommt man eine Stufe hinauf. Knapp die halbe
## Scheitelhöhe: man muss den Sprung wirklich treffen, aber nicht auf den Punkt.
const CLIMB_HEIGHT := 7.0
const FALL_TIME := 0.20               ## kurzes Fallen beim Heruntergehen

## Halber Zoom bei doppelter Kachelgröße = unverändertes Sichtfeld,
## aber doppelt so feine Grafik.
const CAMERA_ZOOM := 1.5
const CAMERA_SMOOTH := 6.0            ## Interpolationsgeschwindigkeit der Kamera

## Streuwert aus zwei Koordinaten — dieselbe Kachel bekommt immer denselben
## Wert, aber ohne sichtbares Muster. Die Primzahlen sind die üblichen aus
## Spatial-Hashing; das Durchmischen am Ende verhindert Streifen.
##
## Wird für Kachelvarianten und für die Verteilung der Dekoration gebraucht.
static func hash2(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

static func world_size_px() -> Vector2i:
	return Vector2i(MAP_W * TILE, MAP_H * TILE)

## Wo die Figur startet. Im Aufbaumodus die Kartenmitte — dort ist ringsum
## gleich viel Platz. Auf der Insel der von Hand gesetzte Dorfrand.
static func spawn_block() -> Vector2i:
	return Vector2i(MAP_W / 2, MAP_H / 2) if EMPTY_WORLD else Layout.SPAWN

## Legt die Tastenbelegung zur Laufzeit an (hält project.godot schlank).
static func setup_input() -> void:
	var actions := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT],
		"jump": [KEY_SPACE],
		"inventory": [KEY_E],
		"toggle_grid": [KEY_G],
		"toggle_minimap": [KEY_M],
		"toggle_info": [KEY_H],
		"debug_info": [KEY_F3],
		"save_map": [KEY_F5],
		"build_slot_1": [KEY_1],
		"build_slot_2": [KEY_2],
		"build_slot_3": [KEY_3],
		"build_slot_4": [KEY_4],
		"build_slot_5": [KEY_5],
		"build_slot_6": [KEY_6],
		"build_slot_7": [KEY_7],
		"build_slot_8": [KEY_8],
	}
	for action: String in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

	# Maustasten gehören genauso in die InputMap wie Tasten — sonst steht die
	# Belegung an zwei Orten und die Steuerungsübersicht kennt nur die Hälfte.
	var mouse := {
		"build_place": MOUSE_BUTTON_LEFT,
		"build_remove": MOUSE_BUTTON_RIGHT,
	}
	for action: String in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = mouse[action]
		InputMap.action_add_event(action, ev)

## Reihenfolge und Beschriftung der Steuerungsübersicht.
##
## Hier stehen NUR die Beschriftungen. Welche Taste eine Aktion auslöst, holt
## die Anzeige aus der InputMap — dadurch kann dort nie eine veraltete oder
## erfundene Taste stehen.
const CONTROL_ROWS := [
	["move_up+move_left+move_down+move_right", "Laufen (auch Pfeiltasten)"],
	["run", "Rennen"],
	["jump", "Springen — und auf Fels hinauf"],
	["build_place", "Block setzen"],
	["build_remove", "Block entfernen"],
	["build_slot_1", "Bau-Leiste Feld 1 (bis Feld 8 mit 2–8)"],
	["inventory", "Inventar öffnen und schliessen"],
	["toggle_grid", "Blockraster ein und aus"],
	["toggle_minimap", "Minimap ein und aus"],
	["toggle_info", "Anzeige oben links ein und aus"],
	["save_map", "Karte speichern"],
	["debug_info", "Entwicklerinfo ein und aus"],
	["ui_cancel", "Pause / zurück"],
]

## Lesbare Tastennamen einer Aktion, direkt aus der InputMap.
##
## Mausrad und weitere Sonderfälle sind bewusst mit aufgeführt: was die Engine
## kennt, soll auch dastehen.
static func keys_for(action: String) -> String:
	# Mehrere Aktionen mit „+" verbunden ergeben eine Zeile: bei der Bewegung
	# soll „W A S D" dastehen und nicht viermal dieselbe Zeile.
	if action.contains("+"):
		var parts: Array[String] = []
		for one: String in action.split("+"):
			var k := keys_for(one)
			parts.append(k.split(" / ")[0])
		return " ".join(parts)
	if not InputMap.has_action(action):
		return "—"
	var names: Array[String] = []
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			names.append(OS.get_keycode_string(code))
		elif ev is InputEventMouseButton:
			names.append(MOUSE_NAMES.get((ev as InputEventMouseButton).button_index,
				"Maustaste"))
	return " / ".join(names) if not names.is_empty() else "—"

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Linke Maustaste",
	MOUSE_BUTTON_RIGHT: "Rechte Maustaste",
	MOUSE_BUTTON_MIDDLE: "Mausrad-Klick",
	MOUSE_BUTTON_WHEEL_UP: "Mausrad hoch",
	MOUSE_BUTTON_WHEEL_DOWN: "Mausrad runter",
}
