class_name DecorArt
extends RefCounted
## Streu-Dekoration: die kleinen Dinge, die aus einer Bodenfläche eine Landschaft
## machen — Grasbüschel, Blumen, Kiesel, Muscheln, Treibholz.
##
## Sie liegen als eigene Kachelschicht über dem Boden, nicht als Spielobjekte.
## Das ist der entscheidende Unterschied: eine Kachelschicht kostet nichts
## zusätzlich (sie wird mit dem Chunk gemalt und mit ihm entladen), während
## tausende einzelne Knoten die Welt sofort unbezahlbar machen würden.
##
## Jede Kachel ist 32 x 32 und fast vollständig durchsichtig; das Objekt sitzt an
## einer festen Stelle darin. Von jeder Art gibt es mehrere Kacheln mit
## unterschiedlicher Lage — dadurch steht die Dekoration nicht in der Mitte
## jedes Feldes wie aufgereiht, sondern verteilt sich über die Fläche.
##
## Licht kommt wie überall im Spiel von oben links: helle Kante oben links,
## Schatten unten rechts.

const T := Config.TILE
const COLS := 8

## Wie viele Lagen es je Art gibt.
const PLACEMENTS := 4

## Was auf welchem Boden wächst bzw. liegt.
enum Kind { TUFT, TUFT_BIG, FLOWER_RED, FLOWER_YELLOW, FLOWER_WHITE, CLOVER,
	STONE, PEBBLES, SHELL, DRIFTWOOD }

const ON_GRASS := [Kind.TUFT, Kind.TUFT_BIG, Kind.FLOWER_RED, Kind.FLOWER_YELLOW,
	Kind.FLOWER_WHITE, Kind.CLOVER, Kind.STONE]
const ON_SAND := [Kind.PEBBLES, Kind.SHELL, Kind.DRIFTWOOD, Kind.STONE]

## -> {"texture", "slots": Array[Vector2i], "grass": Array[int], "sand": Array[int]}
##
## `grass` und `sand` sind Listen von Plätzen in `slots` — beim Malen wird
## daraus einer ausgewürfelt.
static func build(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 55
	var kinds := Kind.size()
	var total := kinds * PLACEMENTS
	var rows := int(ceil(float(total) / COLS))
	var img := Pixel.make(COLS * T, rows * T)
	var slots: Array[Vector2i] = []
	var grass: Array[int] = []
	var sand: Array[int] = []

	for kind in kinds:
		for p in PLACEMENTS:
			var index := kind * PLACEMENTS + p
			var tile := Pixel.make(T, T)
			# Lage innerhalb der Kachel. Rand freilassen, damit nichts an der
			# Kachelgrenze abgeschnitten wird.
			var at := Vector2i(rng.randi_range(8, T - 10), rng.randi_range(8, T - 10))
			_draw(tile, kind, at, rng)
			var pos := Vector2i(index % COLS, index / COLS)
			img.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), pos * T)
			slots.append(pos)
			if ON_GRASS.has(kind):
				grass.append(index)
			if ON_SAND.has(kind):
				sand.append(index)

	return {"texture": Pixel.tex(img), "slots": slots, "grass": grass, "sand": sand}

static func _draw(img: Image, kind: int, at: Vector2i, rng: RandomNumberGenerator) -> void:
	match kind:
		Kind.TUFT: _tuft(img, at, rng, 4)
		Kind.TUFT_BIG: _tuft(img, at, rng, 7)
		Kind.FLOWER_RED: _flower(img, at, rng, Palette.FLOWER_RED)
		Kind.FLOWER_YELLOW: _flower(img, at, rng, Palette.FLOWER_YELLOW)
		Kind.FLOWER_WHITE: _flower(img, at, rng, Palette.FLOWER_WHITE)
		Kind.CLOVER: _clover(img, at, rng)
		Kind.STONE: _stone(img, at, rng)
		Kind.PEBBLES: _pebbles(img, at, rng)
		Kind.SHELL: _shell(img, at, rng)
		Kind.DRIFTWOOD: _driftwood(img, at, rng)

## Grasbüschel.
##
## Der schwierige Teil: ein Büschel steht auf Gras und besteht aus Gras. Ohne
## Wertkontrast liest man es als etwas dichteren Boden, nicht als Objekt — genau
## so sah die erste Fassung aus. Drei Dinge machen daraus ein Ding:
##
##   ein dunkler Kontaktschatten am Fuss  — es steht auf etwas
##   dunkle Halmfüsse, helle Spitzen      — es hat Form
##   eine klare Silhouette nach oben      — man erkennt es am Umriss
static func _tuft(img: Image, at: Vector2i, rng: RandomNumberGenerator, blades: int) -> void:
	var span := 1 + blades / 3
	# Kontaktschatten: ein paar Punkte, nicht mehr.
	#
	# Zweimal danebengegriffen, beide Male mit demselben Ergebnis — ein
	# durchgehender schwarzer Balken unter dem Büschel, der wie ein Loch im
	# Boden aussah. Erst als Ellipse, dann als volle Reihe; dazu kam, dass
	# jeder Halm zusätzlich einen dunklen Fusspunkt setzte und sieben Halme
	# nebeneinander daraus wieder eine Linie machten. Bei sechs Pixel hohen
	# Objekten ist ein Schatten drei Punkte breit und kaum sichtbar.
	Pixel.px(img, at.x, at.y + 1, Color(0, 0, 0, 0.16))
	Pixel.px(img, at.x - 1, at.y + 1, Color(0, 0, 0, 0.10))
	Pixel.px(img, at.x + 1, at.y + 1, Color(0, 0, 0, 0.10))
	for i in blades:
		var lean := roundi(lerpf(-span, span, float(i) / maxf(blades - 1.0, 1.0)))
		var h := rng.randi_range(4, 6) + (1 if absi(lean) < span else 0)
		var x := at.x + lean
		for s in h:
			# Der Halm neigt sich nach aussen, je weiter oben, desto stärker.
			var dx := roundi(lean * (float(s) / h) * 0.7)
			# Unten dunkel, oben hell: das gibt dem Halm Länge und Richtung.
			var f := float(s) / maxf(h - 1.0, 1.0)
			var c := Palette.GRASS_DARK.lerp(Palette.GRASS_LIGHT, minf(f * 1.5, 1.0))
			if s == h - 1:
				c = Palette.GRASS_HI
			Pixel.px(img, x + dx, at.y - s, Color(c, 0.97))

## Blume: kleines Büschel mit einer Blüte darüber. Die Blüte bekommt einen
## helleren Kern, sonst ist sie nur ein Farbfleck.
static func _flower(img: Image, at: Vector2i, rng: RandomNumberGenerator, col: Color) -> void:
	_tuft(img, at, rng, 3)
	var top := at.y - rng.randi_range(4, 6)
	var x := at.x + rng.randi_range(-1, 1)
	Pixel.vline(img, x, top + 1, 3, Color(Palette.GRASS_DARK, 0.8))
	# Blütenblätter als Kreuz, Kern heller
	Pixel.px(img, x, top - 1, col)
	Pixel.px(img, x - 1, top, col)
	Pixel.px(img, x + 1, top, col.darkened(0.15))
	Pixel.px(img, x, top + 1, col.darkened(0.15))
	Pixel.px(img, x, top, col.lightened(0.35))

## Klee: drei runde Blättchen dicht beieinander.
static func _clover(img: Image, at: Vector2i, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var ox: int = [-2, 1, 0][i]
		var oy: int = [0, 0, -2][i]
		var c := Palette.GRASS_LIGHT if i != 2 else Palette.GRASS_HI
		Pixel.rect(img, at.x + ox, at.y + oy, 2, 2, Color(c, 0.92))
		Pixel.px(img, at.x + ox, at.y + oy, Color(c.lightened(0.2), 0.92))
	Pixel.px(img, at.x, at.y + 2, Color(Palette.GRASS_DARK, 0.7))
	if rng.randf() < 0.5:
		Pixel.px(img, at.x + 2, at.y + 1, Color(Palette.GRASS_DARK, 0.5))

## Stein: rundlicher Körper, helle Oberkante links, Schatten rechts unten und
## ein Kontaktschatten auf dem Boden.
static func _stone(img: Image, at: Vector2i, rng: RandomNumberGenerator) -> void:
	var w := rng.randi_range(5, 7)
	var h := rng.randi_range(4, 5)
	Pixel.ellipse(img, at.x + w * 0.5, at.y + h * 0.5 + 1.0, w * 0.62, h * 0.42,
		Color(0, 0, 0, 0.22))
	Pixel.ellipse(img, at.x + w * 0.5, at.y + h * 0.5, w * 0.5, h * 0.5, Palette.STONE)
	Pixel.ellipse(img, at.x + w * 0.5 - 0.6, at.y + h * 0.5 - 0.7, w * 0.34, h * 0.30,
		Palette.STONE_LIGHT)
	Pixel.px(img, at.x + w - 1, at.y + h - 1, Palette.STONE_DARK)
	Pixel.px(img, at.x + w - 2, at.y + h - 1, Palette.STONE_DARK)

## Kiesel: zwei bis drei winzige Steine nebeneinander.
static func _pebbles(img: Image, at: Vector2i, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(2, 3):
		var ox := rng.randi_range(-3, 3)
		var oy := rng.randi_range(-2, 2)
		Pixel.px(img, at.x + ox, at.y + oy + 1, Color(0, 0, 0, 0.18))
		Pixel.px(img, at.x + ox, at.y + oy, Palette.STONE)
		Pixel.px(img, at.x + ox, at.y + oy, Color(Palette.STONE_LIGHT, 0.55))
		if rng.randf() < 0.5:
			Pixel.px(img, at.x + ox + 1, at.y + oy, Palette.STONE_DARK)

## Muschel: ein kleiner Fächer mit Rillen.
static func _shell(img: Image, at: Vector2i, _rng: RandomNumberGenerator) -> void:
	var c := Color8(238, 226, 208)
	Pixel.ellipse(img, at.x, at.y + 1.0, 3.0, 2.4, Color(0, 0, 0, 0.18))
	Pixel.ellipse(img, at.x, at.y, 3.0, 2.6, c)
	Pixel.ellipse(img, at.x - 0.5, at.y - 0.5, 2.0, 1.6, c.lightened(0.25))
	# Rillen
	for dx in [-2, 0, 2]:
		Pixel.px(img, at.x + dx, at.y + 1, Color8(206, 186, 164))
	Pixel.px(img, at.x, at.y + 2, Color8(196, 174, 150))

## Treibholz: ein kurzer Ast mit heller Oberseite.
static func _driftwood(img: Image, at: Vector2i, rng: RandomNumberGenerator) -> void:
	var len := rng.randi_range(6, 9)
	var dy := rng.randi_range(-1, 1)
	for s in len:
		var y := at.y + roundi(s * dy / float(len))
		Pixel.px(img, at.x + s, y + 1, Color(0, 0, 0, 0.20))
		Pixel.px(img, at.x + s, y, Palette.WOOD_DARK)
		Pixel.px(img, at.x + s, y - 1, Palette.WOOD)
	Pixel.px(img, at.x, at.y - 1, Palette.WOOD_LIGHT)
	Pixel.px(img, at.x + len - 1, at.y, Palette.WOOD_DARK.darkened(0.2))
