class_name Simulation
extends Node

## Herzstück: Die Welt tickt in festen Schritten (10 Ticks/Sek.), die Grafik
## läuft unabhängig davon — das ermöglicht Zeitraffer ×1/×3/×10 (Masterplan §5).

signal chronicle(text: String)

const TICKS_PER_SECOND := 10.0
const TICKS_PER_YEAR := 200
const MOVE_SPEED := 3.0
const GATHER_CHANCE := 0.5
const HUT_COST := 8
const MAX_POP_PER_HUT := 3
const LIGHTNING_RADIUS := 28.0

var terrain: Terrain
var speed := 1.0
var tick_count := 0
var year := 1

var settlers: Array[Settler] = []
var huts: Array[Vector2i] = []
var food := 0

var _accum := 0.0
var _prev_speed := 1.0


func _init(terrain_ref: Terrain) -> void:
	terrain = terrain_ref


func _process(delta: float) -> void:
	_accum += delta * TICKS_PER_SECOND * speed
	if _accum > 50.0:
		_accum = 50.0
	while _accum >= 1.0:
		_accum -= 1.0
		_tick()


func set_speed(value: float) -> void:
	speed = value
	if value > 0.0:
		_prev_speed = value


func toggle_pause() -> void:
	if speed > 0.0:
		_prev_speed = speed
		speed = 0.0
	else:
		speed = _prev_speed


func spawn_tribe(world_pos: Vector2) -> void:
	var cell := terrain.local_to_map(world_pos)
	if terrain.get_type(cell) == Terrain.T_WATER:
		chronicle.emit("Jahr %d: Im Wasser kann kein Volk siedeln." % year)
		return
	for i in 3:
		var s := Settler.new()
		s.pos = world_pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		s.target = s.pos
		settlers.append(s)
	chronicle.emit("Jahr %d: Ein Volk betrat die Welt." % year)


func strike_lightning(world_pos: Vector2) -> void:
	terrain.burn_circle(terrain.local_to_map(world_pos), 2)
	var killed := 0
	for i in range(settlers.size() - 1, -1, -1):
		if settlers[i].pos.distance_to(world_pos) < LIGHTNING_RADIUS:
			settlers.remove_at(i)
			killed += 1
	var destroyed := 0
	for i in range(huts.size() - 1, -1, -1):
		if terrain.map_to_local(huts[i]).distance_to(world_pos) < LIGHTNING_RADIUS:
			huts.remove_at(i)
			destroyed += 1
	if killed > 0 or destroyed > 0:
		chronicle.emit("Jahr %d: Der Himmel schlug zu — %d Siedler und %d Hütten vergingen im Feuer." % [year, killed, destroyed])
	else:
		chronicle.emit("Jahr %d: Ein Blitz traf die Erde. Das Volk blickt furchtsam zum Himmel." % year)


func _tick() -> void:
	tick_count += 1
	if tick_count % TICKS_PER_YEAR == 0:
		year += 1
	for s in settlers:
		_tick_settler(s)
	_try_build_hut()
	_try_spawn_settlers()


func _tick_settler(s: Settler) -> void:
	if s.pos.distance_to(s.target) < 2.0:
		var cell := terrain.local_to_map(s.pos)
		if terrain.get_type(cell) == Terrain.T_GRASS and randf() < GATHER_CHANCE:
			food += 1
		s.target = _random_walk_target(s.pos)
	else:
		var next := s.pos + (s.target - s.pos).normalized() * MOVE_SPEED
		if terrain.get_type(terrain.local_to_map(next)) == Terrain.T_WATER:
			s.target = _random_walk_target(s.pos)
		else:
			s.pos = next


func _random_walk_target(from: Vector2) -> Vector2:
	var base := terrain.local_to_map(from)
	for attempt in 8:
		var cell := base + Vector2i(randi_range(-8, 8), randi_range(-8, 8))
		if terrain.in_bounds(cell) and terrain.get_type(cell) != Terrain.T_WATER:
			return terrain.map_to_local(cell)
	return from


func _try_build_hut() -> void:
	if food < HUT_COST or settlers.is_empty():
		return
	if huts.size() >= settlers.size():
		return
	var s: Settler = settlers[randi() % settlers.size()]
	var base := terrain.local_to_map(s.pos)
	for attempt in 10:
		var cell := base + Vector2i(randi_range(-3, 3), randi_range(-3, 3))
		if terrain.in_bounds(cell) and terrain.get_type(cell) == Terrain.T_GRASS and not huts.has(cell):
			huts.append(cell)
			food -= HUT_COST
			chronicle.emit("Jahr %d: Eine neue Hütte wurde errichtet." % year)
			return


func _try_spawn_settlers() -> void:
	var cap := huts.size() * MAX_POP_PER_HUT + 3
	for hut in huts:
		if settlers.size() >= cap:
			return
		if randf() < 0.003:
			var s := Settler.new()
			s.pos = terrain.map_to_local(hut)
			s.target = s.pos
			settlers.append(s)
