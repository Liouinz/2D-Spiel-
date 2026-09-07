class_name ItemSlot
extends Control
## Ein Feld — die Materialkarten im Inventar und die Felder der Bauleiste.
##
## Beide teilen sich diese eine Klasse. Vorher hatte jede Ansicht ihre eigenen
## Rahmen, Abstände und Beschriftungen; dadurch sah die Oberfläche aus wie
## mehrere einzelne Schaltflächen nebeneinander statt wie ein System. Hier
## liegen Form, Farbe und Verhalten an genau einer Stelle.
##
## Vier Zustände, klar auseinanderzuhalten:
##
##   NORMAL     ruhiges Feld
##   HOVER      hellt auf und wächst einen Hauch
##   SELECTED   Rahmen in der Akzentfarbe mit weichem Schein
##   DISABLED   abgedunkelt, nimmt keine Klicks an
##
## Gezeichnet wird alles in `_draw()`: Rahmen, Kachelbild, Nummer, Name. Damit
## gibt es keine verschachtelten Knoten und keine NodePaths, die brechen können.

enum Kind {
	CARD,    ## Materialkarte im Inventar: grosses Bild, Name darunter
	SLOT,    ## Feld der Bauleiste: quadratisch, Nummer oben, Name im Fuss
}

## Kantenlängen. Beide bauen auf dem 64er-Kachelbild auf, damit es 1:1 und
## damit unverzerrt gezeichnet werden kann.
const ICON := TileIcon.SIZE
const CARD_SIZE := Vector2(ICON + 28, ICON + 48)      ## 92 x 112
const SLOT_SIZE := Vector2(ICON + 8, ICON + 8)        ## 72 x 72

const PAD_CARD := 14
const PAD_SLOT := 4

## Höhe der Namenszeile: unter dem Bild bei der Karte, als Band im Fuss beim
## Leistenfeld. Und die Grösse der Nummernmarke oben links.
const CAPTION_H := 30
const BAND_H := 19
const BADGE := Vector2(20, 18)

const FONT_CARD := UiTheme.FONT_SMALL
const FONT_SLOT := UiTheme.FONT_TINY
const FONT_NUMBER := UiTheme.FONT_TINY

## Wie weit ein Feld beim Überfahren und beim Auswählen über seine Kante
## hinauswächst. Bewusst klein — die Bewegung soll ruhig bleiben.
const GROW_HOVER := 1.0
const GROW_SELECTED := 2.0

signal pressed

var kind: int = Kind.CARD
var tile: int = MapData.Tile.GRASS
var number: int = 0                   ## 0 = keine Nummer anzeigen

var selected: bool = false: set = set_selected
var disabled: bool = false: set = set_disabled

var _icon: Texture2D
var _hover := 0.0                     ## 0 … 1, animiert
var _sel := 0.0                       ## 0 … 1, animiert
var _over := false

func setup(slot_kind: int, tile_type: int, icon: Texture2D, num: int = 0) -> ItemSlot:
	kind = slot_kind
	tile = tile_type
	_icon = icon
	number = num
	custom_minimum_size = CARD_SIZE if kind == Kind.CARD else SLOT_SIZE
	size = custom_minimum_size
	# Ohne Fokus: sonst landet die Tastatur in einem Feld und Leertaste oder
	# Eingabe lösen es aus, während der Spieler etwas ganz anderes wollte.
	focus_mode = Control.FOCUS_NONE
	# STOP: der Klick endet hier und läuft nicht als Bauklick in die Welt
	# weiter. Das ist die eigentliche Absicherung gegen durchsickernde Eingaben.
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	return self

## Legt ein anderes Material auf dieses Feld.
func set_tile(tile_type: int, icon: Texture2D) -> void:
	tile = tile_type
	_icon = icon
	queue_redraw()

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	set_process(true)

func set_disabled(value: bool) -> void:
	if disabled == value:
		return
	disabled = value
	if disabled:
		_over = false
	set_process(true)
	queue_redraw()

func _on_enter() -> void:
	if disabled:
		return
	_over = true
	set_process(true)

func _on_exit() -> void:
	_over = false
	set_process(true)

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()

## Läuft nur, solange sich wirklich etwas bewegt — danach schaltet es sich ab.
func _process(delta: float) -> void:
	var want_hover := 1.0 if _over else 0.0
	var want_sel := 1.0 if selected else 0.0
	var step := clampf(delta * UiTheme.STATE_SPEED, 0.0, 1.0)
	_hover = lerpf(_hover, want_hover, step)
	_sel = lerpf(_sel, want_sel, step)
	if absf(_hover - want_hover) < 0.005 and absf(_sel - want_sel) < 0.005:
		_hover = want_hover
		_sel = want_sel
		set_process(false)
	queue_redraw()

# --- Zeichnen ----------------------------------------------------------------

func _draw() -> void:
	var grow := _hover * GROW_HOVER + _sel * GROW_SELECTED
	var frame := Rect2(Vector2(-grow, -grow), size + Vector2(grow, grow) * 2.0)
	draw_style_box(frame_style(), frame)

	var icon_pos := Vector2(PAD_CARD, PAD_CARD - 2) if kind == Kind.CARD \
		else Vector2(PAD_SLOT, PAD_SLOT)
	_draw_icon(icon_pos)

	if kind == Kind.CARD:
		_draw_caption(GroundTileSet.NAMES[tile], size.y - CAPTION_H - 4, CAPTION_H, FONT_CARD)
	else:
		# Der Name liegt im Fuss auf einem dunklen Band. So bleibt das Feld
		# quadratisch und der Name trotzdem lesbar.
		var band := Rect2(PAD_SLOT, size.y - PAD_SLOT - BAND_H, ICON, BAND_H)
		draw_rect(band, Color(UiTheme.SCRIM, 0.74))
		_draw_caption(GroundTileSet.NAMES[tile], band.position.y, band.size.y, FONT_SLOT)
	if number > 0:
		_draw_number()

## Das Kachelbild sitzt in einer leicht vertieften Mulde und wird 1:1
## gezeichnet — keine Streckung, kein angeschnittener Ausschnitt.
func _draw_icon(pos: Vector2) -> void:
	var well := UiTheme.box(UiTheme.SURFACE_SUNKEN, Color(0, 0, 0, 0), 0, UiTheme.RADIUS_S - 2)
	draw_style_box(well, Rect2(pos - Vector2(2, 2), Vector2(ICON + 4, ICON + 4)))
	if _icon == null:
		return
	var tint := Color(1, 1, 1, 1)
	if disabled:
		tint = Color(0.5, 0.5, 0.55, 0.7)
	else:
		# Beim Überfahren und im gewählten Zustand hellt das Bild leicht auf.
		var lift := _hover * 0.10 + _sel * 0.12
		tint = Color(1.0 + lift, 1.0 + lift, 1.0 + lift, 1.0)
	draw_texture_rect(_icon, Rect2(pos, Vector2(ICON, ICON)), false, tint)

func _draw_number() -> void:
	var box := UiTheme.box(Color(UiTheme.SCRIM, 0.78), Color(0, 0, 0, 0), 0, 3)
	box.corner_radius_top_left = UiTheme.RADIUS_S - 2
	var rect := Rect2(Vector2(PAD_SLOT, PAD_SLOT), BADGE)
	draw_style_box(box, rect)
	var col: Color = UiTheme.ACCENT if selected else UiTheme.TEXT
	_text(str(number), rect.position.x, rect.size.x, rect.position.y, rect.size.y,
		FONT_NUMBER, col if not disabled else UiTheme.TEXT_DIM)

func _draw_caption(text: String, y: float, height: float, font_size: int) -> void:
	var col: Color = UiTheme.TEXT
	if disabled:
		col = UiTheme.TEXT_DIM
	elif selected:
		col = UiTheme.ACCENT
	_text(text, 0.0, size.x, y, height, font_size, col)

## Waagerecht und senkrecht mittig, mit dunklem Saum — lesbar auf jedem Boden.
func _text(text: String, x: float, width: float, y: float, height: float,
		font_size: int, col: Color) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var baseline := y + (height + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var at := Vector2(x, baseline)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size,
		UiTheme.OUTLINE, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, col)

## Wie deutlich dieses Feld gerade hervorgehoben ist (0 … 1). Öffentlich,
## damit der Selbsttest die Auswahl prüfen kann, ohne ein Bild zu vergleichen.
func highlight_strength() -> float:
	return _sel

## Dasselbe für den Überfahren-Zustand.
func hover_strength() -> float:
	return _hover

## Rahmen und Fläche des Feldes — der ganze Zustandswechsel steckt hier.
## Ebenfalls öffentlich: der Selbsttest liest daran ab, dass ein gewähltes Feld
## wirklich anders aussieht und nicht nur eine Spur heller ist.
func frame_style() -> StyleBoxFlat:
	if disabled:
		return UiTheme.box(Color(0.09, 0.10, 0.12, 0.55), Color(0.24, 0.24, 0.26, 0.6),
			UiTheme.BORDER, UiTheme.RADIUS_S)

	# Fläche: ruhig, hellt beim Überfahren auf, im gewählten Zustand warm getönt.
	var bg := UiTheme.SURFACE_RAISED.lerp(UiTheme.SURFACE_HOVER, _hover) \
		.lerp(UiTheme.SURFACE_ACTIVE, _sel)
	# Rahmen: dezent, beim Überfahren Holzton, gewählt in der Akzentfarbe.
	var border := UiTheme.LINE.lerp(UiTheme.ACCENT_LINE, _hover).lerp(UiTheme.ACCENT, _sel)
	var box := UiTheme.box(bg, border,
		int(round(lerpf(UiTheme.BORDER, UiTheme.BORDER_STRONG, _sel))), UiTheme.RADIUS_S)

	# Schein: nur das gewählte Feld bekommt einen — dadurch ist die Auswahl
	# nicht mehr an einer dünnen gelben Linie zu erraten.
	if _sel > 0.01:
		box.shadow_size = int(round(10.0 * _sel))
		box.shadow_color = Color(UiTheme.ACCENT, 0.34 * _sel)
	return box
