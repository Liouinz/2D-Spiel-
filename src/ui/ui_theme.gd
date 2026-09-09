class_name UiTheme
extends RefCounted
## Die gemeinsame Designsprache aller Oberflächen.
##
## Hier stehen die Werte, aus denen jedes Menü, jedes Feld und jede Schaltfläche
## gebaut wird — Abstände, Radien, Rahmenstärken, Schriftgrößen, Farben und
## Bewegungsdauern. Vorher hatte jede Datei ihre eigenen Zahlen: das Inventar
## Radius 6, die Menüs Radius 3, die Optionen wieder andere Abstände. Genau
## daran erkennt man einen Prototyp.
##
## Regel: kein Menü erfindet eigene Werte. Wer etwas braucht, das es hier nicht
## gibt, trägt es hier ein — dann haben es alle.

# --- Abstände ----------------------------------------------------------------
# Alles ist ein Vielfaches von 4. Dadurch stehen Dinge aus verschiedenen Menüs
# auf demselben Raster, auch wenn sie nie nebeneinander zu sehen sind.

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 14
const SPACE_L := 22
const SPACE_XL := 34

# --- Form --------------------------------------------------------------------

const RADIUS_S := 6
const RADIUS := 10
const RADIUS_L := 14
const BORDER := 2
const BORDER_STRONG := 3

## Schlagschatten. Tafeln werfen einen weichen, Felder einen kleinen.
const SHADOW_PANEL := 18
const SHADOW_RAISED := 8

# --- Typografie --------------------------------------------------------------
# Fünf Stufen, mehr nicht. Jede hat eine Aufgabe.

const FONT_TITLE := 54        ## nur der Spieltitel
const FONT_H1 := 26           ## Menü-Überschrift
const FONT_BODY := 16         ## Fließtext, Zeilenbeschriftung
const FONT_SMALL := 14        ## Nebeninformation
const FONT_TINY := 12         ## Marken, Nummern

## Saum um Schrift, die über der Welt steht. In Tafeln unnötig, draußen
## unverzichtbar.
const OUTLINE := 4

# --- Schaltflächen -----------------------------------------------------------

const BUTTON_W := 300
const BUTTON_H := 46

# --- Bewegung ----------------------------------------------------------------
# Kurz und ruhig. Alles, was spürbar länger dauert, fühlt sich träge an.

const ANIM := 0.14

## Wie schnell ein Zustand (überfahren, gewählt) nachzieht — als Faktor für
## `lerp` je Sekunde.
const STATE_SPEED := 14.0

# --- Farben ------------------------------------------------------------------
# Die Palette der Welt liefert die Grundtöne, hier bekommen sie ihre Rolle in
# der Oberfläche.

const SURFACE := Color(0.075, 0.085, 0.105, 1.0)         ## Tafel
const SURFACE_RAISED := Color(0.10, 0.11, 0.14, 0.94)    ## Feld, Zeile
const SURFACE_HOVER := Color(0.17, 0.19, 0.23, 0.96)
const SURFACE_ACTIVE := Color(0.22, 0.19, 0.13, 0.98)    ## gewählt: warm getönt
const SURFACE_SUNKEN := Color(0.05, 0.06, 0.08, 0.90)    ## Mulde unter Bildern
const LINE := Color(0.20, 0.21, 0.24, 0.90)
const SCRIM := Color(0.03, 0.04, 0.06, 0.68)             ## Welt hinter einem Menü

const TEXT: Color = Palette.UI_TEXT
const TEXT_DIM: Color = Palette.UI_TEXT_DIM
const ACCENT: Color = Palette.UI_ACCENT
const ACCENT_LINE: Color = Palette.UI_BORDER_HI

# --- Bausteine ---------------------------------------------------------------

## Eine Fläche mit Rahmen. Der Weg, im Spiel eine Fläche zu erzeugen —
## damit sehen Tafeln, Felder und Zeilen überall gleich aus.
static func box(bg: Color, border: Color, width: int = BORDER,
		radius: int = RADIUS, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.5)
	return s

## Die Tafel, auf der ein Menü steht.
static func panel_style() -> StyleBoxFlat:
	var s := box(SURFACE, Palette.UI_BORDER, BORDER, RADIUS_L, SHADOW_PANEL)
	s.content_margin_left = SPACE_L
	s.content_margin_right = SPACE_L
	s.content_margin_top = SPACE_L
	s.content_margin_bottom = SPACE_L
	return s

## Eine abgesetzte Fläche innerhalb einer Tafel — Kategorieleiste, Leiste,
## Einstellungszeile.
static func inset_style(alpha: float = 0.82) -> StyleBoxFlat:
	var s := box(Color(SURFACE_SUNKEN, alpha), Color(0.24, 0.22, 0.19, 0.9),
		BORDER, RADIUS, SHADOW_RAISED)
	return s

static func button_style(bg: Color, border: Color, width: int = BORDER) -> StyleBoxFlat:
	var s := box(bg, border, width, RADIUS)
	s.content_margin_left = SPACE_L
	s.content_margin_right = SPACE_L
	s.content_margin_top = SPACE_S
	s.content_margin_bottom = SPACE_S
	return s

## Das eine Theme des Spiels, einmal gebaut und dann geteilt.
static var _shared: Theme = null

static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared

## Hängt das gemeinsame Theme an eine Oberfläche.
##
## Das muss von Hand passieren, und zwar an der obersten Control jeder
## CanvasLayer. Godot vererbt ein Theme nur entlang der Control-Kette; eine
## CanvasLayer dazwischen unterbricht sie. Ein Theme am Fenster erreicht die
## Menüs dieses Spiels deshalb NICHT — sie liegen alle unter CanvasLayer, und
## die Tafeln bekamen dadurch still Godots graue Voreinstellung statt der
## eigenen Fassung.
static func attach(c: Control) -> void:
	if is_instance_valid(c):
		c.theme = shared()

## Baut das Theme. Über `shared()` benutzen — einmal reicht.
static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY

	t.set_stylebox("normal", "Button", button_style(SURFACE_RAISED, LINE))
	t.set_stylebox("hover", "Button", button_style(SURFACE_HOVER, ACCENT_LINE))
	t.set_stylebox("pressed", "Button", button_style(SURFACE_ACTIVE, ACCENT, BORDER_STRONG))
	t.set_stylebox("disabled", "Button",
		button_style(Color(0.09, 0.10, 0.12, 0.55), Color(0.24, 0.24, 0.26, 0.6)))
	# Der Fokusrahmen liegt ÜBER dem Zustand und darf ihn nicht übermalen:
	# durchsichtige Fläche, nur Rand.
	t.set_stylebox("focus", "Button",
		button_style(Color(0, 0, 0, 0), ACCENT, BORDER_STRONG))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_font_size("font_size", "Button", FONT_BODY)

	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", FONT_BODY)

	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	var track := box(Color(0.05, 0.06, 0.08, 0.9), Color(0, 0, 0, 0), 0, 3)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := box(ACCENT, Color(0, 0, 0, 0), 0, 3)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	# Godots Griff ist ein weisser Punkt und der einzige Fleck der Oberfläche,
	# der nicht zur Palette gehört.
	var grabber := slider_grabber()
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", grabber)

	var flat := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		t.set_stylebox(state, "CheckBox", flat)
	t.set_color("icon_normal_color", "CheckBox", TEXT)
	t.set_color("icon_hover_color", "CheckBox", ACCENT)
	t.set_color("icon_pressed_color", "CheckBox", ACCENT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", ACCENT)
	t.set_font_size("font_size", "CheckBox", FONT_BODY)
	return t

## Der Griff des Reglers: dunkler Saum, Akzentring, heller Kern.
static func slider_grabber() -> ImageTexture:
	var d := 16
	var img := Pixel.make(d, d)
	var c := d * 0.5
	Pixel.circle(img, c, c, 7.0, Color(0, 0, 0, 0.55))
	Pixel.circle(img, c, c, 5.5, ACCENT)
	Pixel.circle(img, c, c, 3.0, ACCENT.lightened(0.4))
	return Pixel.tex(img)

# --- Fertige Bauteile --------------------------------------------------------

## Überschrift. `size` nur setzen, wenn eine der Stufen oben nicht passt.
static func title(text: String, size: int = FONT_TITLE, color: Color = ACCENT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", OUTLINE + 2)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func text_label(text: String, size: int = FONT_SMALL, color: Color = TEXT_DIM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", OUTLINE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Schmale Zierlinie unter einer Überschrift.
static func rule(width: int = 96) -> Control:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = Color(ACCENT_LINE, 0.55)
	line.custom_minimum_size = Vector2(width, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(line)
	return c

static func button(text: String) -> UiButton:
	return UiButton.new().setup(text)

## Senkrechter Abstandhalter in einer der Abstandsstufen.
static func gap(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
