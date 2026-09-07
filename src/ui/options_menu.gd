extends UiScreen
## Einstellungen, nach Themen sortiert.
##
## Links die Kategorien, rechts die Seite dazu. Vorher stand alles in einer
## Spalte untereinander — mit fünf Themen wäre daraus eine Liste geworden, durch
## die man scrollt.
##
## Jede Zeile ist gleich gebaut: Beschriftung links, Auswahl rechts. Auch
## Schalter sind Auswahlen („Aus / An") statt Kästchen — dadurch sieht die ganze
## Seite gleich aus statt nach drei verschiedenen Bedienelementen.
##
## Es steht hier NICHTS, was nicht wirkt. Jede Zeile hängt an einem Wert in
## `Settings`, den `Graphics` oder `Audio` anwendet, und jede Änderung wird
## sofort gespeichert.

signal back_pressed

## Die Seitenfläche ist so groß wie die grösste Seite. Sie ist fest: eine
## Tafel, die beim Wechsel der Kategorie ihre Größe ändert, springt vor den
## Augen. Die Bildratenzeile mit sieben Stufen bestimmt die Breite, die
## Steuerungsübersicht die Höhe — der Selbsttest prüft beides nach.
const PAGE_SIZE := Vector2(660, 312)
const RAIL_W := 176
const RAIL_H := 38
const LABEL_W := 190

var _rail: VBoxContainer
var _pages: VBoxContainer
var _page_list: Array[Control] = []
var _tabs: Array[UiButton] = []
var _page: int = 0
var _fade: float = 1.0

var _music: HSlider
var _rows: Dictionary = {}      ## Name -> UiChoice, für refresh()

func _build() -> void:
	add_heading("EINSTELLUNGEN")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiTheme.SPACE_L)
	content.add_child(body)

	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", UiTheme.SPACE_XS)
	body.add_child(_rail)

	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", _page_frame())
	holder.custom_minimum_size = PAGE_SIZE
	body.add_child(holder)
	_pages = VBoxContainer.new()
	holder.add_child(_pages)

	_add_page("ALLGEMEIN", _page_general())
	_add_page("GRAFIK", _page_video())
	_add_page("LEISTUNG", _page_perf())
	_add_page("STEUERUNG", _page_controls())
	_add_page("TON", _page_audio())
	_show_page(0)

	content.add_child(UiTheme.gap(UiTheme.SPACE_S))
	add_button("ZURÜCK", func() -> void: back_pressed.emit())

## Die Seitenfläche liegt AUF der Tafel, ist also etwas heller als sie. Dunkler
## sah aus wie ein Loch in der Tafel.
func _page_frame() -> StyleBoxFlat:
	var s := UiTheme.box(Color(0.105, 0.115, 0.140, 1.0), UiTheme.LINE,
		UiTheme.BORDER, UiTheme.RADIUS)
	s.content_margin_left = UiTheme.SPACE_L
	s.content_margin_right = UiTheme.SPACE_L
	s.content_margin_top = UiTheme.SPACE_M
	s.content_margin_bottom = UiTheme.SPACE_M
	return s

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
	var grid := _grid()
	_choice(grid, "hints", "Hinweise im Spiel", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.show_hints else 0,
		func(v: int) -> void: Settings.show_hints = v == 1)
	_choice(grid, "fullscreen", "Vollbild", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.fullscreen else 0,
		func(v: int) -> void: Settings.fullscreen = v == 1)
	return _with_note(grid, "Hinweise blenden sich beim Betreten der Welt kurz ein.")

func _page_video() -> Control:
	var grid := _grid()
	_choice(grid, "range", "Sichtweite (Chunks)", Graphics.RANGE_LABELS,
		func() -> int: return Settings.render_range,
		func(v: int) -> void: Settings.render_range = v)
	_choice(grid, "water", "Wasser", Graphics.DETAIL,
		func() -> int: return Settings.water_detail,
		func(v: int) -> void: Settings.water_detail = v)
	_choice(grid, "wind", "Bewegung", Graphics.STEPS,
		func() -> int: return Settings.wind,
		func(v: int) -> void: Settings.wind = v)
	_choice(grid, "particles", "Staub in der Luft", Graphics.STEPS,
		func() -> int: return Settings.particles,
		func(v: int) -> void: Settings.particles = v)
	_choice(grid, "shadows", "Schatten", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.shadows else 0,
		func(v: int) -> void: Settings.shadows = v == 1)
	return _with_note(grid,
		"Eine größere Sichtweite lädt mehr Chunks um die Figur — sie kommen\nnach und nach dazu, das Spiel stockt dabei nicht.")

func _page_perf() -> Control:
	var grid := _grid()
	_choice(grid, "fps", "Bildratengrenze", Graphics.FPS_LABELS,
		func() -> int: return Settings.fps_limit,
		func(v: int) -> void: Settings.fps_limit = v)
	_choice(grid, "vsync", "Bildsynchronisierung", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.vsync else 0,
		func(v: int) -> void: Settings.vsync = v == 1)
	_choice(grid, "perf", "Leistungsanzeige", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.show_perf else 0,
		func(v: int) -> void: Settings.show_perf = v == 1)
	return _with_note(grid,
		"Eine Obergrenze hält die Bildabstände gleichmäßig. Eine Mindest-Bildrate\nkann kein Spiel zusichern — deshalb steht hier keine.")

func _page_audio() -> Control:
	var grid := _grid()
	grid.add_child(_label("Musik"))
	_music = HSlider.new()
	_music.min_value = 0.0
	_music.max_value = 1.0
	_music.step = 0.05
	_music.custom_minimum_size = Vector2(240, 26)
	_music.value_changed.connect(func(v: float) -> void: Settings.set_music_volume(v))
	_music.drag_ended.connect(func(_changed: bool) -> void: Settings.save_settings())
	grid.add_child(_music)
	return _with_note(grid, "Die Musik entsteht im Spiel selbst — es gibt keine Tondateien.")

## Steuerungsübersicht.
##
## Die Tasten kommen aus der InputMap, nicht aus einer Liste im Code. Ändert
## sich eine Belegung, ändert sich diese Anzeige mit — hier kann also nie eine
## veraltete oder erfundene Taste stehen.
func _page_controls() -> Control:
	var rows := GridContainer.new()
	rows.columns = 2
	rows.add_theme_constant_override("h_separation", UiTheme.SPACE_L)
	rows.add_theme_constant_override("v_separation", 2)
	for entry: Array in Config.CONTROL_ROWS:
		var keys := _label(Config.keys_for(entry[0]), UiTheme.ACCENT)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		keys.custom_minimum_size = Vector2(180, 0)
		keys.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
		rows.add_child(keys)
		var what := _label(entry[1])
		what.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
		rows.add_child(what)
	return _with_note(rows, "")

# --- Bausteine einer Seite ---------------------------------------------------

func _with_note(body: Control, note: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.SPACE_M)
	# Die Seite füllt die Fläche aus. Nur dann kann der Hinweis unten stehen
	# statt direkt unter der letzten Zeile zu kleben.
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(filler)
	if note != "":
		var l := UiTheme.text_label(note, UiTheme.FONT_TINY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(l)
	return col

func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", UiTheme.SPACE_L)
	g.add_theme_constant_override("v_separation", UiTheme.SPACE_M)
	return g

## Eine Einstellungszeile. `read` liefert den geltenden Index, `write` legt ihn
## ab — danach wird gemeldet und gespeichert, für alle Zeilen gleich.
func _choice(grid: GridContainer, key: String, label: String, options: Array,
		read: Callable, write: Callable) -> void:
	grid.add_child(_label(label))
	var choice := UiChoice.new().setup(options, int(read.call()))
	choice.changed.connect(func(v: int) -> void:
		write.call(v)
		Settings.changed_and_save())
	grid.add_child(choice)
	_rows[key] = choice

func _label(text: String, col: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	return l

# --- Anzeige nachziehen ------------------------------------------------------

## Wird vor jedem Öffnen aufgerufen: die Anzeige muss zeigen, was wirklich gilt.
func refresh() -> void:
	if _music != null:
		_music.set_value_no_signal(Settings.music_volume)
	_show_row("hints", 1 if Settings.show_hints else 0)
	_show_row("fullscreen", 1 if Settings.fullscreen else 0)
	_show_row("range", Settings.render_range)
	_show_row("water", Settings.water_detail)
	_show_row("wind", Settings.wind)
	_show_row("particles", Settings.particles)
	_show_row("shadows", 1 if Settings.shadows else 0)
	_show_row("fps", Settings.fps_limit)
	_show_row("vsync", 1 if Settings.vsync else 0)
	_show_row("perf", 1 if Settings.show_perf else 0)

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

func _show_row(key: String, value: int) -> void:
	var row: UiChoice = _rows.get(key)
	if row != null:
		row.show_value(value)
