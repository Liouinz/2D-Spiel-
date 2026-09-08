class_name TileArt
extends RefCounted
## Erzeugt alle Bodenkacheln und die Streu-Dekoration.
##
## Bei 32 Pixeln je Kachel trägt Textur auf zwei Ebenen: großflächige weiche
## Flecken geben der Fläche Struktur, feines Korn darüber die Materialwirkung.
## Nur Korn allein sieht aus wie Rauschen, nur Flecken allein wie Filz.

const T := Config.TILE
## Zehn statt sechs. Bei Zoom 2 sieht man rund 220 Kacheln gleichzeitig; mit
## sechs Bildern je Helligkeitsstufe kam dasselbe Bild rund vierzigmal vor und
## das Muster war als Muster zu erkennen.
const VARIANTS := 10
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

## Verteilt Marken auf einem VERWACKELTEN RASTER statt rein zufällig.
##
## Das ist der Kern einer ruhigen Bodenfläche. Rein zufällige Punkte ballen sich
## an manchen Stellen und lassen anderswo Löcher; beides sieht man einer Kachel
## an, und über eine Fläche aus vielen Kacheln wiederholt sich genau diese
## Ballung. Ein Raster mit Streuung je Zelle deckt gleichmässig ab und wirkt
## trotzdem ungeordnet.
func _scatter(rng: RandomNumberGenerator, cells: int, jitter: float) -> Array:
	var out: Array = []
	var step := float(T) / float(cells)
	for cy in cells:
		for cx in cells:
			out.append(Vector2i(
				int(cx * step + rng.randf_range(0.0, step) + rng.randf_range(-jitter, jitter)),
				int(cy * step + rng.randf_range(0.0, step) + rng.randf_range(-jitter, jitter))))
	return out

func _grass_tile(bg: Color, light: Color, dark: Color, hi: Color,
		rng: RandomNumberGenerator, blades: int) -> Image:
	var img := Pixel.filled(T, T, bg)

	# Sehr weiche, grosse Flecken. Bewusst schwach: kräftigere Flecken lasen
	# sich als Flecken auf dem Boden, nicht als Boden.
	_mottle(img, rng, 3, light, 0.16)
	_mottle(img, rng, 3, dark, 0.15)

	# Halme: kurze senkrechte Striche auf dem verwackelten Raster. Sie sind die
	# eigentliche Struktur — nicht Körnung, sondern gerichtete Marken, die man
	# als Bewuchs liest.
	for p: Vector2i in _scatter(rng, 6, 1.0):
		var h := rng.randi_range(2, 3)
		var c := light if rng.randf() < 0.72 else hi
		var a := 0.42 + rng.randf() * 0.22
		Pixel.vline(img, p.x, p.y, h, Color(c, a))
		if rng.randf() < 0.35:
			Pixel.px(img, p.x + (1 if rng.randf() < 0.5 else -1), p.y + 1, Color(c, a * 0.7))

	# Dunkle Zwischenräume — sie geben der Fläche Tiefe, ohne sie zu beleben.
	for p: Vector2i in _scatter(rng, 5, 1.2):
		Pixel.vline(img, p.x, p.y, rng.randi_range(1, 2), Color(dark, 0.34 + rng.randf() * 0.16))

	# Einzelne helle Spitzen, sehr sparsam: sie fangen das Licht.
	for i in blades:
		var p := Vector2i(rng.randi_range(0, T - 1), rng.randi_range(0, T - 1))
		Pixel.px(img, p.x, p.y, Color(hi, 0.55))
	return img

## Sand: eine ruhige Fläche, die trotzdem Korn zeigt.
##
## Vorher war er so zurückgenommen, dass bei näherem Zoom eine fast leere
## beige Fläche übrig blieb. Die Struktur kommt jetzt aus drei Ebenen: weiche
## Verwehungen, gleichmässiges Korn auf dem verwackelten Raster und ein paar
## Rippelmarken, die dem Ganzen eine Richtung geben.
func _sand_tile(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, Palette.SAND)
	_mottle(img, rng, 4, Palette.SAND_LIGHT, 0.20)
	_mottle(img, rng, 3, Palette.SAND_DARK, 0.18)

	for p: Vector2i in _scatter(rng, 7, 1.0):
		var c := Palette.SAND_LIGHT if rng.randf() < 0.55 else Palette.SAND_DARK
		Pixel.px(img, p.x, p.y, Color(c, 0.30 + rng.randf() * 0.22))

	# Rippelmarken: eine helle Kante mit dunklem Schatten darunter — dadurch
	# liest man sie als Welle im Sand und nicht als Kratzer.
	for i in rng.randi_range(2, 3):
		var y := rng.randi_range(2, T - 5)
		var length := rng.randi_range(14, 26)
		var x0 := rng.randi_range(-4, T - length + 4)
		var amp := rng.randf_range(0.8, 1.6)
		var freq := rng.randf_range(0.35, 0.6)
		for s2 in length:
			var wave := int(round(sin(s2 * freq) * amp))
			Pixel.px(img, x0 + s2, y + wave,
				Color(Palette.SAND_LIGHT, 0.55))
			Pixel.px(img, x0 + s2, y + wave + 1,
				Color(Palette.SAND_DARK, 0.42))

	# Vereinzelte Kiesel: kleine dunkle Punkte mit heller Oberkante.
	for i in rng.randi_range(1, 3):
		var p := Vector2i(rng.randi_range(1, T - 2), rng.randi_range(1, T - 2))
		Pixel.px(img, p.x, p.y, Color(Palette.SAND_DARK.darkened(0.22), 0.7))
		Pixel.px(img, p.x, p.y - 1, Color(Palette.SAND_LIGHT, 0.5))
	return img

## Wasser: waagerechte Wellenbänder statt verstreuter Striche.
##
## Der klassische Aufbau für Pixelwasser von oben: eine dunklere Grundfläche mit
## unregelmässigen Bändern, darauf helle Glanzkanten. Die Bänder laufen
## waagerecht — dadurch liest man eine Oberfläche und nicht ein gesprenkeltes
## Feld. Die Bewegung kommt darüber aus dem Shader und der Wasserwirkung.
## Wasserfläche.
##
## Vier Farbschichten übereinander, jede mit einer anderen Aufgabe — eine
## einzelne blaue Fläche mit ein paar Strichen darauf las sich als „blaues
## Rechteck mit Deko":
##
##   1. weiche Tiefenbänder  — die grosse Form, wo es tiefer wird
##   2. eine mittlere Lage   — bricht die Bänder auf, damit keine Streifen
##                             über die Kachel laufen
##   3. Glanzkanten          — kurze helle Striche MIT Schatten darunter; erst
##                             der Schatten macht daraus eine Welle
##   4. Funkeln              — einzelne Punkte, sehr sparsam
##
## Alles bleibt schwach. Wasser, das in jeder Kachel deutlich anders aussieht,
## flimmert über eine Fläche hinweg; die Unterschiede sollen man erst bemerken,
## wenn man hinsieht.
func _water_tile(bg: Color, hi: Color, deep: Color, rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, bg)

	# 1. Tiefenwirkung: breite, weiche Bänder in der dunklen Farbe.
	for i in 3:
		var y := rng.randi_range(0, T - 1)
		var h := rng.randi_range(3, 7)
		for dy in h:
			var a := 0.16 * (1.0 - absf(float(dy) - h * 0.5) / (h * 0.5)) + 0.06
			Pixel.hline(img, 0, y + dy, T, Color(deep, a))

	# 2. Eine mittlere Lage aus weichen Flecken. Ohne sie liegen die Bänder aus
	#    Schritt 1 als waagerechte Streifen über der ganzen Fläche.
	var mid := bg.lerp(hi, 0.35)
	_mottle(img, rng, 3, mid, 0.13)
	_mottle(img, rng, 2, deep, 0.10)

	# 3. Glanzkanten: kurze helle Striche mit einem dunkleren Schatten darunter.
	for i in 4:
		var y := rng.randi_range(1, T - 3)
		var x := rng.randi_range(-6, T - 4)
		var w := rng.randi_range(7, 15)
		for s2 in w:
			# An den Enden ausdünnen, sonst wirkt es wie ein gezogener Strich.
			var edge := minf(float(s2), float(w - 1 - s2)) / 3.0
			var a := 0.42 * minf(edge, 1.0)
			if a <= 0.02:
				continue
			var wave := int(round(sin(s2 * 0.45) * 0.8))
			Pixel.px(img, x + s2, y + wave, Color(hi, a))
			Pixel.px(img, x + s2, y + wave + 1, Color(deep, a * 0.5))

	# 3b. Ein einzelner heller Reflex je Kachel, deutlich schwächer als die
	#     Glanzkanten und ohne Schatten: das ist Licht auf der Oberfläche, keine
	#     Welle. Er sitzt oben links, weil das Licht in dieser Welt von dort
	#     kommt — bei jeder Kachel, bei jedem Grashalm, an der Figur.
	if rng.randf() < 0.7:
		var rx := rng.randi_range(2, T / 2)
		var ry := rng.randi_range(2, T / 2)
		for k in 3:
			Pixel.px(img, rx + k, ry - (k % 2),
				Color(Palette.WATER_FOAM, 0.16 - k * 0.04))

	# 4. Feines Funkeln, sehr sparsam.
	for p: Vector2i in _scatter(rng, 4, 1.5):
		if rng.randf() < 0.45:
			Pixel.px(img, p.x, p.y, Color(Palette.WATER_FOAM, 0.22))
	return img
