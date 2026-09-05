class_name Config
extends RefCounted
## Zentrale Konstanten. Keine hart codierten Werte im restlichen Code (§11).

## Kachelgröße in Bildpunkten. 32 statt 16: bei halbem Kamerazoom bleibt das
## Sichtfeld gleich, aber jede Kachel hat die vierfache Pixelfläche für Details.
const TILE := 32
const MAP_W := 96                     ## Weltbreite in Kacheln
const MAP_H := 72                     ## Welthöhe in Kacheln
const WORLD_SEED := 20260904          ## fester Seed -> reproduzierbare Welt

const PLAYER_SPEED := 124.0           ## Gehen (px/s)
const PLAYER_RUN_SPEED := 216.0       ## Rennen (px/s)
const PLAYER_ACCEL := 1800.0
const PLAYER_FRICTION := 2200.0
const PLAYER_HITBOX := Vector2(18, 12)  ## Fußkollision (halbe Größe)

## Halber Zoom bei doppelter Kachelgröße = unverändertes Sichtfeld,
## aber doppelt so feine Grafik.
const CAMERA_ZOOM := 1.5
const CAMERA_SMOOTH := 6.0            ## Interpolationsgeschwindigkeit der Kamera

static func world_size_px() -> Vector2i:
	return Vector2i(MAP_W * TILE, MAP_H * TILE)

## Legt die Tastenbelegung zur Laufzeit an (hält project.godot schlank).
static func setup_input() -> void:
	var actions := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT],
	}
	for action: String in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
