class_name Config
extends RefCounted
## Zentrale Konstanten. Keine hart codierten Werte im restlichen Code (§11).

const TILE := 16                      ## Kantenlänge einer Kachel in Pixeln
const MAP_W := 96                     ## Weltbreite in Kacheln
const MAP_H := 72                     ## Welthöhe in Kacheln
const WORLD_SEED := 20260904          ## fester Seed -> reproduzierbare Welt

const PLAYER_SPEED := 62.0            ## Gehen (px/s)
const PLAYER_RUN_SPEED := 108.0       ## Rennen (px/s)
const PLAYER_ACCEL := 900.0
const PLAYER_FRICTION := 1100.0
const PLAYER_HITBOX := Vector2(9, 6)  ## Fußkollision (halbe Größe), fühlt sich natürlich an
const PLAYER_SPRITE := Vector2i(16, 24)

const CAMERA_ZOOM := 3.0
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
