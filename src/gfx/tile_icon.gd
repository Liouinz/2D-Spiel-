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
	var middle: int = TileArt.VARIANTS
	var list: Array = art.base[tile]
	for i in TILES * TILES:
		var src: Image = list[middle + i % TileArt.VARIANTS]
		img.blit_rect(src, Rect2i(0, 0, Config.TILE, Config.TILE),
			Vector2i(i % TILES, i / TILES) * Config.TILE)
	return Pixel.tex(img)
