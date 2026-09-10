extends Node

## Reproduzierbares Mess-Harness zu docs/performance.md. Aufruf:
##
##     godot --path . --rendering-driver opengl3 res://tests/benchmark.tscn
##
## Baut eine feste Weltsituation (6 Völker, 4000 Ticks vorgelaufen), friert die
## Tageszeit ein und misst die Wall-Clock-Frametime — einmal mit allem, einmal
## ohne einzelne Systeme. So lässt sich ein Engpass zuordnen, statt ihn zu
## vermuten.

const WARMUP := 45
const SAMPLES := 320

var main_node: Node
var _scenarios: Array = []
var _index := -1
var _frames := 0
var _times: Array[float] = []
var _last_us := 0
var _results: Array = []


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main_node = scene.instantiate()
	add_child(main_node)
	await get_tree().process_frame
	await get_tree().process_frame
	seed(12345)
	var sim = main_node.sim
	main_node.ui.menus.close_start()
	main_node.quality.set_profile(Quality.Profile.MEDIUM, true)
	main_node.quality.set_dynamic_enabled(false)
	var center: Vector2 = main_node.terrain.world_center()
	for i in 6:
		var a := TAU * i / 6.0
		sim.spawn_tribe(center + Vector2.from_angle(a) * 180.0)
	for i in 4000:
		sim._tick()
	# Zusätzlich ein paar Fackeln — die gab es in der Ausgangsmessung nicht,
	# sie kosten in der Lightmap aber real etwas.
	for i in 24:
		sim.place_torch(main_node.terrain.local_to_map(center + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 220.0)))
	print("SETUP: villages=%d settlers=%d huts=%d torches=%d" % [
		sim.villages.size(), sim.settlers.size(), sim.total_huts(), sim.torches.size()])
	_scenarios = [
		{"name": "Tag  (alles an)", "night": false, "off": []},
		{"name": "Nacht(alles an)", "night": true, "off": []},
		{"name": "Nacht ohne Lightmap", "night": true, "off": ["light"]},
		{"name": "Nacht ohne WorldRender", "night": true, "off": ["world"]},
		{"name": "Nacht nur Terrain", "night": true, "off": ["light", "glow", "overlay", "ui", "world", "water"]},
	]
	_next()


func _apply(scn: Dictionary) -> void:
	var sim = main_node.sim
	sim.speed = 1.0
	var target := 420 if scn.night else 100
	sim.tick_count = sim.tick_count - (sim.tick_count % Simulation.DAY_TICKS) + target
	sim.speed = 0.0
	var off: Array = scn.off
	for key in ["light", "glow", "overlay", "ui", "world", "water"]:
		_set_system(key, not off.has(key))


func _set_system(key: String, on: bool) -> void:
	var node: Node = null
	match key:
		"glow": node = main_node.fx_glow
		"overlay": node = main_node.fx_overlay
		"ui": node = main_node.ui
		"world": node = main_node.world_render
		"light": node = main_node.lighting
		"water": node = main_node.water_fx
	if node == null:
		return
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).visible = on
	if node is CanvasLayer:
		(node as CanvasLayer).visible = on


func _next() -> void:
	_index += 1
	if _index >= _scenarios.size():
		_report()
		return
	_apply(_scenarios[_index])
	_frames = 0
	_times.clear()
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if _index >= _scenarios.size():
		return
	var now := Time.get_ticks_usec()
	var dt := (now - _last_us) / 1000.0
	_last_us = now
	_frames += 1
	if _frames <= WARMUP:
		return
	_times.append(dt)
	if _times.size() >= SAMPLES:
		_finish()


func _finish() -> void:
	var sorted := _times.duplicate()
	sorted.sort()
	var sum := 0.0
	for t in sorted:
		sum += t
	var avg: float = sum / sorted.size()
	_results.append({
		"name": _scenarios[_index].name,
		"avg": avg,
		"fps": 1000.0 / avg,
		"p99": sorted[mini(int(sorted.size() * 0.99), sorted.size() - 1)],
		"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"lights": main_node.lighting.active_sources(),
		"cpu": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"lm": main_node.lighting.last_update_ms,
		"lmhz": main_node.lighting.updates_per_second,
	})
	_next()


func _report() -> void:
	print("=== FRAMEZEITEN ===")
	for r in _results:
		print("%-24s avg=%7.2fms  fps=%6.1f  1%%low=%7.2fms  cpu=%5.2fms  draws=%d  lichter=%d  lightmap=%.2fms@%.0fHz" % [
			r.name, r.avg, r.fps, r.p99, r.cpu, r.draws, r.lights, r.lm, r.lmhz])
	get_tree().quit()
