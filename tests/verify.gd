extends SceneTree

## Abnahmeprüfungen ohne Fenster. Aufruf:
##
##     godot --headless --path . --script res://tests/verify.gd
##
## Beendet sich mit Exit-Code 1, sobald eine Prüfung fehlschlägt — damit lässt
## sich das Ganze unverändert in eine CI hängen.
##
## Geprüft wird: Belegung speichern/laden, Konflikterkennung,
## Standard wiederherstellen, Grafikprofile, Zoomstufen, Fackeln, Waten.

var passed := 0
var failed := 0


func check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("  OK   %s" % name)
	else:
		failed += 1
		print("  FEHL %s" % name)


func _init() -> void:
	print("=== ABNAHME ===")
	_test_keybinds()
	_test_quality()
	_test_world()
	print("=== %d bestanden, %d fehlgeschlagen ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_keybinds() -> void:
	print("[Steuerung]")
	if FileAccess.file_exists(InputActions.CONFIG_PATH):
		DirAccess.remove_absolute(InputActions.CONFIG_PATH)
	InputActions.install()
	check("Standard: move_up hat 2 Eingaben (W + Pfeil hoch)",
		InputActions.events_for("move_up").size() == 2)
	check("Standard: W löst move_up aus",
		InputMap.event_is_action(InputActions.make_key_event(KEY_W), "move_up"))
	check("Standard: Pfeil hoch löst move_up ebenfalls aus",
		InputMap.event_is_action(InputActions.make_key_event(KEY_UP), "move_up"))
	check("Maustaste als Belegung: Linksklick = place_block",
		InputMap.event_is_action(InputActions.make_button_event(MOUSE_BUTTON_LEFT), "place_block"))

	# Auf IJKL umlegen — genau der Fall aus dem Auftrag.
	InputActions.replace_event_at("move_up", 0, InputActions.make_key_event(KEY_I))
	InputActions.replace_event_at("move_down", 0, InputActions.make_key_event(KEY_K))
	InputActions.replace_event_at("move_left", 0, InputActions.make_key_event(KEY_J))
	InputActions.replace_event_at("move_right", 0, InputActions.make_key_event(KEY_L))
	check("Umbelegt: I löst move_up aus",
		InputMap.event_is_action(InputActions.make_key_event(KEY_I), "move_up"))
	check("Umbelegt: W löst move_up NICHT mehr aus",
		not InputMap.event_is_action(InputActions.make_key_event(KEY_W), "move_up"))
	check("Umbelegt: Pfeil hoch funktioniert weiterhin",
		InputMap.event_is_action(InputActions.make_key_event(KEY_UP), "move_up"))

	InputActions.add_event("move_up", InputActions.make_key_event(KEY_T))
	check("Dritte Eingabe hinzugefügt", InputActions.events_for("move_up").size() == 3)
	check("Doppelte Eingabe wird abgelehnt",
		not InputActions.add_event("move_up", InputActions.make_key_event(KEY_T)))

	# Konflikt bewusst erzeugen
	InputActions.add_event("move_down", InputActions.make_key_event(KEY_T))
	check("Konflikt erkannt",
		InputActions.conflicts("move_up", InputActions.make_key_event(KEY_T)).has("move_down"))
	InputActions.remove_event_at("move_down", InputActions.events_for("move_down").size() - 1)
	check("Konflikt nach Entfernen weg",
		InputActions.conflicts("move_up", InputActions.make_key_event(KEY_T)).is_empty())

	# Speichern → alles zerstören → laden
	InputActions.save_to_disk()
	InputActions.reset_all(false)
	check("Nach Zurücksetzen wieder W", InputMap.event_is_action(InputActions.make_key_event(KEY_W), "move_up"))
	InputActions.load_from_disk()
	check("Nach Neustart (Laden) wieder I",
		InputMap.event_is_action(InputActions.make_key_event(KEY_I), "move_up"))
	check("Nach Neustart wieder 3 Eingaben", InputActions.events_for("move_up").size() == 3)

	InputActions.reset_all(true)
	check("Standard wiederherstellen + speichern",
		InputMap.event_is_action(InputActions.make_key_event(KEY_W), "move_up"))
	check("Keine Aktion ohne Belegung", _all_actions_bound())
	# Umschalt+1 darf NICHT zusätzlich als "1" durchgehen (exakter Vergleich).
	var shift_one := InputActions.make_key_event(KEY_MASK_SHIFT | KEY_1)
	check("Umschalt+1 trifft Slot 11",
		InputMap.event_is_action(shift_one, "hotbar_11", true))
	check("Umschalt+1 trifft NICHT auch Slot 1",
		not InputMap.event_is_action(shift_one, "hotbar_1", true))
	check("Schlichtes 1 trifft Slot 1",
		InputMap.event_is_action(InputActions.make_key_event(KEY_1), "hotbar_1", true))


func _all_actions_bound() -> bool:
	for entry in InputActions.ACTIONS:
		if InputActions.events_for(entry.id).is_empty():
			return false
	return true


func _test_quality() -> void:
	print("[Grafikprofile]")
	var q := Quality.new()
	q._ready()
	q.set_profile(Quality.Profile.HIGH, true)
	var high_lights: int = q.get_value("light_max_sources")
	var high_hz: float = q.get_value("light_hz")
	q.set_profile(Quality.Profile.LOW, true)
	check("NIEDRIG hat weniger Lichter als HOCH", int(q.get_value("light_max_sources")) < high_lights)
	check("NIEDRIG rechnet Licht seltener", float(q.get_value("light_hz")) < high_hz)
	check("NIEDRIG senkt die Renderauflösung", float(q.get_value("render_scale")) < 1.0)
	q.set_profile(Quality.Profile.HIGH, true)
	q.dynamic_step = 1
	q._rebuild()
	var s1: int = q.get_value("sparkle_budget")
	check("Sparstufe 1 kürzt zuerst Kosmetik", s1 < int(Quality.PROFILES[Quality.Profile.HIGH].sparkle_budget))
	check("Sparstufe 1 lässt das Licht unangetastet",
		float(q.get_value("light_hz")) == float(Quality.PROFILES[Quality.Profile.HIGH].light_hz))
	q.dynamic_step = 2
	q._rebuild()
	check("Sparstufe 2 vergröbert das Licht", int(q.get_value("light_cells_per_tile")) == 1)
	q.dynamic_step = 3
	q._rebuild()
	check("Sparstufe 3 senkt die Auflösung", float(q.get_value("render_scale")) < 1.0)
	q.set_override("water_animation", true)
	check("Spieler-Einstellung schlägt das Profil", bool(q.get_value("water_animation")))
	# Ohne diese Zusicherung dürfte `get_value()` keinen Schlüssel ohne
	# Ersatzwert nachschlagen: Ein Profil, dem ein Regler fehlt, würde sonst
	# im Spiel abstürzen statt hier aufzufallen.
	var key_sets: Array = []
	for profile in Quality.PROFILES:
		var keys: Array = Quality.PROFILES[profile].keys()
		keys.sort()
		key_sets.append(keys)
	check("Alle Profile kennen dieselben Regler",
		key_sets[0] == key_sets[1] and key_sets[1] == key_sets[2])
	check("Profil ist schon nach _ready() benutzbar", not q.settings.is_empty())

	check("Hardware wird erkannt (CPU)", not String(q.hardware.get("cpu", "")).is_empty())
	# Headless hat keine Grafikkarte — dort wird geprüft, dass die Ausgabe
	# trotzdem sauber bleibt statt eine Zahl zu erfinden.
	if DisplayServer.get_name() == "headless":
		check("Ohne GPU: Hardware-Ausgabe bleibt vollständig", q.hardware_lines().size() >= 4)
	else:
		check("Hardware wird erkannt (GPU)", not String(q.hardware.get("gpu", "")).is_empty())
	check("RAM wird gemeldet", int(q.hardware.get("ram_physical", -1)) > 0)
	q.free()


func _rock_mask(t: Terrain, cell: Vector2i) -> int:
	var b := func(c: Vector2i) -> int:
		return Terrain.GROUP_BITS[t.get_type(c)] if t.in_bounds(c) else Terrain.GROUP_BITS[Terrain.OUTSIDE]
	return Terrain._mask_of(Terrain.B_ROCK,
		b.call(cell + Vector2i(0, -1)), b.call(cell + Vector2i(1, 0)),
		b.call(cell + Vector2i(0, 1)), b.call(cell + Vector2i(-1, 0)),
		b.call(cell + Vector2i(1, -1)), b.call(cell + Vector2i(1, 1)),
		b.call(cell + Vector2i(-1, 1)), b.call(cell + Vector2i(-1, -1)))


func _test_world() -> void:
	print("[Welt]")
	var terrain := Terrain.new()
	terrain.generate_island(777)
	var sim := Simulation.new(terrain)
	check("Zoomstufen sind begrenzt und fest", CameraController.ZOOM_STEPS.size() == 3
		and CameraController.ZOOM_STEPS[0] == 1.0)
	var land := Vector2i.ZERO
	for y in Terrain.H:
		for x in Terrain.W:
			if terrain.get_type(Vector2i(x, y)) == Terrain.T_GRASS:
				land = Vector2i(x, y)
				break
		if land != Vector2i.ZERO:
			break
	check("Fackel auf Land setzbar", sim.place_torch(land))
	check("Fackel nicht doppelt", not sim.place_torch(land))
	check("Fackel als Lichtquelle registriert", sim.torches.size() == 1)
	check("Fackel entfernbar", sim.remove_torch(land))
	var water := Vector2i.ZERO
	for y in Terrain.H:
		for x in Terrain.W:
			if terrain.get_type(Vector2i(x, y)) == Terrain.T_WATER_DEEP:
				water = Vector2i(x, y)
				break
		if water != Vector2i.ZERO:
			break
	check("Fackel nicht auf Wasser", not sim.place_torch(water))
	check("Flachwasser ist durchwatbar", Terrain.is_wadeable(Terrain.T_WATER_SHALLOW))
	check("Tiefwasser ist es nicht", not Terrain.is_wadeable(Terrain.T_WATER_DEEP))
	var before := terrain.version
	terrain.paint_circle(land, 3, Terrain.T_SAND)
	check("Weltversion steigt bei Änderung", terrain.version > before)
	check("Minimap liest dieselben Daten", terrain.types_buffer().size() == Terrain.W * Terrain.H)
	check("Alle 47 Blob-Formen vorhanden", TileShapes.config_count() == 47)
	# Der Kernfall aus dem Auftrag: BLOCK BLOCK LEER BLOCK BLOCK
	var o := Vector2i(20, 20)
	terrain.begin_batch()
	for y in range(0, 6):
		for x in range(0, 6):
			terrain.set_type(o + Vector2i(x, y), Terrain.T_GRASS)
	terrain.flush()
	terrain.begin_batch()
	for y in range(1, 5):
		for x in [1, 2, 4, 5]:
			terrain.set_type(o + Vector2i(x, y), Terrain.T_ROCK)
	terrain.flush()
	var left_mask := _rock_mask(terrain, o + Vector2i(2, 2))
	var right_mask := _rock_mask(terrain, o + Vector2i(4, 2))
	check("Lücke bleibt Lücke: linke Wand hat keinen Ost-Nachbarn",
		not TileShapes.has_bit(left_mask, TileShapes.E))
	check("Lücke bleibt Lücke: rechte Wand hat keinen West-Nachbarn",
		not TileShapes.has_bit(right_mask, TileShapes.W))
	check("Getrennte Wände bekommen verschiedene Formen",
		TileShapes.config_index(left_mask) != TileShapes.config_index(right_mask))
	# Nur diagonaler Kontakt darf keine Verbindung ergeben
	terrain.begin_batch()
	for y in range(0, 4):
		for x in range(0, 4):
			terrain.set_type(o + Vector2i(x, y + 10), Terrain.T_GRASS)
	terrain.set_type(o + Vector2i(0, 10), Terrain.T_ROCK)
	terrain.set_type(o + Vector2i(1, 11), Terrain.T_ROCK)
	terrain.flush()
	check("Diagonalkontakt verbindet nicht",
		not TileShapes.has_bit(_rock_mask(terrain, o + Vector2i(0, 10)), TileShapes.SE))
	# Dieselbe Zelle muss nach erneutem Setzen gleich aussehen
	var coords_before := terrain.get_cell_atlas_coords(o + Vector2i(2, 2))
	terrain.set_type(o + Vector2i(2, 2), Terrain.T_GRASS)
	terrain.set_type(o + Vector2i(2, 2), Terrain.T_ROCK)
	check("Tile-Variante ist deterministisch",
		terrain.get_cell_atlas_coords(o + Vector2i(2, 2)) == coords_before)
	_test_bugfixes(terrain, sim)
	sim.free()
	terrain.free()


## Nachweise für die Fehler, die der Ist-Zustands-Audit im README aufgelistet
## hat. Ohne diese Prüfungen kämen sie beim nächsten Umbau zurück.
func _test_bugfixes(terrain: Terrain, sim: Simulation) -> void:
	print("[Behobene Fehler aus dem Audit]")
	# Ein Fleck festes Land mitten in der Karte, daneben Tiefwasser.
	var home := Vector2i(30, 30)
	terrain.begin_batch()
	for y in range(-4, 5):
		for x in range(-4, 5):
			terrain.set_type(home + Vector2i(x, y), Terrain.T_GRASS)
	for y in range(-4, 5):
		for x in range(6, 12):
			terrain.set_type(home + Vector2i(x, y), Terrain.T_WATER_DEEP)
	terrain.flush()

	check("Dorf gründen gelingt", sim.spawn_tribe(terrain.cell_center(home)))
	var v: Village = sim.villages[sim.villages.size() - 1]

	# Träger kehrt heim, wird von Tiefwasser blockiert.
	var carrier: Settler = sim.settlers[0]
	carrier.state = Settler.State.RETURN
	carrier.carrying = Settler.Carry.FOOD
	carrier.pos = terrain.cell_center(home + Vector2i(5, 0))
	carrier.prev_pos = carrier.pos
	carrier.target = terrain.cell_center(home + Vector2i(11, 0))
	var food_before := v.food
	sim._tick_settler(0)
	check("Blockierter Träger zielt aufs Dorf, nicht ins Nirgendwo",
		carrier.target.distance_to(v.center_pos) < 20.0)
	check("Blockierter Träger bucht seine Last noch nicht ab", v.food == food_before)
	check("Blockierter Träger trägt noch", carrier.carrying == Settler.Carry.FOOD)

	# Ankommen fernab des Dorfes darf nichts einbuchen.
	carrier.pos = terrain.cell_center(home + Vector2i(4, 4))
	carrier.target = carrier.pos
	var faith_before := sim.faith
	sim._on_arrival(carrier)
	check("Fern vom Dorf wird nichts abgebucht", v.food == food_before)
	check("Fern vom Dorf gibt es keinen Glauben", is_equal_approx(sim.faith, faith_before))
	check("Fern vom Dorf bleibt der Zustand RETURN", carrier.state == Settler.State.RETURN)

	# Am Dorf angekommen wird ganz normal abgeliefert.
	carrier.pos = v.center_pos
	sim._on_arrival(carrier)
	check("Am Dorf wird abgeliefert", v.food == food_before + 1)
	check("Am Dorf ist die Last abgegeben", carrier.carrying == Settler.Carry.NONE)

	# Ohne erreichbaren Rohstoff wird heimgelaufen statt auf der Stelle gewürfelt.
	# Dafür eine wirklich ausweglose Lage bauen: alles im Suchradius um das
	# Dorf zu Wasser, und eine einzelne Kachel als Insel für den Siedler.
	terrain.begin_batch()
	for y in range(-18, 19):
		for x in range(-18, 19):
			terrain.set_type(home + Vector2i(x, y), Terrain.T_WATER_DEEP)
	for y in range(-2, 3):
		for x in range(-2, 3):
			terrain.set_type(home + Vector2i(x, y), Terrain.T_GRASS)
	var island := home + Vector2i(12, 0)
	terrain.set_type(island, Terrain.T_GRASS)
	terrain.flush()
	var stuck: Settler = sim.settlers[1]
	stuck.state = Settler.State.SEEK
	stuck.job = Settler.Job.LUMBERJACK   # es gibt hier weit und breit keinen Wald
	stuck.pos = terrain.cell_center(island)
	var target := sim._find_resource_target(stuck)
	check("Auf ausweglosem Fleck kein Ziel auf sich selbst",
		target.distance_to(stuck.pos) > 1.0)
	check("Ohne erreichbares Ziel wird heimgelaufen", target.distance_to(v.center_pos) < 20.0)

	# Terraforming hat Folgen: geflutete Hütten verschwinden.
	terrain.paint_circle(home + Vector2i(2, 2), 1, Terrain.T_GRASS)
	v.huts.append(home + Vector2i(2, 2))
	var huts_before := v.huts.size()
	terrain.paint_circle(home + Vector2i(2, 2), 1, Terrain.T_WATER_DEEP)
	sim._tick_buildings()
	check("Geflutete Hütte verschwindet", v.huts.size() == huts_before - 1)

	# Fackeln überleben eine Flutung ebenfalls nicht.
	terrain.paint_circle(home + Vector2i(-2, -2), 1, Terrain.T_GRASS)
	check("Fackel auf trockenem Grund", sim.place_torch(home + Vector2i(-2, -2)))
	terrain.paint_circle(home + Vector2i(-2, -2), 1, Terrain.T_WATER_DEEP)
	sim._tick_torches()
	check("Geflutete Fackel verschwindet", sim.torches.is_empty())
