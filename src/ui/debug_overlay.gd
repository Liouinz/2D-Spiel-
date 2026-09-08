extends Control
## Entwicklerinfo auf F3 — bewusst getrennt von der Leistungsanzeige.
##
## Die Leistungsanzeige beantwortet „läuft es flüssig". Diese hier beantwortet
## „was liegt hier eigentlich, und was kostet es gerade".
##
## ## Nur Gemessenes
##
## Es steht hier nichts, was nicht wirklich abgefragt wird. Godot liefert keine
## Prozessor- oder Grafikkartenauslastung in Prozent — also steht so etwas hier
## auch nicht, obwohl es gut aussähe. Wo ein Treiber einen Zähler nicht füllt,
## steht ein Strich statt einer Null: eine Null sieht aus wie ein Messwert.
##
## ## Und es kostet selbst fast nichts
##
## Der Text wird viermal je Sekunde neu gebaut, nicht sechzigmal, und nur
## solange die Anzeige sichtbar ist. Unsichtbar läuft hier gar nichts: `_process`
## bricht in der ersten Zeile ab.

## Sekunden zwischen zwei Aktualisierungen. Zahlen, die sechzigmal je Sekunde
## springen, kann man ohnehin nicht lesen.
const REFRESH := 0.25

var map: MapData
var player: Player
var streamer: ChunkStreamer
var world: Node2D                ## für Kamera, Licht, Staub

var _left: Label
var _right: Label
var _accum: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = 20
	offset_top = 150
	custom_minimum_size = Vector2(452, 340)
	size = custom_minimum_size
	visible = false

	# Zwei Spalten: links, was die Welt gerade ist, rechts, was sie kostet.
	# Eine einzige lange Liste musste man von oben nach unten absuchen.
	_left = _column(10)
	_right = _column(238)

func _column(x: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	l.offset_left = x
	l.offset_top = 8
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	l.add_theme_color_override("font_color", Palette.UI_TEXT)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(l)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_info"):
		return
	visible = not visible
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < REFRESH:
		return
	_accum = 0.0
	_refresh()
	queue_redraw()

func _refresh() -> void:
	_left.text = "\n".join(_world_lines())
	_right.text = "\n".join(_cost_lines())

## Der ganze angezeigte Text — für den Selbsttest, der prüft, was wirklich
## dasteht, statt sich auf die Namen zweier Felder zu verlassen.
func text() -> String:
	return _left.text + "\n" + _right.text

# --- Linke Spalte: was die Welt ist -------------------------------------------

func _world_lines() -> Array[String]:
	var out: Array[String] = ["— WELT —"]
	if map == null or not is_instance_valid(player):
		out.append("(keine Welt)")
		return out
	var b := GridOverlay.block_at(player.global_position)
	var c := GridOverlay.chunk_of(b)
	var ic := GridOverlay.block_in_chunk(b)
	var t := map.get_tile(b.x, b.y)
	out.append(_row("Feld", "%d | %d" % [b.x, b.y]))
	out.append(_row("Chunk", "%d | %d   (%d | %d)" % [c.x, c.y, ic.x, ic.y]))
	out.append(_row("Boden", GroundTileSet.NAMES.get(t, "?")))
	out.append(_row("begehbar", "%s%s" % ["nein" if map.is_solid(b.x, b.y) else "ja",
		"   schwimmbar" if map.is_swimmable(b.x, b.y) else ""]))
	out.append(_row("Figur", "%s   %.0f px/s" % [_state(), player.velocity.length()]))
	out.append("")
	out.append("— NACHLADEN —")
	if is_instance_valid(streamer):
		var view := _view_rect()
		out.append(_row("Chunks", "%d geladen, %d im Bild"
			% [streamer.loaded_count(), streamer.visible_count(view)]))
		out.append(_row("Kollision", "%d Formen" % streamer.shape_count()))
		out.append(_row("Felder im Bild", "%d" % _visible_tiles(view)))
		out.append(_row("letzter Chunk", "%.2f ms" % streamer.last_load_msec))
	out.append("")
	out.append("— ZEIT —")
	var light := _light()
	if light != null and light.active():
		var t_day := light.time_of_day()
		out.append(_row("Uhr", "%02d:%02d" % [int(t_day * 24.0), int(fposmod(t_day * 1440.0, 60.0))]))
		out.append(_row("Dunkelheit", "%d %%" % int(light.darkness() * 100.0)))
	else:
		out.append(_row("Uhr", "Beleuchtung aus"))
	return out

func _state() -> String:
	if player.is_swimming():
		return "schwimmt"
	if player.is_jumping():
		return "springt"
	return "steht" if player.velocity.length() < 6.0 else "läuft"

# --- Rechte Spalte: was es kostet ---------------------------------------------

func _cost_lines() -> Array[String]:
	var out: Array[String] = ["— BILD —"]
	out.append(_row("FPS", "%d   (ø %.0f)" % [Perf.fps(), Perf.fps_avg()]))
	out.append(_row("1 % low", "%.0f" % Perf.low1()))
	out.append(_row("Bildzeit", "%.2f ms" % Perf.frame_ms()))
	out.append(_row("CPU Render", _ms(Perf.cpu_ms())))
	out.append(_row("GPU Render", _ms(Perf.gpu_ms())))
	out.append(_row("Zeichenaufrufe", _count(Perf.draw_calls())))
	out.append(_row("Objekte im Bild", _count(Perf.render_objects())))
	out.append("")
	out.append("— IM BILD —")
	out.append(_row("Figuren", "%d" % _entities()))
	out.append(_row("Staubpunkte", "%d" % _motes()))
	out.append(_row("Baumarken", "%d" % _marks()))
	var light := _light()
	out.append(_row("Lichtquellen", "%d von %d" % [
		light.lit_count() if light != null else 0,
		light.source_count() if light != null else 0]))
	out.append("")
	out.append("— SPEICHER —")
	out.append(_row("Spiel", _mib(Perf.game_memory())))
	var mem := Perf.system_memory()
	var free: int = int(mem.get("available", -1))
	var total: int = int(mem.get("physical", -1))
	out.append(_row("System", "%s frei von %s" % [_gib(free), _gib(total)]))
	out.append(_row("Grafik", _mib(Perf.video_memory())))
	out.append(_row("davon Texturen", _mib(Perf.texture_memory())))
	out.append("")
	out.append("— ANZEIGE —")
	var win := DisplayServer.window_get_size()
	var vp := Vector2i(get_viewport().get_visible_rect().size)
	out.append(_row("Fenster", "%d x %d" % [win.x, win.y]))
	out.append(_row("Ansicht", "%d x %d" % [vp.x, vp.y]))
	# Der Bildmassstab ist bei Streckmodus „viewport" genau dieses Verhältnis —
	# gerechnet, nicht geraten.
	out.append(_row("Massstab", "%.2fx" % (float(win.x) / maxf(float(vp.x), 1.0))))
	out.append(_row("Kamerazoom", "%.1fx" % _zoom()))
	return out

# --- Zugriffe auf die Welt ----------------------------------------------------

func _light() -> LightManager:
	return world.light if is_instance_valid(world) and world.light != null else null

func _view_rect() -> Rect2:
	if is_instance_valid(world) and is_instance_valid(world.camera):
		return world.camera.visible_world_rect()
	return Rect2()

func _visible_tiles(view: Rect2) -> int:
	if view.size == Vector2.ZERO:
		return 0
	return int(ceil(view.size.x / Config.TILE)) * int(ceil(view.size.y / Config.TILE))

func _zoom() -> float:
	return world.camera.zoom.x if is_instance_valid(world) and is_instance_valid(world.camera) else 1.0

func _entities() -> int:
	if not is_instance_valid(world):
		return 0
	var sorted := world.get_node_or_null("Sorted")
	return sorted.get_child_count() if sorted != null else 0

func _motes() -> int:
	return world.ambient._motes.size() if is_instance_valid(world) \
		and is_instance_valid(world.ambient) else 0

func _marks() -> int:
	return world.build_fx.mark_count() if is_instance_valid(world) \
		and is_instance_valid(world.build_fx) else 0

# --- Zeilensatz ---------------------------------------------------------------

## Beschriftung links, Wert an fester Stelle — sonst tanzen die Zahlen, sobald
## eine Beschriftung ein Zeichen länger wird.
static func _row(label: String, value: String) -> String:
	return "%-15s %s" % [label, value]

## Millisekunden — oder „—", wenn die Engine hier nichts misst. Auch eine
## glatte 0,00 gilt als „nicht gemessen": manche Treiber füllen den Zähler
## nicht, und eine Null sähe aus wie ein echter Messwert.
static func _ms(v: float) -> String:
	return "—" if v <= 0.0 else "%.2f ms" % v

static func _count(v: int) -> String:
	return "—" if v <= 0 else "%d" % v

static func _mib(bytes: int) -> String:
	return "—" if bytes <= 0 else "%.0f MiB" % (float(bytes) / 1048576.0)

static func _gib(bytes: int) -> String:
	return "—" if bytes <= 0 else "%.1f GiB" % (float(bytes) / 1073741824.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 0.80), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.85, 0.55, 0.55), false, 2.0)
	# Trennlinie zwischen den Spalten.
	draw_line(Vector2(228, 8), Vector2(228, size.y - 8), Color(0.45, 0.85, 0.55, 0.25), 1.0)
