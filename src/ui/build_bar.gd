extends CanvasLayer
## Bau-Leiste am unteren Bildrand: acht Felder mit den Bodentypen, die sich
## in die Welt setzen lassen.
##
## Jedes Feld zeigt die echte Bodenkachel als Vorschau — dieselben Bilder, die
## auch auf der Karte liegen. Dadurch stimmt die Leiste immer mit dem überein,
## was ein Klick tatsächlich erzeugt, ohne eigene Symbolgrafiken. Darunter
## steht der Name, weil sich Gras und Wiese als Bild allein kaum unterscheiden.

const SLOT := 48          ## Kantenlänge der Kachelvorschau
const PAD := 8            ## Rand um die Vorschau
const NAME_H := 16        ## Zeile für den Namen
const GAP := 8            ## Abstand zwischen den Feldern
const MARGIN := 14        ## Abstand zum unteren Bildrand

## Reihenfolge der Felder. Tiefwasser fehlt bewusst: als Baufläche ist es von
## flachem Wasser kaum zu unterscheiden und blockiert genauso.
const TYPES := [
	MapData.Tile.GRASS,
	MapData.Tile.MEADOW,
	MapData.Tile.FOREST,
	MapData.Tile.PATH,
	MapData.Tile.COBBLE,
	MapData.Tile.SAND,
	MapData.Tile.ROCK,
	MapData.Tile.WATER,
]

var selected: int = 0

signal slot_clicked(index: int)

var _root: Control
var _slots: Array[Panel] = []
var _textures: Array[Texture2D] = []
var _hint: Label
var _flash: float = 0.0

func setup(art: TileArt) -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var slot_w := SLOT + 2 * PAD
	var slot_h := SLOT + 2 * PAD + NAME_H
	var width := TYPES.size() * slot_w + (TYPES.size() - 1) * GAP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.offset_left = -width * 0.5
	row.offset_right = width * 0.5
	row.offset_top = -slot_h - MARGIN
	row.offset_bottom = -MARGIN
	_root.add_child(row)

	for i in TYPES.size():
		row.add_child(_make_slot(art, i, slot_w, slot_h))

	# Der Hinweis steht ÜBER der Leiste: unter ihr wäre er am Bildrand
	# abgeschnitten und läge über der Steuerungshilfe der HUD.
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -480
	_hint.offset_right = 480
	_hint.offset_top = -slot_h - MARGIN - 26
	_hint.offset_bottom = -slot_h - MARGIN - 4
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Palette.UI_TEXT)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_root.add_child(_hint)

	select(0)

func _make_slot(art: TileArt, i: int, slot_w: int, slot_h: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(slot_w, slot_h)
	# Anklickbar: das Feld fängt den Klick ab, damit er nicht als Bauklick
	# in der Welt landet.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed \
				and e.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(i))

	# Mittlere Helligkeitsstufe, erste Variante — die neutralste Ansicht.
	var tex := TextureRect.new()
	tex.texture = Pixel.tex(art.base[TYPES[i]][TileArt.VARIANTS])
	_textures.append(tex.texture)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.position = Vector2(PAD, PAD)
	tex.size = Vector2(SLOT, SLOT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tex)

	panel.add_child(_slot_label(str(i + 1), 13, Vector2(PAD + 3, PAD - 2), Vector2(20, 18),
		HORIZONTAL_ALIGNMENT_LEFT))
	# 11 Punkt: der längste Name ("Waldboden") passt damit noch ins Feld.
	panel.add_child(_slot_label(GroundTileSet.NAMES[TYPES[i]], 11,
		Vector2(0, SLOT + 2 * PAD - 3), Vector2(slot_w, NAME_H), HORIZONTAL_ALIGNMENT_CENTER))

	_slots.append(panel)
	return panel

func _slot_label(text: String, size: int, pos: Vector2, dim: Vector2, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = dim
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Hebt das gewählte Feld hervor und benennt es.
func select(i: int) -> void:
	selected = posmod(i, TYPES.size())
	for s in _slots.size():
		_slots[s].add_theme_stylebox_override("panel", _frame(s == selected))
	_flash = 0.0
	if _hint != null:
		_hint.text = "%s  gewählt   ·   1–8 oder Mausrad wechseln   ·   links setzen   ·   rechts entfernen" % [
			GroundTileSet.NAMES[TYPES[selected]]]

## Der gewählte Bodentyp.
func tile_type() -> int:
	return TYPES[selected]

## Die Kachel des gewählten Typs — die Bauvorschau zeichnet sie unter den Zeiger.
func preview_texture() -> Texture2D:
	if selected < _textures.size():
		return _textures[selected]
	return null

## Liegt der Mauszeiger über der Leiste? Dann darf kein Block gesetzt werden.
func covers(pos: Vector2) -> bool:
	for s in _slots:
		if s.get_global_rect().has_point(pos):
			return true
	return false

## Blendet für zwei Sekunden eine Meldung statt der Bedienhilfe ein.
func flash(text: String) -> void:
	if _hint == null:
		return
	_hint.text = text
	_flash = 2.0

func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	if _flash <= 0.0:
		select(selected)      # setzt den normalen Hinweistext zurück

func _frame(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.08, 0.10, 0.88 if active else 0.66)
	box.set_border_width_all(3 if active else 2)
	box.border_color = Color(1.00, 0.85, 0.25, 0.95) if active else Color(0, 0, 0, 0.6)
	box.set_corner_radius_all(6)
	return box
