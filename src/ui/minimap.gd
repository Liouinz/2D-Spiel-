extends Control
## Kleine Übersichtskarte oben rechts.
##
## Zeigt einen Ausschnitt um die Figur, nicht die ganze Welt: bei 2048 × 2048
## Blöcken wäre die ganze Karte 2048 Pixel breit. Hier sind es 80 × 80 Blöcke
## bei zwei Bildpunkten je Block.
##
## Gebaut wird über einen Rohpuffer und `Image.create_from_data` statt über
## `set_pixel` — 6400 Einzelaufrufe je Aktualisierung wären dafür zu teuer.

## 64 Blöcke = vier Chunks. Der Bildausschnitt zeigt nur rund 27 × 15 Blöcke,
## die Minimap also gut das Doppelte in jede Richtung. Mehr wäre lesbar zu
## klein: bei 80 Blöcken war ein Haus ein Punkt.
const BLOCKS := 64           ## Kantenlänge des Ausschnitts in Blöcken
const SCALE := 3             ## Bildpunkte je Block
const SIZE := BLOCKS * SCALE
const REFRESH_HZ := 6.0

## Eine Farbe je Bodentyp. Kräftiger als die Kacheln selbst, sonst ist auf
## 80 × 80 Punkten nichts zu unterscheiden.
const COLORS := {
	MapData.Tile.GRASS: Color8(96, 152, 78),
	MapData.Tile.SAND: Color8(226, 206, 148),
	MapData.Tile.WATER: Color8(64, 118, 172),
}

## Wie stark ein Feld an einer Materialgrenze abgedunkelt wird.
##
## Ohne diese Kante ist die Minimap eine Ansammlung von Farbflaechen: man sieht,
## DASS dort Wasser ist, aber nicht, welche Form es hat. Mit ihr bekommt jeder
## Teich einen Umriss und wird auf 3 Bildpunkten je Block lesbar.
const RIM_DARKEN := 0.30

## Wie viele Helligkeitsstufen ein Bodentyp auf der Karte bekommt.
##
## Die Hauptansicht hat seit dieser Runde Flecken, Halme und Kiesel; die
## Minimap war daneben eine glatte Farbflaeche. Drei Stufen mit knapp vier
## Prozent Abstand geben ihr die gleiche Koernung — genug, dass man Gelaende
## sieht statt Papier, und wenig genug, dass die Umrisse davon nicht leiden.
const LEVELS := 3
const LEVEL_STEP := 0.038

var map: MapData
var player: Node2D

var _tex: ImageTexture
var _img: Image
var _buf := PackedByteArray()
var _lut := PackedByteArray()      ## Bodentyp -> RGBA, einmal vorbereitet
var _lut_rim := PackedByteArray()  ## dasselbe, eine Stufe dunkler: die Kante
var _accum: float = 0.0
var _last := Vector2i(-9999, -9999)
var _label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -SIZE - 20
	offset_right = -20
	offset_top = 18
	offset_bottom = 18 + SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Nachschlagetabelle: Bodentyp mal Helligkeitsstufe. Einmal aufgebaut,
	# danach kostet ein Kartenpunkt nur noch vier Bytes kopieren.
	_lut.resize(256 * LEVELS * 4)
	_lut_rim.resize(256 * LEVELS * 4)
	for t in 256:
		var c: Color = COLORS.get(t, Color8(96, 152, 78))
		for l in LEVELS:
			var amount := (float(l) - float(LEVELS - 1) * 0.5) * LEVEL_STEP
			var shaded := c.lightened(amount) if amount > 0.0 else c.darkened(-amount)
			_write(_lut, (t * LEVELS + l) * 4, shaded)
			_write(_lut_rim, (t * LEVELS + l) * 4, shaded.darkened(RIM_DARKEN))

	_buf.resize(BLOCKS * BLOCKS * 4)
	_img = Image.create(BLOCKS, BLOCKS, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)

	_label = Label.new()
	# Unter die Karte, nicht darüber: oben ragte sie aus dem Bild.
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = 4
	_label.offset_bottom = 26
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Palette.UI_TEXT)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_label)

static func _write(buf: PackedByteArray, at: int, c: Color) -> void:
	buf[at] = int(c.r8)
	buf[at + 1] = int(c.g8)
	buf[at + 2] = int(c.b8)
	buf[at + 3] = 255

func _process(delta: float) -> void:
	if map == null or not is_instance_valid(player):
		return
	_accum += delta
	var here := GridOverlay.block_at(player.global_position)
	if here == _last and _accum < 1.0 / REFRESH_HZ:
		return
	_accum = 0.0
	_last = here
	refresh()

## Zeichnet den Ausschnitt neu. Öffentlich, damit die Bau-Leiste nach einem
## gesetzten Block sofort aktualisieren kann statt erst beim nächsten Takt.
func refresh() -> void:
	if map == null or not is_instance_valid(player):
		return
	var center := GridOverlay.block_at(player.global_position)
	var x0 := center.x - BLOCKS / 2
	var y0 := center.y - BLOCKS / 2
	var tiles := map.tiles
	var w := Config.MAP_W
	var h := Config.MAP_H

	for py in BLOCKS:
		var y := y0 + py
		var row := py * BLOCKS * 4
		var inside_y := y >= 0 and y < h
		for px in BLOCKS:
			var x := x0 + px
			var o := row + px * 4
			if not inside_y or x < 0 or x >= w:
				# Ausserhalb der Welt: dunkel, damit der Rand sichtbar wird.
				_buf[o] = 26; _buf[o + 1] = 28; _buf[o + 2] = 34; _buf[o + 3] = 255
				continue
			var here := tiles[y * w + x]
			# Randfelder dunkler. Das ist der ganze Unterschied zwischen einer
			# Karte und einem Farbfeld: ohne Kante sind drei gruene Blocks und
			# eine gruene Flaeche dasselbe Bild. Geprueft werden die vier
			# direkten Nachbarn — vier Vergleiche je Punkt, 4096 Punkte,
			# sechsmal je Sekunde.
			var rim := (y > 0 and tiles[(y - 1) * w + x] != here) \
				or (y < h - 1 and tiles[(y + 1) * w + x] != here) \
				or (x > 0 and tiles[y * w + x - 1] != here) \
				or (x < w - 1 and tiles[y * w + x + 1] != here)
			var src: PackedByteArray = _lut_rim if rim else _lut
			var si := (here * LEVELS + Config.hash2(x, y) % LEVELS) * 4
			_buf[o] = src[si]
			_buf[o + 1] = src[si + 1]
			_buf[o + 2] = src[si + 2]
			_buf[o + 3] = 255

	_img.set_data(BLOCKS, BLOCKS, false, Image.FORMAT_RGBA8, _buf)
	_tex.update(_img)
	var c := GridOverlay.chunk_of(center)
	_label.text = "Chunk %d | %d" % [c.x, c.y]
	queue_redraw()

func _draw() -> void:
	if _tex == null:
		return
	var box := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	draw_rect(box.grow(3.0), Color(0.06, 0.07, 0.09, 0.85), true)
	draw_texture_rect(_tex, box, false)

	# Chunk-Gitter: dieselben gelben Linien wie im Spiel, damit sich beides
	# aufeinander beziehen lässt.
	var center := GridOverlay.block_at(player.global_position) if is_instance_valid(player) else Vector2i.ZERO
	var x0 := center.x - BLOCKS / 2
	var y0 := center.y - BLOCKS / 2
	var step := Config.CHUNK * SCALE
	var first_x := (posmod(-x0, Config.CHUNK)) * SCALE
	var first_y := (posmod(-y0, Config.CHUNK)) * SCALE
	# Schwaecher als im Spiel: dort liegt eine Linie ueber 32 Bildpunkten
	# Kachel, hier ueber dreien. Bei gleicher Deckkraft ueberdeckt das Gitter
	# die Karte, die es einteilen soll.
	var grid := Color(GridOverlay.CHUNK_LINE, GridOverlay.CHUNK_LINE.a * 0.45)
	for gx in range(first_x, SIZE, step):
		draw_line(Vector2(gx, 0), Vector2(gx, SIZE), grid, 1.0)
	for gy in range(first_y, SIZE, step):
		draw_line(Vector2(0, gy), Vector2(SIZE, gy), grid, 1.0)

	# Die Figur sitzt immer in der Mitte.
	#
	# Vorher ein weisses Quadrat mit schwarzem Saum — dieselbe Form, die ein
	# Spieler anderswo im Bild fuer eine vergessene Markierung gehalten hat.
	# Eine Raute in der Akzentfarbe des Spiels ist an derselben Stelle
	# eindeutig: sie zeigt nach oben, sie ist warm, und sie sieht nach nichts
	# anderem aus.
	var mid := (Vector2(SIZE, SIZE) * 0.5).round()
	var ring := PackedVector2Array([mid + Vector2(0, -6), mid + Vector2(5, 0),
		mid + Vector2(0, 6), mid + Vector2(-5, 0)])
	draw_colored_polygon(ring, Color(0, 0, 0, 0.70))
	var core := PackedVector2Array([mid + Vector2(0, -4), mid + Vector2(3, 0),
		mid + Vector2(0, 4), mid + Vector2(-3, 0)])
	draw_colored_polygon(core, Color(Palette.UI_ACCENT, 0.98))
	draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -4),
		mid + Vector2(3, 0), mid + Vector2(0, 0), mid + Vector2(-3, 0)]),
		Color(Palette.UI_ACCENT.lightened(0.35), 0.95))
	draw_rect(box, Color(0.85, 0.80, 0.62, 0.75), false, 2.0)

## Farbe eines Bodentyps auf der Minimap — für den Selbsttest.
static func color_of(tile: int) -> Color:
	return COLORS.get(tile, Color8(96, 152, 78))
