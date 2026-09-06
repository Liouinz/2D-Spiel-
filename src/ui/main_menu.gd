extends Control
## Startmenü: SPIELEN / OPTIONEN / BEENDEN.

signal play_pressed
signal options_pressed
signal quit_pressed

var _first: Button

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = MenuArt.title_background()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	add_child(preload("res://src/ui/cloud_layer.gd").new())

	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.07, 0.10, 0.30)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	box.add_child(UiTheme.title("TALHAIN"))
	box.add_child(UiTheme.rule())
	box.add_child(UiTheme.text_label("Bauen in einer offenen Welt aus Gras, Sand und Wasser", 18))
	box.add_child(_spacer(30))

	var col_center := CenterContainer.new()
	col_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col_center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col_center.add_child(col)

	_first = UiTheme.button("SPIELEN")
	_first.pressed.connect(func() -> void: play_pressed.emit())
	col.add_child(_first)
	var b_opt := UiTheme.button("OPTIONEN")
	b_opt.pressed.connect(func() -> void: options_pressed.emit())
	col.add_child(b_opt)
	var b_quit := UiTheme.button("BEENDEN")
	b_quit.pressed.connect(func() -> void: quit_pressed.emit())
	col.add_child(b_quit)
	box.add_child(_spacer(26))
	box.add_child(UiTheme.text_label("WASD oder Pfeiltasten – Laufen    ·    Shift – Rennen    ·    ESC – Pause", 15))

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func focus_first() -> void:
	if is_instance_valid(_first):
		_first.grab_focus()
