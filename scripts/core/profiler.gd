class_name GameProfiler
extends Node

## Sammelt ausschliesslich Werte, die wirklich gemessen werden können.
## Was die GL-Compatibility-Pipeline nicht liefert (z. B. echte GPU-Zeit),
## wird als "n/v" ausgewiesen statt geschätzt — erfundene Zahlen wären beim
## Optimieren schlimmer als gar keine.

const HISTORY := 240
const SLOW_REFRESH := 0.5
## Die ersten Bilder enthalten Weltgenerierung und Shader-Kompilierung. Sie
## hier mitzuzählen würde "1 % Low" für den Rest der Sitzung verfälschen.
const WARMUP_FRAMES := 30

var frame_ms := 0.0
var frame_avg_ms := 0.0
var frame_low_ms := 0.0        ## 1 % Low (99. Perzentil der Frametime)
var frame_max_ms := 0.0
var fps_avg := 0.0

var counters := {}

var _times := PackedFloat32Array()
var _cursor := 0
var _filled := 0
var _last_us := 0
var _slow_timer := 0.0
var _warmup := WARMUP_FRAMES
var _mem := {}
var _sorted := PackedFloat32Array()


func _ready() -> void:
	_times.resize(HISTORY)
	_sorted.resize(HISTORY)
	_last_us = Time.get_ticks_usec()
	process_priority = -100
	_refresh_slow()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	frame_ms = (now - _last_us) * 0.001
	_last_us = now
	if _warmup > 0:
		_warmup -= 1
		return
	_times[_cursor] = frame_ms
	_cursor = (_cursor + 1) % HISTORY
	_filled = mini(_filled + 1, HISTORY)
	_slow_timer -= delta
	if _slow_timer <= 0.0:
		_slow_timer = SLOW_REFRESH
		_refresh_slow()


## Teure Abfragen (Statistik, Speicherinfo) laufen nur 2×/Sekunde —
## das Overlay selbst darf keine Bildrate kosten.
func _refresh_slow() -> void:
	if _filled == 0:
		return
	var sum := 0.0
	var peak := 0.0
	for i in _filled:
		var t := _times[i]
		sum += t
		peak = maxf(peak, t)
		_sorted[i] = t
	frame_avg_ms = sum / _filled
	frame_max_ms = peak
	fps_avg = 1000.0 / maxf(frame_avg_ms, 0.001)
	var window := _sorted.slice(0, _filled)
	window.sort()
	frame_low_ms = window[mini(int(_filled * 0.99), _filled - 1)]
	_mem = OS.get_memory_info()


func set_counter(key: String, value: Variant) -> void:
	counters[key] = value


func counter(key: String, fallback: Variant = 0) -> Variant:
	return counters.get(key, fallback)


# --- Gemessene Engine-Werte -------------------------------------------------

func process_ms() -> float:
	return Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0


func physics_ms() -> float:
	return Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0


func draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func render_objects() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))


func render_primitives() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func video_mem_bytes() -> int:
	return int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))


func texture_mem_bytes() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))


func static_mem_bytes() -> int:
	return int(Performance.get_monitor(Performance.MEMORY_STATIC))


func node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


func object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func ram_available_bytes() -> int:
	return int(_mem.get("available", -1))


func ram_physical_bytes() -> int:
	return int(_mem.get("physical", -1))


static func format_bytes(bytes: int) -> String:
	if bytes < 0:
		return "n/v"
	if bytes >= 1073741824:
		return "%.2f GB" % (bytes / 1073741824.0)
	if bytes >= 1048576:
		return "%.1f MB" % (bytes / 1048576.0)
	return "%.0f KB" % (bytes / 1024.0)
