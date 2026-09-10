class_name InputActions
extends RefCounted

## Vollständig freie Steuerung. Die Spiellogik fragt ausschliesslich Actions ab
## (`Input.is_action_pressed("move_up")`) — nirgendwo im Spiel steht noch eine
## feste Taste. WASD ist nur die Standardbelegung; jede Aktion darf beliebig
## viele Eingaben besitzen (Tasten UND Mausknöpfe), Konflikte werden erkannt
## und die persönliche Belegung überlebt jeden Neustart.

const CONFIG_PATH := "user://keybinds.cfg"

const CAT_CAMERA := "Kamera"
const CAT_WORLD := "Welt & Bauen"
const CAT_HOTBAR := "Schnellleiste"
const CAT_SIM := "Simulation"
const CAT_UI := "Oberfläche"

## Reihenfolge = Reihenfolge im Steuerungs-Menü.
const ACTIONS: Array[Dictionary] = [
	{"id": "move_up", "label": "Vorwärts", "cat": CAT_CAMERA, "keys": [KEY_W, KEY_UP]},
	{"id": "move_down", "label": "Rückwärts", "cat": CAT_CAMERA, "keys": [KEY_S, KEY_DOWN]},
	{"id": "move_left", "label": "Links", "cat": CAT_CAMERA, "keys": [KEY_A, KEY_LEFT]},
	{"id": "move_right", "label": "Rechts", "cat": CAT_CAMERA, "keys": [KEY_D, KEY_RIGHT]},
	{"id": "sprint", "label": "Schnell bewegen", "cat": CAT_CAMERA, "keys": [KEY_SHIFT]},
	{"id": "camera_drag", "label": "Kamera ziehen", "cat": CAT_CAMERA, "keys": [], "buttons": [MOUSE_BUTTON_MIDDLE]},
	{"id": "zoom_in", "label": "Heranzoomen", "cat": CAT_CAMERA, "keys": [KEY_KP_ADD], "buttons": [MOUSE_BUTTON_WHEEL_UP]},
	{"id": "zoom_out", "label": "Herauszoomen", "cat": CAT_CAMERA, "keys": [KEY_KP_SUBTRACT], "buttons": [MOUSE_BUTTON_WHEEL_DOWN]},

	{"id": "place_block", "label": "Setzen / Anwenden", "cat": CAT_WORLD, "keys": [], "buttons": [MOUSE_BUTTON_LEFT]},
	{"id": "remove_block", "label": "Entfernen", "cat": CAT_WORLD, "keys": [], "buttons": [MOUSE_BUTTON_RIGHT]},
	{"id": "brush_bigger", "label": "Pinsel grösser", "cat": CAT_WORLD, "keys": [KEY_EQUAL]},
	{"id": "brush_smaller", "label": "Pinsel kleiner", "cat": CAT_WORLD, "keys": [KEY_MINUS]},

	{"id": "hotbar_1", "label": "Slot 1", "cat": CAT_HOTBAR, "keys": [KEY_1]},
	{"id": "hotbar_2", "label": "Slot 2", "cat": CAT_HOTBAR, "keys": [KEY_2]},
	{"id": "hotbar_3", "label": "Slot 3", "cat": CAT_HOTBAR, "keys": [KEY_3]},
	{"id": "hotbar_4", "label": "Slot 4", "cat": CAT_HOTBAR, "keys": [KEY_4]},
	{"id": "hotbar_5", "label": "Slot 5", "cat": CAT_HOTBAR, "keys": [KEY_5]},
	{"id": "hotbar_6", "label": "Slot 6", "cat": CAT_HOTBAR, "keys": [KEY_6]},
	{"id": "hotbar_7", "label": "Slot 7", "cat": CAT_HOTBAR, "keys": [KEY_7]},
	{"id": "hotbar_8", "label": "Slot 8", "cat": CAT_HOTBAR, "keys": [KEY_8]},
	{"id": "hotbar_9", "label": "Slot 9", "cat": CAT_HOTBAR, "keys": [KEY_9]},
	{"id": "hotbar_10", "label": "Slot 10", "cat": CAT_HOTBAR, "keys": [KEY_0]},
	{"id": "hotbar_11", "label": "Slot 11", "cat": CAT_HOTBAR, "keys": [KEY_MASK_SHIFT | KEY_1]},

	{"id": "pause_sim", "label": "Simulation anhalten", "cat": CAT_SIM, "keys": [KEY_SPACE]},
	{"id": "speed_down", "label": "Langsamer", "cat": CAT_SIM, "keys": [KEY_PAGEDOWN]},
	{"id": "speed_up", "label": "Schneller", "cat": CAT_SIM, "keys": [KEY_PAGEUP]},

	{"id": "pause_menu", "label": "Menü / Zurück", "cat": CAT_UI, "keys": [KEY_ESCAPE]},
	{"id": "open_inventory", "label": "Inventar", "cat": CAT_UI, "keys": [KEY_I, KEY_TAB]},
	{"id": "toggle_debug", "label": "Entwickler-Overlay", "cat": CAT_UI, "keys": [KEY_F3]},
	{"id": "toggle_minimap", "label": "Minimap", "cat": CAT_UI, "keys": [KEY_M]},
	{"id": "toggle_chronicle", "label": "Chronik", "cat": CAT_UI, "keys": [KEY_C]},
	{"id": "toggle_hud", "label": "HUD ausblenden", "cat": CAT_UI, "keys": [KEY_F1]},
]

static var _installed := false


# --- Aufbau -----------------------------------------------------------------

## Registriert alle Actions in der InputMap und legt die gespeicherte
## Belegung darüber. Muss einmal vor dem ersten Frame laufen.
static func install() -> void:
	if _installed:
		return
	_installed = true
	reset_all(false)
	load_from_disk()


static func ids() -> Array[String]:
	var out: Array[String] = []
	for entry in ACTIONS:
		out.append(entry.id)
	return out


static func categories() -> Array[String]:
	var out: Array[String] = []
	for entry in ACTIONS:
		var cat: String = entry.cat
		if not out.has(cat):
			out.append(cat)
	return out


static func ids_in(category: String) -> Array[String]:
	var out: Array[String] = []
	for entry in ACTIONS:
		if entry.cat == category:
			out.append(entry.id)
	return out


static func label(action: String) -> String:
	for entry in ACTIONS:
		if entry.id == action:
			return entry.label
	return action


static func _entry(action: String) -> Dictionary:
	for entry in ACTIONS:
		if entry.id == action:
			return entry
	return {}


# --- Belegung lesen/ändern --------------------------------------------------

static func events_for(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		out.append(ev)
	return out


## Fügt eine Eingabe hinzu. Doppelte Eingaben derselben Aktion werden
## ignoriert; gibt false zurück, wenn nichts geändert wurde.
static func add_event(action: String, event: InputEvent) -> bool:
	if not InputMap.has_action(action) or event == null:
		return false
	for existing in InputMap.action_get_events(action):
		if same_event(existing, event):
			return false
	InputMap.action_add_event(action, event)
	return true


static func remove_event_at(action: String, index: int) -> void:
	var evs := events_for(action)
	if index < 0 or index >= evs.size():
		return
	InputMap.action_erase_event(action, evs[index])


static func replace_event_at(action: String, index: int, event: InputEvent) -> void:
	var evs := events_for(action)
	InputMap.action_erase_events(action)
	for i in evs.size():
		if i == index:
			if event != null:
				InputMap.action_add_event(action, event)
		else:
			InputMap.action_add_event(action, evs[i])
	if index >= evs.size() and event != null:
		InputMap.action_add_event(action, event)


static func reset_action(action: String) -> void:
	var entry := _entry(action)
	if entry.is_empty():
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for code in entry.get("keys", []):
		InputMap.action_add_event(action, make_key_event(code))
	for button in entry.get("buttons", []):
		InputMap.action_add_event(action, make_button_event(button))


static func reset_all(persist: bool = true) -> void:
	for entry in ACTIONS:
		reset_action(entry.id)
	if persist:
		save_to_disk()


## Andere Aktionen, die dieselbe Eingabe belegen — für die Konfliktanzeige.
static func conflicts(action: String, event: InputEvent) -> Array[String]:
	var out: Array[String] = []
	for entry in ACTIONS:
		if entry.id == action:
			continue
		for existing in InputMap.action_get_events(entry.id):
			if same_event(existing, event):
				out.append(entry.id)
				break
	return out


static func all_conflicts() -> Dictionary:
	var found := {}
	for entry in ACTIONS:
		for ev in InputMap.action_get_events(entry.id):
			var others := conflicts(entry.id, ev)
			if not others.is_empty():
				found[entry.id] = true
	return found


# --- Eingabe-Objekte --------------------------------------------------------

static func make_key_event(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code & KEY_CODE_MASK
	ev.shift_pressed = (code & KEY_MASK_SHIFT) != 0
	ev.ctrl_pressed = (code & KEY_MASK_CTRL) != 0
	ev.alt_pressed = (code & KEY_MASK_ALT) != 0
	return ev


static func make_button_event(button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button as MouseButton
	return ev


## Taugt das Ereignis überhaupt als Belegung? (Mausbewegung z. B. nicht.)
static func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and key.physical_keycode != 0
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


static func same_event(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		return ka.physical_keycode == kb.physical_keycode \
			and ka.shift_pressed == kb.shift_pressed \
			and ka.ctrl_pressed == kb.ctrl_pressed \
			and ka.alt_pressed == kb.alt_pressed
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	return false


## Godot liefert englische Tastennamen ("Up", "Equal"). Für das Menü werden
## die gebräuchlichen deutschen Bezeichnungen verwendet; alles andere fällt
## auf den Engine-Namen zurück.
const _KEY_NAMES := {
	KEY_UP: "Pfeil hoch",
	KEY_DOWN: "Pfeil runter",
	KEY_LEFT: "Pfeil links",
	KEY_RIGHT: "Pfeil rechts",
	KEY_SHIFT: "Umschalt",
	KEY_CTRL: "Strg",
	KEY_ALT: "Alt",
	KEY_META: "Meta",
	KEY_SPACE: "Leertaste",
	KEY_ESCAPE: "Esc",
	KEY_ENTER: "Enter",
	KEY_KP_ENTER: "Num Enter",
	KEY_TAB: "Tab",
	KEY_BACKSPACE: "Rücktaste",
	KEY_DELETE: "Entf",
	KEY_INSERT: "Einfg",
	KEY_HOME: "Pos 1",
	KEY_END: "Ende",
	KEY_PAGEUP: "Bild hoch",
	KEY_PAGEDOWN: "Bild runter",
	KEY_CAPSLOCK: "Feststell",
	KEY_EQUAL: "+",
	KEY_MINUS: "−",
	KEY_PERIOD: ".",
	KEY_COMMA: ",",
	KEY_SLASH: "/",
	KEY_BACKSLASH: "\\",
	KEY_SEMICOLON: ";",
	KEY_APOSTROPHE: "'",
	KEY_BRACKETLEFT: "[",
	KEY_BRACKETRIGHT: "]",
	KEY_QUOTELEFT: "^",
	KEY_KP_ADD: "Num +",
	KEY_KP_SUBTRACT: "Num −",
	KEY_KP_MULTIPLY: "Num ×",
	KEY_KP_DIVIDE: "Num ÷",
	KEY_KP_PERIOD: "Num .",
}

const _BUTTON_NAMES := {
	MOUSE_BUTTON_LEFT: "Maus links",
	MOUSE_BUTTON_RIGHT: "Maus rechts",
	MOUSE_BUTTON_MIDDLE: "Maus Mitte",
	MOUSE_BUTTON_WHEEL_UP: "Mausrad hoch",
	MOUSE_BUTTON_WHEEL_DOWN: "Mausrad runter",
	MOUSE_BUTTON_WHEEL_LEFT: "Mausrad links",
	MOUSE_BUTTON_WHEEL_RIGHT: "Mausrad rechts",
	MOUSE_BUTTON_XBUTTON1: "Maus 4",
	MOUSE_BUTTON_XBUTTON2: "Maus 5",
}


## Lesbarer Name einer Eingabe für das Steuerungs-Menü.
static func describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode
		# Der physische Code wird auf das aktuelle Tastaturlayout abgebildet,
		# damit auf einer deutschen Tastatur nicht "Y" steht, wo "Z" liegt.
		# Headless (Server, Tests) kennt kein Layout — dann der Rohcode.
		var display_code := code
		if DisplayServer.get_name() != "headless":
			var mapped := DisplayServer.keyboard_get_keycode_from_physical(code)
			if mapped != 0:
				display_code = mapped
		var name: String = _KEY_NAMES.get(display_code, "")
		if name.is_empty():
			name = OS.get_keycode_string(display_code)
		if name.is_empty():
			name = OS.get_keycode_string(code)
		var prefix := ""
		if key.ctrl_pressed:
			prefix += "Strg+"
		if key.alt_pressed:
			prefix += "Alt+"
		if key.shift_pressed:
			prefix += "Umschalt+"
		return prefix + name
	if event is InputEventMouseButton:
		var idx := (event as InputEventMouseButton).button_index
		return _BUTTON_NAMES.get(idx, "Maus %d" % idx)
	if event is InputEventJoypadButton:
		return "Gamepad %d" % (event as InputEventJoypadButton).button_index
	return "—"


## Kurzform der ersten Belegung, z. B. für Tooltips ("[W]").
static func hint(action: String) -> String:
	var evs := events_for(action)
	if evs.is_empty():
		return "—"
	return describe(evs[0])


# --- Speichern / Laden ------------------------------------------------------

static func _serialize(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var mods := 0
		if key.shift_pressed:
			mods |= 1
		if key.ctrl_pressed:
			mods |= 2
		if key.alt_pressed:
			mods |= 4
		return "key:%d:%d" % [key.physical_keycode, mods]
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "pad:%d" % (event as InputEventJoypadButton).button_index
	return ""


static func _deserialize(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() < 2:
		return null
	match parts[0]:
		"key":
			var ev := InputEventKey.new()
			ev.physical_keycode = int(parts[1]) as Key
			var mods := int(parts[2]) if parts.size() > 2 else 0
			ev.shift_pressed = (mods & 1) != 0
			ev.ctrl_pressed = (mods & 2) != 0
			ev.alt_pressed = (mods & 4) != 0
			return ev
		"mouse":
			var ev := InputEventMouseButton.new()
			ev.button_index = int(parts[1]) as MouseButton
			return ev
		"pad":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(parts[1]) as JoyButton
			return ev
	return null


static func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	for entry in ACTIONS:
		var serialized := PackedStringArray()
		for ev in events_for(entry.id):
			var text := _serialize(ev)
			if not text.is_empty():
				serialized.append(text)
		cfg.set_value("keybinds", entry.id, serialized)
	cfg.save(CONFIG_PATH)


static func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for entry in ACTIONS:
		if not cfg.has_section_key("keybinds", entry.id):
			continue
		var stored: PackedStringArray = cfg.get_value("keybinds", entry.id, PackedStringArray())
		InputMap.action_erase_events(entry.id)
		for text in stored:
			var ev := _deserialize(text)
			if ev != null:
				InputMap.action_add_event(entry.id, ev)
