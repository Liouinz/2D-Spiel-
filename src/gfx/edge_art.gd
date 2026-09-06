class_name EdgeArt
extends RefCounted
## Uferkanten zwischen Land und Wasser.
##
## Das Eck-Autotiling des Bodens blendet Nachbarn weich ineinander. Für den
## Übergang Gras → Sand ist das richtig. Für die Uferlinie nicht: dort soll man
## sehen, wo das Land aufhört, statt eines Farbverlaufs.
##
## Zwei Kachelsätze:
##   * Uferkante auf dem LAND — das Land hört sichtbar auf
##   * Tiefenband im WASSER — direkt am Ufer fällt der Grund weg
##
## Angesprochen über eine 4-Bit-Nachbarmaske. Bit 1 = Norden, 2 = Osten,
## 4 = Süden, 8 = Westen; gesetzt heisst „dort ist der Nachbar anders".

const T := Config.TILE

const N := 1
const E := 2
const S := 4
const W := 8

const BANK_W := 5            ## Uferkante auf dem Land
const DEPTH_W := 7           ## Tiefenband im Wasser

var source: int = -1                    ## Quellen-ID im TileSet
## Drei Ausführungen je Maske. Ohne sie wiederholt sich dieselbe Wand an jeder
## Kachel und das Ufer sieht gestempelt aus.

var bank: Array[Vector2i] = []          ## Maske -> Kachel (Land am Wasser)
var depth: Array[Vector2i] = []         ## Maske -> Kachel (Wasser am Land)

## Baut den Atlas und hängt ihn in das übergebene TileSet.
static func build(ts: TileSet) -> EdgeArt:
	var e := EdgeArt.new()
	var tiles: Array[Image] = []

	for mask in 16:
		e.bank.append(_slot(tiles, _bank_tile(mask)))
	for mask in 16:
		e.depth.append(_slot(tiles, _depth_tile(mask)))

	var cols := 8
	var rows := int(ceil(float(tiles.size()) / cols))
	var atlas := Pixel.make(cols * T, rows * T)
	for i in tiles.size():
		var pos := Vector2i(i % cols, i / cols)
		atlas.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()), pos * T)

	# Textur und Kachelgröße MÜSSEN vor create_tile stehen: sonst hält die
	# Quelle jede Kachel für ausserhalb der Textur liegend und legt keine an.
	var src := TileSetAtlasSource.new()
	src.texture = Pixel.tex(atlas)
	src.texture_region_size = Vector2i(T, T)
	for i in tiles.size():
		src.create_tile(Vector2i(i % cols, i / cols))
	e.source = ts.add_source(src)
	return e

static func _slot(tiles: Array[Image], img: Image) -> Vector2i:
	var i := tiles.size()
	tiles.append(img)
	return Vector2i(i % 8, i / 8)

# --- Wasser -------------------------------------------------------------

## Uferkante auf dem LAND: das Land hört sichtbar auf, statt zu verlaufen.
static func _bank_tile(mask: int) -> Image:
	return _falloff(mask, BANK_W, Color(0.10, 0.09, 0.07), 0.60)

## Tiefenband im WASSER: direkt am Ufer fällt der Grund weg.
static func _depth_tile(mask: int) -> Image:
	return _falloff(mask, DEPTH_W, Palette.WATER_DEEP.darkened(0.45), 0.88)

## Ein Band, das vom Rand nach innen ausläuft.
##
## Statt einer gezogenen Linie wird je Pixel der Abstand zur nächsten
## „anderen" Seite gerechnet und daraus die Deckkraft. Zwei Vorteile: an einer
## Ecke laufen die Bänder von selbst ineinander statt ein L zu bilden, und der
## Übergang nach innen ist weich. Gedithert wird über dieselbe 4 × 4-Matrix wie
## überall sonst — ein glatter Verlauf sähe in Pixelgrafik falsch aus.
static func _falloff(mask: int, width: int, tint: Color, strength: float) -> Image:
	var img := Pixel.make(T, T)
	if mask == 0:
		return img
	var w := float(width)
	for py in T:
		for px in T:
			var d := 999.0
			if mask & N:
				d = minf(d, py + 0.5)
			if mask & S:
				d = minf(d, T - 0.5 - py)
			if mask & W:
				d = minf(d, px + 0.5)
			if mask & E:
				d = minf(d, T - 0.5 - px)
			if d >= w:
				continue
			# Am Rand voll, nach innen quadratisch auslaufend.
			var f := 1.0 - d / w
			var a := strength * f * f
			# Dithern: der Schwellwert wandert je Pixel, dadurch entsteht ein
			# gestreuter Übergang statt einer Stufe.
			if a < Pixel.bayer(px, py) * 0.30:
				continue
			img.set_pixelv(Vector2i(px, py), Color(tint.r, tint.g, tint.b, minf(a + 0.10, 0.85)))
	return img
