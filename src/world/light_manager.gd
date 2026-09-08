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

## Farbe und Helligkeit über den Tag. Der erste Wert ist die Uhrzeit von 0
## (Mitternacht) bis 1, der zweite die Tönung, mit der die Welt multipliziert
## wird. Weiss heisst: unverändert.
##
## Die Nacht ist deutlich dunkler als in der ersten Fassung (0,40 / 0,46 / 0,68
## vorher, jetzt 0,26 / 0,30 / 0,50). Das ging erst, seit der Schein um die
## Figur nichts mehr kostet: eine dunkle Nacht ohne bezahlbares Licht wäre eine
## Zwangspause gewesen, mit Licht ist sie Atmosphäre.
const RAMP := [
	[0.00, Color(0.26, 0.30, 0.50)],   ## tiefe Nacht, blau
	[0.17, Color(0.40, 0.42, 0.60)],   ## erste Dämmerung
	[0.23, Color(0.92, 0.74, 0.66)],   ## Morgenrot
	[0.30, Color(1.00, 0.97, 0.93)],   ## Vormittag
	[0.50, Color(1.00, 1.00, 1.00)],   ## Mittag
	[0.70, Color(1.00, 0.96, 0.88)],   ## Nachmittag
	[0.79, Color(0.98, 0.72, 0.56)],   ## Abendrot
	[0.86, Color(0.52, 0.46, 0.64)],   ## Dämmerung
	[1.00, Color(0.26, 0.30, 0.50)],   ## wieder Nacht
]

## Wie weit über dem Standpunkt der Schein der Figur sitzt. Die Figur wird an
## ihren FÜSSEN positioniert; ein Licht dort sähe aus, als trüge sie die
## Laterne am Knöchel. Achtzehn Pixel liegen auf Höhe der Brust.
const LIGHT_LIFT := 18.0

## Radius des Grundscheins um die Figur, in Weltpixeln.
const PLAYER_RADIUS := 110.0

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
const GLOW_PEAK := 0.42

var player: Node2D
var camera: Camera2D

var _modulate: CanvasModulate
var _night: CanvasLayer
var _vignette: TextureRect
var _glow_root: Node2D
var _glow_tex: ImageTexture
var _sources: Array[LightSource] = []
var _player_light: LightSource
var _time: float = START_TIME
var _mode: int = -1
var _dark: float = 0.0
var _cycled: bool = true       ## lief die Zeit im letzten Bild?

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

	func world_pos() -> Vector2:
		if is_instance_valid(node):
			return node.global_position - Vector2(0.0, lift)
		return pos - Vector2(0.0, lift)

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

	_player_light = add_source(PLAYER_RADIUS, Color(1.0, 0.88, 0.66), 1.0, 0.0)
	_player_light.node = player
	_player_light.lift = LIGHT_LIFT

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
			img.set_pixel(x, y, Color(1, 1, 1, pow(t, 1.7)))
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

	if _mode >= 3:
		_vignette.modulate = Color(0.05, 0.06, 0.12, _dark * 0.52)
	_update_glows(delta)

## Setzt die Scheine auf ihre Bildschirmposition.
##
## Sie liegen auf einer CanvasLayer, rechnen also in Bildschirmpunkten. Die
## Umrechnung macht die Leinwandtransformation des Viewports — darin stecken
## Kameraposition UND Zoom, es gibt hier also keine zweite Stelle, an der eine
## Zoomstufe gepflegt werden müsste.
func _update_glows(delta: float) -> void:
	var to_screen := get_viewport().get_canvas_transform()
	var zoom: float = camera.zoom.x if is_instance_valid(camera) else 1.0
	var view := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	for s: LightSource in _sources:
		var energy := _dark * s.strength
		if s.flicker > 0.0:
			s.phase += delta * 7.3
			# Zwei Frequenzen: eine einzelne Schwingung sieht aus wie ein
			# Blinker, zwei ungleiche wie eine Flamme.
			var f := sin(s.phase) * 0.6 + sin(s.phase * 2.7 + 1.1) * 0.4
			energy *= 1.0 + f * 0.11 * s.flicker
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
		s.sprite.scale = Vector2.ONE * (r * 2.0 / float(GLOW_TEX))
		s.sprite.modulate = Color(s.color, clampf(energy, 0.0, 1.0) * GLOW_PEAK)

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
