class_name WorldRender
extends Node2D

## Zeichnet Hütten, Lagerfeuer, Fackeln und alle Siedler in einem einzigen
## Draw-Pass — kein Node pro Einheit.
##
## Zwei Dinge halten die Kosten unten:
##   * **Culling**: Nur was im Kameraausschnitt liegt, wird überhaupt
##     angefasst. Vorher lief der Zeichencode über *alle* Dörfer und Siedler,
##     auch die 3 Bildschirme weit entfernten.
##   * **Gruppierte Durchgänge**: erst alle Schatten, dann alle Körper, dann
##     alle Köpfe. Gleichartige Primitive hintereinander lassen sich von der
##     Grafikschicht zu wenigen Zeichenaufrufen zusammenfassen.
##
## Siedlerpositionen werden zwischen den Simulations-Ticks interpoliert.

const CULL_MARGIN := 40.0

var sim: Simulation
var quality: Quality

var _view := Rect2()
var _visible_settlers: Array = []
var _visible_huts: Array = []
var _visible_fires: Array = []
var _visible_torches: Array = []
var _drawn_huts := 0
var _drawn_villages := 0


func _init(sim_ref: Simulation, quality_ref: Quality) -> void:
	sim = sim_ref
	quality = quality_ref
	z_index = 5
	z_as_relative = false


func _process(_delta: float) -> void:
	queue_redraw()


func drawn_entities() -> int:
	return _visible_settlers.size()


func drawn_huts() -> int:
	return _drawn_huts


func drawn_villages() -> int:
	return _drawn_villages


## Gezeichnet wird in Durchgängen *nach Primitivtyp*, nicht Objekt für Objekt.
## Der Grund: Die Grafikschicht kann gleichartige Primitive zu einem einzigen
## Zeichenaufruf zusammenfassen — sobald aber zwischen zwei Rechtecken ein
## Polygon oder eine Linie liegt, reisst die Serie. Objektweise gezeichnet
## kostete eine Hütte drei Aufrufe; so kosten alle Hütten zusammen drei.
func _draw() -> void:
	_view = _view_rect().grow(CULL_MARGIN)
	var alpha := sim.alpha()
	var time := Time.get_ticks_msec() * 0.001
	var shadows: bool = quality.get_value("entity_shadows", true) if quality != null else true

	_visible_settlers.clear()
	for s in sim.settlers:
		var p: Vector2 = s.prev_pos.lerp(s.pos, alpha)
		if _view.has_point(p):
			_visible_settlers.append([s, p])

	_visible_huts.clear()
	_visible_fires.clear()
	_drawn_villages = 0
	for v in sim.villages:
		if not v.fallen and _view.has_point(v.center_pos):
			_visible_fires.append(v.center_pos)
			_drawn_villages += 1
		for hut in v.huts:
			var p := Vector2(hut) * Terrain.TILE
			if _view.has_point(p):
				_visible_huts.append(p)
	_drawn_huts = _visible_huts.size()

	_visible_torches.clear()
	for torch in sim.torches:
		if _view.has_point(torch.pos):
			_visible_torches.append(torch.pos)

	# 1 — Schatten (Rechtecke)
	if shadows:
		for p in _visible_huts:
			draw_rect(Rect2(p + Vector2(2, 13), Vector2(13, 3)), Palette.SHADOW)
		for entry in _visible_settlers:
			draw_rect(Rect2(entry[1] + Vector2(-3, -1), Vector2(6, 2)), Palette.SHADOW)

	# 2 — Hüttenwände, Lichtkante, Türen (Rechtecke)
	var wall_light := Palette.shade(Palette.HUT_WALL, 0.07)
	for p in _visible_huts:
		draw_rect(Rect2(p + Vector2(2, 7), Vector2(12, 8)), Palette.HUT_WALL)
		draw_rect(Rect2(p + Vector2(2, 7), Vector2(12, 1)), wall_light)
		draw_rect(Rect2(p + Vector2(7, 10), Vector2(3, 5)), Palette.HUT_DOOR)

	# 3 — Fackeln (Rechtecke)
	for p in _visible_torches:
		draw_rect(Rect2(p + Vector2(-1, -7), Vector2(2, 8)), Palette.TORCH_STICK)
		draw_rect(Rect2(p + Vector2(-2, -9), Vector2(4, 3)), Palette.TORCH_HEAD)

	# 4 — Siedler (Rechtecke)
	var running := sim.speed > 0.0
	for entry in _visible_settlers:
		_draw_settler(entry[0], entry[1], time, running)

	# 5 — Dächer (Polygone)
	for p in _visible_huts:
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, 8), p + Vector2(8, 1), p + Vector2(16, 8),
		]), Palette.HUT_ROOF)

	# 6 — Kreise (Feuerstellen)
	for c in _visible_fires:
		for i in 6:
			draw_circle(c + Vector2.from_angle(TAU * i / 6.0) * 5.0, 1.4, Palette.FIRE_STONE)

	# 7 — Linien (Dachkante, Feuerholz)
	var roof_edge := Palette.shade(Palette.HUT_ROOF, -0.06)
	for p in _visible_huts:
		draw_line(p + Vector2(8, 1), p + Vector2(16, 8), roof_edge, 1.0)
	for c in _visible_fires:
		draw_line(c + Vector2(-3, 1), c + Vector2(3, -2), Palette.FIRE_LOG, 1.6)
		draw_line(c + Vector2(-3, -2), c + Vector2(3, 1), Palette.FIRE_LOG, 1.6)


func _view_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2(Vector2.ZERO, Vector2(1280, 720))
	var transform := viewport.get_canvas_transform()
	var scale := transform.get_scale()
	return Rect2(-transform.origin / scale, viewport.get_visible_rect().size / scale)


func _draw_settler(s: Settler, p: Vector2, time: float, running: bool) -> void:
	# `running` prüft die Simulationsgeschwindigkeit: Ohne das wippten die
	# Siedler auch im pausierten Spiel weiter, weil prev_pos != pos
	# eingefroren stehen bleibt.
	var moving := running and s.prev_pos.distance_squared_to(s.pos) > 0.01
	var bob := 0.0
	if moving:
		bob = absf(sin(time * 9.0 + s.bob_phase)) * 1.2
	var tunic: Color = Palette.TUNIC_GATHERER if s.job == Settler.Job.GATHERER else Palette.TUNIC_LUMBERJACK
	if s.wading:
		# Im Flachwasser steckt die Figur bis zur Hüfte im Wasser: der Körper
		# wird gekürzt, dazu kommt ein heller Saum an der Wasserlinie.
		draw_rect(Rect2(p + Vector2(-2, -4 - bob), Vector2(4, 3)), tunic)
		var foam := Palette.WATER_FOAM
		foam.a = 0.5
		draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 1)), foam)
	else:
		draw_rect(Rect2(p + Vector2(-2, -4 - bob), Vector2(4, 5)), tunic)
	# Kopf und Traglast sitzen mittig über dem Rumpf (Rumpf: -2 … +2) und
	# direkt auf dem Kopf auf — vorher war der Kopf 0,5 px versetzt und die
	# Last schwebte 1 px darüber.
	draw_rect(Rect2(p + Vector2(-1.5, -7 - bob), Vector2(3, 3)), Palette.SKIN)
	if s.carrying == Settler.Carry.FOOD:
		draw_rect(Rect2(p + Vector2(-1.5, -9 - bob), Vector2(3, 2)), Palette.CARRY_FOOD)
	elif s.carrying == Settler.Carry.WOOD:
		draw_rect(Rect2(p + Vector2(-2.5, -9 - bob), Vector2(5, 2)), Palette.CARRY_WOOD)
