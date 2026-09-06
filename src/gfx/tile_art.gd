class_name TileArt
extends RefCounted
## Erzeugt alle Bodenkacheln und die Streu-Dekoration.
##
## Bei 32 Pixeln je Kachel trägt Textur auf zwei Ebenen: großflächige weiche
## Flecken geben der Fläche Struktur, feines Korn darüber die Materialwirkung.
## Nur Korn allein sieht aus wie Rauschen, nur Flecken allein wie Filz.

const T := Config.TILE
const VARIANTS := 6
## Großflächige Helligkeitsstufen. Der Unterschied muss klein bleiben: bei
## 32er-Kacheln ist jede Kachel eine große einfarbige Fläche, und schon wenige
## Prozent Abstand lassen das Raster als Schachbrett hervortreten.
const SHADES := 3
const SHADE_STEP := 0.035

var base: Array = []        ## [tile_type][stufe * VARIANTS + variante] -> Image
var decor_grass: Array[Image] = []
var decor_forest: Array[Image] = []
var decor_sand: Array[Image] = []
var decor_path: Array[Image] = []
var decor_water: Array[Image] = []
var decor_edge: Array[Image] = []   ## Gras, das an Wegrändern hereinwächst

static func build(seed_value: int) -> TileArt:
	var a := TileArt.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	a._build_bases(rng)
	a._build_decor()
	return a

func _build_bases(rng: RandomNumberGenerator) -> void:
	base.resize(MapData.Tile.COUNT)
	for t in MapData.Tile.COUNT:
		var list: Array[Image] = []
		for shade in SHADES:
			for v in VARIANTS:
				var img := _make_tile(t, rng)
				_shift(img, (shade - 1) * -SHADE_STEP)
				list.append(img)
		base[t] = list

## Hebt oder senkt die Helligkeit einer fertigen Kachel.
func _shift(img: Image, amount: float) -> void:
	if is_zero_approx(amount):
		return
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			img.set_pixel(x, y, c.lightened(amount) if amount > 0.0 else c.darkened(-amount))

func _make_tile(t: int, rng: RandomNumberGenerator) -> Image:
	match t:
		MapData.Tile.GRASS:
			return _grass_tile(Palette.GRASS, Palette.GRASS_LIGHT, Palette.GRASS_DARK, Palette.GRASS_HI, rng, 7)
		MapData.Tile.MEADOW:
			return _grass_tile(Palette.MEADOW_GROUND, Palette.GRASS_LIGHT, Palette.GRASS, Palette.GRASS_HI, rng, 10)
		MapData.Tile.FOREST:
			return _forest_tile(rng)
		MapData.Tile.PATH:
			return _path_tile(rng)
		MapData.Tile.COBBLE:
			return _cobble_tile(rng)
		MapData.Tile.SAND:
			return _sand_tile(rng)
		MapData.Tile.ROCK:
			return _rock_tile(rng)
		MapData.Tile.WATER:
			return _water_tile(Palette.WATER, Palette.WATER_LIGHT, Palette.WATER_DEEP, rng)
		MapData.Tile.DEEP_WATER:
			return _water_tile(Palette.WATER_DEEP, Palette.WATER, Palette.WATER_DEEP.darkened(0.25), rng)
	return Pixel.filled(T, T, Palette.GRASS)

## Weiche Flecken in einer verwandten Farbe — die grobe Struktur der Fläche.
func _mottle(img: Image, rng: RandomNumberGenerator, count: int, tint: Color, strength: float) -> void:
	for i in count:
		Pixel.ellipse(img, rng.randf_range(0, T), rng.randf_range(0, T),
			rng.randf_range(T * 0.16, T * 0.34), rng.randf_range(T * 0.12, T * 0.26),
			Color(tint.r, tint.g, tint.b, strength))

func _grain(img: Image, rng: RandomNumberGenerator, count: int, c: Color) -> void:
	for i in count:
		Pixel.px(img, rng.randi_range(0, T - 1), rng.randi_range(0, T - 1), c)

func _grass_tile(bg: Color, light: Color, dark: Color, hi: Color,
		rng: RandomNumberGenerator, blades: int) -> Image:
	var img := Pixel.filled(T, T, bg)
	_mottle(img, rng, 4, light, 0.40)
	_mottle(img, rng, 3, dark, 0.36)
	_grain(img, rng, 120, light)
	_grain(img, rng, 80, dark)
	_grain(img, rng, 30, hi)
	# Einzelne Halme mit hellem Kopf und dunklem Fuß
	for i in blades:
		var x := rng.randi_range(1, T - 2)
		var y := rng.randi_range(3, T - 5)
		var h := rng.randi_range(3, 5)
		Pixel.vline(img, x, y, h, light)
		Pixel.px(img, x, y, hi)
		Pixel.px(img, x + (1 if rng.randf() < 0.5 else -1), y + 1, light)
		Pixel.px(img, x, y + h, dark)
	return img

func _forest_tile(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, Palette.FOREST_GROUND)
	_mottle(img, rng, 3, Palette.GRASS_DARK, 0.34)
	_mottle(img, rng, 2, Palette.LEAF_DEEP, 0.28)
	_grain(img, rng, 70, Palette.GRASS_DARK)
	_grain(img, rng, 55, Palette.LEAF_DARK)
	# Nadel- und Blattstreu
	for i in 14:
		var x := rng.randi_range(0, T - 3)
		var y := rng.randi_range(0, T - 2)
		Pixel.rect(img, x, y, rng.randi_range(2, 3), 1, Palette.BARK_DARK)
	for i in 5:
		var x := rng.randi_range(1, T - 4)
		var y := rng.randi_range(1, T - 3)
		Pixel.rect(img, x, y, 3, 2, Palette.AUTUMN_DEEP)
		Pixel.px(img, x + 1, y, Palette.AUTUMN_DARK)
	return img

func _path_tile(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, Palette.DIRT)
	_mottle(img, rng, 4, Palette.DIRT_LIGHT, 0.30)
	_mottle(img, rng, 3, Palette.DIRT_DARK, 0.28)
	_grain(img, rng, 110, Palette.DIRT_LIGHT)
	_grain(img, rng, 80, Palette.DIRT_DARK)
	# Eingetretene Steine: heller Rücken, dunkler Schatten
	for i in rng.randi_range(2, 4):
		var x := rng.randi_range(2, T - 5)
		var y := rng.randi_range(2, T - 4)
		var w := rng.randi_range(2, 4)
		Pixel.rect(img, x, y, w, 2, Palette.STONE)
		Pixel.rect(img, x, y, w, 1, Palette.STONE_LIGHT)
		Pixel.rect(img, x, y + 2, w, 1, Palette.DIRT_DARK.darkened(0.2))
	# Abnutzungsrillen in Laufrichtung
	for i in rng.randi_range(1, 2):
		var y := rng.randi_range(4, T - 6)
		var len := rng.randi_range(8, 16)
		var x0 := rng.randi_range(0, T - len)
		Pixel.rect(img, x0, y, len, 1, Palette.DIRT_DARK)
		Pixel.rect(img, x0 + 1, y + 1, len - 2, 1, Palette.DIRT_LIGHT)
	return img

func _sand_tile(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, Palette.SAND)
	_mottle(img, rng, 4, Palette.SAND_LIGHT, 0.34)
	_mottle(img, rng, 3, Palette.SAND_DARK, 0.30)
	_grain(img, rng, 100, Palette.SAND_LIGHT)
	_grain(img, rng, 70, Palette.SAND_DARK)
	# Rippelmarken
	for i in rng.randi_range(1, 3):
		var y := rng.randi_range(3, T - 4)
		var len := rng.randi_range(10, 20)
		var x0 := rng.randi_range(0, T - len)
		for s in len:
			Pixel.px(img, x0 + s, y + int(sin(s * 0.5) * 1.2), Palette.SAND_DARK)
			Pixel.px(img, x0 + s, y + int(sin(s * 0.5) * 1.2) + 1, Palette.SAND_LIGHT)
	return img

func _rock_tile(rng: RandomNumberGenerator) -> Image:
	# Fels aus PLATTEN, nicht aus weichen Flecken. Weiche Flecken plus Körnung
	# ergaben fleckiges Grau ohne Halt — auf dem Bildschirm blass und flach.
	# Eine Platte mit heller Oberkante links, dunkler Unterkante rechts und
	# einer dunklen Fuge ringsum liest sich dagegen sofort als Stein.
	# Die Fuge ist Schatten zwischen Steinen, kein Loch. Zu dunkel gesetzt sah
	# der Fels aus wie Pflaster in Teer.
	var joint := Palette.STONE_DARK.darkened(0.18)
	var img := Pixel.filled(T, T, joint)

	# Ein leicht verzogenes 3x3-Raster von Platten. Die Platten laufen über den
	# Kachelrand hinaus, damit an der Kachelgrenze keine durchgehende Fuge
	# entsteht — sonst sähe man das 32er-Raster im Boden.
	# Grössere Platten und engere Fugen: bei neun kleinen Platten je Kachel sah
	# es aus wie Mosaik statt wie gewachsener Fels.
	var step := T / 2.0
	for gy in range(-1, 3):
		for gx in range(-1, 3):
			var cx := gx * step + step * 0.5 + rng.randf_range(-2.5, 2.5)
			var cy := gy * step + step * 0.5 + rng.randf_range(-2.5, 2.5)
			var rx := step * 0.5 - rng.randf_range(0.2, 1.0)
			var ry := step * 0.5 - rng.randf_range(0.2, 1.0)
			var tone := Palette.STONE.lerp(
				Palette.STONE_LIGHT if rng.randf() < 0.55 else Palette.STONE_DARK,
				rng.randf_range(0.08, 0.38))
			_slab(img, cx, cy, rx, ry, tone, rng)

	_grain(img, rng, 34, Palette.STONE_LIGHT)
	_grain(img, rng, 26, Palette.STONE_DARK)
	return img

## Eine einzelne Steinplatte: Fläche, Lichtkante oben links, Schattenkante
## unten rechts. Die Ecken werden angeknabbert, damit sie nicht wie gestanzt
## aussieht.
func _slab(img: Image, cx: float, cy: float, rx: float, ry: float,
		tone: Color, rng: RandomNumberGenerator) -> void:
	var x0 := int(round(cx - rx))
	var x1 := int(round(cx + rx))
	var y0 := int(round(cy - ry))
	var y1 := int(round(cy + ry))
	var nib := [rng.randi_range(0, 2), rng.randi_range(0, 2),
		rng.randi_range(0, 2), rng.randi_range(0, 2)]
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= T or y >= T:
				continue
			# Ecken abknabbern
			if x - x0 + y - y0 < nib[0]: continue
			if x1 - x + y - y0 < nib[1]: continue
			if x1 - x + y1 - y < nib[2]: continue
			if x - x0 + y1 - y < nib[3]: continue
			var c := tone
			if y == y0 or x == x0:
				c = tone.lightened(0.22)          # Licht von oben links
			elif y == y1 or x == x1:
				c = tone.darkened(0.28)
			img.set_pixel(x, y, c)

## Gepflasterter Dorfplatz: runde Katzenkopfsteine in Fugensand.
func _cobble_tile(rng: RandomNumberGenerator) -> Image:
	var mortar := Palette.DIRT_DARK.lerp(Palette.STONE_DARK, 0.35)
	var img := Pixel.filled(T, T, mortar)
	_grain(img, rng, 60, Palette.DIRT)
	# 4x4-Raster leicht versetzter Steine
	var step := T / 4.0
	for gy in 4:
		for gx in 4:
			var cx := gx * step + step * 0.5 + rng.randf_range(-1.4, 1.4)
			var cy := gy * step + step * 0.5 + rng.randf_range(-1.4, 1.4)
			var rx := rng.randf_range(step * 0.34, step * 0.46)
			var ry := rng.randf_range(step * 0.30, step * 0.42)
			var stone := Palette.STONE.lerp(Palette.DIRT_LIGHT, rng.randf_range(0.0, 0.35))
			Pixel.ellipse(img, cx, cy + 0.8, rx, ry, stone.darkened(0.30))
			Pixel.ellipse(img, cx, cy, rx, ry, stone)
			Pixel.ellipse(img, cx - rx * 0.28, cy - ry * 0.30, rx * 0.55, ry * 0.5,
				stone.lerp(Palette.STONE_LIGHT, 0.6))
			if rng.randf() < 0.3:
				Pixel.px(img, int(cx + rng.randf_range(-1, 1)), int(cy + 1), stone.darkened(0.4))
	return img

func _water_tile(bg: Color, hi: Color, deep: Color, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, bg)
	# Tiefenwirkung: dunklere Schlieren unter der Oberfläche
	for i in 4:
		Pixel.ellipse(img, rng.randf_range(0, T), rng.randf_range(0, T),
			rng.randf_range(7, 14), rng.randf_range(4, 8), Color(deep.r, deep.g, deep.b, 0.20))
	# Wellenlinien
	for i in 5:
		var y := rng.randi_range(1, T - 2)
		var x := rng.randi_range(0, T - 12)
		var w := rng.randi_range(6, 12)
		for s in w:
			Pixel.px(img, x + s, y + int(sin(s * 0.6) * 1.0), Color(hi.r, hi.g, hi.b, 0.42))
	_grain(img, rng, 24, Color(hi.r, hi.g, hi.b, 0.22))
	return img

# --- Streu-Dekoration --------------------------------------------------------

func _build_decor() -> void:
	decor_grass = [
		_flower(Palette.FLOWER_RED), _flower(Palette.FLOWER_YELLOW),
		_flower(Palette.FLOWER_WHITE), _flower(Palette.FLOWER_BLUE),
		_flower_clump(Palette.FLOWER_WHITE), _flower_clump(Palette.FLOWER_YELLOW),
		_tuft(Palette.GRASS_HI), _tuft(Palette.GRASS_LIGHT), _tuft(Palette.GRASS_HI),
		_clover(), _pebble(),
	]
	decor_edge = [_tuft(Palette.GRASS_LIGHT), _tuft(Palette.GRASS), _clover()]
	decor_forest = [
		_mushroom(), _mushroom_pair(), _twig(), _twig(), _leaf_litter(),
		_tuft(Palette.GRASS), _tuft(Palette.GRASS_DARK), _pebble(),
	]
	decor_sand = [_pebble(), _shell(), _shell(), _twig(), _driftwood()]
	decor_path = [_pebble(), _pebble()]
	decor_water = [_lily()]

func _flower(c: Color) -> Image:
	var img := Pixel.make(7, 9)
	Pixel.vline(img, 3, 4, 5, Palette.GRASS_DARK)
	Pixel.px(img, 2, 6, Palette.GRASS)
	Pixel.px(img, 4, 7, Palette.GRASS)
	# Blüte: vier Blätter um eine helle Mitte
	Pixel.rect(img, 2, 1, 3, 3, c)
	Pixel.px(img, 1, 2, c)
	Pixel.px(img, 5, 2, c)
	Pixel.px(img, 3, 0, c)
	Pixel.px(img, 3, 4, c.darkened(0.2))
	Pixel.px(img, 3, 2, Palette.FLOWER_YELLOW if c != Palette.FLOWER_YELLOW else Palette.FLOWER_WHITE)
	return img

func _flower_clump(c: Color) -> Image:
	var img := Pixel.make(13, 11)
	for p: Vector2i in [Vector2i(2, 4), Vector2i(7, 2), Vector2i(5, 7), Vector2i(10, 5)]:
		Pixel.vline(img, p.x, p.y + 2, 3, Palette.GRASS_DARK)
		Pixel.rect(img, p.x - 1, p.y, 3, 2, c)
		Pixel.px(img, p.x, p.y - 1, c)
		Pixel.px(img, p.x, p.y, c.lightened(0.25))
	return img

func _tuft(c: Color) -> Image:
	var img := Pixel.make(11, 9)
	var heights := [4, 6, 8, 5, 3]
	for i in heights.size():
		var x := 1 + i * 2
		var h: int = heights[i]
		Pixel.vline(img, x, 8 - h, h, c)
		Pixel.px(img, x, 8 - h, c.lightened(0.2))
		Pixel.px(img, x, 8, Palette.GRASS_DARK)
	return img

func _clover() -> Image:
	var img := Pixel.make(10, 8)
	for p: Vector2i in [Vector2i(2, 2), Vector2i(6, 1), Vector2i(4, 5)]:
		Pixel.ellipse(img, p.x, p.y, 1.6, 1.3, Palette.GRASS_HI)
		Pixel.px(img, p.x, p.y + 1, Palette.GRASS_LIGHT)
		Pixel.px(img, p.x, p.y + 2, Palette.GRASS_DARK)
	return img

func _pebble() -> Image:
	var img := Pixel.make(8, 6)
	Pixel.ellipse(img, 4, 3.4, 3.2, 2.2, Palette.STONE_DARK)
	Pixel.ellipse(img, 4, 3.0, 2.8, 1.8, Palette.STONE)
	Pixel.ellipse(img, 3.2, 2.4, 1.6, 1.0, Palette.STONE_LIGHT)
	return img

func _mushroom() -> Image:
	var img := Pixel.make(9, 9)
	Pixel.rect(img, 3, 5, 3, 4, Palette.WALL)
	Pixel.rect(img, 3, 5, 1, 4, Palette.WALL.darkened(0.15))
	Pixel.ellipse(img, 4.5, 3.5, 4.2, 2.6, Palette.FLOWER_RED.darkened(0.2))
	Pixel.ellipse(img, 4.5, 3.0, 3.8, 2.2, Palette.FLOWER_RED)
	Pixel.px(img, 3, 2, Palette.FLOWER_WHITE)
	Pixel.px(img, 6, 3, Palette.FLOWER_WHITE)
	return img

func _mushroom_pair() -> Image:
	var img := Pixel.make(15, 9)
	for o: int in [0, 7]:
		Pixel.rect(img, o + 3, 5, 2, 4, Palette.WALL)
		Pixel.ellipse(img, o + 4.0, 3.6, 3.4, 2.2, Palette.FLOWER_RED.darkened(0.2))
		Pixel.ellipse(img, o + 4.0, 3.2, 3.0, 1.8, Palette.FLOWER_RED)
		Pixel.px(img, o + 3, 3, Palette.FLOWER_WHITE)
	return img

func _twig() -> Image:
	var img := Pixel.make(11, 6)
	Pixel.hline(img, 0, 3, 9, Palette.BARK_DARK)
	Pixel.hline(img, 1, 2, 6, Palette.BARK)
	Pixel.px(img, 9, 2, Palette.BARK)
	Pixel.px(img, 4, 4, Palette.BARK_DARK)
	Pixel.px(img, 6, 1, Palette.BARK)
	return img

func _leaf_litter() -> Image:
	var img := Pixel.make(13, 10)
	for p: Vector2i in [Vector2i(1, 2), Vector2i(6, 0), Vector2i(4, 6), Vector2i(9, 4)]:
		Pixel.ellipse(img, p.x + 1.5, p.y + 1.0, 2.0, 1.2, Palette.AUTUMN_DARK)
		Pixel.px(img, p.x + 1, p.y, Palette.AUTUMN)
		Pixel.px(img, p.x + 1, p.y + 2, Palette.AUTUMN_DEEP)
	return img

func _shell() -> Image:
	var img := Pixel.make(8, 6)
	Pixel.ellipse(img, 4, 3.4, 3.2, 2.4, Palette.SAND_DARK)
	Pixel.ellipse(img, 4, 3.0, 2.8, 2.0, Palette.FLOWER_WHITE)
	for i in 3:
		Pixel.px(img, 2 + i * 2, 2 + i % 2, Palette.SAND_DARK)
	return img

func _driftwood() -> Image:
	var img := Pixel.make(17, 7)
	Pixel.rect(img, 0, 2, 15, 3, Palette.BARK_LIGHT)
	Pixel.rect(img, 0, 2, 15, 1, Palette.SAND_LIGHT)
	Pixel.rect(img, 0, 5, 15, 1, Palette.BARK_DARK)
	Pixel.px(img, 5, 1, Palette.BARK_DARK)
	Pixel.px(img, 11, 6, Palette.BARK_DARK)
	Pixel.rect(img, 14, 1, 3, 2, Palette.BARK_LIGHT)
	return img

func _lily() -> Image:
	var img := Pixel.make(14, 12)
	Pixel.ellipse(img, 7, 6.5, 6.4, 5.0, Palette.LEAF_DARK)
	Pixel.ellipse(img, 7, 6.0, 5.8, 4.4, Palette.LEAF)
	Pixel.ellipse(img, 5.6, 4.8, 3.4, 2.4, Palette.LEAF_LIGHT)
	Pixel.rect(img, 6, 0, 3, 4, Palette.LEAF_DARK)
	Pixel.ellipse(img, 10, 3, 2.0, 1.6, Palette.FLOWER_WHITE)
	Pixel.px(img, 10, 3, Palette.FLOWER_YELLOW)
	return img
