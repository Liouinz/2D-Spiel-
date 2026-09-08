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

## Radius des Scheins in Weltpixeln. Kleiner als der Schein der Figur: eine
## Fackel leuchtet einen Platz aus, nicht die halbe Karte.
const RADIUS := 84.0

## Warmes Feuer, deutlich röter als der Schein der Figur.
const COLOR := Color(1.0, 0.76, 0.42)

var map: MapData
var light: LightManager

var _tex: Texture2D
var _sprites: Dictionary = {}      ## Vector2i -> Sprite2D
var _lights: Dictionary = {}       ## Vector2i -> LightManager.LightSource

func _ready() -> void:
	# Über dem Boden, aber unter der Figur: eine Fackel steht auf dem Feld,
	# und wer davorläuft, verdeckt sie.
	z_index = -1
	_tex = Pixel.tex(_torch_image())
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
	s.texture = _tex
	s.centered = false
	# Auf dem Feld stehend: unten mittig, damit sie auf dem Boden aufsitzt.
	s.position = Vector2(cell) * Config.TILE + Vector2(
		(Config.TILE - _tex.get_width()) * 0.5, Config.TILE - _tex.get_height())
	add_child(s)
	_sprites[cell] = s

	if is_instance_valid(light):
		var src := light.add_source(RADIUS, COLOR, 0.85, 1.0)
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

## Eine kleine Fackel: Stiel, Wicklung, Flamme.
##
## 10 x 20 Bildpunkte — schmaler als ein Feld, damit sie danebensteht statt es
## zu füllen. Licht von oben links wie überall sonst: die linke Seite des
## Stiels ist heller.
static func _torch_image() -> Image:
	var img := Pixel.make(10, 20)
	var wood := Palette.WOOD_DARK
	# Stiel
	Pixel.rect(img, 4, 9, 3, 11, wood)
	Pixel.vline(img, 4, 9, 11, Palette.WOOD)
	# Wicklung
	Pixel.rect(img, 3, 7, 5, 3, Palette.WOOD_LIGHT.darkened(0.25))
	Pixel.rect(img, 3, 7, 5, 1, Palette.WOOD_LIGHT)
	# Flamme: aussen dunkelrot, innen gelb, ganz innen fast weiss
	Pixel.ellipse(img, 5.0, 4.0, 4.0, 5.0, Color8(196, 74, 26))
	Pixel.ellipse(img, 5.0, 4.5, 2.8, 3.6, Color8(240, 148, 40))
	Pixel.ellipse(img, 5.0, 5.0, 1.6, 2.2, Color8(252, 220, 130))
	Pixel.px(img, 5, 5, Color8(255, 248, 214))
	Pixel.outline(img, Palette.OUTLINE)
	return img
