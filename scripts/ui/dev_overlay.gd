class_name DevOverlay
extends PanelContainer

## Entwickler-Overlay (Standard: F3).
##
## Grundsatz: Hier steht **nur, was tatsächlich gemessen werden kann.** Die
## GL-Compatibility-Pipeline liefert z. B. keine GPU-Zeit pro Bild — statt eine
## Zahl zu erfinden, steht dort "n/v". Erfundene Werte wären beim Optimieren
## schlimmer als gar keine.
##
## Das Overlay selbst aktualisiert nur 5×/Sekunde und baut seine Labels genau
## einmal auf; es kostet damit praktisch keine Bildrate.

const REFRESH := 0.2

var profiler: GameProfiler
var quality: Quality
var main: Node

var _left: Label
var _right: Label
var _timer := 0.0


func _init(profiler_ref: GameProfiler, quality_ref: Quality, main_ref: Node) -> void:
	profiler = profiler_ref
	quality = quality_ref
	main = main_ref


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	add_child(columns)
	_left = _make_column(columns)
	_right = _make_column(columns)
	_refresh()


func _make_column(parent: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	label.add_theme_color_override("font_color", Palette.UI_TEXT)
	# Monospace hält die Zahlenspalten ruhig, statt bei jeder Ziffer zu wackeln.
	var mono := ThemeDB.fallback_font
	if mono != null:
		label.add_theme_font_override("font", mono)
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	_refresh()


func _refresh() -> void:
	_left.text = "\n".join(_performance_lines())
	_right.text = "\n".join(_world_lines())


func _performance_lines() -> Array[String]:
	var fps_now := Engine.get_frames_per_second()
	var lines: Array[String] = [
		"── LEISTUNG ────────────────",
		"FPS            %d  (Ø %.1f)" % [fps_now, profiler.fps_avg],
		"Frame          %.2f ms" % profiler.frame_ms,
		"Frame Ø        %.2f ms" % profiler.frame_avg_ms,
		"1 %% Low        %.2f ms" % profiler.frame_low_ms,
		"Spitze         %.2f ms" % profiler.frame_max_ms,
		"CPU _process   %.2f ms" % profiler.process_ms(),
		"CPU _physics   %.2f ms" % profiler.physics_ms(),
		"GPU-Zeit       n/v (GL Compatibility)",
		"",
		"── RENDERING ───────────────",
		"Zeichenaufrufe %d" % profiler.draw_calls(),
		"Objekte        %d" % profiler.render_objects(),
		"Primitive      %d" % profiler.render_primitives(),
		"Auflösung      %s" % _resolution_text(),
		"Render Scale   %d %%" % int(round(quality.render_scale() * 100.0)),
		"Zoom           %d %%" % profiler.counter("zoom_percent", 100),
		"",
		"── SPEICHER ────────────────",
		"Spiel (static) %s" % GameProfiler.format_bytes(profiler.static_mem_bytes()),
		"Video-Speicher %s" % GameProfiler.format_bytes(profiler.video_mem_bytes()),
		"davon Texturen %s" % GameProfiler.format_bytes(profiler.texture_mem_bytes()),
		"RAM verfügbar  %s" % GameProfiler.format_bytes(profiler.ram_available_bytes()),
		"RAM gesamt     %s" % GameProfiler.format_bytes(profiler.ram_physical_bytes()),
		"Nodes / Objekte %d / %d" % [profiler.node_count(), profiler.object_count()],
	]
	return lines


func _world_lines() -> Array[String]:
	var lines: Array[String] = [
		"── WELT ────────────────────",
		"Kamera         %s" % profiler.counter("camera_pos", "—"),
		"Chunk          %s" % profiler.counter("camera_chunk", "—"),
		"Sichtbare Tiles %d" % profiler.counter("tiles_visible", 0),
		"Tilemap-Blöcke  %d von %d" % [profiler.counter("chunks_visible", 0), profiler.counter("chunks_total", 0)],
		"Tile-Ebenen     %d" % profiler.counter("tile_layers", 0),
		"",
		"── EINHEITEN ───────────────",
		"Siedler        %d  (gezeichnet %d)" % [profiler.counter("settlers", 0), profiler.counter("settlers_drawn", 0)],
		"Dörfer         %d  (gezeichnet %d)" % [profiler.counter("villages", 0), profiler.counter("villages_drawn", 0)],
		"Hütten         %d  (gezeichnet %d)" % [profiler.counter("huts", 0), profiler.counter("huts_drawn", 0)],
		"Fackeln        %d" % profiler.counter("torches", 0),
		"Partikel       %d" % profiler.counter("particles", 0),
		"Wellen / Fische %d / %d" % [profiler.counter("ripples", 0), profiler.counter("fish", 0)],
		"",
		"── LICHT ───────────────────",
		"Lichtquellen   %d aktiv von %d im Bild" % [profiler.counter("light_sources", 0), profiler.counter("light_sources_found", 0)],
		"Lightmap       %s Zellen" % profiler.counter("lightmap_cells", 0),
		"Neuberechnung  %s ms (%s×/s, Ziel %.0f Hz)" % [
			profiler.counter("lightmap_ms", "0"), profiler.counter("lightmap_updates", "0"),
			float(quality.get_value("light_hz", 0.0))],
		"Auflösung      %d Zelle(n)/Tile" % int(quality.get_value("light_cells_per_tile", 1)),
		"",
		"── PROFIL ──────────────────",
		"Grafikprofil   %s" % quality.profile_name(),
		"Dynamikstufe   %d %s" % [quality.dynamic_step, "(aktiv)" if quality.dynamic_enabled else "(aus)"],
		"Messfenster    %s" % ("%.1f FPS" % quality.last_window_fps() if quality.dynamic_enabled else "—"),
	]
	lines.append("")
	lines.append("── HARDWARE ────────────────")
	lines.append_array(quality.hardware_lines())
	return lines


func _resolution_text() -> String:
	var viewport := get_viewport()
	if viewport == null:
		return "n/v"
	var render := viewport.get_visible_rect().size
	var window := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i(render)
	return "%dx%d → Fenster %dx%d" % [int(render.x), int(render.y), window.x, window.y]
