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

## Beim WASSER bedeuten die Stufen etwas anderes — und dürfen deshalb viel
## weiter auseinanderliegen.
##
## Bei Gras und Sand ist die Stufe eine zufällige Helligkeitsschwankung, und
## jeder sichtbare Unterschied wäre ein Schachbrett. Beim Wasser ist sie die
## TIEFE: Stufe 0 liegt am Ufer, Stufe 2 in der Mitte. Das ist keine
## Schwankung, sondern eine Form — sie folgt der Küstenlinie und darf gesehen
## werden. Ohne sie ist eine Wasserfläche eine gleichmäßig blaue Platte, egal
## wie fein die Kachel gezeichnet ist.
const SHADE_STEP_WATER := 0.085

## Wie weit die Stufen eines Bodentyps auseinanderliegen.
static func shade_step(tile: int) -> float:
	return SHADE_STEP_WATER if tile == MapData.Tile.WATER else SHADE_STEP

## Lage und Hoehe der Tiefenbaender im Wasser: y, Hoehe.
##
## Fest statt gewuerfelt, siehe `_water_tile`. Ungleiche Abstaende, damit die
## Flaeche nicht wie liniertes Papier aussieht; die Zahlen sind so gewaehlt,
## dass sich beim Aneinanderlegen von Kacheln (Abstand 32) kein regelmaessiger
## Takt ergibt, den man als Streifen liest.
const WATER_BANDS: Array[Array] = [[1, 5], [12, 4], [21, 7]]

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
		var step := shade_step(t)
		for shade in SHADES:
			for v in VARIANTS:
				var img := _make_tile(t, rng)
				_shift(img, (shade - 1) * -step)
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

## Ein einzelner Halm: senkrecht, oben leicht geneigt, oben eine Spur blasser.
##
## Der Vorgaenger war eine gerade `vline` mit gelegentlich einem Punkt daneben.
## Ueber eine Flaeche hinweg las sich das als Kammstruktur — lauter parallele
## Striche gleicher Laenge. Eine Neigung, die nach oben zunimmt, macht aus dem
## Strich einen Halm; die Abschwaechung an der Spitze nimmt ihm die harte Kante.
func _blade(img: Image, x: int, y: int, h: int, c: Color, a: float, lean: float) -> void:
	for i in h:
		var f := float(i) / float(maxi(h - 1, 1))
		var dx := int(round(lean * f * f))
		Pixel.px(img, x + dx, y - i, Color(c, a * (1.0 - 0.22 * f)))

func _grass_tile(bg: Color, light: Color, dark: Color, hi: Color,
		rng: RandomNumberGenerator, blades: int) -> Image:
	var img := Pixel.filled(T, T, bg)

	# 1. Grosse weiche Flecken — die Struktur, die man aus zehn Metern sieht.
	#
	# Vier Toene statt zwei. Hell und dunkel allein gaben nur Helligkeit; die
	# Flaeche blieb ueberall derselbe Gruenton und sah deshalb aus wie ein
	# eingefaerbtes Rechteck. Erst eine trockene und eine beschattete Stelle
	# machen daraus eine Wiese. Beide bleiben schwaecher als die
	# Helligkeitsflecken: Farbe faellt staerker auf als Helligkeit.
	# Bewusst SCHWACH — und das ist die eigentliche Einsicht dieser Runde.
	#
	# Ein Fleck ist grossflaechige Struktur, und grossflaechige Struktur, die
	# je Variante anders liegt, ist an jeder Kachelkante ein Sprung. Gemessen
	# (`_check_variant_seams` im Selbsttest): mit kraeftigen Flecken lag die
	# Naht zwischen zwei Varianten bei 1,72, mit halbierten bei 1,43.
	#
	# Die Farbe geht dadurch nicht verloren, sie zieht nur um: die trockenen
	# und die beschatteten Toene stecken jetzt in den HALMEN (Schritt 2), also
	# in feiner Struktur. Feine Struktur darf sich je Variante unterscheiden —
	# man sieht sie nicht als Fuge, sondern als Bewuchs.
	_mottle(img, rng, 3, light, 0.07)
	_mottle(img, rng, 3, dark, 0.06)
	_mottle(img, rng, 2, Palette.GRASS_DRY, 0.05)
	_mottle(img, rng, 2, Palette.GRASS_SHADE, 0.05)

	# 2. Halme auf dem verwackelten Raster. Drei Toene, wechselnde Laenge und
	#    Neigung — die eigentliche Struktur der Flaeche.
	for p: Vector2i in _scatter(rng, 6, 1.0):
		var r := rng.randf()
		var c: Color = light if r < 0.58 else (hi if r < 0.82 else Palette.GRASS_DRY)
		_blade(img, p.x, p.y, rng.randi_range(2, 4), c,
			0.40 + rng.randf() * 0.22, rng.randf_range(-1.2, 1.2))

	# 3. Bueschel: drei kleine dichte Gruppen je Kachel.
	#
	# Gleichmaessig verteilte Halme sehen aus wie Rasen aus der Dose. Gras
	# waechst in Horsten — ein paar Stellen, an denen es dichter und hoeher
	# steht, geben der Flaeche erst ihren Massstab.
	#
	# Zwei statt drei, und schwaecher als beim ersten Versuch. Ein Bueschel ist
	# grossflaechige Struktur, und die kann zwischen zwei verschiedenen
	# Kachelvarianten nicht nahtlos sein (siehe die Tiefenbaender im Wasser).
	# Gemessen stieg die Naht auf der Wiese von 1,24 auf 1,42, als hier drei
	# kraeftige Bueschel standen. Zwei leise tun dasselbe fuer den Blick und
	# kosten die Naht kaum etwas.
	for i in 2:
		var cx := rng.randi_range(0, T - 1)
		var cy := rng.randi_range(2, T - 1)
		for k in rng.randi_range(3, 5):
			_blade(img, cx + rng.randi_range(-3, 3), cy + rng.randi_range(-2, 2),
				rng.randi_range(3, 4), hi if rng.randf() < 0.4 else light,
				0.26 + rng.randf() * 0.16, rng.randf_range(-1.4, 1.4))

	# 4. Dunkle Zwischenraeume — Tiefe zwischen den Halmen.
	for p: Vector2i in _scatter(rng, 5, 1.2):
		Pixel.vline(img, p.x, p.y, rng.randi_range(1, 2), Color(dark, 0.34 + rng.randf() * 0.16))

	# 5. Einzelne helle Spitzen, sehr sparsam: sie fangen das Licht.
	for i in blades:
		var p := Vector2i(rng.randi_range(0, T - 1), rng.randi_range(0, T - 1))
		Pixel.px(img, p.x, p.y, Color(hi, 0.55))

	# 6. Kleinkram im Boden. Hoechstens einer je Kachel und nur in gut einem
	#    Drittel der Faelle — das ist wichtig: die Dekorationsschicht streut
	#    ohnehin Blumen und Kiesel darueber, und was hier drin steht,
	#    wiederholt sich mit der Kachelvariante. Zu viel davon, und man sieht
	#    das Muster.
	if rng.randf() < 0.38:
		_speck(img, rng)
	return img

## Ein einzelnes Bodendetail: ein Kiesel, ein trockener Halm oder eine winzige
## Bluete. Alles drei nur wenige Bildpunkte gross — sie sollen den Blick nicht
## halten, sondern der Flaeche das letzte bisschen Unregelmaessigkeit geben.
func _speck(img: Image, rng: RandomNumberGenerator) -> void:
	var x := rng.randi_range(2, T - 3)
	var y := rng.randi_range(2, T - 3)
	var r := rng.randf()
	if r < 0.42:
		# Kiesel: dunkler Kern, helle Oberkante. Licht von oben links.
		Pixel.px(img, x, y, Color(Palette.STONE_DARK, 0.60))
		Pixel.px(img, x + 1, y, Color(Palette.STONE, 0.50))
		Pixel.px(img, x, y - 1, Color(Palette.STONE_LIGHT, 0.42))
	elif r < 0.76:
		# Trockener Halm: ein einzelner heller Strich im Strohton.
		_blade(img, x, y, rng.randi_range(3, 4), Palette.GRASS_DRY, 0.52,
			rng.randf_range(-1.0, 1.0))
	else:
		# Winzige Bluete: drei Bildpunkte, sonst wird sie zum Gegenstand.
		var col: Color = [Palette.FLOWER_WHITE, Palette.FLOWER_YELLOW][rng.randi() % 2]
		Pixel.px(img, x, y, Color(col, 0.62))
		Pixel.px(img, x - 1, y, Color(col, 0.34))
		Pixel.px(img, x, y - 1, Color(Palette.GRASS_DARK, 0.30))

## Sand: eine ruhige Flaeche, die trotzdem Korn zeigt.
##
## Vorher war sie so zurueckgenommen, dass bei naeherem Zoom eine fast leere
## beige Flaeche uebrig blieb — und aus der Entfernung ein einziges beiges
## Rechteck. Die Struktur kommt jetzt aus vier Ebenen: Verwehungen in vier
## Toenen, dichtes Korn auf dem verwackelten Raster, Rippelmarken mit feuchter
## Kehle, und vereinzelt etwas, das da liegt.
func _sand_tile(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.filled(T, T, Palette.SAND)

	# 1. Verwehungen. Helligkeit UND Farbe: eine sonnige und eine feuchte
	#    Stelle machen aus der Flaeche einen Strand statt einer Fuellfarbe.
	# Schwach, aus demselben Grund wie beim Gras: was gross ist und je Variante
	# anders liegt, zeigt sich als Kachelnaht. Die Farbe traegt hier das Korn
	# (Schritt 2) und die feuchte Kehle der Rippeln (Schritt 3).
	_mottle(img, rng, 4, Palette.SAND_LIGHT, 0.09)
	_mottle(img, rng, 3, Palette.SAND_DARK, 0.08)
	_mottle(img, rng, 2, Palette.SAND_WARM, 0.07)
	_mottle(img, rng, 2, Palette.SAND_DAMP, 0.07)

	# 2. Korn. Dichter als vorher (8 statt 7 Zellen je Kante) und mit einem
	#    dritten, dunkleren Ton: Sand besteht aus Koernern verschiedener
	#    Herkunft, nicht aus hell und dunkel.
	for p: Vector2i in _scatter(rng, 8, 1.0):
		var r := rng.randf()
		var c: Color = Palette.SAND_LIGHT if r < 0.48 \
			else (Palette.SAND_DARK if r < 0.86 else Palette.SAND_DAMP)
		Pixel.px(img, p.x, p.y, Color(c, 0.26 + rng.randf() * 0.24))

	# 3. Rippelmarken: eine helle Kante mit dunklem Schatten darunter — dadurch
	#    liest man sie als Welle im Sand und nicht als Kratzer. Die Kehle
	#    darunter ist eine Spur feucht, das gibt ihr Tiefe.
	for i in rng.randi_range(3, 4):
		var y := rng.randi_range(2, T - 5)
		var length := rng.randi_range(14, 26)
		var x0 := rng.randi_range(-4, T - length + 4)
		var amp := rng.randf_range(0.8, 1.6)
		var freq := rng.randf_range(0.35, 0.6)
		for s2 in length:
			var wave := int(round(sin(s2 * freq) * amp))
			Pixel.px(img, x0 + s2, y + wave, Color(Palette.SAND_LIGHT, 0.55))
			Pixel.px(img, x0 + s2, y + wave + 1, Color(Palette.SAND_DARK, 0.42))
			if (s2 % 3) != 0:
				Pixel.px(img, x0 + s2, y + wave + 2, Color(Palette.SAND_DAMP, 0.22))

	# 4. Was am Strand liegt: Kiesel und dunkle Mineralkoerner.
	for i in rng.randi_range(1, 3):
		var p := Vector2i(rng.randi_range(1, T - 2), rng.randi_range(1, T - 2))
		Pixel.px(img, p.x, p.y, Color(Palette.SAND_DARK.darkened(0.22), 0.7))
		Pixel.px(img, p.x, p.y - 1, Color(Palette.SAND_LIGHT, 0.5))
	# Mineralkoerner: einzelne fast schwarze Punkte. Sie sind der Grund, warum
	# echter Sand nie ganz sauber aussieht.
	for i in rng.randi_range(2, 5):
		Pixel.px(img, rng.randi_range(0, T - 1), rng.randi_range(0, T - 1),
			Color(Palette.STONE_DARK, 0.26 + rng.randf() * 0.18))
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

	# 1. Tiefenwirkung: breite, weiche Baender in der dunklen Farbe.
	#
	#    Sie stehen in JEDER Variante an derselben Stelle — und das ist der
	#    Punkt. Vorher wuerfelte jede Variante ihre Baender neu aus. Ein Band
	#    laeuft ueber die volle Kachelbreite und hoert an der Kante auf; stiess
	#    dort eine Kachel ohne Band an, sprang die Helligkeit. Gemessen war die
	#    Naht im Wasser 1,62-mal so stark wie das Kachelinnere — auf einer
	#    grossen ruhigen Wasserflaeche sah man das als Gitter.
	#
	#    Grossflaechige Struktur kann zwischen zwei verschiedenen Varianten
	#    nicht nahtlos sein. Entweder sie ist ueberall gleich, oder man sieht
	#    die Fuge. Also ist sie ueberall gleich: die Unterschiede zwischen den
	#    Kacheln kommen aus den Lagen darueber, und die sind alle klein oder
	#    weich.
	for band: Array in WATER_BANDS:
		var y: int = int(band[0])
		var h: int = int(band[1])
		for dy in h:
			var a := 0.16 * (1.0 - absf(float(dy) - h * 0.5) / (h * 0.5)) + 0.06
			Pixel.hline(img, 0, y + dy, T, Color(deep, a))

	# 2. Eine mittlere Lage aus weichen Flecken. Ohne sie liegen die Bänder aus
	#    Schritt 1 als waagerechte Streifen über der ganzen Fläche.
	var mid := bg.lerp(hi, 0.35)
	_mottle(img, rng, 3, mid, 0.09)
	_mottle(img, rng, 2, deep, 0.07)

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

	# 3b. Der Reflex: Licht, das sich auf der Oberflaeche spiegelt.
	#
	#     Vorher waren das drei Bildpunkte diagonal bei 16 Prozent — auf dem
	#     Bildschirm nicht zu sehen. Eine Spiegelung auf bewegtem Wasser sieht
	#     anders aus: ein heller Streifen, den die Wellen in kurze waagerechte
	#     Stuecke zerschneiden, nach unten hin schwaecher werdend.
	#
	#     Drei Reihen genuegen dafuer. Sie liegen versetzt uebereinander, jede
	#     kuerzer und blasser als die darueber — das ist die ganze Form, und
	#     man liest sie sofort als Spiegelung statt als Fleck. Waagerecht, weil
	#     die Wellenbaender waagerecht laufen; eine senkrechte Spiegelung
	#     stuende quer zur Oberflaeche.
	if rng.randf() < 0.62:
		var rx := rng.randi_range(3, T - 12)
		var ry := rng.randi_range(3, T - 8)
		var rows: Array[Array] = [[7, 0.30], [5, 0.19], [3, 0.11]]
		for k in rows.size():
			var run: int = int(rows[k][0])
			var a: float = float(rows[k][1])
			var off := rng.randi_range(-1, 2)
			for i in run:
				# Eine Luecke je Reihe: ein durchgehender Strich waere ein
				# Kratzer, kein Spiegelbild.
				if i == run / 2:
					continue
				Pixel.px(img, rx + off + i, ry + k * 2, Color(Palette.WATER_FOAM, a))

	# 4. Feines Funkeln, sehr sparsam.
	for p: Vector2i in _scatter(rng, 4, 1.5):
		if rng.randf() < 0.45:
			Pixel.px(img, p.x, p.y, Color(Palette.WATER_FOAM, 0.22))
	return img
