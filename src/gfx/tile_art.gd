class_name TileArt
extends RefCounted
## Erzeugt alle Bodenkacheln, Übergangskanten und Streu-Dekoration.

const T := Config.TILE
const VARIANTS := 4
const EDGE_DEPTH := 3

var base: Array = []        ## [tile_type][variante] -> Image
var edge: Array = []        ## [tile_type][richtung 0..3] -> Image (oben/unten/links/rechts)
var decor_grass: Array[Image] = []
var decor_forest: Array[Image] = []
var decor_sand: Array[Image] = []
var decor_path: Array[Image] = []
var decor_water: Array[Image] = []

static func build(seed_value: int) -> TileArt:
	var a := TileArt.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	a._build_bases(rng)
	a._build_edges(rng)
	a._build_decor(rng)
	return a

func _build_bases(rng: RandomNumberGenerator) -> void:
	base.resize(MapData.Tile.COUNT)
	for t in MapData.Tile.COUNT:
		var list: Array[Image] = []
		for v in VARIANTS:
			list.append(_make_tile(t, rng))
		base[t] = list

func _make_tile(t: int, rng: RandomNumberGenerator) -> Image:
	match t:
		MapData.Tile.GRASS:
			return _speckle(Palette.GRASS, Palette.GRASS_LIGHT, Palette.GRASS_DARK, 26, 16, rng, 3)
		MapData.Tile.MEADOW:
			return _speckle(Palette.GRASS_LIGHT, Palette.GRASS_HI, Palette.GRASS, 30, 14, rng, 4)
		MapData.Tile.FOREST:
			return _speckle(Palette.GRASS_DARK, Palette.GRASS, Palette.LEAF_DARK, 18, 26, rng, 2)
		MapData.Tile.PATH:
			return _path_tile(rng)
		MapData.Tile.SAND:
			return _speckle(Palette.SAND, Palette.SAND_LIGHT, Palette.SAND_DARK, 22, 18, rng, 0)
		MapData.Tile.ROCK:
			return _rock_tile(rng)
		MapData.Tile.WATER:
			return _water_tile(Palette.WATER, Palette.WATER_LIGHT, rng)
		MapData.Tile.DEEP_WATER:
			return _water_tile(Palette.WATER_DEEP, Palette.WATER, rng)
	return Pixel.filled(T, T, Palette.GRASS)

func _speckle(bg: Color, light: Color, dark: Color, n_light: int, n_dark: int, rng: RandomNumberGenerator, blades: int) -> Image:
	var img := Pixel.filled(T, T, bg)
	for i in n_light:
		Pixel.px(img, rng.randi_range(0, T - 1), rng.randi_range(0, T - 1), light)
	for i in n_dark:
		Pixel.px(img, rng.randi_range(0, T - 1), rng.randi_range(0, T - 1), dark)
	for i in blades:
		var x := rng.randi_range(1, T - 2)
		var y := rng.randi_range(2, T - 3)
		Pixel.vline(img, x, y, 2, light)
		Pixel.px(img, x + 1, y + 1, dark)
	return img

func _path_tile(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, Palette.DIRT)
	for i in 34:
		Pixel.px(img, rng.randi_range(0, T - 1), rng.randi_range(0, T - 1), Palette.DIRT_LIGHT)
	for i in 26:
		Pixel.px(img, rng.randi_range(0, T - 1), rng.randi_range(0, T - 1), Palette.DIRT_DARK)
	for i in 2:
		var x := rng.randi_range(1, T - 3)
		var y := rng.randi_range(1, T - 3)
		Pixel.rect(img, x, y, 2, 1, Palette.STONE_LIGHT)
		Pixel.px(img, x, y + 1, Palette.STONE_DARK)
	return img

func _rock_tile(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, Palette.STONE)
	for i in 5:
		var x := rng.randf_range(0, T)
		var y := rng.randf_range(0, T)
		Pixel.ellipse(img, x, y, rng.randf_range(1.5, 3.5), rng.randf_range(1.2, 2.6), Palette.STONE_DARK)
	for i in 22:
		Pixel.px(img, rng.randi_range(0, T - 1), rng.randi_range(0, T - 1), Palette.STONE_LIGHT)
	return img

func _water_tile(bg: Color, hi: Color, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, bg)
	for i in 3:
		var y := rng.randi_range(1, T - 2)
		var x := rng.randi_range(0, T - 6)
		var w := rng.randi_range(3, 6)
		Pixel.hline(img, x, y, w, Color(hi.r, hi.g, hi.b, 0.5))
	for i in 10:
		Pixel.px(img, rng.randi_range(0, T - 1), rng.randi_range(0, T - 1), Color(hi.r, hi.g, hi.b, 0.28))
	return img

func _build_edges(rng: RandomNumberGenerator) -> void:
	var colors := {
		MapData.Tile.GRASS: Palette.GRASS,
		MapData.Tile.MEADOW: Palette.GRASS_LIGHT,
		MapData.Tile.FOREST: Palette.GRASS_DARK,
		MapData.Tile.PATH: Palette.DIRT,
		MapData.Tile.SAND: Palette.SAND,
		MapData.Tile.ROCK: Palette.STONE,
		MapData.Tile.WATER: Palette.WATER,
		MapData.Tile.DEEP_WATER: Palette.WATER_DEEP,
	}
	edge.resize(MapData.Tile.COUNT)
	for t in MapData.Tile.COUNT:
		var c: Color = colors.get(t, Palette.GRASS)
		var dirs: Array[Image] = []
		for d in 4:
			# 0=oben 1=unten 2=links 3=rechts — Streifen zur Kachelkante hin ausrichten
			var im := Pixel.dither_strip(d < 2, T, EDGE_DEPTH, c, rng)
			if d == 1:
				im.flip_y()
			elif d == 3:
				im.flip_x()
			dirs.append(im)
		edge[t] = dirs

func _build_decor(rng: RandomNumberGenerator) -> void:
	decor_grass = [
		_flower(Palette.FLOWER_RED), _flower(Palette.FLOWER_YELLOW),
		_flower(Palette.FLOWER_WHITE), _flower(Palette.FLOWER_BLUE),
		_tuft(Palette.GRASS_HI), _tuft(Palette.GRASS_LIGHT), _pebble(),
	]
	decor_forest = [_mushroom(), _twig(), _tuft(Palette.GRASS), _pebble()]
	decor_sand = [_pebble(), _shell(), _twig()]
	decor_path = [_pebble(), _pebble()]
	decor_water = [_lily()]

func _flower(c: Color) -> Image:
	var img := Pixel.make(3, 4)
	Pixel.vline(img, 1, 2, 2, Palette.GRASS_DARK)
	Pixel.px(img, 1, 0, c)
	Pixel.px(img, 0, 1, c)
	Pixel.px(img, 2, 1, c)
	Pixel.px(img, 1, 1, Color(c.r * 1.25, c.g * 1.25, c.b * 1.05, 1.0))
	return img

func _tuft(c: Color) -> Image:
	var img := Pixel.make(5, 4)
	Pixel.vline(img, 0, 2, 2, c)
	Pixel.vline(img, 2, 1, 3, c)
	Pixel.vline(img, 4, 2, 2, c)
	Pixel.px(img, 1, 3, Palette.GRASS_DARK)
	Pixel.px(img, 3, 3, Palette.GRASS_DARK)
	return img

func _pebble() -> Image:
	var img := Pixel.make(4, 3)
	Pixel.rect(img, 1, 0, 2, 1, Palette.STONE_LIGHT)
	Pixel.rect(img, 0, 1, 4, 1, Palette.STONE)
	Pixel.rect(img, 1, 2, 2, 1, Palette.STONE_DARK)
	return img

func _mushroom() -> Image:
	var img := Pixel.make(4, 4)
	Pixel.rect(img, 1, 2, 2, 2, Palette.WALL)
	Pixel.rect(img, 0, 1, 4, 1, Palette.FLOWER_RED)
	Pixel.rect(img, 1, 0, 2, 1, Palette.FLOWER_RED)
	Pixel.px(img, 1, 1, Palette.FLOWER_WHITE)
	return img

func _twig() -> Image:
	var img := Pixel.make(5, 3)
	Pixel.hline(img, 0, 1, 4, Palette.WOOD_DARK)
	Pixel.px(img, 4, 0, Palette.WOOD)
	Pixel.px(img, 2, 2, Palette.WOOD)
	return img

func _shell() -> Image:
	var img := Pixel.make(4, 3)
	Pixel.rect(img, 1, 0, 2, 1, Palette.FLOWER_WHITE)
	Pixel.rect(img, 0, 1, 4, 1, Palette.SAND_LIGHT)
	Pixel.px(img, 1, 2, Palette.SAND_DARK)
	Pixel.px(img, 2, 2, Palette.SAND_DARK)
	return img

func _lily() -> Image:
	var img := Pixel.make(7, 6)
	Pixel.ellipse(img, 3.5, 3.0, 3.4, 2.6, Palette.LEAF)
	Pixel.ellipse(img, 3.0, 2.4, 2.2, 1.6, Palette.LEAF_LIGHT)
	Pixel.rect(img, 3, 0, 2, 2, Palette.LEAF_DARK)
	Pixel.px(img, 5, 1, Palette.FLOWER_WHITE)
	return img
