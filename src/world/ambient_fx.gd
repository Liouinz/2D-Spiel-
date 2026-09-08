class_name AmbientFx
extends Node2D
## Staub und Pollen in der Luft.
##
## Kleine helle Punkte, die langsam mit dem Wind treiben. Sie sind der
## Unterschied zwischen „ein Bild" und „draussen": ohne sie steht die Luft über
## dem Boden völlig still.
##
## Sie leben ausschliesslich im sichtbaren Ausschnitt. Wer ihn verlässt, wird
## auf der Gegenseite wieder eingesetzt statt weiterberechnet — dadurch kostet
## die Wirkung immer gleich viel, egal wie gross die Welt ist. Ausserhalb des
## Bildes wird nichts gezeichnet und nichts bewegt.

const SPEED := 14.0            ## Grunddrift in Bildpunkten je Sekunde
const REDRAW_HZ := 30.0

## Warmes Weiss. Der Boden ist stark gekörnt; ein blasser sandfarbener Punkt
## verschwand darin restlos — erst ein heller Kern hebt sich ab, ohne dass die
## Punkte wie Bildfehler wirken.
const CORE := Color(1.0, 0.97, 0.88)

var camera: GameCamera

var _motes: Array[Dictionary] = []
var _time: float = 0.0
var _accum: float = 0.0
var _rng := RandomNumberGenerator.new()

## Gezeichnete Punkte im letzten Bild — nur Messung für den Selbsttest.
var drawn: int = 0

func _ready() -> void:
	z_index = 100                ## über dem Boden, unter dem Raster
	_rng.seed = 20260907
	Graphics.applied.connect(_rebuild)
	_rebuild()

## Legt so viele Punkte an, wie die Einstellung erlaubt.
func _rebuild() -> void:
	var want := Graphics.particle_count()
	while _motes.size() > want:
		_motes.pop_back()
	while _motes.size() < want:
		_motes.append(_new_mote(_visible_rect(), true))
	set_process(want > 0)
	if want == 0:
		queue_redraw()

func _new_mote(area: Rect2, anywhere: bool) -> Dictionary:
	var pos := Vector2(
		_rng.randf_range(area.position.x, area.end.x),
		_rng.randf_range(area.position.y, area.end.y))
	if not anywhere:
		# Neu eingesetzte Punkte kommen von der Windseite herein, nicht aus
		# dem Nichts mitten im Bild.
		pos.x = area.position.x - _rng.randf_range(0.0, 24.0)
	return {
		"pos": pos,
		"phase": _rng.randf_range(0.0, TAU),
		"rise": _rng.randf_range(0.35, 1.1),      ## wie stark er auf und ab schwebt
		"drift": _rng.randf_range(0.6, 1.5),      ## wie schnell er treibt
		# In WELTpixeln. Bei Zoom 2 sind das zwei bzw. vier Bildschirmpunkte —
		# mehr wirkt nicht wie Staub, sondern wie Schmutz auf dem Bildschirm.
		"size": 1.0 if _rng.randf() < 0.72 else 2.0,
		"alpha": _rng.randf_range(0.30, 0.62),
	}

func _visible_rect() -> Rect2:
	if is_instance_valid(camera):
		return camera.visible_world_rect().grow(32.0)
	return Rect2(Vector2.ZERO, Vector2(Config.TILE * 40, Config.TILE * 24))

func _process(delta: float) -> void:
	_time += delta
	var area := _visible_rect()
	for m: Dictionary in _motes:
		var p: Vector2 = m["pos"]
		p.x += SPEED * float(m["drift"]) * delta
		p.y += sin(_time * 0.7 + float(m["phase"])) * float(m["rise"]) * delta * 12.0
		if p.x > area.end.x or p.y < area.position.y - 32.0 or p.y > area.end.y + 32.0:
			var fresh := _new_mote(area, false)
			fresh["pos"] = Vector2(area.position.x - 8.0,
				_rng.randf_range(area.position.y, area.end.y))
			_motes[_motes.find(m)] = fresh
			continue
		m["pos"] = p
	_accum += delta
	if _accum >= 1.0 / REDRAW_HZ:
		_accum = 0.0
		queue_redraw()

func _draw() -> void:
	drawn = 0
	if _motes.is_empty():
		return
	var area := _visible_rect()
	for m: Dictionary in _motes:
		var p: Vector2 = m["pos"]
		if not area.has_point(p):
			continue
		var s: float = m["size"]
		# Ein leichtes Pulsieren, damit die Punkte nicht wie Bildfehler wirken.
		var a: float = float(m["alpha"]) * (0.62 + 0.38 * sin(_time * 1.6 + float(m["phase"])))
		var at := p.round()
		# Weicher Hof unter dem Kern: ein einzelnes helles Quadrat sähe wie ein
		# defekter Bildpunkt aus, mit Hof wie etwas, das in der Luft schwebt.
		draw_rect(Rect2(at - Vector2.ONE, Vector2(s + 2.0, s + 2.0)),
			Color(CORE, a * 0.28), true)
		draw_rect(Rect2(at, Vector2(s, s)), Color(CORE, a), true)
		drawn += 1
