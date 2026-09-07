class_name UiChoice
extends Control
## Eine Reihe von Möglichkeiten, von denen genau eine gilt.
##
## Statt eines Aufklappmenüs: alle Stufen stehen nebeneinander, die geltende ist
## hervorgehoben. Man sieht damit auf einen Blick, was es überhaupt gibt und wo
## man gerade steht — bei „Aus / Niedrig / Hoch" oder „30 / 60 / 120" ist das
## deutlich schneller zu erfassen als eine Liste, die man erst öffnen muss.
##
## Auch Schalter laufen hierüber („Aus / An"). Dadurch sehen alle Einstellungen
## gleich aus, statt Kästchen neben Auswahlfeldern zu mischen.
##
## Zustände und Bewegung sind dieselben wie beim Feld im Inventar: ruhig,
## überfahren, gewählt. Ein Menü darf sich nicht anders anfühlen als das
## Inventar.

signal changed(index: int)

const HEIGHT := 32
const GAP := 4
const PAD_X := UiTheme.SPACE_M

var labels: Array[String] = []
var index: int = 0

var _widths: Array[float] = []
var _sel: Array[float] = []      ## Auswahl-Anteil je Feld, animiert
var _hot: Array[float] = []      ## Überfahren-Anteil je Feld, animiert
var _over: int = -1

func setup(options: Array, current: int) -> UiChoice:
	labels.clear()
	for o in options:
		labels.append(str(o))
	index = clampi(current, 0, labels.size() - 1)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_measure()
	for i in labels.size():
		_sel.append(1.0 if i == index else 0.0)
		_hot.append(0.0)
	mouse_exited.connect(func() -> void: _over = -1; set_process(true))
	return self

## Breite je Feld aus der Beschriftung — „Unbegrenzt" braucht mehr Platz als
## „60", und gleich breite Felder würden entweder abschneiden oder gähnen.
func _measure() -> void:
	_widths.clear()
	var font := get_theme_default_font()
	var total := 0.0
	for t: String in labels:
		var w := 44.0
		if font != null:
			w = maxf(w, font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1,
				UiTheme.FONT_SMALL).x + PAD_X * 2.0)
		w = ceilf(w)
		_widths.append(w)
		total += w
	custom_minimum_size = Vector2(total + GAP * maxi(labels.size() - 1, 0), HEIGHT)
	size = custom_minimum_size

func select(i: int, notify: bool = true) -> void:
	var next := clampi(i, 0, labels.size() - 1)
	if next == index:
		return
	index = next
	set_process(true)
	if notify:
		changed.emit(index)

## Setzt die Anzeige auf einen Wert, ohne ihn zu melden — für das Nachziehen
## nach dem Laden der Einstellungen.
func show_value(i: int) -> void:
	index = clampi(i, 0, labels.size() - 1)
	set_process(true)

func _rect_of(i: int) -> Rect2:
	var x := 0.0
	for k in i:
		x += _widths[k] + GAP
	return Rect2(x, 0.0, _widths[i], HEIGHT)

func _at(pos: Vector2) -> int:
	for i in labels.size():
		if _rect_of(i).has_point(pos):
			return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _over
		_over = _at((event as InputEventMouseMotion).position)
		if was != _over:
			set_process(true)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _at((event as InputEventMouseButton).position)
		if hit >= 0:
			grab_focus()
			select(hit)
			accept_event()
	# Mit der Tastatur: links und rechts wandern durch die Stufen. Ohne das
	# wäre das Menü ohne Maus nicht bedienbar.
	elif has_focus() and event.is_action_pressed("ui_left"):
		select(index - 1)
		accept_event()
	elif has_focus() and event.is_action_pressed("ui_right"):
		select(index + 1)
		accept_event()

func _process(delta: float) -> void:
	var step := clampf(delta * UiTheme.STATE_SPEED, 0.0, 1.0)
	var settled := true
	for i in labels.size():
		var want_sel := 1.0 if i == index else 0.0
		var want_hot := 1.0 if i == _over else 0.0
		_sel[i] = lerpf(_sel[i], want_sel, step)
		_hot[i] = lerpf(_hot[i], want_hot, step)
		if absf(_sel[i] - want_sel) > 0.005 or absf(_hot[i] - want_hot) > 0.005:
			settled = false
		else:
			_sel[i] = want_sel
			_hot[i] = want_hot
	if settled:
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	for i in labels.size():
		var r := _rect_of(i)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(UiTheme.RADIUS_S)
		var bg := UiTheme.SURFACE_RAISED
		bg = bg.lerp(UiTheme.SURFACE_HOVER, _hot[i])
		bg = bg.lerp(UiTheme.SURFACE_ACTIVE, _sel[i])
		box.bg_color = bg
		var border := UiTheme.LINE
		border = border.lerp(UiTheme.ACCENT_LINE, _hot[i])
		border = border.lerp(UiTheme.ACCENT, _sel[i])
		box.border_color = border
		box.set_border_width_all(int(round(lerpf(UiTheme.BORDER, UiTheme.BORDER_STRONG, _sel[i]))))
		if _sel[i] > 0.01:
			box.shadow_size = int(round(8.0 * _sel[i]))
			box.shadow_color = Color(UiTheme.ACCENT, 0.28 * _sel[i])
		draw_style_box(box, r)
		if font == null:
			continue
		var col: Color = UiTheme.TEXT_DIM.lerp(UiTheme.TEXT, _hot[i]).lerp(UiTheme.ACCENT, _sel[i])
		var baseline := r.position.y + (r.size.y + font.get_ascent(UiTheme.FONT_SMALL)
			- font.get_descent(UiTheme.FONT_SMALL)) * 0.5
		draw_string(font, Vector2(r.position.x, baseline), labels[i],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FONT_SMALL, col)

	# Fokusrahmen um die ganze Reihe: wer mit der Tastatur unterwegs ist, muss
	# sehen, welche Zeile gerade dran ist.
	if has_focus():
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.border_color = Color(UiTheme.ACCENT, 0.75)
		ring.set_border_width_all(UiTheme.BORDER)
		ring.set_corner_radius_all(UiTheme.RADIUS)
		draw_style_box(ring, Rect2(Vector2(-3, -3), size + Vector2(6, 6)))

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
