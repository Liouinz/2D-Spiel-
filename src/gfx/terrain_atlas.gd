class_name TerrainAtlas
extends RefCounted
## Baut aus den Vollkacheln eines Bodentyps einen Atlas für Godots
## Terrain-Autotiling im Eck-Modus.
##
## Godot waehlt im Modus TERRAIN_MODE_MATCH_CORNERS eine Kachel anhand der vier
## Ecken aus. Es gibt also 15 verwendbare Eckmasken (1..15) — Maske 0 bleibt leer.
## Die Form einer Teilkachel entsteht durch bilineare Interpolation der vier
## Eckwerte; die Schwelle wird gedithert, damit die Kante ausgefranst bleibt
## statt mathematisch glatt zu wirken.
##
## Bitfolge der Maske: 0 = oben links, 1 = oben rechts, 2 = unten rechts,
## 3 = unten links — genau die Reihenfolge, die Godot erwartet.

const T := Config.TILE
const COLS := 8
const PARTIAL := 15          ## Masken 0..14 belegen die Plaetze 0..14
const FULL_START := PARTIAL  ## ab hier liegen die Vollkacheln (Maske 15)

## `variants` ist TileArt.base[typ]: SHADES * VARIANTS Vollkacheln.
## `hard` = gebaute Fläche: eckige Quadranten statt runder Formen. Für die
## drei Naturböden wird das nicht gebraucht, die Möglichkeit bleibt.
## -> {"texture", "slots": Array[Vector2i], "full_start": int}
static func build(variants: Array, rng: RandomNumberGenerator, hard: bool = false) -> Dictionary:
	var full_count := variants.size()
	var total := PARTIAL + full_count
	var rows := int(ceil(float(total) / COLS))
	var img := Pixel.make(COLS * T, rows * T)
	var slots: Array[Vector2i] = []

	# Teilkacheln: Masken 0..14 aus der mittleren Helligkeitsstufe.
	# Maske 0 ist die einzeln stehende Kachel — ohne sie würde eine Kachel ohne
	# gleichartige Nachbarn schlicht verschwinden.
	var mid := TileArt.VARIANTS  # Beginn der mittleren Stufe im flachen Array
	for i in PARTIAL:
		var mask := i
		var src: Image = variants[mid + (mask * 5) % TileArt.VARIANTS]
		var tile := _quads(src, mask, rng) if hard else _shape(src, mask, rng)
		var pos := _slot_pos(i)
		img.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), pos * T)
		slots.append(pos)

	# Vollkacheln (Maske 15) in allen Helligkeitsstufen und Varianten
	for i in full_count:
		var src: Image = variants[i]
		var pos := _slot_pos(PARTIAL + i)
		img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), pos * T)
		slots.append(pos)

	return {"texture": Pixel.tex(img), "slots": slots, "full_start": FULL_START}

static func _slot_pos(index: int) -> Vector2i:
	return Vector2i(index % COLS, index / COLS)

## Schneidet aus einer Vollkachel die von der Eckmaske abgedeckte Flaeche aus.
static func _shape(src: Image, mask: int, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(T, T)
	if mask == 0:
		return _blob(src, rng)
	var tl := float(mask & 1)
	var tr := float((mask >> 1) & 1)
	var br := float((mask >> 2) & 1)
	var bl := float((mask >> 3) & 1)
	for y in T:
		for x in T:
			var u := (x + 0.5) / float(T)
			var w := (y + 0.5) / float(T)
			var v := tl * (1.0 - u) * (1.0 - w) + tr * u * (1.0 - w) + br * u * w + bl * (1.0 - u) * w
			# Gedithertes Schwellwertband -> gestreute Pixel statt glatter Kurve
			var threshold := 0.5 + (Pixel.bayer(x, y) - 0.5) * 0.30 + rng.randf_range(-0.06, 0.06)
			if v > threshold:
				img.set_pixel(x, y, src.get_pixel(x, y))
	_rim(img)
	return img

## Gebaute Fläche: die vier Viertel werden ganz oder gar nicht gefüllt, die
## Innenkanten nur leicht aufgeraut.
static func _quads(src: Image, mask: int, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(T, T)
	var half := T / 2
	var origin := [Vector2i(0, 0), Vector2i(half, 0), Vector2i(half, half), Vector2i(0, half)]
	if mask == 0:
		# Einzeln stehende Kachel: kleines Feld in der Mitte
		for y in range(half / 2, T - half / 2):
			for x in range(half / 2, T - half / 2):
				img.set_pixel(x, y, src.get_pixel(x, y))
	else:
		for c in 4:
			if not (mask & (1 << c)):
				continue
			var o: Vector2i = origin[c]
			for y in range(o.y, o.y + half):
				for x in range(o.x, o.x + half):
					img.set_pixel(x, y, src.get_pixel(x, y))
	_roughen(img, src, rng)
	_rim(img)
	return img

## Verschiebt einzelne Pixel an der Innenkante, damit die Quadranten nicht wie
## mit dem Lineal geschnitten wirken. Der Kachelrand bleibt unangetastet.
static func _roughen(img: Image, src: Image, rng: RandomNumberGenerator) -> void:
	var copy := Image.create_from_data(T, T, false, Pixel.FMT, img.get_data())
	for y in range(1, T - 1):
		for x in range(1, T - 1):
			var filled := copy.get_pixel(x, y).a > 0.0
			var contact := false
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if (copy.get_pixel(x + o.x, y + o.y).a > 0.0) != filled:
					contact = true
					break
			if not contact:
				continue
			if filled and rng.randf() < 0.28:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif not filled and rng.randf() < 0.18:
				img.set_pixel(x, y, src.get_pixel(x, y))

## Freistehende Kachel: ein runder Fleck in der Mitte.
static func _blob(src: Image, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(T, T)
	var c := T * 0.5
	for y in T:
		for x in T:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / (T * 0.42)
			var threshold := 1.0 + (Pixel.bayer(x, y) - 0.5) * 0.34 + rng.randf_range(-0.06, 0.06)
			if d < threshold:
				img.set_pixel(x, y, src.get_pixel(x, y))
	_rim(img)
	return img

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
