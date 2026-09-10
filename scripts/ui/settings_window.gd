class_name SettingsWindow
extends Control

## Einstellungen in drei Reitern: Grafik, Steuerung, Spiel.
## Liegt als Overlay über der Welt und schluckt Eingaben, damit hinter dem
## Fenster nicht weitergemalt wird.

signal closed

var quality: Quality
var game_ui: Node
var keybinds: KeybindPage

var _tabs: TabContainer
var _profile_option: OptionButton
var _scale_label: Label


func _init(quality_ref: Quality, game_ui_ref: Node) -> void:
	quality = quality_ref
	game_ui = game_ui_ref


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	header.add_child(UiTheme.title_label("EINSTELLUNGEN"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(UiTheme.button("Schliessen", _close))
	box.add_child(UiTheme.separator())

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(620, 400)
	box.add_child(_tabs)
	_tabs.add_child(_build_graphics())
	keybinds = KeybindPage.new()
	keybinds.name = "Steuerung"
	_tabs.add_child(keybinds)
	_tabs.add_child(_build_game())
	hide()


func _close() -> void:
	if keybinds != null and keybinds.is_capturing():
		keybinds.cancel_capture()
	hide()
	closed.emit()


func open() -> void:
	show()
	_sync_graphics()


# --- Grafik -----------------------------------------------------------------

func _build_graphics() -> Control:
	var page := VBoxContainer.new()
	page.name = "Grafik"
	page.add_theme_constant_override("separation", 10)

	var row := HBoxContainer.new()
	page.add_child(row)
	row.add_child(UiTheme.text_label("Grafikprofil"))
	_profile_option = OptionButton.new()
	_profile_option.focus_mode = Control.FOCUS_NONE
	_profile_option.add_item("Automatisch (nach Hardware)", 0)
	_profile_option.add_item("HOCH", 1)
	_profile_option.add_item("MITTEL", 2)
	_profile_option.add_item("NIEDRIG", 3)
	_profile_option.item_selected.connect(_on_profile_selected)
	row.add_child(_profile_option)

	page.add_child(UiTheme.checkbox(
		"Dynamische Qualität (senkt bei FPS-Einbruch gezielt einzelne Effekte)",
		quality.dynamic_enabled, func(v: bool): quality.set_dynamic_enabled(v),
		"Fällt die Bildrate länger unter 60, werden nacheinander Funken,\nWolken, Lichtauflösung und zuletzt die Renderauflösung reduziert."))

	page.add_child(UiTheme.separator())
	page.add_child(UiTheme.text_label("Einzelne Effekte (überschreiben das Profil)", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	page.add_child(_override_check("Wasser animieren", "water_animation",
		"Bewegte Wasseroberfläche über einen Shader auf den Wasser-Ebenen."))
	page.add_child(_override_check("Wellenringe im Wasser", "water_ripples",
		"Wellen, wenn Siedler waten, Regen fällt oder etwas einschlägt."))
	page.add_child(_override_check("Schatten unter Einheiten", "entity_shadows"))

	var scale_row := HBoxContainer.new()
	page.add_child(scale_row)
	scale_row.add_child(UiTheme.text_label("Render Scale"))
	var slider := HSlider.new()
	slider.min_value = 60
	slider.max_value = 100
	slider.step = 5
	slider.value = int(round(quality.render_scale() * 100.0))
	slider.custom_minimum_size = Vector2(200, 0)
	slider.value_changed.connect(_on_scale_changed)
	scale_row.add_child(slider)
	_scale_label = UiTheme.text_label("%d %%" % int(slider.value))
	scale_row.add_child(_scale_label)

	page.add_child(UiTheme.separator())
	var hardware := VBoxContainer.new()
	page.add_child(hardware)
	hardware.add_child(UiTheme.text_label("Erkannte Hardware", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	for line in quality.hardware_lines():
		hardware.add_child(UiTheme.text_label(line, UiTheme.FONT_SMALL))
	return page


func _override_check(text: String, key: String, tooltip: String = "") -> CheckBox:
	var value: bool = bool(quality.get_value(key, true))
	return UiTheme.checkbox(text, value, func(v: bool): quality.set_override(key, v), tooltip)


func _on_profile_selected(index: int) -> void:
	match index:
		0: quality.auto_select()
		1: quality.set_profile(Quality.Profile.HIGH, true)
		2: quality.set_profile(Quality.Profile.MEDIUM, true)
		3: quality.set_profile(Quality.Profile.LOW, true)


func _on_scale_changed(value: float) -> void:
	quality.set_override("render_scale", value / 100.0)
	_scale_label.text = "%d %%" % int(value)


const _PROFILE_ITEMS := {
	Quality.Profile.HIGH: 1,
	Quality.Profile.MEDIUM: 2,
	Quality.Profile.LOW: 3,
}


func _sync_graphics() -> void:
	_profile_option.select(0 if quality.auto_profile else _PROFILE_ITEMS[quality.profile])


# --- Spiel ------------------------------------------------------------------

func _build_game() -> Control:
	var page := VBoxContainer.new()
	page.name = "Spiel"
	page.add_theme_constant_override("separation", 10)
	page.add_child(UiTheme.text_label("Anzeige", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	page.add_child(UiTheme.checkbox("Minimap anzeigen", true,
		func(v: bool): game_ui.set_minimap_visible(v)))
	page.add_child(UiTheme.checkbox("Chronik anzeigen", true,
		func(v: bool): game_ui.set_chronicle_visible(v)))
	page.add_child(UiTheme.checkbox("Entwickler-Overlay anzeigen", false,
		func(v: bool): game_ui.set_debug_visible(v),
		"Zeigt gemessene Leistungs- und Weltdaten. Standardtaste: F3."))
	page.add_child(UiTheme.separator())
	page.add_child(UiTheme.text_label("Simulationstempo", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	var speeds := HBoxContainer.new()
	page.add_child(speeds)
	for entry in [["Pause", 0.0], ["1×", 1.0], ["3×", 3.0], ["10×", 10.0]]:
		speeds.add_child(UiTheme.button(entry[0], func(): game_ui.set_speed(entry[1])))
	return page
