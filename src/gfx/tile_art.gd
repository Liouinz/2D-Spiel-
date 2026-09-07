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
## Vorher 0,035. Das dichte Korn hat die Stufen früher verdeckt; auf einer
## ruhigeren Fläche fällt jede Stufe sofort als Schachbrettfeld auf. Die grosse
## Helligkeitsbewegung kommt jetzt ohnehin vom Wind-Shader, der über Kachelkanten
## hinweg weich verläuft.
const SHADE_STEP := 0.018

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
	# Grosse weiche Flecken zuerst — sie geben der Fläche ihre Struktur.
	_mottle(img, rng, 5, light, 0.30)
	_mottle(img, rng, 4, dark, 0.28)
	# Korn: deutlich weniger und viel schwächer als früher.
	#
	# Vorher lagen 230 deckende Einzelpixel auf 1024 — knapp ein Viertel der
	# Kachel. Aus zwei Metern Abstand war das kein Gras, sondern Bildrauschen,
	# und es überdeckte jede grössere Struktur. Jetzt sind es rund 70, und sie
	# werden eingeblendet statt gesetzt: das Korn stört die Fläche nicht mehr,
	# es raut sie nur auf.
	_grain(img, rng, 44, Color(light.r, light.g, light.b, 0.42))
	_grain(img, rng, 30, Color(dark.r, dark.g, dark.b, 0.38))
	# Halme in kleinen Büscheln statt einzeln verstreut: zwei bis drei
	# nebeneinander liest man als Gras, gleichmässig verteilte Striche nicht.
	for i in blades:
		var bx := rng.randi_range(1, T - 3)
		var by := rng.randi_range(3, T - 6)
		for k in rng.randi_range(2, 3):
			var x := bx + k + rng.randi_range(-1, 1)
			var y := by + rng.randi_range(-1, 1)
			var h := rng.randi_range(3, 5)
			Pixel.vline(img, x, y, h, Color(light.r, light.g, light.b, 0.85))
			Pixel.px(img, x, y, Color(hi.r, hi.g, hi.b, 0.75))
			Pixel.px(img, x, y + h, Color(dark.r, dark.g, dark.b, 0.7))
	return img

func _sand_tile(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, Palette.SAND)
	_mottle(img, rng, 5, Palette.SAND_LIGHT, 0.26)
	_mottle(img, rng, 4, Palette.SAND_DARK, 0.22)
	# Sand ist eine ruhige Fläche. Dichtes Korn liess ihn körnig wie Schmirgel
	# aussehen; die Rippelmarken tragen die Struktur.
	_grain(img, rng, 34, Color(Palette.SAND_LIGHT.r, Palette.SAND_LIGHT.g,
		Palette.SAND_LIGHT.b, 0.40))
	_grain(img, rng, 24, Color(Palette.SAND_DARK.r, Palette.SAND_DARK.g,
		Palette.SAND_DARK.b, 0.34))
	# Rippelmarken
	for i in rng.randi_range(2, 3):
		var y := rng.randi_range(3, T - 4)
		var len := rng.randi_range(12, 22)
		var x0 := rng.randi_range(0, T - len)
		for s2 in len:
			var wave := int(sin(s2 * 0.5) * 1.2)
			Pixel.px(img, x0 + s2, y + wave,
				Color(Palette.SAND_DARK.r, Palette.SAND_DARK.g, Palette.SAND_DARK.b, 0.55))
			Pixel.px(img, x0 + s2, y + wave + 1,
				Color(Palette.SAND_LIGHT.r, Palette.SAND_LIGHT.g, Palette.SAND_LIGHT.b, 0.6))
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
