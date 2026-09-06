class_name EdgeArt
extends RefCounted
## Kanten, die Höhe zeigen: Felsklippen und Ufer.
##
## Das Eck-Autotiling des Bodens blendet Nachbarn weich ineinander. Für Wiese
## und Waldboden ist das richtig — für Fels und Wasser nicht: dort soll man
## sehen, dass es eine Stufe gibt, statt eines Farbverlaufs.
##
## Wie Pixel-Spiele Höhe erzeugen (Slynyrd, „Top Down Tiles"):
##   * eine WANDFLÄCHE nach unten, weil man von schräg oben schaut
##   * darunter ein SCHLAGSCHATTEN — höchstens eine Kachel lang, und immer
##     gleich lang, egal wie hoch die Wand ist
##   * eine LICHTKANTE oben, wo die Fläche vom Licht angeschnitten wird
## Die Lichtrichtung ist dieselbe wie überall sonst im Spiel: von oben links.
##
## Angesprochen wird über eine 4-Bit-Nachbarmaske. Bit 1 = Norden, 2 = Osten,
## 4 = Süden, 8 = Westen; gesetzt heißt „dort ist der Nachbar ANDERS".

const T := Config.TILE

const N := 1
const E := 2
const S := 4
const W := 8

## Die Wand läuft über die Blockkante hinweg: die obere Hälfte liegt auf der
## Felskachel, die untere auf der Kachel darunter.
##
## Das muss so sein, weil das Eck-Autotiling die Geländegrenze auf das ECKRASTER
## legt — eine halbe Kachel versetzt zum Blockraster. Der Fels läuft dadurch
## schon in der Kachelmitte in Gras aus. Eine Wand nur im unteren Kachelteil
## stünde sichtbar auf Gras. Deckt sie beide Kacheln, verdeckt sie den weichen
## Auslauf und die Kante sitzt dort, wo der Block endet.
const WALL_TOP := 16         ## auf der Felskachel, von unten gerechnet
const WALL_FOOT := 7         ## auf der Kachel darunter
const SHADOW_H := 10         ## Schlagschatten darunter — immer gleich lang
const SHADOW_DX := 2         ## Versatz nach rechts: Licht kommt von links
const BANK_W := 5            ## Uferkante auf dem Land
const DEPTH_W := 7           ## Tiefenband im Wasser

var source: int = -1                    ## Quellen-ID im TileSet
## Drei Ausführungen je Maske. Ohne sie wiederholt sich dieselbe Wand an jeder
## Kachel und die Klippe sieht gestempelt aus.
const VARIANTS := 3

var cliff: Array[Vector2i] = []         ## (Maske * VARIANTS + Ausführung)
var bank: Array[Vector2i] = []          ## Maske -> Kachel (Land am Wasser)
var depth: Array[Vector2i] = []         ## Maske -> Kachel (Wasser am Land)
var foot: Array[Vector2i] = []          ## Wandfuss + Schlagschatten darunter

## Baut den Atlas und hängt ihn in das übergebene TileSet.
static func build(ts: TileSet) -> EdgeArt:
	var e := EdgeArt.new()
	var tiles: Array[Image] = []

	for mask in 16:
		for v in VARIANTS:
			e.cliff.append(_slot(tiles, _cliff_tile(mask, v)))
	for mask in 16:
		e.bank.append(_slot(tiles, _bank_tile(mask)))
	for mask in 16:
		e.depth.append(_slot(tiles, _depth_tile(mask)))
	for v in VARIANTS:
		e.foot.append(_slot(tiles, _foot_tile(v)))

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

# --- Fels ---------------------------------------------------------------

## Die Klippe. Nach Süden hin eine Wand, nach Norden eine Lichtkante, seitlich
## abgesetzte Ränder. Zusammen liest sich das als erhöhte Fläche.
static func _cliff_tile(mask: int, v: int) -> Image:
	var img := Pixel.make(T, T)

	if mask & S:
		_wall(img, T - WALL_TOP, WALL_TOP, true, v)

	if mask & N:
		# Oberkante: erst eine dunkle Trennlinie zum Nachbarn, dann die
		# Lichtkante. Ohne die Trennlinie klebt der harte Felsrand am Gras.
		for x in T:
			var jag := 1 if _rough(x, 91 + v * 7) < 2 else 0
			Pixel.px(img, x, jag, Palette.STONE_DARK.darkened(0.30))
			Pixel.px(img, x, jag + 1, Palette.STONE_LIGHT)
			Pixel.px(img, x, jag + 2, Palette.STONE_LIGHT.lerp(Palette.STONE, 0.45))
			Pixel.px(img, x, jag + 3, Palette.STONE_LIGHT.lerp(Palette.STONE, 0.78))

	if mask & W:
		# Lichtseite: das Licht kommt von links oben.
		for y in T:
			var jag := 1 if _rough(y, 37 + v * 7) < 2 else 0
			Pixel.px(img, jag, y, Palette.STONE_DARK.darkened(0.22))
			Pixel.px(img, jag + 1, y, Palette.STONE_LIGHT.lerp(Palette.STONE, 0.25))
			Pixel.px(img, jag + 2, y, Palette.STONE_LIGHT.lerp(Palette.STONE, 0.70))
	if mask & E:
		# Schattenseite
		for y in T:
			var jag := 1 if _rough(y, 53 + v * 7) < 2 else 0
			Pixel.px(img, T - 1 - jag, y, Palette.STONE_DARK.darkened(0.35))
			Pixel.px(img, T - 2 - jag, y, Palette.STONE_DARK)
			Pixel.px(img, T - 3 - jag, y, Palette.STONE_DARK.lerp(Palette.STONE, 0.55))
	return img

## Die Fortsetzung der Wand auf der Kachel unter dem Fels, dazu der
## Schlagschatten. Er ist immer gleich lang, egal wie hoch die Felsfläche ist —
## so machen es Pixel-Spiele, sonst kippt die Perspektive.
static func _foot_tile(v: int) -> Image:
	var img := Pixel.make(T, T)
	_wall(img, 0, WALL_FOOT, false, v)
	for y in range(WALL_FOOT, WALL_FOOT + SHADOW_H):
		var f := 1.0 - float(y - WALL_FOOT) / SHADOW_H
		var a := 0.46 * f * f
		for x in range(SHADOW_DX, T):
			if a < Pixel.bayer(x, y) * 0.22:
				continue
			Pixel.px(img, x, y, Color(0.05, 0.06, 0.11, a + 0.08))
	return img

## Eine Steinwand von `top` an, `height` Pixel hoch.
##
## Nicht einfach dunkel: oben am Bruch hell, nach unten in den Schatten, dazu
## unregelmässige Risse. Gleichmässige Risse sähen aus wie ein Heizkörper.
static func _wall(img: Image, top: int, height: int, lip: bool, v: int) -> void:
	# Die Wand geht insgesamt über WALL_TOP + WALL_FOOT Pixel; der Verlauf
	# muss über beide Kacheln hinweg durchlaufen, sonst gibt es eine Naht.
	var total := float(WALL_TOP + WALL_FOOT)
	var offset := 0.0 if lip else float(WALL_TOP)
	for y in range(top, top + height):
		var f := (offset + float(y - top)) / total
		Pixel.hline(img, 0, y, T, Palette.STONE.lerp(Palette.STONE_DARK.darkened(0.35), f))

	if lip:
		# Bruchkante: helle Lippe, wo die Deckfläche abbricht.
		for x in T:
			var jag := _rough(x, 17 + v * 7) % 2
			Pixel.px(img, x, top - jag, Palette.STONE_LIGHT)
			Pixel.px(img, x, top - jag + 1, Palette.STONE_LIGHT.lerp(Palette.STONE, 0.55))

	# Waagerechte Schichtung: Fels bricht in Lagen, das trägt mehr zur Wirkung
	# bei als viele senkrechte Striche.
	if lip:
		var band := top + int(height * 0.55)
		for x in T:
			if _rough(x, 61 + v * 7) < 6:
				Pixel.px(img, x, band, Palette.STONE_DARK.darkened(0.18))

	# Risse: wenige und ungleich lang. Ein Riss je rund zwölf Pixel — bei
	# jedem vierten sähe die Wand aus wie ein Lattenzaun.
	for x in T:
		if _hash(x + v * 101) % 12 != 0:
			continue
		var deep := Palette.STONE_DARK.darkened(0.40)
		var lit := Palette.STONE.lerp(Palette.STONE_LIGHT, 0.25)
		# Der Riss läuft IMMER bis zur Unterkante durch, nur sein Anfang wandert.
		# Sonst brechen die Risse an der Kachelgrenze ab und der Wandfuss
		# bekommt eine eigene Reihe Striche, die zu nichts gehört.
		var start := top + (0 if not lip else 2 + _rough(x, 29 + v * 7))
		var h := top + height - start
		if h < 2:
			continue
		var wide := 1 + (_rough(x, 83 + v * 7) % 2)
		for i in wide:
			Pixel.vline(img, x + i, start, h, deep)
		# Lichtkante rechts vom Riss — dort trifft das Licht von links wieder auf.
		if x + wide < T:
			Pixel.vline(img, x + wide, start, h, lit)

	if not lip:
		# Fuss der Wand: dunkle Abschlusslinie zum Boden hin.
		Pixel.hline(img, 0, top + height - 1, T, Palette.STONE_DARK.darkened(0.55))

## Kleiner Streuwert 0..7 — für unregelmässige Kanten.
static func _rough(v: int, salt: int) -> int:
	return _hash(v * 31 + salt) % 8

static func _hash(v: int) -> int:
	var h := v * 73856093
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

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
