class_name Hud
extends Control

## Das eigentliche Spiel-HUD: Statusleiste, Schnellleiste mit Item-Icons,
## Chronik, Hinweis-Einblendungen und die Hover-Info zu einzelnen Siedlern.
##
## Die Schnellleiste zeigt pro Slot die *aktuell belegte* Taste an — wer die
## Steuerung umlegt, sieht das sofort auf den Slots.

const MAX_CHRONICLE_LINES := 8
const NOTICE_TTL := 4.0
const HOVER_INTERVAL := 0.1
## Die Statuszeile baut mehrere formatierte Strings. 10×/s reicht dafür
## vollkommen — 60×/s wäre reine Verschwendung.
const STATUS_INTERVAL := 0.1

signal slot_selected(index: int)

var main: Node

var _status: Label
var _hover: Label
var _chronicle_panel: PanelContainer
var _chronicle_label: Label
var _chronicle_lines: Array[String] = []
var _slots: Array[Button] = []
var _slot_keys: Array[Label] = []
var _slot_costs: Array[float] = []
var _notice_box: VBoxContainer
var _notices: Array = []
var _hover_timer := 0.0
var _status_timer := 0.0
var _hotbar: PanelContainer
var _brush_label: Label


func _init(main_ref: Node) -> void:
	main = main_ref


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_status()
	_build_notices()
	# Reihenfolge = Zeichenreihenfolge: die Schnellleiste liegt zuletzt oben,
	# damit sie auf schmalen Fenstern nicht von der Chronik verdeckt wird.
	_build_chronicle()
	_build_hotbar()


# --- Aufbau -----------------------------------------------------------------

func _build_status() -> void:
	var panel := PanelContainer.new()
	UiTheme.place(panel, UiTheme.Place.TOP_LEFT)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(UiTheme.title_label("TERRARIA MUNDI", UiTheme.FONT_BASE))
	_status = UiTheme.text_label("", UiTheme.FONT_BASE)
	box.add_child(_status)
	_hover = UiTheme.text_label("", UiTheme.FONT_SMALL, Palette.UI_ACCENT)
	box.add_child(_hover)


func _build_notices() -> void:
	_notice_box = VBoxContainer.new()
	UiTheme.place(_notice_box, UiTheme.Place.TOP_CENTER, 12)
	_notice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notice_box)


func _build_hotbar() -> void:
	_hotbar = PanelContainer.new()
	UiTheme.place(_hotbar, UiTheme.Place.BOTTOM_CENTER, 10)
	add_child(_hotbar)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_hotbar.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	box.add_child(row)
	for i in Items.count():
		row.add_child(_build_slot(i))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(footer)
	_brush_label = UiTheme.text_label("", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	footer.add_child(_brush_label)


func _build_slot(index: int) -> Control:
	var item := Items.get_item(index)
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(48, 54)
	button.pressed.connect(func(): slot_selected.emit(index))
	button.tooltip_text = "%s\n%s" % [item.name, item.tip]
	if item.cost > 0.0:
		button.tooltip_text += "\nKosten: %d Glaube" % int(item.cost)
	_slot_costs.append(item.cost)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(content)

	var key := UiTheme.text_label("", 9, Palette.UI_TEXT_DIM)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(key)
	_slot_keys.append(key)

	var icon := TextureRect.new()
	icon.texture = Items.build_icon(index)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var label := UiTheme.text_label(item.name, 9, Palette.UI_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(label)

	_slots.append(button)
	return button


func _build_chronicle() -> void:
	_chronicle_panel = PanelContainer.new()
	UiTheme.place(_chronicle_panel, UiTheme.Place.BOTTOM_RIGHT)
	add_child(_chronicle_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_chronicle_panel.add_child(box)
	box.add_child(UiTheme.text_label("CHRONIK", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	_chronicle_label = UiTheme.text_label("Die Welt wartet auf ihre Geschichte.", UiTheme.FONT_SMALL)
	_chronicle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chronicle_label.custom_minimum_size = Vector2(296, 0)
	box.add_child(_chronicle_label)


# --- Aktualisierung ---------------------------------------------------------

## Die Slots zeigen immer die *aktuell* belegte Taste — nach einer Änderung im
## Steuerungs-Menü stimmt die Beschriftung sofort wieder.
func refresh_slot_keys() -> void:
	for i in _slot_keys.size():
		_slot_keys[i].text = InputActions.hint("hotbar_%d" % (i + 1))


func select_slot(index: int) -> void:
	for i in _slots.size():
		_slots[i].button_pressed = i == index


func set_chronicle_visible(value: bool) -> void:
	_chronicle_panel.visible = value


func chronicle_visible() -> bool:
	return _chronicle_panel.visible


func notify(text: String, color: Color = Palette.UI_TEXT) -> void:
	var label := UiTheme.text_label(text, UiTheme.FONT_BASE, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_box.add_child(label)
	_notices.append({"node": label, "ttl": NOTICE_TTL})
	while _notices.size() > 4:
		var oldest: Dictionary = _notices.pop_front()
		oldest.node.queue_free()


func add_chronicle(text: String) -> void:
	_chronicle_lines.append(text)
	while _chronicle_lines.size() > MAX_CHRONICLE_LINES:
		_chronicle_lines.pop_front()
	_chronicle_label.text = "\n".join(_chronicle_lines)


func _process(delta: float) -> void:
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = STATUS_INTERVAL
		_update_status()
	_update_slots()
	for i in range(_notices.size() - 1, -1, -1):
		var n: Dictionary = _notices[i]
		n.ttl -= delta
		var node: Label = n.node
		node.modulate.a = clampf(n.ttl / 1.0, 0.0, 1.0)
		if n.ttl <= 0.0:
			node.queue_free()
			_notices.remove_at(i)
	_hover_timer -= delta
	if _hover_timer <= 0.0:
		_hover_timer = HOVER_INTERVAL
		_update_hover()


func _update_status() -> void:
	var sim: Simulation = main.sim
	var tempo := "Pause" if sim.speed <= 0.0 else "%d×" % int(sim.speed)
	_status.text = "Jahr %d · %s · Glaube %d\nSiedler %d · Dörfer %d · Hütten %d · Fackeln %d\nNahrung %d · Holz %d · Tempo %s" % [
		sim.year, sim.day_phase_name(), int(sim.faith),
		sim.settlers.size(), sim.living_villages(), sim.total_huts(), sim.torches.size(),
		sim.total_food(), sim.total_wood(), tempo,
	]
	_brush_label.text = "%s: %s   ·   %s / %s: Pinsel %d   ·   %s: setzen   %s: entfernen" % [
		Items.item_name(main.selected_slot),
		InputActions.hint("hotbar_%d" % (main.selected_slot + 1)),
		InputActions.hint("brush_smaller"), InputActions.hint("brush_bigger"), main.brush_radius,
		InputActions.hint("place_block"), InputActions.hint("remove_block"),
	]


func _update_slots() -> void:
	var faith: float = main.sim.faith
	for i in _slots.size():
		var affordable := _slot_costs[i] <= 0.0 or faith >= _slot_costs[i]
		_slots[i].modulate = Color.WHITE if affordable else Color(1.0, 0.62, 0.60)


## Nur 10×/Sekunde — die Suche läuft über alle Siedler.
func _update_hover() -> void:
	var mouse: Vector2 = main.get_global_mouse_position()
	var best: Settler = null
	var best_dist := 14.0
	for s in main.sim.settlers:
		var d: float = s.pos.distance_to(mouse)
		if d < best_dist:
			best_dist = d
			best = s
	if best == null:
		var cell: Vector2i = main.terrain.local_to_map(mouse)
		if main.terrain.in_bounds(cell):
			_hover.text = "· %s bei %d,%d" % [Terrain.type_name(main.terrain.get_type(cell)), cell.x, cell.y]
		else:
			_hover.text = ""
		return
	var job := "Sammler" if best.job == Settler.Job.GATHERER else "Holzfäller"
	var age: int = (main.sim.tick_count - best.born_tick) / Simulation.TICKS_PER_YEAR
	var village: Village = main.sim.villages[best.village_id]
	_hover.text = "→ %s (%s, %d Jahre) aus %s" % [best.name, job, age, village.name]
