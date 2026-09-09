class_name Main
extends Node2D

## Einstiegspunkt: baut Welt, Simulation, Render-Ebenen, Licht, Kamera und UI
## zusammen und leitet Eingaben an das aktive Gottheit-Werkzeug weiter.

enum Tool { GRASS, FOREST, SAND, WATER, ROCK, SETTLE, LIGHTNING, RAIN, BLESS, METEOR }

const TOOL_TO_TERRAIN := {
	Tool.GRASS: Terrain.T_GRASS,
	Tool.FOREST: Terrain.T_FOREST,
	Tool.SAND: Terrain.T_SAND,
	Tool.WATER: Terrain.T_WATER_DEEP,
	Tool.ROCK: Terrain.T_ROCK,
}

var current_tool: int = Tool.GRASS
var brush_radius := 2

var terrain: Terrain
var sim: Simulation
var world_render: WorldRender
var fx_glow: FxGlow
var fx_overlay: FxOverlay
var cam: CameraController
var ui: GameUI

var _painting := false


func _ready() -> void:
	terrain = Terrain.new()
	add_child(terrain)

	sim = Simulation.new(terrain)
	add_child(sim)
	sim.meteor_impact.connect(_on_meteor_impact)

	world_render = WorldRender.new(sim)
	add_child(world_render)

	fx_glow = FxGlow.new(sim)
	add_child(fx_glow)

	fx_overlay = FxOverlay.new(sim)
	add_child(fx_overlay)

	add_child(LightManager.new(sim))

	cam = CameraController.new()
	cam.position = terrain.world_center()
	cam.set_map_limits(terrain.world_size())
	add_child(cam)
	cam.make_current()

	ui = GameUI.new(self)
	add_child(ui)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_painting = true
			_apply_tool(get_global_mouse_position(), true)
		else:
			_painting = false
	elif event is InputEventMouseMotion and _painting:
		_apply_tool(get_global_mouse_position(), false)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _set_tool(Tool.GRASS)
			KEY_2: _set_tool(Tool.FOREST)
			KEY_3: _set_tool(Tool.SAND)
			KEY_4: _set_tool(Tool.WATER)
			KEY_5: _set_tool(Tool.ROCK)
			KEY_6: _set_tool(Tool.SETTLE)
			KEY_7: _set_tool(Tool.LIGHTNING)
			KEY_8: _set_tool(Tool.RAIN)
			KEY_9: _set_tool(Tool.BLESS)
			KEY_0: _set_tool(Tool.METEOR)
			KEY_SPACE: sim.toggle_pause()
			KEY_PLUS, KEY_KP_ADD: adjust_brush(1)
			KEY_MINUS, KEY_KP_SUBTRACT: adjust_brush(-1)


func _set_tool(tool: int) -> void:
	current_tool = tool
	if ui != null:
		ui.sync_tool_buttons()


func adjust_brush(delta: int) -> void:
	brush_radius = clampi(brush_radius + delta, 1, 8)


func _apply_tool(world_pos: Vector2, is_click: bool) -> void:
	match current_tool:
		Tool.GRASS, Tool.FOREST, Tool.SAND, Tool.WATER, Tool.ROCK:
			terrain.paint_circle(terrain.local_to_map(world_pos), brush_radius, TOOL_TO_TERRAIN[current_tool])
		Tool.SETTLE:
			if is_click:
				sim.spawn_tribe(world_pos)
		Tool.LIGHTNING:
			if is_click and sim.cast_lightning(world_pos):
				fx_glow.add_flash(world_pos)
				cam.shake(6.0)
		Tool.RAIN:
			if is_click:
				sim.cast_rain(world_pos)
		Tool.BLESS:
			if is_click and sim.cast_blessing(world_pos):
				fx_glow.add_blessing(world_pos)
		Tool.METEOR:
			if is_click:
				sim.cast_meteor(world_pos)


func _on_meteor_impact(world_pos: Vector2) -> void:
	cam.shake(14.0)
	fx_glow.add_impact(world_pos)
