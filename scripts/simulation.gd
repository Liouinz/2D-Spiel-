class_name Simulation
extends Node

## Herzstück: feste Ticks (10/Sek.) getrennt vom Rendering (Masterplan §5).
## Simuliert Dörfer mit Wirtschaft (sichtbare Träger!), Geburten und Tod,
## Glauben-Ökonomie für Gottheit-Kräfte, Wetter, Waldwachstum, Lava-Abkühlung
## und den Tag/Nacht-Zyklus. Alles Erzählenswerte landet in der Chronik.

signal chronicle(text: String)
signal meteor_impact(world_pos: Vector2)
## Etwas hat die Wasseroberfläche berührt — der Wasser-Effektlayer macht daraus
## auslaufende Wellenringe.
signal water_disturbed(world_pos: Vector2, strength: float)
## Ein Regengebiet ist verklungen — der Effektlayer räumt seine Tropfen weg.
signal rain_ended(id: int)

const TICKS_PER_SECOND := 10.0
const TICKS_PER_YEAR := 200
const DAY_TICKS := 600
const MOVE_SPEED := 3.0

const HUT_FOOD := 6
const HUT_WOOD := 5
const BIRTH_FOOD := 2
const POP_PER_HUT := 3

const FAITH_START := 20.0
const FAITH_MAX := 200.0
const FAITH_PER_SETTLER := 0.002
const FAITH_PER_DELIVERY := 0.05
const COST_LIGHTNING := 10.0
const COST_RAIN := 6.0
const COST_BLESSING := 8.0
const COST_METEOR := 40.0

const LIGHTNING_RADIUS := 28.0
const METEOR_FALL_TICKS := 14
const METEOR_KILL_RADIUS := 52.0
const LAVA_COOL_TICKS := 400
const RAIN_TICKS := 80
const RAIN_RADIUS := 90.0

## Tempo eine Stufe hoch/runter — die Stufen sind dieselben wie im Menü.
const SPEED_STEPS: Array[float] = [0.0, 1.0, 3.0, 10.0]


## Wie nah ein Träger am Dorfplatz stehen muss, damit die Last zählt.
const DELIVERY_RADIUS := 26.0
const MAX_TORCHES := 240
const TORCH_RADIUS := 7.0 * Terrain.TILE
const WADE_SPEED := 0.55

var terrain: Terrain
var speed := 1.0
var tick_count := 0
var year := 1
var faith := FAITH_START

var villages: Array[Village] = []
var settlers: Array[Settler] = []
var rain_areas: Array = []
var meteors: Array = []
## Gesetzte Fackeln: leichte Datenobjekte, keine Nodes — sie sind gleichzeitig
## Lichtquelle (Lightmap) und Weltobjekt (WorldRender).
var torches: Array = []

var _lava_cells := {}
var _next_rain_id := 0
var _accum := 0.0
var _prev_speed := 1.0
var _last_fail_tick := -1000


func _init(terrain_ref: Terrain) -> void:
	terrain = terrain_ref


func _process(delta: float) -> void:
	_accum += delta * TICKS_PER_SECOND * speed
	if _accum > 50.0:
		_accum = 50.0
	while _accum >= 1.0:
		_accum -= 1.0
		_tick()


## Interpolationsfaktor fürs Rendering zwischen zwei Ticks.
func alpha() -> float:
	return clampf(_accum, 0.0, 1.0)


func time_of_day() -> float:
	return float(tick_count % DAY_TICKS) / DAY_TICKS


func night_factor() -> float:
	var t := time_of_day()
	if t < 0.45:
		return 0.0
	elif t < 0.55:
		return (t - 0.45) / 0.10
	elif t < 0.90:
		return 1.0
	return 1.0 - (t - 0.90) / 0.10


func day_phase_name() -> String:
	var t := time_of_day()
	if t < 0.45:
		return "Tag"
	elif t < 0.55:
		return "Abend"
	elif t < 0.90:
		return "Nacht"
	return "Morgen"


func set_speed(value: float) -> void:
	speed = value
	if value > 0.0:
		_prev_speed = value


func step_speed(direction: int) -> void:
	var current := 0
	for i in SPEED_STEPS.size():
		if is_equal_approx(SPEED_STEPS[i], speed):
			current = i
			break
	set_speed(SPEED_STEPS[clampi(current + direction, 0, SPEED_STEPS.size() - 1)])


## Setzt die Simulation für eine frische Welt zurück (das Terrain erneuert
## der Aufrufer). Die Kräfte-Ökonomie startet wieder bei null.
func reset() -> void:
	villages.clear()
	settlers.clear()
	rain_areas.clear()
	meteors.clear()
	torches.clear()
	_lava_cells.clear()
	tick_count = 0
	year = 1
	faith = FAITH_START
	_accum = 0.0
	chronicle.emit("Eine neue Welt liegt unberührt vor dir.")


func toggle_pause() -> void:
	if speed > 0.0:
		_prev_speed = speed
		speed = 0.0
	else:
		speed = _prev_speed


# --- Eingriffe der Gottheit -------------------------------------------------

func spawn_tribe(world_pos: Vector2) -> bool:
	var cell := terrain.local_to_map(world_pos)
	var t := terrain.get_type(cell)
	if Terrain.is_water(t) or t == Terrain.T_LAVA:
		chronicle.emit("Jahr %d: Hier kann kein Volk siedeln." % year)
		return false
	if t == Terrain.T_FOREST or t == Terrain.T_ROCK:
		terrain.set_type(cell, Terrain.T_GRASS)
	var v := Village.new()
	v.id = villages.size()
	v.name = NameGen.village_name()
	v.center = cell
	v.center_pos = terrain.map_to_local(cell)
	villages.append(v)
	for i in 4:
		_spawn_settler(v)
	chronicle.emit("Jahr %d: Das Volk von %s betrat die Welt." % [year, v.name])
	return true


func cast_lightning(world_pos: Vector2) -> bool:
	if not _try_spend(COST_LIGHTNING):
		return false
	terrain.burn_circle(terrain.local_to_map(world_pos), 2)
	var victims: Array[String] = []
	for i in range(settlers.size() - 1, -1, -1):
		if settlers[i].pos.distance_to(world_pos) < LIGHTNING_RADIUS:
			victims.append(settlers[i].name)
			settlers.remove_at(i)
	var destroyed := _destroy_huts_near(world_pos, LIGHTNING_RADIUS)
	if victims.size() == 1:
		chronicle.emit("Jahr %d: %s wurde vom Blitz erschlagen." % [year, victims[0]])
	elif victims.size() > 1:
		chronicle.emit("Jahr %d: Der Blitz erschlug %d Siedler." % [year, victims.size()])
	elif destroyed > 0:
		chronicle.emit("Jahr %d: Der Blitz zerschmetterte eine Hütte." % year)
	else:
		var witnesses := _count_settlers_near(world_pos, 200.0)
		if witnesses > 0:
			faith = minf(faith + 2.0, FAITH_MAX)
			chronicle.emit("Jahr %d: Das Volk erzittert vor deiner Macht am Himmel." % year)
	return true


func cast_rain(world_pos: Vector2) -> bool:
	if not _try_spend(COST_RAIN):
		return false
	_next_rain_id += 1
	rain_areas.append({"id": _next_rain_id, "pos": world_pos, "radius": RAIN_RADIUS, "ttl": RAIN_TICKS})
	chronicle.emit("Jahr %d: Warmer Regen fällt auf das Land." % year)
	return true


func cast_blessing(world_pos: Vector2) -> bool:
	var v := _nearest_village(world_pos, 150.0)
	if v == null:
		chronicle.emit("Jahr %d: Niemand ist da, um deinen Segen zu empfangen." % year)
		return false
	if not _try_spend(COST_BLESSING):
		return false
	v.food += 12
	v.fertile_until = tick_count + 600
	chronicle.emit("Jahr %d: Dein Segen liegt auf %s — die Speicher füllen sich." % [year, v.name])
	return true


func cast_meteor(world_pos: Vector2) -> bool:
	if not _try_spend(COST_METEOR):
		return false
	meteors.append({"pos": world_pos, "ttl": METEOR_FALL_TICKS})
	chronicle.emit("Jahr %d: Ein zorniges Licht erscheint am Himmel …" % year)
	return true


# --- Fackeln ----------------------------------------------------------------

func torch_at(cell: Vector2i) -> int:
	for i in torches.size():
		if torches[i].cell == cell:
			return i
	return -1


func place_torch(cell: Vector2i) -> bool:
	if not terrain.in_bounds(cell):
		return false
	if not Terrain.is_walkable(terrain.get_type(cell)):
		return false
	if torch_at(cell) >= 0:
		return false
	if torches.size() >= MAX_TORCHES:
		return false
	torches.append({
		"cell": cell,
		"pos": terrain.cell_center(cell),
		"radius": TORCH_RADIUS,
		"energy": 0.95,
		"phase": randf() * TAU,
	})
	return true


func remove_torch(cell: Vector2i) -> bool:
	var index := torch_at(cell)
	if index < 0:
		return false
	torches.remove_at(index)
	return true


## Fackeln, die durch Lava/Wasser ihren Halt verloren haben, verschwinden.
func _tick_torches() -> void:
	for i in range(torches.size() - 1, -1, -1):
		if not Terrain.is_walkable(terrain.get_type(torches[i].cell)):
			torches.remove_at(i)


## Terraforming hat Folgen: Wer ein Dorf flutet oder in Lava taucht, verliert
## die Hütten darauf. Vorher schwammen sie unbeeindruckt weiter.
func _tick_buildings() -> void:
	for v in villages:
		var lost := 0
		for i in range(v.huts.size() - 1, -1, -1):
			if not Terrain.is_walkable(terrain.get_type(v.huts[i])):
				v.huts.remove_at(i)
				lost += 1
		if lost > 0:
			chronicle.emit("Jahr %d: In %s versank%s %d Hütte%s." % [
				year, v.name, "" if lost == 1 else "en", lost, "" if lost == 1 else "n"])


func lava_cells() -> Array:
	return _lava_cells.keys()


# --- Simulations-Ticks ------------------------------------------------------

func _tick() -> void:
	tick_count += 1
	if tick_count % TICKS_PER_YEAR == 0:
		year += 1
	for s in settlers:
		s.prev_pos = s.pos
	for i in range(settlers.size() - 1, -1, -1):
		_tick_settler(i)
	if tick_count % 10 == 0:
		for v in villages:
			_tick_village(v)
	_tick_nature()
	if tick_count % 20 == 0:
		_tick_torches()
		_tick_buildings()
	_tick_rain()
	_tick_meteors()
	_tick_lava()
	faith = minf(faith + settlers.size() * FAITH_PER_SETTLER, FAITH_MAX)


func _tick_settler(index: int) -> void:
	var s := settlers[index]
	var age := (tick_count - s.born_tick) / TICKS_PER_YEAR
	if age > s.lifespan_years and randf() < 0.002:
		settlers.remove_at(index)
		if randf() < 0.3:
			chronicle.emit("Jahr %d: %s entschlief friedlich mit %d Jahren." % [year, s.name, age])
		return
	if s.pos.distance_to(s.target) < 2.0:
		_on_arrival(s)
		return
	var direction := (s.target - s.pos).normalized()
	var next := s.pos + direction * MOVE_SPEED
	var next_type := terrain.get_type(terrain.local_to_map(next))
	if next_type == Terrain.T_LAVA:
		chronicle.emit("Jahr %d: %s verging in glühender Lava." % [year, s.name])
		settlers.remove_at(index)
		return
	if next_type == Terrain.T_WATER_DEEP:
		# Tiefwasser bleibt unpassierbar. Wer heimkehrt, bekommt *das Dorf*
		# als neues Ziel — vorher wurde stattdessen ein Rohstoffziel gewürfelt,
		# und die Last wurde dann irgendwo im Nirgendwo verbucht.
		if s.state == Settler.State.RETURN:
			s.target = _home_target(villages[s.village_id])
		else:
			s.target = _find_resource_target(s)
		return
	if Terrain.is_wadeable(next_type):
		# Flachwasser wird durchwatet: langsamer, und es zieht eine Spur
		# aus Wellen hinter der Figur her.
		s.pos += direction * MOVE_SPEED * WADE_SPEED
		s.wading = true
		if (tick_count + s.village_id) % 3 == 0:
			water_disturbed.emit(s.pos, 0.55)
		return
	if s.wading:
		s.wading = false
		water_disturbed.emit(s.pos, 0.35)
	s.pos = next


func _on_arrival(s: Settler) -> void:
	var v := villages[s.village_id]
	if s.state == Settler.State.RETURN:
		# Abgeliefert wird nur *am Dorf*. Vorher genügte "irgendwo
		# angekommen": Wer unterwegs umgeleitet wurde, buchte seine Last
		# mitten in der Landschaft ein — inklusive Glauben dafür.
		if s.pos.distance_to(v.center_pos) > DELIVERY_RADIUS:
			s.target = _home_target(v)
			return
		if s.carrying == Settler.Carry.FOOD:
			v.food += 1
			faith = minf(faith + FAITH_PER_DELIVERY, FAITH_MAX)
		elif s.carrying == Settler.Carry.WOOD:
			v.wood += 1
			faith = minf(faith + FAITH_PER_DELIVERY, FAITH_MAX)
		s.carrying = Settler.Carry.NONE
		s.state = Settler.State.SEEK
		s.target = _find_resource_target(s)
		return
	var cell := terrain.local_to_map(s.pos)
	var t := terrain.get_type(cell)
	if s.job == Settler.Job.GATHERER and t == Terrain.T_GRASS:
		s.carrying = Settler.Carry.FOOD
		s.state = Settler.State.RETURN
		s.target = _home_target(v)
	elif s.job == Settler.Job.LUMBERJACK and t == Terrain.T_FOREST:
		s.carrying = Settler.Carry.WOOD
		if randf() < 0.3:
			terrain.set_type(cell, Terrain.T_GRASS)
		s.state = Settler.State.RETURN
		s.target = _home_target(v)
	else:
		s.target = _find_resource_target(s)


func _find_resource_target(s: Settler) -> Vector2:
	var v := villages[s.village_id]
	var want := Terrain.T_GRASS if s.job == Settler.Job.GATHERER else Terrain.T_FOREST
	for attempt in 12:
		var cell := v.center + Vector2i(randi_range(-16, 16), randi_range(-16, 16))
		if terrain.in_bounds(cell) and terrain.get_type(cell) == want:
			return terrain.map_to_local(cell)
	var own := terrain.local_to_map(s.pos)
	for attempt in 8:
		var cell := own + Vector2i(randi_range(-6, 6), randi_range(-6, 6))
		# Die eigene Zelle ist kein Ziel — sonst "geht" der Siedler dorthin,
		# wo er schon steht, und würfelt im nächsten Tick wieder von vorn.
		if cell != own and terrain.in_bounds(cell) and Terrain.is_walkable(terrain.get_type(cell)):
			return terrain.map_to_local(cell)
	# Gar nichts erreichbar: heimlaufen statt auf der Stelle einzufrieren.
	return _home_target(v)


## Ein leicht gestreuter Punkt am Dorfplatz — damit Träger nicht alle exakt
## auf demselben Pixel stehen.
func _home_target(v: Village) -> Vector2:
	return v.center_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))


func _tick_village(v: Village) -> void:
	if v.fallen:
		return
	var pop := _population(v)
	if pop == 0:
		v.fallen = true
		chronicle.emit("Jahr %d: %s ist verlassen. Nur der Wind erzählt noch von seinen Bewohnern." % [year, v.name])
		return
	if v.food >= HUT_FOOD and v.wood >= HUT_WOOD and pop >= v.huts.size() * 2 and v.huts.size() < 40:
		_build_hut(v)
	var cap := v.huts.size() * POP_PER_HUT + 4
	if pop < cap and v.food >= BIRTH_FOOD:
		var chance := 0.25 if tick_count < v.fertile_until else 0.06
		if randf() < chance:
			v.food -= BIRTH_FOOD
			_spawn_settler(v)


func _build_hut(v: Village) -> void:
	var radius := 2 + v.huts.size() / 4
	for attempt in 20:
		var cell := v.center + Vector2i(randi_range(-radius, radius), randi_range(-radius, radius))
		if not terrain.in_bounds(cell) or cell == v.center or v.huts.has(cell):
			continue
		var t := terrain.get_type(cell)
		if t == Terrain.T_GRASS or t == Terrain.T_SAND:
			v.huts.append(cell)
			v.food -= HUT_FOOD
			v.wood -= HUT_WOOD
			chronicle.emit("Jahr %d: In %s wurde eine neue Hütte errichtet." % [year, v.name])
			_check_stage(v)
			return


func _check_stage(v: Village) -> void:
	if v.huts.size() >= 8 and v.stage < Village.Stage.TOWN:
		v.stage = Village.Stage.TOWN
		chronicle.emit("Jahr %d: Aus dem Dorf %s ist eine Stadt geworden!" % [year, v.name])
	elif v.huts.size() >= 3 and v.stage < Village.Stage.VILLAGE:
		v.stage = Village.Stage.VILLAGE
		chronicle.emit("Jahr %d: Aus dem Lager %s ist ein Dorf geworden." % [year, v.name])


func _spawn_settler(v: Village) -> void:
	var s := Settler.new()
	s.name = NameGen.settler_name()
	s.village_id = v.id
	s.born_tick = tick_count
	s.lifespan_years = randi_range(55, 85)
	s.bob_phase = randf() * TAU
	var lumberjacks := 0
	var pop := 0
	for other in settlers:
		if other.village_id == v.id:
			pop += 1
			if other.job == Settler.Job.LUMBERJACK:
				lumberjacks += 1
	s.job = Settler.Job.LUMBERJACK if lumberjacks * 3 < pop else Settler.Job.GATHERER
	var origin := v.center_pos
	if not v.huts.is_empty() and randf() < 0.7:
		origin = terrain.map_to_local(v.huts.pick_random())
	s.pos = origin + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	s.prev_pos = s.pos
	s.target = s.pos
	settlers.append(s)


func _tick_nature() -> void:
	for i in 12:
		var cell := terrain.random_cell()
		if terrain.get_type(cell) != Terrain.T_GRASS:
			continue
		var near_forest := false
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if terrain.get_type(cell + offset) == Terrain.T_FOREST:
				near_forest = true
				break
		if near_forest and randf() < 0.12:
			terrain.set_type(cell, Terrain.T_FOREST)


func _tick_rain() -> void:
	for i in range(rain_areas.size() - 1, -1, -1):
		var area: Dictionary = rain_areas[i]
		area.ttl -= 1
		if area.ttl <= 0:
			rain_areas.remove_at(i)
			rain_ended.emit(area.id)
			continue
		for j in 6:
			var radius: float = area.radius
			var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * radius
			if offset.length() > area.radius:
				continue
			var cell: Vector2i = terrain.local_to_map(area.pos + offset)
			var t := terrain.get_type(cell)
			if t == Terrain.T_SAND and randf() < 0.5:
				terrain.set_type(cell, Terrain.T_GRASS)
			elif t == Terrain.T_GRASS and randf() < 0.08:
				terrain.set_type(cell, Terrain.T_FOREST)
			elif t == Terrain.T_LAVA:
				terrain.set_type(cell, Terrain.T_ROCK)
				_lava_cells.erase(cell)
			elif Terrain.is_water(t) and randf() < 0.5:
				water_disturbed.emit(area.pos + offset, 0.3)


func _tick_meteors() -> void:
	for i in range(meteors.size() - 1, -1, -1):
		var m: Dictionary = meteors[i]
		m.ttl -= 1
		if m.ttl > 0:
			continue
		meteors.remove_at(i)
		_meteor_hit(m.pos)


func _meteor_hit(world_pos: Vector2) -> void:
	var center := terrain.local_to_map(world_pos)
	terrain.burn_circle(center, 4)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := center + Vector2i(dx, dy)
			if terrain.in_bounds(cell) and not Terrain.is_water(terrain.get_type(cell)):
				terrain.set_type(cell, Terrain.T_LAVA)
				_lava_cells[cell] = LAVA_COOL_TICKS
	var killed := 0
	for i in range(settlers.size() - 1, -1, -1):
		if settlers[i].pos.distance_to(world_pos) < METEOR_KILL_RADIUS:
			settlers.remove_at(i)
			killed += 1
	var destroyed := _destroy_huts_near(world_pos, METEOR_KILL_RADIUS)
	if killed > 0 or destroyed > 0:
		chronicle.emit("Jahr %d: Der Meteor riss %d Siedler und %d Hütten ins Verderben." % [year, killed, destroyed])
	else:
		chronicle.emit("Jahr %d: Ein Meteor schlug ein. Die Erde brennt noch immer." % year)
	meteor_impact.emit(world_pos)


func _tick_lava() -> void:
	if _lava_cells.is_empty():
		return
	for cell in _lava_cells.keys():
		_lava_cells[cell] -= 1
		if _lava_cells[cell] <= 0:
			if terrain.get_type(cell) == Terrain.T_LAVA:
				terrain.set_type(cell, Terrain.T_ROCK)
			_lava_cells.erase(cell)


# --- Helfer -----------------------------------------------------------------

func _population(v: Village) -> int:
	var pop := 0
	for s in settlers:
		if s.village_id == v.id:
			pop += 1
	return pop


func total_food() -> int:
	var sum := 0
	for v in villages:
		sum += v.food
	return sum


func total_wood() -> int:
	var sum := 0
	for v in villages:
		sum += v.wood
	return sum


func total_huts() -> int:
	var sum := 0
	for v in villages:
		sum += v.huts.size()
	return sum


func living_villages() -> int:
	var count := 0
	for v in villages:
		if not v.fallen:
			count += 1
	return count


func _nearest_village(world_pos: Vector2, max_dist: float) -> Village:
	var best: Village = null
	var best_dist := max_dist
	for v in villages:
		if v.fallen:
			continue
		var d := v.center_pos.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best = v
	return best


func _count_settlers_near(world_pos: Vector2, radius: float) -> int:
	var count := 0
	for s in settlers:
		if s.pos.distance_to(world_pos) < radius:
			count += 1
	return count


func _destroy_huts_near(world_pos: Vector2, radius: float) -> int:
	var destroyed := 0
	for v in villages:
		for i in range(v.huts.size() - 1, -1, -1):
			if terrain.map_to_local(v.huts[i]).distance_to(world_pos) < radius:
				v.huts.remove_at(i)
				destroyed += 1
	return destroyed


func _try_spend(cost: float) -> bool:
	if faith >= cost:
		faith -= cost
		return true
	if tick_count - _last_fail_tick > 20:
		_last_fail_tick = tick_count
		chronicle.emit("Dein Einfluss ist zu schwach — %d Glaube nötig, %d vorhanden." % [int(cost), int(faith)])
	return false
