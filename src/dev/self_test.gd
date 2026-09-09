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
var _settings_backup := PackedByteArray()
var _had_settings := false
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

## Bild ablegen — aber erst, wenn nichts mehr in Bewegung ist.
##
## Menüs und Felder blenden weich ein. Ein Bild mitten in der Einblendung zeigt
## halbe Deckkraft und halbe Abdunkelung und taugt weder als Beleg noch für die
## Dokumentation. Deshalb wartet JEDES Bild hier ab, statt an jeder Aufrufstelle
## einzeln daran denken zu müssen.
func _shot(name: String) -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(14)
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
	# Der Lauf startet auf einem BEKANNTEN Stand.
	#
	# Vorher erbte er die Einstellungen des letzten Laufs aus der
	# settings.cfg — und ein früherer Lauf hatte dort den Staub auf 0 stehen
	# lassen. Die Prüfung „Mit Staub rechnet er wieder" schlug seitdem in jedem
	# Lauf fehl, ohne dass sich am Code etwas geändert hätte. Ein Test, dessen
	# Ergebnis vom letzten Test abhängt, prüft nicht mehr den Code.
	if FileAccess.file_exists(Settings.PATH):
		_settings_backup = FileAccess.get_file_as_bytes(Settings.PATH)
		_had_settings = true
	# Die Werte kommen aus einer FRISCHEN Instanz derselben Datei. Damit steht
	# hier keine zweite Liste, die irgendwann von den echten Vorgaben abweicht:
	# ändert jemand eine Voreinstellung, ändert sich der Teststart mit.
	var fresh_settings: Node = load("res://src/core/settings.gd").new()
	for key: String in ["render_range", "water_detail", "wind", "particles",
			"decor", "shadows", "light", "day_cycle", "zoom", "fps_limit",
			"vsync", "show_perf", "show_hints", "music_volume"]:
		Settings.set(key, fresh_settings.get(key))
	fresh_settings.free()
	# Ohne Automatik: sie regelt nach der gemessenen Bildzeit, und auf dieser
	# Maschine ist die schlecht genug, dass sie mitten im Lauf den Staub
	# abschaltet — genau den Wert, den kurz darauf geprüft wird. Ihre eigene
	# Wirkung prüft `_check_quality()` direkt.
	Settings.auto_quality = false
	Settings.changed.emit()
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
	await _check_variant_seams()

	# --- Kachelsatz und Kachelraster technisch prüfen ---
	await _check_tileset(world, map, player)

	# --- Karte ---
	var counts := _count_tiles(map, GridOverlay.block_at(player.position), 40)
	_check(counts.size() == 1 and counts.has(MapData.Tile.GRASS),
		"Karte startet leer (nur Gras)")
	# Unter „Sorted" hängen nur die Figur und der (leere) Behälter für Fackeln.
	# Requisiten gibt es in diesem Spiel nicht mehr, und wenn wieder welche
	# auftauchen, fällt es hier auf.
	var sorted := world.get_node("Sorted")
	var unexpected: Array[String] = []
	for child: Node in sorted.get_children():
		if not (child is Player or child is Torches):
			unexpected.append(child.name)
	_check(unexpected.is_empty() and world.torches.count() == 0,
		"Keine Requisiten auf der Karte%s"
		% ("" if unexpected.is_empty() else " (%s)" % ", ".join(unexpected)))
	_check(map.is_solid(0, 10) and map.is_solid(Config.MAP_W - 1, 10),
		"Unsichtbare Wand am Kartenrand")
	var g: GridOverlay = world.grid
	# Das Raster ist da, aber beim Start abgeschaltet: die Welt soll wie eine
	# Welt aussehen und nicht wie kariertes Papier.
	_check(g != null and g.visible and not g.show_grid,
		"Blockraster liegt bereit, ist beim Start aber aus")
	_check(g.z_index > 100, "Raster liegt über der Welt")
	# Bodenmarken (Bauvorschau, Feld unter der Figur) liegen UNTER der Figur.
	var marks: Node2D = g.get_node("Bodenmarken")
	_check(not marks.z_as_relative and marks.z_index < 0,
		"Bodenmarken liegen unter der Figur (z %d, absolut: %s)"
		% [marks.z_index, not marks.z_as_relative])
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
	await _check_terrain_shapes(world, map)
	await _check_gaps(world, map)
	await _check_build_feedback(world)
	await _check_idle_cost(world)
	await _check_toggle(world, map, player)
	await _check_inventory_ui(world)
	await _check_design_system(world)
	await _check_settings(world)
	await _check_motion(world)
	await _check_quality()
	await _check_light(world)
	await _check_figure(world)
	await _check_torch_and_zoom(world)
	await _check_jump_and_torch(world)
	await _check_shore(world)
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
	# Für dieses eine Bild wird das Raster eingeschaltet: der Weltrand gehört
	# dazu, und er soll dokumentiert bleiben.
	world.grid.show_grid = true
	await _shot("04_raster_rand")
	world.grid.show_grid = Config.SHOW_BLOCK_GRID

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
	# JEDE Kategorieseite wird abgelichtet. Eine Seite, die nie jemand ansieht,
	# ist eine Seite, auf der etwas verrutschen kann, ohne dass es auffällt —
	# und genau das ist hier schon zweimal passiert.
	for entry: Array in [[1, "12_grafik"], [2, "13_effekte"], [3, "14_leistung"],
			[4, "15_steuerung"]]:
		main._options_menu._show_page(entry[0])
		await _shot(entry[1])
	main._options_menu._show_page(0)
	await _frames(4)
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
	# Jetzt liegt eine gebaute Karte vor: das Hauptmenü muss „Fortsetzen"
	# zeigen, und „Neue Welt" muss nachfragen, statt sie zu überschreiben.
	_check(MapData.has_save(), "Es gibt jetzt eine gebaute Karte")
	_check(main._main_menu._continue.visible,
		"Mit gespeicherter Karte steht „Fortsetzen\" im Hauptmenü")
	await _shot("16_hauptmenue_fortsetzen")
	main.ask_new_world()
	await _frames(4)
	_check(main.state == main.State.CONFIRM, "„Neue Welt\" fragt vorher nach")
	await _shot("17_rueckfrage")
	main._unhandled_input(_key("ui_cancel"))
	await _frames(4)
	_check(main.state == main.State.MENU, "ESC bricht die Rückfrage ab")
	main.start_game()
	await _frames(6)
	_check(main._world != null and main._world != world, "Neustart erzeugt frische Welt")
	var again: MapData = main._world.map
	_check(again.get_tile(mark.x, mark.y) == MapData.Tile.SAND,
		"Gebaute Karte wird beim nächsten Start wieder geladen")
	MapData.clear_user()
	_check(MapData.load_user().is_empty(), "Ohne Datei wird nichts geladen")
	_restore_save()
	_restore_settings()

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
	_check(GroundTileSet.LAYER_COUNT == 5 and GroundTileSet.LAYER_EDGE == 3
		and GroundTileSet.LAYER_DECOR == 4,
		"Fünf Schichten: drei Böden, Kanten, Streu-Dekoration")

	var inv_all: Array = Inventory.ALL
	_check(inv_all.size() == 3
		and inv_all.has(MapData.Tile.GRASS) and inv_all.has(MapData.Tile.SAND)
		and inv_all.has(MapData.Tile.WATER),
		"Inventar zeigt genau Gras, Sand, Wasser")
	var bar_types: Array = BuildBar.DEFAULT_TYPES
	_check(bar_types.size() == 3, "Bau-Leiste hat drei Felder")
	# Der Staub in der Luft darf nicht das Hellste im Bild sein.
	#
	# Er war es: fast reines Weiss bei bis zu 62 Prozent, heller als jede
	# Grasspitze und heller als der Sand. Ein Spieler hat die Punkte deshalb
	# fuer vergessene Markierungen gehalten und ihre Entfernung verlangt. Sie
	# sind keine Markierungen — aber sie haben ausgesehen wie welche, und das
	# ist derselbe Fehler.
	var mote := Color(AmbientFx.CORE, 1.0)
	_check(mote.get_luminance() < Palette.SAND_LIGHT.get_luminance(),
		"Staub ist blasser als heller Sand (%.2f gegen %.2f)"
		% [mote.get_luminance(), Palette.SAND_LIGHT.get_luminance()])
	_check(AmbientFx.PEAK <= 0.35,
		"Und nie kraeftiger als %.2f" % AmbientFx.PEAK)

	var mini_script := preload("res://src/ui/minimap.gd")
	var mini_colors: Dictionary = mini_script.COLORS
	_check(mini_colors.size() == 3, "Minimap kennt drei Farben")
	# Und jede davon hat eine dunklere Kantenfassung. Ohne sie ist die Karte
	# eine Ansammlung von Farbflaechen: man sieht, DASS dort Wasser ist, aber
	# nicht, welche Form es hat.
	var rim_ok := true
	for key: int in mini_colors:
		var c: Color = mini_colors[key]
		if c.darkened(mini_script.RIM_DARKEN).get_luminance() >= c.get_luminance() - 0.04:
			rim_ok = false
	_check(rim_ok, "Und zu jeder eine deutlich dunklere Kante (%.2f)"
		% mini_script.RIM_DARKEN)

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
	# Drei Böden und die Dekoration. Die Kantenschicht hat KEINE eigene Quelle
	# mehr: Schaum und Tiefe stehen in der Wasserkachel selbst, seit sich das
	# Wasser in seinem Feld zurückzieht.
	_check(ts.get_source_count() == GroundTileSet.STACK.size() + 1,
		"Genau %d Atlasquellen: drei Böden und Dekor (%d)"
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

## Sieht man das Kachelraster, wenn VERSCHIEDENE Varianten aneinanderstossen?
##
## `_check_seams` prueft jede Kachel gegen SICH SELBST — ob ihre rechte Spalte
## zu ihrer eigenen linken passt. Das ist noetig, aber es ist nicht die Frage,
## die auf dem Bildschirm gestellt wird: dort liegt neben Variante 3 die
## Variante 7, und ob DIE zusammenpassen, hat vorher nichts gemessen.
##
## Genau da sass der Fehler. Die Tiefenbaender im Wasser wurden je Variante neu
## ausgewuerfelt; ein Band lief ueber die volle Kachelbreite und hoerte an der
## Kante auf. Stiess dort eine Kachel ohne Band an, sprang die Helligkeit — und
## ueber eine ruhige Wasserflaeche hinweg sah man ein Gitter. Auf dem
## Bildschirm gemessen lag die Naht bei 1,62.
##
## Die Regel dahinter gilt fuer jede Kachelgrafik mit Varianten: was gross ist,
## muss in allen Varianten gleich sein, sonst sieht man die Fuge. Was sich
## unterscheiden darf, muss klein oder weich sein.
func _check_variant_seams() -> void:
	var art := TileArt.build(Config.WORLD_SEED)
	var worst := 0.0
	var worst_name := ""
	print("Nähte zwischen VERSCHIEDENEN Varianten (1,0 = so glatt wie innen):")
	for t in MapData.Tile.COUNT:
		var list: Array = art.base[t]
		var seam := 0.0
		var pairs := 0
		# Jede Variante gegen jede andere derselben Helligkeitsstufe — genau
		# die Paare, die auf der Karte nebeneinander liegen koennen.
		for a in TileArt.VARIANTS:
			for b in TileArt.VARIANTS:
				if a == b:
					continue
				var ia: Image = list[TileArt.VARIANTS + a]
				var ib: Image = list[TileArt.VARIANTS + b]
				var w := ia.get_width()
				var h := ia.get_height()
				var d := 0.0
				for y in h:
					d += _diff(ia.get_pixel(w - 1, y), ib.get_pixel(0, y))
				for x in w:
					d += _diff(ia.get_pixel(x, h - 1), ib.get_pixel(x, 0))
				seam += d / float(w + h)
				pairs += 1
		seam /= maxf(float(pairs), 1.0)
		var inner := _inner_diff(list[TileArt.VARIANTS])
		var ratio := seam / maxf(inner, 0.0001)
		print("  %-12s %.2f" % [GroundTileSet.NAMES[t], ratio])
		if ratio > worst:
			worst = ratio
			worst_name = GroundTileSet.NAMES[t]
	# 1,45: darueber lagen Wasser (1,62) und Gras, als die grossflaechige
	# Struktur noch je Variante gewuerfelt wurde.
	_check(worst < 1.45,
		"Auch verschiedene Kachelvarianten passen aneinander (schlechteste: %s %.2f)"
		% [worst_name, worst])
	await get_tree().process_frame

## Mittlerer Unterschied zweier benachbarter Bildpunkte IM Kachelinneren.
func _inner_diff(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
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
	return inner / maxf(float(n), 1.0)

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
	var grid_was := g.show_grid
	g.show_grid = false
	await _frames(2)
	_check(g.visible and not g.show_grid, "Raster aus, Vorschau bleibt gezeichnet")
	_check(world.build_bar.preview_texture() != null, "Vorschau kennt die gewählte Kachel")
	g.show_grid = grid_was

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

	# Kielwellen: wer sich im Wasser bewegt, zieht eine Spur. Und sie hört
	# wieder auf — eine Spur, die stehen bleibt, wäre ein Leck.
	var water_fx: WaterFx = world.get_node("WaterFx")
	water_fx._splashes.clear()
	await _drive("move_right", 30)
	_check(not water_fx._splashes.is_empty(),
		"Durchs Wasser laufen zieht eine Spur (%d Wellen)" % water_fx._splashes.size())
	_check(water_fx._splashes.size() <= WaterFx.MAX_WAVES,
		"Und die Spur bleibt gedeckelt (%d von höchstens %d)"
		% [water_fx._splashes.size(), WaterFx.MAX_WAVES])
	player.velocity = Vector2.ZERO
	await _frames(70)
	_check(water_fx._splashes.is_empty(),
		"Im Stehen läuft sie aus (%d übrig)" % water_fx._splashes.size())
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

# --- Sparsamkeit --------------------------------------------------------------

## Nichts rechnet, wenn es nichts zu rechnen gibt.
##
## Das ist die Regel, an der Wirkungen in einem Sandkastenspiel scheitern: sie
## laufen weiter, auch wenn sie abgeschaltet sind oder gar nichts zu tun haben.
## Hier wird für jede der drei Wirkungen nachgesehen, ob sie sich wirklich
## abschaltet — `is_processing()` lügt nicht.
func _check_idle_cost(world: Node2D) -> void:
	var fx: BuildFx = world.build_fx
	var ambient: AmbientFx = world.ambient
	var water: WaterFx = world.get_node("WaterFx")

	await _frames(40)
	_check(not fx.is_processing(),
		"Ohne offene Zeichen rechnet die Bau-Rückmeldung nicht")
	world.build_tool.place(Config.spawn_block() + Vector2i(28, 28), MapData.Tile.SAND)
	await _frames(2)
	_check(fx.is_processing(), "Mit einem Zeichen rechnet sie wieder")
	await _frames(40)
	_check(not fx.is_processing(), "Und hört von selbst wieder auf")

	# Beide Richtungen mit festen Werten, nicht mit dem, was gerade eingestellt
	# ist: sonst hängt das Ergebnis daran, womit der Lauf gestartet wurde.
	var part_before := Settings.particles
	Settings.particles = 0
	Settings.changed_and_save()
	await _frames(4)
	_check(not ambient.is_processing(), "Ohne Staub rechnet der Staub nicht")
	Settings.particles = 2
	Settings.changed_and_save()
	await _frames(4)
	_check(ambient.is_processing(), "Mit Staub rechnet er wieder")
	Settings.particles = part_before
	Settings.changed_and_save()

	var water_before := Settings.water_detail
	Settings.water_detail = 0
	Settings.changed_and_save()
	water.prims = -1
	await _frames(10)
	_check(water.prims <= 0, "Wasser „Einfach\" zeichnet nichts (%d)" % water.prims)
	Settings.water_detail = water_before
	Settings.changed_and_save()
	await _frames(6)

# --- Bauen: Form erkennen, Rückmeldung geben ----------------------------------

## Erkennt das Gelände, welche Form gebaut wurde?
##
## Die Übergangskachel eines Feldes ist durch ihre ECKMASKE bestimmt: vier Bits,
## eines je Ecke, gesetzt wenn eines der drei dort anliegenden Felder zur Schicht
## gehört. Aus der Maske lässt sich also ablesen, ob ein Feld eine gerade Kante,
## eine Aussenecke oder eine Innenecke ist — und genau das wird hier geprüft,
## statt Bilder zu vergleichen.
##
##   1 Bit   Aussenecke (nur diagonal berührt)
##   2 Bits  gerade Kante
##   3 Bits  Innenecke
##   4 Bits  Vollkachel (Maske 15)
func _check_terrain_shapes(world: Node2D, map: MapData) -> void:
	var tool: BuildTool = world.build_tool
	var origin := Config.spawn_block() + Vector2i(20, 20)
	var sand := MapData.Tile.SAND

	# --- Einzelnes Feld ---
	tool.place(origin, sand)
	await _frames(2)
	_check(_mask_at(world, 1, origin) == 15,
		"Einzelnes Feld ist eine Vollkachel (%d)" % _mask_at(world, 1, origin))
	var north := _mask_at(world, 1, origin + Vector2i(0, -1))
	var north_west := _mask_at(world, 1, origin + Vector2i(-1, -1))
	_check(_bits(north) == 2, "Feld über einem Einzelblock ist eine Kante (%d Bits)" % _bits(north))
	_check(_bits(north_west) == 1,
		"Feld schräg über einem Einzelblock ist eine Aussenecke (%d Bits)" % _bits(north_west))
	_check(north == 12, "Die Kante liegt unten (Maske %d, erwartet 12)" % north)
	_check(north_west == 4, "Die Aussenecke liegt unten rechts (Maske %d, erwartet 4)" % north_west)

	# --- Gerade Fläche: Mitte einer 3 x 3 bleibt voll, der Rand wird Kante ---
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			tool.place(origin + Vector2i(ox, oy), sand)
	await _frames(2)
	_check(_mask_at(world, 1, origin) == 15, "Mitte einer Fläche bleibt eine Vollkachel")
	var edge := _mask_at(world, 1, origin + Vector2i(0, -2))
	_check(edge == 12, "Über einer Fläche liegt eine gerade Kante (Maske %d)" % edge)

	# --- Innenecke: L-Form, das freie Feld in der Kerbe ---
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			tool.place(origin + Vector2i(ox, oy), MapData.Tile.GRASS)
	var l_cells := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	for c: Vector2i in l_cells:
		tool.place(origin + c, sand)
	await _frames(2)
	var inner := _mask_at(world, 1, origin + Vector2i(1, 1))
	_check(_bits(inner) == 3,
		"Das Feld in der Kerbe einer L-Form ist eine Innenecke (%d Bits, Maske %d)"
		% [_bits(inner), inner])
	_check(inner == 11, "Die Innenecke lässt genau die abgewandte Ecke frei (Maske %d)" % inner)

	# --- Wasser zieht sich zurück, statt hinauszuwachsen ---
	#
	# Das ist die Antwort auf „die Wasserbecken sind zu kantig". Wasser wächst
	# NICHT in die Nachbarfelder (sonst liefe die Figur sichtbar auf Wasser,
	# ohne zu schwimmen), sondern frisst in seinem EIGENEN Feld eine Rauschkante
	# hinein. Darunter liegt Sand, der dabei zum Vorschein kommt.
	for c: Vector2i in l_cells:
		tool.place(origin + c, MapData.Tile.GRASS)
	var pond := origin + Vector2i(6, 0)
	tool.place(pond, MapData.Tile.WATER)
	await _frames(3)
	_check(_mask_at(world, 2, pond) == 0,
		"Ein einzelnes Wasserfeld wird eine runde Pfütze, kein Quadrat (Maske %d)"
		% _mask_at(world, 2, pond))
	_check(_mask_at(world, 2, pond + Vector2i(0, -1)) < 0,
		"Und es läuft nicht auf das Nachbarfeld über — Karte und Bild bleiben einig")
	_check(_mask_at(world, 1, pond) == 15,
		"Unter dem Wasser liegt Sand, der an der zurückgezogenen Kante zu sehen ist")

	# Die Mitte einer Fläche bleibt voll, ihre Ecke zieht sich zurück.
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			tool.place(pond + Vector2i(ox, oy), MapData.Tile.WATER)
	await _frames(3)
	_check(_mask_at(world, 2, pond) == 15, "Die Mitte einer Wasserfläche bleibt voll")
	var w_corner := _mask_at(world, 2, pond + Vector2i(-1, -1))
	_check(w_corner >= 0 and w_corner < 15,
		"Die Ecke einer Wasserfläche zieht sich zurück (Maske %d)" % w_corner)
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			tool.place(pond + Vector2i(ox, oy), MapData.Tile.GRASS)
	await _frames(3)

## Eine echte Lücke muss eine sichtbare Lücke bleiben.
##
## Das war ein gemeldeter Fehler, und er stimmte:
##
##   [SAND][SAND][ leer ][SAND][SAND]
##
## Das leere Feld hat links UND rechts Sand. Der Übergang wächst aus den
## Nachbarn heraus und setzt eine Ecke, sobald eines der drei dort anliegenden
## Felder dazugehört — also alle vier. Maske 15, und die lag im Atlas hinter den
## Teilkacheln: das leere Feld bekam eine VOLLKACHEL Sand und die Lücke war weg.
##
## Derselbe Fehler traf jeden einzeln entfernten Block mitten in einer Fläche:
## acht Nachbarn ringsum, Maske 15, Vollkachel — das Entfernen war unsichtbar.
##
## Geprüft wird deshalb nicht die Maske (die ist in beiden Fällen 15), sondern
## ob wirklich eine Vollkachel gesetzt wurde, und ob im Kachelbild noch Löcher
## sind, durch die der Boden darunter zu sehen ist.
func _check_gaps(world: Node2D, map: MapData) -> void:
	var tool: BuildTool = world.build_tool
	var sand := MapData.Tile.SAND
	var origin := GridOverlay.block_at(world.player.global_position) + Vector2i(0, -8)
	for oy in range(-2, 3):
		for ox in range(-4, 5):
			tool.place(origin + Vector2i(ox, oy), MapData.Tile.GRASS)
	await _frames(2)

	# --- Die gemeldete Reihe: [S][S][ ][S][S] ---
	for ox: int in [-2, -1, 1, 2]:
		tool.place(origin + Vector2i(ox, 0), sand)
	await _frames(3)
	_check(not _is_full(world, 1, origin),
		"Die Lücke in [S][S][ ][S][S] bleibt eine Lücke")
	var open_px := _open_pixels(world, 1, origin)
	_check(open_px > 60,
		"Durch die Lücke ist der Boden darunter zu sehen (%d von 1024 Punkten)" % open_px)

	# --- Ein einzeln entfernter Block mitten in einer Fläche ---
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			tool.place(origin + Vector2i(ox, oy), sand)
	await _frames(3)
	_check(_is_full(world, 1, origin), "Mitten in der Fläche liegt eine Vollkachel")
	tool.place(origin, MapData.Tile.GRASS)
	await _frames(3)
	_check(not _is_full(world, 1, origin),
		"Ein entfernter Block mitten in der Fläche ist wirklich weg")
	_check(_open_pixels(world, 1, origin) > 60,
		"Und man sieht den Boden darunter (%d Punkte)" % _open_pixels(world, 1, origin))

	# --- Zwei Felder Abstand bleiben zwei Felder ---
	for oy in range(-2, 3):
		for ox in range(-4, 5):
			tool.place(origin + Vector2i(ox, oy), MapData.Tile.GRASS)
	for ox: int in [-3, -2, 1, 2]:
		tool.place(origin + Vector2i(ox, 0), sand)
	await _frames(3)
	var both_open := _open_pixels(world, 1, origin) + _open_pixels(world, 1, origin + Vector2i(-1, 0))
	_check(both_open > 300,
		"Zwei Felder Abstand bleiben deutlich offen (%d Punkte)" % both_open)

	# Aufräumen.
	for oy in range(-2, 3):
		for ox in range(-4, 5):
			tool.place(origin + Vector2i(ox, oy), MapData.Tile.GRASS)
	await _frames(3)

## Liegt auf diesem Feld dieser Schicht eine Vollkachel?
func _is_full(world: Node2D, layer_pos: int, cell: Vector2i) -> bool:
	var idx := _slot_index(world, layer_pos, cell)
	return idx >= TerrainAtlas.FULL_START

## Wie viele der 1024 Bildpunkte der gesetzten Kachel durchsichtig sind — also
## wie viel vom Boden darunter zu sehen ist.
func _open_pixels(world: Node2D, layer_pos: int, cell: Vector2i) -> int:
	var layer: TileMapLayer = world.streamer.layers[layer_pos]
	var coords := layer.get_cell_atlas_coords(cell)
	if coords.x < 0:
		return Config.TILE * Config.TILE          # gar keine Kachel = ganz offen
	var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	var img := src.texture.get_image()
	var n := 0
	for y in Config.TILE:
		for x in Config.TILE:
			if img.get_pixel(coords.x * Config.TILE + x, coords.y * Config.TILE + y).a < 0.35:
				n += 1
	return n

func _slot_index(world: Node2D, layer_pos: int, cell: Vector2i) -> int:
	var layer: TileMapLayer = world.streamer.layers[layer_pos]
	var coords := layer.get_cell_atlas_coords(cell)
	if coords.x < 0:
		return -1
	return (world.streamer.ground._slots[layer_pos] as Array).find(coords)

## Die Eckmaske eines Feldes auf einer Bodenschicht.
##
## 0 – 14 sind Übergänge, 15 ist eine Vollkachel, −1 heisst: dort liegt nichts.
##
## Jede Maske liegt in mehreren Ausführungen hintereinander im Atlas, deshalb
## wird der Platz durch ihre Anzahl geteilt.
func _mask_at(world: Node2D, layer_pos: int, cell: Vector2i) -> int:
	var layer: TileMapLayer = world.streamer.layers[layer_pos]
	var coords := layer.get_cell_atlas_coords(cell)
	if coords.x < 0:
		return -1
	var slots: Array = world.streamer.ground._slots[layer_pos]
	var idx := slots.find(coords)
	if idx < 0:
		return -1
	return (idx / TerrainAtlas.EDGE_VARIANTS) if idx < TerrainAtlas.FULL_START else 15

func _bits(mask: int) -> int:
	if mask < 0:
		return 0
	var n := 0
	for i in 4:
		if mask & (1 << i):
			n += 1
	return n

## Bauen muss sich anfühlen, als hätte man etwas getan.
##
## Geprüft wird, dass jedes gesetzte Feld ein Zeichen bekommt, dass das Zeichen
## wieder verschwindet, und dass beim schnellen Ziehen nicht hunderte davon
## stehen bleiben und die Welt zudecken.
func _check_build_feedback(world: Node2D) -> void:
	var fx: BuildFx = world.build_fx
	var tool: BuildTool = world.build_tool
	_check(fx != null, "Rückmeldung beim Bauen vorhanden")
	if fx == null:
		return
	var at := Config.spawn_block() + Vector2i(24, 24)
	tool.place(at, MapData.Tile.SAND)
	await _frames(3)
	_check(fx.drawn > 0, "Ein gesetzter Block bekommt ein Zeichen (%d)" % fx.drawn)
	await _frames(40)
	_check(fx.drawn == 0, "Das Zeichen verschwindet von selbst wieder (%d)" % fx.drawn)

	# Schnelles Ziehen: viele Felder, aber die Zeichen bleiben begrenzt.
	for i in 60:
		tool.place(at + Vector2i(i % 12, i / 12), MapData.Tile.SAND)
	_check(fx._marks.size() <= BuildFx.MAX_MARKS,
		"Beim Ziehen bleiben höchstens %d Zeichen stehen (%d)"
		% [BuildFx.MAX_MARKS, fx._marks.size()])
	for i in 60:
		tool.place(at + Vector2i(i % 12, i / 12), MapData.Tile.GRASS)
	await _frames(40)

# --- Bewegung in der Welt -----------------------------------------------------

## Wind, Wasserlicht und Staub — und dass sich beides wirklich abschalten lässt.
##
## „Aus" muss heissen: kostet nichts. Ein Shader mit Stärke null rechnet
## trotzdem für jeden Eckpunkt, und Staubpunkte, die nur unsichtbar sind, werden
## trotzdem bewegt. Deshalb wird hier nicht die Sichtbarkeit geprüft, sondern
## ob Material und Punkte überhaupt noch da sind.
func _check_motion(world: Node2D) -> void:
	var streamer: ChunkStreamer = world.streamer
	var ambient: AmbientFx = world.ambient
	var wind_before := Settings.wind
	var part_before := Settings.particles

	for level in 3:
		Settings.wind = level
		Settings.changed_and_save()
		await _frames(2)
		_check(streamer.wind_level() == level,
			"Bewegungsstufe %d liegt wirklich auf dem Boden (%d)" % [level, streamer.wind_level()])
	Settings.wind = 0
	Settings.changed_and_save()
	await _frames(2)
	_check(streamer.layers[0].material == null and streamer.layers[2].material == null,
		"Bewegung „Aus\" hängt das Material ab, statt es auf null zu rechnen")

	# Die Wellen laufen im Vertex-Schritt, nicht je Bildpunkt. Im Fragment
	# kostete dieselbe Wirkung das Fünffache je Bild — deshalb steht das hier
	# als Prüfung und nicht nur als Kommentar.
	Settings.wind = 2
	Settings.changed_and_save()
	await _frames(2)
	var code: String = streamer.layers[0].material.shader.code
	_check(code.contains("void vertex()") and not code.contains("void fragment()"),
		"Die Bewegung wird je Eckpunkt gerechnet, nicht je Bildpunkt")

	# Staub: Anzahl folgt der Einstellung, „Aus" lässt nichts übrig.
	for entry: Array in [[0, 0], [1, 18], [2, 42]]:
		Settings.particles = entry[0]
		Settings.changed_and_save()
		await _frames(4)
		_check(ambient._motes.size() == entry[1],
			"Staubstufe %d hält %d Punkte (%d)" % [entry[0], entry[1], ambient._motes.size()])
	Settings.particles = 0
	Settings.changed_and_save()
	await _frames(6)
	_check(ambient.drawn == 0, "Staub „Aus\" zeichnet nichts mehr (%d)" % ambient.drawn)
	Settings.particles = 2
	Settings.changed_and_save()
	await _frames(20)
	_check(ambient.drawn > 0, "Staub „Voll\" zeichnet wieder (%d Punkte)" % ambient.drawn)

	# Was die Bewegung kostet, getrennt nach Ursache.
	#
	# Ein erster Durchlauf wird weggeworfen: ein frisch angehängter Shader wird
	# beim ersten Bild übersetzt, und diese eine Spitze (gemessen: 100 ms)
	# gehört nicht in die Messung.
	Settings.wind = 2
	Settings.particles = 2
	Settings.changed_and_save()
	await _frames(30)
	await _frame_cost()

	var cost := {}
	for entry: Array in [["Wind + Staub", 2, 2], ["nur Staub", 0, 2],
			["nur Wind", 2, 0], ["nichts", 0, 0]]:
		Settings.wind = entry[1]
		Settings.particles = entry[2]
		Settings.changed_and_save()
		await _frames(25)
		cost[entry[0]] = await _frame_cost()
	for key: String in cost:
		print("  Bewegung %-14s %6.2f ms je Bild" % [key, cost[key]])

	# Geprüft wird die Grössenordnung, nicht die Nachkommastelle: auf einem
	# Software-Rasterizer streuen die Werte um ein bis zwei Millisekunden, ein
	# Unterschied darunter sagt nichts. Was diese Prüfung fangen soll, ist eine
	# Wirkung, die das Bild VIELFACH teurer macht — die erste Fassung rechnete
	# die Wellen je Bildpunkt statt je Eckpunkt und kostete das Fünffache.
	var quiet: float = cost["nichts"]
	var loud: float = cost["Wind + Staub"]
	_check(loud <= quiet * 1.6 + 3.0,
		"Bewegung kostet keine Grössenordnung (%.2f ms mit, %.2f ms ohne)" % [loud, quiet])

	Settings.wind = wind_before
	Settings.particles = part_before
	Settings.changed_and_save()
	await _frames(20)

# --- Qualitätsprofile ---------------------------------------------------------

## Profile müssen zwei Dinge können: wirklich etwas einstellen, und beim
## Sparen die richtigen Dinge opfern.
##
## Der zweite Punkt ist der, um den es geht. Ein Profil, das jeden Regler nach
## unten schiebt, ist keine Anpassung, sondern Aufgeben. Gemessen kostet die
## Tönung des Tageslichts nichts und der Bewuchs am Boden nichts — beides
## bleibt deshalb auch auf der niedrigsten Stufe an, und weggenommen wird, was
## Füllrate frisst.
func _check_quality() -> void:
	var before := {}
	for entry: Array in Quality.GIVE_UP:
		before[entry[0]] = Settings.get(entry[0])
	var shadows_before := Settings.shadows
	var decor_before := Settings.decor

	# 1. Jedes Profil stellt wirklich etwas ein und wird wiedererkannt.
	var wrong: Array[String] = []
	for level in Quality.NAMES.size():
		Quality.apply(level)
		if Quality.current() != level:
			wrong.append("%s wird nicht wiedererkannt" % Quality.NAMES[level])
	_check(wrong.is_empty(), "Jedes Profil stellt ein, was es verspricht%s"
		% ("" if wrong.is_empty() else " (%s)" % ", ".join(wrong)))

	# 2. „Eigene": sobald ein Regler nicht mehr passt, behauptet nichts mehr,
	#    ein Profil sei eingestellt.
	Quality.apply(Quality.Level.HOCH)
	Settings.particles = 0
	_check(Quality.current() < 0,
		"Ein von Hand verstellter Regler heisst „Eigene\", nicht mehr „Hoch\"")

	# 3. Die niedrigste Stufe behält, was gratis ist.
	Quality.apply(Quality.Level.NIEDRIG)
	_check(Settings.light >= 1 and Settings.decor >= 1,
		"Auch „Niedrig\" behält Tagesverlauf und Bewuchs (Licht %d, Bewuchs %d)"
		% [Settings.light, Settings.decor])
	_check(Settings.particles == 0 and Settings.wind == 0,
		"Und gibt auf, was Füllrate kostet")

	# 4. Heruntergeregelt wird EINE Wirkung je Schritt, teuerste zuerst.
	Quality.apply(Quality.Level.HOCH)
	var first := Quality.step_down()
	_check(first == "light" and Settings.light == 2,
		"Zuerst fällt die Sichtgrenze (%s -> Licht %d)" % [first, Settings.light])
	var steps := 0
	while Quality.step_down() != "" and steps < 20:
		steps += 1
	_check(steps > 0 and steps < 20, "Und danach ist irgendwann Schluss (%d Schritte)" % steps)

	# 5. Nach oben nie über das hinaus, was der Mensch eingestellt hat.
	var ceiling := {"light": 2, "particles": 1, "wind": 0,
		"water_detail": 0, "render_range": 0}
	var guard := 0
	while Quality.step_up(ceiling) != "" and guard < 20:
		guard += 1
	_check(Settings.light == 2 and Settings.particles == 1 and Settings.wind == 0,
		"Die Automatik gibt nie mehr zurück, als eingestellt war (Licht %d, Staub %d, Wind %d)"
		% [Settings.light, Settings.particles, Settings.wind])

	# 6. Die Hardwareerkennung liefert echte Werte, keine Platzhalter.
	var hw := Quality.hardware()
	_check(int(hw["cores"]) > 0 and String(hw["gpu"]) != "",
		"Hardware wird erkannt (%d Kerne, %s, %s)"
		% [hw["cores"], hw["gpu"], Quality.gpu_kind(int(hw["gpu_type"]))])
	var guess := Quality.suggest()
	_check(guess >= 0 and guess < Quality.NAMES.size(),
		"Und daraus folgt ein Vorschlag: %s" % Quality.NAMES[guess])

	for key: String in before:
		Settings.set(key, before[key])
	Settings.shadows = shadows_before
	Settings.decor = decor_before
	Settings.changed_and_save()
	await _frames(4)

# --- Beleuchtung --------------------------------------------------------------

## Das Tageslicht muss vier Dinge können: sich über den Tag ändern, der Figur
## folgen, auf Stufe „Aus" verschwinden — und dabei billig bleiben.
##
## Der letzte Punkt ist der, der diese Prüfungen nötig macht. Gemessen wurde
## (Renderzeit des Viewports, llvmpipe): ein echtes `PointLight2D` kostete
## +3,43 ms CPU-Renderzeit, ein Vollbild-Fragment-Shader als Vignette weitere
## +1,69 CPU und +1,80 GPU — zusammen eine Verdopplung der Renderkosten, bei
## Tag wie bei Nacht. Beides ist ersetzt; diese Prüfungen halten fest, dass es
## ersetzt BLEIBT. Ein wieder eingebautes Light2D fiele sonst erst auf einem
## fremden Rechner auf.
func _check_light(world: Node2D) -> void:
	var light: LightManager = world.light
	var before := Settings.light

	# 1. Der Verlauf ist wirklich ein Verlauf: Nacht deutlich dunkler als Mittag,
	#    Morgen und Abend warm getönt statt neutral.
	var night := LightManager.tint_at(0.0).get_luminance()
	var noon := LightManager.tint_at(0.5).get_luminance()
	_check(night < noon - 0.4,
		"Die Nacht ist merklich dunkler als der Mittag (%.2f gegen %.2f)" % [night, noon])
	var dusk := LightManager.tint_at(0.79)
	_check(dusk.r > dusk.b + 0.2, "Der Abend ist warm getönt (r %.2f, b %.2f)" % [dusk.r, dusk.b])
	# Und er springt nirgends: zwischen zwei benachbarten Zeitpunkten darf sich
	# die Farbe nur wenig ändern, sonst gäbe es im Spiel einen sichtbaren Ruck.
	var jump := 0.0
	var prev := LightManager.tint_at(0.0)
	for i in range(1, 401):
		var cur := LightManager.tint_at(i / 400.0)
		jump = maxf(jump, absf(cur.get_luminance() - prev.get_luminance()))
		prev = cur
	_check(jump < 0.02, "Der Tagesverlauf springt nirgends (grösster Schritt %.4f)" % jump)

	# 2. KEIN echtes 2D-Licht in der ganzen Welt. Das ist die eigentliche
	#    Leistungsprüfung: ein Light2D zwingt den Canvas-Renderer in den
	#    beleuchteten Pfad, und weil das Licht der Figur nachgeführt wird,
	#    fällt diese Arbeit jedes Bild neu an.
	var lights := _find_all_of_class(world, "Light2D")
	_check(lights.is_empty(), "Kein echtes 2D-Licht in der Welt (%d gefunden)" % lights.size())

	# 3. Und kein Vollbild-Shader: die Sichtgrenze ist eine gebackene Textur.
	var night_layer: CanvasLayer = light.get_node("Nachtschicht")
	var vignette: TextureRect = night_layer.get_node("Sichtgrenze")
	_check(vignette.material == null and vignette.texture != null,
		"Die Sichtgrenze ist eine gebackene Textur, kein Shader")

	# 3b. Die Blaustunde: ein einfaches Viereck, ebenfalls ohne Shader — und
	#     GANZ UNTEN auf der Nachtschicht. Laege sie ueber den Scheinen, wuerde
	#     das warme Fackellicht mit eingefaerbt, und der Kontrast zwischen kalt
	#     und warm, der eine Nachtszene traegt, waere weg.
	var blue: ColorRect = night_layer.get_node("Blaustunde")
	_check(blue.material == null and night_layer.get_child(0) == blue,
		"Die Blaustunde liegt unter den Scheinen und braucht keinen Shader")

	# 3c. Und sie ist wirklich blau — nicht nur so benannt.
	#
	#     Das ist der Punkt, an dem die Nacht vorher scheiterte: die Toenung
	#     MULTIPLIZIERT, und eine blaue Toenung ueber gruenem Gras ergibt
	#     dunkles Gruen, kein Blau. In der Tabelle stand trotzdem seit jeher
	#     „tiefe Nacht, blau". Geprueft wird deshalb das Ergebnis, nicht die
	#     Absicht: Gras mal Nachttoenung, dann die Blaustunde darueber.
	var night_tint := LightManager.tint_at(0.0)
	var grass_lit := Color(Palette.GRASS.r * night_tint.r,
		Palette.GRASS.g * night_tint.g, Palette.GRASS.b * night_tint.b)
	var washed := grass_lit.lerp(LightManager.NIGHT_BLUE, LightManager.NIGHT_BLUE_A)
	_check(grass_lit.b < grass_lit.g, "Ohne Blaustunde bliebe die Nacht gruen (b %.3f < g %.3f)"
		% [grass_lit.b, grass_lit.g])
	_check(washed.b > grass_lit.b * 1.3,
		"Mit ihr wird sie blau (Blauanteil %.3f statt %.3f)" % [washed.b, grass_lit.b])

	# 3d. Zwei Scheine liegen an der Figur uebereinander, und additiv heisst
	#     addiert. Ihre Summe muss unter der Saettigung bleiben, sonst steht
	#     nachts ein weisser Fleck an der Stelle der Figur — genau das war beim
	#     ersten Versuch der Fall.
	var peak := LightManager.GLOW_PEAK * (1.0 + 0.40)
	_check(peak < 0.56, "Die beiden Scheine der Figur summieren sich auf %.2f" % peak)

	# 4. Tagesverlauf: die Uhr läuft, der Schein folgt der Figur.
	var cycle_before := Settings.day_cycle
	Settings.light = 3
	Settings.day_cycle = true
	Settings.changed_and_save()
	light.set_time(0.0)
	await _frames(4)
	var t0 := light.time_of_day()
	await _frames(30)
	_check(light.active() and light.time_of_day() > t0, "Die Zeit läuft (%.4f -> %.4f)"
		% [t0, light.time_of_day()])

	# Der Schein liegt auf einer Bildschirmebene; geprüft wird deshalb gegen die
	# umgerechnete Weltposition der Figur, nicht gegen die Weltposition selbst.
	var glow := light.player_glow()
	var want: Vector2 = get_viewport().get_canvas_transform() \
		* (world.player.global_position - Vector2(0.0, LightManager.LIGHT_LIFT))
	_check(glow != null and glow.position.distance_to(want) < 1.5,
		"Der Schein sitzt auf Brusthöhe bei der Figur (%.1f px Abstand)"
		% (glow.position.distance_to(want) if glow != null else -1.0))

	# 5. Nachts brennt der Schein, mittags nicht — und mittags ist die ganze
	#    Nachtschicht unsichtbar, kostet also nichts.
	var at_night := light.light_energy()
	await _shot("20_nacht")
	light.set_time(0.79)
	await _shot("21_abend")
	light.set_time(0.5)
	await _frames(4)
	var at_noon := light.light_energy()
	_check(at_night > 0.5 and at_noon <= 0.01,
		"Der Schein blendet nachts auf und mittags ab (%.2f / %.2f)" % [at_night, at_noon])
	_check(not night_layer.visible,
		"Am Mittag ist die Nachtschicht ganz abgeschaltet")
	light.set_time(0.0)
	await _frames(4)
	_check(night_layer.visible and glow.visible,
		"Nachts ist sie wieder da")

	# 6. Die Stufen schalten wirklich einzeln. Das ist der Punkt der ganzen
	#    Abstufung: wer „Einfach" wählt, soll den Tagesverlauf behalten und nur
	#    die beiden Flächen loswerden, die Füllrate kosten.
	var glow_root: Node2D = night_layer.get_node("Schein")
	var steps: Array[String] = []
	for entry: Array in [[1, false, false], [2, true, false], [3, true, true]]:
		Settings.light = entry[0]
		Settings.changed_and_save()
		light.set_time(0.0)
		await _frames(4)
		if glow_root.visible != entry[1]:
			steps.append("Stufe %d: Schein %s" % [entry[0], glow_root.visible])
		if vignette.visible != entry[2]:
			steps.append("Stufe %d: Sichtgrenze %s" % [entry[0], vignette.visible])
		# Die Tönung muss auf JEDER Stufe wirken: sie ist der Teil, der die
		# Nacht ausmacht, und sie ist gemessen gratis.
		if light.tint().get_luminance() > 0.5:
			steps.append("Stufe %d ohne Tönung (%.2f)" % [entry[0], light.tint().get_luminance()])
	_check(steps.is_empty(), "Jede Lichtstufe schaltet genau ihren Teil zu%s"
		% ("" if steps.is_empty() else " (%s)" % ", ".join(steps)))

	# 7. „Fest" hält die Zeit an — wer bauen will, soll bauen können.
	Settings.light = 3
	Settings.day_cycle = false
	Settings.changed_and_save()
	await _frames(30)
	_check(is_equal_approx(light.time_of_day(), LightManager.START_TIME),
		"„Fest\" hält die Tageszeit an (%.3f)" % light.time_of_day())
	_check(light.tint().get_luminance() > 0.9,
		"„Fest\" steht am hellen Vormittag (%.2f)" % light.tint().get_luminance())

	Settings.day_cycle = cycle_before

	# 8. „Aus" hängt alles ab.
	Settings.light = 0
	Settings.changed_and_save()
	await _frames(4)
	var off: Array[String] = []
	if light.active():
		off.append("läuft weiter")
	if light.is_processing():
		off.append("rechnet weiter")
	for node: Node in [light.get_node("Tageslicht"), night_layer]:
		if node.get("visible"):
			off.append("%s sichtbar" % node.name)
	_check(off.is_empty(), "Beleuchtung „Aus\" kostet wirklich nichts%s"
		% ("" if off.is_empty() else " (%s)" % ", ".join(off)))

	# 9. Das Licht liegt auf der Welt, nicht auf der Oberfläche.
	_check(night_layer.layer < world.hud.layer,
		"Die Nachtschicht liegt unter der Oberfläche (%d gegen %d)"
		% [night_layer.layer, world.hud.layer])

	# 10. Zeichenaufrufe: die Beleuchtung darf keinen zweiten Durchgang über die
	#     Welt auslösen. Millisekunden schwanken auf dieser Maschine zu stark,
	#     Aufrufe nicht.
	var draws := {}
	for entry: Array in [["aus", 0], ["voll", 3]]:
		Settings.light = entry[1]
		Settings.changed_and_save()
		if entry[1] == 3:
			light.set_time(0.0)
		await _frames(20)
		draws[entry[0]] = await _draw_calls()
	print("  Licht: %d Zeichenaufrufe aus, %d voll" % [draws["aus"], draws["voll"]])
	_check(draws["voll"] <= draws["aus"] + 8,
		"Beleuchtung bleibt bei den Zeichenaufrufen bescheiden (%d gegen %d)"
		% [draws["voll"], draws["aus"]])

	Settings.light = before
	Settings.changed_and_save()
	await _frames(6)

# --- Sprung, Handfackel, Ufer -------------------------------------------------

## Der Sprung muss eine Bewegung sein, keine Verschiebung; die Handfackel muss
## bei Nacht da sein und am Tag weg; das Ufer muss Schaum tragen.
func _check_jump_and_torch(world: Node2D) -> void:
	var player: Player = world.player
	var light: LightManager = world.light
	var frames: Dictionary = player._frames

	# 1. Drei wirklich verschiedene Sprungstellungen je Richtung.
	var same: Array[String] = []
	for dir in 3:
		var set: Array = frames["jump"][dir]
		var seen: Array[PackedByteArray] = []
		for f: Texture2D in set:
			var data := f.get_image().get_data()
			if not seen.has(data):
				seen.append(data)
		if seen.size() < 3:
			same.append("Richtung %d: %d Stellungen" % [dir, seen.size()])
	_check(same.is_empty(), "Der Sprung hat drei verschiedene Stellungen je Richtung%s"
		% ("" if same.is_empty() else " (%s)" % ", ".join(same)))
	# Und sie unterscheiden sich vom Stand — sonst wäre es doch nur eine
	# Verschiebung, nur mit mehr Code.
	var standing: PackedByteArray = (frames["idle"][0][0] as Texture2D).get_image().get_data()
	var rising: PackedByteArray = (frames["jump"][0][ActorArt.JUMP_RISE] as Texture2D) \
		.get_image().get_data()
	_check(standing != rising, "Die Sprungstellung ist nicht das Standbild")

	# 2. Im Sprung wird sie auch wirklich benutzt.
	player.velocity = Vector2.ZERO
	await _frames(4)
	var before: Texture2D = player._sprite.texture
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(6)
	_check(player.is_jumping() and player._sprite.texture != before,
		"Beim Springen wechselt die Figur wirklich die Stellung")
	await _frames(50)

	# 3. Die Handfackel: nachts da, tags weg.
	var before_light := Settings.light
	Settings.light = 3
	Settings.changed_and_save()
	light.set_time(0.5)                       # Mittag
	await _frames(4)
	player._update_torch(0.0)
	var torch: Sprite2D = player.get_node("Handfackel")
	_check(not torch.visible, "Am Mittag trägt die Figur keine Fackel")
	light.set_time(0.0)                       # Mitternacht
	await _frames(4)
	player._update_torch(0.0)
	_check(torch.visible and torch.texture != null,
		"Nachts hält sie eine Fackel in der Hand")

	# 4. Und die Flamme steht nicht still.
	var flame := torch.texture
	var moved := false
	for i in 30:
		player._update_torch(0.05)
		if torch.texture != flame:
			moved = true
			break
	_check(moved, "Die Flamme bewegt sich")
	_check((frames["torch"] as Array).size() >= 3,
		"Sie hat mehrere Bilder (%d)" % (frames["torch"] as Array).size())

	# 5. Sie ist kleiner als eine gesetzte Fackel — sie wird getragen, nicht
	#    aufgestellt.
	_check(LightManager.PLAYER_RADIUS < Torches.RADIUS,
		"Die Handfackel leuchtet kürzer als eine gesetzte (%.0f gegen %.0f)"
		% [LightManager.PLAYER_RADIUS, Torches.RADIUS])

	Settings.light = before_light
	Settings.changed_and_save()
	await _frames(4)

## Die Uferkante trägt ihren Schaum selbst.
##
## Vorher lag die Brandung in einer zweiten Schicht daneben, am Blockrand — und
## das Wasser war deshalb ein Rechteck. Jetzt steckt beides in derselben
## Kachel, und zwei getrennt erzeugte Bilder können sich nicht mehr
## widersprechen.
func _check_shore(world: Node2D) -> void:
	var tool: BuildTool = world.build_tool
	var origin := GridOverlay.block_at(world.player.global_position) + Vector2i(0, -6)
	# Am hellen Tag: ein Ufer im Dunkeln kann man nicht beurteilen, und dieses
	# Bild landet in der Dokumentation.
	world.light.set_time(0.4)
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			tool.place(origin + Vector2i(ox, oy), MapData.Tile.WATER)
	await _frames(3)

	# Das Randfeld trägt Schaum, das Innenfeld nicht.
	var edge_foam := _foam_pixels(world, 2, origin + Vector2i(-2, 0))
	var mid_foam := _foam_pixels(world, 2, origin)
	_check(edge_foam > 12,
		"Die Wasserkante trägt einen Schaumsaum (%d Punkte)" % edge_foam)
	_check(mid_foam < edge_foam / 2,
		"Mitten in der Fläche gibt es keinen (%d gegen %d)" % [mid_foam, edge_foam])

	# Und sie ist zurückgezogen: das Randfeld ist nicht ganz gefüllt.
	var open_px := _open_pixels(world, 2, origin + Vector2i(-2, 0))
	_check(open_px > 40,
		"Am Rand kommt der Sand darunter zum Vorschein (%d Punkte)" % open_px)

	# Und die BEWEGTE Wasserwirkung bleibt drin, wo auch Wasser gezeichnet ist.
	#
	# Das ist die Pruefung, die in der letzten Runde gefehlt hat. Damals zog
	# sich die Wasserzeichnung um eine halbe Kachel zurueck, aber der animierte
	# Uferschaum blieb an der Kachelkante der KARTE haengen — also einen halben
	# Block draussen im Sand. Auf dem Bildschirm lief dadurch ein blasses
	# gestricheltes Rechteck um jeden Teich, gut sichtbar, und kein einziger
	# Test schlug an.
	#
	# Der Schaum ist seither gebacken; was hier lebt, ist das Glitzern, und das
	# darf nur auf Feldern liegen, die auch als volle Kachel gezeichnet sind.
	var wfx: WaterFx = world.get_node("WaterFx")
	_check(wfx._solid_water(origin.x, origin.y),
		"Mitten im Teich gilt das Feld als volles Wasser")
	_check(not wfx._solid_water(origin.x - 2, origin.y),
		"Am Rand nicht — dort liegt die halbe Kachel im Sand")
	# Und es gibt keinen zweiten Weg, an dem so etwas wieder entstehen koennte:
	# eine Uferschleife ueber die Kachelkanten ist hier nicht mehr vorhanden.
	var wfx_src := FileAccess.get_file_as_string("res://src/world/water_fx.gd")
	_check(not wfx_src.contains("func _foam"),
		"Kein blockgenauer Schaumsaum mehr in der Wasserwirkung")

	await _shot("22_ufer")
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			tool.place(origin + Vector2i(ox, oy), MapData.Tile.GRASS)
	await _frames(3)

## Wie viele Punkte der Kachel deutlich heller sind als das Wasser — also Schaum.
func _foam_pixels(world: Node2D, layer_pos: int, cell: Vector2i) -> int:
	var layer: TileMapLayer = world.streamer.layers[layer_pos]
	var coords := layer.get_cell_atlas_coords(cell)
	if coords.x < 0:
		return 0
	var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	var img := src.texture.get_image()
	var n := 0
	for y in Config.TILE:
		for x in Config.TILE:
			var c := img.get_pixel(coords.x * Config.TILE + x, coords.y * Config.TILE + y)
			if c.a > 0.5 and c.get_luminance() > 0.66:
				n += 1
	return n

# --- Fackel und Zoom ----------------------------------------------------------

## Die Fackel muss Licht machen, wieder verschwinden und einen Neustart
## überstehen. Der Zoom muss GANZZAHLIG bleiben — daran hing schon einmal die
## Schärfe des ganzen Bildes.
func _check_torch_and_zoom(world: Node2D) -> void:
	var tool: BuildTool = world.build_tool
	var torches: Torches = world.torches
	var light: LightManager = world.light
	var map: MapData = world.map
	var cell := GridOverlay.block_at(world.player.global_position) + Vector2i(2, 0)

	# 1. Setzen: Bild in der Welt UND Licht auf der Nachtschicht.
	var lights_before := light.source_count()
	var on := torches.toggle(cell)
	await _frames(3)
	_check(on and torches.has_torch(cell), "Eine Fackel lässt sich setzen")
	_check(light.source_count() == lights_before + 1,
		"Und sie bringt eine Lichtquelle mit (%d -> %d)"
		% [lights_before, light.source_count()])
	_check(map.torches.has(cell), "Sie steht in der Karte, nicht nur im Bild")

	# 2. Und sie ist KEIN echtes Licht — sonst wäre die zehnte Fackel nicht
	#    mehr bezahlbar. Das ist die eigentliche Prüfung an dieser Stelle.
	_check(_find_all_of_class(world, "Light2D").is_empty(),
		"Auch mit Fackel gibt es kein echtes 2D-Licht")

	# 3. Nochmal drücken nimmt sie wieder weg.
	var off := torches.toggle(cell)
	await _frames(3)
	_check(not off and not torches.has_torch(cell), "Nochmal drücken nimmt sie weg")
	_check(light.source_count() == lights_before, "Und das Licht geht mit")
	_check(not map.torches.has(cell), "Auch aus der Karte")

	# 4. Sie übersteht Speichern und Laden — über den echten Weg.
	torches.toggle(cell)
	await _frames(2)
	map.save_user()
	map.torches = []
	MapData.loaded_torches = []
	var reloaded := MapData.load_user()
	_check(not reloaded.is_empty() and MapData.loaded_torches.has(cell),
		"Fackeln überstehen Speichern und Laden (%d gefunden)"
		% MapData.loaded_torches.size())
	map.torches = [cell]
	torches.toggle(cell)
	await _frames(2)

	# 5. Zoom: genau drei Stufen, alle ganzzahlig.
	var crooked: Array[String] = []
	for z: float in Config.ZOOM_STEPS:
		if not is_equal_approx(z, floorf(z)):
			crooked.append("%.2f" % z)
	_check(crooked.is_empty(),
		"Jede Zoomstufe ist ganzzahlig — sonst wären die Pixel wieder krumm%s"
		% ("" if crooked.is_empty() else " (%s)" % ", ".join(crooked)))

	var cam: GameCamera = world.camera
	var zoom_before := Settings.zoom
	Settings.zoom = 0
	Settings.changed_and_save()
	await _frames(3)
	var wide := cam.visible_world_rect().size
	Settings.zoom = 2
	Settings.changed_and_save()
	await _frames(3)
	var close := cam.visible_world_rect().size
	_check(is_equal_approx(cam.zoom.x, 3.0) and close.x < wide.x,
		"Näher heran zeigt weniger Welt (%.0f gegen %.0f Pixel breit)" % [close.x, wide.x])

	# 6. Und die Grenzen sind hart: kein Schritt über die Enden hinaus.
	cam.step_zoom(1)
	await _frames(2)
	_check(Settings.zoom == 2, "Über die nächste Stufe hinaus geht es nicht")
	Settings.zoom = 0
	Settings.changed_and_save()
	cam.step_zoom(-1)
	await _frames(2)
	_check(Settings.zoom == 0, "Und unter die weiteste auch nicht")

	Settings.zoom = zoom_before
	Settings.changed_and_save()
	await _frames(4)

# --- Die Figur ----------------------------------------------------------------

## Laufzyklus, Eintauchen und Bodenschatten — an den Bildern selbst geprüft,
## nicht am Code, der sie erzeugt.
func _check_figure(world: Node2D) -> void:
	var frames: Dictionary = world.player._frames

	# 1. Der Laufzyklus ist wirklich ein Zyklus. Bild 0 und 2 sind absichtlich
	#    gleich (die Durchgangsstellung kommt zweimal vor, einmal je Bein), die
	#    beiden Ausschläge müssen sich aber unterscheiden — sonst tritt die
	#    Figur auf der Stelle, ohne dass es jemand am Code sähe.
	var flat: Array[String] = []
	for dir in 3:
		var set: Array = frames["walk"][dir]
		var seen: Array[PackedByteArray] = []
		for f: Texture2D in set:
			var data := f.get_image().get_data()
			if not seen.has(data):
				seen.append(data)
		if seen.size() < 3:
			flat.append("Richtung %d: nur %d Stellungen" % [dir, seen.size()])
	_check(flat.is_empty(), "Der Laufzyklus hat drei verschiedene Stellungen je Richtung%s"
		% ("" if flat.is_empty() else " (%s)" % ", ".join(flat)))

	# 2. Beim Schwimmen ist die Figur EINGETAUCHT, nicht abgeschnitten. Unter
	#    der Wasserlinie muss noch etwas zu sehen sein — sonst steckt sie in
	#    einem gestanzten Loch.
	var under := 0
	var img: Image = (frames["swim"][ActorArt.Dir.DOWN][0] as Texture2D).get_image()
	var line := ActorArt.H - ActorArt.SWIM_SINK
	for y in range(line + 2, ActorArt.H):
		for x in ActorArt.W:
			if img.get_pixel(x, y).a > 0.02:
				under += 1
	_check(under > 40, "Der Körper bleibt unter Wasser zu ahnen (%d Punkte)" % under)

	# Und der Wellenkragen ist ein Ring, keine Linie: keine Bildzeile darf über
	# die ganze Breite durchlaufen.
	var full_rows := 0
	for y in range(line - 4, line + 5):
		var run := 0
		for x in ActorArt.W:
			if img.get_pixel(x, y).a > 0.4:
				run += 1
		if run >= ActorArt.W - 4:
			full_rows += 1
	_check(full_rows == 0, "Der Wellenkragen ist ein Ring, kein Brett (%d durchgehende Reihen)"
		% full_rows)

	# 3. Der Bodenschatten liegt nach unten rechts versetzt — das Licht kommt
	#    in dieser Welt von oben links.
	var shadow: Image = (frames["shadow"] as Texture2D).get_image()
	var sx := 0.0
	var sy := 0.0
	var mass := 0.0
	for y in shadow.get_height():
		for x in shadow.get_width():
			var a := shadow.get_pixel(x, y).a
			sx += (x + 0.5) * a
			sy += (y + 0.5) * a
			mass += a
	_check(mass > 0.0, "Die Figur hat einen Bodenschatten")
	if mass > 0.0:
		var cx := sx / mass - shadow.get_width() * 0.5
		var cy := sy / mass - shadow.get_height() * 0.5
		_check(cx > 0.05 and cy > 0.05,
			"Der Schatten fällt nach unten rechts (%.2f | %.2f)" % [cx, cy])
	await get_tree().process_frame

## Mittlere Zahl der Zeichenaufrufe über 20 Bilder.
func _draw_calls() -> int:
	var total := 0.0
	for i in 20:
		await get_tree().process_frame
		total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return int(round(total / 20.0))

## Mittlere Bildzeit über 30 Bilder in Millisekunden.
func _frame_cost() -> float:
	var total := 0.0
	for i in 30:
		await get_tree().process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS)
	return total / 30.0 * 1000.0

# --- Einstellungen ------------------------------------------------------------

## Jede Einstellung muss wirklich etwas tun — und einen Neustart überleben.
##
## Ein Menü voller Schalter, hinter denen nichts hängt, ist schlimmer als kein
## Menü: es verspricht etwas. Deshalb wird hier nicht geprüft, ob ein Wert
## gespeichert wurde, sondern ob sich das SYSTEM daran ändert, an dem er hängt.
func _check_settings(world: Node2D) -> void:
	var cfg := ConfigFile.new()
	var had := cfg.load(Settings.PATH) == OK

	# 1. Bildratengrenze landet in der Engine.
	var fps_before := Settings.fps_limit
	Settings.fps_limit = 0                       # 30
	Settings.changed_and_save()
	await _frames(2)
	_check(Engine.max_fps == 30, "Bildratengrenze wirkt (Engine.max_fps = %d)" % Engine.max_fps)
	Settings.fps_limit = Graphics.FPS_VALUES.size() - 1   # Unbegrenzt
	Settings.changed_and_save()
	await _frames(2)
	_check(Engine.max_fps == 0, "Unbegrenzt heisst wirklich unbegrenzt (%d)" % Engine.max_fps)

	# 2. Sichtweite lädt wirklich mehr und wieder weniger Chunks.
	var range_before := Settings.render_range
	var loaded_before: int = world.streamer.loaded_count()
	Settings.render_range = 2                     # 7 x 7
	Settings.changed_and_save()
	await _frames(40)
	var want := (2 * Config.LOAD_RADIUS + 1) * (2 * Config.LOAD_RADIUS + 1)
	_check(Config.LOAD_RADIUS == 3, "Sichtweite setzt den Chunk-Radius (%d)" % Config.LOAD_RADIUS)
	_check(world.streamer.loaded_count() == want,
		"Grössere Sichtweite lädt mehr Chunks (%d von %d, vorher %d)"
		% [world.streamer.loaded_count(), want, loaded_before])
	Settings.render_range = 0                     # 3 x 3
	Settings.changed_and_save()
	await _frames(10)
	_check(world.streamer.loaded_count() == 9,
		"Kleinere Sichtweite entlädt sofort (%d)" % world.streamer.loaded_count())
	Settings.render_range = range_before
	Settings.changed_and_save()
	await _frames(40)

	# 3. Wasser auf der einfachsten Stufe zeichnet nichts mehr.
	var water: WaterFx = world.get_node("WaterFx")
	var water_before := Settings.water_detail
	Settings.water_detail = 0
	Settings.changed_and_save()
	water.queue_redraw()
	await _frames(6)
	_check(not Graphics.water_animated() and water.prims == 0,
		"Wasser „Einfach\" zeichnet keine Wirkung mehr (%d Rechtecke)" % water.prims)
	Settings.water_detail = 2
	Settings.changed_and_save()
	_check(Graphics.water_redraw_hz() > Graphics.water_redraw_hz() - 1.0
		and is_equal_approx(Graphics.water_redraw_hz(), 24.0),
		"Wasser „Hoch\" zeichnet wieder mit voller Rate")
	Settings.water_detail = water_before

	# 4. Schatten lassen sich abschalten — an der Figur, nicht nur im Menü.
	Settings.shadows = false
	Settings.changed_and_save()
	await _frames(4)
	_check(not Graphics.shadows_on() and not _player_shadow(world.player).visible,
		"Schatten aus heisst: die Figur wirft keinen mehr")
	Settings.shadows = true
	Settings.changed_and_save()
	await _frames(4)
	_check(_player_shadow(world.player).visible, "Schatten an heisst: er ist wieder da")

	# 5. Alles überlebt einen Neustart. Geprüft wird über den echten Weg:
	#    schreiben, Werte verstellen, neu laden, vergleichen.
	Settings.render_range = 0
	Settings.water_detail = 0
	Settings.fps_limit = 2
	Settings.vsync = false
	Settings.shadows = false
	Settings.save_settings()
	Settings.render_range = 3
	Settings.water_detail = 2
	Settings.fps_limit = 5
	Settings.vsync = true
	Settings.shadows = true
	Settings.load_settings()
	_check(Settings.render_range == 0 and Settings.water_detail == 0
		and Settings.fps_limit == 2 and not Settings.vsync and not Settings.shadows,
		"Einstellungen überleben den Neustart")

	# 6. Das Menü zeigt, was wirklich gilt.
	main._options_menu.refresh()
	await _frames(2)
	var shown: int = main._options_menu._rows["fps"].index
	_check(shown == Settings.fps_limit,
		"Das Menü zeigt den geltenden Wert (%d)" % shown)

	# Aufräumen: alles zurück auf die Voreinstellungen dieser Sitzung.
	Settings.render_range = range_before
	Settings.water_detail = water_before
	Settings.fps_limit = fps_before
	Settings.vsync = true
	Settings.shadows = true
	Settings.changed_and_save()
	if not had:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	await _frames(30)

## Der Bodenschatten der Figur — der erste Sprite2D mit negativem z_index.
func _player_shadow(player: Node) -> Sprite2D:
	for child: Node in player.get_children():
		if child is Sprite2D and (child as Sprite2D).z_index < 0:
			return child as Sprite2D
	return null

# --- Eine Designsprache -------------------------------------------------------

## Alle Oberflächen benutzen wirklich dasselbe Theme.
##
## Das ist kein Geschmacksthema, sondern eine Falle: Godot vererbt ein Theme nur
## entlang der Control-Kette, und JEDE Oberfläche dieses Spiels liegt unter
## einer CanvasLayer, die diese Kette unterbricht. Ein Theme am Fenster wirkt
## deshalb nicht — die Tafeln bekamen still Godots graue Voreinstellung
## (0.1, 0.1, 0.1, 0.6) und waren halb durchsichtig, ohne dass irgendwo ein
## Fehler stand. Diese Prüfung fällt darauf herein, bevor es jemand sieht.
func _check_design_system(world: Node2D) -> void:
	var want: StyleBoxFlat = UiTheme.panel_style()
	var wrong: Array[String] = []
	for entry: Array in [["Hauptmenü", main._main_menu], ["Pause", main._pause_menu],
			["Einstellungen", main._options_menu], ["Rückfrage", main._confirm],
			["Inventar", world.inventory], ["Bauleiste", world.build_bar],
			["HUD", world.hud]]:
		var node: Node = entry[1]
		if node == null:
			wrong.append("%s fehlt" % entry[0])
			continue
		var c := _first_control(node)
		if c == null:
			wrong.append("%s ohne Oberfläche" % entry[0])
			continue
		if c.get_theme_default_font_size() != UiTheme.FONT_BODY:
			wrong.append("%s erbt das Theme nicht" % entry[0])
	_check(wrong.is_empty(), "Jede Oberfläche erbt dasselbe Theme%s"
		% ("" if wrong.is_empty() else " (%s)" % ", ".join(wrong)))

	# Und die Tafeln benutzen wirklich die eigene Fassung, nicht Godots graue.
	var panels: Array[String] = []
	for entry: Array in [["Pause", main._pause_menu], ["Einstellungen", main._options_menu],
			["Rückfrage", main._confirm]]:
		var node: Node = entry[1]
		var pc := _find_node_of_type(node, "PanelContainer")
		if pc == null:
			panels.append("%s ohne Tafel" % entry[0])
			continue
		var sb := (pc as Control).get_theme_stylebox("panel", "PanelContainer")
		if not (sb is StyleBoxFlat) or not (sb as StyleBoxFlat).bg_color.is_equal_approx(want.bg_color):
			panels.append("%s: %s" % [entry[0],
				(sb as StyleBoxFlat).bg_color if sb is StyleBoxFlat else "keine Flächenfassung"])
	_check(panels.is_empty(), "Jede Tafel ist deckend und in der eigenen Fassung%s"
		% ("" if panels.is_empty() else " (%s)" % ", ".join(panels)))

	# Jede Kategorieseite passt in die Fläche, die für sie da ist.
	var overflow: Array = main._options_menu.page_fits()
	_check(overflow.is_empty(), "Jede Einstellungsseite passt in ihre Fläche%s"
		% ("" if overflow.is_empty() else " (%s)" % ", ".join(overflow)))

	# Schaltflächen werden nicht auf Containerbreite gezogen.
	var stretched: Array[String] = []
	for b: Node in _find_all_of_type(main._pause_menu, "UiButton"):
		var btn := b as UiButton
		if btn.size.x > btn.custom_minimum_size.x + 1.0:
			stretched.append(btn.text)
	_check(stretched.is_empty(), "Schaltflächen behalten ihre Breite%s"
		% ("" if stretched.is_empty() else " (%s)" % ", ".join(stretched)))
	await get_tree().process_frame

func _first_control(node: Node) -> Control:
	if node is Control:
		return node as Control
	for child: Node in node.get_children():
		var c := _first_control(child)
		if c != null:
			return c
	return null

func _find_node_of_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child: Node in node.get_children():
		var found := _find_node_of_type(child, type_name)
		if found != null:
			return found
	return null

## Alle Knoten einer ENGINE-Klasse (nicht eines Skripts): `is_class` erfasst
## auch die Ableitungen, ein `PointLight2D` gilt also als `Light2D`.
func _find_all_of_class(node: Node, cls: String) -> Array[Node]:
	var out: Array[Node] = []
	if node.is_class(cls):
		out.append(node)
	for child: Node in node.get_children():
		out.append_array(_find_all_of_class(child, cls))
	return out

func _find_all_of_type(node: Node, script_class: String) -> Array[Node]:
	var out: Array[Node] = []
	if node.get_script() != null and (node.get_script() as Script).get_global_name() == script_class:
		out.append(node)
	for child: Node in node.get_children():
		out.append_array(_find_all_of_type(child, script_class))
	return out

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

	# 3b. Die Leiste liegt UEBER der Welt und laesst sie durch. Ein Feld im
	#     Inventar tut das nicht — dort steht ohnehin ein abgedunkelter
	#     Hintergrund dahinter, und ein durchscheinendes Feld waere dort nur
	#     unruhig. Derselbe Bauteil, zwei Auftraege.
	var bar_slot: ItemSlot = world.build_bar._slots[0]
	var card_slot: ItemSlot = cards[0]
	_check(bar_slot.overlay and not card_slot.overlay,
		"Die Felder der Leiste sind durchscheinend, die des Inventars nicht")
	_check(bar_slot.frame_style().bg_color.a < card_slot.frame_style().bg_color.a,
		"Und das schlaegt auf die Deckkraft durch (%.2f gegen %.2f)"
		% [bar_slot.frame_style().bg_color.a, card_slot.frame_style().bg_color.a])

	# 3c. Zwischen den Feldern liegen Fugen — sonst sind es drei Schaltflaechen
	#     nebeneinander und keine Leiste.
	var lines: Control = world.build_bar._frame.get_node("Trennlinien")
	_check(lines.size.y > 0.0 and lines.gaps.size() == world.build_bar.types.size() - 1,
		"Zwischen den Feldern der Leiste stehen Trennlinien (%d)" % lines.gaps.size())

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
	# 1. Jede belegbare Aktion existiert wirklich und hat eine Eingabe.
	var missing: Array[String] = []
	for entry: Array in Keybinds.ACTIONS:
		var one: String = entry[0]
		if not InputMap.has_action(one) or Config.keys_for(one) == "—":
			missing.append(one)
	_check(missing.is_empty(),
		"Die Steuerungsseite zeigt nur Aktionen, die es gibt%s"
		% ("" if missing.is_empty() else " (fehlt: %s)" % ", ".join(missing)))

	# 2. Die SPIELLOGIK hängt an keiner festen Taste. Das ist der Kern der
	#    freien Belegung: wer `KEY_W` in Welt, Figur oder Kamera stehen lässt,
	#    macht jede Umbelegung zur Lüge.
	#
	#    Geprüft wird Welt, Figur, Kamera und Kern — nicht die Oberfläche. Ein
	#    Menü darf Esc kennen: dass die Abbruchtaste Esc ist, ist eine Regel des
	#    Betriebssystems und keine Spielsteuerung. `keybinds.gd` ist ohnehin
	#    ausgenommen, dort STEHT die Belegung.
	var hard_coded: Array[String] = []
	for path: String in _gd_files("res://src"):
		var logic := path.contains("/world/") or path.contains("/player/") \
			or path.contains("/camera/") or path.contains("/core/")
		if not logic or path.ends_with("keybinds.gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if line.split("#")[0].contains("KEY_"):
				hard_coded.append(path.get_file())
				break
	_check(hard_coded.is_empty(), "Keine feste Taste in der Spiellogik%s"
		% ("" if hard_coded.is_empty() else " (%s)" % ", ".join(hard_coded)))

	# 3. Umbelegen wirkt wirklich — geprüft am echten Weg: belegen, nachsehen,
	#    zurücksetzen.
	var before_text := Config.keys_for("move_up")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_I
	var problem := Keybinds.replace("move_up", 0, ev)
	_check(problem == "" and Config.keys_for("move_up").begins_with("I"),
		"Vorwärts lässt sich auf I legen (%s)" % Config.keys_for("move_up"))
	_check(InputMap.event_is_action(ev, "move_up"), "Und die Engine kennt die neue Taste")

	# Konflikte werden erkannt, statt zwei Aktionen auf eine Taste zu legen.
	var clash := InputEventKey.new()
	clash.physical_keycode = KEY_I
	var refused := Keybinds.add("jump", clash)
	_check(refused != "" and refused.contains("Vorwärts"),
		"Eine schon belegte Taste wird abgelehnt (%s)" % refused)

	# Mehrere Eingaben je Aktion: die zweite bleibt, die letzte lässt sich nicht
	# wegnehmen — eine Aktion ohne Eingabe wäre unerreichbar.
	_check(Keybinds.events_of("move_up").size() >= 2,
		"Eine Aktion trägt mehrere Eingaben (%d)" % Keybinds.events_of("move_up").size())
	while Keybinds.events_of("move_up").size() > 1:
		Keybinds.remove_at("move_up", 0)
	_check(Keybinds.remove_at("move_up", 0) != "",
		"Die letzte Eingabe lässt sich nicht wegnehmen")

	# Und alles geht auf Standard zurück.
	Keybinds.reset_all()
	_check(Config.keys_for("move_up") == before_text,
		"„Standard wiederherstellen\" holt die Auslieferung zurück (%s)"
		% Config.keys_for("move_up"))

	# Gespeichert wird die Belegung wirklich: schreiben, verstellen, neu laden.
	ev = InputEventKey.new()
	ev.physical_keycode = KEY_J
	Keybinds.replace("move_left", 0, ev)
	Settings.save_settings()
	Keybinds.reset_all()
	Settings.load_settings()
	Keybinds.setup()
	_check(Config.keys_for("move_left").begins_with("J"),
		"Die eigene Belegung übersteht einen Neustart (%s)" % Config.keys_for("move_left"))
	Keybinds.reset_all()
	Settings.save_settings()

	# 2. Die Tasten stimmen mit der tatsächlichen Belegung überein.
	_check(Config.keys_for("inventory") == "E", "E öffnet das Inventar")
	_check(Config.keys_for("toggle_grid") == "G", "G schaltet das Raster")
	_check(Config.keys_for("build_place") == "Linke Maustaste", "Links setzt")
	_check(Config.keys_for("build_remove") == "Rechte Maustaste", "Rechts entfernt")
	_check(Config.keys_for("build_slot_3") == "3", "Feld 3 liegt auf der 3")
	_check(Config.keys_for("build_slot_1+build_slot_2+build_slot_3") == "1 2 3",
		"Materialwahl steht als eine Zeile: 1 2 3")
	_check(Config.keys_for("pause") == "Esc", "Pause liegt auf Esc und ist belegbar")
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
		and text.contains("CPU Render") and text.contains("GPU Render")
		and text.contains("1 % low"),
		"Leistungsanzeige nennt FPS, 1 % low, Speicher und beide Renderzeiten")
	# Keine erfundene Auslastung: Godot liefert keine Prozentzahl für Prozessor
	# oder Grafikkarte. Ein Prozentzeichen in EINER Zeile mit „CPU" oder „GPU"
	# wäre also ausgedacht. („1 % low" ist eine Bildrate, keine Auslastung.)
	var fake := false
	for line: String in text.split("\n"):
		if (line.contains("CPU") or line.contains("GPU")) and line.contains("%"):
			fake = true
	_check(not fake, "Keine erfundene Auslastung in Prozent")
	# Auch hier: der Rahmen muss den Inhalt fassen. Vorher lag die letzte Zeile
	# („Speicher 51 MiB") halb ausserhalb.
	var p_panel: Vector2 = perf.panel_size()
	var p_content: Vector2 = perf.content_size()
	_check(p_panel.x + 0.5 >= p_content.x and p_panel.y + 0.5 >= p_content.y,
		"Die Leistungsanzeige passt in ihren Rahmen (%.0f x %.0f für %.0f x %.0f)"
		% [p_panel.x, p_panel.y, p_content.x, p_content.y])
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
	await _frames(20)     # die Anzeige baut ihren Text viermal je Sekunde neu
	var info: String = dbg.text()
	_check(dbg.visible and info.contains("Chunk") and info.contains("Boden"),
		"F3 zeigt Chunk, Feld, Boden und Zustand")
	_check(not info.contains("Höhenstufe"),
		"Keine Höhenstufe mehr in der Entwicklerinfo")
	# Die neuen Angaben: alles, was der Auftrag verlangt und die Engine wirklich
	# misst. Fehlt eine Zeile, fällt es hier auf und nicht erst im Bild.
	var want_rows := ["1 % low", "CPU Render", "GPU Render", "Zeichenaufrufe",
		"Chunks", "Felder im Bild", "Lichtquellen", "Staubpunkte", "Figuren",
		"Spiel", "System", "Grafik", "Fenster",
		"Ansicht", "Massstab", "Kamerazoom", "letzter Chunk", "Uhr"]
	var gaps: Array[String] = []
	for row: String in want_rows:
		if not info.contains(row):
			gaps.append(row)
	_check(gaps.is_empty(), "Die Entwicklerinfo nennt alles Gemessene%s"
		% ("" if gaps.is_empty() else " (fehlt: %s)" % ", ".join(gaps)))
	# Und nichts Erfundenes: keine Auslastung in Prozent.
	var made_up := false
	for line: String in info.split("\n"):
		if (line.contains("CPU") or line.contains("GPU")) and line.contains("%"):
			made_up = true
	_check(not made_up, "Keine erfundene Auslastung in der Entwicklerinfo")

	# Und sie passt in ihren Rahmen. Genau das war kaputt: die Tafel hatte eine
	# feste Grösse, der Text war höher, und die letzten drei Abschnitte standen
	# ungerahmt über der Welt.
	var panel: Vector2 = dbg.panel_size()
	var content: Vector2 = dbg.content_size()
	_check(panel.x + 0.5 >= content.x and panel.y + 0.5 >= content.y,
		"Die Entwicklerinfo passt in ihren Rahmen (%.0f x %.0f für %.0f x %.0f)"
		% [panel.x, panel.y, content.x, content.y])
	# Und auf den Bildschirm. Das Spiel rechnet immer in 1280 x 720, auch auf
	# einem 1366 x 768 grossen Notebook — deshalb reicht diese eine Prüfung.
	var screen := get_viewport().get_visible_rect().size
	_check(dbg.position.x + panel.x <= screen.x and dbg.position.y + panel.y <= screen.y,
		"Und sie passt auf den Bildschirm (%.0f | %.0f + %.0f x %.0f in %.0f x %.0f)"
		% [dbg.position.x, dbg.position.y, panel.x, panel.y, screen.x, screen.y])
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
	# Ein Messdurchlauf wird weggeworfen. Auch nach dem Aufwärmen fällt beim
	# ersten Fenster noch eine Spitze an (zuletzt gemessen: 56 ms statt 17) —
	# Shader-Übersetzung und Texturuploads, die erst hier fällig werden. Eine
	# Zahl, die in der Dokumentation landet, darf davon nicht stammen.
	await _frame_cost()

	var t_still := 0.0
	for i in 30:
		await get_tree().physics_frame
		t_still += Performance.get_monitor(Performance.TIME_PROCESS)
	var ms_still := t_still / 30.0 * 1000.0

	var t_process := 0.0
	var t_physics := 0.0
	var draws := 0.0
	var runs := 60
	var drawn_before := Engine.get_frames_drawn()
	Input.action_press("move_right")
	for i in runs:
		await get_tree().physics_frame
		t_process += Performance.get_monitor(Performance.TIME_PROCESS)
		t_physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	Input.action_release("move_right")
	var drawn := maxi(Engine.get_frames_drawn() - drawn_before, 1)
	var ms_process := t_process / runs * 1000.0

	# Die Physikzeit wird auf EINEN Schritt umgerechnet, nicht auf ein Bild.
	#
	# Godot zählt in TIME_PHYSICS_PROCESS die Zeit ALLER Physikschritte, die in
	# einer Hauptschleifen-Runde gelaufen sind. Auf dieser Maschine dauert ein
	# Bild je nach Auslastung 20 bis 55 ms, und Godot holt die feste Schrittrate
	# nach: mal ein Schritt je Bild, mal drei. Ungeteilt misst die Zahl deshalb
	# die Auslastung der Maschine und nicht die Physik — sie stand bei sonst
	# unverändertem Code einmal bei 4,75 und einmal bei 11,46 ms.
	var steps_per_frame := float(runs) / float(drawn)
	var ms_physics := t_physics / runs * 1000.0 / steps_per_frame
	print("Leistung nach dem Aufwärmen: Stand %.2f ms, Lauf mit Chunk-Laden %.2f ms, physics %.2f ms je Schritt (%.1f Schritte je Bild), Draw-Calls %d" % [
		ms_still, ms_process, ms_physics, steps_per_frame, int(draws / runs)])
	# Gemessen wird auf einem Software-Rasterizer (Xvfb/llvmpipe). Die
	# Prozesszeit hängt dort an der Füllrate und schwankt zwischen Läufen um
	# mehr als das Doppelte — sie wird berichtet, aber nicht bewertet.
	print("Aufschlag der Spielwelt gegenüber dem Menü: %.2f ms (Software-Rasterizer, nur Bericht)"
		% (ms_still - ms_menu))
	var avg_draws := int(draws / runs)
	_check(avg_draws < 120, "Zeichenaufrufe bleiben gebündelt (%d)" % avg_draws)
	_check(ms_physics < 8.0, "Physikzeit je Schritt unter 8 ms (%.2f)" % ms_physics)

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
## Gibt dem Spieler seine Einstellungen zurück. Ein Testlauf darf niemandem
## seine Grafikstufen umstellen.
func _restore_settings() -> void:
	if _had_settings:
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_settings_backup)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))

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
