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

## Radius des Scheins in Weltpixeln. GRÖSSER als die Handfackel der Figur (92):
## eine gesetzte Fackel steht fest und leuchtet einen Platz aus, die Figur trägt
## nur ein Licht mit sich.
const RADIUS := 120.0

## Bilder der Flamme. Eine Fackel, die stillsteht, ist kein Feuer.
##
## Dieselbe Zahl wie bei der Handfackel und dieselbe Zeichnung
## (`ActorArt.draw_flame`) — zwei Feuer im selben Bild, die verschieden
## flackern, sehen aus wie zwei verschiedene Materialien.
const FLAMES := ActorArt.FLAME_FRAMES

## Etwas langsamer als die Handfackel (11): eine Fackel im Halter steht still,
## eine in der Hand wird bewegt und flackert dadurch staerker.
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
	# Auf dem Feld stehend: unten mittig, damit sie auf dem Boden aufsitzt.
	s.position = Vector2(cell) * Config.TILE + Vector2(
		(Config.TILE - _tex[0].get_width()) * 0.5,
		Config.TILE - _tex[0].get_height())
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
## 10 x 22 Bildpunkte — hoeher und kraeftiger als die Handfackel (11 x 20, aber
## davon nur ein Drittel Stiel). Eine gesetzte Fackel steckt in der Erde und
## ragt heraus; eine in der Hand ist ein Stueck Holz, das jemand haelt.
##
## Sie ist schmaler als ein Feld, damit sie danebensteht statt es zu fuellen.
## Licht von oben links wie ueberall sonst.
static func _torch_image(f: int = 0) -> Image:
	var img := Pixel.make(10, 22)

	# Stiel, drei Spalten. Unten dunkler: dort steckt er im Boden.
	Pixel.vline(img, 4, 9, 13, Palette.WOOD_LIGHT)
	Pixel.vline(img, 5, 9, 13, Palette.WOOD)
	Pixel.vline(img, 6, 9, 13, Palette.WOOD_DARK)
	Pixel.rect(img, 4, 20, 3, 2, Palette.WOOD_DARK.darkened(0.30))
	# Maserung
	Pixel.px(img, 5, 14, Palette.WOOD_DARK)
	Pixel.px(img, 4, 17, Palette.WOOD)

	# Wicklung: derselbe Lederton wie an der Handfackel.
	Pixel.rect(img, 3, 6, 5, 5, Color8(74, 52, 38))
	Pixel.rect(img, 3, 6, 5, 1, Color8(112, 82, 56))
	Pixel.px(img, 3, 7, Color8(96, 70, 48))
	for x in range(4, 7):
		Pixel.px(img, x, 9, Color8(52, 36, 26))
	Pixel.px(img, 7, 7, Color8(48, 34, 24))

	Pixel.outline(img, Palette.OUTLINE)

	# Flamme zuletzt und ohne Umriss — etwas groesser als die der Handfackel.
	ActorArt.draw_flame(img, 5.0, 6.0, 2.2, 9.5, f)
	return img
