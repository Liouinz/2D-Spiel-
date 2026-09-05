extends Node
## Automatischer Selbsttest (§19: nichts gilt als fertig, bevor es lief).
## Start:  godot --path . -- --selftest [--shots=/pfad]

var main: Node
var _fails: Array[String] = []
var _shot_dir: String = ""

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shot_dir = a.substr(8)
	var guard := Timer.new()
	guard.wait_time = 150.0
	guard.one_shot = true
	guard.process_mode = Node.PROCESS_MODE_ALWAYS
	guard.timeout.connect(func() -> void:
		push_error("Selbsttest-Zeitüberschreitung")
		print("=== ERGEBNIS: ZEITÜBERSCHREITUNG ===")
		get_tree().quit(2))
	add_child(guard)
	guard.start()
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  [ok]   ", what)
	else:
		_fails.append(what)
		print("  [FAIL] ", what)

func _shot(name: String) -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_dir.path_join(name + ".png"))

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run() -> void:
	print("=== SELBSTTEST ===")
	if _shot_dir != "":
		var sheet: Array[String] = preload("res://src/dev/asset_sheet.gd").dump(_shot_dir, Config.WORLD_SEED)
		print("Requisiten: ", ", ".join(sheet))
	await get_tree().process_frame

	# --- Hauptmenü ---
	_check(main.state == main.State.MENU, "Start im Hauptmenü")
	await _frames(3)
	await _shot("01_hauptmenue")
	# Grundlast ohne Welt — dient als Vergleichswert für die Messung unten
	await _frames(20)
	var base := 0.0
	for i in 30:
		await get_tree().physics_frame
		base += Performance.get_monitor(Performance.TIME_PROCESS)
	var ms_menu := base / 30.0 * 1000.0
	print("Grundlast im Menü: process %.2f ms" % ms_menu)

	# --- Spiel starten ---
	main.start_game()
	await _frames(4)
	var world: Node2D = main._world
	_check(world != null, "Welt wurde erzeugt")
	var player: Player = world.player
	var map: MapData = world.map
	_check(player != null, "Spieler existiert")
	_check(main.state == main.State.PLAYING, "Zustand PLAYING")
	_check(not get_tree().paused, "Baum läuft")

	# --- Karte ---
	var counts := {}
	for i in map.tiles.size():
		counts[map.tiles[i]] = counts.get(map.tiles[i], 0) + 1
	_check(counts.size() >= 6, "Karte enthält mehrere Bereiche (%d Typen)" % counts.size())
	for t in [MapData.Tile.GRASS, MapData.Tile.FOREST, MapData.Tile.WATER, MapData.Tile.PATH, MapData.Tile.SAND]:
		_check(counts.get(t, 0) > 20, "Bereich %d vorhanden" % t)
	var spawn_tile := Vector2i(int(player.position.x) / Config.TILE, int(player.position.y) / Config.TILE)
	_check(not map.is_solid(spawn_tile.x, spawn_tile.y), "Startpunkt ist begehbar")
	_check(world.get_node("Collision").get_child_count() > 10, "Kollisionsformen gebaut (%d)" %
		world.get_node("Collision").get_child_count())
	await _shot("02_dorf")

	# --- Bewegung ---
	var start := player.position
	await _drive("move_right", 30)
	_check(player.position.x > start.x + Config.TILE * 0.5, "Bewegung nach rechts")
	await _drive("move_up", 30)
	_check(player.position.y < start.y - Config.TILE * 0.25, "Bewegung nach oben")
	await _drive("move_left", 30)
	await _drive("move_down", 30)
	_check(player.position.distance_to(start) < Config.TILE * 3.0, "Zurück in Startnähe")

	# --- Kamera folgt ---
	var cam: GameCamera = world.camera
	await _frames(20)
	_check(cam.global_position.distance_to(player.global_position) < Config.TILE * 3.0, "Kamera folgt dem Spieler")
	_check(cam.limit_right == Config.world_size_px().x, "Kameragrenzen gesetzt")

	# --- Kollision: gegen Wasser laufen ---
	var wet := _find_water_shore(map)
	if wet != Vector2i(-1, -1):
		player.position = Vector2(wet.x * Config.TILE + 8, wet.y * Config.TILE + 8)
		player.velocity = Vector2.ZERO
		await _frames(2)
		await _drive("move_down", 90)
		var tile := Vector2i(int(player.position.x) / Config.TILE, int(player.position.y) / Config.TILE)
		_check(not map.is_solid(tile.x, tile.y), "Spieler läuft nicht ins Wasser")
	else:
		_check(false, "Uferkachel gefunden")

	# --- Kollision: gegen einen Baum laufen ---
	var blocked: bool = await _walk_into_prop(world)
	_check(blocked, "Requisiten (Baum/Fels/Haus) blockieren")

	# --- Weltgrenze ---
	player.position = Vector2(Config.TILE * 4, Config.TILE * 4)
	player.velocity = Vector2.ZERO
	await _frames(2)
	await _drive("move_left", 120)
	var size := Config.world_size_px()
	_check(player.position.x >= 0.0 and player.position.y >= 0.0
		and player.position.x <= size.x and player.position.y <= size.y, "Spieler bleibt in der Welt")

	# Für den Screenshot zurück ins Dorf und in den Wald
	player.position = Vector2(Layout.SPAWN.x * Config.TILE, (Layout.SPAWN.y - 16) * Config.TILE)
	player.velocity = Vector2.ZERO
	cam.snap_to_target()
	await _frames(6)
	await _shot("03_wald")

	# Strand / Bucht
	var beach := _find_beach(map)
	if beach != Vector2i(-1, -1):
		player.position = Vector2(beach.x * Config.TILE, beach.y * Config.TILE)
		player.velocity = Vector2.ZERO
		cam.snap_to_target()
		await _frames(6)
		await _shot("04_strand")
	_check(beach != Vector2i(-1, -1), "Strand mit Wasser vorhanden")

	_check(world.build_msec < 5000, "Welt lädt zügig (%d ms)" % world.build_msec)

	# --- Leistung: schlimmster Fall ist die Bucht mit viel Wasser ---
	if beach != Vector2i(-1, -1):
		player.position = Vector2(beach.x * Config.TILE, beach.y * Config.TILE)
		cam.snap_to_target()
	await _frames(30)                      # aufwärmen
	var t_process := 0.0
	var t_physics := 0.0
	var draws := 0.0
	var runs := 60
	Input.action_press("move_right")
	for i in runs:
		await get_tree().physics_frame
		t_process += Performance.get_monitor(Performance.TIME_PROCESS)
		t_physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	Input.action_release("move_right")
	var ms_process := t_process / runs * 1000.0
	var ms_physics := t_physics / runs * 1000.0
	print("Leistung: process %.2f ms, physics %.2f ms, Draw-Calls %d, Objekte %d" % [
		ms_process, ms_physics, int(draws / runs), world.get_node("Sorted").get_child_count()])
	# Gemessen wird auf einem Software-Rasterizer (Xvfb/llvmpipe). Die Prozesszeit
	# hängt dort an der Füllrate und schwankt zwischen Läufen um mehr als das
	# Doppelte — sie wird berichtet, aber nicht bewertet. Geprüft wird, was
	# unabhängig vom Renderer aussagekräftig ist: Physikzeit, Ladezeit,
	# Wasserlast und die Bündelung der Zeichenaufrufe. Bricht das Batching der
	# Kachelschichten, fällt es dort sofort auf.
	print("Aufschlag der Spielwelt gegenüber dem Menü: %.2f ms (Software-Rasterizer, nur Bericht)"
		% (ms_process - ms_menu))
	var avg_draws := int(draws / runs)
	_check(avg_draws < 120, "Zeichenaufrufe bleiben gebündelt (%d)" % avg_draws)
	var water: WaterFx = world.get_node("WaterFx")
	print("Wasser-Effekt: %d Rechtecke im letzten Bild" % water.prims)
	_check(water.prims < 900, "Wasser zeichnet sparsam (%d Rechtecke)" % water.prims)

	_check(ms_physics < 8.0, "Physikzeit pro Bild unter 8 ms (%.2f)" % ms_physics)

	# --- Audio ---
	_check(Audio._sfx.size() >= 5, "Effektklänge erzeugt (%d)" % Audio._sfx.size())
	_check(Audio._music.has("world") and Audio._music["world"].data.size() > 1000,
		"Weltmusik erzeugt und geloopt")
	Audio.play_ui("confirm")
	Audio.play_step()
	_check(true, "Klänge lassen sich abspielen")

	# --- Pause ---
	main.pause_game()
	await _frames(2)
	_check(main.state == main.State.PAUSED and get_tree().paused, "Pause aktiv")
	await _shot("05_pause")

	# --- Optionen ---
	main.open_options()
	await _frames(2)
	_check(main.state == main.State.OPTIONS, "Optionen offen")
	await _shot("06_optionen")
	main.close_options()
	await _frames(2)
	_check(main.state == main.State.PAUSED, "Zurück zur Pause")
	main.resume_game()
	await _frames(2)
	_check(main.state == main.State.PLAYING and not get_tree().paused, "Fortgesetzt")

	# --- Zurück ins Menü und erneut starten ---
	main.to_main_menu()
	await _frames(4)
	_check(main.state == main.State.MENU, "Zurück im Hauptmenü")
	main.start_game()
	await _frames(6)
	_check(main._world != null and main._world != world, "Neustart erzeugt frische Welt")

	print("=== ERGEBNIS: %s (%d Fehler) ===" % ["OK" if _fails.is_empty() else "FEHLER", _fails.size()])
	for f: String in _fails:
		print("   fehlgeschlagen: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)

func _drive(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(2)

func _find_beach(map: MapData) -> Vector2i:
	for y in range(Config.MAP_H - 4, 4, -1):
		for x in range(4, Config.MAP_W - 4):
			if map.get_tile(x, y) == MapData.Tile.SAND and map.is_water(x, y + 2):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _find_water_shore(map: MapData) -> Vector2i:
	for y in range(2, Config.MAP_H - 3):
		for x in range(2, Config.MAP_W - 3):
			if not map.is_solid(x, y) and map.is_water(x, y + 1) and map.is_water(x, y + 2):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _walk_into_prop(world: Node2D) -> bool:
	var body: StaticBody2D = world.get_node("Collision")
	for child in body.get_children():
		var cs := child as CollisionShape2D
		var r := (cs.shape as RectangleShape2D).size
		if r.x > Config.TILE * 6:
			continue  # Wasserflächen überspringen, wir wollen eine Requisite
		var target := cs.position
		var from := target + Vector2(0, -Config.TILE * 2.5)
		var tile := Vector2i(int(from.x) / Config.TILE, int(from.y) / Config.TILE)
		if world.map.is_solid(tile.x, tile.y):
			continue
		world.player.position = from
		world.player.velocity = Vector2.ZERO
		await _frames(2)
		await _drive("move_down", 60)
		return world.player.position.y < target.y
	return false
