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
const BUILD_CHUNKS := Vector2i(128, 128)

## Blockraster beim Start sichtbar. Im Spiel mit G umschaltbar.
##
## AUS beim Start. Das Raster ist ein Werkzeug zum Planen, kein Teil der Welt:
## eingeschaltet legt es ein gelbes Kreuz über den ganzen Bildschirm und
## schreibt „Chunk 64 | 64" quer neben die Figur. Wer das Spiel zum ersten Mal
## startet, sah bisher genau das — eine Karte mit Gitternetz, kein Ort. Es ist
## keine Zeile Funktion verloren: G schaltet es an, die Steuerungshilfe sagt
## das in der ersten Zeile, und die Minimap zeigt Gebautes auch ohne Raster.
const SHOW_BLOCK_GRID := false

## Kantenlänge eines Chunks in Blöcken — dieselbe Größe wie in Minecraft.
const CHUNK := 16

static var MAP_W: int = BUILD_CHUNKS.x * CHUNK
static var MAP_H: int = BUILD_CHUNKS.y * CHUNK

## Wie viele Chunks ringsum geladen bleiben.
##
## Statisch statt konstant: die Sichtweite ist eine Einstellung. `Graphics`
## setzt den Wert aus `Settings.render_range`, der ChunkStreamer liest ihn bei
## jeder Neuberechnung. Radius 2 (5 x 5 Chunks) ist die Voreinstellung — der
## Bildausschnitt ist bei Zoom 1,5 nur rund 27 x 15 Blöcke groß, das lässt
## ringsum mindestens einen ganzen Chunk Puffer.
static var LOAD_RADIUS: int = 2

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


## Kamerazoom. MUSS ganzzahlig sein.
##
## Vorher stand hier 1,5, damit das Sichtfeld bei der Verdopplung der
## Kachelgröße gleich blieb. Der Preis dafür war hoch und fiel erst beim
## Hineinzoomen ins Bild auf: bei Faktor 1,5 wird aus einem Weltpixel mal ein,
## mal zwei Bildschirmpunkte. Jede Kante einer Figur war dadurch abwechselnd
## ein und zwei Punkte dick, Augen waren unterschiedlich breit, Umrisse
## ausgefranst — genau das, was Pixel-Art nicht sein darf, und durch keine
## bessere Zeichnung zu heilen.
##
## Mit Faktor 2 ist jeder Weltpixel exakt zwei Bildschirmpunkte. Das Sichtfeld
## wird dabei kleiner (20 x 11 statt 27 x 15 Blöcke) — das ist die Gegenleistung
## und in etwa die Bildeinstellung, die Aufbauspiele dieser Art benutzen.
const CAMERA_ZOOM := 2.0
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

## Wo die Figur startet: die Kartenmitte, dort ist ringsum gleich viel Platz.
static func spawn_block() -> Vector2i:
	return Vector2i(MAP_W / 2, MAP_H / 2)

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
	["jump", "Springen"],
	["build_place", "Block setzen"],
	["build_remove", "Block entfernen"],
	["build_slot_1", "Material wählen (1 Gras, 2 Sand, 3 Wasser)"],
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
