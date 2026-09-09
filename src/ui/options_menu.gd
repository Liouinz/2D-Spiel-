extends UiScreen
## Einstellungen, nach Themen sortiert.
##
## Links die Kategorien, rechts die Seite dazu. Fünf Kategorien:
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
## Stufen bestimmt die Breite, die Grafikseite mit ihren fünf Zeilen die
## Höhe — der Selbsttest misst beides nach.
const PAGE_SIZE := Vector2(636, 400)
const RAIL_W := 176
const RAIL_H := 38

const ROW_GAP := 4

var _rail: VBoxContainer
var _pages: VBoxContainer
var _page_list: Array[Control] = []
var _tabs: Array[UiButton] = []
var _page: int = 0
var _fade: float = 1.0

var _music: HSlider
var _music_value: Label
var _bind_rows: VBoxContainer
var _bind_note: Label
var _capture_action: String = ""
var _capture_index: int = -1
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
	_add_page("EFFEKTE", _page_effects())
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

## Grafik: was das Bild ausmacht. Ganz oben das Profil — es setzt alle Regler
## auf einen Schlag, und darunter kann man jeden einzeln nachziehen.
func _page_video() -> Control:
	var rows := _rows_box()
	rows.add_child(_profile_row())
	_choice(rows, "range", "Sichtweite (Chunks)", Graphics.RANGE_LABELS,
		func() -> int: return Settings.render_range,
		func(v: int) -> void: Settings.render_range = v)
	_choice(rows, "light", "Beleuchtung", Graphics.LIGHT,
		func() -> int: return Settings.light,
		func(v: int) -> void: Settings.light = v)
	_choice(rows, "daycycle", "Tageszeit", Graphics.DAY,
		func() -> int: return 1 if Settings.day_cycle else 0,
		func(v: int) -> void: Settings.day_cycle = v == 1)
	_choice(rows, "shadows", "Schatten", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.shadows else 0,
		func(v: int) -> void: Settings.shadows = v == 1)
	return _with_note(rows,
		"Die Beleuchtung ist abgestuft, weil ihre Teile unterschiedlich kosten: die"
		+ "\nTönung ist gemessen gratis, erst „Mittel“ und „Hoch“ kosten Füllrate."
		+ "\nWer Bildrate braucht, verliert mit „Einfach“ nicht die Nacht, sondern"
		+ "\nnur die beiden Flächen darüber.")

## Effekte: was sich bewegt und was auf dem Boden liegt. Eigene Seite, damit
## die Grafikseite nicht zu einer Liste aus neun Zeilen wird, durch die man
## sich hindurchlesen muss.
func _page_effects() -> Control:
	var rows := _rows_box()
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
	return _with_note(rows,
		"„Aus“ kostet wirklich nichts: die Wirkung wird abgehängt, nicht auf null\ngerechnet. Der Bewuchs ist eine Kachelschicht und damit fast umsonst.")

## Die Profilzeile. Sie zeigt „Eigene", sobald die Regler zu keinem Profil mehr
## passen — eine gespeicherte „aktuelle Stufe" würde irgendwann „Hoch"
## behaupten, während drei Regler längst von Hand verstellt sind.
func _profile_row() -> Control:
	var labels: Array = Quality.NAMES.duplicate()
	labels.append("Eigene")
	var choice := UiChoice.new().setup(labels, _profile_index())
	choice.changed.connect(func(v: int) -> void:
		if v < Quality.NAMES.size():
			Quality.apply(v)
			Graphics.set_ceiling_from_settings()
			Settings.changed_and_save()
			refresh()
		else:
			# „Eigene" ist ein Zustand, kein Befehl — nichts anwenden.
			choice.show_value(_profile_index()))
	_rows["profile"] = choice
	return _strip("Profil", choice)

func _profile_index() -> int:
	var c := Quality.current()
	return c if c >= 0 else Quality.NAMES.size()

func _page_perf() -> Control:
	var rows := _rows_box()
	_choice(rows, "fps", "Bildratengrenze", Graphics.FPS_LABELS,
		func() -> int: return Settings.fps_limit,
		func(v: int) -> void: Settings.fps_limit = v)
	_choice(rows, "vsync", "Bildsynchronisierung", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.vsync else 0,
		func(v: int) -> void: Settings.vsync = v == 1)
	_choice(rows, "auto", "Automatik", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.auto_quality else 0,
		func(v: int) -> void: Settings.auto_quality = v == 1)
	_choice(rows, "perf", "Leistungsanzeige", Graphics.OFF_ON,
		func() -> int: return 1 if Settings.show_perf else 0,
		func(v: int) -> void: Settings.show_perf = v == 1)
	return _with_note(rows,
		"Die Automatik nimmt eine teure Wirkung weg, wenn es vier Sekunden lang unter\nrund 44 Bilder fällt, und gibt sie zurück, sobald wieder Luft ist — nie mehr,\nals hier eingestellt war. Eine Mindest-Bildrate kann kein Spiel zusichern.")

## Die Steuerungsseite: jede Aktion frei belegbar.
##
## `W` `A` `S` `D` ist hier nur der Auslieferungszustand. Die Spiellogik fragt
## nirgends eine Taste ab, sondern immer eine Aktion — deshalb kann jede
## Belegung auf jede Taste, ohne dass am Spiel etwas geändert werden müsste.
##
## Eine Aktion trägt mehrere Eingaben. Genau so funktionieren WASD und
## Pfeiltasten gleichzeitig: sie liegen auf denselben vier Aktionen.
##
## Bedienung: eine Taste anklicken und die neue drücken. Rechtsklick nimmt eine
## Belegung weg. Eine zweite Schaltfläche je Eintrag zum Löschen hätte die
## Zeile verdoppelt, ohne etwas zu erklären.
func _page_controls() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.SPACE_S)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PAGE_SIZE.x, PAGE_SIZE.y - 74)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_bind_rows = VBoxContainer.new()
	_bind_rows.add_theme_constant_override("separation", 2)
	_bind_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bind_rows)
	_rebuild_binds()

	_bind_note = UiTheme.text_label(_HELP, UiTheme.FONT_TINY)
	_bind_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_bind_note)

	var reset := UiTheme.button("STANDARD WIEDERHERSTELLEN").sized(300, 30)
	reset.pressed.connect(func() -> void:
		Keybinds.reset_all()
		Settings.save_settings()
		_say(_HELP)
		_rebuild_binds())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(reset)
	return col

const _HELP := "Taste anklicken und die neue drücken · Rechtsklick nimmt eine Belegung weg · bis zu drei je Aktion"

## Baut die Zeilenliste neu. Immer ganz, nie stückweise: eine Liste, die an
## einer Stelle nachgezogen wird und an einer anderen nicht, ist der Anfang
## jeder Anzeige, die etwas Falsches behauptet.
func _rebuild_binds() -> void:
	for child: Node in _bind_rows.get_children():
		child.queue_free()
	var i := 0
	for entry: Array in Keybinds.ACTIONS:
		_bind_rows.add_child(_bind_row(entry[0], entry[1], i % 2 == 1))
		i += 1

func _bind_row(action: String, label: String, shaded: bool) -> Control:
	var strip := PanelContainer.new()
	if shaded:
		strip.add_theme_stylebox_override("panel",
			UiTheme.box(Color(1, 1, 1, 0.035), Color(0, 0, 0, 0), 0, 4))
	else:
		strip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_S)
	strip.add_child(row)

	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(176, 28)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	name_label.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	row.add_child(name_label)

	var events := Keybinds.events_of(action)
	for i in events.size():
		row.add_child(_key_button(action, i, Keybinds.describe(events[i])))
	if events.size() < Keybinds.MAX_PER_ACTION:
		row.add_child(_key_button(action, -1, "+"))
	return strip

## Eine Belegung als Schaltfläche. `index` -1 heisst „hier kommt eine dazu".
func _key_button(action: String, index: int, text: String) -> UiButton:
	var b := UiTheme.button(text).sized(112 if index >= 0 else 34, 28, UiTheme.FONT_TINY)
	b.pressed.connect(func() -> void: _start_capture(action, index, b))
	# Rechtsklick nimmt weg. Godots Button meldet nur den Linksklick, also wird
	# der rechte hier selbst abgefangen.
	b.gui_input.connect(func(event: InputEvent) -> void:
		if index < 0 or not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_say(Keybinds.remove_at(action, index), _HELP)
			Settings.save_settings()
			_rebuild_binds())
	return b

## Nimmt die nächste Eingabe auf. Solange das läuft, kommt keine Taste im Spiel
## an — sonst würde das Belegen von „Springen" beim Drücken gleich springen.
func _start_capture(action: String, index: int, button: UiButton) -> void:
	_capture_action = action
	_capture_index = index
	button.text = "…"
	_say("Jetzt die neue Taste oder Maustaste drücken. Esc bricht ab.")

## Schliesst das Menue und bricht dabei eine laufende Tastenaufnahme ab.
##
## Ohne das blieb `_capture_action` stehen, wenn das Menue auf einem Weg
## zuging, den `_input` nicht sieht (etwa ueber ein Gamepad): der naechste
## Tastendruck im Spiel waere dann als Belegung geschluckt worden.
func set_open(open: bool) -> void:
	if not open and _capture_action != "":
		_capture_action = ""
		_rebuild_binds()
	super.set_open(open)

func _input(event: InputEvent) -> void:
	if _capture_action == "":
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var action := _capture_action
	var index := _capture_index
	_capture_action = ""
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_say("Abgebrochen.", _HELP)
		_rebuild_binds()
		return
	var problem := Keybinds.add(action, event) if index < 0 \
		else Keybinds.replace(action, index, event)
	_say(problem, "%s: %s" % [Keybinds.label_of(action), Keybinds.describe_action(action)])
	Settings.save_settings()
	_rebuild_binds()

## Sagt, was passiert ist. Ohne Rückmeldung drückt man eine belegte Taste und
## nichts geschieht — und weiss nicht, ob das Menü kaputt ist oder die Taste.
func _say(text: String, fallback: String = "") -> void:
	if _bind_note != null:
		_bind_note.text = text if text != "" else fallback

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
	_show_row("profile", _profile_index())
	_show_row("range", Settings.render_range)
	_show_row("water", Settings.water_detail)
	_show_row("wind", Settings.wind)
	_show_row("particles", Settings.particles)
	_show_row("decor", Settings.decor)
	_show_row("light", Settings.light)
	_show_row("daycycle", 1 if Settings.day_cycle else 0)
	_show_row("shadows", 1 if Settings.shadows else 0)
	_show_row("fps", Settings.fps_limit)
	_show_row("vsync", 1 if Settings.vsync else 0)
	_show_row("perf", 1 if Settings.show_perf else 0)
	_show_row("auto", 1 if Settings.auto_quality else 0)

func _show_row(key: String, value: int) -> void:
	var row: UiChoice = _rows.get(key)
	if row != null:
		row.show_value(value)
