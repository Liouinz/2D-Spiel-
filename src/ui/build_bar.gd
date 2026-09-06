class_name BuildBar
extends CanvasLayer
## Bauleiste am unteren Bildrand — die Schnellauswahl im Spiel.
##
## Drei Felder in einer zusammenhängenden Leiste, so wie man es aus
## Sandkastenspielen kennt: Nummer oben links, das Material als Bild, der Name
## im Fuss. Das gewählte Feld ist deutlich hervorgehoben, nicht nur an einer
## dünnen Linie zu erkennen.
##
## Die Leiste hat genau eine Aufgabe: schnell zwischen den drei belegten
## Materialien wechseln. WAS auf den Feldern liegt, wird im Inventar (E)
## bestimmt — die beiden sind technisch verbunden, bleiben aber getrennte
## Ansichten mit getrennten Aufgaben.
##
## Bewusst ohne Dauertext: früher stand hier eine Zeile mit vier
## Bedienhinweisen. Die Steuerung steht in der HUD und im Optionsmenü; die
## Leiste selbst zeigt nur noch, was sie ist.

const SLOT := ItemSlot.SLOT_SIZE      ## 72 x 72
const GAP := 6                        ## Abstand zwischen den Feldern
const PAD := 7                        ## Rand der Leiste um die Felder
const MARGIN := 16                    ## Abstand zum unteren Bildrand

## Anfangsbelegung der drei Felder. Änderbar: im Inventar (E) lässt sich jedes
## Feld mit einem beliebigen Bodentyp belegen, und die Belegung bleibt
## gespeichert.
const DEFAULT_TYPES := [
	MapData.Tile.GRASS,
	MapData.Tile.SAND,
	MapData.Tile.WATER,
]

var selected: int = 0
var types: Array = DEFAULT_TYPES.duplicate()

## Die Materialbilder der Oberfläche — das Inventar nimmt dieselben, damit
## beide Ansichten dasselbe zeigen.
var icons: Array[Texture2D] = []

signal slot_clicked(index: int)

## Wird gemeldet, wenn sich die Belegung geändert hat — Settings sichern sie.
signal loadout_changed

var _root: Control
var _frame: Panel
var _slots: Array[ItemSlot] = []
var _world_tex: Array[Texture2D] = []   ## 32er-Kacheln für die Bauvorschau
var _art: TileArt
var _message: Label
var _flash: float = 0.0

func setup(art: TileArt) -> void:
	layer = 6
	_art = art
	icons = TileIcon.build(art)
	_world_tex.resize(types.size())

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var w := int(PAD * 2 + types.size() * SLOT.x + (types.size() - 1) * GAP)
	var h := int(PAD * 2 + SLOT.y)

	_frame = Panel.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_frame.offset_left = -w * 0.5
	_frame.offset_right = w * 0.5
	_frame.offset_top = -h - MARGIN
	_frame.offset_bottom = -MARGIN
	# STOP: ein Klick auf die Leiste endet hier und wird nicht zusätzlich als
	# Bauklick in der Welt ausgeführt.
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_theme_stylebox_override("panel", bar_frame())
	_root.add_child(_frame)

	for i in types.size():
		var slot := ItemSlot.new().setup(ItemSlot.Kind.SLOT, types[i], icons[types[i]], i + 1)
		slot.position = Vector2(PAD + i * (SLOT.x + GAP), PAD)
		slot.pressed.connect(func() -> void: slot_clicked.emit(i))
		_frame.add_child(slot)
		_slots.append(slot)
		_world_tex[i] = Pixel.tex(art.base[types[i]][TileArt.VARIANTS])

	# Nur für kurze Rückmeldungen wie „Karte gespeichert“ — sonst unsichtbar.
	_message = Label.new()
	_message.name = "Message"
	_message.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message.offset_left = -320
	_message.offset_right = 320
	_message.offset_top = -h - MARGIN - 30
	_message.offset_bottom = -h - MARGIN - 6
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.visible = false
	_message.add_theme_font_size_override("font_size", 15)
	_message.add_theme_color_override("font_color", Palette.UI_ACCENT)
	_message.add_theme_constant_override("outline_size", 6)
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_root.add_child(_message)

	select(0)

## Die Fassung der Leiste. Öffentlich, weil das Inventar dieselbe verwendet —
## so sieht die Leiste dort genauso aus wie im Spiel.
static func bar_frame() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.07, 0.09, 0.82)
	box.border_color = Color(0.24, 0.22, 0.19, 0.9)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.shadow_size = 8
	box.shadow_color = Color(0, 0, 0, 0.38)
	return box

## Hebt das gewählte Feld hervor.
func select(i: int) -> void:
	selected = posmod(i, types.size())
	for s in _slots.size():
		_slots[s].selected = s == selected

## Der gewählte Bodentyp.
func tile_type() -> int:
	return types[selected]

## Belegt ein Feld mit einem anderen Bodentyp — das macht das Inventar.
func equip(slot: int, tile: int) -> void:
	if slot < 0 or slot >= types.size() or types[slot] == tile:
		return
	if tile < 0 or tile >= MapData.Tile.COUNT:
		return
	types[slot] = tile
	_slots[slot].set_tile(tile, icons[tile])
	_world_tex[slot] = Pixel.tex(_art.base[tile][TileArt.VARIANTS])
	loadout_changed.emit()

## Belegung als Liste von Bodentypen (für das Sichern).
func loadout() -> Array:
	return types.duplicate()

func set_loadout(list: Array) -> void:
	for i in mini(list.size(), types.size()):
		equip(i, int(list[i]))

## Die Weltkachel des gewählten Typs — die Bauvorschau zeichnet sie in den
## Block unter dem Zeiger. Bewusst die 32er-Kachel, nicht das grosse Feldbild:
## die Vorschau liegt auf genau einem Block.
func preview_texture() -> Texture2D:
	if selected < _world_tex.size():
		return _world_tex[selected]
	return null

## Liegt der Mauszeiger über der Leiste? Dann darf kein Block gesetzt werden.
func covers(pos: Vector2) -> bool:
	if not visible or not is_instance_valid(_frame):
		return false
	return _frame.get_global_rect().has_point(pos)

## Blendet für zwei Sekunden eine Meldung über der Leiste ein.
func flash(text: String) -> void:
	if _message == null:
		return
	_message.text = text
	_message.visible = true
	_message.modulate.a = 1.0
	_flash = 2.0

func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	if _flash <= 0.0:
		_message.visible = false
	elif _flash < 0.5:
		_message.modulate.a = _flash / 0.5
