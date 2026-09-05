extends Control
## Pause-Menü: FORTSETZEN / OPTIONEN / ZUM HAUPTMENÜ.

signal resume_pressed
signal options_pressed
signal menu_pressed

var _first: Button

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.08, 0.62)
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
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	col.add_child(UiTheme.title("PAUSE", 40))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 8)
	col.add_child(sep)

	_first = UiTheme.button("SPIEL FORTSETZEN")
	_first.pressed.connect(func() -> void: resume_pressed.emit())
	col.add_child(_first)
	var b_opt := UiTheme.button("OPTIONEN")
	b_opt.pressed.connect(func() -> void: options_pressed.emit())
	col.add_child(b_opt)
	var b_menu := UiTheme.button("ZUM HAUPTMENÜ")
	b_menu.pressed.connect(func() -> void: menu_pressed.emit())
	col.add_child(b_menu)
	for b: Button in [_first, b_opt, b_menu]:
		b.mouse_entered.connect(func() -> void: Audio.play_ui("blip"))

	col.add_child(UiTheme.text_label("ESC schließt die Pause wieder", 15))

func focus_first() -> void:
	if is_instance_valid(_first):
		_first.grab_focus()
