extends Node
## Einstiegspunkt und Spielzustands-Automat (§11: Game State getrennt vom Rest).

enum State { MENU, PLAYING, PAUSED, OPTIONS }

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
	get_viewport().set_input_as_handled()

# --- Zustandswechsel ---------------------------------------------------------

func start_game() -> void:
	Audio.play_ui("confirm")
	if is_instance_valid(_world):
		_world.queue_free()
	_world = WorldScene.new()
	add_child(_world)
	_set_state(State.PLAYING)
	Audio.play_music("world")

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
	if is_instance_valid(_world):
		_world.queue_free()
		_world = null
	_set_state(State.MENU)
	Audio.play_music("menu")

func quit_game() -> void:
	Settings.save_settings()
	get_tree().quit()

func _set_state(next: State) -> void:
	state = next
	var in_menu := next == State.MENU
	_main_menu.visible = in_menu
	_pause_menu.visible = next == State.PAUSED
	_options_menu.visible = next == State.OPTIONS
	get_tree().paused = next != State.PLAYING
	if is_instance_valid(_world):
		_world.visible = next != State.MENU
		# Die HUD liegt auf einer CanvasLayer und erbt die Sichtbarkeit nicht.
		if is_instance_valid(_world.hud):
			_world.hud.visible = next == State.PLAYING
	if in_menu:
		_main_menu.focus_first()
	elif next == State.PAUSED:
		_pause_menu.focus_first()
	elif next == State.OPTIONS:
		_options_menu.focus_first()
