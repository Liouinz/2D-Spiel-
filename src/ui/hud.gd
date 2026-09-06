extends CanvasLayer
## Steuerungshilfe beim Betreten der Welt und — im Aufbaumodus — eine
## Anzeige, auf welchem Block die Figur gerade steht.

const SHOW_TIME := 7.0
const FADE_TIME := 1.5

var player: Node2D
var grid: GridOverlay

var _label: Label
var _blocks: Label
var _time: float = 0.0

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Blockanzeige: nur im Aufbaumodus sinnvoll
	if Config.EMPTY_WORLD:
		_blocks = _make_label(20)
		_blocks.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_blocks.offset_left = 24
		_blocks.offset_top = 18
		_blocks.offset_right = 900
		_blocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		root.add_child(_blocks)

	if Settings.show_hints:
		_label = _make_label(17)
		if Config.EMPTY_WORLD:
			# Unten ist im Aufbaumodus kein Platz — dort liegt die Bau-Leiste.
			# Die Steuerungshilfe kommt deshalb unter die Blockanzeige.
			_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_label.offset_left = 24
			_label.offset_top = 78
			_label.offset_right = 900
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_label.text = "WASD / Pfeiltasten – Laufen   ·   Shift – Rennen   ·   Leertaste – Springen"
			_label.text += "\nG – Raster   ·   F5 – Karte speichern   ·   ESC – Pause"
		else:
			_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			_label.offset_top = -64
			_label.offset_bottom = -28
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label.text = "WASD / Pfeiltasten – Laufen   ·   Shift – Rennen   ·   Leertaste – Springen   ·   ESC – Pause"
		root.add_child(_label)

func _make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.UI_TEXT)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _process(delta: float) -> void:
	if _blocks != null and is_instance_valid(player):
		var b := GridOverlay.block_at(player.global_position)
		var c := GridOverlay.chunk_of(b)
		var ic := GridOverlay.block_in_chunk(b)
		var on := is_instance_valid(grid) and grid.show_grid
		_blocks.text = "Chunk  %d | %d      ·      Block  %d | %d      ·      im Chunk  %d | %d\n%d px je Block   ·   %d × %d Blöcke   =   %d × %d Chunks   ·   G – Raster %s" % [
			c.x, c.y, b.x, b.y, ic.x, ic.y,
			Config.TILE, Config.MAP_W, Config.MAP_H,
			Config.MAP_W / Config.CHUNK, Config.MAP_H / Config.CHUNK,
			"aus" if on else "an"]

	if _label == null:
		return
	_time += delta
	if _time < SHOW_TIME:
		return
	var a := 1.0 - (_time - SHOW_TIME) / FADE_TIME
	if a <= 0.0:
		_label.queue_free()
		_label = null
		return
	_label.modulate.a = a
