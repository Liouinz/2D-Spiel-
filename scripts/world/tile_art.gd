class_name TileArt
extends RefCounted

## Erzeugt den kompletten Tile-Atlas zur Laufzeit: für jede Material-Art alle
## 47 Blob-Formen × mehrere Varianten. Boden-Arten sind deckend und bekommen
## eine Kantenbeleuchtung (oben hell, unten Schatten); Auflage-Arten (Wasser,
## Laubdach, Lava) sind transparent, werden an offenen Kanten abgerundet und
## erhalten eine Silhouetten-Kontur — dadurch verliert das Bild die harte
## Quadrat-Optik, ohne dass ein einziges Bild-Asset nötig wäre.
##
## Gearbeitet wird auf rohen RGBA8-Bytepuffern (16×16 = 1024 Byte) statt über
## Image.set_pixel: derselbe Atlas entsteht so um ein Vielfaches schneller.

const TILE := 16
const VARIANTS := 3

enum {
	K_SEABED,
	K_SAND,
	K_GRASS,
	K_ROCK,
	K_WATER,
	K_WATER_DEEP,
	K_CANOPY,
	K_LAVA,
}
const KIND_COUNT := 8

## Deckende Böden vs. transparente Auflagen.
const OPAQUE_KINDS := [K_SEABED, K_SAND, K_GRASS, K_ROCK]

const ROUNDING := {
	K_WATER: 5.2,
	K_WATER_DEEP: 6.0,
	K_CANOPY: 4.4,
	K_LAVA: 4.8,
}
const NOTCH := {
	K_WATER: 3.4,
	K_WATER_DEEP: 3.8,
	K_CANOPY: 3.0,
	K_LAVA: 3.2,
}
const RIM_COLOR := {
	K_WATER: Palette.WATER_FOAM,
	K_WATER_DEEP: Color(0.34, 0.58, 0.80),
	K_CANOPY: Palette.CANOPY_LIGHT,
	K_LAVA: Palette.LAVA_HOT,
}
const RIM_STRENGTH := {
	K_WATER: 0.42,
	K_WATER_DEEP: 0.30,
	K_CANOPY: 0.34,
	K_LAVA: 0.55,
}


static func build_tile_set() -> TileSet:
	var configs := TileShapes.config_count()
	var img := Image.create(configs * VARIANTS * TILE, KIND_COUNT * TILE, false, Image.FORMAT_RGBA8)
	for kind in KIND_COUNT:
		var opaque := OPAQUE_KINDS.has(kind)
		for variant in VARIANTS:
			var base := _material(kind, variant)
			for config in configs:
				var mask := TileShapes.config_mask(config)
				var buf := base.duplicate()
				if opaque:
					_shape_opaque(buf, mask)
				else:
					_shape_overlay(buf, mask, kind)
				var tile := Image.create_from_data(TILE, TILE, false, Image.FORMAT_RGBA8, buf)
				img.blit_rect(
					tile,
					Rect2i(0, 0, TILE, TILE),
					Vector2i((config * VARIANTS + variant) * TILE, kind * TILE)
				)
	var src := TileSetAtlasSource.new()
	# Ohne Padding: Die Tiles werden nearest gefiltert, brauchen also keine
	# Randerweiterung — und jedes create_tile() spart sich den kompletten
	# Neuaufbau der Padding-Textur.
	src.use_texture_padding = false
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for kind in KIND_COUNT:
		for config in configs:
			for variant in VARIANTS:
				src.create_tile(Vector2i(config * VARIANTS + variant, kind))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts


## Atlas-Koordinate für Art + Form + Variante.
static func atlas_coords(kind: int, config: int, variant: int) -> Vector2i:
	return Vector2i(config * VARIANTS + (variant % VARIANTS), kind)


# --- Basismaterial ----------------------------------------------------------

static func _material(kind: int, variant: int) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(TILE * TILE * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind * 7919 + variant * 613 + 17
	var base := _base_color(kind)
	var grain := _grain(kind)
	for y in TILE:
		for x in TILE:
			_put(buf, x, y, Palette.shade(base, rng.randf_range(-grain, grain)))
	match kind:
		K_SEABED:
			for i in 7:
				_shade(buf, rng.randi_range(0, 15), rng.randi_range(0, 15), -0.05)
		K_SAND:
			for i in 6:
				var x := rng.randi_range(0, 14)
				var y := rng.randi_range(0, 15)
				_shade(buf, x, y, -0.07)
				_shade(buf, x + 1, y, -0.04)
			for i in 2:
				var y := rng.randi_range(3, 12)
				for x in range(rng.randi_range(1, 5), rng.randi_range(8, 15)):
					_shade(buf, x, y, 0.05)
		K_GRASS:
			# Wenige, zurückhaltende Halme. Mehr Details wirken auf einer
			# grossen Fläche nicht reicher, sondern nur unruhig.
			for i in 5:
				var x := rng.randi_range(1, 14)
				var y := rng.randi_range(3, 13)
				_put(buf, x, y, Palette.shade(Palette.GRASS_LIGHT, -0.02))
				_put(buf, x, y - 1, Palette.shade(Palette.GRASS_LIGHT, -0.07))
			for i in 3:
				_shade(buf, rng.randi_range(0, 15), rng.randi_range(0, 15), -0.035)
		K_ROCK:
			for i in 4:
				var x := rng.randi_range(2, 12)
				var y := rng.randi_range(2, 12)
				for step in rng.randi_range(2, 4):
					_put(buf, mini(x + step, 15), mini(y + step, 15), Palette.ROCK_DARK)
			for i in 5:
				_put(buf, rng.randi_range(0, 15), rng.randi_range(0, 15), Palette.ROCK_LIGHT)
		K_WATER, K_WATER_DEEP:
			for i in 3:
				var y := rng.randi_range(2, 13)
				var x0 := rng.randi_range(1, 8)
				for x in range(x0, mini(x0 + rng.randi_range(3, 6), 15)):
					_shade(buf, x, y, 0.055)
		K_CANOPY:
			# Drei weiche Kronenballen pro Kachel — genug, damit ein Wald
			# lebendig wirkt, wenig genug, dass er nicht flimmert.
			for i in 3:
				var cx := rng.randi_range(3, 12)
				var cy := rng.randi_range(3, 11)
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						if dx * dx + dy * dy <= 6:
							_put(buf, cx + dx, cy + dy, Palette.shade(Palette.CANOPY_LIGHT, -0.02))
						elif dx * dx + dy * dy <= 9:
							_shade(buf, cx + dx, cy + dy, 0.02)
			for i in 3:
				_shade(buf, rng.randi_range(0, 15), rng.randi_range(9, 15), -0.05)
		K_LAVA:
			for i in 5:
				var x := rng.randi_range(1, 13)
				var y := rng.randi_range(0, 15)
				_put(buf, x, y, Palette.LAVA_HOT)
				_put(buf, x + 1, y, Palette.shade(Palette.LAVA_HOT, -0.12))
	return buf


static func _base_color(kind: int) -> Color:
	match kind:
		K_SEABED: return Palette.SEABED_DEEP
		K_SAND: return Palette.SAND
		K_GRASS: return Palette.GRASS
		K_ROCK: return Palette.ROCK
		K_WATER: return Palette.WATER_SHALLOW
		K_WATER_DEEP: return Palette.WATER_DEEP
		K_CANOPY: return Palette.CANOPY
		K_LAVA: return Palette.LAVA
	return Color.MAGENTA


static func _grain(kind: int) -> float:
	match kind:
		K_WATER, K_WATER_DEEP: return 0.016
		K_GRASS: return 0.020
		K_CANOPY: return 0.024
		K_LAVA: return 0.05
	return 0.030


# --- Formgebung -------------------------------------------------------------

## Deckende Böden: nur Kantenbeleuchtung. Eine offene Kante wird oben heller
## und unten dunkler — dadurch liest man Höhe und Trennung sofort.
static func _shape_opaque(buf: PackedByteArray, mask: int) -> void:
	var n := TileShapes.has_bit(mask, TileShapes.N)
	var e := TileShapes.has_bit(mask, TileShapes.E)
	var s := TileShapes.has_bit(mask, TileShapes.S)
	var w := TileShapes.has_bit(mask, TileShapes.W)
	if not n:
		for x in TILE:
			_shade(buf, x, 0, 0.11)
			_shade(buf, x, 1, 0.05)
	if not s:
		for x in TILE:
			_shade(buf, x, TILE - 1, -0.15)
			_shade(buf, x, TILE - 2, -0.07)
	if not w:
		for y in TILE:
			_shade(buf, 0, y, -0.07)
			_shade(buf, 1, y, -0.03)
	if not e:
		for y in TILE:
			_shade(buf, TILE - 1, y, -0.07)
			_shade(buf, TILE - 2, y, -0.03)
	# Innenecken: beide Kardinalnachbarn da, die Diagonale fehlt.
	_inner_corner_opaque(buf, n and w and not TileShapes.has_bit(mask, TileShapes.NW), 0, 0)
	_inner_corner_opaque(buf, n and e and not TileShapes.has_bit(mask, TileShapes.NE), TILE - 2, 0)
	_inner_corner_opaque(buf, s and w and not TileShapes.has_bit(mask, TileShapes.SW), 0, TILE - 2)
	_inner_corner_opaque(buf, s and e and not TileShapes.has_bit(mask, TileShapes.SE), TILE - 2, TILE - 2)


static func _inner_corner_opaque(buf: PackedByteArray, active: bool, ox: int, oy: int) -> void:
	if not active:
		return
	for dy in 2:
		for dx in 2:
			_shade(buf, ox + dx, oy + dy, -0.11)


## Auflagen: Silhouette schneiden (runde Aussenecken, Kerbe an Innenecken),
## danach eine Kontur entlang der entstandenen Kante zeichnen.
static func _shape_overlay(buf: PackedByteArray, mask: int, kind: int) -> void:
	var n := TileShapes.has_bit(mask, TileShapes.N)
	var e := TileShapes.has_bit(mask, TileShapes.E)
	var s := TileShapes.has_bit(mask, TileShapes.S)
	var w := TileShapes.has_bit(mask, TileShapes.W)
	var radius: float = ROUNDING[kind]
	var notch: float = NOTCH[kind]
	_corner(buf, not n and not w, n and w and not TileShapes.has_bit(mask, TileShapes.NW), 0, 0, radius, notch)
	_corner(buf, not n and not e, n and e and not TileShapes.has_bit(mask, TileShapes.NE), TILE, 0, radius, notch)
	_corner(buf, not s and not w, s and w and not TileShapes.has_bit(mask, TileShapes.SW), 0, TILE, radius, notch)
	_corner(buf, not s and not e, s and e and not TileShapes.has_bit(mask, TileShapes.SE), TILE, TILE, radius, notch)
	_outline(buf, n, e, s, w, RIM_COLOR[kind], RIM_STRENGTH[kind])


## `outer`: Aussenecke abrunden. `inner`: kleine Kerbe in die Innenecke.
## (cx, cy) ist der Eckpunkt in Pixelkoordinaten (0 oder TILE).
static func _corner(buf: PackedByteArray, outer: bool, inner: bool, cx: int, cy: int, radius: float, notch: float) -> void:
	if not outer and not inner:
		return
	var span := int(ceil(maxf(radius, notch))) + 1
	var x0 := maxi(cx - span, 0)
	var x1 := mini(cx + span, TILE)
	var y0 := maxi(cy - span, 0)
	var y1 := mini(cy + span, TILE)
	# Mittelpunkt des Rundungskreises liegt um `radius` nach innen versetzt.
	var mx := (cx as float) + (radius if cx == 0 else -radius)
	var my := (cy as float) + (radius if cy == 0 else -radius)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var px := x + 0.5
			var py := y + 0.5
			if outer:
				# Nur der Quadrant zwischen Eckpunkt und Kreismittelpunkt zählt.
				var outside_x := px < mx if cx == 0 else px > mx
				var outside_y := py < my if cy == 0 else py > my
				if outside_x and outside_y:
					var d := Vector2(px - mx, py - my).length()
					if d > radius:
						_alpha(buf, x, y, 0.0)
					elif d > radius - 1.0:
						_alpha(buf, x, y, 0.45)
			if inner:
				var d2 := Vector2(px - cx, py - cy).length()
				if d2 < notch - 1.0:
					_alpha(buf, x, y, 0.0)
				elif d2 < notch:
					_alpha(buf, x, y, 0.45)


## Kontur: jedes noch sichtbare Pixel, das an Leere oder an eine offene
## Tile-Kante grenzt, wird zur Randfarbe hin verschoben.
static func _outline(buf: PackedByteArray, n: bool, e: bool, s: bool, w: bool, rim: Color, strength: float) -> void:
	var edge := PackedInt32Array()
	for y in TILE:
		for x in TILE:
			if _alpha_of(buf, x, y) < 40:
				continue
			var exposed := false
			if y == 0:
				exposed = not n
			elif _alpha_of(buf, x, y - 1) < 40:
				exposed = true
			if not exposed:
				if y == TILE - 1:
					exposed = not s
				elif _alpha_of(buf, x, y + 1) < 40:
					exposed = true
			if not exposed:
				if x == 0:
					exposed = not w
				elif _alpha_of(buf, x - 1, y) < 40:
					exposed = true
			if not exposed:
				if x == TILE - 1:
					exposed = not e
				elif _alpha_of(buf, x + 1, y) < 40:
					exposed = true
			if exposed:
				edge.append(y * TILE + x)
	for index in edge:
		_mix(buf, index % TILE, index / TILE, rim, strength)


# --- Pixel-Helfer (roher RGBA8-Puffer) --------------------------------------

static func _put(buf: PackedByteArray, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= TILE or y >= TILE:
		return
	var i := (y * TILE + x) * 4
	buf[i] = int(c.r * 255.0)
	buf[i + 1] = int(c.g * 255.0)
	buf[i + 2] = int(c.b * 255.0)
	buf[i + 3] = int(c.a * 255.0)


static func _shade(buf: PackedByteArray, x: int, y: int, amount: float) -> void:
	if x < 0 or y < 0 or x >= TILE or y >= TILE:
		return
	var i := (y * TILE + x) * 4
	var delta := int(amount * 255.0)
	buf[i] = clampi(buf[i] + delta, 0, 255)
	buf[i + 1] = clampi(buf[i + 1] + delta, 0, 255)
	buf[i + 2] = clampi(buf[i + 2] + delta, 0, 255)


static func _mix(buf: PackedByteArray, x: int, y: int, c: Color, t: float) -> void:
	var i := (y * TILE + x) * 4
	buf[i] = int(lerpf(buf[i], c.r * 255.0, t))
	buf[i + 1] = int(lerpf(buf[i + 1], c.g * 255.0, t))
	buf[i + 2] = int(lerpf(buf[i + 2], c.b * 255.0, t))


static func _alpha(buf: PackedByteArray, x: int, y: int, factor: float) -> void:
	var i := (y * TILE + x) * 4 + 3
	buf[i] = int(buf[i] * factor)


static func _alpha_of(buf: PackedByteArray, x: int, y: int) -> int:
	return buf[(y * TILE + x) * 4 + 3]
