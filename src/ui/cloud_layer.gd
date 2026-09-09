extends Control
## Wolkenband, das im Hauptmenü langsam vorbeizieht. Rein dekorativ.

const BAND_W := 320
const BAND_H := 64
const SPEED := 5.0     ## Pixel pro Sekunde in Bildpunkten der Vorlage

var _tex: Texture2D
var _offset: float = 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	_tex = MenuArt.cloud_band(BAND_W, BAND_H)

func _process(delta: float) -> void:
	_offset = fmod(_offset + SPEED * delta, float(BAND_W))
	queue_redraw()

func _draw() -> void:
	if _tex == null:
		return
	var scale := size.x / float(BAND_W)
	var w := size.x
	var h := BAND_H * scale
	var y := size.y * 0.02
	var x := -_offset * scale
	draw_texture_rect(_tex, Rect2(x, y, w, h), false)
	draw_texture_rect(_tex, Rect2(x + w, y, w, h), false)
