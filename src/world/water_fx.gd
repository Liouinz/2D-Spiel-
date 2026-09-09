class_name WaterFx
extends Node2D
## Animiertes Wasser: Glitzern, Eintauchringe und Kielwellen.
##
## Hier steht NUR, was sich bewegt. Alles Feste am Wasser — Uferschaum,
## Tiefenbaender, Reflexe — steckt in der Kachel selbst und wird einmal
## gezeichnet.
##
## Das war nicht immer so, und die Trennung ist teuer erkauft: es gab hier
## einen `_foam()`, der einen Schaumsaum an die Kachelkanten jeder Wasserzelle
## malte. Seit sich die Wasserzeichnung um eine halbe Kachel ZURUECKZIEHT
## (siehe `GroundTileSet.SHRINK`), liegt diese Kante nicht mehr am Wasser,
## sondern einen halben Block draussen im Sand. Auf dem Bildschirm war das ein
## blasses, gestricheltes Rechteck rund um jeden Teich — dieselbe Sorte Fehler
## wie ein dunkles Rechteck, nur in Hellgrau.
##
## Es waere moeglich gewesen, den Saum auf die gezeichnete Linie zu schieben.
## Die verlaeuft aber verrauscht durch die Kachelmitte; ein Saum daneben traefe
## mal Wasser, mal Sand, und stuende wieder als Linie da. Also gilt hier
## dieselbe Regel wie beim Ufer: EINE Quelle. Der Schaum ist gebacken
## (`TerrainAtlas.Rim.SHORE`), und was hier lebt, lebt gut sichtbar INNERHALB
## der Wasserflaeche.
##
## Zwei Sparmassnahmen halten das billig:
## 1. Gezeichnet wird nur der sichtbare Ausschnitt.
## 2. Das Bild wird nur rund 24-mal je Sekunde neu aufgebaut.

const T := Config.TILE
const SPLASH_TIME := 0.55    ## Lebensdauer eines Wellenrings
const WAKE_TIME := 0.9       ## Lebensdauer einer Kielwelle — länger, sie ist leiser
const WAKE_EVERY := 0.16     ## Abstand zwischen zwei Kielwellen in Sekunden

## Wie viele Wellen höchstens gleichzeitig leben. Beim Durchqueren eines
## grossen Teichs entstünden sonst hunderte; ab einem Dutzend sieht man ohnehin
## keine einzelne mehr, sondern nur noch eine helle Spur.
const MAX_WAVES := 18

var camera: GameCamera
var prims: int = 0           ## gezeichnete Rechtecke im letzten Bild (nur Messung)

var _map: MapData
var _time: float = 0.0
var _splashes: Array = []      ## {"pos": Vector2, "age": float}
var _accum: float = 0.0

## Muss vor dem ersten Zeichnen aufgerufen werden.
func setup(map: MapData) -> void:
	_map = map

## Nach einer Änderung an einer Kachel neu zeichnen.
func refresh(_cell: Vector2i) -> void:
	queue_redraw()

## Ein Wellenring, wenn jemand eintaucht.
func splash(pos: Vector2) -> void:
	_add_wave({"pos": pos, "age": 0.0, "life": SPLASH_TIME, "dir": Vector2.ZERO})

## Eine Kielwelle hinter jemandem, der sich im Wasser bewegt.
##
## Getrennt vom Eintauchring, weil sie etwas anderes erzählt: der Ring sagt
## „hier ist gerade jemand hineingefallen", die Kielwelle sagt „hier zieht
## jemand durch". Sie ist deshalb schwächer, länger sichtbar und in die
## Gegenrichtung der Bewegung gezogen.
func wake(pos: Vector2, dir: Vector2) -> void:
	_add_wave({"pos": pos, "age": 0.0, "life": WAKE_TIME, "dir": dir.normalized()})

func _add_wave(w: Dictionary) -> void:
	if _splashes.size() >= MAX_WAVES:
		_splashes.pop_front()
	_splashes.append(w)
	queue_redraw()

func _process(delta: float) -> void:
	# Wellen altern IMMER, auch wenn nichts gezeichnet wird.
	#
	# Vorher stand der Abbruch weiter oben, und die Figur meldete ihre Wellen
	# trotzdem weiter: auf der ruhigen Stufe sammelten sich achtzehn tote
	# Eintraege an, die beim Umschalten schlagartig alle auf einmal erschienen.
	# Altern kostet eine Zahl je Welle; ein falscher Zustand kostet mehr.
	if not _splashes.is_empty():
		for sp: Dictionary in _splashes:
			sp["age"] += delta
		_splashes = _splashes.filter(func(sp: Dictionary) -> bool:
			return sp["age"] < float(sp["life"]))

	# Auf der einfachsten Wasserstufe bleibt die Fläche ruhig: kein Glitzern,
	# keine Brandung, keine Wellenringe — und damit auch kein Neuzeichnen. Das
	# ist der grösste Einzelposten, den sich ein schwacher Rechner sparen kann.
	if not Graphics.water_animated():
		return
	_time += delta
	if not _splashes.is_empty():
		queue_redraw()
	_accum += delta
	if _accum >= 1.0 / Graphics.water_redraw_hz():
		_accum = 0.0
		queue_redraw()

func _draw() -> void:
	prims = 0
	if _map == null or not Graphics.water_animated():
		return
	var rect: Rect2
	if is_instance_valid(camera):
		rect = camera.visible_world_rect().grow(T)
	else:
		rect = Config.fallback_view()
	var x0 := maxi(int(rect.position.x / T), 0)
	var y0 := maxi(int(rect.position.y / T), 0)
	var x1 := mini(int(rect.end.x / T) + 1, Config.MAP_W)
	var y1 := mini(int(rect.end.y / T) + 1, Config.MAP_H)

	for y in range(y0, y1):
		for x in range(x0, x1):
			if not _solid_water(x, y):
				continue
			_glint(x, y)
	_draw_splashes()

## Liegt auf diesem Feld WIRKLICH ueberall Wasser — auch im Bild?
##
## Das ist nicht dasselbe wie `is_water`. Die Karte sagt, wo Wasser ist; die
## Zeichnung zieht sich an der Grenze um eine halbe Kachel zurueck. Auf einem
## Randfeld liegt deshalb zur Haelfte Sand, und ein Glitzern an der falschen
## Stelle laege auf dem Strand.
##
## Die Bedingung ist dieselbe, die `GroundTileSet` fuer die volle Kachel
## verlangt (dort `keep == 15`): alle acht Nachbarn sind Wasser. Sie steht hier
## noch einmal, weil dort mit der Kacheltabelle gerechnet wird und hier mit der
## Karte — dieselbe Regel, zwei Zugriffswege. Der Selbsttest prueft, dass beide
## dasselbe sagen.
func _solid_water(x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if not _map.is_water(x + dx, y + dy):
				return false
	return true

## Der Ring wächst und wird blasser — wie eine Welle, die sich ausbreitet.
## Gezeichnet als Kranz kurzer Striche, nicht als glatter Kreis: ein sauberer
## Kreis sähe in Pixelgrafik falsch aus.
func _draw_splashes() -> void:
	for sp: Dictionary in _splashes:
		var life: float = sp["life"]
		var f: float = sp["age"] / life
		var center: Vector2 = sp["pos"]
		var dir: Vector2 = sp["dir"]
		if dir == Vector2.ZERO:
			# Eintauchen: ein geschlossener Ring, der schnell aufgeht.
			var r: float = 5.0 + f * 20.0
			var a: float = (1.0 - f) * 0.8
			for i in 14:
				var ang := TAU * (float(i) + (0.5 if (i % 2) else 0.0)) / 14.0
				var d := Vector2(cos(ang), sin(ang) * 0.55)
				var p := center + d * r
				draw_rect(Rect2(p.x - 1.5, p.y, 3.0, 1.0), Color(Palette.WATER_FOAM, a), true)
				prims += 1
			continue
		# Kielwelle: zwei Bögen, die schräg nach hinten auseinanderlaufen — die
		# Form, die ein Körper im Wasser wirklich hinterlässt. Ein zweiter
		# runder Ring sähe aus, als wäre die Figur nochmal hineingefallen.
		var back := -dir
		var side := Vector2(-dir.y, dir.x)
		var spread: float = 4.0 + f * 15.0
		var drift: float = f * 11.0
		var a2: float = (1.0 - f) * (1.0 - f) * 0.45
		if a2 <= 0.02:
			continue
		for s: float in [-1.0, 1.0]:
			for i in 3:
				var along := float(i) * 0.34
				var p := center + back * (drift + along * spread) \
					+ side * s * (spread * (0.45 + along))
				draw_rect(Rect2(p.x - 1.5, p.y, 3.0, 1.0),
					Color(Palette.WATER_FOAM, a2), true)
				prims += 1

func _glint(x: int, y: int) -> void:
	var h := (x * 73856093) ^ (y * 19349663)
	var phase := float(h % 1000) / 1000.0
	var pulse := sin((_time * 0.9 + phase) * TAU)
	if pulse < 0.55:
		return
	var a: float = (pulse - 0.55) / 0.45 * 0.55
	var ox := float(h % 7)
	var oy := float((h / 7) % 11)
	var w := 3.0 + float((h / 3) % 3)
	draw_rect(Rect2(x * T + ox, y * T + oy, w, 1.0), Color(Palette.WATER_FOAM, a), true)
	prims += 1
	if (h % 5) == 0:
		draw_rect(Rect2(x * T + ox + 1, y * T + oy + 2, w - 1.0, 1.0), Color(Palette.WATER_LIGHT, a * 0.8), true)
		prims += 1
