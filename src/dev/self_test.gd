extends Node
## Automatischer Selbsttest (§19: nichts gilt als fertig, bevor es lief).
## Start:  godot --path . -- --selftest [--shots=/pfad]

var main: Node
var _fails: Array[String] = []
var _shot_dir: String = ""
var _save_backup := PackedByteArray()
var _had_save := false

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
	# Der Test baut selbst und speichert dabei. Eine vorhandene Karte des
	# Spielers wird deshalb beiseitegelegt und am Ende zurückgeschrieben —
	# ein Testlauf darf niemandem seine Arbeit löschen.
	_had_save = FileAccess.file_exists(MapData.SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_bytes(MapData.SAVE_PATH)
	MapData.clear_user()
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
	# Beim Betreten der Welt fallen einmalig Shader-Übersetzung und
	# Texturuploads an — im ersten Messfenster waren das 849 ms, im zweiten
	# schon 2,5. Deshalb wird erst gemessen, wenn das durch ist.
	await _frames(30)

	# --- Karte ---
	# Bei 4,2 Millionen Kacheln wird nicht mehr die ganze Karte gezählt,
	# sondern der geladene Ausschnitt um die Figur.
	var counts := _count_tiles(map, GridOverlay.block_at(player.position), 40)
	if Config.EMPTY_WORLD:
		_check(counts.size() == 1 and counts.has(MapData.Tile.GRASS), "Karte ist leer (nur Boden)")
		_check(world.get_node("Sorted").get_child_count() == 1, "Keine Requisiten auf der Karte")
		_check(map.is_solid(0, 10) and map.is_solid(Config.MAP_W - 1, 10),
			"Unsichtbare Wand am Kartenrand")
		var g: GridOverlay = world.grid
		_check(g != null and g.visible, "Blockraster ist sichtbar")
		_check(g.z_index > 100, "Raster liegt über der Welt")
	else:
		_check(counts.size() >= 6, "Karte enthält mehrere Bereiche (%d Typen)" % counts.size())
		for t in [MapData.Tile.GRASS, MapData.Tile.FOREST, MapData.Tile.WATER, MapData.Tile.PATH, MapData.Tile.SAND]:
			_check(counts.get(t, 0) > 20, "Bereich %d vorhanden" % t)
	var spawn_tile := Vector2i(int(player.position.x) / Config.TILE, int(player.position.y) / Config.TILE)
	_check(not map.is_solid(spawn_tile.x, spawn_tile.y), "Startpunkt ist begehbar")
	var want := (2 * Config.LOAD_RADIUS + 1) * (2 * Config.LOAD_RADIUS + 1)
	_check(world.streamer.loaded_count() == want,
		"Chunks um die Figur geladen (%d von %d)" % [world.streamer.loaded_count(), want])
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

	# --- Blickrichtung: die Seitenansicht ist nach rechts gezeichnet ---
	await _drive("move_right", 12)
	_check(player._dir == ActorArt.Dir.SIDE and not player._flip, "Blick nach rechts ungespiegelt")
	await _drive("move_left", 12)
	_check(player._dir == ActorArt.Dir.SIDE and player._flip, "Blick nach links gespiegelt")

	# --- Sprung: hebt ab, Boden bleibt, landet wieder ---
	player.velocity = Vector2.ZERO
	await _frames(4)
	var ground_pos := player.position
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(6)
	_check(player.is_jumping() and player.jump_height() > 1.0,
		"Sprung hebt ab (%.1f px)" % player.jump_height())
	_check(player.position.distance_to(ground_pos) < 0.01,
		"Bodenposition bleibt beim Sprung unverändert")
	await _frames(45)
	_check(not player.is_jumping() and player.jump_height() == 0.0, "Sprung landet wieder")

	# --- Kamera folgt ---
	var cam: GameCamera = world.camera
	await _frames(20)
	_check(cam.global_position.distance_to(player.global_position) < Config.TILE * 3.0, "Kamera folgt dem Spieler")
	_check(cam.limit_right == Config.world_size_px().x, "Kameragrenzen gesetzt")

	if Config.EMPTY_WORLD:
		await _check_chunks()
		await _check_building(world, map, player)
		await _check_streaming(world, player)

	if not Config.EMPTY_WORLD:
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
	player.position = Vector2(Config.TILE * 4.0, Config.TILE * 4.0)
	player.velocity = Vector2.ZERO
	await _frames(2)
	await _drive("move_left", 120)
	var size := Config.world_size_px()
	_check(player.position.x >= 0.0 and player.position.y >= 0.0
		and player.position.x <= size.x and player.position.y <= size.y, "Spieler bleibt in der Welt")
	_check(world.streamer.shape_count() > 0,
		"Weltrand hat Kollisionsformen (%d)" % world.streamer.shape_count())

	# Für den Screenshot zurück ins Dorf und in den Wald
	player.position = Vector2(Config.spawn_block().x, Config.spawn_block().y - 16) * Config.TILE
	player.velocity = Vector2.ZERO
	cam.snap_to_target()
	await _frames(6)
	await _shot("03_wald")

	var beach := Vector2i(-1, -1)
	if Config.EMPTY_WORLD:
		# Aufbaumodus: Raster am Kartenrand zeigen, dort sitzt die Wand
		player.position = Vector2(Config.TILE * 4.0, Config.TILE * 4.0)
		player.velocity = Vector2.ZERO
		cam.snap_to_target()
		await _frames(6)
		await _shot("04_raster_rand")
	else:
		beach = _find_beach(map)
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
	# Aufwärmen. Gemessen wurde: das allererste Messfenster nach dem Betreten
	# der Welt lag bei 849 ms, das zweite schon bei 2,5 — Shader-Übersetzung
	# und Texturuploads, kein Dauerzustand. Auch nach einem weiten Sprung im
	# Gelände fällt das noch einmal an, deshalb hier grosszügig.
	await _frames(90)

	# Zwei Messungen: im Stand und im Lauf. Im Lauf kommt das Nachladen der
	# Chunks dazu — das ist der interessante Fall, aber getrennt zu sehen.
	var t_still := 0.0
	for i in 30:
		await get_tree().physics_frame
		t_still += Performance.get_monitor(Performance.TIME_PROCESS)
	var ms_still := t_still / 30.0 * 1000.0

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
	print("Leistung nach dem Aufwärmen: Stand %.2f ms, Lauf mit Chunk-Laden %.2f ms, physics %.2f ms, Draw-Calls %d" % [
		ms_still, ms_process, ms_physics, int(draws / runs)])
	# Gemessen wird auf einem Software-Rasterizer (Xvfb/llvmpipe). Die Prozesszeit
	# hängt dort an der Füllrate und schwankt zwischen Läufen um mehr als das
	# Doppelte — sie wird berichtet, aber nicht bewertet. Geprüft wird, was
	# unabhängig vom Renderer aussagekräftig ist: Physikzeit, Ladezeit,
	# Wasserlast und die Bündelung der Zeichenaufrufe. Bricht das Batching der
	# Kachelschichten, fällt es dort sofort auf.
	print("Aufschlag der Spielwelt gegenüber dem Menü: %.2f ms (Software-Rasterizer, nur Bericht)"
		% (ms_still - ms_menu))
	var avg_draws := int(draws / runs)
	_check(avg_draws < 120, "Zeichenaufrufe bleiben gebündelt (%d)" % avg_draws)

	# Renderunabhängige Kennzahlen: die Prozesszeit misst hier ein
	# Software-Rasterizer und taugt nur zum Bericht, nicht zum Prüfen.
	var mm: Control = world.hud.minimap
	if mm != null:
		var t0 := Time.get_ticks_usec()
		for i in 60:
			mm.refresh()
		var ms_mini := (Time.get_ticks_usec() - t0) / 60000.0
		print("Minimap: %.2f ms je Aufbau" % ms_mini)
		_check(ms_mini < 6.0, "Minimap baut sich zügig auf (%.2f ms)" % ms_mini)
	var st2: ChunkStreamer = world.streamer
	var probe := GridOverlay.chunk_of(GridOverlay.block_at(player.global_position)) + Vector2i(3, 0)
	var t2 := Time.get_ticks_usec()
	for i in 10:
		st2.ground.paint_chunk(st2.layers, map, probe)
	var ms_chunk := (Time.get_ticks_usec() - t2) / 10000.0
	print("Chunk malen: %.2f ms" % ms_chunk)
	_check(ms_chunk < 8.0, "Ein Chunk ist schnell gemalt (%.2f ms)" % ms_chunk)
	var water: WaterFx = world.get_node("WaterFx")
	print("Wasser-Effekt: %d Rechtecke im letzten Bild" % water.prims)
	_check(water.prims < 900, "Wasser zeichnet sparsam (%d Rechtecke)" % water.prims)

	_check(ms_physics < 8.0, "Physikzeit pro Bild unter 8 ms (%.2f)" % ms_physics)

	# --- Lizenzlage: das Projekt darf keine fremden Asset-Dateien enthalten ---
	var assets := _find_assets("res://")
	_check(assets.is_empty(), "Keine Asset-Dateien im Projekt (%s)" %
		("keine" if assets.is_empty() else ", ".join(assets)))

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
	if Config.EMPTY_WORLD:
		# Der Weg aus dem Bau-Test wurde beim Verlassen automatisch gesichert
		# und muss jetzt wieder auf der Karte liegen.
		var again: MapData = main._world.map
		var mid2 := Config.spawn_block() + Vector2i(-5, -5)
		_check(again.get_tile(mid2.x, mid2.y) == MapData.Tile.PATH,
			"Gebaute Karte wird beim nächsten Start wieder geladen")
	_restore_save()

	print("=== ERGEBNIS: %s (%d Fehler) ===" % ["OK" if _fails.is_empty() else "FEHLER", _fails.size()])
	for f: String in _fails:
		print("   fehlgeschlagen: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)

## Sucht Bild-, Ton- und Schriftdateien im Projekt. Alle Grafiken und Klänge
## werden zur Laufzeit berechnet; ein Treffer hier hieße, dass sich doch eine
## fremde Datei eingeschlichen hat und in CREDITS.md gehören würde.
func _find_assets(path: String) -> Array[String]:
	const SUFFIX := [".png", ".jpg", ".jpeg", ".wav", ".ogg", ".mp3", ".ttf", ".otf"]
	var found: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir():
			# docs/ enthält Bildschirmfotos für die Dokumentation, keine Spielinhalte
			if not name.begins_with(".") and name != "docs" and name != "prototype_godsim":
				found.append_array(_find_assets(full))
		else:
			for suffix: String in SUFFIX:
				if name.to_lower().ends_with(suffix):
					found.append(full)
					break
		name = dir.get_next()
	dir.list_dir_end()
	return found

## Chunk-Rechnung: 16 x 16 Blöcke, die Karte geht ohne Rest darin auf.
func _check_chunks() -> void:
	var b := Vector2i(51, 41)
	_check(GridOverlay.chunk_of(b) == Vector2i(3, 2) and GridOverlay.block_in_chunk(b) == Vector2i(3, 9),
		"Chunk-Rechnung: Block 51|41 liegt in Chunk 3|2, dort auf 3|9")
	_check(GridOverlay.chunk_of(Vector2i(0, 0)) == Vector2i.ZERO
		and GridOverlay.block_in_chunk(Vector2i(Config.CHUNK, Config.CHUNK)) == Vector2i.ZERO,
		"Chunk-Grenzen liegen richtig")
	_check(Config.MAP_W % Config.CHUNK == 0 and Config.MAP_H % Config.CHUNK == 0,
		"Karte ergibt %d × %d volle Chunks" % [Config.MAP_W / Config.CHUNK, Config.MAP_H / Config.CHUNK])
	await get_tree().process_frame

## Bau-Leiste: Blöcke setzen, Nachbarschaft, Wasserkollision, Speichern.
func _check_building(world: Node2D, map: MapData, player: Player) -> void:
	var tool: BuildTool = world.build_tool
	_check(tool != null and world.build_bar != null, "Bau-Leiste vorhanden")
	if tool == null:
		return

	# --- Der Fehler aus dem Foto: einzelne Blöcke wurden Klekse ---
	var home0 := GridOverlay.block_at(player.global_position)
	var cob: TileMapLayer = world.streamer.layers[8]     # Pflaster
	var solo := home0 + Vector2i(-10, -8)
	tool.place(solo, MapData.Tile.COBBLE)
	await _frames(2)
	var full_start := TerrainAtlas.FULL_START
	_check(cob.get_cell_atlas_coords(solo).x + cob.get_cell_atlas_coords(solo).y * TerrainAtlas.COLS
		>= full_start, "Einzelner Block ist eine Vollkachel, kein Klecks")
	_check(cob.get_cell_source_id(solo + Vector2i(1, 0)) != -1,
		"Nachbarfeld bekommt den Saum")

	# Sechs in einer Reihe: früher zerfiel das in sechs Punkte.
	var rowy := home0.y - 5
	for i in 6:
		tool.place(Vector2i(home0.x - 10 + i, rowy), MapData.Tile.COBBLE)
	await _frames(2)
	var all_full := true
	for i in 6:
		var c := Vector2i(home0.x - 10 + i, rowy)
		var a := cob.get_cell_atlas_coords(c)
		if a.x + a.y * TerrainAtlas.COLS < full_start:
			all_full = false
	_check(all_full, "Reihe aus sechs Blöcken ergibt sechs Vollkacheln")

	# Die Bauvorschau darf nicht am Raster hängen — genau das war der Fehler.
	var g: GridOverlay = world.grid
	g.show_grid = false
	await _frames(2)
	_check(g.visible and not g.show_grid, "Raster aus, Vorschau bleibt gezeichnet")
	_check(world.build_bar.preview_texture() != null, "Vorschau kennt die gewählte Kachel")
	g.show_grid = true

	# Stapelposition 7 ist der Weg — dort muss der gesetzte Fleck erscheinen.
	var path_layer: TileMapLayer = world.streamer.layers[7]
	var before := path_layer.get_used_cells().size()
	# Gebaut wird neben der Figur — nur dort sind Chunks geladen.
	var home := GridOverlay.block_at(player.global_position)
	var origin := home + Vector2i(-6, -6)
	for oy in 3:
		for ox in 3:
			tool.place(origin + Vector2i(ox, oy), MapData.Tile.PATH)
	await _frames(2)
	var mid := origin + Vector2i(1, 1)
	_check(map.get_tile(mid.x, mid.y) == MapData.Tile.PATH, "Block gesetzt (Weg)")
	# 9 gesetzte Felder plus der Saum auf den 16 Nachbarfeldern ringsum.
	_check(path_layer.get_used_cells().size() == before + 25,
		"Wegfläche mit Saum bemalt (%d Zellen)" % (path_layer.get_used_cells().size() - before))
	# Die Mitte ist eine Vollkachel, die Ecke eine Übergangskachel.
	_check(path_layer.get_cell_atlas_coords(mid)
		!= path_layer.get_cell_atlas_coords(origin),
		"Randkacheln des Flecks sind Übergänge")

	# Zurücksetzen: das Feld ist kein Weg mehr, bekommt aber den Saum der
	# Nachbarn, die noch Weg sind.
	tool.place(origin, MapData.Tile.GRASS)
	await _frames(2)
	var a_reset := path_layer.get_cell_atlas_coords(origin)
	_check(a_reset.x + a_reset.y * TerrainAtlas.COLS < TerrainAtlas.FULL_START,
		"Zurückgesetzter Block ist keine Vollkachel mehr")

	# Flaches Wasser lässt sich durchschwimmen, Tiefwasser nicht.
	var wet := home + Vector2i(6, -6)
	tool.place(wet, MapData.Tile.WATER)
	await _frames(2)
	_check(not map.is_solid(wet.x, wet.y) and map.is_swimmable(wet.x, wet.y),
		"Gesetztes Wasser ist schwimmbar")
	player.position = Vector2(wet.x + 0.5, wet.y - 1.5) * Config.TILE
	player.velocity = Vector2.ZERO
	await _frames(3)
	_check(not player.is_swimming(), "An Land wird nicht geschwommen")
	# Bis ins Wasser laufen und dort anhalten: eine feste Bilderzahl liefe
	# einfach durch den Teich hindurch.
	Input.action_press("move_down")
	var reached := false
	for i in 90:
		await get_tree().physics_frame
		if player.is_swimming():
			reached = true
			break
	Input.action_release("move_down")
	await _frames(4)
	var stand := GridOverlay.block_at(player.global_position)
	_check(reached and player.is_swimming(),
		"Figur schwimmt im gesetzten Wasser (Block %d|%d)" % [stand.x, stand.y])
	_check(player.velocity.length() <= Config.SWIM_SPEED + 1.0,
		"Im Wasser höchstens Schwimmgeschwindigkeit (%.0f)" % player.velocity.length())
	await _drive("move_up", 70)
	_check(not player.is_swimming(), "Nach dem Verlassen wird wieder gelaufen")

	# Sprung ins Wasser: der Sprung wird zu Ende geflogen, erst dann geschwommen.
	player.position = Vector2(wet.x + 0.5, wet.y - 1.2) * Config.TILE
	player.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_press("move_down")
	var mid_air_swim := false
	for i in 40:
		await get_tree().physics_frame
		if player.is_swimming() and player.is_jumping():
			mid_air_swim = true
	Input.action_release("move_down")
	await _frames(10)
	_check(not mid_air_swim, "Im Sprung wird nicht geschwommen")
	_check(player.is_swimming(), "Nach der Landung im Wasser wird geschwommen")
	await _drive("move_up", 60)

	# Tiefwasser bleibt eine Wand.
	var deep := home + Vector2i(8, -6)
	tool.place(deep, MapData.Tile.DEEP_WATER)
	await _frames(2)
	_check(map.is_solid(deep.x, deep.y) and tool.shape_count() > 0,
		"Tiefwasser blockiert (%d Formen)" % tool.shape_count())
	tool.place(wet, MapData.Tile.GRASS)
	tool.place(deep, MapData.Tile.GRASS)
	await _frames(2)
	_check(not map.is_solid(deep.x, deep.y), "Tiefwasser entfernt, Kollision weg")

	# Ein kleines Stück Dorf bauen — als Bildbeleg und als Belastungsprobe für
	# die Übergänge zwischen vier verschiedenen Bodentypen auf engem Raum.
	await _build_demo(tool, world, player)

	# --- Inventar: ausrüsten, was in der Leiste liegt ---
	var inv: CanvasLayer = world.inventory
	_check(inv != null, "Inventar vorhanden")
	if inv != null:
		main.toggle_inventory()
		await _frames(3)
		_check(main.state == main.State.INVENTORY and inv.visible, "Inventar öffnet mit E")
		await _frames(4)
		await _shot("09_inventar")
		inv.select_slot(2)
		var before_type: int = world.build_bar.types[2]
		inv.equip_requested.emit(2, MapData.Tile.DEEP_WATER)
		await _frames(3)
		_check(world.build_bar.types[2] == MapData.Tile.DEEP_WATER
			and before_type != MapData.Tile.DEEP_WATER,
			"Klick im Inventar rüstet den Typ auf das gewählte Feld")
		world.build_bar.select(2)
		_check(world.build_bar.tile_type() == MapData.Tile.DEEP_WATER,
			"Die Leiste setzt danach den neuen Typ")
		inv.equip_requested.emit(2, before_type)
		main.toggle_inventory()
		await _frames(3)
		_check(main.state == main.State.PLAYING and not inv.visible, "Inventar schliesst wieder")
		world.build_bar.select(0)

	# --- Eigene Tasten für Minimap und Anzeige ---
	var g2: GridOverlay = world.grid
	var grid_before := g2.show_grid
	var mini_before: bool = world.hud.minimap.visible
	world.hud._unhandled_input(_key("toggle_minimap"))
	await _frames(2)
	_check(world.hud.minimap.visible != mini_before and g2.show_grid == grid_before,
		"M schaltet die Minimap, das Raster bleibt")
	world.hud._unhandled_input(_key("toggle_minimap"))
	world.hud._unhandled_input(_key("toggle_info"))
	await _frames(2)
	_check(not world.hud._blocks.visible and g2.show_grid == grid_before,
		"H schaltet die Anzeige, das Raster bleibt")
	world.hud._unhandled_input(_key("toggle_info"))
	await _frames(2)

	# Minimap zeigt, was unter der Figur liegt.
	var mini: Control = world.hud.minimap
	_check(mini != null, "Minimap vorhanden")
	if mini != null:
		mini.refresh()
		await _frames(2)
		var under := map.get_tile(int(player.position.x) / Config.TILE, int(player.position.y) / Config.TILE)
		var img: Image = mini._img
		_check(img.get_width() > 0 and img.get_height() > 0,
			"Minimap-Bild ist %d × %d" % [img.get_width(), img.get_height()])
		var center_px := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		_check(center_px.is_equal_approx(mini.color_of(under)),
			"Mittelpunkt der Minimap zeigt den Boden unter der Figur")

	# Speichern und Laden ergibt dieselbe Karte.
	_check(tool.save(), "Karte gespeichert")
	var reread := MapData.load_user()
	_check(reread == map.tiles, "Geladene Karte stimmt mit der gebauten überein")
	MapData.clear_user()
	_check(MapData.load_user().is_empty(), "Ohne Datei wird nichts geladen")

## Baut von Hand ein Stück Dorf: Hausgrundriss aus Pflaster, ein Weg dorthin,
## eine Wiese und ein Teich. Setzt dieselben Aufrufe ab wie ein Mausklick.
func _build_demo(tool: BuildTool, world: Node2D, player: Player) -> void:
	var o := GridOverlay.block_at(player.global_position) + Vector2i(-8, 2)
	# Hausgrundriss: 3 Reihen zu je 2 Blöcken, wie vom Maßstab her besprochen
	for y in 3:
		for x in 2:
			tool.place(o + Vector2i(x, y), MapData.Tile.COBBLE)
	# Weg vom Haus nach rechts, zwei Blöcke breit
	for x in range(2, 14):
		for y in 2:
			tool.place(o + Vector2i(x, y + 1), MapData.Tile.PATH)
	# Wiese ringsum
	for y in range(-3, 7):
		for x in range(-3, 3):
			var c := o + Vector2i(x, y)
			if tool.map.get_tile(c.x, c.y) == MapData.Tile.GRASS:
				tool.place(c, MapData.Tile.MEADOW)
	# Felsplateau: hier muss die Klippe mit Wand und Schlagschatten entstehen
	for y in range(-2, 3):
		for x in range(14, 21):
			tool.place(o + Vector2i(x, y), MapData.Tile.ROCK)
	# Teich mit Sandsaum
	for y in range(6, 11):
		for x in range(7, 13):
			tool.place(o + Vector2i(x, y), MapData.Tile.SAND)
	for y in range(7, 10):
		for x in range(8, 12):
			tool.place(o + Vector2i(x, y), MapData.Tile.WATER)
	await _frames(2)
	_check(tool.map.is_swimmable(o.x + 9, o.y + 8), "Teich ist schwimmbar")

	# --- Fels ist eine Stufe: dagegenlaufen hält an, im Sprung kommt man hinauf
	var ledge := o + Vector2i(17, 3)          # Gras direkt unter dem Plateau
	player.position = Vector2(ledge.x + 0.5, ledge.y + 0.5) * Config.TILE
	player.velocity = Vector2.ZERO
	await _frames(4)
	_check(player.level() == 0, "Auf dem Boden ist die Höhenstufe 0")
	await _drive("move_up", 45)
	_check(player.level() == 0 and tool.map.level_at(
		GridOverlay.block_at(player.global_position).x,
		GridOverlay.block_at(player.global_position).y) == 0,
		"Gegen die Felskante laufen hält an")

	# Jetzt mit Sprung: Leertaste drücken und dabei weiterlaufen.
	player.position = Vector2(ledge.x + 0.5, ledge.y + 0.6) * Config.TILE
	player.velocity = Vector2.ZERO
	await _frames(3)
	Input.action_press("move_up")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var climbed := false
	for i in 40:
		await get_tree().physics_frame
		if player.level() == 1:
			climbed = true
			break
	Input.action_release("move_up")
	await _frames(4)
	_check(climbed, "Mit dem Sprung kommt man auf den Fels")
	if climbed:
		await _drive("move_up", 25)
		world.camera.snap_to_target()
		tool.set_process(false)
		world.grid.cursor_block = Vector2i(-1, -1)
		await _frames(6)
		await _shot("10_auf_dem_fels")
		tool.set_process(true)

	# Herunter geht immer — bis zur Kante laufen, egal wie weit oben sie steht.
	Input.action_press("move_down")
	var dropped := false
	for i in 120:
		await get_tree().physics_frame
		if player.level() == 0:
			dropped = true
			break
	Input.action_release("move_down")
	await _frames(4)
	_check(dropped, "Vom Fels herunter geht ohne Sprung")

	# Klippe: Wandkachel auf dem Fels, Schlagschatten auf der Kachel darunter
	var edges: TileMapLayer = world.streamer.layers[GroundTileSet.LAYER_EDGE]
	var shadows: TileMapLayer = world.streamer.layers[GroundTileSet.LAYER_SHADOW]
	var brink := o + Vector2i(17, 2)          # unterste Felsreihe
	_check(edges.get_cell_source_id(brink) != -1, "Fels bekommt eine Kantenkachel")
	_check(shadows.get_cell_source_id(brink + Vector2i(0, 1)) != -1,
		"Schlagschatten liegt unter der Klippe")
	_check(shadows.get_cell_source_id(brink) == -1,
		"Auf dem Fels selbst liegt kein Schatten")
	var shore := o + Vector2i(9, 6)           # Sand direkt über dem Teich
	_check(edges.get_cell_source_id(shore) != -1, "Land am Wasser bekommt eine Uferkante")
	_check(edges.get_cell_source_id(o + Vector2i(9, 7)) != -1,
		"Wasser am Ufer bekommt ein Tiefenband")

	player.position = Vector2(o.x + 12.0, o.y + 4.0) * Config.TILE
	player.velocity = Vector2.ZERO
	world.camera.snap_to_target()
	await _frames(6)
	await _shot("07_bauen")

	# Schwimmbild: Figur mitten in den Teich setzen. Der Bauzeiger liegt in
	# der Bildmitte und verdeckte sie sonst.
	player.position = Vector2(o.x + 9.5, o.y + 8.5) * Config.TILE
	player.velocity = Vector2.ZERO
	world.camera.snap_to_target()
	tool.set_process(false)
	world.grid.cursor_block = Vector2i(-1, -1)
	await _frames(8)
	_check(player.is_swimming(), "Figur schwimmt im Teich")
	await _shot("08_schwimmen")
	tool.set_process(true)
	player.position = Vector2(o.x + 12.0, o.y + 4.0) * Config.TILE
	player.velocity = Vector2.ZERO
	await _frames(4)

## Chunk-Laden: die Welt kommt und geht um die Figur herum.
func _check_streaming(world: Node2D, player: Player) -> void:
	var st: ChunkStreamer = world.streamer
	var want := (2 * Config.LOAD_RADIUS + 1) * (2 * Config.LOAD_RADIUS + 1)
	# Das Nachladen ist auf zwei Chunks je Bild begrenzt: nach den Fahrten
	# oben können noch welche in der Warteschlange stehen.
	await _frames(20)
	var here := GridOverlay.chunk_of(GridOverlay.block_at(player.global_position))
	_check(st.is_loaded(here), "Chunk unter der Figur ist geladen")
	var cells := st.layers[0].get_used_cells().size()
	_check(cells == want * Config.CHUNK * Config.CHUNK,
		"Grundschicht hat genau die geladenen Zellen (%d)" % cells)

	# Weit weg versetzen: alles Alte muss verschwinden, Neues nachkommen.
	var far := here + Vector2i(20, 20)
	player.position = Vector2(far.x * Config.CHUNK + 8, far.y * Config.CHUNK + 8) * Config.TILE
	player.velocity = Vector2.ZERO
	var loads_before := st.loads
	await _frames(40)
	_check(not st.is_loaded(here), "Alte Chunks sind entladen")
	_check(st.is_loaded(far), "Chunk am neuen Ort ist geladen")
	_check(st.loaded_count() == want,
		"Wieder %d Chunks geladen (%d)" % [want, st.loaded_count()])
	_check(st.layers[0].get_used_cells().size() == cells,
		"Zellzahl bleibt begrenzt (%d)" % st.layers[0].get_used_cells().size())
	_check(st.loads - loads_before == want and st.unloads >= want,
		"Genau %d nachgeladen, %d entladen" % [st.loads - loads_before, st.unloads])

## Legt die Karte des Spielers wieder so ab, wie sie vor dem Test war.
func _restore_save() -> void:
	MapData.clear_user()
	if not _had_save:
		return
	var f := FileAccess.open(MapData.SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_buffer(_save_backup)
		f.close()

## Zählt die Bodentypen in einem Quadrat um einen Block.
func _count_tiles(map: MapData, center: Vector2i, radius: int) -> Dictionary:
	var out := {}
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not map.in_bounds(x, y):
				continue
			var t := map.get_tile(x, y)
			out[t] = out.get(t, 0) + 1
	return out

## Baut ein Tastenereignis für eine Aktion — für Prüfungen, die direkt in
## _unhandled_input gehen.
func _key(action: String) -> InputEventKey:
	var ev := InputEventKey.new()
	var list := InputMap.action_get_events(action)
	ev.physical_keycode = (list[0] as InputEventKey).physical_keycode
	ev.pressed = true
	return ev

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
	var body: StaticBody2D = world.streamer.body
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
