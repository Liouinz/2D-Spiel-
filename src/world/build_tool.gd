class_name BuildTool
extends Node
## Setzt einzelne Bodenblöcke im laufenden Spiel.
##
## 1–8 oder Mausrad wählt den Bodentyp, linke Maustaste setzt ihn auf den Block
## unter dem Zeiger, rechte Maustaste setzt zurück auf Gras. Gedrückt halten
## malt. Der Block unter dem Zeiger wird im Raster hell umrandet.
##
## Geändert wird immer beides: die Karte als Daten (MapData) und die neun
## Bodenschichten. Wasser bekommt zusätzlich eine eigene Kollisionsform, damit
## man nicht hineinlaufen kann.

var map: MapData
var streamer: ChunkStreamer     ## setzt Kacheln und Kollision des Chunks neu
var bar: CanvasLayer            ## BuildBar
var grid: GridOverlay
var camera: GameCamera
var water: WaterFx              ## Brandung neu berechnen, wenn Wasser entsteht
var minimap: Control            ## sofort nachziehen statt erst beim nächsten Takt
var main: Node                  ## öffnet und schliesst das Inventar

var _last: Vector2i = Vector2i(-9999, -9999)

func _process(_delta: float) -> void:
	var cell := _hovered()
	var over_bar: bool = is_instance_valid(bar) and bar.covers(_screen_mouse())
	var ok := map.in_bounds(cell.x, cell.y) and not over_bar
	if is_instance_valid(grid):
		grid.cursor_block = cell if ok else Vector2i(-1, -1)
		grid.cursor_tex = bar.preview_texture() if is_instance_valid(bar) else null
	if not ok:
		return
	# Gedrückt halten malt — aber nur, wenn sich der Block geändert hat.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if cell != _last:
			place(cell, bar.tile_type())
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if cell != _last:
			place(cell, MapData.Tile.GRASS)
	else:
		_last = Vector2i(-9999, -9999)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		main.toggle_inventory()
		get_viewport().set_input_as_handled()
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
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if is_instance_valid(bar) and bar.covers(_screen_mouse()):
			return
		var b: int = (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			bar.select(bar.selected - 1)
			get_viewport().set_input_as_handled()
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			bar.select(bar.selected + 1)
			get_viewport().set_input_as_handled()

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
	if map.get_tile(cell.x, cell.y) == tile:
		return
	map.set_tile(cell.x, cell.y, tile)
	streamer.refresh_cell(cell)
	if is_instance_valid(water):
		water.refresh(cell)
	if is_instance_valid(minimap):
		minimap.refresh()
	Audio.play_step()

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
