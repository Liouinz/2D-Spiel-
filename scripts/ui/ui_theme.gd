class_name UiTheme
extends RefCounted

## Ein einziges Theme für die gesamte Oberfläche. Alle Rahmen, Farben,
## Abstände und Zustände (normal / überfahren / aktiv / gesperrt) stammen von
## hier — deshalb sieht kein Fenster im Spiel nach Standard-Engine-UI aus,
## und ein Farbwechsel in der Palette zieht sich automatisch durch alles.

const FONT_SMALL := 11
const FONT_BASE := 13
const FONT_TITLE := 17
const BORDER := 2
const GAP := 6


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BASE

	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())
	theme.set_stylebox("panel", "PopupPanel", panel_style(Palette.UI_BG_DEEP))

	var normal := button_style(Palette.UI_PANEL, Palette.UI_BORDER)
	var hover := button_style(Palette.UI_PANEL_HOVER, Palette.UI_BORDER_LIGHT)
	var pressed := button_style(Palette.UI_PANEL_ACTIVE, Palette.UI_ACCENT)
	var disabled := button_style(Color(0.10, 0.09, 0.08), Color(0.24, 0.21, 0.17))
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, Palette.UI_TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Palette.UI_ACCENT)
		theme.set_color("font_disabled_color", type, Palette.UI_TEXT_DIM)
		theme.set_font_size("font_size", type, FONT_BASE)

	theme.set_color("font_color", "Label", Palette.UI_TEXT)
	theme.set_font_size("font_size", "Label", FONT_BASE)

	theme.set_stylebox("panel", "TabContainer", panel_style(Palette.UI_BG_DEEP))
	theme.set_stylebox("tab_selected", "TabContainer", button_style(Palette.UI_PANEL_ACTIVE, Palette.UI_ACCENT))
	theme.set_stylebox("tab_unselected", "TabContainer", button_style(Palette.UI_PANEL, Palette.UI_BORDER))
	theme.set_stylebox("tab_hovered", "TabContainer", button_style(Palette.UI_PANEL_HOVER, Palette.UI_BORDER_LIGHT))
	theme.set_color("font_selected_color", "TabContainer", Palette.UI_ACCENT)
	theme.set_color("font_unselected_color", "TabContainer", Palette.UI_TEXT_DIM)
	theme.set_color("font_hovered_color", "TabContainer", Palette.UI_TEXT)

	theme.set_stylebox("normal", "LineEdit", button_style(Color(0.06, 0.055, 0.05), Palette.UI_BORDER))
	theme.set_color("font_color", "LineEdit", Palette.UI_TEXT)

	theme.set_stylebox("slider", "HSlider", flat(Color(0.06, 0.055, 0.05), Palette.UI_BORDER, 1, 0))
	theme.set_stylebox("grabber_area", "HSlider", flat(Palette.UI_BORDER, Palette.UI_BORDER, 0, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", flat(Palette.UI_ACCENT, Palette.UI_ACCENT, 0, 0))

	theme.set_stylebox("panel", "TooltipPanel", panel_style(Palette.UI_BG_DEEP))
	theme.set_color("font_color", "TooltipLabel", Palette.UI_TEXT)
	theme.set_font_size("font_size", "TooltipLabel", FONT_SMALL)

	theme.set_constant("separation", "HBoxContainer", GAP)
	theme.set_constant("separation", "VBoxContainer", GAP)
	theme.set_constant("h_separation", "GridContainer", GAP)
	theme.set_constant("v_separation", "GridContainer", 4)
	return theme


enum Place { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT, TOP_CENTER, BOTTOM_CENTER }


## Verankert ein Panel verlässlich an einer Bildschirmecke.
##
## Godots `set_anchors_and_offsets_preset(..., PRESET_MODE_MINSIZE, m)` rechnet
## die Offsets aus der Mindestgrösse *im Moment des Aufrufs* — die ist beim
## Aufbau aber noch 0, weshalb die Panels später an der falschen Stelle stehen
## oder ganz aus dem Bild wandern. Hier wird stattdessen der Anker gesetzt und
## über die Wachstumsrichtung aufgelöst: das Panel bleibt an seiner Ecke, egal
## wie gross sein Inhalt wird oder wie das Fenster skaliert.
static func place(control: Control, where: int, margin: float = 8.0) -> void:
	var right := where == Place.TOP_RIGHT or where == Place.BOTTOM_RIGHT
	var bottom := where == Place.BOTTOM_LEFT or where == Place.BOTTOM_RIGHT or where == Place.BOTTOM_CENTER
	var centered := where == Place.TOP_CENTER or where == Place.BOTTOM_CENTER

	if centered:
		control.anchor_left = 0.5
		control.anchor_right = 0.5
		control.offset_left = 0.0
		control.offset_right = 0.0
		control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	elif right:
		control.anchor_left = 1.0
		control.anchor_right = 1.0
		control.offset_left = -margin
		control.offset_right = -margin
		control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		control.anchor_left = 0.0
		control.anchor_right = 0.0
		control.offset_left = margin
		control.offset_right = margin
		control.grow_horizontal = Control.GROW_DIRECTION_END

	if bottom:
		control.anchor_top = 1.0
		control.anchor_bottom = 1.0
		control.offset_top = -margin
		control.offset_bottom = -margin
		control.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		control.anchor_top = 0.0
		control.anchor_bottom = 0.0
		control.offset_top = margin
		control.offset_bottom = margin
		control.grow_vertical = Control.GROW_DIRECTION_END


static func flat(bg: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = maxi(margin - 2, 0)
	style.content_margin_bottom = maxi(margin - 2, 0)
	return style


## Panels bekommen zusätzlich eine helle Innenkante — das ist der Trick, der
## einer flachen Fläche die typische Pixel-UI-Tiefe gibt.
static func panel_style(bg: Color = Palette.UI_BG) -> StyleBoxFlat:
	var style := flat(bg, Palette.UI_BORDER, BORDER, 10)
	style.expand_margin_left = 0.0
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	return flat(bg, border, BORDER, 9)


## Überschrift im Holz/Pergament-Duktus.
static func title_label(text: String, size: int = FONT_TITLE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.UI_ACCENT)
	label.add_theme_font_size_override("font_size", size)
	return label


static func text_label(text: String, size: int = FONT_BASE, color: Color = Palette.UI_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label


static func separator() -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.UI_BORDER
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	line.add_theme_stylebox_override("separator", style)
	return line


static func button(text: String, callback: Callable, tooltip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if not tooltip.is_empty():
		b.tooltip_text = tooltip
	if callback.is_valid():
		b.pressed.connect(callback)
	return b


static func checkbox(text: String, value: bool, callback: Callable, tooltip: String = "") -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = value
	box.focus_mode = Control.FOCUS_NONE
	if not tooltip.is_empty():
		box.tooltip_text = tooltip
	if callback.is_valid():
		box.toggled.connect(callback)
	return box
