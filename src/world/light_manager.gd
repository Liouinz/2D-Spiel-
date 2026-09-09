class_name LightManager
extends Node2D
## Umgebungslicht, Tagesverlauf, Lichtquellen und Sichtgrenze.
##
## ## Warum das hier einmal umgebaut wurde
##
## Die erste Fassung benutzte Godots eingebaute 2D-Beleuchtung: ein
## `PointLight2D` um die Figur und eine Vignette als Vollbild-`ColorRect` mit
## eigenem Fragment-Shader. Gemessen (llvmpipe, 1280 x 720, Renderzeit des
## Viewports, nicht Prozesszeit):
##
##   Beleuchtung aus          CPU  6,07 ms   GPU 2,66 ms
##   nur Toenung              CPU  6,06 ms   GPU 2,75 ms     <- gratis
##   + Figurenlicht           CPU  9,48 ms   GPU 2,57 ms     <- +3,43 ms CPU
##   + Vignette               CPU 11,58 ms   GPU 4,72 ms     <- +1,69 / +1,80
##
## Die Beleuchtung verdoppelte also die Renderkosten (+91 % CPU, +77 % GPU) —
## und zwar bei Tag genauso wie bei Nacht. Zwei Ursachen, beide vermeidbar:
##
## 1. Ein echtes `Light2D` zwingt den Canvas-Renderer in den beleuchteten Pfad:
##    jedes Element im Umkreis wird ein zweites Mal eingereiht, und weil das
##    Licht jedes Bild der Figur nachgeführt wird, fällt diese Arbeit auch
##    jedes Bild neu an. Das kostet CPU-Renderzeit, nicht GPU.
## 2. Ein Vollbild-Fragment-Shader rechnet `length()` und `smoothstep()` für
##    921 600 Bildpunkte — je Bild.
##
## ## Was stattdessen passiert
##
## Drei Mittel, und nur das erste fasst die Welt überhaupt an:
##
##   CanvasModulate  färbt und dunkelt die Welt über den Tag. GEMESSEN GRATIS —
##                   ein Knoten, ein Multiplizieren, unabhängig von der Zahl
##                   der Kacheln. Das ist der Teil, der gut aussieht, und der
##                   bleibt deshalb genau so.
##   Sichtgrenze     eine EINMAL GEBACKENE Verlaufstextur statt eines Shaders.
##                   Der Verlauf ist beim Start fertig; je Bild bleibt ein
##                   einziges texturiertes Rechteck.
##   Schein          additive Sprites statt echter Lichter. Ein Sprite je
##                   Lichtquelle, keine zweiten Durchgänge über die Welt.
##
## Der Unterschied zum echten Licht: ein `Light2D` multipliziert mit der Farbe
## des Untergrunds (Gras leuchtet grün), ein additiver Schein legt warmes Licht
## darüber. Für eine Fackel ist das zweite ohnehin das richtige Bild — und es
## kostet einen Bruchteil.
##
## ## Und was am Tag passiert: nichts
##
## Die ganze Nachtschicht hängt an der Dunkelheit. Am Mittag ist sie 0, dann
## sind Sichtgrenze und Schein unsichtbar und kosten nichts. Vorher lag die
## Vignette auch mittags bei Stärke 0,20 über dem Bild — sichtbar war davon
## fast nichts, bezahlt wurde sie voll.
##
## ## Vier Stufen, nicht ein Schalter
##
## Die drei Mittel kosten sehr unterschiedlich, also sind sie einzeln
## abstufbar (`Graphics.LIGHT`):
##
##   0 Aus       nichts davon, kein Prozessschritt
##   1 Einfach   nur die Tönung — der ganze Tagesverlauf, gemessen gratis
##   2 Mittel    dazu der Schein um die Figur
##   3 Hoch      dazu die Sichtgrenze am Bildrand
##
## Wer auf einem schwachen Laptop spielt, verliert mit „Einfach" also nicht die
## Nacht, sondern nur die beiden Flächen, die Füllrate kosten.

## Länge eines ganzen Tages in Sekunden. Acht Minuten: lang genug, dass der
## Wechsel nicht hektisch wirkt, kurz genug, dass man ihn in einer Sitzung sieht.
const DAY_LENGTH := 480.0

## Wo der Tag beginnt, wenn die Welt geladen wird — heller Vormittag.
const START_TIME := 0.34

## Der Ton, in den die Nacht faellt — und warum es ihn ueberhaupt braucht.
##
## `CanvasModulate` MULTIPLIZIERT. Eine blaue Toenung ueber einer gruenen Wiese
## kann daraus nie eine blaue Nacht machen: im Gras steckt fast kein Blau, das
## sich verstaerken liesse. Gras (78, 138, 68) mal (0.26, 0.30, 0.50) ergibt
## (20, 41, 34) — dunkles Gruen. Genau so sah die Nacht auch aus, obwohl in der
## Tabelle unten seit jeher „tiefe Nacht, blau" steht.
##
## Blau muss also DAZUKOMMEN, nicht durchmultipliziert werden. Das ist eine
## einzelne halbdurchsichtige Flaeche ueber der Welt, unter den Scheinen: ein
## Viereck, kein Shader. Sie liegt bewusst UNTER den additiven Scheinen — so
## faellt der warme Schein einer gesetzten Fackel in eine kalte Umgebung, und
## der Kontrast, den eine Nachtszene braucht, entsteht von selbst.
const NIGHT_BLUE := Color(0.15, 0.25, 0.52)

## Deckkraft bei voller Dunkelheit. Darueber kippt die Welt ins Comichafte,
## darunter bleibt sie das dunkle Gruen von vorher.
const NIGHT_BLUE_A := 0.28

## Farbe und Helligkeit über den Tag. Der erste Wert ist die Uhrzeit von 0
## (Mitternacht) bis 1, der zweite die Tönung, mit der die Welt multipliziert
## wird. Weiss heisst: unverändert.
##
## Die Nacht ist deutlich dunkler als in der ersten Fassung (0,40 / 0,46 / 0,68
## vorher, jetzt 0,26 / 0,30 / 0,50). Das ging erst, seit der Schein um die
## Figur nichts mehr kostet: eine dunkle Nacht ohne bezahlbares Licht wäre eine
## Zwangspause gewesen, mit Licht ist sie Atmosphäre.
const RAMP := [
	[0.00, Color(0.24, 0.28, 0.46)],   ## tiefe Nacht
	[0.17, Color(0.40, 0.42, 0.60)],   ## erste Dämmerung
	[0.23, Color(0.92, 0.74, 0.66)],   ## Morgenrot
	[0.30, Color(1.00, 0.97, 0.93)],   ## Vormittag
	[0.50, Color(1.00, 1.00, 1.00)],   ## Mittag
	[0.70, Color(1.00, 0.96, 0.88)],   ## Nachmittag
	[0.79, Color(0.98, 0.72, 0.56)],   ## Abendrot
	[0.86, Color(0.52, 0.46, 0.64)],   ## Dämmerung
	[1.00, Color(0.24, 0.28, 0.46)],   ## wieder Nacht
]

## Wie weit über dem Standpunkt der Schein der Figur sitzt. Die Figur wird an
## ihren FÜSSEN positioniert; ein Licht dort sähe aus, als trüge sie die
## Laterne am Knöchel. Achtzehn Pixel liegen auf Höhe der Brust.
const LIGHT_LIFT := 18.0

## Radius des Scheins um die Figur, in Weltpixeln.
##
## KLEINER als eine gesetzte Welt-Fackel (96). Eine gesetzte Fackel ist ein
## echtes Feuer auf einem Mast; der Schein um die Figur ist nur so viel Sicht,
## dass man die naechsten Schritte erkennt. Waere er groesser, waere jede
## gesetzte Fackel überflüssig.
const PLAYER_RADIUS := 78.0

## Und wie kräftig. Deutlich unter 1: additiv aufgetragen ist voller Anschlag
## ein weisser Fleck, und dann sieht man die Figur nicht mehr, die er zeigen
## soll. 0,62 hellt gerade so weit auf, dass Gras noch grün und Sand noch sandig
## bleibt.
const SIGHT_STRENGTH := 0.62

## Kantenlänge der gebackenen Scheintextur. 128 reicht: sie wird ohnehin weich
## skaliert, und ein Verlauf hat keine Details, die eine höhere Auflösung
## zeigen könnte.
const GLOW_TEX := 128

## Auflösung der Sichtgrenze. Sehr klein und absichtlich: ein Verlauf über den
## ganzen Bildschirm braucht keine 1280 Punkte Breite, und beim Skalieren mit
## weicher Filterung sieht man den Unterschied nicht.
const VIGNETTE_TEX := Vector2i(160, 90)

## Ab wann Sichtgrenze und Schein überhaupt gezeichnet werden.
const MIN_VISIBLE := 0.02

## Wie kräftig ein Schein höchstens wird.
##
## Der Schein liegt ÜBER der Figur und wird dazugerechnet. Bei voller Stärke
## wurde die Figur deshalb schlicht weiss — im ersten Bild der Nacht stand ein
## heller Fleck, in dem man Gesicht und Kleidung nicht mehr erkannte. Ein
## Viertel bis knapp die Hälfte reicht: über einer dunklen Nacht liest sich das
## als warmes Licht, nicht als Überbelichtung.
##
## Dieselbe Falle ein zweites Mal: mit dem hellen Kern (siehe `CORE_SHARE`)
## liegen an der Figur ZWEI Scheine uebereinander, und additiv heisst addiert.
## 0,50 plus 0,50 ergab wieder den weissen Fleck. Was zaehlt, ist die SUMME in
## der Mitte — sie muss unter etwa 0,55 bleiben, sonst laufen alle drei Kanaele
## in die Saettigung und aus dem warmen Licht wird Weiss.
const GLOW_PEAK := 0.42

## Wie weit der helle Kern des Scheins reicht, als Anteil am aeusseren
## Schein. Klein genug, dass er die Figur beleuchtet statt die halbe Wiese.
const CORE_SHARE := 0.40


## Die Farbe von Fackellicht: #FFAF64.
##
## Warmes Orange, nicht Gelb. Gelb ueber einer blauen Nacht ergibt Gruen — der
## Blauanteil der Umgebung mischt sich hinein, und uebrig bleibt ein fahler
## Ton. Je weniger Blau im Licht steckt, desto waermer bleibt der Kegel.
const TORCH_LIGHT := Color8(255, 175, 100)

## Und die Farbe des Scheins um die Figur.
##
## NICHT das Orange der Fackel: die Figur trägt keine. Ein warmer Kegel ohne
## Feuer darin ist eine Behauptung — man sucht das Licht im Bild und findet
## nichts. Ein fast neutraler, leicht sandfarbener Ton liest sich dagegen als
## das, was er ist: Restlicht, in dem man die nächsten Schritte noch erkennt.
##
## Und er ist nicht blau. Ein blauer Schein über einer blauen Nacht hellt nur
## das Blau auf — der Boden darunter bleibt eine Fläche ohne eigene Farbe. Ein
## Ton mit etwas mehr Rot und Grün holt Gras und Sand zurück, ohne dass es nach
## Feuer aussieht.
##
## Und er ist gedämpft, nicht weiss. Ein fast weisser Schein legte sich als
## milchiger Nebel über die ganze Umgebung: Boden, Figur und Nacht liefen zu
## einer einzigen blassen Fläche zusammen. Sichtbar machen heisst hier, den
## Untergrund noch erkennen zu lassen — nicht, ihn zu überstrahlen.
const NIGHT_SIGHT := Color8(206, 196, 172)

# --- Flackern ------------------------------------------------------------------
#
# Wie stark, wie oft, wie schnell. Getrennte Zahlen, weil sie Verschiedenes
# tun: SPAN ist die Auslenkung, MIN/MAX bestimmen, wie unregelmaessig es wirkt
# (gleiche Werte hier ergaeben wieder einen Takt), SPEED, wie hart der Sprung
# ist. Zu hart, und es blinkt; zu weich, und es atmet.
const FLICKER_SPAN := 0.16       ## +/- 16 % bei voller Staerke
const FLICKER_MIN := 0.05        ## kuerzester Halt auf einem Wert, in Sekunden
const FLICKER_MAX := 0.19        ## laengster
const FLICKER_SPEED := 15.0      ## wie schnell auf das Ziel zugelaufen wird

## Wie stark der Radius mitatmet — halb so stark wie die Helligkeit. Voll
## mitzupulsieren sieht aus, als wuerde die Flamme gezoomt.
const FLICKER_RADIUS := 0.5

# --- Glut ----------------------------------------------------------------------

## Wie viele Funken gleichzeitig ueber einer Flamme stehen.
const EMBER_COUNT := 4
const EMBER_RISE := 15.0         ## Weltpixel je Sekunde nach oben
const EMBER_LIFE := 1.15         ## Sekunden, bis ein Funke verloescht
const EMBER_DRIFT := 5.0         ## seitliches Taumeln

var player: Node2D
var camera: Camera2D

var _modulate: CanvasModulate
var _night: CanvasLayer
var _vignette: TextureRect
var _blue: ColorRect
var _embers: Embers

## Wie viele Funken im letzten Bild gezeichnet wurden — nur Messung fuer den
## Selbsttest. Eine Wirkung, die man nicht zaehlen kann, kann man auch nicht
## pruefen; und „ich sehe sie doch" ist bei einem Bildpunkt kein Beleg.
var embers_drawn: int = 0
var _rng := RandomNumberGenerator.new()
var _glow_root: Node2D
var _glow_tex: ImageTexture
var _sources: Array[LightSource] = []
var _player_core: LightSource
var _player_light: LightSource
var _time: float = START_TIME
var _mode: int = -1
var _dark: float = 0.0
var _cycled: bool = true       ## lief die Zeit im letzten Bild?

## Wie lange ein Lichtdurchgang dauert, geglättet, in Millisekunden. Für die
## Entwicklerinfo — und damit die Behauptung „das kostet fast nichts" eine Zahl
## hat, die man nachsehen kann, statt nur ein Satz zu sein.
var _update_ms: float = 0.0

## Eine Lichtquelle: ein weicher Schein an einer Stelle der Welt.
##
## Sie folgt entweder einem Knoten (die Figur, später ein Wesen) oder steht
## fest an einem Punkt (eine gesetzte Fackel). Gezeichnet wird sie als ein
## additives Sprite auf der Nachtschicht — nicht als Licht, siehe oben.
class LightSource:
	extends RefCounted
	var node: Node2D            ## folgt diesem Knoten, wenn gesetzt
	var pos: Vector2            ## sonst: fester Punkt in der Welt
	var lift: float = 0.0       ## wie weit über dem Standpunkt
	var radius: float = 96.0    ## in Weltpixeln
	var color: Color = Color(1.0, 0.86, 0.62)
	var strength: float = 1.0   ## Vielfaches der Dunkelheit
	var flicker: float = 0.0    ## 0 = ruhig, 1 = deutliches Flackern
	var sprite: Sprite2D
	var phase: float = 0.0

	## Versatz gegenueber `node`. Ersetzt `lift` fuer Quellen, die einem Knoten
	## folgen: der Schein der Figur sitzt nicht an ihren Fuessen, sondern auf
	## Brusthoehe darueber.
	var offset := Vector2.ZERO

	## Flackern als ZUFALLSGANG statt als Schwingung.
	##
	## Vorher waren es zwei Sinus mit ungleicher Frequenz. Das ist besser als
	## einer, aber es bleibt periodisch — und lange genug angesehen findet das
	## Auge den Takt. Ein Feuer hat keinen: es springt auf einen neuen Wert und
	## bleibt unterschiedlich lange dort. Genau das steht hier.
	var flick: float = 1.0      ## aktueller Faktor
	var flick_to: float = 1.0   ## Ziel, auf das zugelaufen wird
	var flick_left: float = 0.0 ## Sekunden, bis ein neues Ziel gewuerfelt wird

	## Glut, die aufsteigt. Leer, wenn diese Quelle keine spruehen soll.
	var embers: Array[Dictionary] = []

	func world_pos() -> Vector2:
		if is_instance_valid(node):
			return node.global_position + offset
		return pos - Vector2(0.0, lift)

## Aufsteigende Glut.
##
## Ein einziger Knoten zeichnet die Funken ALLER Feuer. Das ist kein Geiz,
## sondern die Stelle, an der die Information schon liegt: der Lichtverwalter
## kennt jede Quelle, ihre Weltposition und — wichtiger — ob sie gerade im Bild
## ist. Ein eigener Partikelknoten je Fackel muesste all das noch einmal
## wissen, und hundert gesetzte Fackeln waeren hundert Knoten.
##
## Fortbewegt werden die Funken in `_update_glows`, wo ohnehin ueber die
## Quellen gelaufen wird. Hier wird nur gezeichnet.
class Embers:
	extends Node2D
	var owner_light: LightManager

	func _draw() -> void:
		if not is_instance_valid(owner_light):
			return
		owner_light.draw_embers(self)

func _ready() -> void:
	_modulate = CanvasModulate.new()
	_modulate.name = "Tageslicht"
	add_child(_modulate)

	# Sichtgrenze und Schein liegen auf einer eigenen Ebene über der Welt und
	# unter jeder Oberfläche (HUD 5, Bauleiste 6, Inventar 8). Dort gilt die
	# Tönung nicht — sonst würde der Schein von der Nacht mit abgedunkelt, also
	# genau von dem, was er aufhellen soll.
	_night = CanvasLayer.new()
	_night.name = "Nachtschicht"
	_night.layer = 1
	add_child(_night)

	# Die Blaustunde. Erstes Kind, also GANZ UNTEN auf der Nachtschicht:
	# darueber liegen Sichtgrenze und Scheine, und ein Fackelschein soll die
	# Kaelte durchbrechen, nicht von ihr ueberdeckt werden.
	_blue = ColorRect.new()
	_blue.name = "Blaustunde"
	_blue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blue.color = Color(NIGHT_BLUE, 0.0)
	_night.add_child(_blue)

	_vignette = TextureRect.new()
	_vignette.name = "Sichtgrenze"
	_vignette.texture = _vignette_texture()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Weich filtern, nicht pixelig: das Projekt stellt global „nearest" ein,
	# damit die Kacheln scharf bleiben. Ein Verlauf ist die eine Ausnahme —
	# ohne Filterung sähe man 160 Stufen quer über den Bildschirm.
	_vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_night.add_child(_vignette)

	_glow_root = Node2D.new()
	_glow_root.name = "Schein"
	_night.add_child(_glow_root)
	_glow_tex = _glow_texture()

	# Die Glut liegt in der WELT, nicht auf der Bildschirmebene: sie steigt von
	# einem Ort auf und muss mit der Kamera wandern. z_index 2 haelt sie ueber
	# der Figur (0).
	_embers = Embers.new()
	_embers.name = "Glut"
	_embers.owner_light = self
	_embers.z_index = 2
	add_child(_embers)

	# Ohne Flackern (0,0). Die Figur trägt keine Fackel mehr; was hier leuchtet,
	# ist kein Feuer, sondern der Rest an Sicht, den man nachts noch hat. Etwas,
	# das zuckt, behauptet eine Flamme, die es nicht gibt.
	_player_light = add_source(PLAYER_RADIUS, NIGHT_SIGHT, SIGHT_STRENGTH, 0.0)
	_player_light.node = player
	_player_light.offset = Vector2(0.0, -LIGHT_LIFT)

	# Ein zweiter, kleiner Schein direkt an der Figur.
	#
	# Ein einzelner weicher Verlauf ueber 76 Pixel ist ein gleichmaessiger
	# Hauch — er hellt auf, aber er beleuchtet niemanden. Eine Flamme hat einen
	# Kern: dicht am Feuer ist es hell, und das faellt schnell ab. Zwei
	# uebereinandergelegte Verlaeufe unterschiedlicher Weite ergeben genau
	# diese Kurve, und der zweite kostet ein weiteres Viereck.
	_player_core = add_source(PLAYER_RADIUS * CORE_SHARE,
		NIGHT_SIGHT.lightened(0.10), SIGHT_STRENGTH * 0.32, 0.0)
	_player_core.node = player
	_player_core.offset = Vector2(0.0, -LIGHT_LIFT)

	Graphics.applied.connect(_apply_mode)
	_apply_mode()

# --- Lichtquellen -------------------------------------------------------------

## Meldet eine neue Lichtquelle an. Der Rückgabewert ist der Griff, mit dem sie
## bewegt oder wieder abgemeldet wird.
func add_source(radius: float, color: Color, strength: float = 1.0,
		flicker: float = 0.0) -> LightSource:
	var s := LightSource.new()
	s.radius = radius
	s.color = color
	s.strength = strength
	s.flicker = flicker
	s.phase = randf() * TAU
	s.sprite = Sprite2D.new()
	s.sprite.texture = _glow_tex
	s.sprite.centered = true
	s.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Additiv: der Schein legt Licht dazu, statt die Farbe darunter zu ersetzen.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.sprite.material = mat
	s.sprite.visible = false
	_glow_root.add_child(s.sprite)
	_sources.append(s)
	return s

## Meldet eine Lichtquelle wieder ab.
func remove_source(s: LightSource) -> void:
	if s == null or not _sources.has(s):
		return
	_sources.erase(s)
	if is_instance_valid(s.sprite):
		s.sprite.queue_free()

## Wie viele Lichtquellen es gerade gibt — für die Entwicklerinfo.
func source_count() -> int:
	return _sources.size()

## Der Schein der Figur — für Anzeige und Selbsttest.
func player_glow() -> Sprite2D:
	return _player_light.sprite if _player_light != null else null

## Wie viele davon gerade wirklich gezeichnet werden.
func lit_count() -> int:
	var n := 0
	for s: LightSource in _sources:
		if is_instance_valid(s.sprite) and s.sprite.visible:
			n += 1
	return n

# --- Gebackene Bilder ---------------------------------------------------------

## Weicher runder Verlauf als Scheintextur — einmal beim Start.
func _glow_texture() -> ImageTexture:
	var img := Pixel.make(GLOW_TEX, GLOW_TEX)
	var c := GLOW_TEX * 0.5
	for y in GLOW_TEX:
		for x in GLOW_TEX:
			var t := 1.0 - clampf(Vector2(x + 0.5 - c, y + 0.5 - c).length() / c, 0.0, 1.0)
			# Etwas flacher als quadratisch: die Mitte bleibt weich, statt in
			# einem hellen Kern zusammenzulaufen. Linear sähe dagegen aus wie
			# ein Scheinwerferkegel mit harter Kante.
			#
			# Von 1,7 auf 1,45 heruntergenommen, als das Licht von der Brust an
			# die Flamme wanderte: die Quelle sitzt seither seitlich neben der
			# Figur, und mit dem steileren Abfall lag ihr halber Koerper schon
			# im Auslauf. Flacher heisst hier weiter, nicht heller.
			img.set_pixel(x, y, Color(1, 1, 1, pow(t, 1.45)))
	return Pixel.tex(img)

## Die Sichtgrenze: aussen dunkel, in der Mitte offen. Einmal gebacken.
func _vignette_texture() -> ImageTexture:
	var w := VIGNETTE_TEX.x
	var h := VIGNETTE_TEX.y
	var img := Pixel.make(w, h)
	for y in h:
		for x in w:
			var u := (x + 0.5) / float(w) - 0.5
			var v := (y + 0.5) / float(h) - 0.5
			# Auf die Diagonale bezogen, damit die Ecken nicht überbetont sind.
			var d := Vector2(u, v).length() * 1.414 * 2.0
			img.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.52, 1.06, d)))
	return Pixel.tex(img)

# --- Zustand ------------------------------------------------------------------

func _apply_mode() -> void:
	var mode := Graphics.light_mode()
	if mode == _mode:
		return
	_mode = mode
	# „Aus" heisst wirklich aus: keine Tönung, keine Sichtgrenze, kein Schein,
	# kein Prozessschritt.
	_modulate.visible = mode > 0
	_night.visible = mode > 0
	# Stufe 2 bringt den Schein, Stufe 3 zusätzlich die Sichtgrenze.
	_glow_root.visible = mode >= 2
	_vignette.visible = mode >= 3
	set_process(mode > 0)
	_refresh()

func _process(delta: float) -> void:
	# Die Zeit hängt an einer eigenen Einstellung, nicht an der Lichtstufe:
	# ein stehender Tag kostet genauso viel wie ein laufender, das ist eine
	# Frage des Spielgefühls.
	var cycle := Graphics.day_cycle()
	if cycle:
		_time = fposmod(_time + delta / DAY_LENGTH, 1.0)
	elif _cycled:
		# Nur im Augenblick des Umschaltens auf den hellen Vormittag springen.
		# Jedes Bild zurückzusetzen hiesse, dass `set_time()` bei stehender
		# Zeit gar nichts bewirkt — eine stille Falle für jeden Aufrufer.
		_time = START_TIME
	_cycled = cycle
	_refresh(delta)

func _refresh(delta: float = 0.0) -> void:
	if _mode <= 0:
		return
	var t0 := Time.get_ticks_usec()
	var tint := tint_at(_time)
	_modulate.color = tint

	# Wie dunkel es ist — daraus folgt alles Weitere. Gerechnet aus der
	# geltenden Tönung, nicht aus der Uhrzeit: ändert sich der Verlauf oben,
	# passt sich der Rest von selbst an.
	_dark = clampf((0.86 - tint.get_luminance()) * 2.0, 0.0, 1.0)

	# Am Tag ist die ganze Nachtschicht unsichtbar und kostet nichts.
	var lit := _dark > MIN_VISIBLE and _mode >= 2
	if _night.visible != lit:
		_night.visible = lit
	if not lit:
		return

	_blue.color = Color(NIGHT_BLUE, _dark * NIGHT_BLUE_A)
	if _mode >= 3:
		_vignette.modulate = Color(0.05, 0.06, 0.12, _dark * 0.52)
	_update_glows(delta)
	_measure(t0)

## Setzt die Scheine auf ihre Bildschirmposition.
##
## Sie liegen auf einer CanvasLayer, rechnen also in Bildschirmpunkten. Die
## Umrechnung macht die Leinwandtransformation des Viewports — darin stecken
## Kameraposition UND Zoom, es gibt hier also keine zweite Stelle, an der eine
## Zoomstufe gepflegt werden müsste.
func _update_glows(delta: float) -> void:
	var any_embers := false
	var to_screen := get_viewport().get_canvas_transform()
	var zoom: float = camera.zoom.x if is_instance_valid(camera) else 1.0
	var view := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	for s: LightSource in _sources:
		var energy := _dark * s.strength
		if s.flicker > 0.0:
			# Zufallsgang: alle 0,05 bis 0,19 Sekunden ein neues Ziel, dann
			# schnell darauf zu. Weder die Hoehe der Spruenge noch ihr Abstand
			# wiederholt sich — das ist der Unterschied zu einer Schwingung.
			s.flick_left -= delta
			if s.flick_left <= 0.0:
				s.flick_to = 1.0 + _rng.randf_range(-FLICKER_SPAN, FLICKER_SPAN) * s.flicker
				s.flick_left = _rng.randf_range(FLICKER_MIN, FLICKER_MAX)
			s.flick = lerpf(s.flick, s.flick_to, clampf(delta * FLICKER_SPEED, 0.0, 1.0))
			energy *= s.flick
		var screen: Vector2 = to_screen * s.world_pos()
		var r := s.radius * zoom
		# Ausserhalb des Bildes wird gar nicht gezeichnet. Eine Fackel drei
		# Chunks weiter kostet damit nichts ausser diesem Vergleich.
		var on_screen := view.grow(r).has_point(screen)
		var show := on_screen and energy > MIN_VISIBLE
		if s.sprite.visible != show:
			s.sprite.visible = show
		if not show:
			continue
		s.sprite.position = screen
		# Der Radius atmet mit, halb so stark wie die Helligkeit.
		var breathe := 1.0 + (s.flick - 1.0) * FLICKER_RADIUS
		s.sprite.scale = Vector2.ONE * (r * breathe * 2.0 / float(GLOW_TEX))
		s.sprite.modulate = Color(s.color, clampf(energy, 0.0, 1.0) * GLOW_PEAK)
		if not s.embers.is_empty():
			_step_embers(s, delta)
			any_embers = true
	if any_embers and is_instance_valid(_embers):
		_embers.queue_redraw()

# --- Glut ---------------------------------------------------------------------

## Meldet, dass diese Quelle Funken spruehen soll.
func add_embers(s: LightSource) -> void:
	s.embers.clear()
	for i in EMBER_COUNT:
		# Beim Anlegen ueber die Lebensdauer verteilt, sonst starten alle vier
		# gemeinsam und steigen als Kette auf.
		s.embers.append(_new_ember(float(i) / float(EMBER_COUNT) * EMBER_LIFE))

func _new_ember(age: float = 0.0) -> Dictionary:
	return {
		"age": age,
		"x": _rng.randf_range(-1.6, 1.6),      ## Startversatz an der Flamme
		"sway": _rng.randf_range(-1.0, 1.0),   ## Richtung des Taumelns
		"rate": _rng.randf_range(0.78, 1.24),  ## wie schnell dieser Funke steigt
	}

## Ein Schritt fuer die Funken EINER Quelle. Aufgerufen nur, wenn sie im Bild
## ist — Glut ueber einer Fackel drei Chunks weiter kostet nichts.
func _step_embers(s: LightSource, delta: float) -> void:
	for i in s.embers.size():
		var e: Dictionary = s.embers[i]
		e["age"] = float(e["age"]) + delta
		if float(e["age"]) >= EMBER_LIFE:
			s.embers[i] = _new_ember()

## Zeichnet die Funken aller Quellen. Weltkoordinaten.
##
## Ein Funke ist EIN Bildpunkt. Zwei waeren ein Klotz, und an einem Feuer sieht
## man ohnehin nur den Lichtpunkt, nicht die Form. Er wird nach oben hin
## schwaecher und kuehlt von Gelb nach Rot ab — das ist die ganze Erzaehlung:
## etwas Heisses steigt auf und erlischt.
func draw_embers(on: CanvasItem) -> void:
	embers_drawn = 0
	for s: LightSource in _sources:
		if s.embers.is_empty() or not is_instance_valid(s.sprite) or not s.sprite.visible:
			continue
		var base := s.world_pos()
		for e: Dictionary in s.embers:
			var t: float = float(e["age"]) / EMBER_LIFE
			if t >= 1.0:
				continue
			var rise: float = EMBER_RISE * float(e["rate"]) * float(e["age"])
			var sway: float = sin(float(e["age"]) * 3.4 + float(e["sway"]) * 6.0) \
				* EMBER_DRIFT * t
			var p := (base + Vector2(float(e["x"]) + sway, -rise)).round()
			# Verloescht nicht linear: die letzten Zehntel gehen schnell.
			var a := pow(1.0 - t, 1.5) * _dark
			if a <= 0.03:
				continue
			var col := ActorArt.FLAME_IN.lerp(ActorArt.FLAME_OUT, t)
			on.draw_rect(Rect2(p, Vector2.ONE), Color(col, a), true)
			embers_drawn += 1

# --- Auskunft -----------------------------------------------------------------

## Die Tönung zu einer Uhrzeit (0 … 1). Öffentlich, damit der Selbsttest den
## Verlauf prüfen kann, ohne acht Minuten zu warten.
static func tint_at(time: float) -> Color:
	var t := fposmod(time, 1.0)
	for i in range(RAMP.size() - 1):
		var a: Array = RAMP[i]
		var b: Array = RAMP[i + 1]
		if t >= a[0] and t <= b[0]:
			var span: float = b[0] - a[0]
			var f: float = 0.0 if span <= 0.0 else (t - a[0]) / span
			return (a[1] as Color).lerp(b[1] as Color, f)
	return RAMP[0][1]

## Gleitender Mittelwert statt Rohwert: der Rohwert schwankt je Bild um ein
## Vielfaches, und eine Anzeige, die vierzigmal je Sekunde springt, liest
## niemand.
func _measure(t0: int) -> void:
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	_update_ms = lerpf(_update_ms, ms, 0.1)

## Wie lange ein Lichtdurchgang dauert, in Millisekunden.
func update_msec() -> float:
	return _update_ms

## Läuft die Beleuchtung überhaupt? Auf Stufe „Aus" ist alles abgehängt.
func active() -> bool:
	return _mode > 0

## Wie dunkel es gerade ist: 0 am Mittag, knapp 1 um Mitternacht.
func darkness() -> float:
	return _dark

## Wie stark der Schein um die Figur gerade angefordert wird: 0 am Mittag, 1 um
## Mitternacht. Auf dem Bild landet davon `GLOW_PEAK` — die Zahl hier ist der
## Antrieb, nicht die Deckkraft.
func light_energy() -> float:
	return _dark * _player_light.strength if _player_light != null else 0.0

## Die geltende Tönung der Welt.
func tint() -> Color:
	return _modulate.color

## Uhrzeit von 0 (Mitternacht) bis 1 — für Anzeige und Selbsttest.
func time_of_day() -> float:
	return _time

## Setzt die Uhrzeit. Der Selbsttest springt damit durch den Tag.
func set_time(t: float) -> void:
	_time = fposmod(t, 1.0)
	_refresh()
