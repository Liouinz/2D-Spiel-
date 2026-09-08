extends CanvasLayer
## Steuerungshilfe beim Betreten der Welt und eine Anzeige, auf welchem
## Block die Figur gerade steht.

const SHOW_TIME := 7.0
const FADE_TIME := 1.5

var player: Node2D
var grid: GridOverlay

var _label: Label
var _blocks: Label
var minimap: Control
var perf: Control
var debug: Control
var _time: float = 0.0

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.attach(root)
	add_child(root)

	# Blockanzeige: Chunk, Block und Position der Figur.
	#
	# Kleiner und blasser als früher (20 Punkt in vollem Weiss). Die Angaben
	# sind nützlich, aber sie sind Nebeninformation — in voller Grösse und
	# Helligkeit war die Ecke das Erste, was man im Bild sah, und das Spiel
	# wirkte dadurch wie ein Werkzeug mit Weltansicht.
	_blocks = _make_label(UiTheme.FONT_SMALL)
	_blocks.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_blocks.offset_left = 24
	_blocks.offset_top = 18
	_blocks.offset_right = 900
	_blocks.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(_blocks)

	# Minimap: zeigt das Gebaute auch dann, wenn das Raster aus ist.
	minimap = preload("res://src/ui/minimap.gd").new()
	minimap.name = "Minimap"
	root.add_child(minimap)

	# Leistungsanzeige: immer vorhanden, beim Start immer unsichtbar.
	perf = preload("res://src/ui/perf_overlay.gd").new()
	perf.name = "Perf"
	perf.visible = Settings.show_perf
	root.add_child(perf)
	Settings.changed.connect(func() -> void:
		if is_instance_valid(perf):
			perf.visible = Settings.show_perf)

	debug = preload("res://src/ui/debug_overlay.gd").new()
	debug.name = "Debug"
	root.add_child(debug)

	if Settings.show_hints:
		# Unten ist kein Platz — dort liegt die Bau-Leiste. Die Steuerungshilfe
		# kommt deshalb unter die Blockanzeige.
		_label = _make_label(UiTheme.FONT_SMALL)
		_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_label.offset_left = 24
		_label.offset_top = 78
		_label.offset_right = 900
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label.text = "WASD / Pfeiltasten – Laufen   ·   Shift – Rennen   ·   Leertaste – Springen"
		_label.text += "\nE – Inventar   ·   G – Raster   ·   M – Minimap   ·   H – diese Anzeige"
		_label.text += "\nF5 – Karte speichern   ·   ESC – Pause"
		root.add_child(_label)

func _make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.62))
	l.add_theme_constant_override("outline_size", UiTheme.OUTLINE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## M schaltet die Minimap, H die Anzeige oben links. Beides getrennt vom
## Raster (G) — vorher hing alles an einer Taste.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_minimap"):
		if is_instance_valid(minimap):
			minimap.visible = not minimap.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_info"):
		if is_instance_valid(_blocks):
			_blocks.visible = not _blocks.visible
		if is_instance_valid(_label):
			_label.visible = not _label.visible
		get_viewport().set_input_as_handled()

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
