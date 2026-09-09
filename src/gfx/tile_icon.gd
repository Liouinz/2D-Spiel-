class_name TileIcon
extends RefCounted
## Materialbild für die Oberfläche: ein Stück echter Boden statt eines Symbols.
##
## Ein Feld im Inventar oder in der Bauleiste zeigt vier aneinandergelegte
## Bodenkacheln — dieselben Bilder, die auch auf der Karte liegen. Damit
## entspricht jedes Feld exakt dem Material, das ein Klick in der Welt erzeugt,
## nur als grösseres und ruhigeres Stück Fläche.
##
## Die Kantenlänge ist ein ganzzahliges Vielfaches der Kachelgrösse und wird in
## der Oberfläche 1:1 gezeichnet. Das ist der Grund für diese Klasse: eine
## 32er-Kachel in ein 48er-Feld gestreckt macht manche Bildpunkte zwei breit
## und manche einen — genau die verzerrten, angeschnittenen Vorschauen, die es
## hier nicht geben soll.

## Kacheln je Kante. Vier Kacheln zeigen die Struktur des Materials, ohne dass
## das Feld unruhig wird.
const TILES := 2

## Kantenlänge in Bildpunkten — 64 bei 32er-Kacheln.
const SIZE := Config.TILE * TILES

## Ein Bild je Bodentyp, in der Reihenfolge von MapData.Tile.
static func build(art: TileArt) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for t in MapData.Tile.COUNT:
		out.append(_one(art, t))
	return out

static func _one(art: TileArt, tile: int) -> Texture2D:
	var img := Pixel.make(SIZE, SIZE)
	# Mittlere Helligkeitsstufe — dieselbe, die auf der Karte den Grundton
	# bildet. Vier verschiedene Varianten daraus, damit die Fläche nicht wie
	# viermal dasselbe Bild aussieht; weil die Kacheln nahtlos gezeichnet sind,
	# ist zwischen ihnen trotzdem keine Naht zu sehen.
	var middle: int = TileArt.MID
	var list: Array = art.base[tile]
	for i in TILES * TILES:
		var src: Image = list[middle + i % TileArt.VARIANTS]
		img.blit_rect(src, Rect2i(0, 0, Config.TILE, Config.TILE),
			Vector2i(i % TILES, i / TILES) * Config.TILE)
	_emboss(img)
	return Pixel.tex(img)

## Macht aus der Flaeche einen Brocken Material.
##
## Ein 64 x 64 grosses Stueck Gras ist in einem Feld der Bauleiste ein gruenes
## Rechteck — technisch richtig, aber es sagt nichts. Was fehlt, ist eine FORM:
## eine Lichtkante oben links, ein Schatten unten rechts, abgerundete Ecken.
## Damit liest man ein Stueck Boden, das man aufheben und hinlegen kann, und
## nicht eine Farbprobe.
##
## Dieselbe Lichtrichtung wie ueberall sonst im Spiel — oben links.
static func _emboss(img: Image) -> void:
	var n := SIZE
	# Lichtkante oben und links.
	for i in n:
		Pixel.px(img, i, 0, Color(1, 1, 1, 0.26))
		Pixel.px(img, i, 1, Color(1, 1, 1, 0.12))
		Pixel.px(img, 0, i, Color(1, 1, 1, 0.22))
		Pixel.px(img, 1, i, Color(1, 1, 1, 0.10))
	# Schattenkante unten und rechts.
	for i in n:
		Pixel.px(img, i, n - 1, Color(0, 0, 0, 0.34))
		Pixel.px(img, i, n - 2, Color(0, 0, 0, 0.16))
		Pixel.px(img, n - 1, i, Color(0, 0, 0, 0.30))
		Pixel.px(img, n - 2, i, Color(0, 0, 0, 0.14))
	# Ecken abrunden: einen Bildpunkt je Ecke wegnehmen. Ein Quadrat mit
	# scharfen Ecken sitzt in einem Feld mit runden Ecken wie eingeklemmt.
	for c: Vector2i in [Vector2i(0, 0), Vector2i(n - 1, 0),
			Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
		img.set_pixelv(c, Color(0, 0, 0, 0))
