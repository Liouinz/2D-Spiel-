extends Control
## Optionen: Musiklautstärke, Vollbild, Hinweise — plus Steuerungsübersicht.

signal back_pressed

var _music: HSlider
var _fullscreen: CheckBox
var _hints: CheckBox
var _perf: CheckBox
var _back: Button

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.70)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	col.add_child(UiTheme.title("OPTIONEN", 40))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)

	_music = _add_slider(grid, "Musik")

	grid.add_child(_label("Vollbild"))
	_fullscreen = CheckBox.new()
	_fullscreen.toggled.connect(_on_fullscreen)
	grid.add_child(_fullscreen)

	grid.add_child(_label("Hinweise anzeigen"))
	_hints = CheckBox.new()
	_hints.toggled.connect(func(v: bool) -> void: Settings.show_hints = v)
	grid.add_child(_hints)

	grid.add_child(_label("Leistungsanzeige"))
	_perf = CheckBox.new()
	_perf.toggled.connect(func(v: bool) -> void:
		Settings.show_perf = v
		Settings.changed.emit())
	grid.add_child(_perf)

	col.add_child(_controls_section())

	_back = UiTheme.button("ZURÜCK")
	_back.pressed.connect(func() -> void: back_pressed.emit())
	col.add_child(_back)

	refresh()

## Steuerungsübersicht.
##
## Die Tasten kommen aus der InputMap, nicht aus einer Liste im Code. Ändert
## sich eine Belegung, ändert sich diese Anzeige mit — hier kann also nie eine
## veraltete oder erfundene Taste stehen.
func _controls_section() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(UiTheme.title("STEUERUNG", 22))

	var rows := GridContainer.new()
	rows.columns = 2
	rows.add_theme_constant_override("h_separation", 22)
	rows.add_theme_constant_override("v_separation", 3)
	for entry: Array in Config.CONTROL_ROWS:
		var keys := _label(Config.keys_for(entry[0]))
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		keys.custom_minimum_size = Vector2(210, 0)
		keys.add_theme_font_size_override("font_size", 15)
		rows.add_child(keys)
		var what := _label(entry[1])
		what.add_theme_font_size_override("font_size", 15)
		rows.add_child(what)
	box.add_child(rows)
	return box

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Palette.UI_TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _add_slider(grid: GridContainer, text: String) -> HSlider:
	grid.add_child(_label(text))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(240, 24)
	grid.add_child(s)
	return s

func _on_fullscreen(v: bool) -> void:
	Settings.fullscreen = v
	Settings.apply()

func refresh() -> void:
	_music.set_value_no_signal(Settings.music_volume)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_hints.set_pressed_no_signal(Settings.show_hints)
	_perf.set_pressed_no_signal(Settings.show_perf)
	if not _music.value_changed.is_connected(_on_music):
		_music.value_changed.connect(_on_music)

func _on_music(v: float) -> void:
	Settings.set_music_volume(v)

func focus_first() -> void:
	if is_instance_valid(_back):
		_back.grab_focus()
