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

## Radius des Scheins in Weltpixeln. GRÖSSER als die Handfackel der Figur (76):
## eine gesetzte Fackel steht fest und leuchtet einen Platz aus, die Figur trägt
## nur ein Licht mit sich.
const RADIUS := 96.0

## Bilder der Flamme. Eine Fackel, die stillsteht, ist kein Feuer.
const FLAMES := 4
const FLAME_FPS := 7.0

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

## Eine kleine Fackel: Stiel, Wicklung, Flamme.
##
## 10 x 20 Bildpunkte — schmaler als ein Feld, damit sie danebensteht statt es
## zu füllen. Licht von oben links wie überall sonst: die linke Seite des
## Stiels ist heller.
static func _torch_image(f: int = 0) -> Image:
	var img := Pixel.make(10, 20)
	var wood := Palette.WOOD_DARK
	# Stiel
	Pixel.rect(img, 4, 9, 3, 11, wood)
	Pixel.vline(img, 4, 9, 11, Palette.WOOD)
	# Wicklung
	Pixel.rect(img, 3, 7, 5, 3, Palette.WOOD_LIGHT.darkened(0.25))
	Pixel.rect(img, 3, 7, 5, 1, Palette.WOOD_LIGHT)
	# Flamme: aussen dunkelrot, innen gelb, ganz innen fast weiss. Je Bild eine
	# andere Höhe, Breite und Neigung — das ist das Flackern.
	var tall: Array = [0.0, 1.1, 0.4, 1.5]
	var wide: Array = [0.0, -0.4, 0.5, -0.2]
	var lean: Array = [0.0, -0.4, 0.3, 0.5]
	var i := f % FLAMES
	var h: float = 5.0 + float(tall[i])
	var w: float = 4.0 + float(wide[i])
	var cx: float = 5.0 + float(lean[i])
	var cy: float = 4.4 - h * 0.16
	Pixel.ellipse(img, cx, cy, w, h, Color8(196, 74, 26))
	Pixel.ellipse(img, cx, cy + 0.6, w * 0.68, h * 0.70, Color8(240, 148, 40))
	Pixel.ellipse(img, cx, cy + 1.1, w * 0.38, h * 0.42, Color8(252, 220, 130))
	Pixel.px(img, int(cx), int(cy + 1.0), Color8(255, 248, 214))
	Pixel.outline(img, Palette.OUTLINE)
	return img
