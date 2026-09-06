extends Control
## Kleine Leistungsanzeige, standardmässig aus.
##
## Angezeigt wird nur, was die Engine wirklich misst. Es gibt hier bewusst
## keine „CPU 43 %"-Anzeige: Godot liefert keine Systemauslastung, sondern
## Renderzeiten. Die stehen deshalb auch so beschriftet da. Liefert die Engine
## einen Wert nicht, steht „—" statt einer erfundenen Zahl.

const REFRESH := 0.25          ## Sekunden zwischen zwei Aktualisierungen

var _label: Label
var _accum: float = 0.0
var _vp_rid: RID

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(210, 124)
	offset_left = -230
	offset_right = -20
	offset_top = 250
	offset_bottom = 374

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 8
	_label.offset_top = 6
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Palette.UI_TEXT)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_label)

	# Ohne dieses Einschalten liefert die Engine keine Renderzeiten.
	var vp := get_viewport()
	if vp != null:
		_vp_rid = vp.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < REFRESH:
		return
	_accum = 0.0
	refresh()

func refresh() -> void:
	if _label == null:
		return
	_label.text = "\n".join([
		"FPS   %d" % Engine.get_frames_per_second(),
		"Speicher   %s" % _mib(OS.get_static_memory_usage()),
		"CPU Render   %s" % _ms(_cpu_ms()),
		"GPU Render   %s" % _ms(_gpu_ms()),
		"Zeichenaufrufe   %s" % _count(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	])
	queue_redraw()

func _cpu_ms() -> float:
	return RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) if _vp_rid.is_valid() else -1.0

func _gpu_ms() -> float:
	return RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid) if _vp_rid.is_valid() else -1.0

## Millisekunden — oder „—", wenn die Engine hier nichts misst.
##
## Auch eine glatte 0,00 gilt als „nicht gemessen": manche Treiber füllen den
## Zähler nicht, und eine Null sähe aus wie ein echter Messwert.
static func _ms(v: float) -> String:
	return "—" if v <= 0.0 else "%.2f ms" % v

static func _mib(bytes: int) -> String:
	return "%.0f MiB" % (float(bytes) / 1048576.0)

## Zähler, die manche Treiber nicht füllen: dann lieber „—" als eine Null, die
## nach „nichts los" aussieht.
static func _count(monitor: int) -> String:
	var v := Performance.get_monitor(monitor)
	return "—" if v <= 0.0 else "%d" % int(v)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 0.72), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.80, 0.62, 0.55), false, 2.0)
