extends Node
## Einstiegspunkt und Spielzustands-Automat (§11: Game State getrennt vom Rest).

enum State { MENU, PLAYING, PAUSED, OPTIONS, INVENTORY }

const WorldScene := preload("res://src/world/world.gd")
const MainMenu := preload("res://src/ui/main_menu.gd")
const PauseMenu := preload("res://src/ui/pause_menu.gd")
const OptionsMenu := preload("res://src/ui/options_menu.gd")
const UiTheme := preload("res://src/ui/ui_theme.gd")

var state: State = State.MENU
var _return_state: State = State.MENU  ## wohin die Optionen zurückführen

var _world: Node2D = null
var _ui_layer: CanvasLayer
var _ui_root: Control
var _main_menu: Control
var _pause_menu: Control
var _options_menu: Control
var _loading: Label
var _busy := false          ## Welt wird gerade gebaut — zweiter Klick prallt ab

func _ready() -> void:
	Config.setup_input()
	Settings.apply()
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 10
	add_child(_ui_layer)

	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.theme = UiTheme.build()
	_ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer.add_child(_ui_root)

	_main_menu = MainMenu.new()
	_main_menu.play_pressed.connect(start_game)
	_main_menu.options_pressed.connect(open_options)
	_main_menu.quit_pressed.connect(quit_game)
	_ui_root.add_child(_main_menu)

	_pause_menu = PauseMenu.new()
	_pause_menu.resume_pressed.connect(resume_game)
	_pause_menu.options_pressed.connect(open_options)
	_pause_menu.menu_pressed.connect(to_main_menu)
	_pause_menu.visible = false
	_ui_root.add_child(_pause_menu)

	_options_menu = OptionsMenu.new()
	_options_menu.back_pressed.connect(close_options)
	_options_menu.visible = false
	_ui_root.add_child(_options_menu)

	_loading = _make_loading()
	_ui_root.add_child(_loading)

	_set_state(State.MENU)
	Audio.play_music("menu")

	if OS.get_cmdline_user_args().has("--selftest"):
		var test := preload("res://src/dev/self_test.gd").new()
		test.main = self
		add_child(test)

## ESC steuert Pause/Zurück. Läuft auch, während der Baum pausiert ist.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	match state:
		State.PLAYING:
			pause_game()
		State.PAUSED:
			resume_game()
		State.OPTIONS:
			close_options()
		State.INVENTORY:
			close_inventory()
	get_viewport().set_input_as_handled()

## E öffnet und schliesst das Inventar. Der Baum pausiert dabei, damit sich in
## Ruhe klicken lässt.
func toggle_inventory() -> void:
	if state == State.INVENTORY:
		close_inventory()
	elif state == State.PLAYING:
		open_inventory()

func open_inventory() -> void:
	if not is_instance_valid(_world) or not is_instance_valid(_world.inventory):
		return
	Audio.play_ui("open")
	_world.inventory.refresh()
	_set_state(State.INVENTORY)

func close_inventory() -> void:
	Audio.play_ui("close")
	_set_state(State.PLAYING)

# --- Zustandswechsel ---------------------------------------------------------

## Der Weltaufbau dauert einige hundert Millisekunden. Ohne Zwischenschritt
## friert das Fenster dabei ein und wirkt abgestürzt. Deshalb erst den Hinweis
## einblenden, zwei Bilder abwarten (eines setzt die Sichtbarkeit, das zweite
## zeichnet sie wirklich) und dann bauen.
func start_game() -> void:
	if _busy:
		return
	_busy = true
	Audio.play_ui("confirm")
	if is_instance_valid(_world):
		_world.queue_free()
		_world = null
	_main_menu.visible = false
	_loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame

	var t0 := Time.get_ticks_msec()
	_world = WorldScene.new()
	add_child(_world)
	print("[start] Welt bereit nach %d ms" % (Time.get_ticks_msec() - t0))

	_loading.visible = false
	_busy = false
	_set_state(State.PLAYING)
	Audio.play_music("world")

func _make_loading() -> Label:
	var l := Label.new()
	l.name = "Loading"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Palette.UI_TEXT)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.text = "Lädt …"
	l.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.09, 1.0)
	l.add_theme_stylebox_override("normal", bg)
	return l

func pause_game() -> void:
	if state != State.PLAYING:
		return
	Audio.play_ui("open")
	_set_state(State.PAUSED)

func resume_game() -> void:
	if state != State.PAUSED:
		return
	Audio.play_ui("close")
	_set_state(State.PLAYING)

func open_options() -> void:
	Audio.play_ui("open")
	_return_state = state
	_options_menu.refresh()
	_set_state(State.OPTIONS)

func close_options() -> void:
	Audio.play_ui("close")
	Settings.save_settings()
	_set_state(_return_state)

func to_main_menu() -> void:
	Audio.play_ui("close")
	_save_world()
	if is_instance_valid(_world):
		_world.queue_free()
		_world = null
	_set_state(State.MENU)
	Audio.play_music("menu")

func quit_game() -> void:
	Settings.save_settings()
	_save_world()
	get_tree().quit()

## Die im Aufbaumodus gebaute Karte darf beim Verlassen nicht verloren gehen.
func _save_world() -> void:
	if not Config.EMPTY_WORLD or not is_instance_valid(_world):
		return
	if _world.map != null:
		_world.map.save_user()

func _set_state(next: State) -> void:
	state = next
	var in_menu := next == State.MENU
	_main_menu.visible = in_menu and not _busy
	_pause_menu.visible = next == State.PAUSED
	_options_menu.visible = next == State.OPTIONS
	get_tree().paused = next != State.PLAYING
	if is_instance_valid(_world):
		_world.visible = next != State.MENU
		# HUD und Bau-Leiste liegen auf eigenen CanvasLayer und erben die
		# Sichtbarkeit der Welt nicht — sie werden einzeln geschaltet.
		if is_instance_valid(_world.hud):
			_world.hud.visible = next == State.PLAYING
		if is_instance_valid(_world.build_bar):
			_world.build_bar.visible = next == State.PLAYING or next == State.INVENTORY
		if is_instance_valid(_world.inventory):
			_world.inventory.visible = next == State.INVENTORY
	if in_menu:
		_main_menu.focus_first()
	elif next == State.PAUSED:
		_pause_menu.focus_first()
	elif next == State.OPTIONS:
		_options_menu.focus_first()
