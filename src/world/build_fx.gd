class_name BuildFx
extends Node2D
## Rückmeldung: was gerade passiert ist.
##
## Zwei kurze Zeichen, beide nur ein paar Zehntelsekunden lang:
##
##   Bauen   ein Rahmen, der aus dem gesetzten Block herauswächst und verblasst
##   Landen  eine kleine Staubwolke unter der Figur
##
## Ohne so etwas fühlt sich Bauen an, als würde man eine Tabelle ausfüllen: der
## Block ist da, aber nichts hat ihn gesetzt. Das Zeichen darf dabei nicht im
## Weg sein — es ist nach 0,22 Sekunden weg und nie mehr als ein heller Umriss.
##
## Alles lebt in einer einzigen Liste und wird in einem `_draw()` gezeichnet.
## Ist die Liste leer, läuft weder `_process` noch `_draw`.

const FLASH_TIME := 0.22
const PUFF_TIME := 0.38

## Wie weit der Rahmen über den Block hinauswächst.
const FLASH_GROW := 5.0

## Mehr als so viele Zeichen gleichzeitig gibt es nicht. Beim schnellen Ziehen
## entstehen sonst hunderte, und die verdecken am Ende die Welt, die sie zeigen
## sollen.
const MAX_MARKS := 24

var _marks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

## Gezeichnete Zeichen im letzten Bild — nur Messung für den Selbsttest.
var drawn: int = 0

func _ready() -> void:
	z_index = 400             ## über dem Boden, unter dem Raster
	_rng.seed = 8123
	set_process(false)

## Ein gesetzter Block.
func flash(cell: Vector2i) -> void:
	_add({"kind": "flash", "cell": cell, "age": 0.0})

## Die Figur ist aufgekommen.
func puff(pos: Vector2) -> void:
	if Graphics.particle_count() <= 0:
		return
	for i in 5:
		_add({
			"kind": "puff", "age": 0.0,
			"pos": pos + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-2.0, 2.0)),
			"vel": Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(-6.0, 2.0)),
			"size": _rng.randf_range(1.0, 2.0),
		})

func _add(mark: Dictionary) -> void:
	if _marks.size() >= MAX_MARKS:
		_marks.pop_front()
	_marks.append(mark)
	set_process(true)

func _process(delta: float) -> void:
	for m: Dictionary in _marks:
		m["age"] = float(m["age"]) + delta
		if m["kind"] == "puff":
			m["pos"] = Vector2(m["pos"]) + Vector2(m["vel"]) * delta
	_marks = _marks.filter(func(m: Dictionary) -> bool:
		return float(m["age"]) < (FLASH_TIME if m["kind"] == "flash" else PUFF_TIME))
	if _marks.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	drawn = 0
	var t := float(Config.TILE)
	for m: Dictionary in _marks:
		if m["kind"] == "flash":
			_draw_flash(m, t)
		else:
			_draw_puff(m)
		drawn += 1

## Der Rahmen wächst nach aussen und verblasst — so wirkt es, als sei der Block
## eingerastet, statt einfach dazustehen.
func _draw_flash(m: Dictionary, t: float) -> void:
	var f: float = clampf(float(m["age"]) / FLASH_TIME, 0.0, 1.0)
	var cell: Vector2i = m["cell"]
	var grow := FLASH_GROW * f
	var box := Rect2(cell.x * t - grow, cell.y * t - grow, t + grow * 2.0, t + grow * 2.0)
	var a := (1.0 - f) * 0.85
	draw_rect(box, Color(Palette.UI_ACCENT, a), false, 2.0)
	# Im ersten Drittel zusätzlich eine schwache Füllung: das ist der „Treffer".
	if f < 0.34:
		draw_rect(Rect2(cell.x * t, cell.y * t, t, t),
			Color(1.0, 1.0, 1.0, (1.0 - f / 0.34) * 0.22), true)

func _draw_puff(m: Dictionary) -> void:
	var f: float = clampf(float(m["age"]) / PUFF_TIME, 0.0, 1.0)
	var s: float = float(m["size"]) * (1.0 + f)
	draw_rect(Rect2(Vector2(m["pos"]).round(), Vector2(s, s)),
		Color(Palette.SAND_LIGHT, (1.0 - f) * 0.5), true)
