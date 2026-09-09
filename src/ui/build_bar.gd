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
## Abstand zwischen den Feldern.
##
## Von 6 auf 10 erhoeht, damit die Trennlinie (siehe `Dividers`) ueberhaupt
## Platz hat: bei sechs Punkten Luecke standen die Rahmen zweier Felder fast
## aneinander, und dazwischen war kein Raum fuer eine Fuge.
const GAP := 10
const PAD := 7                        ## Rand der Leiste um die Felder
const MARGIN := UiTheme.SPACE_M       ## Abstand zum unteren Bildrand

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
	UiTheme.attach(_root)
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
		var slot := ItemSlot.new()
		slot.overlay = true
		slot.setup(ItemSlot.Kind.SLOT, types[i], icons[types[i]], i + 1)
		slot.position = Vector2(PAD + i * (SLOT.x + GAP), PAD)
		slot.pressed.connect(func() -> void: slot_clicked.emit(i))
		_frame.add_child(slot)
		_slots.append(slot)
		_world_tex[i] = Pixel.tex(art.base[types[i]][TileArt.MID])

	var lines := Dividers.new()
	lines.name = "Trennlinien"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Groesse ausdruecklich setzen statt ueber Anker: der Rahmen bekommt seine
	# Masse erst, wenn Godot die Oberflaeche einmal durchgerechnet hat — und
	# ein Kind mit Hoehe 0 zeichnet nichts.
	lines.position = Vector2.ZERO
	lines.size = Vector2(w, h)
	for i in range(1, types.size()):
		lines.gaps.append(PAD + i * (SLOT.x + GAP) - GAP * 0.5)
	# Unter die Felder: eine Linie, die ueber ein gewaehltes Feld liefe, waere
	# ein Strich durch das Bild statt eine Fuge daneben.
	_frame.add_child(lines)
	_frame.move_child(lines, 0)

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
	_message.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	_message.add_theme_color_override("font_color", UiTheme.ACCENT)
	_message.add_theme_constant_override("outline_size", UiTheme.OUTLINE + 2)
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_root.add_child(_message)

	select(0)

## Die Fassung der Leiste. Öffentlich, weil das Inventar dieselbe verwendet —
## so sieht die Leiste dort genauso aus wie im Spiel.
## Der Rahmen der Leiste.
##
## Vorher war er fast undurchsichtig. Eine Leiste am unteren Bildrand ist aber
## kein Fenster, sondern eine Anzeige, die ueber der Welt liegt — man soll
## sehen, dass darunter Boden ist. Der Auftrag nennt es „durchscheinender
## Hintergrund"; technisch heisst das: dieselbe Form wie bisher, aber die
## Fuellung laesst die Welt durch.
##
## Nicht zu weit: unter der Leiste steht mal Gras, mal Sand, mal Wasser, und
## die Namen der Materialien muessen auf jedem davon lesbar bleiben. 0,58 ist
## die Grenze, ab der ein heller Sandstrand die Schrift zu stoeren beginnt.
static func bar_frame() -> StyleBoxFlat:
	var s := UiTheme.inset_style(0.58)
	# Eine Lichtkante an der Oberkante: sie trennt die Leiste von der Welt,
	# ohne einen zweiten Rahmen zu brauchen.
	s.border_width_top = 3
	s.border_color = Color(Palette.UI_BORDER_HI, 0.55)
	return s

## Die Trennlinien zwischen den Feldern.
##
## Drei Felder mit Luft dazwischen lesen sich als drei einzelne Schaltflaechen,
## die zufaellig nebeneinander liegen. Eine Linie in jeder Luecke macht daraus
## EINE Leiste mit drei Faechern — derselbe Unterschied wie zwischen drei
## Zetteln und einer Tabelle.
class Dividers:
	extends Control

	## Drei Abschnitte je Linie: schwach, kraeftig, schwach. Eine Linie mit
	## gleicher Deckkraft ueber die volle Hoehe stiesse oben und unten gegen die
	## Rundung des Rahmens und saehe abgeschnitten aus.
	const PARTS: Array[Array] = [
		[0.08, 0.16, 0.18],    ## Anteil oben, Hoehe, Deckkraft
		[0.24, 0.52, 0.55],
		[0.76, 0.16, 0.18],
	]

	var gaps: Array[float] = []

	func _draw() -> void:
		for x: float in gaps:
			for part: Array in PARTS:
				var y: float = size.y * float(part[0])
				var h: float = size.y * float(part[1])
				draw_rect(Rect2(x, y, 1.0, h),
					Color(Palette.UI_BORDER_HI, float(part[2])), true)

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
	_world_tex[slot] = Pixel.tex(_art.base[tile][TileArt.MID])
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
