class_name BuildTool
extends Node
## Setzt einzelne Bodenblöcke im laufenden Spiel.
##
## 1–8 oder Mausrad wählt den Bodentyp, linke Maustaste setzt ihn auf den Block
## unter dem Zeiger, rechte Maustaste setzt zurück auf Gras. Gedrückt halten
## malt. Der Block unter dem Zeiger wird im Raster hell umrandet.
##
## Zum Eingabeverhalten — hier steckten zwei Fehler:
##
## 1. Gesetzt wird auf das PRESS-EREIGNIS, nicht auf den abgefragten
##    Tastenzustand. `Input.is_mouse_button_pressed()` fragt den rohen Zustand
##    ab: das lief an der Ereigniskette vorbei, liess sich von der Oberfläche
##    nicht abfangen, und ein Klick auf „Fortsetzen" im Menü setzte gleich
##    einen Block in der Welt. Ausserdem gingen sehr kurze Klicks verloren,
##    die innerhalb eines Bildes begannen und endeten.
##
## 2. Gemalt wird nur, solange ein Druck gehalten wird, der IN DER WELT
##    begonnen hat (`_painting`). Eine Taste, die beim Schliessen eines
##    Fensters noch gedrückt ist, malt dadurch nicht weiter.

var map: MapData
var streamer: ChunkStreamer     ## setzt Kacheln und Kollision des Chunks neu
var bar: CanvasLayer            ## BuildBar
var grid: GridOverlay
var camera: GameCamera
var water: WaterFx              ## Brandung neu berechnen, wenn Wasser entsteht
var minimap: Control            ## sofort nachziehen statt erst beim nächsten Takt
var main: Node                  ## öffnet und schliesst das Inventar
var player: Player              ## damit sich niemand selbst einmauert

## Weiter als so viele Felder wird beim Ziehen nicht aufgefüllt. Springt der
## Zeiger (Fenster verlassen, Menü zu), soll keine lange Linie entstehen.
const STROKE_MAX := 12

var _last: Vector2i = Vector2i(-9999, -9999)
var _painting: int = 0         ## 0 = aus, sonst die gedrückte Maustaste

## Darf gerade gebaut werden? Nur im laufenden Spiel — nicht im Menü, nicht in
## den Optionen und nicht im Inventar.
func _playing() -> bool:
	return is_instance_valid(main) and main.state == main.State.PLAYING

func _process(_delta: float) -> void:
	if not _playing():
		_painting = 0
		if is_instance_valid(grid):
			grid.cursor_block = Vector2i(-1, -1)
		return
	var cell := _hovered()
	var ok := _world_cell(cell)
	if is_instance_valid(grid):
		grid.cursor_block = cell if ok else Vector2i(-1, -1)
		grid.cursor_tex = bar.preview_texture() if is_instance_valid(bar) else null
	if _painting == 0 or not ok or cell == _last:
		return
	# Beim Ziehen die Lücke zum letzten Feld auffüllen: bei schneller Maus liegen
	# zwischen zwei Bildern mehrere Felder, sonst entstünde eine Punktreihe.
	var d := cell - _last
	if maxi(absi(d.x), absi(d.y)) > STROKE_MAX:
		place(cell, _tile_for(_painting))
	else:
		_stroke(_last, cell, _tile_for(_painting))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		main.toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if not _playing():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_8:
			bar.select(k - KEY_1)
			Audio.play_ui("blip")
			get_viewport().set_input_as_handled()
		elif k == KEY_F5:
			save()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == _painting:
				_painting = 0
				_last = Vector2i(-9999, -9999)
			return
		if is_instance_valid(bar) and bar.covers(_screen_mouse()):
			return
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				bar.select(bar.selected - 1)
			MOUSE_BUTTON_WHEEL_DOWN:
				bar.select(bar.selected + 1)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				var cell := _hovered()
				if not _world_cell(cell):
					return
				# Der Druck selbst setzt sofort: auch ein Klick, der innerhalb
				# eines Bildes beginnt und endet, kommt dadurch an.
				_painting = mb.button_index
				_last = Vector2i(-9999, -9999)
				place(cell, _tile_for(mb.button_index))
			_:
				return
		get_viewport().set_input_as_handled()

## Liegt das Feld in der Welt und nicht unter der Bau-Leiste?
func _world_cell(cell: Vector2i) -> bool:
	if not map.in_bounds(cell.x, cell.y):
		return false
	return not (is_instance_valid(bar) and bar.covers(_screen_mouse()))

func _tile_for(button: int) -> int:
	return MapData.Tile.GRASS if button == MOUSE_BUTTON_RIGHT else bar.tile_type()

## Setzt alle Felder auf der Linie von `from` nach `to`. Ohne das reisst eine
## schnell gezogene Wand auf.
func _stroke(from: Vector2i, to: Vector2i, tile: int) -> void:
	if from.x < -9000:
		place(to, tile)
		return
	var d := to - from
	var steps := maxi(absi(d.x), absi(d.y))
	for i in range(1, steps + 1):
		place(Vector2i(
			from.x + int(round(float(d.x) * i / steps)),
			from.y + int(round(float(d.y) * i / steps))), tile)

## Block unter dem Mauszeiger, in Weltkoordinaten umgerechnet.
func _hovered() -> Vector2i:
	if not is_instance_valid(camera):
		return Vector2i(-1, -1)
	return GridOverlay.block_at(camera.get_global_mouse_position())

func _screen_mouse() -> Vector2:
	var vp := get_viewport()
	return vp.get_mouse_position() if vp != null else Vector2.ZERO

## Setzt einen Block. Öffentlich, damit der Selbsttest ihn ohne Maus auslösen kann.
func place(cell: Vector2i, tile: int) -> void:
	if not map.in_bounds(cell.x, cell.y):
		return
	_last = cell
	if tile < 0 or tile >= MapData.Tile.COUNT:
		return
	if map.get_tile(cell.x, cell.y) == tile:
		return
	# Kein fester Block in die eigene Figur.
	#
	# Sonst entsteht eine Kollisionsform mitten im Körper, und move_and_slide()
	# drückt ihn im nächsten Bild mit voller Kraft heraus — die Figur wird
	# weggeschleudert, und in welche Richtung hängt vom Zufall der Überlappung
	# ab. Deshalb gar nicht erst zulassen.
	if _blocks_player(cell, tile):
		if is_instance_valid(bar):
			bar.flash("Da stehst Du selbst")
		return
	map.set_tile(cell.x, cell.y, tile)
	streamer.refresh_cell(cell)
	if is_instance_valid(water):
		water.refresh(cell)
	if is_instance_valid(minimap):
		minimap.refresh()
	Audio.play_step()

## Würde dieser Block die Figur einschliessen? Geprüft wird der Fussabdruck,
## nicht nur der Mittelpunkt.
func _blocks_player(cell: Vector2i, tile: int) -> bool:
	if not is_instance_valid(player):
		return false
	if tile != MapData.Tile.DEEP_WATER:
		return false            # nur Tiefwasser hält auf
	var base := player.global_position
	for corner: Vector2 in [
			Vector2(-Player.FOOT.x, 0.0), Vector2(Player.FOOT.x, 0.0),
			Vector2(-Player.FOOT.x, -Player.FOOT.y), Vector2(Player.FOOT.x, -Player.FOOT.y)]:
		if GridOverlay.block_at(base + corner) == cell:
			return true
	return false

## Sichert die gebaute Karte von Hand (F5). Automatisch passiert das ausserdem
## beim Zurück ins Hauptmenü und beim Beenden.
func save() -> bool:
	var ok := map.save_user()
	Audio.play_ui("confirm" if ok else "close")
	if is_instance_valid(bar):
		bar.flash("Karte gespeichert" if ok else "Karte konnte nicht gespeichert werden")
	return ok

## Kollisionsformen der geladenen Chunks — für den Selbsttest.
func shape_count() -> int:
	return streamer.shape_count()
