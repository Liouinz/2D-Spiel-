class_name World
extends Node2D
## Setzt die Spielwelt zusammen: Boden, Wasser, Requisiten, Kollision,
## Spieler und Kamera. Hält selbst keine Spiellogik.

var map: MapData
var player: Player
var camera: GameCamera
var hud: CanvasLayer

const HudScene := preload("res://src/ui/hud.gd")

var build_msec: int = 0

var _sorted: Node2D

func _ready() -> void:
	var started := Time.get_ticks_msec()
	var builder := WorldBuilder.new()
	builder.build(Config.WORLD_SEED)
	map = builder.map

	# Der Boden ist ein echtes Kachelraster: eine TileMapLayer je Schicht,
	# von unten nach oben per Terrain-Autotiling ineinander eingeblendet.
	var ground := Node2D.new()
	ground.name = "Ground"
	add_child(ground)
	var t_layers := Time.get_ticks_msec()
	for pos in GroundTileSet.STACK.size():
		var layer := TileMapLayer.new()
		layer.name = "L%d_%s" % [pos, GroundTileSet.NAMES[GroundTileSet.STACK[pos]]]
		layer.z_index = -40 + pos
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.add_child(layer)
		builder.ground.paint(layer, pos, builder.cells_for(pos), builder.variant_map())

	builder.timings["schichten"] = Time.get_ticks_msec() - t_layers

	# Dekoration ist eine eigene Rasterschicht (Blumen, Grasbüschel, Steine).
	var decor := TileMapLayer.new()
	decor.name = "Decoration"
	decor.z_index = -25
	decor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.add_child(decor)
	builder.ground.paint_decor(decor, builder.decor_map())

	# Bodenschatten: ein weicher Fleck je Requisite, passend skaliert.
	var shadows := Node2D.new()
	shadows.name = "Shadows"
	shadows.z_index = -22
	add_child(shadows)
	var shadow_tex := PropArt.shadow_texture()
	for p: Dictionary in builder.placed:
		var e: Dictionary = PropArt.variant(builder.props, p["name"], p["variant"])
		var sh: Vector2 = e["shadow"]
		if sh == Vector2.ZERO:
			continue
		var s := Sprite2D.new()
		s.texture = shadow_tex
		s.centered = true
		var pos: Vector2 = p["pos"]
		s.position = pos + Vector2(sh.x * 0.22, -2.0 + sh.y * 0.15)
		s.scale = Vector2(sh.x / 26.0, sh.y / 12.5)
		shadows.add_child(s)

	var water := WaterFx.new()
	water.name = "WaterFx"
	water.z_index = -10
	water.setup(map)
	add_child(water)

	var body := StaticBody2D.new()
	body.name = "Collision"
	for r: Rect2 in builder.collision_rects:
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		body.add_child(cs)
	add_child(body)

	_sorted = Node2D.new()
	_sorted.name = "Sorted"
	_sorted.y_sort_enabled = true
	add_child(_sorted)

	for p: Dictionary in builder.placed:
		var e: Dictionary = PropArt.variant(builder.props, p["name"], p["variant"])
		var s := Sprite2D.new()
		s.texture = e["tex"]
		s.centered = false
		var size: Vector2 = e["size"]
		s.offset = Vector2(-size.x * 0.5, -size.y)
		s.position = p["pos"]
		_sorted.add_child(s)

	player = Player.new()
	player.name = "Player"
	var spawn := map.find_free_near(Layout.SPAWN)
	player.position = Vector2(spawn.x * Config.TILE + Config.TILE * 0.5, spawn.y * Config.TILE + Config.TILE * 0.5)
	_sorted.add_child(player)

	camera = GameCamera.new()
	camera.name = "Camera"
	camera.target = player
	add_child(camera)
	camera.setup(Config.world_size_px())
	camera.snap_to_target()
	water.camera = camera

	hud = HudScene.new()
	add_child(hud)
	build_msec = Time.get_ticks_msec() - started
	print("Welt aufgebaut in %d ms (%d Objekte, %d Kollisionsformen)" % [
		build_msec, builder.placed.size(), builder.collision_rects.size()])
	print("  Phasen: ", builder.timings)
