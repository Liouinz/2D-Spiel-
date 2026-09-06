class_name World
extends Node2D
## Setzt die Spielwelt zusammen: Boden, Wasser, Requisiten, Kollision,
## Spieler und Kamera. Hält selbst keine Spiellogik.

var map: MapData
var player: Player
var camera: GameCamera
var hud: CanvasLayer
var grid: GridOverlay
var build_bar: CanvasLayer
var build_tool: BuildTool
var inventory: CanvasLayer
var streamer: ChunkStreamer

const HudScene := preload("res://src/ui/hud.gd")
const BuildBarScene := preload("res://src/ui/build_bar.gd")
const InventoryScene := preload("res://src/ui/inventory.gd")

var build_msec: int = 0

var _sorted: Node2D
func _ready() -> void:
	# Die Welt MUSS pausierbar sein.
	#
	# Main setzt für sich PROCESS_MODE_ALWAYS, damit Menüs auch bei pausiertem
	# Baum bedienbar bleiben. Die Welt hängt als Kind darunter und erbte das
	# still mit — get_tree().paused hatte auf sie überhaupt keine Wirkung.
	# Dadurch lief bei offenem Menü oder Inventar alles weiter: die Figur ging
	# weiter, und das Bauwerkzeug setzte bei jedem Klick im Menü einen Block.
	process_mode = Node.PROCESS_MODE_PAUSABLE

	var started := Time.get_ticks_msec()
	var builder := WorldBuilder.new()
	builder.build(Config.WORLD_SEED)
	map = builder.map

	# Die Figur muss vor dem Boden dastehen: der ChunkStreamer lädt um sie
	# herum, also braucht er ihre Position, bevor die erste Kachel fällt.
	player = Player.new()
	player.name = "Player"
	player.map = map
	var spawn := map.find_free_near(Config.spawn_block())
	player.position = Vector2(spawn.x + 0.5, spawn.y + 0.5) * Config.TILE

	# Der Boden ist ein echtes Kachelraster: eine TileMapLayer je Schicht, von
	# unten nach oben per Terrain-Autotiling ineinander eingeblendet. Geladen
	# wird chunkweise um die Figur herum.
	var t_layers := Time.get_ticks_msec()
	streamer = ChunkStreamer.new()
	streamer.name = "Streamer"
	add_child(streamer)
	streamer.setup(map, builder.ground, player)
	streamer.decor_at = builder.decor_at
	streamer.prime()
	builder.timings["schichten"] = Time.get_ticks_msec() - t_layers

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

	# Requisiten haben eigene Fussabdrücke; Wasser und Weltrand macht der
	# Streamer chunkweise.
	for r: Rect2 in builder.prop_collision():
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		streamer.body.add_child(cs)

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

	_sorted.add_child(player)

	camera = GameCamera.new()
	camera.name = "Camera"
	camera.target = player
	add_child(camera)
	camera.setup(Config.world_size_px())
	camera.snap_to_target()
	water.camera = camera
	player.splashed.connect(water.splash)

	# Rotes Blockraster über allem — zeigt das sonst unsichtbare Grid.
	grid = GridOverlay.new()
	grid.name = "GridOverlay"
	grid.camera = camera
	grid.player = player
	add_child(grid)

	hud = HudScene.new()
	hud.player = player
	hud.grid = grid
	add_child(hud)
	if is_instance_valid(hud.minimap):
		hud.minimap.map = map
		hud.minimap.player = player

	# Bau-Leiste: nur im Aufbaumodus. Auf der fertigen Insel würde ein Klick
	# sonst Wege und Küste zerlegen.
	if Config.EMPTY_WORLD:
		build_bar = BuildBarScene.new()
		add_child(build_bar)
		build_bar.setup(builder.art)

		build_tool = BuildTool.new()
		build_tool.name = "BuildTool"
		build_tool.map = map
		build_tool.streamer = streamer
		build_tool.bar = build_bar
		build_tool.grid = grid
		build_tool.camera = camera
		build_tool.water = water
		build_tool.minimap = hud.minimap
		build_tool.main = get_parent()
		build_tool.player = player
		add_child(build_tool)
		build_bar.slot_clicked.connect(func(i: int) -> void:
			build_bar.select(i)
			Audio.play_ui("blip"))
		build_bar.set_loadout(Settings.build_loadout)
		build_bar.loadout_changed.connect(func() -> void:
			Settings.build_loadout = build_bar.loadout()
			Settings.save_settings())

		inventory = InventoryScene.new()
		# Das Inventar ist UI und muss bei pausiertem Baum bedienbar bleiben.
		inventory.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(inventory)
		inventory.setup(builder.art, build_bar)
		inventory.equip_requested.connect(func(slot: int, tile: int) -> void:
			build_bar.equip(slot, tile)
			inventory.refresh()
			Audio.play_ui("confirm"))

	build_msec = Time.get_ticks_msec() - started
	print("Welt aufgebaut in %d ms (%d Objekte, %d Chunks, %d Kollisionsformen)" % [
		build_msec, builder.placed.size(), streamer.loaded_count(), streamer.shape_count()])
	print("  Phasen: ", builder.timings)
