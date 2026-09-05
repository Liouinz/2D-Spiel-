class_name World
extends Node2D
## Setzt die Spielwelt zusammen: Boden, Wasser, Requisiten, Kollision,
## Spieler und Kamera. Hält selbst keine Spiellogik.

var map: MapData
var player: Player
var camera: GameCamera

var _sorted: Node2D

func _ready() -> void:
	var builder := WorldBuilder.new()
	builder.build(Config.WORLD_SEED)
	map = builder.map

	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = builder.ground_texture
	ground.centered = false
	ground.z_index = -20
	add_child(ground)

	var water := WaterFx.new()
	water.name = "WaterFx"
	water.map = map
	water.z_index = -10
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
		var e: Dictionary = builder.props[p["name"]]
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
