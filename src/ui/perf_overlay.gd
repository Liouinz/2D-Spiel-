extends Control
## Kleine Leistungsanzeige, standardmässig aus.
##
## Angezeigt wird nur, was die Engine wirklich misst. Es gibt hier bewusst
## keine „CPU 43 %"-Anzeige: Godot liefert keine Systemauslastung, sondern
## Renderzeiten. Die stehen deshalb auch so beschriftet da. Liefert die Engine
## einen Wert nicht, steht „—" statt einer erfundenen Zahl.
##
## Die Zahlen kommen aus `Perf` — derselben Quelle, aus der sich auch die
## Entwicklerinfo und die automatische Qualitätsanpassung bedienen. Zwei
## Anzeigen, die sich ihre Bildrate getrennt ausrechnen, widersprechen sich
## irgendwann, und dann diskutiert man über Anzeigen statt über Leistung.
##
## Die Tafel misst sich selbst: ihre Höhe kam vorher aus einer festen Zahl, und
## die letzte Zeile („Speicher 51 MiB") lag halb ausserhalb des Rahmens. Eine
## Zahl, die man von Hand nachziehen muss, sobald eine Zeile dazukommt, geht
## irgendwann daneben — hier übernimmt der Container das.

const REFRESH := 0.25          ## Sekunden zwischen zwei Aktualisierungen
const MARGIN := 20             ## Abstand zum Bildschirmrand

var _panel: PanelContainer
var _label: Label
var _accum: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_top = 250

	_panel = PanelContainer.new()
	_panel.name = "Tafel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.07, 0.09, 0.80)
	box.border_color = Color(0.85, 0.80, 0.62, 0.55)
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)

	var pad := MarginContainer.new()
	for side: String in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	for side: String in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 7)
	_panel.add_child(pad)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Palette.UI_TEXT)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	pad.add_child(_label)

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
		"FPS   %d   (ø %.0f)" % [Perf.fps(), Perf.fps_avg()],
		"1 %% low   %.0f" % Perf.low1(),
		"Bildzeit   %.2f ms" % Perf.frame_ms(),
		"CPU Render   %s" % _ms(Perf.cpu_ms()),
		"GPU Render   %s" % _ms(Perf.gpu_ms()),
		"Zeichenaufrufe   %s" % _num(Perf.draw_calls()),
		"Speicher   %s" % _mib(Perf.game_memory()),
	])
	_fit()

## Zieht die Tafel auf ihren Inhalt und hängt sie an die rechte obere Ecke.
func _fit() -> void:
	_panel.reset_size()
	var want := _panel.get_combined_minimum_size()
	_panel.size = want
	size = want
	offset_left = -want.x - MARGIN
	offset_right = -MARGIN
	offset_bottom = offset_top + want.y

## Die Grösse, die die Tafel wirklich einnimmt — für den Selbsttest.
func panel_size() -> Vector2:
	return _panel.size

func content_size() -> Vector2:
	return _panel.get_combined_minimum_size()

static func _num(v: int) -> String:
	return "—" if v <= 0 else "%d" % v

## Millisekunden — oder „—", wenn die Engine hier nichts misst.
##
## Auch eine glatte 0,00 gilt als „nicht gemessen": manche Treiber füllen den
## Zähler nicht, und eine Null sähe aus wie ein echter Messwert.
static func _ms(v: float) -> String:
	return "—" if v <= 0.0 else "%.2f ms" % v

static func _mib(bytes: int) -> String:
	return "—" if bytes <= 0 else "%.0f MiB" % (float(bytes) / 1048576.0)
