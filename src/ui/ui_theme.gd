class_name UiTheme
extends RefCounted
## Ein gemeinsames Theme für alle Menüs — Holz/Pergament, passend zur Spielwelt.

const FONT_TITLE := 64
const FONT_BUTTON := 24
const FONT_LABEL := 18
const FONT_SMALL := 15

static func _box(bg: Color, border: Color, width: int = 2, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

## Baut aus einer erzeugten Textur einen 9-teiligen Rahmen, der beim Skalieren
## seine Pixelgröße behält.
static func _frame(tex: Texture2D, pad_x: int, pad_y: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.set_texture_margin_all(MenuArt.MARGIN)
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_LABEL

	var normal := _frame(MenuArt.button_frame(0), 24, 12)
	var hover := _frame(MenuArt.button_frame(1), 24, 12)
	var pressed := _frame(MenuArt.button_frame(2), 24, 12)
	var focus := _box(Color(0, 0, 0, 0), Palette.UI_ACCENT)

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", _box(Color8(40, 38, 36, 180), Color8(80, 74, 66)))
	t.set_color("font_color", "Button", Palette.UI_TEXT)
	t.set_color("font_hover_color", "Button", Palette.UI_ACCENT)
	t.set_color("font_pressed_color", "Button", Palette.UI_ACCENT)
	t.set_color("font_focus_color", "Button", Palette.UI_ACCENT)
	t.set_font_size("font_size", "Button", FONT_BUTTON)

	t.set_color("font_color", "Label", Palette.UI_TEXT)
	t.set_font_size("font_size", "Label", FONT_LABEL)

	t.set_stylebox("panel", "PanelContainer", _frame(MenuArt.panel_frame(), 34, 28))

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color8(28, 26, 24, 220)
	slider_bg.set_corner_radius_all(3)
	slider_bg.content_margin_top = 5
	slider_bg.content_margin_bottom = 5
	var slider_fg := StyleBoxFlat.new()
	slider_fg.bg_color = Palette.UI_ACCENT
	slider_fg.set_corner_radius_all(3)
	slider_fg.content_margin_top = 5
	slider_fg.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", slider_fg)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_fg)

	var flat := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		t.set_stylebox(state, "CheckBox", flat)
	t.set_color("icon_normal_color", "CheckBox", Palette.UI_TEXT)
	t.set_color("icon_hover_color", "CheckBox", Palette.UI_ACCENT)
	t.set_color("icon_pressed_color", "CheckBox", Palette.UI_ACCENT)
	t.set_color("font_color", "CheckBox", Palette.UI_TEXT)
	t.set_color("font_hover_color", "CheckBox", Palette.UI_ACCENT)
	t.set_font_size("font_size", "CheckBox", FONT_LABEL)
	return t

static func title(text: String, size: int = FONT_TITLE, color: Color = Palette.UI_ACCENT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func text_label(text: String, size: int = FONT_SMALL, color: Color = Palette.UI_TEXT_DIM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Schmale Zierleiste unter der Überschrift.
static func rule() -> Control:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = Palette.UI_ACCENT
	line.custom_minimum_size = Vector2(260, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(line)
	return c

static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 0)
	b.focus_mode = Control.FOCUS_ALL
	return b
