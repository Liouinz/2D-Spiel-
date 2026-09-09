extends Node
## Autoload: sammelt Bild- und Renderzeiten. Eine Quelle für alle.
##
## Anzeige und automatische Qualitätsanpassung brauchen dieselben Zahlen. Wenn
## jede sich ihre eigenen holt, driften sie auseinander und man diskutiert
## anschliessend darüber, welche recht hat.
##
## Was hier steht, ist GEMESSEN. Godot liefert keine Systemauslastung in
## Prozent — weder für den Prozessor noch für die Grafikkarte —, deshalb steht
## so etwas hier auch nicht. Es gibt Bildzeiten, Renderzeiten, Zählwerte und
## Speicher, und das ist genug.
##
## Kosten: ein Eintrag in einen Ringpuffer je Bild, plus zwei Abfragen beim
## RenderingServer. Die Auswertung (Mittelwert, 1 % low) läuft nur, wenn jemand
## danach fragt — also viermal je Sekunde für die Anzeige, nicht 60-mal.

## Wie viele Bilder im Rückblick stehen. 240 sind bei 60 Bildern je Sekunde
## vier Sekunden — lang genug, dass ein einzelner Ruckler die Mittelwerte nicht
## dominiert, kurz genug, dass die Anzeige auf eine Änderung reagiert.
const WINDOW := 240

var _ms := PackedFloat32Array()
var _at: int = 0
var _filled: int = 0
var _vp: RID
var _cpu: float = 0.0
var _gpu: float = 0.0

## Geglättete Bildzeit für die automatische Qualitätsanpassung. Ein
## gleitender Mittelwert reagiert ruhiger als der Rohwert und schwingt nicht.
var _smooth_ms: float = 16.67

func _ready() -> void:
	process_priority = -100        # vor allem anderen, damit delta stimmt
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ms.resize(WINDOW)
	var vp := get_viewport()
	if vp != null:
		_vp = vp.get_viewport_rid()
		# Ohne dieses Einschalten liefert die Engine keine Renderzeiten.
		RenderingServer.viewport_set_measure_render_time(_vp, true)

func _process(delta: float) -> void:
	var ms := delta * 1000.0
	_ms[_at] = ms
	_at = (_at + 1) % WINDOW
	_filled = mini(_filled + 1, WINDOW)
	_smooth_ms = lerpf(_smooth_ms, ms, 0.05)
	if _vp.is_valid():
		_cpu = RenderingServer.viewport_get_measured_render_time_cpu(_vp)
		_gpu = RenderingServer.viewport_get_measured_render_time_gpu(_vp)

# --- Bildrate -----------------------------------------------------------------

## Die Bildrate dieses Augenblicks, wie Godot sie zählt.
func fps() -> int:
	return Engine.get_frames_per_second()

## Bildzeit des letzten Bildes in Millisekunden.
func frame_ms() -> float:
	return _ms[(_at - 1 + WINDOW) % WINDOW] if _filled > 0 else 0.0

## Geglättete Bildzeit — die Grundlage jeder Entscheidung über die Qualität.
func smooth_ms() -> float:
	return _smooth_ms

## Mittlere Bildrate über das Fenster.
func fps_avg() -> float:
	if _filled == 0:
		return 0.0
	var total := 0.0
	for i in _filled:
		total += _ms[i]
	var mean := total / _filled
	return 1000.0 / mean if mean > 0.0 else 0.0

## Die „1 % low": die Bildrate der langsamsten hundertstel Bilder.
##
## Das ist die Zahl, die beschreibt, ob es RUCKELT. Ein Mittelwert von 60 sagt
## nichts darüber, ob zwischendurch Bilder mit 90 ms dabei waren — und genau
## die spürt man.
func low1() -> float:
	if _filled < 20:
		return 0.0
	var sorted := _sorted_window()
	# Die schlechtesten ein Prozent, mindestens aber ein Bild.
	var n := maxi(1, _filled / 100)
	var total := 0.0
	for i in n:
		total += sorted[_filled - 1 - i]
	var mean := total / n
	return 1000.0 / mean if mean > 0.0 else 0.0

func _sorted_window() -> Array:
	var out: Array = []
	out.resize(_filled)
	for i in _filled:
		out[i] = _ms[i]
	out.sort()
	return out

# --- Renderzeiten -------------------------------------------------------------
# Beides in Millisekunden je Bild, direkt von der Engine. Ein Wert <= 0 heisst
# „hier misst der Treiber nichts" — dann zeigt die Anzeige einen Strich statt
# einer Null, die nach „nichts los" aussähe.

## Zeit, in der der Renderer die Zeichenbefehle zusammenstellt.
func cpu_ms() -> float:
	return _cpu

## Zeit, die die Grafikkarte zum Ausführen braucht.
func gpu_ms() -> float:
	return _gpu

# --- Speicher -----------------------------------------------------------------

## Speicher, den das Spiel selbst belegt (Bytes).
func game_memory() -> int:
	return OS.get_static_memory_usage()

## Arbeitsspeicher des Rechners: {"physical", "free", "available"} in Bytes.
## Nicht jedes System füllt jedes Feld; -1 heisst „unbekannt".
func system_memory() -> Dictionary:
	return OS.get_memory_info()

## Grafikspeicher in Bytes, soweit der Treiber ihn meldet.
func video_memory() -> int:
	return int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))

func texture_memory() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))

# --- Zählwerte ----------------------------------------------------------------

func draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func render_objects() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

func nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
