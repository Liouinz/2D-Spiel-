class_name GameUI
extends CanvasLayer

## Minimalistische UI: Werkzeugleiste, Tempo, Statuszeile und die Chronik —
## das automatisch geschriebene Geschichtsbuch (Vorstufe zum Killer-Feature).

const TOOL_NAMES := ["Gras", "Wasser", "Sand", "Siedler", "Blitz"]
const MAX_CHRONICLE_LINES := 5

var main: Main
var _stats: Label
var _chronicle_label: Label
var _chronicle_lines: Array[String] = []


func _init(main_ref: Main) -> void:
	main = main_ref


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var tools := HBoxContainer.new()
	vbox.add_child(tools)
	for i in TOOL_NAMES.size():
		_add_button(tools, "%d %s" % [i + 1, TOOL_NAMES[i]], main._set_tool.bind(i))

	var speeds := HBoxContainer.new()
	vbox.add_child(speeds)
	_add_button(speeds, "Pause", main.sim.set_speed.bind(0.0))
	_add_button(speeds, "1×", main.sim.set_speed.bind(1.0))
	_add_button(speeds, "3×", main.sim.set_speed.bind(3.0))
	_add_button(speeds, "10×", main.sim.set_speed.bind(10.0))

	_stats = Label.new()
	vbox.add_child(_stats)

	var chronicle_title := Label.new()
	chronicle_title.text = "— Chronik —"
	vbox.add_child(chronicle_title)

	_chronicle_label = Label.new()
	_chronicle_label.text = "Die Welt wartet auf ihre Geschichte."
	vbox.add_child(_chronicle_label)

	main.sim.chronicle.connect(_on_chronicle)


func _process(_delta: float) -> void:
	var sim: Simulation = main.sim
	var tempo := "Pause"
	if sim.speed > 0.0:
		tempo = "%d×" % int(sim.speed)
	_stats.text = "Jahr %d   Siedler %d   Hütten %d   Nahrung %d\nWerkzeug: %s (Tasten 1–5)   Pinsel: %d (+/−)   Tempo: %s (Leertaste)" % [
		sim.year, sim.settlers.size(), sim.huts.size(), sim.food,
		TOOL_NAMES[main.current_tool], main.brush_radius, tempo,
	]


func _on_chronicle(text: String) -> void:
	_chronicle_lines.append(text)
	while _chronicle_lines.size() > MAX_CHRONICLE_LINES:
		_chronicle_lines.pop_front()
	_chronicle_label.text = "\n".join(_chronicle_lines)


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
