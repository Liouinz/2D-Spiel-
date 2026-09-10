class_name KeybindPage
extends VBoxContainer

## Vollständige Steuerungsseite: ansehen, ändern, zusätzliche Taste hinzufügen,
## Taste entfernen, Standard wiederherstellen, speichern, verwerfen.
##
## Eine Aktion darf beliebig viele Eingaben haben (so funktionieren WASD *und*
## Pfeiltasten gleichzeitig). Doppelt belegte Eingaben werden rot markiert und
## im Tooltip benannt — verboten sind sie nicht, denn manchmal will man genau
## das.

signal changed

var _rows := {}
var _capture_action := ""
var _capture_index := -1
var _capture_button: Button
var _status: Label
var _dirty := false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	add_child(head)
	head.add_child(UiTheme.text_label(
		"Klick auf eine Belegung, dann die neue Taste drücken. Esc bricht ab.",
		UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	_status = UiTheme.text_label("", UiTheme.FONT_SMALL, Palette.UI_WARN)
	head.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for category in InputActions.categories():
		list.add_child(UiTheme.title_label(category, UiTheme.FONT_BASE))
		var grid := GridContainer.new()
		grid.columns = 2
		list.add_child(grid)
		for action in InputActions.ids_in(category):
			var label := UiTheme.text_label(InputActions.label(action))
			label.custom_minimum_size = Vector2(180, 0)
			grid.add_child(label)
			var row := HBoxContainer.new()
			grid.add_child(row)
			_rows[action] = row
		list.add_child(UiTheme.separator())

	var footer := HBoxContainer.new()
	add_child(footer)
	footer.add_child(UiTheme.button("Standard wiederherstellen", _reset_all,
		"Setzt alle Aktionen auf die Werksbelegung zurück."))
	footer.add_child(UiTheme.button("Änderungen verwerfen", _discard,
		"Lädt die zuletzt gespeicherte Belegung."))
	footer.add_child(UiTheme.button("Speichern", _save,
		"Speichert die Belegung dauerhaft (übersteht den Neustart)."))
	_rebuild_rows()


func _rebuild_rows() -> void:
	var conflicts := InputActions.all_conflicts()
	for action in _rows:
		var row: HBoxContainer = _rows[action]
		for child in row.get_children():
			child.queue_free()
		var events := InputActions.events_for(action)
		for i in events.size():
			row.add_child(_binding_button(action, i, events[i], conflicts.has(action)))
		var add := UiTheme.button("+", _start_capture.bind(action, events.size()),
			"Weitere Eingabe für „%s“ hinzufügen" % InputActions.label(action))
		add.custom_minimum_size = Vector2(26, 0)
		row.add_child(add)
		var reset := UiTheme.button("↺", _reset_one.bind(action),
			"Standardbelegung für „%s“ wiederherstellen" % InputActions.label(action))
		reset.custom_minimum_size = Vector2(26, 0)
		row.add_child(reset)
	_status.text = "Ungespeicherte Änderungen" if _dirty else ""


func _binding_button(action: String, index: int, event: InputEvent, has_conflict: bool) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var button := UiTheme.button(InputActions.describe(event), _start_capture.bind(action, index))
	button.custom_minimum_size = Vector2(112, 0)
	if has_conflict:
		var others := InputActions.conflicts(action, event)
		if not others.is_empty():
			button.add_theme_color_override("font_color", Palette.UI_BAD)
			var names: Array[String] = []
			for other in others:
				names.append(InputActions.label(other))
			button.tooltip_text = "Doppelt belegt mit: " + ", ".join(names)
	else:
		button.tooltip_text = "Klicken und neue Eingabe drücken"
	box.add_child(button)
	var remove := UiTheme.button("×", _remove.bind(action, index), "Diese Eingabe entfernen")
	remove.custom_minimum_size = Vector2(22, 0)
	remove.add_theme_color_override("font_color", Palette.UI_TEXT_DIM)
	box.add_child(remove)
	return box


func _start_capture(action: String, index: int) -> void:
	_capture_action = action
	_capture_index = index
	_status.text = "Eingabe für „%s“ drücken … (Esc bricht ab)" % InputActions.label(action)


func cancel_capture() -> void:
	_capture_action = ""
	_capture_index = -1
	_rebuild_rows()


func is_capturing() -> bool:
	return not _capture_action.is_empty()


## Während der Aufnahme frisst diese Seite jede Eingabe — sonst würde die
## gedrückte Taste zusätzlich noch ihre alte Aktion auslösen.
func _input(event: InputEvent) -> void:
	if _capture_action.is_empty() or not is_visible_in_tree():
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		if (event as InputEventKey).pressed:
			cancel_capture()
			get_viewport().set_input_as_handled()
		return
	if not InputActions.is_bindable(event):
		return
	get_viewport().set_input_as_handled()
	var stored := _to_binding(event)
	InputActions.replace_event_at(_capture_action, _capture_index, stored)
	_capture_action = ""
	_capture_index = -1
	_dirty = true
	_rebuild_rows()
	changed.emit()


## Nur die identifizierenden Anteile übernehmen — ein Tastendruck bringt sonst
## Position, Zeitstempel und Textinhalt mit in die Belegung.
func _to_binding(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode
		if code == 0:
			code = key.keycode
		var out := InputEventKey.new()
		out.physical_keycode = code
		out.shift_pressed = key.shift_pressed
		out.ctrl_pressed = key.ctrl_pressed
		out.alt_pressed = key.alt_pressed
		return out
	if event is InputEventMouseButton:
		return InputActions.make_button_event((event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		var pad := InputEventJoypadButton.new()
		pad.button_index = (event as InputEventJoypadButton).button_index
		return pad
	return null


func _remove(action: String, index: int) -> void:
	InputActions.remove_event_at(action, index)
	_dirty = true
	_rebuild_rows()
	changed.emit()


func _reset_one(action: String) -> void:
	InputActions.reset_action(action)
	_dirty = true
	_rebuild_rows()
	changed.emit()


func _reset_all() -> void:
	InputActions.reset_all(false)
	_dirty = true
	_rebuild_rows()
	changed.emit()


func _discard() -> void:
	InputActions.reset_all(false)
	InputActions.load_from_disk()
	_dirty = false
	_rebuild_rows()
	changed.emit()


func _save() -> void:
	InputActions.save_to_disk()
	_dirty = false
	_rebuild_rows()
