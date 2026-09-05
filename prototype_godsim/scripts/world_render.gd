class_name WorldRender
extends Node2D

## Zeichnet Hütten, Lagerfeuer und alle Siedler in einem einzigen Draw-Pass —
## kein Node pro Einheit. Siedler-Positionen werden zwischen den
## Simulations-Ticks interpoliert, dazu kommt ein Geh-Wippen ("Juice").

const SHADOW := Color(0.0, 0.0, 0.0, 0.18)
const SKIN := Color(0.94, 0.84, 0.70)
const TUNIC_GATHERER := Color(0.43, 0.51, 0.24)
const TUNIC_LUMBERJACK := Color(0.55, 0.31, 0.20)
const CARRY_FOOD := Color(0.86, 0.75, 0.35)
const CARRY_WOOD := Color(0.51, 0.35, 0.20)
const HUT_WALL := Color(0.48, 0.33, 0.21)
const HUT_ROOF := Color(0.35, 0.23, 0.15)
const HUT_DOOR := Color(0.22, 0.14, 0.09)
const FIRE_STONE := Color(0.42, 0.42, 0.44)
const FIRE_LOG := Color(0.38, 0.26, 0.15)

var sim: Simulation


func _init(sim_ref: Simulation) -> void:
	sim = sim_ref


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var alpha := sim.alpha()
	var time := Time.get_ticks_msec() * 0.001
	for v in sim.villages:
		_draw_campfire(v)
		for hut in v.huts:
			_draw_hut(Vector2(hut) * Terrain.TILE)
	for s in sim.settlers:
		_draw_settler(s, alpha, time)


func _draw_campfire(v: Village) -> void:
	var c := v.center_pos
	for i in 6:
		var angle := TAU * i / 6.0
		draw_circle(c + Vector2.from_angle(angle) * 5.0, 1.4, FIRE_STONE)
	draw_line(c + Vector2(-3, 1), c + Vector2(3, -2), FIRE_LOG, 1.6)
	draw_line(c + Vector2(-3, -2), c + Vector2(3, 1), FIRE_LOG, 1.6)


func _draw_hut(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(2, 13), Vector2(13, 3)), SHADOW)
	draw_rect(Rect2(p + Vector2(2, 7), Vector2(12, 8)), HUT_WALL)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, 8),
		p + Vector2(8, 1),
		p + Vector2(16, 8),
	]), HUT_ROOF)
	draw_rect(Rect2(p + Vector2(7, 10), Vector2(3, 5)), HUT_DOOR)


func _draw_settler(s: Settler, alpha: float, time: float) -> void:
	var p := s.prev_pos.lerp(s.pos, alpha)
	var moving := s.prev_pos.distance_squared_to(s.pos) > 0.01
	var bob := 0.0
	if moving:
		bob = absf(sin(time * 9.0 + s.bob_phase)) * 1.2
	draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 2)), SHADOW)
	var tunic := TUNIC_GATHERER if s.job == Settler.Job.GATHERER else TUNIC_LUMBERJACK
	draw_rect(Rect2(p + Vector2(-2, -4 - bob), Vector2(4, 5)), tunic)
	draw_rect(Rect2(p + Vector2(-1, -7 - bob), Vector2(3, 3)), SKIN)
	if s.carrying == Settler.Carry.FOOD:
		draw_rect(Rect2(p + Vector2(-1, -10 - bob), Vector2(3, 2)), CARRY_FOOD)
	elif s.carrying == Settler.Carry.WOOD:
		draw_rect(Rect2(p + Vector2(-2, -10 - bob), Vector2(5, 2)), CARRY_WOOD)
