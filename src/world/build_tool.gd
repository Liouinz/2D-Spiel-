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
var ground: GroundTileSet
var layers: Array = []          ## die neun TileMapLayer, Reihenfolge wie STACK
var bar: CanvasLayer            ## BuildBar
var grid: GridOverlay
var camera: GameCamera
var body: StaticBody2D          ## Sammelknoten für die Wasserformen
var water: WaterFx              ## Brandung neu berechnen, wenn Wasser entsteht

var _water: Dictionary = {}     ## Vector2i -> CollisionShape2D
var _last: Vector2i = Vector2i(-9999, -9999)

func _process(_delta: float) -> void:
	var cell := _hovered()
	if is_instance_valid(grid):
		grid.cursor_block = cell if map.in_bounds(cell.x, cell.y) else Vector2i(-1, -1)
	if not map.in_bounds(cell.x, cell.y):
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

## Setzt einen Block. Öffentlich, damit der Selbsttest ihn ohne Maus auslösen kann.
func place(cell: Vector2i, tile: int) -> void:
	if not map.in_bounds(cell.x, cell.y):
		return
	_last = cell
	if map.get_tile(cell.x, cell.y) == tile:
		return
	map.set_tile(cell.x, cell.y, tile)
	ground.update_cell(layers, map, cell)
	_update_collision(cell)
	if is_instance_valid(water):
		water.refresh(cell)
	Audio.play_step()

## Wasser blockiert, alles andere ist begehbar. Der Kartenrand bleibt in jedem
## Fall gesperrt — dort steht die unsichtbare Wand.
func _update_collision(cell: Vector2i) -> void:
	var edge := cell.x == 0 or cell.y == 0 or cell.x == Config.MAP_W - 1 or cell.y == Config.MAP_H - 1
	var solid := edge or map.is_water(cell.x, cell.y)
	if solid:
		map.block(cell.x, cell.y)
	else:
		map.solid[map.idx(cell.x, cell.y)] = 0

	var want := solid and not edge      # die Randwand hat schon ihre Form
	var has: bool = _water.has(cell)
	if want == has:
		return
	if want:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(Config.TILE, Config.TILE)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = Vector2(cell.x + 0.5, cell.y + 0.5) * Config.TILE
		body.add_child(cs)
		_water[cell] = cs
	else:
		var cs: CollisionShape2D = _water[cell]
		_water.erase(cell)
		cs.queue_free()

## Sichert die gebaute Karte von Hand (F5). Automatisch passiert das ausserdem
## beim Zurück ins Hauptmenü und beim Beenden.
func save() -> bool:
	var ok := map.save_user()
	Audio.play_ui("confirm" if ok else "close")
	if is_instance_valid(bar):
		bar.flash("Karte gespeichert" if ok else "Karte konnte nicht gespeichert werden")
	return ok

## Anzahl gesetzter Wasserformen — für den Selbsttest.
func water_shapes() -> int:
	return _water.size()
