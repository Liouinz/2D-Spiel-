extends CanvasLayer
## Inventar: hier wird ausgerüstet, was in der Bau-Leiste liegt.
##
## Oben alle Bodentypen als anklickbare Karten, unten die acht Felder der
## Leiste. Erst unten ein Feld wählen, dann oben einen Typ anklicken — er wird
## darauf gelegt. Damit stellt man sich die Leiste selbst zusammen, statt mit
## einer festen Reihenfolge zu leben.
##
## Geöffnet und geschlossen mit E, geschlossen auch mit ESC. Das Spiel pausiert
## solange, damit sich in Ruhe klicken lässt.

const CARD := 72
const PAD := 10
const COLS := 5

## Alles, was sich setzen lässt — auch Tiefwasser, das in der Leiste anfangs
## fehlt. Es blockiert, im Gegensatz zu flachem Wasser.
const ALL := [
	MapData.Tile.GRASS,
	MapData.Tile.MEADOW,
	MapData.Tile.FOREST,
	MapData.Tile.PATH,
	MapData.Tile.COBBLE,
	MapData.Tile.SAND,
	MapData.Tile.ROCK,
	MapData.Tile.WATER,
	MapData.Tile.DEEP_WATER,
]

## Kurze Erklärung je Typ — sonst rät man, was ein Block tut.
const HINTS := {
	MapData.Tile.ROCK: "eine Stufe höher · hinaufspringen",
	MapData.Tile.WATER: "durchschwimmbar",
	MapData.Tile.DEEP_WATER: "hält auf",
}

signal equip_requested(slot: int, tile: int)

var bar: CanvasLayer            ## BuildBar
var target_slot: int = 0

var _root: Control
var _slot_frames: Array[Panel] = []
var _hint: Label

func setup(art: TileArt, build_bar: CanvasLayer) -> void:
	layer = 8
	bar = build_bar
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.07, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var w: int = COLS * (CARD + PAD) + PAD + 40
	# Höhe reicht für Titel, zwei Reihen Karten, die Bau-Leiste UND die
	# Hinweiszeile darunter — sonst lag der Hinweis über den Feldern.
	var h: int = 2 * (CARD + PAD) + 254
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_bottom = h * 0.5
	panel.add_theme_stylebox_override("panel", _box(Color(0.10, 0.11, 0.14, 0.97),
		Color(0.85, 0.80, 0.62, 0.9), 3))
	_root.add_child(panel)

	panel.add_child(_text("Inventar", 26, 16, HORIZONTAL_ALIGNMENT_CENTER, w))
	panel.add_child(_text("Feld unten wählen, dann oben einen Boden anklicken",
		15, 50, HORIZONTAL_ALIGNMENT_CENTER, w))

	# --- Bodentypen ---
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", PAD)
	grid.add_theme_constant_override("v_separation", PAD)
	grid.position = Vector2(20, 84)
	panel.add_child(grid)
	for t: int in ALL:
		grid.add_child(_card(art, t))

	# --- Die acht Felder der Leiste ---
	panel.add_child(_text("Bau-Leiste", 18, 84 + 2 * (CARD + PAD) + 16,
		HORIZONTAL_ALIGNMENT_CENTER, w))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(20, 84 + 2 * (CARD + PAD) + 46)
	panel.add_child(row)
	for i in bar.types.size():
		row.add_child(_slot_card(i, w))

	_hint = _text("", 15, h - 36, HORIZONTAL_ALIGNMENT_CENTER, w)
	panel.add_child(_hint)
	select_slot(0)

func _card(art: TileArt, tile: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD, CARD)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _box(Color(0.07, 0.08, 0.10, 0.9),
		Color(0, 0, 0, 0.6), 2))
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			equip_requested.emit(target_slot, tile))
	card.mouse_entered.connect(func() -> void: _describe(tile))

	var tex := TextureRect.new()
	tex.texture = Pixel.tex(art.base[tile][TileArt.VARIANTS])
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.position = Vector2(8, 6)
	tex.size = Vector2(CARD - 16, CARD - 30)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tex)

	var nm := _text(GroundTileSet.NAMES[tile], 12, CARD - 22,
		HORIZONTAL_ALIGNMENT_CENTER, CARD)
	nm.position.x = 0
	card.add_child(nm)
	return card

func _slot_card(i: int, _w: int) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(CARD - 14, CARD - 14)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			select_slot(i))
	var num := _text(str(i + 1), 15, 4, HORIZONTAL_ALIGNMENT_CENTER, CARD - 14)
	num.position.x = 0
	card.add_child(num)
	var nm := _text("", 11, CARD - 36, HORIZONTAL_ALIGNMENT_CENTER, CARD - 14)
	nm.position.x = 0
	nm.name = "Name"
	card.add_child(nm)
	_slot_frames.append(card)
	return card

## Wählt das Feld, das als Nächstes belegt wird.
func select_slot(i: int) -> void:
	target_slot = clampi(i, 0, _slot_frames.size() - 1)
	refresh()

## Zieht Rahmen und Beschriftung der Felder nach — nach jedem Ausrüsten.
func refresh() -> void:
	for s in _slot_frames.size():
		var active := s == target_slot
		_slot_frames[s].add_theme_stylebox_override("panel", _box(
			Color(0.07, 0.08, 0.10, 0.95 if active else 0.7),
			Color(1.00, 0.85, 0.25, 0.95) if active else Color(0, 0, 0, 0.6),
			3 if active else 2))
		var nm := _slot_frames[s].get_node("Name") as Label
		nm.text = GroundTileSet.NAMES[bar.types[s]]
	_describe(bar.types[target_slot])

func _describe(tile: int) -> void:
	if _hint == null:
		return
	var extra: String = HINTS.get(tile, "begehbar")
	_hint.text = "%s — %s        (Feld %d wird belegt)" % [
		GroundTileSet.NAMES[tile], extra, target_slot + 1]

func _text(msg: String, size: int, y: int, align: int, width: int) -> Label:
	var l := Label.new()
	l.text = msg
	l.position = Vector2(0, y)
	l.size = Vector2(width, size + 8)
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.UI_TEXT)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(width)
	box.border_color = border
	box.set_corner_radius_all(6)
	return box
