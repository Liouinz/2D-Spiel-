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

## Halber Zoom bei doppelter Kachelgröße = unverändertes Sichtfeld,
## aber doppelt so feine Grafik.
const CAMERA_ZOOM := 1.5
const CAMERA_SMOOTH := 6.0            ## Interpolationsgeschwindigkeit der Kamera

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
		"toggle_grid": [KEY_G],
	}
	for action: String in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
