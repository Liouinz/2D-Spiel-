class_name Hud
extends CanvasLayer
## Dezente Steuerungshilfe beim Betreten der Welt. Blendet sich selbst aus.

const SHOW_TIME := 7.0
const FADE_TIME := 1.5

var _label: Label
var _time: float = 0.0

func _ready() -> void:
	layer = 5
	if not Settings.show_hints:
		queue_free()
		return
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_label = Label.new()
	_label.text = "WASD / Pfeiltasten – Laufen    ·    Shift – Rennen    ·    ESC – Pause"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Palette.UI_TEXT)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -56
	_label.offset_bottom = -24
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_label)

func _process(delta: float) -> void:
	_time += delta
	if _time < SHOW_TIME:
		return
	var a := 1.0 - (_time - SHOW_TIME) / FADE_TIME
	if a <= 0.0:
		queue_free()
		return
	_label.modulate.a = a
