class_name UiScreen
extends Control
## Das Grundgerüst jedes Vollbild-Menüs.
##
## Abdunkelung, mittig gesetzte Tafel, gemeinsamer Innenrand, weiches Ein- und
## Ausblenden — einmal hier statt in jedem Menü noch einmal. Ein neues Menü
## erbt davon, füllt in `_build()` seinen Inhalt ein und ist damit automatisch
## Teil derselben Designsprache.
##
## Ein Menü bleibt undurchlässig für Mausklicks, SOLANGE es zu sehen ist —
## auch während es ausblendet. Dadurch kann der Klick auf „Fortsetzen" nicht in
## der Welt landen, bevor das Menü ganz verschwunden ist.

## Wie stark die Welt hinter dem Menü abgedunkelt wird. Menüs mit eigenem
## Hintergrundbild setzen das in `_configure()` herunter.
var scrim_alpha: float = UiTheme.SCRIM.a

## Steht der Inhalt auf einer Tafel? Das Hauptmenü sagt hier Nein — es steht
## frei auf seinem Titelbild.
var framed: bool = true

var content: VBoxContainer     ## hier hängt das Menü seinen Inhalt ein

var _scrim: ColorRect
var _card: Control             ## das, was ein- und ausblendet
var _open_t: float = 0.0
var _want: bool = false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# STOP: hinter einem offenen Menü passiert nichts mehr, auch nicht durch
	# einen Klick daneben.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _ready() -> void:
	_configure()
	_background()

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(UiTheme.SCRIM, 0.0)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	content = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", UiTheme.SPACE_S)
	if framed:
		var panel := PanelContainer.new()
		panel.name = "Panel"
		center.add_child(panel)
		panel.add_child(content)
		_card = panel
	else:
		center.add_child(content)
		_card = content
	_card.resized.connect(func() -> void: UiAnim.center_pivot(_card))

	_build()
	UiAnim.center_pivot(_card)
	UiAnim.apply(_card, 0.0)

# --- Von den einzelnen Menüs überschrieben ------------------------------------

## Stellt `framed` und `scrim_alpha` ein, bevor gebaut wird.
func _configure() -> void:
	pass

## Eigenes Hintergrundbild, hinter der Abdunkelung.
func _background() -> void:
	pass

## Baut den Inhalt in `content` ein.
func _build() -> void:
	pass

# --- Bausteine ---------------------------------------------------------------

## Überschrift plus Zierlinie — jedes Menü fängt so an.
func add_heading(text: String, size: int = UiTheme.FONT_H1) -> void:
	content.add_child(UiTheme.title(text, size))
	content.add_child(UiTheme.rule())
	content.add_child(UiTheme.gap(UiTheme.SPACE_S))

func add_button(text: String, on_press: Callable) -> UiButton:
	var b := UiTheme.button(text)
	b.pressed.connect(on_press)
	content.add_child(b)
	return b

# --- Auf und zu --------------------------------------------------------------

## Öffnet und schliesst das Menü. Nur der Zustandsautomat in Main ruft das auf.
func set_open(open: bool) -> void:
	if _want == open:
		return
	_want = open
	if open:
		visible = true
	set_process(true)

func _process(delta: float) -> void:
	var dir := 1.0 if _want else -1.0
	_open_t = clampf(_open_t + dir * delta / UiTheme.ANIM, 0.0, 1.0)
	UiAnim.apply(_card, _open_t)
	_scrim.color.a = scrim_alpha * UiAnim.ease_t(_open_t)
	if (_want and _open_t >= 1.0) or (not _want and _open_t <= 0.0):
		visible = _want
		set_process(false)

## Setzt den Tastaturfokus auf die erste erreichbare Schaltfläche.
##
## Gesucht statt gemerkt: eine Schaltfläche kann ausgeblendet sein (im
## Hauptmenü „Fortsetzen", solange es keine Karte gibt), und dann soll der
## Fokus auf der nächsten landen, nicht ins Leere greifen.
func focus_first() -> void:
	var target := _first_focusable(content)
	if target != null:
		target.grab_focus()

func _first_focusable(node: Node) -> Control:
	for child: Node in node.get_children():
		if child is Control:
			var c := child as Control
			if not c.visible:
				continue
			if c.focus_mode != Control.FOCUS_NONE and not (c is BaseButton and (c as BaseButton).disabled):
				return c
			var deeper := _first_focusable(c)
			if deeper != null:
				return deeper
	return null
