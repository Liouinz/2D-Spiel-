class_name Main
extends Node2D

## Einstiegspunkt: baut Welt, Simulation, Render-Ebenen, Licht, Kamera und UI
## zusammen und leitet Eingaben an den aktiven Schnellleisten-Eintrag weiter.
##
## Wichtig: In dieser Datei steht **kein einziger fester Tastencode** mehr.
## Alles läuft über Actions (`place_block`, `hotbar_3`, `toggle_debug` …), die
## im Steuerungs-Menü frei belegbar sind.

const MIN_BRUSH := 1
const MAX_BRUSH := 8

var selected_slot := 0
var brush_radius := 2

var terrain: Terrain
var sim: Simulation
var quality: Quality
var profiler: GameProfiler
var world_render: WorldRender
var water_fx: WaterFx
var fx_glow: FxGlow
var fx_overlay: FxOverlay
var lighting: Lighting
var cam: CameraController
var ui: GameUI

var _painting := false
var _erasing := false
var _counter_timer := 0.0


func _ready() -> void:
	InputActions.install()

	quality = Quality.new()
	quality.name = "Quality"
	add_child(quality)
	quality.auto_select()

	profiler = GameProfiler.new()
	profiler.name = "Profiler"
	add_child(profiler)

	terrain = Terrain.new()
	add_child(terrain)

	sim = Simulation.new(terrain)
	add_child(sim)
	sim.meteor_impact.connect(_on_meteor_impact)

	world_render = WorldRender.new(sim, quality)
	add_child(world_render)

	water_fx = WaterFx.new(terrain, sim, quality)
	add_child(water_fx)

	fx_overlay = FxOverlay.new(sim, quality)
	add_child(fx_overlay)

	lighting = Lighting.new(sim, quality)
	add_child(lighting)

	fx_glow = FxGlow.new(sim, quality)
	add_child(fx_glow)

	cam = CameraController.new()
	cam.position = terrain.world_center()
	cam.set_map_limits(terrain.world_size())
	add_child(cam)
	cam.make_current()

	ui = GameUI.new(self)
	add_child(ui)


## Welt neu würfeln, ohne das Spiel neu zu starten.
func regenerate_world() -> void:
	sim.reset()
	terrain.generate_island()
	cam.position = terrain.world_center()


# --- Eingabe ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _handle_ui_actions(event):
		return
	if ui != null and ui.blocking_input():
		return
	if event.is_action_pressed("place_block"):
		_painting = true
		_apply_tool(get_global_mouse_position(), true)
	elif event.is_action_released("place_block"):
		_painting = false
	elif event.is_action_pressed("remove_block"):
		_erasing = true
		_remove_at(get_global_mouse_position())
	elif event.is_action_released("remove_block"):
		_erasing = false
	elif event is InputEventMouseMotion:
		if _painting:
			_apply_tool(get_global_mouse_position(), false)
		elif _erasing:
			_remove_at(get_global_mouse_position())
	elif event.is_action_pressed("brush_bigger"):
		adjust_brush(1)
	elif event.is_action_pressed("brush_smaller"):
		adjust_brush(-1)
	elif event.is_action_pressed("pause_sim"):
		sim.toggle_pause()
	elif event.is_action_pressed("speed_up"):
		sim.step_speed(1)
	elif event.is_action_pressed("speed_down"):
		sim.step_speed(-1)
	else:
		for i in Items.count():
			# `exact_match = true`: Sonst würde "Umschalt+1" zusätzlich die
			# Action "1" auslösen und immer Slot 1 statt Slot 11 gewinnen.
			if event.is_action_pressed("hotbar_%d" % (i + 1), false, true):
				select_slot(i)
				return


## UI-Actions wirken auch, während ein Menü offen ist.
func _handle_ui_actions(event: InputEvent) -> bool:
	if event.is_action_pressed("pause_menu"):
		ui.toggle_pause_menu()
		return true
	if event.is_action_pressed("toggle_debug"):
		ui.toggle_debug()
		return true
	if event.is_action_pressed("toggle_minimap"):
		ui.toggle_minimap()
		return true
	if event.is_action_pressed("toggle_chronicle"):
		ui.toggle_chronicle()
		return true
	if event.is_action_pressed("toggle_hud"):
		ui.toggle_hud()
		return true
	if event.is_action_pressed("open_inventory"):
		ui.open_settings()
		return true
	return false


func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, Items.count() - 1)
	if ui != null:
		ui.select_slot(selected_slot)


func adjust_brush(delta: int) -> void:
	brush_radius = clampi(brush_radius + delta, MIN_BRUSH, MAX_BRUSH)


# --- Werkzeuge --------------------------------------------------------------

func _apply_tool(world_pos: Vector2, is_click: bool) -> void:
	var item := Items.get_item(selected_slot)
	match item.kind:
		Items.Kind.TERRAIN:
			var cell := terrain.local_to_map(world_pos)
			if terrain.paint_circle(cell, brush_radius, item.type) > 0 and Terrain.is_water(item.type):
				water_fx.add_ripple(terrain.cell_center(cell), 1.0)
		Items.Kind.TORCH:
			if is_click and sim.place_torch(terrain.local_to_map(world_pos)):
				ui.notify("Fackel gesetzt.", Palette.LIGHT_TORCH)
		Items.Kind.TRIBE:
			if is_click:
				sim.spawn_tribe(world_pos)
		Items.Kind.POWER:
			if is_click:
				_cast_power(item.type, world_pos)


func _cast_power(power: int, world_pos: Vector2) -> void:
	match power:
		Items.Power.LIGHTNING:
			if sim.cast_lightning(world_pos):
				fx_glow.add_flash(world_pos)
				lighting.add_burst(world_pos, Palette.FLASH, 320.0, 0.35, 1.2)
				cam.shake(6.0)
				_splash(world_pos, 1.2)
		Items.Power.RAIN:
			sim.cast_rain(world_pos)
		Items.Power.BLESSING:
			if sim.cast_blessing(world_pos):
				fx_glow.add_blessing(world_pos)
		Items.Power.METEOR:
			sim.cast_meteor(world_pos)


## Rechtsklick: Fackel aufnehmen, sonst Bewuchs entfernen (Wald/Fels → Gras,
## Wasser → Sand). Das ist die „Abriss“-Seite des Bausystems.
func _remove_at(world_pos: Vector2) -> void:
	var cell := terrain.local_to_map(world_pos)
	if not terrain.in_bounds(cell):
		return
	if sim.remove_torch(cell):
		return
	terrain.begin_batch()
	var radius := brush_radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var target := cell + Vector2i(dx, dy)
			if not terrain.in_bounds(target):
				continue
			match terrain.get_type(target):
				Terrain.T_FOREST, Terrain.T_ROCK, Terrain.T_LAVA:
					terrain.set_type(target, Terrain.T_GRASS)
				Terrain.T_WATER_DEEP, Terrain.T_WATER_SHALLOW:
					terrain.set_type(target, Terrain.T_SAND)
	terrain.update_shorelines(cell, radius + 2)
	terrain.flush()


func _splash(world_pos: Vector2, strength: float) -> void:
	water_fx.add_ripple(world_pos, strength)


func _on_meteor_impact(world_pos: Vector2) -> void:
	cam.shake(14.0)
	fx_glow.add_impact(world_pos)
	lighting.add_burst(world_pos, Palette.IMPACT_OUTER, 260.0, 0.7, 1.4)
	_splash(world_pos, 1.4)


# --- Messwerte für das Entwickler-Overlay -----------------------------------

func _process(delta: float) -> void:
	# Sicherheitsnetz gegen "hängenden Pinsel": Wird die Taste über einem
	# UI-Panel oder ausserhalb des Fensters losgelassen, sieht
	# `_unhandled_input` das Loslassen nie. Deshalb hier gegen den echten
	# Tastenzustand abgleichen.
	if _painting and not Input.is_action_pressed("place_block"):
		_painting = false
	if _erasing and not Input.is_action_pressed("remove_block"):
		_erasing = false
	_counter_timer -= delta
	if _counter_timer > 0.0:
		return
	_counter_timer = 0.2
	var view := cam.visible_world_rect()
	var tiles_x := int(ceil(view.size.x / Terrain.TILE)) + 1
	var tiles_y := int(ceil(view.size.y / Terrain.TILE)) + 1
	var chunk := Vector2i(int(floor(cam.position.x / (Terrain.TILE * 16))), int(floor(cam.position.y / (Terrain.TILE * 16))))
	profiler.set_counter("camera_pos", "%d, %d" % [int(cam.position.x), int(cam.position.y)])
	profiler.set_counter("camera_chunk", "%d, %d" % [chunk.x, chunk.y])
	profiler.set_counter("zoom_percent", cam.zoom_percent())
	profiler.set_counter("tiles_visible", tiles_x * tiles_y)
	profiler.set_counter("chunks_visible", int(ceil(tiles_x / 16.0)) * int(ceil(tiles_y / 16.0)))
	profiler.set_counter("chunks_total", int(ceil(Terrain.W / 16.0)) * int(ceil(Terrain.H / 16.0)))
	profiler.set_counter("tile_layers", 4)
	profiler.set_counter("settlers", sim.settlers.size())
	profiler.set_counter("settlers_drawn", world_render.drawn_entities())
	profiler.set_counter("villages", sim.villages.size())
	profiler.set_counter("villages_drawn", world_render.drawn_villages())
	profiler.set_counter("huts", sim.total_huts())
	profiler.set_counter("huts_drawn", world_render.drawn_huts())
	profiler.set_counter("torches", sim.torches.size())
	profiler.set_counter("particles", fx_glow.particle_count() + fx_overlay.particle_count())
	profiler.set_counter("ripples", water_fx.ripple_count())
	profiler.set_counter("fish", water_fx.fish_count())
	profiler.set_counter("light_sources", lighting.active_sources())
	profiler.set_counter("light_sources_found", lighting.found_sources())
	profiler.set_counter("lightmap_cells", lighting.lightmap_cells())
	profiler.set_counter("lightmap_ms", "%.2f" % lighting.last_update_ms)
	profiler.set_counter("lightmap_updates", "%.0f" % lighting.updates_per_second)
