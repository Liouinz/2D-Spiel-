class_name Main
extends Node2D

## Einstiegspunkt: baut Welt, Simulation, Kamera und UI zusammen und
## leitet Eingaben an das aktive Gottheit-Werkzeug weiter.

enum Tool { GRASS, WATER, SAND, SETTLER, LIGHTNING }

const TOOL_TO_TERRAIN := {
	Tool.GRASS: Terrain.T_GRASS,
	Tool.WATER: Terrain.T_WATER,
	Tool.SAND: Terrain.T_SAND,
}

var current_tool: int = Tool.GRASS
var brush_radius := 2

var terrain: Terrain
var sim: Simulation
var settler_layer: SettlerLayer
var cam: CameraController

var _painting := false


func _ready() -> void:
	terrain = Terrain.new()
	add_child(terrain)

	sim = Simulation.new(terrain)
	add_child(sim)

	settler_layer = SettlerLayer.new(sim)
	add_child(settler_layer)

	cam = CameraController.new()
	cam.position = terrain.world_center()
	add_child(cam)
	cam.make_current()

	add_child(GameUI.new(self))


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
			KEY_2: _set_tool(Tool.WATER)
			KEY_3: _set_tool(Tool.SAND)
			KEY_4: _set_tool(Tool.SETTLER)
			KEY_5: _set_tool(Tool.LIGHTNING)
			KEY_SPACE: sim.toggle_pause()
			KEY_PLUS, KEY_KP_ADD:
				brush_radius = mini(brush_radius + 1, 8)
			KEY_MINUS, KEY_KP_SUBTRACT:
				brush_radius = maxi(brush_radius - 1, 1)


func _set_tool(tool: int) -> void:
	current_tool = tool


func _apply_tool(world_pos: Vector2, is_click: bool) -> void:
	match current_tool:
		Tool.GRASS, Tool.WATER, Tool.SAND:
			terrain.paint_circle(terrain.local_to_map(world_pos), brush_radius, TOOL_TO_TERRAIN[current_tool])
		Tool.SETTLER:
			if is_click:
				sim.spawn_tribe(world_pos)
		Tool.LIGHTNING:
			if is_click:
				sim.strike_lightning(world_pos)
				settler_layer.add_flash(world_pos)
				cam.shake(6.0)
