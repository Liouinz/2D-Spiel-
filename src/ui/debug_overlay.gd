extends Control
## Entwicklerinfo auf F3 — bewusst getrennt von der Leistungsanzeige.
##
## Die Leistungsanzeige beantwortet „läuft es flüssig". Diese hier beantwortet
## „was liegt hier eigentlich, und was kostet es gerade".
##
## ## Die Tafel misst sich selbst
##
## Die erste Fassung hatte eine feste Grösse (452 x 340). Der Text war höher,
## und die letzten drei Abschnitte standen ungerahmt über der Welt — auf einem
## Bildschirmfoto sah das aus, als sei die Anzeige kaputt, und das war sie auch.
##
## Eine feste Zahl kann das nicht lösen: die Höhe hängt an der Schriftgrösse,
## an der Sprache und daran, wie viele Zeilen gerade Sinn ergeben. Deshalb
## steht der Inhalt jetzt in echten Containern, und die Tafel übernimmt deren
## Mindestgrösse. Was hineingeschrieben wird, passt damit immer hinein.
##
## Passt es trotzdem nicht auf den Bildschirm — ein kleines Notebook mit
## 1366 x 768 ist der Fall, für den das gebaut ist —, wird die Schrift eine
## Stufe kleiner. Abschneiden ist keine Antwort.
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
## solange die Anzeige sichtbar ist. Unsichtbar läuft hier gar nichts.

## Sekunden zwischen zwei Aktualisierungen. Zahlen, die sechzigmal je Sekunde
## springen, kann man ohnehin nicht lesen.
const REFRESH := 0.25

## Abstand zum Bildschirmrand. Die Tafel darf nie bis an die Kante stossen.
const MARGIN := 16

## Schriftgrössen von gross nach klein. Passt die Tafel nicht, wird die
## nächste genommen.
const SIZES := [14, 12, 11]

var map: MapData
var player: Player
var streamer: ChunkStreamer
var world: Node2D                ## für Kamera, Licht, Staub

var _panel: PanelContainer
var _left: Label
var _right: Label
var _accum: float = 0.0
var _size_step: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = MARGIN
	offset_top = 150
	visible = false

	_panel = PanelContainer.new()
	_panel.name = "Tafel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _box())
	add_child(_panel)

	var pad := MarginContainer.new()
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	for side: String in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	_panel.add_child(pad)

	# Zwei Spalten: links, was die Welt gerade IST, rechts, was sie KOSTET.
	# Eine einzige lange Liste musste man von oben nach unten absuchen, und auf
	# einem 768 Punkte hohen Bildschirm passte sie ohnehin nicht.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	pad.add_child(cols)
	_left = _column(cols)
	_right = _column(cols)
	_apply_font()

func _box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.07, 0.09, 0.86)
	s.border_color = Color(0.45, 0.85, 0.55, 0.55)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s

func _column(parent: Control) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", Palette.UI_TEXT)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(l)
	return l

func _apply_font() -> void:
	var px: int = SIZES[clampi(_size_step, 0, SIZES.size() - 1)]
	_left.add_theme_font_size_override("font_size", px)
	_right.add_theme_font_size_override("font_size", px)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_info"):
		return
	visible = not visible
	if visible:
		_refresh()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < REFRESH:
		return
	_accum = 0.0
	_refresh()

func _refresh() -> void:
	_left.text = "\n".join(_world_lines())
	_right.text = "\n".join(_cost_lines())
	_fit()

## Zieht die Tafel auf ihren Inhalt — und den Inhalt notfalls auf den
## Bildschirm. Nach jedem Text neu, weil sich die Zeilen ändern können.
func _fit() -> void:
	var room := get_viewport_rect().size - Vector2(MARGIN * 2, offset_top + MARGIN)
	for step in SIZES.size():
		_size_step = step
		_apply_font()
		# Der Container kennt seine Mindestgrösse erst, wenn er neu gerechnet
		# hat; ohne das bleibt beim ersten Bild die alte Zahl stehen.
		_panel.reset_size()
		var want := _panel.get_combined_minimum_size()
		_panel.size = want
		size = want
		if want.x <= room.x and want.y <= room.y:
			return
	# Auch die kleinste Stufe passt nicht: dann lieber schmal und vollständig
	# als breit und abgeschnitten — die Spalten rutschen untereinander.
	_panel.size = _panel.get_combined_minimum_size()

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
		out.append(_row("Chunks geladen", "%d" % streamer.loaded_count()))
		out.append(_row("davon im Bild", "%d" % streamer.visible_count(view)))
		out.append(_row("Kollisionsformen", "%d" % streamer.shape_count()))
		out.append(_row("Felder im Bild", "%d" % _visible_tiles(view)))
		out.append(_row("letzter Chunk", "%.2f ms" % streamer.last_load_msec))

	out.append("")
	out.append("— LICHT —")
	# Diese Zeilen stehen IMMER da, auch bei abgeschalteter Beleuchtung. Eine
	# Anzeige, in der je nach Einstellung Zeilen erscheinen und verschwinden,
	# springt beim Umschalten und man sucht anschliessend die Zeile, die man
	# gerade noch gelesen hat.
	var light := _light()
	var on := light != null and light.active()
	var t_day: float = light.time_of_day() if light != null else 0.0
	out.append(_row("Uhr", "%02d:%02d" % [
		int(t_day * 24.0), int(fposmod(t_day * 1440.0, 60.0))] if on else "—"))
	out.append(_row("Dunkelheit", ("%d %%" % int(light.darkness() * 100.0)) if on else "—"))
	out.append(_row("Lichtquellen", ("%d" % light.source_count()) if light != null else "—"))
	out.append(_row("davon sichtbar", ("%d" % light.lit_count()) if on else "—"))
	out.append(_row("Lichtrechnung", ("%.3f ms" % light.update_msec()) if on else "—"))
	return out

func _state() -> String:
	if player.is_swimming():
		return "schwimmt"
	if player.is_jumping():
		return "springt"
	return "steht" if player.velocity.length() < 6.0 else "läuft"

# --- Rechte Spalte: was es kostet ---------------------------------------------

func _cost_lines() -> Array[String]:
	var out: Array[String] = ["— RENDERING —"]
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
	out.append(_row("Fackeln", "%d" % _torches()))

	out.append("")
	out.append("— SPEICHER —")
	out.append(_row("Spiel", _mib(Perf.game_memory())))
	out.append(_row("Grafik", _mib(Perf.video_memory())))
	out.append(_row("davon Texturen", _mib(Perf.texture_memory())))
	var mem := Perf.system_memory()
	out.append(_row("System frei", _gib(int(mem.get("available", -1)))))
	out.append(_row("System gesamt", _gib(int(mem.get("physical", -1)))))

	out.append("")
	out.append("— ANZEIGE —")
	var win := DisplayServer.window_get_size()
	var vp := Vector2i(get_viewport().get_visible_rect().size)
	out.append(_row("Fenster", "%d x %d" % [win.x, win.y]))
	out.append(_row("Ansicht", "%d x %d" % [vp.x, vp.y]))
	# Der Bildmassstab ist bei Streckmodus „viewport" genau dieses Verhältnis —
	# gerechnet, nicht geraten.
	out.append(_row("Massstab", "%.2fx" % (float(win.x) / maxf(float(vp.x), 1.0))))
	out.append(_row("Kamerazoom", "%.0fx" % _zoom()))
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
	return world.camera.zoom.x if is_instance_valid(world) \
		and is_instance_valid(world.camera) else 1.0

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

func _torches() -> int:
	return world.torches.count() if is_instance_valid(world) \
		and is_instance_valid(world.torches) else 0

## Der ganze angezeigte Text — für den Selbsttest, der prüft, was wirklich
## dasteht, statt sich auf die Namen zweier Felder zu verlassen.
func text() -> String:
	return _left.text + "\n" + _right.text

## Die Grösse, die die Tafel gerade wirklich einnimmt. Der Selbsttest vergleicht
## sie mit dem, was der Inhalt braucht — dort ist die Anzeige schon einmal
## übergelaufen, ohne dass es jemandem auffiel.
func panel_size() -> Vector2:
	return _panel.size

func content_size() -> Vector2:
	return _panel.get_combined_minimum_size()

# --- Zeilensatz ---------------------------------------------------------------

## Beschriftung links, Wert an fester Stelle — sonst tanzen die Zahlen, sobald
## eine Beschriftung ein Zeichen länger wird.
static func _row(label: String, value: String) -> String:
	return "%-17s %s" % [label, value]

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
