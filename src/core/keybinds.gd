class_name Keybinds
extends RefCounted
## Die Tastenbelegung: Standard, Änderungen, Konflikte und Speichern.
##
## ## Warum das eine eigene Datei ist
##
## Die Spiellogik fragt NIRGENDS eine Taste ab. Sie fragt eine Aktion:
## `Input.is_action_pressed("move_up")`. Welche Taste das auslöst, weiss nur
## die InputMap — und was in der InputMap steht, entscheidet allein diese
## Datei. Dadurch kann ein Spieler jede Aktion auf jede Taste legen, ohne dass
## an einer einzigen Stelle im Spiel etwas angepasst werden müsste.
##
## `W` `A` `S` `D` ist deshalb nicht „die Steuerung", sondern nur der
## Auslieferungszustand von `DEFAULT_KEYS`.
##
## ## Mehrere Eingaben je Aktion
##
## Eine Aktion hält eine LISTE von Ereignissen, nicht eines. So funktionieren
## WASD und die Pfeiltasten gleichzeitig — beide liegen auf denselben vier
## Aktionen. Genauso kann jemand eine dritte Taste dazulegen oder eine
## wegnehmen.
##
## ## Gespeichert wird die Belegung, nicht die Tastatur
##
## Abgelegt werden PHYSISCHE Tastencodes: die Taste an der Stelle, an der auf
## einer amerikanischen Tastatur `W` sitzt. Auf einer französischen Tastatur
## liegt dort `Z`, und genau die soll dann vorwärts laufen — sonst müsste jeder
## mit einer anders angeordneten Tastatur die Steuerung von Hand neu belegen.
## Angezeigt wird trotzdem der Buchstabe, der wirklich auf der Taste steht.

## Die Auslieferungsbelegung. Mehr steht hier nicht: kein Sonderfall, keine
## zweite Liste woanders.
const DEFAULT_KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"inventory": [KEY_E],
	"pause": [KEY_ESCAPE],
	"zoom_in": [KEY_EQUAL, KEY_KP_ADD],
	"zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
	"place_torch": [KEY_F],
	"toggle_grid": [KEY_G],
	"toggle_minimap": [KEY_M],
	"toggle_info": [KEY_H],
	"debug_info": [KEY_F3],
	"save_map": [KEY_F5],
	"build_slot_1": [KEY_1],
	"build_slot_2": [KEY_2],
	"build_slot_3": [KEY_3],
}

const DEFAULT_MOUSE := {
	"build_place": [MOUSE_BUTTON_LEFT],
	"build_remove": [MOUSE_BUTTON_RIGHT],
}

## Reihenfolge und Beschriftung im Steuerungsmenü. Was hier nicht steht, kann
## man auch nicht umbelegen — und alles, was hier steht, kann man wirklich.
const ACTIONS := [
	["move_up", "Vorwärts"],
	["move_down", "Rückwärts"],
	["move_left", "Links"],
	["move_right", "Rechts"],
	["run", "Rennen"],
	["jump", "Springen"],
	["build_place", "Block setzen"],
	["build_remove", "Block entfernen"],
	["place_torch", "Fackel setzen"],
	["build_slot_1", "Material 1"],
	["build_slot_2", "Material 2"],
	["build_slot_3", "Material 3"],
	["inventory", "Inventar"],
	["zoom_in", "Näher heran"],
	["zoom_out", "Weiter weg"],
	["toggle_grid", "Blockraster"],
	["toggle_minimap", "Minimap"],
	["toggle_info", "Anzeige oben links"],
	["debug_info", "Entwicklerinfo"],
	["save_map", "Karte speichern"],
	["pause", "Pause"],
]

const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Linke Maustaste",
	MOUSE_BUTTON_RIGHT: "Rechte Maustaste",
	MOUSE_BUTTON_MIDDLE: "Mausrad-Klick",
	MOUSE_BUTTON_WHEEL_UP: "Mausrad hoch",
	MOUSE_BUTTON_WHEEL_DOWN: "Mausrad runter",
	MOUSE_BUTTON_XBUTTON1: "Maus vor",
	MOUSE_BUTTON_XBUTTON2: "Maus zurück",
}

## Deutsche Namen für die Tasten, die keinen Buchstaben tragen.
##
## `OS.get_keycode_string()` liefert „Space", „Up", „Shift" — englisch, weil es
## Godots interne Namen sind. In einem deutschen Menü liest sich das wie eine
## Übersetzungslücke. Buchstaben und Ziffern kommen weiter von der Engine: die
## heissen überall gleich, und sie hängen an der Tastatur des Spielers.
const KEY_NAMES := {
	KEY_SPACE: "Leertaste",
	KEY_ESCAPE: "Esc",
	KEY_SHIFT: "Umschalt",
	KEY_CTRL: "Strg",
	KEY_ALT: "Alt",
	KEY_TAB: "Tabulator",
	KEY_ENTER: "Eingabe",
	KEY_KP_ENTER: "Eingabe (Ziffernblock)",
	KEY_BACKSPACE: "Rücktaste",
	KEY_DELETE: "Entf",
	KEY_INSERT: "Einfg",
	KEY_HOME: "Pos 1",
	KEY_END: "Ende",
	KEY_PAGEUP: "Bild hoch",
	KEY_PAGEDOWN: "Bild runter",
	KEY_UP: "Pfeil hoch",
	KEY_DOWN: "Pfeil runter",
	KEY_LEFT: "Pfeil links",
	KEY_RIGHT: "Pfeil rechts",
	KEY_KP_ADD: "Plus (Ziffernblock)",
	KEY_KP_SUBTRACT: "Minus (Ziffernblock)",
	KEY_EQUAL: "Plus",
	KEY_MINUS: "Minus",
	KEY_CAPSLOCK: "Feststell",
}

## Wie viele Eingaben eine Aktion höchstens tragen darf. Drei reichen für
## „Taste, zweite Taste, Maus"; eine Zeile mit acht Einträgen wäre unlesbar.
const MAX_PER_ACTION := 3

# --- Anlegen und Anwenden -----------------------------------------------------

## Legt alle Aktionen an und belegt sie — aus den gespeicherten Werten, sonst
## aus dem Standard. Wird einmal beim Start gerufen.
static func setup() -> void:
	for action: String in _all_actions():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var saved: Dictionary = Settings.keybinds
	for action: String in _all_actions():
		var list: Array = saved.get(action, [])
		# Nicht nur „leer", sondern „nichts Brauchbares darin": eine
		# beschaedigte Datei kann eine Liste enthalten, aus der `_parse` nichts
		# gewinnt — dann stand die Aktion auf null Ereignissen und war ohne
		# „alles zuruecksetzen" nicht mehr erreichbar.
		var events := _parse(list) if not list.is_empty() else []
		_set_events(action, events if not events.is_empty() \
			else _default_events(action))

## Setzt alles auf den Auslieferungszustand zurück.
static func reset_all() -> void:
	for action: String in _all_actions():
		_set_events(action, _default_events(action))
	store()

## Schreibt die geltende Belegung nach `Settings`. Gespeichert wird sie dort.
static func store() -> void:
	var out := {}
	for action: String in _all_actions():
		out[action] = _serialize(InputMap.action_get_events(action))
	Settings.keybinds = out

# --- Ändern -------------------------------------------------------------------

## Die Eingaben einer Aktion, in der Reihenfolge, in der sie angelegt wurden.
static func events_of(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return out
	for ev: InputEvent in InputMap.action_get_events(action):
		if _usable(ev):
			out.append(ev)
	return out

## Legt eine weitere Eingabe auf eine Aktion. Gibt "" zurück, wenn es geklappt
## hat, sonst den Grund.
static func add(action: String, ev: InputEvent) -> String:
	if not _usable(ev):
		return "Diese Eingabe lässt sich nicht belegen."
	if events_of(action).size() >= MAX_PER_ACTION:
		return "Mehr als %d Eingaben je Aktion gehen nicht." % MAX_PER_ACTION
	for existing: InputEvent in events_of(action):
		if same(existing, ev):
			return "Diese Eingabe liegt hier schon."
	var clash := conflict(action, ev)
	if clash != "":
		return "Belegt durch „%s“." % label_of(clash)
	InputMap.action_add_event(action, ev)
	store()
	return ""

## Ersetzt die Eingabe an dieser Stelle. Gleiche Rückgabe wie `add`.
static func replace(action: String, index: int, ev: InputEvent) -> String:
	if not _usable(ev):
		return "Diese Eingabe lässt sich nicht belegen."
	var clash := conflict(action, ev)
	if clash != "" and clash != action:
		return "Belegt durch „%s“." % label_of(clash)
	var list := events_of(action)
	if index < 0 or index >= list.size():
		return "Diese Stelle gibt es nicht."
	# Dieselbe Pruefung wie in `add`: sonst kann dieselbe Taste zweimal in
	# derselben Aktion stehen. `conflict` faengt das nicht, weil es die eigene
	# Aktion absichtlich ueberspringt.
	for i in list.size():
		if i != index and same(list[i], ev):
			return "Diese Eingabe liegt hier schon."
	list[index] = ev
	_set_events(action, list)
	store()
	return ""

## Nimmt eine Eingabe weg. Die letzte bleibt stehen: eine Aktion ganz ohne
## Eingabe wäre unerreichbar, und man sähe im Menü nicht, dass sie es ist.
static func remove_at(action: String, index: int) -> String:
	var list := events_of(action)
	if list.size() <= 1:
		return "Die letzte Eingabe kann nicht weg — sonst wäre die Aktion nicht mehr erreichbar."
	if index < 0 or index >= list.size():
		return "Diese Stelle gibt es nicht."
	list.remove_at(index)
	_set_events(action, list)
	store()
	return ""

## Welche ANDERE Aktion diese Eingabe schon benutzt — oder "".
##
## Geprüft wird gegen alle belegbaren Aktionen, nicht nur gegen die eigene
## Gruppe: eine Taste, die gleichzeitig springt und das Inventar öffnet, tut
## beides, und das merkt man erst im Spiel.
static func conflict(action: String, ev: InputEvent) -> String:
	for entry: Array in ACTIONS:
		var other: String = entry[0]
		if other == action:
			continue
		for e: InputEvent in events_of(other):
			if same(e, ev):
				return other
	return ""

## Sind das dieselbe Taste beziehungsweise dieselbe Maustaste?
static func same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _code(a as InputEventKey) == _code(b as InputEventKey)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index \
			== (b as InputEventMouseButton).button_index
	return false

# --- Beschriften --------------------------------------------------------------

## Der Name einer Eingabe, wie er auf der Taste steht.
##
## Gespeichert wird die Taste nach ihrer LAGE (physischer Code), angezeigt wird
## der Buchstabe, der auf der Tastatur des Spielers wirklich daraufsteht. Auf
## einer deutschen Tastatur heisst dieselbe Lage `Z`, auf einer amerikanischen
## `Y` — beide Male ist es die richtige Beschriftung.
static func describe(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code := _code(ev as InputEventKey)
		if KEY_NAMES.has(code):
			return KEY_NAMES[code]
		var shown := DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(shown if shown != 0 else code)
	if ev is InputEventMouseButton:
		return MOUSE_NAMES.get((ev as InputEventMouseButton).button_index, "Maustaste")
	return "?"

## Alle Eingaben einer Aktion als eine Zeile — für die Übersicht.
static func describe_action(action: String) -> String:
	if action.contains("+"):
		var parts: Array[String] = []
		for one: String in action.split("+"):
			var k := describe_action(one)
			parts.append(k.split(" / ")[0])
		return " ".join(parts)
	var names: Array[String] = []
	for ev: InputEvent in events_of(action):
		names.append(describe(ev))
	return " / ".join(names) if not names.is_empty() else "—"

## Die Beschriftung einer Aktion aus ACTIONS.
static func label_of(action: String) -> String:
	for entry: Array in ACTIONS:
		if entry[0] == action:
			return entry[1]
	return action

# --- Innereien ----------------------------------------------------------------

static func _all_actions() -> Array[String]:
	var out: Array[String] = []
	for entry: Array in ACTIONS:
		out.append(entry[0])
	return out

## Nur Tasten und Maustasten. Mausbewegung, Achsen und Ähnliches wären als
## Belegung sinnlos und würden beim Aufnehmen sofort zuschnappen.
static func _usable(ev: InputEvent) -> bool:
	if ev is InputEventKey:
		return _code(ev as InputEventKey) != 0
	return ev is InputEventMouseButton

static func _code(k: InputEventKey) -> int:
	return k.physical_keycode if k.physical_keycode != 0 else k.keycode

static func _set_events(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for ev: InputEvent in events:
		InputMap.action_add_event(action, ev)

static func _default_events(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for key: int in DEFAULT_KEYS.get(action, []):
		var k := InputEventKey.new()
		k.physical_keycode = key
		out.append(k)
	for button: int in DEFAULT_MOUSE.get(action, []):
		var m := InputEventMouseButton.new()
		m.button_index = button
		out.append(m)
	return out

## Ablageform: „taste:87" oder „maus:1". Absichtlich lesbar — wer in seine
## settings.cfg schaut, soll sehen, was dort steht.
static func _serialize(events: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for ev: InputEvent in events:
		if ev is InputEventKey:
			out.append("taste:%d" % _code(ev as InputEventKey))
		elif ev is InputEventMouseButton:
			out.append("maus:%d" % (ev as InputEventMouseButton).button_index)
	return out

static func _parse(list: Array) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for s in list:
		var text := String(s)
		var parts := text.split(":")
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		if parts[0] == "taste":
			var k := InputEventKey.new()
			k.physical_keycode = int(parts[1])
			out.append(k)
		elif parts[0] == "maus":
			var m := InputEventMouseButton.new()
			m.button_index = int(parts[1])
			out.append(m)
	return out
