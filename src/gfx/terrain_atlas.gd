class_name TerrainAtlas
extends RefCounted
## Baut aus den Vollkacheln eines Bodentyps einen Atlas für Godots
## Terrain-Autotiling im Eck-Modus.
##
## Godot waehlt im Modus TERRAIN_MODE_MATCH_CORNERS eine Kachel anhand der vier
## Ecken aus. Es gibt 16 Eckmasken (0..15), und alle 16 werden gebraucht:
## Maske 0 ist die einzeln stehende Kachel, Maske 15 die ringsum umgebene mit
## einer Oeffnung.
## Die Form einer Teilkachel entsteht durch bilineare Interpolation der vier
## Eckwerte. Die Schwelle wird dabei mit RAUSCHEN verschoben, nicht gedithert.
##
## Vorher lag hier eine geordnete 4x4-Bayer-Matrix. Die ist regelmässig — und
## genau so sah die Kante auch aus: ein Schachbrett aus Einzelpixeln, quer über
## jeden Übergang zwischen zwei Böden. Bei Zoom 1,5 ging das unter, bei Zoom 2
## war es das Künstlichste im ganzen Bild. Zusammenhängendes Rauschen ergibt
## stattdessen Zungen und Buchten, wie von Hand gesetzt.
##
## Dazu gibt es jede Maske in mehreren Ausführungen. Vorher existierte je
## Eckmaske genau EINE Kachel; jede Küstenlinie im Spiel bestand damit aus
## fünfzehn immer gleichen Bausteinen. Welche Ausführung ein Feld bekommt,
## entscheidet sein Streuwert — dadurch ist es ortsfest und ändert sich nicht
## beim Nachladen eines Chunks.
##
## Bitfolge der Maske: 0 = oben links, 1 = oben rechts, 2 = unten rechts,
## 3 = unten links — genau die Reihenfolge, die Godot erwartet.

const T := Config.TILE
const COLS := 8

## Eckmasken 0..15. Die 15 ist der Sonderfall und der Grund, warum sie hier
## überhaupt steht: ein Feld, das RINGSUM von einem Boden umgeben ist, aber
## selbst nicht dazugehört.
##
## Vorher endete die Tabelle bei 14, und Maske 15 griff damit hinter die
## Teilkacheln — in die Vollkacheln. Ein leeres Feld zwischen zwei Sandflächen
## bekam also eine volle Sandkachel und die Lücke verschwand:
##
##   [SAND][SAND][ leer ][SAND][SAND]   ->   eine durchgehende Sandfläche
##
## Genauso war jeder einzeln entfernte Block mitten in einer Fläche unsichtbar:
## acht Nachbarn ringsum, Maske 15, Vollkachel. Man klickte, der Block war in
## der Karte weg — und man sah es nicht.
##
## Maske 15 bekommt deshalb eine eigene Form: gefüllt, aber mit einer Öffnung,
## durch die der Boden darunter zu sehen bleibt.
const PARTIAL := 16

## Ausführungen je Maske. Drei reichen: die Kante ist ohnehin nur ein Streifen
## am Rand einer Fläche, und mehr Ausführungen kosten Atlasfläche für einen
## Unterschied, den niemand mehr bemerkt.
##
## Bei Maske 15 bedeuten dieselben drei Plätze etwas anderes: nicht drei
## zufällige Ausführungen, sondern drei RICHTUNGEN der Öffnung (siehe HOLE_*).
## Welche gilt, entscheidet dort die Lage der Nachbarn statt des Streuwerts.
const EDGE_VARIANTS := 3

## Öffnungsformen für Maske 15.
const HOLE_ROUND := 0        ## ringsum umgeben: rundes Loch
const HOLE_VERTICAL := 1     ## Boden links und rechts: die Lücke läuft senkrecht
const HOLE_HORIZONTAL := 2   ## Boden oben und unten: die Lücke läuft waagerecht

## Halbe Öffnungsbreite, bezogen auf die halbe Kachel. 0,44 ergibt bei einer
## 32er-Kachel eine Öffnung von 14 Bildpunkten — bei Zoom 2 also 28 auf dem
## Bildschirm. Das sieht man, und man sieht es als Absicht.
const HOLE := 0.44

## Plätze 0 .. PARTIAL * EDGE_VARIANTS - 1 sind Teilkacheln, danach kommen die
## Vollkacheln (Maske 15).
const FULL_START := PARTIAL * EDGE_VARIANTS

## Wie der Rand einer Teilkachel behandelt wird.
##
## SOFT   eine Spur dunkler — der Saum, mit dem Sand auf Gras aufliegt.
## SHORE  Uferlinie: aussen ein heller Schaumsaum, nach innen ein dunkleres
##        Tiefenband. Damit trägt die Wasserkachel ihre eigene Küstenlinie,
##        statt sie aus einer zweiten Schicht danebenlegen zu müssen — und
##        zwei getrennt erzeugte Bilder können sich nicht mehr widersprechen.
enum Rim { SOFT, SHORE }

## `variants` ist TileArt.base[typ]: SHADES * VARIANTS Vollkacheln.
## -> {"texture", "slots": Array[Vector2i], "full_start": int}
static func build(variants: Array, rng: RandomNumberGenerator,
		rim: int = Rim.SOFT) -> Dictionary:
	var full_count := variants.size()
	var total := FULL_START + full_count
	var rows := int(ceil(float(total) / COLS))
	var img := Pixel.make(COLS * T, rows * T)
	var slots: Array[Vector2i] = []

	# Teilkacheln: Masken 0..15 aus der mittleren Helligkeitsstufe.
	# Maske 0 ist die einzeln stehende Kachel — ohne sie würde eine Kachel ohne
	# gleichartige Nachbarn schlicht verschwinden.
	var mid := TileArt.MID
	for mask in PARTIAL:
		for v in EDGE_VARIANTS:
			# Nachgerechnet: `(mask * 5 + v * 3) % 10` erreichte ueber alle 16
			# Masken und 3 Varianten nur {0,1,3,5,6,8} — vier der zehn
			# gezeichneten Varianten kamen an Kanten NIE vor. Mit einem
			# Schritt, der zu 10 teilerfremd ist, laufen alle durch.
			var src: Image = variants[mid + (mask * EDGE_VARIANTS + v) % TileArt.VARIANTS]
			var tile: Image
			if mask == 15:
				# Umgeben, aber nicht dazugehörend: gefüllt mit Öffnung.
				tile = _hole(src, v, rng)
			else:
				tile = _shape(src, mask, rng)
			if rim == Rim.SHORE:
				_shore(tile)
			var pos := _slot_pos(mask * EDGE_VARIANTS + v)
			img.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), pos * T)
			slots.append(pos)

	# Vollkacheln (Maske 15) in allen Helligkeitsstufen und Varianten
	for i in full_count:
		var src: Image = variants[i]
		var pos := _slot_pos(FULL_START + i)
		img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), pos * T)
		slots.append(pos)

	return {"texture": Pixel.tex(img), "slots": slots, "full_start": FULL_START}

static func _slot_pos(index: int) -> Vector2i:
	return Vector2i(index % COLS, index / COLS)

## Rauschfeld für die Kantenform. Frequenz und Stärke sind so gewählt, dass
## eine Bucht ungefähr vier bis acht Pixel breit wird — fein genug für eine
## 32er-Kachel, grob genug, dass man Form statt Körnung sieht.
static func _edge_noise(seed_value: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.13
	n.fractal_octaves = 2
	return n

## Schneidet aus einer Vollkachel die von der Eckmaske abgedeckte Flaeche aus.
static func _shape(src: Image, mask: int, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(T, T)
	if mask == 0:
		return _blob(src, rng)
	var noise := _edge_noise(rng.randi())
	var tl := float(mask & 1)
	var tr := float((mask >> 1) & 1)
	var br := float((mask >> 2) & 1)
	var bl := float((mask >> 3) & 1)
	for y in T:
		for x in T:
			var u := (x + 0.5) / float(T)
			var w := (y + 0.5) / float(T)
			var v := tl * (1.0 - u) * (1.0 - w) + tr * u * (1.0 - w) + br * u * w + bl * (1.0 - u) * w
			# Zusammenhängendes Rauschen statt geordnetem Dither: die Kante
			# bekommt Zungen und Buchten statt eines Schachbretts.
			var threshold := 0.5 + noise.get_noise_2d(x, y) * 0.22
			if v > threshold:
				img.set_pixel(x, y, src.get_pixel(x, y))
	_rim(img)
	return img

## Maske 15: das Feld ist ringsum umgeben, gehört aber selbst nicht dazu.
##
## Gefüllt bis auf eine Öffnung in der Mitte, durch die der Boden darunter zu
## sehen bleibt. Die Richtung der Öffnung folgt der Lage der Nachbarn: liegt
## der Boden links und rechts, läuft die Lücke senkrecht weiter und die Öffnung
## ist ein senkrechter Schlitz. Ein rundes Loch wäre dort falsch — es sähe aus
## wie ein einzelnes Loch statt wie ein durchgehender Spalt.
static func _hole(src: Image, kind: int, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(T, T)
	var noise := _edge_noise(rng.randi())
	var c := T * 0.5
	for y in T:
		for x in T:
			var dx := (x + 0.5 - c) / c
			var dy := (y + 0.5 - c) / c
			var m := 0.0
			match kind:
				HOLE_VERTICAL: m = absf(dx)
				HOLE_HORIZONTAL: m = absf(dy)
				_: m = Vector2(dx, dy).length()
			# Dieselbe Rauschschwelle wie an jeder anderen Kante: die Öffnung
			# soll aussehen wie ausgewaschen, nicht wie ausgestanzt.
			if m > HOLE + noise.get_noise_2d(x, y) * 0.13:
				img.set_pixel(x, y, src.get_pixel(x, y))
	_rim(img)
	return img

## Freistehende Kachel: ein runder Fleck in der Mitte.
static func _blob(src: Image, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(T, T)
	var c := T * 0.5
	var noise := _edge_noise(rng.randi())
	for y in T:
		for x in T:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / (T * 0.42)
			var threshold := 1.0 + noise.get_noise_2d(x, y) * 0.26
			if d < threshold:
				img.set_pixel(x, y, src.get_pixel(x, y))
	_rim(img)
	return img

## Uferlinie in die Kachel hinein: aussen Schaum, nach innen Tiefe.
##
## Gerechnet wird über den Abstand zum Rand der FORM (nicht der Kachel): die
## äusserste Reihe wird zum Schaum hin aufgehellt, die beiden darunter
## abgedunkelt. Der Kachelrand selbst zählt nicht als Formrand — sonst läge an
## jeder Kachelgrenze mitten im Wasser ein Schaumstreifen.
static func _shore(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(9)
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= 0.0:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + o.x
				var ny := y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue                      # Kachelrand: keine Küste
				if img.get_pixel(nx, ny).a <= 0.0:
					dist[y * w + x] = 0
					break
	# Zwei Ausbreitungsschritte: daraus werden die Abstände 1 und 2.
	for step in 2:
		var copy := dist.duplicate()
		for y in h:
			for x in w:
				if copy[y * w + x] != 9 or img.get_pixel(x, y).a <= 0.0:
					continue
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + o.x
					var ny := y + o.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if copy[ny * w + nx] == step:
						dist[y * w + x] = step + 1
						break
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			match dist[y * w + x]:
				0: img.set_pixel(x, y, c.lerp(Palette.WATER_FOAM, 0.62))
				1: img.set_pixel(x, y, c.lerp(Palette.WATER_FOAM, 0.24))
				2: img.set_pixel(x, y, c.darkened(0.14))

## Dunkelt die innerste Pixelreihe an der Schnittkante leicht ab. An den
## Kachelraendern passiert das nicht, dort waere sonst das Raster sichtbar.
static func _rim(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := Image.create_from_data(w, h, false, Pixel.FMT, img.get_data())
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a <= 0.0:
				continue
			var edge := false
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + o.x
				var ny := y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue     # Kachelrand: kein Saum
				if src.get_pixel(nx, ny).a <= 0.0:
					edge = true
					break
			if edge:
				var c := src.get_pixel(x, y)
				img.set_pixel(x, y, c.darkened(0.16))
