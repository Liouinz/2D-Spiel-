class_name Inventory
extends CanvasLayer
## Inventar (E) — hier wird bestimmt, was auf der Bauleiste liegt.
##
## Aufbau von oben nach unten:
##
##   INVENTAR          Überschrift
##   [Gras][Sand][Wasser]   die drei Materialien, die es gibt
##   Bauleiste         Zwischenüberschrift
##   [1][2][3]         die Felder der Leiste, so wie sie im Spiel aussehen
##   E – Schliessen    der einzige Bedienhinweis, der übrig bleibt
##
## Bedienung ohne Erklärtext: das gewählte Feld der Leiste UND das Material,
## das darauf liegt, sind gleichzeitig hervorgehoben. Damit ist ohne einen
## einzigen Satz zu sehen, was zusammengehört. Ein Klick auf ein Material legt
## es auf das hervorgehobene Feld, ein Klick auf ein Feld wechselt es.
##
## Inventar und Leiste bleiben getrennte Ansichten mit getrennten Aufgaben:
## das Inventar bestückt, die Leiste wählt im Spiel schnell aus. Verbunden sind
## sie über genau einen Zustand — `bar.selected`. Zwei getrennte Auswahlen (eine
## im Inventar, eine in der Leiste) waren vorher die Ursache dafür, dass man
## erst lesen musste, was gerade gemeint ist.
##
## Der Zustand steckt in Main (State.INVENTORY): solange offen, ist der Baum
## pausiert und in der Welt passiert nichts.

## Alles, was sich setzen lässt. Genau drei Materialien — mehr gibt es nicht,
## weder hier noch auf der Karte.
const ALL := [
	MapData.Tile.GRASS,
	MapData.Tile.SAND,
	MapData.Tile.WATER,
]

const CARD := ItemSlot.CARD_SIZE      ## 92 x 112
const CARD_GAP := UiTheme.SPACE_M
const PAD := UiTheme.SPACE_L          ## Innenrand der Tafel
const PAD_TOP := 18
const PAD_BOTTOM := UiTheme.SPACE_M
const TITLE_H := 30
const LABEL_H := 20
const FOOTER_H := 18

## Dauer und Stärke der Einblendung kommen aus dem Designsystem — das Inventar
## blendet damit genauso ein wie jedes Menü.
const OPEN_TIME := UiTheme.ANIM
const DIM := UiTheme.SCRIM.a

signal equip_requested(slot: int, tile: int)

var bar: BuildBar

## Das Feld, das als Nächstes belegt wird. Kein eigener Zustand — es IST das
## gewählte Feld der Leiste. Nur so können beide Ansichten nicht auseinander
## laufen.
var target_slot: int:
	get:
		return bar.selected if is_instance_valid(bar) else 0

var _root: Control
var _dim: ColorRect
var _panel: Panel
var _cards: Array[ItemSlot] = []
var _slots: Array[ItemSlot] = []
var _open_t: float = 0.0

func setup(build_bar: BuildBar) -> void:
	layer = 8
	bar = build_bar
	visible = false

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.attach(_root)
	add_child(_root)

	# Abdunkelung. STOP, nicht IGNORE: sie fängt jeden Klick neben der Tafel ab,
	# damit er nicht als Bauklick in der Welt landet.
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(UiTheme.SCRIM, DIM)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_build_panel()

## Baut die Tafel. Die Höhe ergibt sich aus den Zeilen, sie steht nicht als
## Zahl im Code — vorher war sie eine handgerechnete Konstante, die bei jeder
## Änderung nicht mehr passte.
func _build_panel() -> void:
	var content_w := int(ALL.size() * CARD.x + (ALL.size() - 1) * CARD_GAP)
	var bar_w := int(BuildBar.PAD * 2 + ALL.size() * ItemSlot.SLOT_SIZE.x
		+ (ALL.size() - 1) * BuildBar.GAP)
	var bar_h := int(BuildBar.PAD * 2 + ItemSlot.SLOT_SIZE.y)
	var w := content_w + PAD * 2

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_box())
	_root.add_child(_panel)

	var y := PAD_TOP
	_panel.add_child(_label("INVENTAR", UiTheme.FONT_H1, PAD, y, content_w, TITLE_H,
		UiTheme.ACCENT))
	y += TITLE_H + 6

	# Schmale Zierlinie unter der Überschrift — trennt Kopf und Inhalt, ohne
	# dass dafür ein weiterer Satz nötig wäre.
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.ACCENT_LINE, 0.55)
	rule.position = Vector2((w - 64) * 0.5, y)
	rule.size = Vector2(64, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rule)
	y += 2 + 18

	for i in ALL.size():
		var tile: int = ALL[i]
		var card := ItemSlot.new().setup(ItemSlot.Kind.CARD, tile, bar.icons[tile])
		card.position = Vector2(PAD + i * (CARD.x + CARD_GAP), y)
		card.pressed.connect(func() -> void: equip_requested.emit(target_slot, tile))
		_panel.add_child(card)
		_cards.append(card)
	y += int(CARD.y) + 16

	_panel.add_child(_label("Bauleiste", UiTheme.FONT_SMALL, PAD, y, content_w, LABEL_H,
		UiTheme.TEXT_DIM))
	y += LABEL_H + 8

	# Die Leiste sieht hier genauso aus wie im Spiel — gleiche Fassung, gleiche
	# Felder. Sonst wirkte das Inventar wie eine zweite, andere Leiste.
	var bar_frame := Panel.new()
	bar_frame.name = "BarFrame"
	bar_frame.position = Vector2((w - bar_w) * 0.5, y)
	bar_frame.size = Vector2(bar_w, bar_h)
	bar_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	bar_frame.add_theme_stylebox_override("panel", BuildBar.bar_frame())
	_panel.add_child(bar_frame)
	for i in ALL.size():
		var slot := ItemSlot.new().setup(ItemSlot.Kind.SLOT, bar.types[i],
			bar.icons[bar.types[i]], i + 1)
		slot.position = Vector2(BuildBar.PAD + i * (ItemSlot.SLOT_SIZE.x + BuildBar.GAP),
			BuildBar.PAD)
		slot.pressed.connect(select_slot.bind(i))
		bar_frame.add_child(slot)
		_slots.append(slot)
	y += bar_h + 12

	_panel.add_child(_label("E – Schließen", UiTheme.FONT_TINY, PAD, y, content_w, FOOTER_H,
		UiTheme.TEXT_DIM))
	y += FOOTER_H + PAD_BOTTOM

	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -w * 0.5
	_panel.offset_right = w * 0.5
	_panel.offset_top = -y * 0.5
	_panel.offset_bottom = y * 0.5
	UiAnim.center_pivot(_panel)

## Wählt das Feld, das als Nächstes belegt wird — und damit zugleich das Feld,
## das nach dem Schliessen gebaut wird.
func select_slot(i: int) -> void:
	if is_instance_valid(bar):
		bar.select(i)
	refresh()

## Zieht die Hervorhebungen nach: das gewählte Feld und das Material darauf.
func refresh() -> void:
	if not is_instance_valid(bar):
		return
	var active: int = bar.types[bar.selected]
	for i in _slots.size():
		_slots[i].set_tile(bar.types[i], bar.icons[bar.types[i]])
		_slots[i].selected = i == bar.selected
	for i in _cards.size():
		_cards[i].selected = ALL[i] == active

## Öffnen und Schliessen. Nur Main ruft das auf — genau ein Weg hinein und
## einer hinaus, deshalb kann der Zustand nicht doppelt umschlagen.
func set_open(open: bool) -> void:
	if open == visible:
		return
	if open:
		refresh()
		_open_t = 0.0
		_apply_open()
	visible = open
	set_process(open)

func _process(delta: float) -> void:
	if _open_t >= 1.0:
		set_process(false)
		return
	_open_t = minf(_open_t + delta / OPEN_TIME, 1.0)
	_apply_open()

## Weiche Einblendung — dieselbe Kurve und dieselbe Dauer wie bei den Menüs.
func _apply_open() -> void:
	UiAnim.apply(_panel, _open_t)
	_dim.color.a = DIM * UiAnim.ease_t(_open_t)

## 1 – 3 wählen auch im offenen Inventar das Feld. Dieselben Aktionen wie im
## Spiel, aus der InputMap — nicht noch einmal als Tastencode im Code.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	for i in _slots.size():
		if event.is_action_pressed("build_slot_%d" % (i + 1)):
			select_slot(i)
			get_viewport().set_input_as_handled()
			return

func _label(text: String, font_size: int, x: int, y: int, width: int, height: int,
		col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, y)
	l.size = Vector2(width, height)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", UiTheme.OUTLINE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Dieselbe Tafel wie in den Menüs.
func _panel_box() -> StyleBoxFlat:
	return UiTheme.box(UiTheme.SURFACE, Palette.UI_BORDER, UiTheme.BORDER,
		UiTheme.RADIUS_L, UiTheme.SHADOW_PANEL)
