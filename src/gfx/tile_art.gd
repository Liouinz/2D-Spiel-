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

static func build(seed_value: int) -> TileArt:
	var a := TileArt.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	a._build_bases(rng)
	return a

func _build_bases(rng: RandomNumberGenerator) -> void:
	# Bodenkacheln werden nahtlos gezeichnet: eine Fläche aus vielen gleichen
	# Kacheln zeigt sonst an jeder Naht einen Bruch, und genau das liess den
	# Boden wie aneinandergelegte Rechtecke aussehen.
	Pixel.wrap = T
	_build_bases_raw(rng)
	Pixel.wrap = 0

## Derselbe Aufbau ohne Kantenumlauf — der Selbsttest vergleicht damit, wie
## stark die Naht vorher auffiel.
func _build_bases_raw(rng: RandomNumberGenerator) -> void:
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
		MapData.Tile.SAND:
			return _sand_tile(rng)
		MapData.Tile.WATER:
			return _water_tile(Palette.WATER, Palette.WATER_LIGHT, Palette.WATER_DEEP, rng)
	return _grass_tile(Palette.GRASS, Palette.GRASS_LIGHT, Palette.GRASS_DARK,
		Palette.GRASS_HI, rng, 7)

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
