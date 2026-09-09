class_name WorldBuilder
extends RefCounted
## Erzeugt Karte, Kachelgrafik und Kachelsatz.
##
## Der Boden wird hier NICHT gemalt und die Kollision nicht gebaut — beides
## läuft chunkweise im ChunkStreamer. Bei 4,2 Millionen Kacheln wäre alles
## andere weder vom Speicher noch von der Zeit her tragbar.

var map: MapData
var art: TileArt
var ground: GroundTileSet            ## Kachelsatz mit Übergängen
var timings: Dictionary = {}         ## Dauer der Bauphasen in ms (Diagnose)

func _phase(name: String, started: int) -> int:
	timings[name] = Time.get_ticks_msec() - started
	return Time.get_ticks_msec()

func build(seed_value: int, fresh: bool = false) -> void:
	var t := Time.get_ticks_msec()
	map = MapData.new()
	map.generate(seed_value, fresh)
	t = _phase("karte", t)
	art = TileArt.build(seed_value)
	t = _phase("kacheln", t)
	ground = GroundTileSet.build(art, seed_value)
	t = _phase("kachelsatz", t)
