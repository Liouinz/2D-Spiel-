class_name World
extends Node2D
## Setzt die Spielwelt zusammen: Boden, Wasser, Kollision, Spieler und Kamera.
## Hält selbst keine Spiellogik.

var map: MapData
var player: Player
var camera: GameCamera
var hud: CanvasLayer
var grid: GridOverlay
var build_bar: BuildBar
var build_tool: BuildTool
var inventory: Inventory
var streamer: ChunkStreamer
var ambient: AmbientFx
var build_fx: BuildFx
var light: LightManager
var torches: Torches

const HudScene := preload("res://src/ui/hud.gd")

var build_msec: int = 0

## Von Main gesetzt, bevor die Welt in den Baum kommt: neue Welt statt der
## gespeicherten Karte.
var fresh: bool = false

var _sorted: Node2D

## Wie viele Dinge in der sortierten Schicht liegen — Figur, Fackeln, alles,
## was voreinander stehen kann. Fuer die Entwicklerinfo.
##
## Oeffentlich, damit die Anzeige den Knoten nicht ueber seinen NAMEN suchen
## muss: `get_node_or_null("Sorted")` war die einzige Zeichenkettensuche der
## ganzen Oberflaeche und haette beim Umbenennen still 0 gemeldet.
func entity_count() -> int:
	return _sorted.get_child_count() if is_instance_valid(_sorted) else 0

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
	builder.build(Config.WORLD_SEED, fresh)
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
	streamer.prime()
	builder.timings["schichten"] = Time.get_ticks_msec() - t_layers

	var water := WaterFx.new()
	water.name = "WaterFx"
	water.z_index = -10
	water.setup(map)
	add_child(water)

	_sorted = Node2D.new()
	_sorted.name = "Sorted"
	_sorted.y_sort_enabled = true
	add_child(_sorted)
	_sorted.add_child(player)

	camera = GameCamera.new()
	camera.name = "Camera"
	camera.target = player
	add_child(camera)
	camera.setup(Config.world_size_px())
	camera.snap_to_target()
	water.camera = camera
	player.splashed.connect(water.splash)
	player.waded.connect(water.wake)

	# Kurze Rückmeldung beim Bauen und beim Aufkommen.
	build_fx = BuildFx.new()
	build_fx.name = "BuildFx"
	add_child(build_fx)
	player.landed.connect(build_fx.puff)

	# Staub und Pollen in der Luft — nur im sichtbaren Ausschnitt.
	ambient = AmbientFx.new()
	ambient.name = "AmbientFx"
	ambient.camera = camera
	add_child(ambient)

	# Tageslicht, ein weicher Schein um die Figur, dunklere Bildränder.
	# Muss nach der Kamera kommen: die Vignette liegt auf einer eigenen
	# CanvasLayer über der Welt, aber unter jeder Oberfläche.
	light = LightManager.new()
	light.name = "Light"
	light.player = player
	light.camera = camera
	add_child(light)

	# Fackeln: Bild in der Welt, Licht auf der Nachtschicht.
	torches = Torches.new()
	torches.name = "Fackeln"
	torches.map = map
	torches.light = light
	_sorted.add_child(torches)

	# Rotes Blockraster über allem — zeigt das sonst unsichtbare Grid.
	grid = GridOverlay.new()
	grid.name = "GridOverlay"
	grid.camera = camera
	grid.player = player
	add_child(grid)

	hud = HudScene.new()
	hud.player = player
	add_child(hud)
	if is_instance_valid(hud.minimap):
		hud.minimap.map = map
		hud.minimap.player = player
	if is_instance_valid(hud.debug):
		hud.debug.map = map
		hud.debug.player = player
		hud.debug.streamer = streamer
		hud.debug.world = self

	build_bar = BuildBar.new()
	build_bar.name = "BuildBar"
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
	build_tool.fx = build_fx
	build_tool.torches = torches
	build_tool.main = get_parent()
	add_child(build_tool)
	build_bar.slot_clicked.connect(func(i: int) -> void:
		build_bar.select(i))
	build_bar.set_loadout(Settings.build_loadout)
	build_bar.loadout_changed.connect(func() -> void:
		Settings.build_loadout = build_bar.loadout()
		Settings.save_settings())

	inventory = Inventory.new()
	inventory.name = "Inventory"
	# Das Inventar ist UI und muss bei pausiertem Baum bedienbar bleiben.
	inventory.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(inventory)
	inventory.setup(build_bar)
	# Genau ein Weg vom Klick zur Belegung: das Inventar bittet, die Leiste
	# führt aus, das Inventar zieht seine Anzeige nach. Kein zweiter Pfad,
	# keine doppelten Meldungen.
	inventory.equip_requested.connect(func(slot: int, tile: int) -> void:
		build_bar.equip(slot, tile)
		inventory.refresh())

	build_msec = Time.get_ticks_msec() - started
	print("Welt aufgebaut in %d ms (%d Chunks, %d Kollisionsformen)" % [
		build_msec, streamer.loaded_count(), streamer.shape_count()])
	print("  Phasen: ", builder.timings)
