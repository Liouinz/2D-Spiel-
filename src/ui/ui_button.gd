class_name UiButton
extends Button
## Die Schaltfläche des Spiels. Es gibt genau diese eine.
##
## Farbe und Rahmen der vier Zustände kommen aus dem Theme (UiTheme.build()),
## die Bewegung von hier: beim Überfahren wächst die Fläche einen Hauch, beim
## Drücken sinkt sie kurz ein. Das ist derselbe Übergang, den auch die Felder
## im Inventar benutzen — deshalb fühlt sich die ganze Oberfläche gleich an.
##
## Tastatur und Maus verhalten sich absichtlich gleich: ein Knopf mit
## Tastaturfokus sieht aus wie einer unter dem Zeiger. Wer mit den Pfeiltasten
## durch ein Menü geht, sieht damit dasselbe wie mit der Maus.

const GROW := 0.018            ## Wachstum beim Überfahren
const SINK := 0.03             ## Einsinken beim Drücken

var _hover := 0.0
var _press := 0.0
var _held := false

func setup(label: String) -> UiButton:
	text = label
	custom_minimum_size = Vector2(UiTheme.BUTTON_W, UiTheme.BUTTON_H)
	# Menüs sollen sich auch ohne Maus bedienen lassen.
	focus_mode = Control.FOCUS_ALL
	# SHRINK_CENTER: eine Schaltfläche behält ihre Breite, statt in einer
	# Spalte auf die Breite des breitesten Nachbarn gezogen zu werden. Ohne das
	# wird aus „ZURÜCK" ein Balken über die ganze Tafel.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return self

## Andere Maße als die zwei Standardgrößen — für die Kategorieleiste im
## Einstellungsmenü.
func sized(w: int, h: int, font_size: int = UiTheme.FONT_SMALL) -> UiButton:
	custom_minimum_size = Vector2(w, h)
	add_theme_font_size_override("font_size", font_size)
	return self

func _ready() -> void:
	resized.connect(_center_pivot)
	button_down.connect(func() -> void: _held = true; set_process(true))
	button_up.connect(func() -> void: _held = false; set_process(true))
	mouse_entered.connect(func() -> void: set_process(true))
	mouse_exited.connect(func() -> void: set_process(true))
	focus_entered.connect(func() -> void: set_process(true))
	focus_exited.connect(func() -> void: set_process(true))
	_center_pivot()

func _center_pivot() -> void:
	pivot_offset = size * 0.5

## Läuft nur, solange sich etwas bewegt.
func _process(delta: float) -> void:
	var want_hover := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	var want_press := 1.0 if _held and not disabled else 0.0
	var step := clampf(delta * UiTheme.STATE_SPEED, 0.0, 1.0)
	_hover = lerpf(_hover, want_hover, step)
	_press = lerpf(_press, want_press, step)
	if absf(_hover - want_hover) < 0.005 and absf(_press - want_press) < 0.005:
		_hover = want_hover
		_press = want_press
		set_process(false)
	_center_pivot()
	scale = Vector2.ONE * (1.0 + GROW * _hover - SINK * _press)
