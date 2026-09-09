class_name Torches
extends Node2D
## Gesetzte Fackeln: eine tragbare Lichtquelle, die man in die Welt stellt.
##
## Eine Fackel ist zwei Dinge, die getrennt bleiben:
##
##   ein BILD in der Welt — ein Sprite auf dem Feld, das auch am Tag dasteht
##   ein LICHT auf der Nachtschicht — angemeldet beim LightManager
##
## Das Licht ist kein `Light2D`. Das ist der ganze Grund, warum es Fackeln
## überhaupt geben kann, ohne dass die Bildrate einbricht: gemessen kostete ein
## einziges echtes 2D-Licht +3,43 ms CPU-Renderzeit, weil es jedes Element in
## seinem Umkreis ein zweites Mal einreihen lässt. Zehn Fackeln wären damit
## nicht bezahlbar gewesen. Ein additives Sprite kostet ein Viereck — und
## ausserhalb des Bildes gar nichts, siehe `LightManager._update_glows`.

## Radius des Scheins in Weltpixeln. GRÖSSER als der Sichtkreis der Figur (78):
## eine gesetzte Fackel steht fest und leuchtet einen Platz aus, die Figur trägt
## nur ein Licht mit sich.
const RADIUS := 120.0

## Bilder der Flamme. Eine Fackel, die stillsteht, ist kein Feuer.
##
## Dieselbe Zeichnung wie im Bild der Figur
## (`ActorArt.draw_flame`) — zwei Feuer im selben Bild, die verschieden
## flackern, sehen aus wie zwei verschiedene Materialien.
const FLAMES := ActorArt.FLAME_FRAMES

## Langsam genug, dass man die einzelnen Bilder nicht zaehlt, schnell genug,
## dass es lebt.
const FLAME_FPS := 9.0

## Warmes Feuer, deutlich röter als der Schein der Figur.
const COLOR := Color(1.0, 0.76, 0.42)

var map: MapData
var light: LightManager

var _tex: Array[Texture2D] = []
var _time: float = 0.0
var _sprites: Dictionary = {}      ## Vector2i -> Sprite2D
var _lights: Dictionary = {}       ## Vector2i -> LightManager.LightSource
var _shown: int = -1               ## welches Flammenbild gerade steht

func _ready() -> void:
	# Über dem Boden, aber unter der Figur: eine Fackel steht auf dem Feld,
	# und wer davorläuft, verdeckt sie.
	z_index = -1
	for f in FLAMES:
		_tex.append(Pixel.tex(_torch_image(f)))
	if map != null:
		for cell: Vector2i in map.torches:
			_add(cell)

## Setzt eine Fackel oder nimmt sie wieder weg. Gibt zurück, ob jetzt eine
## dasteht — die Rückmeldung, die das Bauwerkzeug für seinen Blitz braucht.
func toggle(cell: Vector2i) -> bool:
	if _sprites.has(cell):
		_remove(cell)
		return false
	_add(cell)
	return true

func has_torch(cell: Vector2i) -> bool:
	return _sprites.has(cell)

func count() -> int:
	return _sprites.size()

func _add(cell: Vector2i) -> void:
	if _sprites.has(cell):
		return
	var s := Sprite2D.new()
	s.texture = _tex[0]
	s.centered = false
	s.scale = Vector2.ONE * ActorArt.DRAW_SCALE
	# Auf dem Feld stehend: unten mittig, damit sie auf dem Boden aufsitzt.
	# Gerechnet wird mit der DARGESTELLTEN Groesse, nicht mit der des Bildes —
	# das Bild ist doppelt so fein wie die Welt.
	var shown := Vector2(_tex[0].get_size()) * ActorArt.DRAW_SCALE
	s.position = Vector2(cell) * Config.TILE + Vector2(
		(Config.TILE - shown.x) * 0.5, Config.TILE - shown.y)
	add_child(s)
	_sprites[cell] = s

	if is_instance_valid(light):
		var src := light.add_source(RADIUS, COLOR, 0.9, 1.0)
		# Der Schein sitzt an der Flamme, nicht am Fuss des Stiels.
		src.pos = Vector2(cell) * Config.TILE + Vector2(Config.TILE * 0.5, 4.0)
		light.add_embers(src)
		_lights[cell] = src
	if map != null and not map.torches.has(cell):
		map.torches.append(cell)

func _remove(cell: Vector2i) -> void:
	if _sprites.has(cell):
		(_sprites[cell] as Sprite2D).queue_free()
		_sprites.erase(cell)
	if _lights.has(cell):
		if is_instance_valid(light):
			light.remove_source(_lights[cell])
		_lights.erase(cell)
	if map != null:
		map.torches.erase(cell)

## Lässt die Flammen laufen — und nur die, die man auch sieht.
##
## Ein Bildwechsel je Sprite alle 0,14 Sekunden ist nichts; hundert Fackeln
## drei Chunks weiter wären trotzdem hundert Zuweisungen je Bild für nichts.
## Deshalb wird nur angefasst, was gerade im Bild liegt.
func _process(delta: float) -> void:
	if _sprites.is_empty():
		return
	_time += delta * FLAME_FPS
	var frame: int = int(_time) % FLAMES
	if frame == _shown:
		return
	_shown = frame
	var view := _view()
	for cell: Vector2i in _sprites:
		var s: Sprite2D = _sprites[cell]
		var here := Rect2(Vector2(cell) * Config.TILE, Vector2(Config.TILE, Config.TILE))
		if view.size == Vector2.ZERO or view.intersects(here):
			s.texture = _tex[frame]

func _view() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2()
	return Rect2(cam.get_screen_center_position()
		- get_viewport_rect().size / cam.zoom * 0.5,
		get_viewport_rect().size / cam.zoom).grow(Config.TILE * 2)

## Eine gesetzte Fackel: Stiel, Wicklung, Flamme.
##
## 20 x 44 Kunstpixel, dargestellt mit Faktor 0,5 — also 10 x 22 Weltpixel, wie
## vorher. Dieselbe doppelte Dichte wie die Figur: zwei
## Gegenstaende im selben Bild mit unterschiedlich grossen Pixeln fallen sofort
## auf, und die Fackel steht direkt neben der Figur.
##
## Sie ist schmaler als ein Feld, damit sie danebensteht statt es zu fuellen.
## Licht von oben links wie ueberall sonst.
static func _torch_image(f: int = 0) -> Image:
	var img := Pixel.make(20, 44)
	var leather := Color8(74, 52, 38)
	var leather_hi := Color8(112, 82, 56)
	var cord := Color8(52, 36, 26)

	# Stiel, sechs Spalten. Unten dunkler: dort steckt er im Boden.
	Pixel.rect(img, 8, 18, 2, 26, Palette.WOOD_LIGHT)
	Pixel.rect(img, 10, 18, 2, 26, Palette.WOOD)
	Pixel.rect(img, 12, 18, 2, 26, Palette.WOOD_DARK)
	Pixel.rect(img, 8, 40, 6, 4, Palette.WOOD_DARK.darkened(0.30))
	# Maserung
	Pixel.rect(img, 10, 24, 1, 6, Palette.WOOD_DARK)
	Pixel.rect(img, 9, 32, 1, 5, Palette.WOOD)
	# Erdanhaftung am Fuss: sie steckt in der Erde, sie liegt nicht darauf.
	Pixel.rect(img, 7, 42, 8, 2, Palette.WOOD_DARK.darkened(0.45))

	# Wicklung: Leder um den Kopf, drei Schnurgaenge.
	Pixel.rect(img, 6, 12, 10, 10, leather)
	Pixel.rect(img, 6, 12, 10, 2, leather_hi)
	Pixel.rect(img, 6, 13, 2, 8, leather.lightened(0.18))
	for i in 3:
		Pixel.rect(img, 6, 15 + i * 3, 10, 1, cord)
	Pixel.rect(img, 15, 13, 1, 8, cord.darkened(0.2))

	Pixel.outline(img, Palette.OUTLINE)

	# Flamme zuletzt und ohne Umriss — ein schwarzer Rand um Feuer sieht aus
	# wie ein Aufkleber.
	ActorArt.draw_flame(img, 10.0, 12.0, 4.6, 19.0, f)
	return img
