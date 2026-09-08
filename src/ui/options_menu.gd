extends UiScreen
## Einstellungen, nach Themen sortiert.
##
## Links die Kategorien, rechts die Seite dazu. Vier Kategorien, nicht fünf:
## „Ton" bestand aus einem einzigen Regler und war eine fast leere Seite — ein
## Thema, das aus einer Zeile besteht, ist kein Thema, sondern eine Zeile.
## Die Musik steht jetzt bei „Allgemein".
##
## Jede Zeile ist ein Streifen über die ganze Seitenbreite: Beschriftung links,
## Auswahl rechts. Das ist nicht Zierde. Vorher lagen die Zeilen als schmale
## Tabelle mitten in der Fläche, jede Seite fing an einer anderen Stelle an, und
## rechts blieb totes Feld — beim Wechsel der Kategorie sprang alles. Streifen
## über die volle Breite haben auf jeder Seite dieselben Kanten.
##
## Auch Schalter sind Auswahlen („Aus / An") statt Kästchen. Dadurch sieht die
## Seite gleich aus, statt nach drei verschiedenen Bedienelementen.
##
## Es steht hier NICHTS, was nicht wirkt. Jede Zeile hängt an einem Wert in
## `Settings`, den `Graphics` oder `Audio` anwendet, und jede Änderung wird
## sofort gespeichert.

signal back_pressed

## Die Seitenfläche ist fest: eine Tafel, die beim Wechsel der Kategorie ihre
## Größe ändert, springt vor den Augen. Die Bildratenzeile mit ihren sieben
## Stufen bestimmt die Breite, die Grafikseite mit ihren sieben Zeilen die
## Höhe — der Selbsttest misst beides nach.
const PAGE_SIZE := Vector2(636, 400)
const RAIL_W := 176
const RAIL_H := 38

const ROW_GAP := 4
const KEY_W := 150          ## Tastenspalte der Steuerungsübersicht

var _rail: VBoxContainer
var _pages: VBoxContainer
var _page_list: Array[Control] = []
var _tabs: Array[UiButton] = []
var _page: int = 0
var _fade: float = 1.0

var _music: HSlider
var _music_value: Label
var _rows: Dictionary = {}      ## Name -> UiChoice, für refresh()

func _build() -> void:
	add_heading("EINSTELLUNGEN")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiTheme.SPACE_L)
	content.add_child(body)

	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", UiTheme.SPACE_XS)
	body.add_child(_rail)

	# Eine senkrechte Linie trennt Kategorien und Inhalt — mehr braucht es nicht.
	var divider := ColorRect.new()
	divider.color = Color(UiTheme.LINE, 0.7)
	divider.custom_minimum_size = Vector2(1, PAGE_SIZE.y)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(divider)

	# Die Seite steht OHNE eigenen Rahmen auf der Tafel.
	#
	# Vorher lag sie in einem zweiten Kasten. Der muss so hoch sein wie die
	# längste Kategorie, und auf einer Seite mit drei Zeilen war er zu zwei
	# Dritteln leer — ein sichtbar leerer Kasten liest sich als unfertig. Ohne
	# Rahmen sind die Zeilen selbst die Struktur, und der Platz darunter ist
	# einfach Rand. Die feste Grösse bleibt: sie hält die Tafel ruhig, wenn man
	# die Kategorie wechselt.
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_left", UiTheme.SPACE_M)
	holder.custom_minimum_size = PAGE_SIZE
	body.add_child(holder)
	_pages = VBoxContainer.new()
	holder.add_child(_pages)

	_add_page("ALLGEMEIN", _page_general())
	_add_page("GRAFIK", _page_video())
	_add_page("LEISTUNG", _page_perf())
	_add_page("STEUERUNG", _page_controls())
	_show_page(0)

	content.add_child(UiTheme.gap(UiTheme.SPACE_S))
	add_button("ZURÜCK", func() -> void: back_pressed.emit())

func _add_page(title: String, page: Control) -> void:
	var index := _page_list.size()
	var tab := UiTheme.button(title).sized(RAIL_W, RAIL_H)
	tab.toggle_mode = true
	tab.pressed.connect(func() -> void: _show_page(index))
	_rail.add_child(tab)
	_tabs.append(tab)

	page.visible = false
	_pages.add_child(page)
	_page_list.append(page)

func _show_page(index: int) -> void:
	_page = clampi(index, 0, _page_list.size() - 1)
	for i in _page_list.size():
		_page_list[i].visible = i == _page
		_tabs[i].set_pressed_no_signal(i == _page)
	# Der Fokus wandert mit. Ohne das leuchtete die zuletzt angeklickte
	# Kategorie UND die mit dem Fokus — zwei hervorgehobene Reiter, von denen
	# nur einer gilt.
	if is_inside_tree() and _tabs[_page].is_inside_tree():
		_tabs[_page].grab_focus()
	# Kurzes Aufblenden beim Wechsel — sonst springt die Seite hart um.
	_fade = 0.0
	set_process(true)

func _process(delta: float) -> void:
	super._process(delta)
	if _fade >= 1.0:
		return
	_fade = minf(_fade + delta / UiTheme.ANIM, 1.0)
	_page_list[_page].modulate.a = UiAnim.ease_t(_fade)
	if _fade < 1.0:
		set_process(true)

# --- Die Seiten --------------------------------------------------------------

func _page_general() -> Control:
	var rows := _rows_box()
	_choice(rows, "hints", "Hinweise im Spiel", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.show_hints else 0,
		func(v: int) -> void: Settings.show_hints = v == 1)
	_choice(rows, "fullscreen", "Vollbild", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.fullscreen else 0,
		func(v: int) -> void: Settings.fullscreen = v == 1)
	rows.add_child(_music_row())
	return _with_note(rows,
		"Die Musik entsteht im Spiel selbst — es gibt keine Tondateien.")

func _page_video() -> Control:
	var rows := _rows_box()
	_choice(rows, "range", "Sichtweite (Chunks)", Graphics.RANGE_LABELS,
		func() -> int: return Settings.render_range,
		func(v: int) -> void: Settings.render_range = v)
	_choice(rows, "water", "Wasser", Graphics.DETAIL,
		func() -> int: return Settings.water_detail,
		func(v: int) -> void: Settings.water_detail = v)
	_choice(rows, "wind", "Bewegung", Graphics.STEPS,
		func() -> int: return Settings.wind,
		func(v: int) -> void: Settings.wind = v)
	_choice(rows, "particles", "Staub in der Luft", Graphics.STEPS,
		func() -> int: return Settings.particles,
		func(v: int) -> void: Settings.particles = v)
	_choice(rows, "decor", "Bewuchs am Boden", Graphics.STEPS,
		func() -> int: return Settings.decor,
		func(v: int) -> void: Settings.decor = v)
	_choice(rows, "light", "Beleuchtung", Graphics.LIGHT,
		func() -> int: return Settings.light,
		func(v: int) -> void: Settings.light = v)
	_choice(rows, "shadows", "Schatten", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.shadows else 0,
		func(v: int) -> void: Settings.shadows = v == 1)
	return _with_note(rows,
		"Eine größere Sichtweite lädt mehr Chunks um die Figur — sie kommen nach und\nnach dazu. „Aus“ kostet wirklich nichts: die Wirkung wird abgehängt.")

func _page_perf() -> Control:
	var rows := _rows_box()
	_choice(rows, "fps", "Bildratengrenze", Graphics.FPS_LABELS,
		func() -> int: return Settings.fps_limit,
		func(v: int) -> void: Settings.fps_limit = v)
	_choice(rows, "vsync", "Bildsynchronisierung", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.vsync else 0,
		func(v: int) -> void: Settings.vsync = v == 1)
	_choice(rows, "perf", "Leistungsanzeige", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.show_perf else 0,
		func(v: int) -> void: Settings.show_perf = v == 1)
	return _with_note(rows,
		"Eine Obergrenze hält die Bildabstände gleichmäßig. Eine Mindest-Bildrate\nkann kein Spiel zusichern — deshalb steht hier keine.")

## Steuerungsübersicht als Tabelle über die volle Seitenbreite.
##
## Die Tasten kommen aus der InputMap, nicht aus einer Liste im Code. Ändert
## sich eine Belegung, ändert sich diese Anzeige mit — hier kann also nie eine
## veraltete oder erfundene Taste stehen.
##
## Abwechselnd hinterlegte Zeilen statt einzelner Streifen: bei dreizehn Zeilen
## wären Streifen mit Abstand zu unruhig, und die Zeilen sind zu flach, um
## einzeln zu wirken.
func _page_controls() -> Control:
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 0)
	var i := 0
	for entry: Array in Config.CONTROL_ROWS:
		table.add_child(_key_row(Config.keys_for(entry[0]), entry[1], i % 2 == 1))
		i += 1
	return _with_note(table, "")

func _key_row(keys: String, what: String, shaded: bool) -> Control:
	var strip := PanelContainer.new()
	if shaded:
		strip.add_theme_stylebox_override("panel",
			UiTheme.box(Color(1, 1, 1, 0.035), Color(0, 0, 0, 0), 0, 4))
	else:
		strip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	strip.add_child(row)

	var key := Label.new()
	key.text = keys
	key.custom_minimum_size = Vector2(KEY_W, 22)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_theme_color_override("font_color", UiTheme.ACCENT)
	key.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	row.add_child(key)

	var text := Label.new()
	text.text = what
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_color", UiTheme.TEXT)
	text.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	row.add_child(text)
	return strip

# --- Bausteine einer Seite ---------------------------------------------------

func _rows_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", ROW_GAP)
	return box

## Eine Einstellungszeile als Streifen über die ganze Breite.
func _strip(label: String, control: Control) -> PanelContainer:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _row_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	strip.add_child(row)

	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", UiTheme.TEXT)
	row.add_child(l)

	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return strip

func _row_style() -> StyleBoxFlat:
	var s := UiTheme.box(Color(0.150, 0.160, 0.190, 0.80), Color(0, 0, 0, 0),
		0, UiTheme.RADIUS_S)
	s.content_margin_left = UiTheme.SPACE_M
	s.content_margin_right = UiTheme.SPACE_M
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

## `read` liefert den geltenden Index, `write` legt ihn ab — danach wird
## gemeldet und gespeichert, für alle Zeilen gleich.
func _choice(rows: VBoxContainer, key: String, label: String, options: Array,
		read: Callable, write: Callable) -> void:
	var choice := UiChoice.new().setup(options, int(read.call()))
	choice.changed.connect(func(v: int) -> void:
		write.call(v)
		Settings.changed_and_save())
	rows.add_child(_strip(label, choice))
	_rows[key] = choice

## Der Musikregler mit seinem Wert daneben. Ein Regler ohne Zahl lässt einen
## raten, wo man gerade steht.
func _music_row() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.SPACE_S)
	_music = HSlider.new()
	_music.min_value = 0.0
	_music.max_value = 1.0
	_music.step = 0.05
	_music.custom_minimum_size = Vector2(260, 24)
	_music.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_music.value_changed.connect(func(v: float) -> void:
		Settings.set_music_volume(v)
		_show_music_value())
	_music.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
	box.add_child(_music)

	_music_value = Label.new()
	_music_value.custom_minimum_size = Vector2(46, 0)
	_music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_music_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_music_value.add_theme_color_override("font_color", UiTheme.ACCENT)
	_music_value.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	box.add_child(_music_value)
	_show_music_value()
	return _strip("Musik", box)

func _show_music_value() -> void:
	if _music_value != null:
		_music_value.text = "%d %%" % int(round(Settings.music_volume * 100.0))

## Setzt den Hinweis direkt unter die Zeilen, auf dieselbe linke Kante wie ihre
## Beschriftungen.
##
## Vorher war er an den Fuss der Seite geheftet. Auf einer Seite mit drei Zeilen
## klaffte dann ein Loch zwischen Inhalt und Hinweis, und der Hinweis stand
## ausserdem sechzehn Bildpunkte weiter links als jede Beschriftung darüber.
## Unter seinem Inhalt gehört er hin; der freie Platz darunter liest sich als
## Rand, das Loch dazwischen las sich als Fehler.
func _with_note(body: Control, note: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.SPACE_M)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	if note != "":
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", UiTheme.SPACE_M)
		var l := UiTheme.text_label(note, UiTheme.FONT_TINY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		pad.add_child(l)
		col.add_child(pad)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler)
	return col

# --- Anzeige nachziehen ------------------------------------------------------

## Der Fokus gehört auf die geltende Kategorie, nicht auf die erste.
func focus_first() -> void:
	if not _tabs.is_empty() and _tabs[_page].is_inside_tree():
		_tabs[_page].grab_focus()

## Passt jede Seite in die Fläche? Der Selbsttest prüft das — eine Seite, die
## überläuft, würde man sonst erst bei der längsten Kategorie bemerken.
func page_fits() -> Array:
	var too_big: Array = []
	for i in _page_list.size():
		var need := _page_list[i].get_combined_minimum_size()
		if need.x > PAGE_SIZE.x or need.y > PAGE_SIZE.y:
			too_big.append("%s (%d x %d)" % [_tabs[i].text, need.x, need.y])
	return too_big

## Wird vor jedem Öffnen aufgerufen: die Anzeige muss zeigen, was wirklich gilt.
func refresh() -> void:
	if _music != null:
		_music.set_value_no_signal(Settings.music_volume)
	_show_music_value()
	_show_row("hints", 1 if Settings.show_hints else 0)
	_show_row("fullscreen", 1 if Settings.fullscreen else 0)
	_show_row("range", Settings.render_range)
	_show_row("water", Settings.water_detail)
	_show_row("wind", Settings.wind)
	_show_row("particles", Settings.particles)
	_show_row("decor", Settings.decor)
	_show_row("light", Settings.light)
	_show_row("shadows", 1 if Settings.shadows else 0)
	_show_row("fps", Settings.fps_limit)
	_show_row("vsync", 1 if Settings.vsync else 0)
	_show_row("perf", 1 if Settings.show_perf else 0)

func _show_row(key: String, value: int) -> void:
	var row: UiChoice = _rows.get(key)
	if row != null:
		row.show_value(value)
