class_name LightManager
extends Node2D
## Umgebungslicht, Tagesverlauf und Vignette.
##
## Bis hierher war die Welt völlig flach ausgeleuchtet: jede Kachel zu jeder
## Zeit gleich hell. Das ist der Unterschied zwischen einer Textur und einem
## Ort. Drei Mittel, alle billig:
##
##   CanvasModulate   färbt und dunkelt die ganze Welt — das Tageslicht selbst
##   PointLight2D     ein weicher Schein um die Figur, der nachts aufblendet
##   Vignette         dunklere Bildränder, die den Blick zur Mitte ziehen
##
## Das Licht liegt auf der WELT, nicht auf der Oberfläche: `CanvasModulate` wirkt
## nur in seiner eigenen CanvasLayer, und HUD, Leiste und Inventar liegen auf
## eigenen. Ein abendlich oranges Menü wäre ein Fehler, keine Stimmung.
##
## Der Tagesverlauf ist bewusst zahm. Eine Nacht, in der man nichts mehr sieht,
## ist in einem Bauspiel keine Atmosphäre, sondern eine Zwangspause: der
## dunkelste Punkt liegt bei knapp der halben Helligkeit, und die Figur bringt
## ihr eigenes Licht mit.

## Länge eines ganzen Tages in Sekunden. Acht Minuten: lang genug, dass der
## Wechsel nicht hektisch wirkt, kurz genug, dass man ihn in einer Sitzung sieht.
const DAY_LENGTH := 480.0

## Wo der Tag beginnt, wenn die Welt geladen wird — heller Vormittag.
const START_TIME := 0.34

## Farbe und Helligkeit über den Tag. Der erste Wert ist die Uhrzeit von 0
## (Mitternacht) bis 1, der zweite die Tönung, mit der die Welt multipliziert
## wird. Weiss heisst: unverändert.
const RAMP := [
	[0.00, Color(0.40, 0.46, 0.68)],   ## tiefe Nacht, blau
	[0.17, Color(0.52, 0.52, 0.70)],   ## erste Dämmerung
	[0.23, Color(0.92, 0.74, 0.66)],   ## Morgenrot
	[0.30, Color(1.00, 0.97, 0.93)],   ## Vormittag
	[0.50, Color(1.00, 1.00, 1.00)],   ## Mittag
	[0.70, Color(1.00, 0.96, 0.88)],   ## Nachmittag
	[0.79, Color(0.98, 0.72, 0.56)],   ## Abendrot
	[0.86, Color(0.60, 0.54, 0.72)],   ## Dämmerung
	[1.00, Color(0.40, 0.46, 0.68)],   ## wieder Nacht
]

## Radius des Scheins um die Figur in Weltpixeln.
const LIGHT_RADIUS := 128

## Wie weit über dem Standpunkt der Schein sitzt. Die Figur wird an ihren
## FÜSSEN positioniert; ein Licht dort sähe aus, als trüge sie die Laterne
## am Knöchel. Achtzehn Pixel liegen auf Höhe der Brust.
const LIGHT_LIFT := 18.0

var player: Node2D

var _modulate: CanvasModulate
var _light: PointLight2D
var _vignette_layer: CanvasLayer
var _vignette: ColorRect
var _time: float = START_TIME
var _mode: int = -1

const VIGNETTE := """
shader_type canvas_item;

uniform float strength = 0.55;

void fragment() {
	// Abstand zur Bildmitte, auf die Diagonale bezogen.
	float d = length(UV - vec2(0.5)) * 1.414;
	float v = smoothstep(0.55, 1.06, d);
	COLOR = vec4(0.02, 0.03, 0.06, v * strength);
}
"""

func _ready() -> void:
	_modulate = CanvasModulate.new()
	_modulate.name = "Tageslicht"
	add_child(_modulate)

	_light = PointLight2D.new()
	_light.name = "Figurenlicht"
	_light.texture = _light_texture()
	_light.energy = 0.0
	_light.color = Color(1.0, 0.92, 0.76)
	# Der Schein soll aufhellen, nicht überstrahlen: ADD addiert Licht auf das,
	# was schon da ist, statt es zu ersetzen.
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_light)

	# Die Vignette liegt über der Welt, aber unter jeder Oberfläche. HUD (5),
	# Leiste (6) und Inventar (8) bleiben davon unberührt.
	_vignette_layer = CanvasLayer.new()
	_vignette_layer.name = "Vignette"
	_vignette_layer.layer = 1
	add_child(_vignette_layer)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = WorldShaders.make(VIGNETTE)
	_vignette_layer.add_child(_vignette)

	Graphics.applied.connect(_apply_mode)
	_apply_mode()

## Weicher runder Verlauf als Lichttextur.
func _light_texture() -> ImageTexture:
	var d := LIGHT_RADIUS * 2
	var img := Pixel.make(d, d)
	var c := d * 0.5
	for y in d:
		for x in d:
			var t := 1.0 - clampf(Vector2(x - c, y - c).length() / c, 0.0, 1.0)
			# Quadratisch abfallend: linear sähe aus wie ein Scheinwerferkegel.
			img.set_pixel(x, y, Color(1, 1, 1, t * t))
	return Pixel.tex(img)

func _apply_mode() -> void:
	var mode := Graphics.light_mode()
	if mode == _mode:
		return
	_mode = mode
	# „Aus" heisst wirklich aus: kein Tönen, kein Licht, keine Vignette. Ein
	# CanvasModulate in Weiss würde weiterhin über jedes Bildpunkt gerechnet.
	_modulate.visible = mode > 0
	_light.visible = mode > 0
	_vignette_layer.visible = mode > 0
	set_process(mode > 0)
	if mode == 1:
		_time = START_TIME
	_refresh()

func _process(delta: float) -> void:
	if _mode >= 2:
		_time = fposmod(_time + delta / DAY_LENGTH, 1.0)
	_refresh()

func _refresh() -> void:
	if _mode <= 0:
		return
	_modulate.color = tint_at(_time)
	if is_instance_valid(player):
		_light.global_position = player.global_position - Vector2(0.0, LIGHT_LIFT)
	# Der Schein blendet auf, sobald es dunkel wird — nicht nach Uhrzeit,
	# sondern nach tatsächlicher Helligkeit. Dadurch passt er automatisch,
	# wenn sich der Verlauf oben einmal ändert.
	var brightness := _modulate.color.get_luminance()
	_light.energy = clampf((0.86 - brightness) * 2.4, 0.0, 1.05)
	# Am Tag nur eine Ahnung von Rand, nachts deutlich. Eine Vignette, die man
	# am hellen Mittag bemerkt, ist ein Filter — keine Beleuchtung.
	_vignette.material.set_shader_parameter("strength",
		lerpf(0.20, 0.50, clampf((0.86 - brightness) * 2.0, 0.0, 1.0)))

## Die Tönung zu einer Uhrzeit (0 … 1). Öffentlich, damit der Selbsttest den
## Verlauf prüfen kann, ohne acht Minuten zu warten.
static func tint_at(time: float) -> Color:
	var t := fposmod(time, 1.0)
	for i in range(RAMP.size() - 1):
		var a: Array = RAMP[i]
		var b: Array = RAMP[i + 1]
		if t >= a[0] and t <= b[0]:
			var span: float = b[0] - a[0]
			var f: float = 0.0 if span <= 0.0 else (t - a[0]) / span
			return (a[1] as Color).lerp(b[1] as Color, f)
	return RAMP[0][1]

## Läuft die Beleuchtung überhaupt? Auf Stufe „Aus" ist alles abgehängt.
func active() -> bool:
	return _mode > 0

## Wie hell der Schein um die Figur gerade brennt — 0 am Mittag.
func light_energy() -> float:
	return _light.energy

## Die geltende Tönung der Welt.
func tint() -> Color:
	return _modulate.color

## Uhrzeit von 0 (Mitternacht) bis 1 — für Anzeige und Selbsttest.
func time_of_day() -> float:
	return _time

## Setzt die Uhrzeit. Der Selbsttest springt damit durch den Tag.
func set_time(t: float) -> void:
	_time = fposmod(t, 1.0)
	_refresh()
