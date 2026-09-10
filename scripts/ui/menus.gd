class_name Menus
extends Control

## Startbildschirm und Pausemenü. Beide liegen als Overlay über der laufenden
## Welt — der Startbildschirm zeigt die Insel dadurch schon im Hintergrund,
## statt einen schwarzen Ladebildschirm zu präsentieren.

signal start_pressed
signal resume_pressed
signal settings_pressed
signal new_world_pressed
signal quit_pressed

var _start_screen: Control
var _pause_screen: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_screen = _build_start()
	add_child(_start_screen)
	_pause_screen = _build_pause()
	add_child(_pause_screen)
	_pause_screen.hide()


func showing_start() -> bool:
	return _start_screen.visible


func showing_pause() -> bool:
	return _pause_screen.visible


func blocking() -> bool:
	return _start_screen.visible or _pause_screen.visible


func close_start() -> void:
	_start_screen.hide()


func set_pause_visible(value: bool) -> void:
	_pause_screen.visible = value


func _shell(dim_alpha: float) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(340, 0)
	panel.add_child(box)
	return [root, box]


func _build_start() -> Control:
	var parts := _shell(0.62)
	var box: VBoxContainer = parts[1]
	box.add_child(UiTheme.title_label("TERRARIA MUNDI", 30))
	box.add_child(UiTheme.text_label(
		"Du bist keine Figur in dieser Welt — du bist die Welt.",
		UiTheme.FONT_BASE, Palette.UI_TEXT_DIM))
	box.add_child(UiTheme.separator())
	box.add_child(_menu_button("Welt betreten", func(): start_pressed.emit()))
	box.add_child(_menu_button("Neue Welt erschaffen", func(): new_world_pressed.emit()))
	box.add_child(_menu_button("Einstellungen", func(): settings_pressed.emit()))
	box.add_child(_menu_button("Beenden", func(): quit_pressed.emit()))
	box.add_child(UiTheme.separator())
	box.add_child(UiTheme.text_label(
		"Bewegen: %s %s %s %s  ·  Menü: %s  ·  Entwickler-Overlay: %s" % [
			InputActions.hint("move_up"), InputActions.hint("move_left"),
			InputActions.hint("move_down"), InputActions.hint("move_right"),
			InputActions.hint("pause_menu"), InputActions.hint("toggle_debug"),
		], UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	return parts[0]


func _build_pause() -> Control:
	var parts := _shell(0.45)
	var box: VBoxContainer = parts[1]
	box.add_child(UiTheme.title_label("PAUSE"))
	box.add_child(UiTheme.separator())
	box.add_child(_menu_button("Fortsetzen", func(): resume_pressed.emit()))
	box.add_child(_menu_button("Einstellungen", func(): settings_pressed.emit()))
	box.add_child(_menu_button("Neue Welt erschaffen", func(): new_world_pressed.emit()))
	box.add_child(_menu_button("Beenden", func(): quit_pressed.emit()))
	return parts[0]


func _menu_button(text: String, callback: Callable) -> Button:
	var b := UiTheme.button(text, callback)
	b.custom_minimum_size = Vector2(0, 34)
	return b
