extends Node
## Einstiegspunkt und Spielzustands-Automat (§11: Game State getrennt vom Rest).

## Ein Zustand zur Zeit. CONFIRM liegt über dem Hauptmenü: das bleibt sichtbar,
## nimmt aber keine Eingaben mehr an.
enum State { MENU, PLAYING, PAUSED, OPTIONS, INVENTORY, CONFIRM }

const MainMenu := preload("res://src/ui/main_menu.gd")
const PauseMenu := preload("res://src/ui/pause_menu.gd")
const OptionsMenu := preload("res://src/ui/options_menu.gd")
const ConfirmDialog := preload("res://src/ui/confirm_dialog.gd")

var state: State = State.MENU
var _return_state: State = State.MENU  ## wohin die Optionen zurückführen

var _world: Node2D = null
var _ui_layer: CanvasLayer
var _ui_root: Control
var _main_menu: UiScreen
var _pause_menu: UiScreen
var _options_menu: UiScreen
var _confirm: UiScreen
var _loading: Label
var _busy := false          ## Welt wird gerade gebaut — zweiter Klick prallt ab

func _ready() -> void:
	Config.setup_input()
	process_mode = Node.PROCESS_MODE_ALWAYS


	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 10
	add_child(_ui_layer)

	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	UiTheme.attach(_ui_root)
	_ui_layer.add_child(_ui_root)

	_main_menu = MainMenu.new()
	_main_menu.continue_pressed.connect(func() -> void: start_game(false))
	_main_menu.new_world_pressed.connect(ask_new_world)
	_main_menu.options_pressed.connect(open_options)
	_main_menu.quit_pressed.connect(quit_game)
	_ui_root.add_child(_main_menu)

	_pause_menu = PauseMenu.new()
	_pause_menu.resume_pressed.connect(resume_game)
	_pause_menu.options_pressed.connect(open_options)
	_pause_menu.menu_pressed.connect(to_main_menu)
	_ui_root.add_child(_pause_menu)

	_options_menu = OptionsMenu.new()
	_options_menu.back_pressed.connect(close_options)
	_ui_root.add_child(_options_menu)

	_confirm = ConfirmDialog.new()
	_confirm.setup("NEUE WELT",
		"Es gibt bereits eine gebaute Karte. Eine neue Welt überschreibt sie, "
		+ "sobald das nächste Mal gespeichert wird.", "NEUE WELT ANFANGEN")
	_confirm.confirmed.connect(func() -> void: start_game(true))
	_confirm.cancelled.connect(func() -> void: _set_state(State.MENU))
	_ui_root.add_child(_confirm)

	_loading = _make_loading()
	_ui_root.add_child(_loading)

	_set_state(State.MENU)
	Audio.play_music("menu")

	if OS.get_cmdline_user_args().has("--selftest"):
		var test := preload("res://src/dev/self_test.gd").new()
		test.main = self
		add_child(test)
	elif OS.get_cmdline_user_args().has("--profile"):
		var prof := preload("res://src/dev/profiler.gd").new()
		prof.main = self
		add_child(prof)

## ESC und E. Läuft auch, während der Baum pausiert ist.
##
## Das Inventar MUSS hier liegen, nicht im Bauwerkzeug. Die Welt ist
## pausierbar, damit bei offenem Fenster nichts mehr in ihr passiert — dadurch
## bekommt das Bauwerkzeug bei offenem Inventar aber gar keine Eingaben mehr
## und konnte es nie wieder schliessen. E öffnete, E schloss nicht. Main läuft
## als einziger Knoten immer, hier gehört der Umschalter hin.
func _unhandled_input(event: InputEvent) -> void:
	# Verbraucht wird ein Tastendruck nur, wenn er hier auch wirklich etwas
	# bewirkt hat. Vorher schluckte E die Taste in jedem Zustand — auch im
	# Hauptmenü, wo sie nichts zu suchen hatte.
	if event.is_action_pressed("inventory"):
		if toggle_inventory():
			get_viewport().set_input_as_handled()
		return
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
		State.CONFIRM:
			_set_state(State.MENU)
		_:
			return
	get_viewport().set_input_as_handled()

## E öffnet und schliesst das Inventar. Der Baum pausiert dabei, damit sich in
## Ruhe klicken lässt.
##
## Gibt zurück, ob der Zustand tatsächlich gewechselt hat. Nur dann gilt die
## Taste als verbraucht.
func toggle_inventory() -> bool:
	if state == State.INVENTORY:
		return close_inventory()
	if state == State.PLAYING:
		return open_inventory()
	return false

## Beide Wege prüfen den Zustand, bevor sie ihn setzen. Dadurch kann das
## Inventar nicht doppelt geöffnet oder doppelt geschlossen werden, egal ob
## der Anstoss von der Taste, von ESC oder aus dem Selbsttest kommt.
func open_inventory() -> bool:
	if state != State.PLAYING:
		return false
	if not is_instance_valid(_world) or not is_instance_valid(_world.inventory):
		return false
	_set_state(State.INVENTORY)
	return true

func close_inventory() -> bool:
	if state != State.INVENTORY:
		return false
	_set_state(State.PLAYING)
	return true

# --- Zustandswechsel ---------------------------------------------------------

## Der Weltaufbau dauert einige hundert Millisekunden. Ohne Zwischenschritt
## friert das Fenster dabei ein und wirkt abgestürzt. Deshalb erst den Hinweis
## einblenden, zwei Bilder abwarten (eines setzt die Sichtbarkeit, das zweite
## zeichnet sie wirklich) und dann bauen.
## „Neue Welt" fragt nach, wenn dabei eine gebaute Karte verloren ginge.
func ask_new_world() -> void:
	if MapData.has_save():
		_set_state(State.CONFIRM)
	else:
		start_game(true)

func start_game(fresh: bool = false) -> void:
	if _busy:
		return
	_busy = true
	if is_instance_valid(_world):
		_world.queue_free()
		_world = null
	_main_menu.set_open(false)
	_confirm.set_open(false)
	_loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame

	var t0 := Time.get_ticks_msec()
	_world = World.new()
	_world.fresh = fresh
	add_child(_world)
	print("[start] Welt bereit nach %d ms" % (Time.get_ticks_msec() - t0))

	_loading.visible = false
	_busy = false
	_set_state(State.PLAYING)
	Audio.play_music("world")
	# Erst ab hier darf die Automatik nachregeln. Im Menü ist das Bild ohnehin
	# billig; dort würde sie fröhlich hochregeln, was in der Welt gleich wieder
	# klemmt.
	Graphics.in_world = true

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
	_set_state(State.PAUSED)

func resume_game() -> void:
	if state != State.PAUSED:
		return
	_set_state(State.PLAYING)

func open_options() -> void:
	_return_state = state
	_options_menu.refresh()
	_set_state(State.OPTIONS)

func close_options() -> void:
	Settings.save_settings()
	_set_state(_return_state)

func to_main_menu() -> void:
	Graphics.in_world = false
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
	if not is_instance_valid(_world):
		return
	if _world.map != null:
		_world.map.save_user()

func _set_state(next: State) -> void:
	state = next
	# CONFIRM liegt ÜBER dem Hauptmenü — das bleibt stehen, sonst sähe die
	# Rückfrage aus, als käme sie aus dem Nichts.
	var in_menu := next == State.MENU or next == State.CONFIRM
	if in_menu:
		_main_menu.refresh()
	_main_menu.set_open(in_menu and not _busy)
	_pause_menu.set_open(next == State.PAUSED)
	_options_menu.set_open(next == State.OPTIONS)
	_confirm.set_open(next == State.CONFIRM)
	get_tree().paused = next != State.PLAYING
	if is_instance_valid(_world):
		_world.visible = next != State.MENU
		# HUD und Bau-Leiste liegen auf eigenen CanvasLayer und erben die
		# Sichtbarkeit der Welt nicht — sie werden einzeln geschaltet.
		if is_instance_valid(_world.hud):
			_world.hud.visible = next == State.PLAYING
		# Die Leiste ist nur im Spiel zu sehen. Bei offenem Inventar zeigt das
		# Inventar sie selbst — zweimal dieselbe Leiste auf einem Bild wäre
		# genau die Doppelung, die es hier nicht mehr geben soll.
		if is_instance_valid(_world.build_bar):
			_world.build_bar.visible = next == State.PLAYING
		# Ein Weg auf, ein Weg zu: das Inventar schaltet sich selbst und
		# blendet sich dabei weich ein.
		if is_instance_valid(_world.inventory):
			_world.inventory.set_open(next == State.INVENTORY)
		# Die Bauvorschau hier löschen, nicht im Bauwerkzeug: das läuft bei
		# pausiertem Baum zu Recht nicht mehr und käme gar nicht mehr dazu.
		# Sonst bliebe der Zeigerkasten während des Menüs stehen.
		if is_instance_valid(_world.grid) and next != State.PLAYING:
			_world.grid.cursor_block = Vector2i(-1, -1)
			_world.grid.queue_redraw()
	match next:
		State.MENU:
			_main_menu.focus_first()
		State.CONFIRM:
			_confirm.focus_first()
		State.PAUSED:
			_pause_menu.focus_first()
		State.OPTIONS:
			_options_menu.focus_first()
