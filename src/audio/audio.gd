extends Node
## Autoload: alle Klänge werden prozedural erzeugt (keine Asset-Dateien nötig).
## Musik kommt in Phase 5 dazu; die Schnittstelle steht bereits.

const RATE := 22050
const MUSIC_RATE := 11025  ## Flächenklänge brauchen keine hohe Rate
const VOICES := 8

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music_player: AudioStreamPlayer
var _music_track: String = ""
var _music: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx["blip"] = _tone(660.0, 0.06, 0.35, "square")
	_sfx["confirm"] = _sequence([[523.0, 0.07], [784.0, 0.11]], 0.35)
	_sfx["open"] = _sequence([[392.0, 0.05], [587.0, 0.08]], 0.30)
	_sfx["close"] = _sequence([[587.0, 0.05], [392.0, 0.09]], 0.30)
	_sfx["step"] = _noise(0.055, 0.22)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	Settings.changed.connect(_apply_volumes)

func play_ui(name: String) -> void:
	_play(name if _sfx.has(name) else "blip", 1.0)

func play_step() -> void:
	_play("step", randf_range(0.9, 1.12))

func _play(name: String, pitch: float) -> void:
	if Settings.sfx_volume <= 0.001 or not _sfx.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sfx[name]
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(clampf(Settings.sfx_volume, 0.001, 1.0))
	p.play()

func play_music(track: String) -> void:
	_music_track = track
	_start_music()

func _start_music() -> void:
	if _music_track == "" or Settings.music_volume <= 0.001:
		_music_player.stop()
		return
	if not _music.has(_music_track):
		# Erst beim ersten Bedarf erzeugen — der Spielstart bleibt schnell.
		if _music_track != "menu" and _music_track != "world":
			return
		_music[_music_track] = _make_music(_music_track)
	if _music_player.stream != _music[_music_track] or not _music_player.playing:
		_music_player.stream = _music[_music_track]
		_music_player.play()
	_music_player.volume_db = linear_to_db(clampf(Settings.music_volume, 0.001, 1.0))

func _apply_volumes() -> void:
	_start_music()

# --- Musik -------------------------------------------------------------------

## Ruhige Endlosschleife aus vier Akkorden über einem Bordun.
## Alles rechnerisch erzeugt — keine Audiodateien im Projekt.
func _make_music(track: String) -> AudioStreamWAV:
	const BAR := 4.0
	var chords := [
		[220.00, 261.63, 329.63],   # a-moll
		[174.61, 220.00, 261.63],   # F-Dur
		[196.00, 246.94, 293.66],   # G-Dur
		[164.81, 207.65, 246.94],   # e-moll
	]
	var bright := track == "world"
	var total := int(MUSIC_RATE * BAR * chords.size())
	var buf := PackedFloat32Array()
	buf.resize(total)
	var drone := 110.0

	for i in total:
		var t := float(i) / MUSIC_RATE
		var bar := int(t / BAR) % chords.size()
		var local := fmod(t, BAR) / BAR
		# weiches Ein- und Ausblenden je Akkord -> nahtloser Übergang
		var env := sin(local * PI)
		env *= env
		var v := 0.0
		var chord: Array = chords[bar]
		for n in chord.size():
			var f: float = chord[n]
			var detune := 1.0 + sin(t * 0.27 + n) * 0.0016
			v += sin(TAU * f * detune * t) * (0.34 if n == 0 else 0.26)
			if bright:
				v += sin(TAU * f * 2.0 * t) * 0.07
		v *= env
		v += sin(TAU * drone * t) * 0.16 * (0.7 + 0.3 * sin(t * 0.35))
		buf[i] = v * 0.30

	if bright:
		_add_melody(buf, BAR)

	var stream := _wav(buf, MUSIC_RATE)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total
	return stream

## Sparsame Glockentöne über dem Klangteppich.
func _add_melody(buf: PackedFloat32Array, bar: float) -> void:
	var notes := [
		[0.6, 659.25], [1.8, 523.25], [4.7, 587.33], [6.2, 440.00],
		[8.5, 659.25], [10.1, 783.99], [12.4, 587.33], [14.0, 493.88],
	]
	for note: Array in notes:
		var start := int(float(note[0]) * MUSIC_RATE)
		var freq: float = note[1]
		var length := int(MUSIC_RATE * 1.1)
		for i in length:
			var idx := start + i
			if idx >= buf.size():
				break
			var t := float(i) / MUSIC_RATE
			var env: float = minf(1.0, t / 0.02) * pow(1.0 - float(i) / length, 3.0)
			buf[idx] += sin(TAU * freq * t) * env * 0.075

# --- Klangerzeugung ----------------------------------------------------------

func _wav(samples: PackedFloat32Array, rate: int = RATE) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s

func _tone(freq: float, dur: float, gain: float, shape: String) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var phase := fmod(freq * t, 1.0)
		var v := (1.0 if phase < 0.5 else -1.0) if shape == "square" else sin(phase * TAU)
		var env: float = minf(1.0, float(i) / (RATE * 0.005)) * pow(1.0 - float(i) / n, 2.0)
		buf[i] = v * env * gain
	return _wav(buf)

func _sequence(notes: Array, gain: float) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	for note: Array in notes:
		var freq: float = note[0]
		var dur: float = note[1]
		var n := int(RATE * dur)
		for i in n:
			var t := float(i) / RATE
			var v := sin(fmod(freq * t, 1.0) * TAU) * 0.7 + sin(fmod(freq * 2.0 * t, 1.0) * TAU) * 0.3
			var env: float = minf(1.0, float(i) / (RATE * 0.006)) * pow(1.0 - float(i) / n, 1.6)
			buf.append(v * env * gain)
	return _wav(buf)

func _noise(dur: float, gain: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := 0.0
	for i in n:
		# tiefpassgefiltertes Rauschen -> weicher Schritt auf Erde
		last = lerpf(last, rng.randf_range(-1.0, 1.0), 0.35)
		var env: float = pow(1.0 - float(i) / n, 2.5)
		buf[i] = last * env * gain
	return _wav(buf)
