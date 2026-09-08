class_name Profiler
extends Node
## Misst, was das BILD kostet — nicht, was das Skript kostet.
##
## Start:  godot --path . -- --profile
##
## Dieser Harness existiert wegen eines Messfehlers, der eine ganze Runde lang
## unbemerkt blieb. Die Kosten der Beleuchtung wurden vorher mit
## `Performance.TIME_PROCESS` gemessen — und damit gar nicht gemessen:
##
##   TIME_PROCESS ist die Zeit, die Godot im _process-Schritt der Hauptschleife
##   verbringt. Das Zeichnen läuft danach und steckt NICHT darin.
##
## Herausgekommen war deshalb, die Beleuchtung koste nichts ("aus" 49,45 ms,
## "voll" 41,77 ms — also scheinbar billiger als gar keine). Auf einem echten
## Rechner bricht die Bildrate nachts trotzdem von 60 auf 20 ein. Die Zahl war
## nicht ungenau, sie war das falsche Mass.
##
## Was wirklich misst, ist die Engine selbst:
##
##   RenderingServer.viewport_set_measure_render_time(rid, true)
##   RenderingServer.viewport_get_measured_render_time_cpu(rid)   ## Aufbau
##   RenderingServer.viewport_get_measured_render_time_gpu(rid)   ## Zeichnen
##
## Beides sind Millisekunden je Bild. Der CPU-Wert ist die Zeit, in der der
## Renderer die Zeichenbefehle zusammenstellt; der GPU-Wert die Zeit, die die
## Grafikkarte zum Ausführen braucht. Ein Effekt, der die Füllrate frisst,
## zeigt sich im GPU-Wert; ein Effekt, der zu viele Einzelobjekte erzeugt, im
## CPU-Wert und in den Zeichenaufrufen.

## Wie viele Bilder je Messfenster gemittelt werden.
const SAMPLES := 40

## Bilder, die vor jeder Messung verworfen werden. Ein frisch angehängter
## Shader wird beim ersten Bild übersetzt; diese Spitze gehört nicht dazu.
const WARMUP := 45

var main: Node

var _vp: RID
var _rows: Array[Dictionary] = []

func _ready() -> void:
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	# Ohne Bildratengrenze misst man, was der Rechner hergibt, statt der Grenze.
	Engine.max_fps = 0
	_run()

func _run() -> void:
	print("=== LEISTUNGSMESSUNG ===")
	print("Renderer: %s   Grafik: %s" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
		RenderingServer.get_video_adapter_name()])

	main.start_game(true)
	await _frames(60)
	var world: Node2D = main._world
	if world == null:
		print("FEHLER: keine Welt")
		get_tree().quit(2)
		return
	var light: LightManager = world.light

	# Die Figur bleibt stehen: gemessen wird das Bild, nicht das Nachladen.
	world.player.velocity = Vector2.ZERO

	# --- Die Nachtfrage -------------------------------------------------------
	# Jede Zeile schaltet genau ein Mittel dazu. Was zwischen zwei Zeilen
	# dazukommt, ist der Preis dieses einen Mittels.
	var night: CanvasLayer = light.get_node("Nachtschicht")
	var vignette: TextureRect = night.get_node("Sichtgrenze")
	var glows: Node2D = night.get_node("Schein")
	var tint: CanvasModulate = light.get_node("Tageslicht")

	Settings.light = 0
	Settings.changed_and_save()
	await _measure(world, "Beleuchtung aus")

	Settings.light = 2
	Settings.changed_and_save()
	light.set_time(0.0)                    # tiefe Nacht
	tint.visible = true
	glows.visible = false
	vignette.visible = false
	await _measure(world, "nur Toenung (Nacht)")

	glows.visible = true
	await _measure(world, "+ Figurenlicht")

	vignette.visible = true
	await _measure(world, "+ Vignette (Nacht voll)")

	glows.visible = false
	vignette.visible = true
	await _measure(world, "nur Toenung + Vignette")

	glows.visible = true
	light.set_time(0.5)                    # Mittag: die Nachtschicht faellt weg
	await _measure(world, "Tag voll")

	# --- Was sonst noch kostet ------------------------------------------------
	Settings.light = 0
	Settings.changed_and_save()
	var save := [Settings.wind, Settings.particles, Settings.decor, Settings.water_detail]
	Settings.wind = 0
	Settings.particles = 0
	Settings.decor = 0
	Settings.water_detail = 0
	Settings.changed_and_save()
	await _frames(60)
	await _measure(world, "alles aus (Grundlast)")

	Settings.wind = save[0]
	Settings.particles = save[1]
	Settings.decor = save[2]
	Settings.water_detail = save[3]
	Settings.changed_and_save()

	_report()
	get_tree().quit(0)

## Ein Messfenster: aufwärmen, dann SAMPLES Bilder mitteln.
func _measure(world: Node2D, name: String) -> void:
	await _frames(WARMUP)
	var cpu := 0.0
	var gpu := 0.0
	var draws := 0.0
	var objs := 0.0
	var frame_ms := 0.0
	var t0 := Time.get_ticks_usec()
	for i in SAMPLES:
		await RenderingServer.frame_post_draw
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(_vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(_vp)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objs += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	frame_ms = float(Time.get_ticks_usec() - t0) / 1000.0 / SAMPLES
	_rows.append({
		"name": name,
		"cpu": cpu / SAMPLES,
		"gpu": gpu / SAMPLES,
		"frame": frame_ms,
		"fps": 1000.0 / maxf(frame_ms, 0.001),
		"draws": int(draws / SAMPLES),
		"objs": int(objs / SAMPLES),
	})

func _report() -> void:
	print("")
	print("%-26s %9s %9s %9s %7s %7s %7s" % [
		"Fall", "CPU ms", "GPU ms", "Bild ms", "FPS", "Aufrufe", "Objekte"])
	print("-".repeat(84))
	for r: Dictionary in _rows:
		print("%-26s %9.2f %9.2f %9.2f %7.0f %7d %7d" % [
			r["name"], r["cpu"], r["gpu"], r["frame"], r["fps"], r["draws"], r["objs"]])
	print("")
	# Die Aufschläge, um die es geht — als Differenz, nicht als Rohwert.
	var by := {}
	for r: Dictionary in _rows:
		by[r["name"]] = r
	_delta(by, "nur Toenung (Nacht)", "Beleuchtung aus", "Toenung allein")
	_delta(by, "+ Figurenlicht", "nur Toenung (Nacht)", "Figurenlicht allein")
	_delta(by, "nur Toenung + Vignette", "nur Toenung (Nacht)", "Vignette allein")
	_delta(by, "+ Vignette (Nacht voll)", "Beleuchtung aus", "Nacht insgesamt")

func _delta(by: Dictionary, a: String, b: String, what: String) -> void:
	if not (by.has(a) and by.has(b)):
		return
	var x: Dictionary = by[a]
	var y: Dictionary = by[b]
	print("  %-22s CPU %+6.2f ms   GPU %+6.2f ms   Bild %+6.2f ms" % [
		what, x["cpu"] - y["cpu"], x["gpu"] - y["gpu"], x["frame"] - y["frame"]])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
