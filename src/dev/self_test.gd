extends Node
## Automatischer Selbsttest (§19: nichts gilt als fertig, bevor es lief).
## Start:  godot --path . -- --selftest [--shots=/pfad]
##
## Die Welt kennt genau drei Materialien: Gras, Sand, Wasser. Der Test prüft
## das an jeder Stelle nach, an der früher ein weiterer Bodentyp stand — und
## zusätzlich die Punkte, an denen zuletzt Fehler steckten: E als echter
## Umschalter, die Trennung von Oberfläche und Spiel, die Technik des
## Kachelsatzes, das Bauen auf dem Raster, Wasser und Kollision, und dass es
## keine Klangeffekte mehr gibt, die Musik aber läuft.

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
	await get_tree().process_frame

	# --- Genau drei Materialien, überall ---
	await _check_three_materials()

	# --- Hauptmenü ---
	_check(main.state == main.State.MENU, "Start im Hauptmenü")
	await _frames(3)
	await _shot("01_hauptmenue")
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

	# --- Kachelbilder: nahtlos? ---
	await _check_seams()

	# --- Kachelsatz und Kachelraster technisch prüfen ---
	await _check_tileset(world, map, player)

	# --- Karte ---
	var counts := _count_tiles(map, GridOverlay.block_at(player.position), 40)
	_check(counts.size() == 1 and counts.has(MapData.Tile.GRASS),
		"Karte startet leer (nur Gras)")
	_check(world.get_node("Sorted").get_child_count() == 1,
		"Keine Requisiten auf der Karte")
	_check(map.is_solid(0, 10) and map.is_solid(Config.MAP_W - 1, 10),
		"Unsichtbare Wand am Kartenrand")
	var g: GridOverlay = world.grid
	_check(g != null and g.visible, "Blockraster ist sichtbar")
	_check(g.z_index > 100, "Raster liegt über der Welt")
	var spawn_tile := GridOverlay.block_at(player.position)
	_check(not map.is_solid(spawn_tile.x, spawn_tile.y), "Startpunkt ist begehbar")
	var want := (2 * Config.LOAD_RADIUS + 1) * (2 * Config.LOAD_RADIUS + 1)
	_check(world.streamer.loaded_count() == want,
		"Chunks um die Figur geladen (%d von %d)" % [world.streamer.loaded_count(), want])
	await _shot("02_welt")

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
	_check(cam.global_position.distance_to(player.global_position) < Config.TILE * 3.0,
		"Kamera folgt dem Spieler")
	_check(cam.limit_right == Config.world_size_px().x, "Kameragrenzen gesetzt")

	await _check_chunks()
	await _check_building(world, map, player)
	await _check_water(world, map, player)
	await _check_toggle(world, map, player)
	await _check_inventory_ui(world)
	await _check_input_lock(world, map, player)
	await _check_input_map(world)
	await _check_stress(world, map, player)
	await _check_streaming(world, player)

	# --- Weltgrenze ---
	player.position = Vector2(Config.TILE * 4.0, Config.TILE * 4.0)
	player.velocity = Vector2.ZERO
	cam.snap_to_target()
	await _frames(6)
	await _drive("move_left", 120)
	var size := Config.world_size_px()
	_check(player.position.x >= 0.0 and player.position.y >= 0.0
		and player.position.x <= size.x and player.position.y <= size.y,
		"Spieler bleibt in der Welt")
	_check(world.streamer.shape_count() > 0,
		"Weltrand hat Kollisionsformen (%d)" % world.streamer.shape_count())
	cam.snap_to_target()
	await _frames(6)
	await _shot("04_raster_rand")

	_check(world.build_msec < 5000, "Welt lädt zügig (%d ms)" % world.build_msec)

	await _check_performance(world, map, player, ms_menu)

	# --- Lizenzlage: das Projekt darf keine fremden Asset-Dateien enthalten ---
	var assets := _find_assets("res://")
	_check(assets.is_empty(), "Keine Asset-Dateien im Projekt (%s)" %
		("keine" if assets.is_empty() else ", ".join(assets)))

	# --- Ton: Musik bleibt, Effekte sind weg ---
	await _check_audio()

	# --- Pause ---
	main.pause_game()
	await _frames(2)
	_check(main.state == main.State.PAUSED and get_tree().paused, "Pause aktiv")
	await _shot("05_pause")

	# --- Optionen ---
	main.open_options()
	await _frames(2)
	_check(main.state == main.State.OPTIONS, "Optionen offen")
	await _frames(4)
	await _shot("06_optionen")
	main.close_options()
	await _frames(2)
	_check(main.state == main.State.PAUSED, "Zurück zur Pause")
	main.resume_game()
	await _frames(2)
	_check(main.state == main.State.PLAYING and not get_tree().paused, "Fortgesetzt")

	# --- Speichern und Laden ---
	var tool: BuildTool = world.build_tool
	# Fester Punkt in der Kartenmitte: die Figur steht nach der Randprüfung
	# ganz aussen, ein Feld neben ihr läge ausserhalb der Karte.
	var mark := Config.spawn_block() + Vector2i(3, 3)
	tool.place(mark, MapData.Tile.SAND)
	await _frames(2)
	_check(tool.save(), "Karte gespeichert")
	var reread := MapData.load_user()
	_check(reread == map.tiles, "Geladene Karte stimmt mit der gebauten überein")

	# --- Zurück ins Menü und erneut starten ---
	main.to_main_menu()
	await _frames(4)
	_check(main.state == main.State.MENU, "Zurück im Hauptmenü")
	main.start_game()
	await _frames(6)
	_check(main._world != null and main._world != world, "Neustart erzeugt frische Welt")
	var again: MapData = main._world.map
	_check(again.get_tile(mark.x, mark.y) == MapData.Tile.SAND,
		"Gebaute Karte wird beim nächsten Start wieder geladen")
	MapData.clear_user()
	_check(MapData.load_user().is_empty(), "Ohne Datei wird nichts geladen")
	_restore_save()

	print("=== ERGEBNIS: %s (%d Fehler) ===" % ["OK" if _fails.is_empty() else "FEHLER", _fails.size()])
	for f: String in _fails:
		print("   fehlgeschlagen: ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)

# --- Drei Materialien ---------------------------------------------------------

## Gras, Sand, Wasser — und sonst nichts. Geprüft wird nicht nur die Aufzählung,
## sondern jede Liste, die früher weitere Bodentypen führte: Kachelstapel,
## Namen, Bau-Leiste, Inventar, Minimap. Ein vergessener Eintrag fällt hier auf,
## nicht erst im Spiel.
func _check_three_materials() -> void:
	_check(MapData.Tile.COUNT == 3, "Genau drei Bodentypen (%d)" % MapData.Tile.COUNT)
	_check(MapData.Tile.GRASS == 0 and MapData.Tile.SAND == 1 and MapData.Tile.WATER == 2,
		"Reihenfolge Gras, Sand, Wasser")
	_check(MapData.NAMES.size() == 3 and MapData.TERRAIN.size() == 3,
		"Namen und Geländetabelle kennen nur die drei")
	_check(GroundTileSet.STACK.size() == 3
		and GroundTileSet.STACK == [MapData.Tile.GRASS, MapData.Tile.SAND, MapData.Tile.WATER],
		"Kachelstapel hat drei Schichten")
	_check(GroundTileSet.LAYER_COUNT == 4 and GroundTileSet.LAYER_EDGE == 3,
		"Vier Schichten: drei Böden plus Kanten")

	var inv_all: Array = Inventory.ALL
	_check(inv_all.size() == 3
		and inv_all.has(MapData.Tile.GRASS) and inv_all.has(MapData.Tile.SAND)
		and inv_all.has(MapData.Tile.WATER),
		"Inventar zeigt genau Gras, Sand, Wasser")
	var bar_types: Array = BuildBar.DEFAULT_TYPES
	_check(bar_types.size() == 3, "Bau-Leiste hat drei Felder")
	var mini_colors: Dictionary = preload("res://src/ui/minimap.gd").COLORS
	_check(mini_colors.size() == 3, "Minimap kennt drei Farben")

	# Keine Quelltextstelle darf noch einen entfernten Bodentyp nennen.
	var stale := _grep_sources(["Tile.MEADOW", "Tile.FOREST", "Tile.PATH",
		"Tile.COBBLE", "Tile.ROCK", "Tile.DEEP_WATER", "EMPTY_WORLD",
		"level_at", "LAYER_SHADOW", "PropArt", "Layout"])
	_check(stale.is_empty(), "Keine Reste entfernter Bodentypen im Quelltext%s"
		% ("" if stale.is_empty() else " (%s)" % ", ".join(stale)))
	await get_tree().process_frame

## Sucht Wörter in allen .gd-Dateien unter res://src — ohne diese Datei selbst.
func _grep_sources(words: Array) -> Array[String]:
	var hits: Array[String] = []
	for file: String in _gd_files("res://src"):
		if file.ends_with("self_test.gd"):
			continue
		var text := FileAccess.get_file_as_string(file)
		for w: String in words:
			if text.contains(w):
				hits.append("%s: %s" % [file.get_file(), w])
	return hits

func _gd_files(path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out

# --- Kachelsatz und Kachelraster ---------------------------------------------

## Die Technik hinter den Kacheln, nicht ihr Aussehen.
##
## Geprüft wird, was ein verrutschtes Bild überhaupt erst möglich macht:
## Kachelgröße, Atlasbereiche, angelegte Kacheln, Ursprung, Transformationen
## der Schichten, Reihenfolge der Z-Werte und die Umrechnung von Feld auf
## Weltkoordinate. Stimmt hier etwas nicht, liegt eine Kachel neben ihrem Feld.
func _check_tileset(world: Node2D, map: MapData, player: Player) -> void:
	var st: ChunkStreamer = world.streamer
	var ts: TileSet = st.ground.tileset
	var T := Config.TILE

	_check(ts.tile_size == Vector2i(T, T), "Kachelgröße im Kachelsatz ist %d × %d" % [T, T])
	_check(ts.get_source_count() == GroundTileSet.STACK.size() + 1,
		"Genau %d Atlasquellen: drei Böden und die Kanten (%d)"
		% [GroundTileSet.STACK.size() + 1, ts.get_source_count()])

	# Jede Quelle: Textur da, Bereichsgröße genau eine Kachel, Kacheln angelegt.
	var bad_src: Array[String] = []
	var bad_origin := 0
	var tiles_total := 0
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			bad_src.append("Quelle %d ist kein Atlas" % sid)
			continue
		if src.texture == null or src.texture.get_width() <= 0:
			bad_src.append("Quelle %d ohne Textur" % sid)
		if src.texture_region_size != Vector2i(T, T):
			bad_src.append("Quelle %d: Bereich %s" % [sid, src.texture_region_size])
		if src.get_tiles_count() == 0:
			bad_src.append("Quelle %d hat keine Kacheln" % sid)
		for k in src.get_tiles_count():
			var coords := src.get_tile_id(k)
			tiles_total += 1
			# Der Bereich muss ganz in der Textur liegen — sonst zieht die
			# Kachel Pixel ihrer Nachbarin mit herein.
			var r := src.get_tile_texture_region(coords)
			if r.position.x < 0 or r.position.y < 0 \
					or r.end.x > src.texture.get_width() \
					or r.end.y > src.texture.get_height() \
					or r.size != Vector2i(T, T):
				bad_src.append("Quelle %d Kachel %s: Bereich %s" % [sid, coords, r])
			var td := src.get_tile_data(coords, 0)
			if td.texture_origin != Vector2i.ZERO:
				bad_origin += 1
	_check(bad_src.is_empty(), "Alle Atlasquellen sind sauber aufgebaut (%d Kacheln)%s"
		% [tiles_total, "" if bad_src.is_empty() else " — " + ", ".join(bad_src)])
	_check(bad_origin == 0,
		"Keine Kachel hat einen Versatz gegen ihr Feld (%d abweichend)" % bad_origin)

	# Die Schichten selbst: kein Versatz, keine Skalierung, gemeinsamer Satz.
	_check(st.layers.size() == GroundTileSet.LAYER_COUNT,
		"Vier Kachelschichten liegen an (%d)" % st.layers.size())
	_check(st.position == Vector2.ZERO and st.scale == Vector2.ONE
		and is_zero_approx(st.rotation),
		"Der Kachelknoten selbst ist unverschoben und unskaliert")
	var moved: Array[String] = []
	var last_z := -9999
	var z_ok := true
	for i in st.layers.size():
		var l: TileMapLayer = st.layers[i]
		if l.position != Vector2.ZERO or l.scale != Vector2.ONE or not is_zero_approx(l.rotation):
			moved.append(l.name)
		if l.tile_set != ts:
			moved.append("%s: fremder Kachelsatz" % l.name)
		if l.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			moved.append("%s: weicher Filter" % l.name)
		if l.z_index <= last_z:
			z_ok = false
		last_z = l.z_index
	_check(moved.is_empty(), "Alle Schichten liegen deckungsgleich auf dem Raster%s"
		% ("" if moved.is_empty() else " (%s)" % ", ".join(moved)))
	_check(z_ok, "Die Schichten liegen in aufsteigender Reihenfolge übereinander")

	# Feld -> Weltkoordinate: die Kachel sitzt genau auf ihrem Block.
	var probe := GridOverlay.block_at(player.global_position)
	var mid: Vector2 = st.layers[0].map_to_local(probe)
	_check(mid.is_equal_approx(Vector2(probe) * T + Vector2(T, T) * 0.5),
		"Feld %d|%d liegt bei %s — genau auf dem Raster" % [probe.x, probe.y, mid])
	_check(st.layers[0].to_global(st.layers[0].map_to_local(probe))
		.is_equal_approx(Vector2(probe) * T + Vector2(T, T) * 0.5),
		"Auch in Weltkoordinaten sitzt die Kachel auf dem Block")

	# Jede gesetzte Zelle zeigt auf eine Kachel, die es wirklich gibt.
	var ghosts := 0
	var checked := 0
	for i in st.layers.size():
		var l: TileMapLayer = st.layers[i]
		for cell: Vector2i in l.get_used_cells():
			checked += 1
			if checked % 97 != 0:
				continue          # Stichprobe: 4,2 Mio Zellen wären zu viel
			var sid := l.get_cell_source_id(cell)
			var src := ts.get_source(sid) as TileSetAtlasSource
			if src == null or not src.has_tile(l.get_cell_atlas_coords(cell)):
				ghosts += 1
	_check(ghosts == 0, "Keine Zelle zeigt auf eine unbekannte Kachel (%d geprüft)"
		% (checked / 97))

	# Die Grundschicht deckt jedes geladene Feld — sonst blitzt Hintergrund durch.
	var want := (2 * Config.LOAD_RADIUS + 1) * (2 * Config.LOAD_RADIUS + 1)
	_check(st.layers[0].get_used_cells().size() == want * Config.CHUNK * Config.CHUNK,
		"Grundschicht deckt jedes geladene Feld (%d)" % st.layers[0].get_used_cells().size())
	await get_tree().process_frame

## Sind die Bodenkacheln nahtlos?
##
## Gemessen, nicht behauptet: verglichen wird der mittlere Farbunterschied an
## der Naht (letzte Spalte gegen erste Spalte, letzte Zeile gegen erste Zeile)
## mit dem Unterschied zweier benachbarter Spalten IM Kachelinneren. Bei einer
## nahtlosen Kachel sind beide Werte ähnlich; ein Bruch an der Naht sticht als
## Vielfaches heraus.
func _check_seams() -> void:
	var before := TileArt.new()
	Pixel.wrap = 0
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = Config.WORLD_SEED
	before._build_bases_raw(rng_b)

	var art := TileArt.build(Config.WORLD_SEED)
	var worst := 0.0
	var worst_name := ""
	print("Kachelnähte (1,0 = so glatt wie das Kachelinnere):")
	for t in MapData.Tile.COUNT:
		var img_after: Image = art.base[t][TileArt.VARIANTS]
		var img_before: Image = before.base[t][TileArt.VARIANTS]
		var r_after := _seam_ratio(img_after)
		var r_before := _seam_ratio(img_before)
		print("  %-12s vorher %.2f   nachher %.2f" % [
			GroundTileSet.NAMES[t], r_before, r_after])
		if r_after > worst:
			worst = r_after
			worst_name = GroundTileSet.NAMES[t]
	# 1,6 lässt Luft für Zufall bei nur 32 Pixeln Kantenlänge, schlägt aber bei
	# einem echten Bruch (dort lagen die Werte bei 3 bis 8) sicher an.
	_check(worst < 1.6, "Alle Bodenkacheln sind nahtlos (schlechteste: %s %.2f)"
		% [worst_name, worst])
	await get_tree().process_frame

## Naht-Unterschied geteilt durch Innen-Unterschied.
func _seam_ratio(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var seam := 0.0
	for y in h:
		seam += _diff(img.get_pixel(w - 1, y), img.get_pixel(0, y))
	for x in w:
		seam += _diff(img.get_pixel(x, h - 1), img.get_pixel(x, 0))
	seam /= float(w + h)

	var inner := 0.0
	var n := 0
	for y in h:
		for x in range(1, w):
			inner += _diff(img.get_pixel(x - 1, y), img.get_pixel(x, y))
			n += 1
	for x in w:
		for y in range(1, h):
			inner += _diff(img.get_pixel(x, y - 1), img.get_pixel(x, y))
			n += 1
	inner /= maxf(float(n), 1.0)
	return seam / maxf(inner, 0.0001)

static func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

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

# --- Bauen --------------------------------------------------------------------

## Das Bauwerkzeug auf dem Raster: einzelne Blöcke, Nachbarschaft in alle acht
## Richtungen, Reihen, schnelles Ziehen, Bauen in Bewegung.
func _check_building(world: Node2D, map: MapData, player: Player) -> void:
	var tool: BuildTool = world.build_tool
	_check(tool != null and world.build_bar != null, "Bau-Leiste vorhanden")
	if tool == null:
		return
	var sand: TileMapLayer = world.streamer.layers[1]
	var full_start := TerrainAtlas.FULL_START
	var home := GridOverlay.block_at(player.global_position)

	# Der Fehler aus dem Foto: einzelne Blöcke wurden Kleckse.
	var solo := home + Vector2i(-10, -8)
	tool.place(solo, MapData.Tile.SAND)
	await _frames(2)
	var a_solo := sand.get_cell_atlas_coords(solo)
	_check(a_solo.x + a_solo.y * TerrainAtlas.COLS >= full_start,
		"Einzelner Block ist eine Vollkachel, kein Klecks")
	_check(sand.get_cell_source_id(solo + Vector2i(1, 0)) != -1,
		"Nachbarfeld bekommt den Saum")

	# Ein Klick setzt genau ein Feld — und zwar das unter dem Zeiger.
	var quick := home + Vector2i(-10, -10)
	var neighbours_before := _count_of(map, quick, MapData.Tile.SAND)
	tool.place(quick, MapData.Tile.SAND)
	await _frames(2)
	_check(map.get_tile(quick.x, quick.y) == MapData.Tile.SAND
		and _count_of(map, quick, MapData.Tile.SAND) == neighbours_before,
		"Ein Klick setzt genau ein Feld, kein Nachbarfeld")

	# Alle acht Richtungen an ein bestehendes Feld anbauen.
	var seed_cell := home + Vector2i(-14, -2)
	tool.place(seed_cell, MapData.Tile.SAND)
	var missing: Array[String] = []
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		tool.place(seed_cell + o, MapData.Tile.SAND)
		if map.get_tile(seed_cell.x + o.x, seed_cell.y + o.y) != MapData.Tile.SAND:
			missing.append(str(o))
	await _frames(2)
	_check(missing.is_empty(), "Anbauen in alle acht Richtungen%s"
		% ("" if missing.is_empty() else " (fehlt: %s)" % ", ".join(missing)))

	# Jede Materialkombination nebeneinander: Gras an Sand, Sand an Wasser, …
	var pair := home + Vector2i(-18, -12)
	var kinds := [MapData.Tile.GRASS, MapData.Tile.SAND, MapData.Tile.WATER]
	var pair_bad: Array[String] = []
	var row := 0
	for a: int in kinds:
		for b: int in kinds:
			var c := pair + Vector2i(0, row)
			tool.place(c, a)
			tool.place(c + Vector2i(1, 0), b)
			await _frames(1)
			if map.get_tile(c.x, c.y) != a or map.get_tile(c.x + 1, c.y) != b:
				pair_bad.append("%s|%s" % [GroundTileSet.NAMES[a], GroundTileSet.NAMES[b]])
			row += 1
	_check(pair_bad.is_empty(), "Alle neun Materialpaare liegen nebeneinander%s"
		% ("" if pair_bad.is_empty() else " (%s)" % ", ".join(pair_bad)))

	# Sechs in einer Reihe: früher zerfiel das in sechs Punkte.
	var rowy := home.y - 5
	for i in 6:
		tool.place(Vector2i(home.x - 10 + i, rowy), MapData.Tile.SAND)
	await _frames(2)
	var all_full := true
	for i in 6:
		var a := sand.get_cell_atlas_coords(Vector2i(home.x - 10 + i, rowy))
		if a.x + a.y * TerrainAtlas.COLS < full_start:
			all_full = false
	_check(all_full, "Reihe aus sechs Blöcken ergibt sechs Vollkacheln")

	# Ziehen über mehrere Felder darf keine Lücke lassen.
	var drag_from := home + Vector2i(-12, 4)
	var drag_to := drag_from + Vector2i(7, 3)
	tool._last = drag_from
	tool.place(drag_from, MapData.Tile.SAND)
	tool._stroke(drag_from, drag_to, MapData.Tile.SAND)
	await _frames(2)
	var gap := false
	var dd := drag_to - drag_from
	for i in 8:
		var c := Vector2i(drag_from.x + int(round(float(dd.x) * i / 7.0)),
			drag_from.y + int(round(float(dd.y) * i / 7.0)))
		if map.get_tile(c.x, c.y) != MapData.Tile.SAND:
			gap = true
	_check(not gap, "Schnelles Ziehen lässt keine Lücke")

	# Ein 3 × 3-Fleck: Mitte voll, Rand Übergang, Saum ringsum.
	var origin := home + Vector2i(12, -12)
	var before := sand.get_used_cells().size()
	for oy in 3:
		for ox in 3:
			tool.place(origin + Vector2i(ox, oy), MapData.Tile.SAND)
	await _frames(2)
	var mid := origin + Vector2i(1, 1)
	_check(map.get_tile(mid.x, mid.y) == MapData.Tile.SAND, "Block gesetzt (Sand)")
	_check(sand.get_used_cells().size() == before + 25,
		"Fläche mit Saum bemalt (%d Zellen)" % (sand.get_used_cells().size() - before))
	_check(sand.get_cell_atlas_coords(mid) != sand.get_cell_atlas_coords(origin),
		"Randkacheln des Flecks sind Übergänge")

	# Zurücksetzen auf Gras: keine Vollkachel mehr, aber der Saum der Nachbarn.
	tool.place(origin, MapData.Tile.GRASS)
	await _frames(2)
	var a_reset := sand.get_cell_atlas_coords(origin)
	_check(a_reset.x + a_reset.y * TerrainAtlas.COLS < full_start,
		"Zurückgesetzter Block ist keine Vollkachel mehr")

	# Die Bauvorschau hängt nicht am Raster.
	var g: GridOverlay = world.grid
	g.show_grid = false
	await _frames(2)
	_check(g.visible and not g.show_grid, "Raster aus, Vorschau bleibt gezeichnet")
	_check(world.build_bar.preview_texture() != null, "Vorschau kennt die gewählte Kachel")
	g.show_grid = true

	# Aufräumen, damit die späteren Prüfungen freies Feld haben.
	for oy in range(-14, 8):
		for ox in range(-20, 10):
			tool.place(home + Vector2i(ox, oy), MapData.Tile.GRASS)
	await _frames(2)

## Wie viele der vier Nachbarfelder tragen diesen Typ?
func _count_of(map: MapData, cell: Vector2i, tile: int) -> int:
	var n := 0
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.get_tile(cell.x + o.x, cell.y + o.y) == tile:
			n += 1
	return n

# --- Wasser und Kollision -----------------------------------------------------

## Wasser, Schwimmen und die Frage aus dem Auftrag: wird die Figur am Wasser
## noch nach oben geschleudert?
##
## Der Fehler lag früher in `lift()`: beim Verlassen einer Felsstufe wurde dem
## Bildversatz die volle Wandhöhe aufgeschlagen. Fels gibt es nicht mehr, und
## `lift()` liefert nur noch die Sprunghöhe. Geprüft wird das aus allen vier
## Richtungen, weil das Verhalten früher richtungsabhängig war.
func _check_water(world: Node2D, map: MapData, player: Player) -> void:
	var tool: BuildTool = world.build_tool
	var home := GridOverlay.block_at(player.global_position)
	var pond := home + Vector2i(10, 10)

	# Ein Teich mit Sandsaum, 6 × 6 Wasser.
	for y in range(-1, 7):
		for x in range(-1, 7):
			tool.place(pond + Vector2i(x, y), MapData.Tile.SAND)
	for y in 6:
		for x in 6:
			tool.place(pond + Vector2i(x, y), MapData.Tile.WATER)
	await _frames(3)
	_check(map.is_swimmable(pond.x + 3, pond.y + 3), "Gesetztes Wasser ist schwimmbar")
	_check(not map.is_solid(pond.x + 3, pond.y + 3), "Wasser hält niemanden auf")

	# An Land wird nicht geschwommen.
	player.position = Vector2(pond.x + 3.5, pond.y - 2.5) * Config.TILE
	player.velocity = Vector2.ZERO
	world.camera.snap_to_target()
	await _frames(4)
	_check(not player.is_swimming(), "An Land wird nicht geschwommen")

	# Aus allen vier Richtungen hinein: nirgends ein Sprung nach oben, nirgends
	# ein Ruck in der Position, überall wird geschwommen.
	var sides := {
		"von Norden": [Vector2(3.5, -2.5), "move_down"],
		"von Süden": [Vector2(3.5, 8.5), "move_up"],
		"von Westen": [Vector2(-2.5, 3.5), "move_right"],
		"von Osten": [Vector2(8.5, 3.5), "move_left"],
	}
	var not_swimming: Array[String] = []
	var flung: Array[String] = []
	var worst_step := 0.0
	var worst_lift := 0.0
	for name: String in sides:
		var off: Vector2 = sides[name][0]
		player.position = (Vector2(pond) + off) * Config.TILE
		player.velocity = Vector2.ZERO
		await _frames(4)
		Input.action_press(sides[name][1])
		var prev := player.position
		var swam := false
		for i in 100:
			await get_tree().physics_frame
			var step := prev.distance_to(player.position)
			worst_step = maxf(worst_step, step)
			worst_lift = maxf(worst_lift, player.lift())
			if step > Config.TILE * 0.5:
				flung.append("%s (%.1f px in einem Bild)" % [name, step])
			prev = player.position
			if player.is_swimming():
				swam = true
		Input.action_release(sides[name][1])
		await _frames(4)
		if not swam:
			not_swimming.append(name)
	_check(not_swimming.is_empty(), "Aus allen vier Richtungen ins Wasser%s"
		% ("" if not_swimming.is_empty() else " (kein Schwimmen: %s)" % ", ".join(not_swimming)))
	_check(flung.is_empty(),
		"Am Wasser wird die Figur nicht geschleudert (grösster Schritt %.1f px)%s"
		% [worst_step, "" if flung.is_empty() else " — " + ", ".join(flung)])
	_check(is_zero_approx(worst_lift),
		"Kein Bildversatz am Ufer — nur der Sprung hebt (%.1f px)" % worst_lift)

	# Im Wasser höchstens Schwimmgeschwindigkeit.
	player.position = (Vector2(pond) + Vector2(3.5, 3.5)) * Config.TILE
	player.velocity = Vector2.ZERO
	await _frames(6)
	_check(player.is_swimming(), "Figur schwimmt im Teich")
	await _drive("move_right", 20)
	_check(player.velocity.length() <= Config.SWIM_SPEED + 1.0,
		"Im Wasser höchstens Schwimmgeschwindigkeit (%.0f)" % player.velocity.length())
	world.camera.snap_to_target()
	world.build_tool.set_process(false)
	world.grid.cursor_block = Vector2i(-1, -1)
	await _frames(8)
	await _shot("08_schwimmen")
	world.build_tool.set_process(true)

	# Sprung ins Wasser: der Sprung wird zu Ende geflogen, erst dann geschwommen.
	player.position = (Vector2(pond) + Vector2(3.5, -1.4)) * Config.TILE
	player.velocity = Vector2.ZERO
	await _frames(4)
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

	# Wieder heraus und den Teich abräumen.
	await _drive("move_up", 80)
	_check(not player.is_swimming(), "Nach dem Verlassen wird wieder gelaufen")

	# An einer Chunk-Grenze entlanglaufen, ohne hängenzubleiben. Die
	# Kollisionsrechtecke der Nachbarchunks überlappen dafür um einen halben
	# Pixel — sonst fängt sich `move_and_slide()` an der stumpfen Innenkante.
	var border := Vector2i((home.x / Config.CHUNK + 1) * Config.CHUNK, home.y + 20)
	player.position = Vector2(border.x - 0.5, border.y - 6.5) * Config.TILE
	player.velocity = Vector2.ZERO
	world.camera.snap_to_target()
	await _frames(6)
	var from_y := player.position.y
	await _drive("move_down", 90)
	var travelled := player.position.y - from_y
	_check(travelled > 90.0,
		"Läuft an der Chunk-Grenze entlang ohne hängenzubleiben (%.0f px)" % travelled)

	var shot_pos := (Vector2(pond) + Vector2(3.0, -4.0)) * Config.TILE
	player.position = shot_pos
	player.velocity = Vector2.ZERO
	world.camera.snap_to_target()
	await _frames(8)
	await _shot("07_bauen")

# --- Inventar und E-Umschalter ------------------------------------------------

## E ist ein echter Umschalter: auf, zu, wieder auf. Und derselbe Tastendruck
## darf nicht gleichzeitig im Spiel landen.
##
## Der Fehler war, dass E im Bauwerkzeug lag. Die Welt ist pausierbar, damit bei
## offenem Fenster nichts mehr in ihr passiert — dadurch bekam das Bauwerkzeug
## bei offenem Inventar gar keine Eingaben mehr und konnte nie wieder
## schliessen. Jetzt liegt der Umschalter in Main, dem einzigen Knoten, der
## immer läuft.
func _check_toggle(world: Node2D, map: MapData, player: Player) -> void:
	var inv: CanvasLayer = world.inventory
	_check(inv != null, "Inventar vorhanden")
	if inv == null:
		return
	_check(inv.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Das Inventar läuft auch bei pausiertem Baum")

	# Dreimal umschalten — über das echte Tastenereignis, nicht über die
	# Hilfsfunktion. Genau daran scheiterte es vorher.
	var seen: Array[String] = []
	for i in 3:
		main._unhandled_input(_key("inventory"))
		# Reichlich Bilder abwarten: das Inventar blendet sich weich ein, und
		# ein Bild mitten in der Einblendung wäre als Beleg wertlos.
		await _frames(14)
		seen.append("offen" if main.state == main.State.INVENTORY else "zu")
	_check(seen == ["offen", "zu", "offen"],
		"E öffnet, E schliesst, E öffnet wieder (%s)" % ", ".join(seen))
	_check(inv.visible and main.state == main.State.INVENTORY, "Inventar ist jetzt offen")

	# Der Tastendruck darf nicht zusätzlich im Spiel ankommen.
	var before := player.position
	var probe := GridOverlay.block_at(player.global_position) + Vector2i(3, 3)
	var tile_before := map.get_tile(probe.x, probe.y)
	await _frames(8)
	_check(player.position == before and map.get_tile(probe.x, probe.y) == tile_before,
		"Bei offenem Inventar passiert in der Welt nichts")

	# Ausrüsten: Feld wählen, Material anklicken.
	inv.select_slot(2)
	var slot_before: int = world.build_bar.types[2]
	var other: int = MapData.Tile.SAND if slot_before != MapData.Tile.SAND else MapData.Tile.WATER
	inv.equip_requested.emit(2, other)
	await _frames(3)
	_check(world.build_bar.types[2] == other,
		"Klick im Inventar rüstet den Typ auf das gewählte Feld")
	world.build_bar.select(2)
	_check(world.build_bar.tile_type() == other, "Die Leiste setzt danach den neuen Typ")
	inv.equip_requested.emit(2, slot_before)
	world.build_bar.select(0)

	# Auch ESC schliesst.
	main._unhandled_input(_key("ui_cancel"))
	await _frames(3)
	_check(main.state == main.State.PLAYING and not inv.visible, "ESC schliesst das Inventar")

# --- Inventar als Oberfläche ---------------------------------------------------

## Das Inventar als Oberfläche, nicht als Entwicklerfenster.
##
## Vorher standen hier zwei Erklärsätze, die Auswahl war eine dünne gelbe Linie,
## die Vorschaubilder waren in ein Rechteck gestreckt, und die Leiste im
## Inventar sah anders aus als die echte. Jeder dieser Punkte hat hier eine
## Prüfung bekommen, damit er nicht zurückkommt.
func _check_inventory_ui(world: Node2D) -> void:
	var inv: Inventory = world.inventory
	var bar: BuildBar = world.build_bar
	if inv == null or bar == null:
		return
	main.open_inventory()
	await _frames(14)

	# 1. Bilder, die nicht verzerren können.
	#
	#    Das Materialbild wird 1:1 gezeichnet. Damit das aufgeht, muss seine
	#    Kantenlänge ein ganzes Vielfaches der Weltkachel sein — eine 32er
	#    Kachel in ein 48er Feld gestreckt macht manche Bildpunkte zwei breit.
	_check(TileIcon.SIZE % Config.TILE == 0 and TileIcon.SIZE > Config.TILE,
		"Materialbild ist ein ganzes Vielfaches der Kachel (%d px)" % TileIcon.SIZE)
	_check(bar.icons.size() == MapData.Tile.COUNT,
		"Ein Materialbild je Bodentyp (%d)" % bar.icons.size())
	var square := true
	for tex: Texture2D in bar.icons:
		if tex == null or tex.get_width() != TileIcon.SIZE \
				or tex.get_height() != TileIcon.SIZE:
			square = false
	_check(square, "Jedes Materialbild ist quadratisch und unverzerrt")

	# 2. Gleiche Felder, gleichmässige Abstände.
	var cards: Array[ItemSlot] = []
	var row: Array[ItemSlot] = []
	for slot: ItemSlot in _item_slots(inv):
		if slot.kind == ItemSlot.Kind.CARD:
			cards.append(slot)
		else:
			row.append(slot)
	_check(cards.size() == 3 and row.size() == 3,
		"Drei Materialfelder und drei Leistenfelder (%d / %d)" % [cards.size(), row.size()])
	_even_row(cards, "Materialfelder")
	_even_row(row, "Leistenfelder im Inventar")
	_even_row(_item_slots(bar), "Leistenfelder im Spiel")
	_check(not row.is_empty() and not _item_slots(bar).is_empty()
		and row[0].size == _item_slots(bar)[0].size,
		"Die Leiste sieht im Inventar aus wie im Spiel")

	# 3. Die Auswahl ist eindeutig — nicht nur eine dünne Linie.
	inv.select_slot(0)
	await _frames(14)
	var lit := 0
	for slot: ItemSlot in row:
		if slot.selected:
			lit += 1
	_check(lit == 1, "Genau ein Feld der Leiste ist gewählt (%d)" % lit)
	var chosen := row[0]
	var other := row[1]
	_check(chosen.highlight_strength() > 0.9 and other.highlight_strength() < 0.1,
		"Das gewählte Feld ist voll hervorgehoben, die anderen nicht")
	var hot := chosen.frame_style()
	var cold := other.frame_style()
	_check(hot.border_width_left > cold.border_width_left and hot.shadow_size > 0
		and cold.shadow_size == 0,
		"Gewählt heisst kräftigerer Rahmen UND Schein, nicht nur eine Linie")
	_check(hot.bg_color != cold.bg_color, "Auch die Fläche des gewählten Feldes ist anders")

	# 4. Überfahren hebt ein Feld sichtbar ab — und lässt es wieder los.
	var probe := cards[1]
	_hover_at(probe.get_global_rect().get_center())
	await _frames(14)
	_check(probe.hover_strength() > 0.9,
		"Ein Feld hebt sich beim Überfahren ab (%.2f)" % probe.hover_strength())
	_check(probe.frame_style().bg_color != cards[2].frame_style().bg_color,
		"Das überfahrene Feld sieht anders aus als seine Nachbarn")
	# Genau jetzt zeigt ein Bild alle drei Zustände auf einmal: Gras gewählt,
	# Sand überfahren, Wasser ruhig. Deshalb entsteht es hier und nicht beim
	# Öffnen.
	await _shot("09_inventar")
	_hover_at(Vector2(4, 4))
	await _frames(14)
	_check(probe.hover_strength() < 0.1, "Und fällt danach wieder zurück")

	# 5. Kein Erklärtext mehr. Übrig sind Überschrift, Zwischenüberschrift und
	#    der eine Hinweis, wie man wieder herauskommt.
	var texts: Array[String] = []
	for l: Label in _labels(inv):
		if l.text.strip_edges() != "":
			texts.append(l.text)
	var longest := 0
	for t: String in texts:
		longest = maxi(longest, t.length())
	_check(texts.size() <= 3 and longest <= 20,
		"Kaum noch Text im Inventar (%d Zeilen, längste %d Zeichen: %s)"
		% [texts.size(), longest, ", ".join(texts)])

	# 6. Nichts kann eine Eingabe durchlassen: kein Feld nimmt den Tastaturfokus,
	#    jedes fängt seinen Mausklick selbst ab.
	var leaky: Array[String] = []
	for slot: ItemSlot in _item_slots(inv) + _item_slots(bar):
		if slot.focus_mode != Control.FOCUS_NONE:
			leaky.append("Fokus")
		if slot.mouse_filter != Control.MOUSE_FILTER_STOP:
			leaky.append("Mausfilter")
	_check(leaky.is_empty(), "Kein Feld lässt eine Eingabe durch%s"
		% ("" if leaky.is_empty() else " (%s)" % ", ".join(leaky)))

	# 7. Inventar und Leiste sind getrennte Ansichten: nie beide zugleich.
	_check(inv.visible and not bar.visible,
		"Bei offenem Inventar ist die Leiste im Spiel nicht zusätzlich zu sehen")

	# 8. Testplan 6 – 8: jedes der drei Materialien lässt sich wählen.
	var saved: Array = bar.loadout()
	for tile: int in [MapData.Tile.GRASS, MapData.Tile.SAND, MapData.Tile.WATER]:
		inv.select_slot(0)
		inv.equip_requested.emit(0, tile)
		await _frames(2)
		_check(bar.types[0] == tile and bar.tile_type() == tile,
			"%s im Inventar gewählt — %s ist aktiv" % [MapData.NAMES[tile], MapData.NAMES[tile]])
	bar.set_loadout(saved)
	await _frames(2)

	# 9. Testplan 9: über die Leiste gewechselt kommt dasselbe Material heraus.
	var wrong: Array[String] = []
	for i in bar.types.size():
		bar.slot_clicked.emit(i)
		await _frames(2)
		if bar.selected != i or bar.tile_type() != bar.types[i]:
			wrong.append(str(i + 1))
	_check(wrong.is_empty(), "Ein Klick auf ein Feld der Leiste wählt genau dessen Material%s"
		% ("" if wrong.is_empty() else " (Feld %s)" % ", ".join(wrong)))
	bar.select(0)

	# 10. Der Umschalter greift nur da, wo er soll. In der Pause tut E nichts —
	#    und meldet das auch, damit die Taste nicht stillschweigend verschwindet.
	main.close_inventory()
	await _frames(3)
	main.pause_game()
	await _frames(3)
	_check(not main.toggle_inventory() and main.state == main.State.PAUSED,
		"E öffnet das Inventar nicht aus der Pause heraus")
	main.resume_game()
	await _frames(3)
	_check(main.state == main.State.PLAYING and not inv.visible,
		"Danach läuft das Spiel wieder, das Inventar bleibt zu")

## Gleich groß und gleich weit auseinander — sonst wirkt eine Reihe gebastelt.
func _even_row(list: Array, what: String) -> void:
	if list.size() < 2:
		_check(false, "%s: zu wenige Felder zum Vergleichen" % what)
		return
	var same := true
	var gaps: Array[float] = []
	for i in list.size():
		if list[i].size != list[0].size:
			same = false
		if i > 0:
			gaps.append(list[i].position.x - (list[i - 1].position.x + list[i - 1].size.x))
	var even := true
	for g: float in gaps:
		if absf(g - gaps[0]) > 0.5:
			even = false
	_check(same, "%s: alle gleich groß (%s)" % [what, list[0].size])
	_check(even, "%s: gleichmäßige Abstände (%.0f px)" % [what, gaps[0]])

## Schiebt den Mauszeiger auf einen Punkt, damit sich der Überfahren-Zustand
## prüfen lässt.
func _hover_at(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	get_viewport().push_input(motion)

func _item_slots(node: Node) -> Array[ItemSlot]:
	var out: Array[ItemSlot] = []
	if node is ItemSlot:
		out.append(node)
	for child: Node in node.get_children():
		out.append_array(_item_slots(child))
	return out

func _labels(node: Node) -> Array[Label]:
	var out: Array[Label] = []
	if node is Label:
		out.append(node)
	for child: Node in node.get_children():
		out.append_array(_labels(child))
	return out

## Kein Durchsickern von Eingaben zwischen Oberfläche und Spiel.
##
## Der Fehler war: Main setzt für sich PROCESS_MODE_ALWAYS, die Welt hing als
## Kind darunter und erbte das. get_tree().paused hatte auf sie keine Wirkung,
## und das Bauwerkzeug fragte den rohen Maustastenzustand ab — ein Klick auf
## „Fortsetzen" setzte damit gleich einen Block.
func _check_input_lock(world: Node2D, map: MapData, player: Player) -> void:
	var tool: BuildTool = world.build_tool
	_check(world.process_mode == Node.PROCESS_MODE_PAUSABLE, "Die Welt ist pausierbar")

	var probe := GridOverlay.block_at(player.global_position) + Vector2i(4, 4)
	tool.place(probe, MapData.Tile.GRASS)
	await _frames(2)

	for entry: Array in [["Pause", main.State.PAUSED],
			["Optionen", main.State.OPTIONS],
			["Inventar", main.State.INVENTORY]]:
		if entry[1] == main.State.PAUSED:
			main.pause_game()
		elif entry[1] == main.State.OPTIONS:
			main.pause_game()
			main.open_options()
		else:
			main.toggle_inventory()
		await _frames(3)

		var pos_before := player.position
		var tile_before := map.get_tile(probe.x, probe.y)
		# Maustaste UND Laufrichtung gedrückt halten — genau die Lage, in der
		# vorher gebaut und gelaufen wurde.
		Input.action_press("move_right")
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		tool._unhandled_input(press)
		await _frames(12)
		Input.action_release("move_right")

		_check(map.get_tile(probe.x, probe.y) == tile_before,
			"%s: kein Block wird gesetzt" % entry[0])
		_check(player.position == pos_before, "%s: die Figur bewegt sich nicht" % entry[0])
		_check(world.grid.cursor_block.x < 0, "%s: keine Bauvorschau" % entry[0])

		if entry[1] == main.State.PAUSED:
			main.resume_game()
		elif entry[1] == main.State.OPTIONS:
			main.close_options()
			main.resume_game()
		else:
			main.toggle_inventory()
		await _frames(4)

	# Der Klick auf „Fortsetzen“ selbst darf nichts setzen: er geht an die
	# Schaltfläche, die Welt ist noch pausiert.
	main.pause_game()
	await _frames(3)
	var before_resume := map.get_tile(probe.x, probe.y)
	main._pause_menu.resume_pressed.emit()
	await _frames(6)
	_check(main.state == main.State.PLAYING, "Fortsetzen setzt das Spiel fort")
	_check(map.get_tile(probe.x, probe.y) == before_resume,
		"Fortsetzen setzt keinen Block")

	# Nach dem Schliessen läuft alles wieder — aber die noch gedrückte Taste
	# malt nicht weiter.
	var after := map.get_tile(probe.x, probe.y)
	await _frames(8)
	_check(map.get_tile(probe.x, probe.y) == after,
		"Eine noch gehaltene Maustaste baut nicht weiter")

## Eingaben zentral, Steuerungsübersicht ehrlich, Anzeigen wie verlangt.
func _check_input_map(world: Node2D) -> void:
	# 1. Jede Aktion der Übersicht existiert wirklich und hat eine Taste.
	var missing: Array[String] = []
	for entry: Array in Config.CONTROL_ROWS:
		for one: String in String(entry[0]).split("+"):
			if not InputMap.has_action(one) or Config.keys_for(one) == "—":
				missing.append(one)
	_check(missing.is_empty(),
		"Steuerungsübersicht zeigt nur Aktionen, die es gibt%s"
		% ("" if missing.is_empty() else " (fehlt: %s)" % ", ".join(missing)))

	# 2. Die Tasten stimmen mit der tatsächlichen Belegung überein.
	_check(Config.keys_for("inventory") == "E", "E öffnet das Inventar")
	_check(Config.keys_for("toggle_grid") == "G", "G schaltet das Raster")
	_check(Config.keys_for("build_place") == "Linke Maustaste", "Links setzt")
	_check(Config.keys_for("build_remove") == "Rechte Maustaste", "Rechts entfernt")
	_check(Config.keys_for("build_slot_3") == "3", "Feld 3 liegt auf der 3")
	_check(not InputMap.has_action("build_slot_4"),
		"Es gibt nur drei Materialtasten")
	_check(Config.keys_for("save_map") == "F5", "F5 speichert")
	_check(Config.keys_for("move_up+move_left+move_down+move_right") == "W A S D",
		"Bewegung steht als eine Zeile: W A S D")

	# 3. Keine hartcodierte Taste mehr im Bauwerkzeug.
	var src := FileAccess.get_file_as_string("res://src/world/build_tool.gd")
	_check(not src.contains("KEY_1") and not src.contains("KEY_F5"),
		"Das Bauwerkzeug kennt keine Tastencodes mehr")

	# 4. Leistungsanzeige: beim Start aus, einschaltbar, echte Zahlen.
	var perf: Control = world.hud.perf
	_check(perf != null and not perf.visible and not Settings.show_perf,
		"Leistungsanzeige startet ausgeschaltet")
	Settings.show_perf = true
	Settings.changed.emit()
	await _frames(3)
	perf.refresh()
	_check(perf.visible, "Leistungsanzeige lässt sich einschalten")
	var text: String = perf._label.text
	_check(text.contains("FPS") and text.contains("Speicher")
		and text.contains("CPU Render") and text.contains("GPU Render"),
		"Leistungsanzeige nennt FPS, Speicher und beide Renderzeiten")
	_check(not text.contains("%"), "Keine erfundene Prozentanzeige")
	_check(OS.get_static_memory_usage() > 0 and Engine.get_frames_per_second() >= 0,
		"Speicher und FPS liefern echte Werte (%s)" % [OS.get_static_memory_usage()])
	Settings.show_perf = false
	Settings.changed.emit()
	await _frames(2)
	_check(not perf.visible, "Leistungsanzeige lässt sich wieder ausschalten")

	# 5. Entwicklerinfo ist etwas anderes und liegt auf F3.
	var dbg: Control = world.hud.debug
	_check(dbg != null and not dbg.visible, "Entwicklerinfo startet ausgeschaltet")
	dbg._unhandled_input(_key("debug_info"))
	await _frames(3)
	_check(dbg.visible and dbg._label.text.contains("Chunk")
		and dbg._label.text.contains("Boden"),
		"F3 zeigt Chunk, Feld, Boden und Zustand")
	_check(not dbg._label.text.contains("Höhenstufe"),
		"Keine Höhenstufe mehr in der Entwicklerinfo")
	Settings.show_perf = true
	Settings.changed.emit()
	await _frames(6)
	await _shot("11_anzeigen")
	Settings.show_perf = false
	Settings.changed.emit()
	dbg._unhandled_input(_key("debug_info"))
	await _frames(2)

	# 6. Eigene Tasten für Minimap und Anzeige.
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

	# 7. Die Minimap zeigt, was unter der Figur liegt.
	var mini: Control = world.hud.minimap
	if mini != null:
		mini.refresh()
		await _frames(2)
		var p: Node2D = world.player
		var m: MapData = world.map
		var under := m.get_tile(
			int(p.position.x) / Config.TILE, int(p.position.y) / Config.TILE)
		var img: Image = mini._img
		_check(img.get_width() > 0 and img.get_height() > 0,
			"Minimap-Bild ist %d × %d" % [img.get_width(), img.get_height()])
		var center_px := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		_check(center_px.is_equal_approx(mini.color_of(under)),
			"Mittelpunkt der Minimap zeigt den Boden unter der Figur")

## Alles zusammen, schnell hintereinander: Setzen, Abbauen, Bauen in Bewegung.
func _check_stress(world: Node2D, map: MapData, player: Player) -> void:
	var tool: BuildTool = world.build_tool
	var home := GridOverlay.block_at(player.global_position)
	var field := home + Vector2i(-20, -14)

	# 40 Setzungen so schnell wie möglich, abwechselnd alle drei Typen.
	var kinds := [MapData.Tile.SAND, MapData.Tile.WATER, MapData.Tile.GRASS]
	for i in 40:
		tool.place(field + Vector2i(i % 8, i / 8), kinds[i % kinds.size()])
	await _frames(2)
	var wrong := 0
	for i in 40:
		var c := field + Vector2i(i % 8, i / 8)
		if map.get_tile(c.x, c.y) != kinds[i % kinds.size()]:
			wrong += 1
	_check(wrong == 0, "40 schnelle Setzungen landen alle richtig (%d falsch)" % wrong)

	# Wieder abbauen — jedes Feld muss zurück auf Gras.
	for i in 40:
		tool.place(field + Vector2i(i % 8, i / 8), MapData.Tile.GRASS)
	await _frames(2)
	var left := 0
	for i in 40:
		var c := field + Vector2i(i % 8, i / 8)
		if map.get_tile(c.x, c.y) != MapData.Tile.GRASS:
			left += 1
	_check(left == 0, "Abbauen räumt alle 40 Felder (%d übrig)" % left)

	# Bauen WÄHREND der Bewegung und im Sprung.
	player.position = Vector2(field.x + 2.5, field.y + 6.5) * Config.TILE
	player.velocity = Vector2.ZERO
	world.camera.snap_to_target()
	await _frames(4)
	Input.action_press("move_right")
	Input.action_press("jump")
	var built: Array[Vector2i] = []
	for i in 24:
		await get_tree().physics_frame
		var c := GridOverlay.block_at(player.global_position) + Vector2i(0, 3)
		tool.place(c, MapData.Tile.SAND)
		built.append(c)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _frames(3)
	var missed := 0
	for c: Vector2i in built:
		if map.get_tile(c.x, c.y) != MapData.Tile.SAND:
			missed += 1
	_check(missed == 0, "Bauen während Laufen und Sprung trifft (%d daneben)" % missed)

	# Ein Block unter den eigenen Füssen darf die Figur nicht wegschleudern.
	var under := GridOverlay.block_at(player.global_position)
	var pos_before := player.position
	tool.place(under, MapData.Tile.WATER)
	await _frames(10)
	_check(player.position.distance_to(pos_before) < Config.TILE,
		"Ein Block unter der Figur schleudert sie nicht weg (%.1f px)"
		% player.position.distance_to(pos_before))
	tool.place(under, MapData.Tile.GRASS)

	for c: Vector2i in built:
		tool.place(c, MapData.Tile.GRASS)
	await _frames(2)

## Chunk-Laden: die Welt kommt und geht um die Figur herum.
func _check_streaming(world: Node2D, player: Player) -> void:
	var st: ChunkStreamer = world.streamer
	var want := (2 * Config.LOAD_RADIUS + 1) * (2 * Config.LOAD_RADIUS + 1)
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
	world.camera.snap_to_target()
	var loads_before := st.loads
	await _frames(40)
	_check(not st.is_loaded(here), "Alte Chunks sind entladen")
	_check(st.is_loaded(far), "Chunk am neuen Ort ist geladen")
	_check(st.loaded_count() == want, "Wieder %d Chunks geladen (%d)" % [want, st.loaded_count()])
	_check(st.layers[0].get_used_cells().size() == cells,
		"Zellzahl bleibt begrenzt (%d)" % st.layers[0].get_used_cells().size())
	_check(st.loads - loads_before == want and st.unloads >= want,
		"Genau %d nachgeladen, %d entladen" % [st.loads - loads_before, st.unloads])

	# Keine Kollisionsform ohne festes Feld: alte Formen entfernter Blöcke
	# dürfen nicht als unsichtbare Wand zurückbleiben.
	var ghost := 0
	for child in st.body.get_children():
		var cs := child as CollisionShape2D
		if cs == null:
			continue
		var c := GridOverlay.block_at(cs.position)
		if not world.map.is_solid(c.x, c.y):
			ghost += 1
	_check(ghost == 0, "Keine Kollisionsform ohne festes Feld (%d verwaist)" % ghost)

## Ton: die Musik läuft, Klangeffekte gibt es nicht mehr.
func _check_audio() -> void:
	_check(Audio._music.has("world") and Audio._music["world"].data.size() > 1000,
		"Weltmusik erzeugt und geloopt")
	_check(Audio._music_player != null and Audio._music_player.stream != null,
		"Der Musikspieler hat eine Spur")
	Audio.play_music("menu")
	await _frames(2)
	_check(Audio._music.has("menu"), "Menümusik lässt sich abspielen")
	Audio.play_music("world")
	await _frames(2)

	# Keine Effektschnittstelle mehr — weder im Ton noch an einer Aufrufstelle.
	_check(not Audio.has_method("play_ui") and not Audio.has_method("play_step"),
		"Keine Effektschnittstelle mehr im Ton")
	var callers := _grep_sources(["play_ui", "play_step", "sfx_volume"])
	_check(callers.is_empty(), "Keine Aufrufe von Klangeffekten mehr%s"
		% ("" if callers.is_empty() else " (%s)" % ", ".join(callers)))
	_check(not ("sfx_volume" in Settings), "Keine Effektlautstärke in den Einstellungen")

## Leistung: gemessen, nicht behauptet.
func _check_performance(world: Node2D, map: MapData, player: Player, ms_menu: float) -> void:
	# Aufwärmen. Gemessen wurde: das allererste Messfenster nach dem Betreten
	# der Welt lag bei 849 ms, das zweite schon bei 2,5 — Shader-Übersetzung
	# und Texturuploads, kein Dauerzustand.
	await _frames(90)

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
	# Gemessen wird auf einem Software-Rasterizer (Xvfb/llvmpipe). Die
	# Prozesszeit hängt dort an der Füllrate und schwankt zwischen Läufen um
	# mehr als das Doppelte — sie wird berichtet, aber nicht bewertet.
	print("Aufschlag der Spielwelt gegenüber dem Menü: %.2f ms (Software-Rasterizer, nur Bericht)"
		% (ms_still - ms_menu))
	var avg_draws := int(draws / runs)
	_check(avg_draws < 120, "Zeichenaufrufe bleiben gebündelt (%d)" % avg_draws)
	_check(ms_physics < 8.0, "Physikzeit pro Bild unter 8 ms (%.2f)" % ms_physics)

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

# --- Hilfsmittel --------------------------------------------------------------

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
	var src := InputMap.action_get_events(action)[0] as InputEventKey
	# Beides übernehmen: eigene Aktionen liegen als physischer Code vor, die
	# eingebaute ui_cancel dagegen als keycode. Nur eines von beidem zu kopieren
	# ergab ein Ereignis, das zu gar nichts passte.
	ev.physical_keycode = src.physical_keycode
	ev.keycode = src.keycode
	ev.pressed = true
	return ev

func _drive(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(2)
