class_name GameUI
extends CanvasLayer

## UI in dunkler Holz-Optik: Werkzeugleiste mit Glauben-Kosten, Tempo,
## Statuszeile mit Hover-Info zu einzelnen Siedlern, Chronik-Panel und
## eine live aktualisierte Minimap.

const MAX_CHRONICLE_LINES := 8
const MINIMAP_INTERVAL := 0.5

const TOOL_LABELS := [
	"1 Gras", "2 Wald", "3 Sand", "4 Wasser", "5 Fels",
	"6 Siedler", "7 Blitz (10)", "8 Regen (6)", "9 Segen (8)", "0 Meteor (40)",
]
const TOOL_NAMES := [
	"Gras", "Wald", "Sand", "Wasser", "Fels",
	"Siedler", "Blitz", "Regen", "Segen", "Meteor",
]

const MINIMAP_COLORS := {
	Terrain.T_WATER_DEEP: Color(0.10, 0.24, 0.43),
	Terrain.T_WATER_SHALLOW: Color(0.20, 0.39, 0.63),
	Terrain.T_SAND: Color(0.80, 0.70, 0.47),
	Terrain.T_GRASS: Color(0.33, 0.55, 0.23),
	Terrain.T_FOREST: Color(0.18, 0.36, 0.15),
	Terrain.T_ROCK: Color(0.45, 0.45, 0.47),
	Terrain.T_LAVA: Color(0.95, 0.42, 0.10),
}

var main: Main

var _stats: Label
var _hover: Label
var _chronicle_label: Label
var _chronicle_lines: Array[String] = []
var _tool_buttons: Array[Button] = []
var _power_costs := {6: 10.0, 7: 6.0, 8: 8.0, 9: 40.0}
var _minimap_img: Image
var _minimap_tex: ImageTexture
var _minimap_timer := 0.0


func _init(main_ref: Main) -> void:
	main = main_ref


func _ready() -> void:
	_build_top_left()
	_build_chronicle_panel()
	_build_minimap_panel()
	main.sim.chronicle.connect(_on_chronicle)


func _build_top_left() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _wood_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "TERRARIA MUNDI — Prototyp"
	title.add_theme_color_override("font_color", Color(0.9, 0.78, 0.5))
	vbox.add_child(title)

	var group := ButtonGroup.new()
	var terrain_row := HBoxContainer.new()
	vbox.add_child(terrain_row)
	for i in 5:
		_add_tool_button(terrain_row, i, group)
	_add_button(terrain_row, "Pinsel −", main.adjust_brush.bind(-1))
	_add_button(terrain_row, "Pinsel +", main.adjust_brush.bind(1))

	var power_row := HBoxContainer.new()
	vbox.add_child(power_row)
	for i in range(5, 10):
		_add_tool_button(power_row, i, group)

	var speed_row := HBoxContainer.new()
	vbox.add_child(speed_row)
	_add_button(speed_row, "Pause", main.sim.set_speed.bind(0.0))
	_add_button(speed_row, "1×", main.sim.set_speed.bind(1.0))
	_add_button(speed_row, "3×", main.sim.set_speed.bind(3.0))
	_add_button(speed_row, "10×", main.sim.set_speed.bind(10.0))
	var hint := Label.new()
	hint.text = "  Mausrad: Zoom · Mitte/WASD: Schwenken · Leertaste: Pause"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	speed_row.add_child(hint)

	_stats = Label.new()
	vbox.add_child(_stats)

	_hover = Label.new()
	_hover.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	_hover.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_hover)


func _build_chronicle_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _wood_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "— Chronik —"
	title.add_theme_color_override("font_color", Color(0.9, 0.78, 0.5))
	vbox.add_child(title)

	_chronicle_label = Label.new()
	_chronicle_label.text = "Die Welt wartet auf ihre Geschichte."
	_chronicle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chronicle_label.custom_minimum_size = Vector2(380, 0)
	_chronicle_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_chronicle_label)


func _build_minimap_panel() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _wood_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(panel)

	_minimap_img = Image.create(Terrain.W, Terrain.H, false, Image.FORMAT_RGBA8)
	_minimap_tex = ImageTexture.create_from_image(_minimap_img)
	var rect := TextureRect.new()
	rect.texture = _minimap_tex
	rect.custom_minimum_size = Vector2(Terrain.W, Terrain.H)
	panel.add_child(rect)


func _process(delta: float) -> void:
	_update_stats()
	_update_hover()
	_update_power_buttons()
	_minimap_timer -= delta
	if _minimap_timer <= 0.0:
		_minimap_timer = MINIMAP_INTERVAL
		_update_minimap()


func _update_stats() -> void:
	var sim := main.sim
	var tempo := "Pause"
	if sim.speed > 0.0:
		tempo = "%d×" % int(sim.speed)
	_stats.text = "Jahr %d · %s · Glaube: %d\nSiedler %d · Dörfer %d · Hütten %d · Nahrung %d · Holz %d\nWerkzeug: %s · Pinsel %d · Tempo %s" % [
		sim.year, sim.day_phase_name(), int(sim.faith),
		sim.settlers.size(), sim.living_villages(), sim.total_huts(),
		sim.total_food(), sim.total_wood(),
		TOOL_NAMES[main.current_tool], main.brush_radius, tempo,
	]


func _update_hover() -> void:
	var mouse := main.get_global_mouse_position()
	var best: Settler = null
	var best_dist := 14.0
	for s in main.sim.settlers:
		var d := s.pos.distance_to(mouse)
		if d < best_dist:
			best_dist = d
			best = s
	if best == null:
		_hover.text = ""
		return
	var job := "Sammler" if best.job == Settler.Job.GATHERER else "Holzfäller"
	var age := (main.sim.tick_count - best.born_tick) / Simulation.TICKS_PER_YEAR
	var village: Village = main.sim.villages[best.village_id]
	_hover.text = "→ %s (%s, %d Jahre) aus %s" % [best.name, job, age, village.name]


func _update_power_buttons() -> void:
	for tool_id in _power_costs:
		var affordable: bool = main.sim.faith >= _power_costs[tool_id]
		_tool_buttons[tool_id].modulate = Color.WHITE if affordable else Color(1.0, 0.55, 0.55)


func sync_tool_buttons() -> void:
	_tool_buttons[main.current_tool].button_pressed = true


func _update_minimap() -> void:
	var terrain := main.terrain
	for y in Terrain.H:
		for x in Terrain.W:
			var t := terrain.get_type(Vector2i(x, y))
			_minimap_img.set_pixel(x, y, MINIMAP_COLORS[t])
	for s in main.sim.settlers:
		var cell := terrain.local_to_map(s.pos)
		if terrain.in_bounds(cell):
			_minimap_img.set_pixel(cell.x, cell.y, Color.WHITE)
	for v in main.sim.villages:
		if v.fallen:
			continue
		for dy in 2:
			for dx in 2:
				var p := v.center + Vector2i(dx, dy)
				if terrain.in_bounds(p):
					_minimap_img.set_pixel(p.x, p.y, Color(1.0, 0.85, 0.3))
	_minimap_tex.update(_minimap_img)


func _on_chronicle(text: String) -> void:
	_chronicle_lines.append(text)
	while _chronicle_lines.size() > MAX_CHRONICLE_LINES:
		_chronicle_lines.pop_front()
	_chronicle_label.text = "\n".join(_chronicle_lines)


func _wood_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.07, 0.85)
	style.border_color = Color(0.45, 0.35, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _add_tool_button(parent: Control, tool_id: int, group: ButtonGroup) -> void:
	var button := Button.new()
	button.text = TOOL_LABELS[tool_id]
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(main._set_tool.bind(tool_id))
	if tool_id == main.current_tool:
		button.button_pressed = true
	parent.add_child(button)
	_tool_buttons.append(button)


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(callback)
	parent.add_child(button)
