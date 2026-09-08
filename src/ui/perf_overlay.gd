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
## Die „1 % low" steht bewusst neben der Bildrate: ein Mittelwert von 60 sagt
## nichts darüber, ob zwischendurch Bilder mit 90 ms dabei waren — und genau
## die spürt man.

const REFRESH := 0.25          ## Sekunden zwischen zwei Aktualisierungen

var _label: Label
var _accum: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(226, 150)
	offset_left = -246
	offset_right = -20
	offset_top = 250
	offset_bottom = 400

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
	queue_redraw()

static func _num(v: int) -> String:
	return "—" if v <= 0 else "%d" % v

## Millisekunden — oder „—", wenn die Engine hier nichts misst.
##
## Auch eine glatte 0,00 gilt als „nicht gemessen": manche Treiber füllen den
## Zähler nicht, und eine Null sähe aus wie ein echter Messwert.
static func _ms(v: float) -> String:
	return "—" if v <= 0.0 else "%.2f ms" % v

static func _mib(bytes: int) -> String:
	return "%.0f MiB" % (float(bytes) / 1048576.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 0.72), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.80, 0.62, 0.55), false, 2.0)
