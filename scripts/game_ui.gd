class_name GameUI
extends CanvasLayer

## Klammer um alle Oberflächen-Teile: HUD, Minimap, Chronik, Entwickler-Overlay,
## Einstellungen, Start- und Pausemenü. Hier laufen auch die UI-Actions
## zusammen — die Tasten dafür stehen frei im Steuerungs-Menü.

var main: Node

var hud: Hud
var minimap: Minimap
var dev_overlay: DevOverlay
var settings: SettingsWindow
var menus: Menus

var _theme: Theme
var _last_quality_notice := ""


func _init(main_ref: Node) -> void:
	main = main_ref
	layer = 10


func _ready() -> void:
	_theme = UiTheme.build()

	hud = Hud.new(main)
	hud.theme = _theme
	add_child(hud)
	hud.slot_selected.connect(main.select_slot)

	minimap = Minimap.new(main.terrain, main.sim, main.quality)
	minimap.theme = _theme
	minimap.camera = main.cam
	UiTheme.place(minimap, UiTheme.Place.BOTTOM_LEFT)
	hud.add_child(minimap)

	dev_overlay = DevOverlay.new(main.profiler, main.quality, main)
	dev_overlay.theme = _theme
	UiTheme.place(dev_overlay, UiTheme.Place.TOP_RIGHT)
	dev_overlay.hide()
	add_child(dev_overlay)

	settings = SettingsWindow.new(main.quality, self)
	settings.theme = _theme
	add_child(settings)
	settings.closed.connect(_on_settings_closed)

	menus = Menus.new()
	menus.theme = _theme
	add_child(menus)
	menus.start_pressed.connect(_on_start)
	menus.resume_pressed.connect(func(): set_paused(false))
	menus.settings_pressed.connect(func(): settings.open())
	menus.new_world_pressed.connect(_on_new_world)
	menus.quit_pressed.connect(func(): get_tree().quit())

	main.sim.chronicle.connect(hud.add_chronicle)
	main.quality.changed.connect(_on_quality_changed)
	hud.refresh_slot_keys()
	hud.select_slot(main.selected_slot)
	settings.keybinds.changed.connect(hud.refresh_slot_keys)
	# Startbildschirm: die Welt läuft im Hintergrund weiter, ist aber angehalten.
	main.sim.set_speed(0.0)


func _on_start() -> void:
	menus.close_start()
	main.sim.set_speed(1.0)


func _on_new_world() -> void:
	menus.close_start()
	menus.set_pause_visible(false)
	main.regenerate_world()
	main.sim.set_speed(1.0)
	hud.notify("Eine neue Welt ist entstanden.", Palette.UI_ACCENT)


func _on_settings_closed() -> void:
	hud.refresh_slot_keys()


## Meldet nur *echte* Wechsel. Jede Einstellung im Menü baut das Profil neu
## auf; ohne diesen Vergleich stapelten sich identische Einblendungen.
func _on_quality_changed() -> void:
	if hud == null or menus == null or menus.showing_start():
		return
	var text := "Grafikprofil: %s%s" % [
		main.quality.profile_name(),
		"" if main.quality.dynamic_step == 0 else " · Sparstufe %d" % main.quality.dynamic_step,
	]
	if text == _last_quality_notice:
		return
	_last_quality_notice = text
	hud.notify(text, Palette.UI_TEXT_DIM)


## Blockiert ein Overlay gerade die Welt? Main fragt das, bevor es Eingaben
## als Werkzeugklick auswertet.
func blocking_input() -> bool:
	return settings.visible or menus.blocking()


func set_paused(value: bool) -> void:
	menus.set_pause_visible(value)
	if value:
		main.sim.set_speed(0.0)
	else:
		settings.hide()
		main.sim.set_speed(1.0)


func toggle_pause_menu() -> void:
	if settings.visible:
		settings.hide()
		return
	if menus.showing_start():
		return
	set_paused(not menus.showing_pause())


func set_minimap_visible(value: bool) -> void:
	minimap.visible = value


func set_chronicle_visible(value: bool) -> void:
	hud.set_chronicle_visible(value)


func set_debug_visible(value: bool) -> void:
	dev_overlay.visible = value


func toggle_debug() -> void:
	dev_overlay.visible = not dev_overlay.visible


func toggle_minimap() -> void:
	minimap.visible = not minimap.visible


func toggle_chronicle() -> void:
	hud.set_chronicle_visible(not hud.chronicle_visible())


func toggle_hud() -> void:
	hud.visible = not hud.visible


func open_settings() -> void:
	settings.open()


func set_speed(value: float) -> void:
	main.sim.set_speed(value)


func notify(text: String, color: Color = Palette.UI_TEXT) -> void:
	hud.notify(text, color)


func select_slot(index: int) -> void:
	hud.select_slot(index)
