class_name MapData
extends RefCounted
## Die Karte als Daten: Bodentyp je Feld. Kein Rendering hier.
##
## Bewusst nur drei Materialien. Vorher waren es neun (Wiese, Waldboden, Weg,
## Pflaster, Fels, Tiefwasser); die brachten mehr Fehler als Spielwert. Was
## bleibt, muss zuverlässig funktionieren.

enum Tile { GRASS, SAND, WATER, COUNT }

## Was ein Gelände ist — an EINER Stelle, nicht mehrfach nachgebaut.
##
## `swim`   hier wird geschwommen statt gelaufen
## `solid`  hält auf: hier kommt niemand durch
##
## Sichtbares Gelände und tatsächliche Begehbarkeit stammen damit aus derselben
## Quelle und können nicht auseinanderlaufen.
const TERRAIN := {
	Tile.GRASS: {"swim": false, "solid": false},
	Tile.SAND:  {"swim": false, "solid": false},
	Tile.WATER: {"swim": true,  "solid": false},
}

## Anzeigename je Bodentyp — für Bau-Leiste, Inventar und Entwicklerinfo.
const NAMES := {
	Tile.GRASS: "Gras",
	Tile.SAND: "Sand",
	Tile.WATER: "Wasser",
}

## Eine Eigenschaft eines Bodentyps. Unbekannte Werte verhalten sich wie Gras.
static func terrain(tile: int, key: String) -> Variant:
	var row: Dictionary = TERRAIN.get(tile, TERRAIN[Tile.GRASS])
	return row[key]

var tiles := PackedByteArray()

func _init() -> void:
	tiles.resize(Config.MAP_W * Config.MAP_H)

func idx(x: int, y: int) -> int:
	return y * Config.MAP_W + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < Config.MAP_W and y < Config.MAP_H

func get_tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Tile.WATER
	# Unbekannte Werte hier abfangen statt beim Laden: eine beschädigte Datei
	# darf nicht in die Kachelsuche durchschlagen, aber 4,2 Millionen Bytes
	# beim Start durchzugehen kostete 100 ms für nichts.
	var t := tiles[idx(x, y)]
	return t if t < Tile.COUNT else Tile.GRASS

func set_tile(x: int, y: int, t: int) -> void:
	if in_bounds(x, y):
		tiles[idx(x, y)] = t

func is_water(x: int, y: int) -> bool:
	return get_tile(x, y) == Tile.WATER

## Kann hier geschwommen werden?
func is_swimmable(x: int, y: int) -> bool:
	return in_bounds(x, y) and terrain(get_tile(x, y), "swim")

## Begehbarkeit wird gerechnet statt gespeichert.
##
## Kein zweites ganzseitiges Feld: bei 2048 x 2048 Blöcken wären das 4,2 MB,
## die nach jedem gesetzten Block nachgeführt werden müssten. Die Regel ist
## ohnehin kurz — nur der Weltrand hält auf, Wasser wird durchschwommen.
func is_solid(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	if x == 0 or y == 0 or x == Config.MAP_W - 1 or y == Config.MAP_H - 1:
		return true
	return terrain(get_tile(x, y), "solid")

## Baut die Karte auf: eine leere Grasfläche mit unsichtbarer Wand am Rand.
##
## `fresh` entscheidet, ob eine gespeicherte Karte geladen wird. Das Hauptmenü
## trennt beides sauber: „Fortsetzen" lädt, „Neue Welt" fängt von vorn an. Die
## Datei wird dabei NICHT gelöscht — sie wird erst beim nächsten Speichern
## überschrieben, und bis dahin ist der alte Stand noch da.
func generate(_seed_value: int, fresh: bool = false) -> void:
	# fill() statt einer Doppelschleife: bei 4,2 Millionen Feldern wären das
	# sonst mehrere Sekunden, so ist es ein Speicherbefehl.
	tiles.fill(Tile.GRASS)
	if fresh:
		return
	var saved := load_user()
	if not saved.is_empty():
		tiles = saved

## Sucht ausgehend von `start` das nächste freie, begehbare Feld.
func find_free_near(start: Vector2i) -> Vector2i:
	if not is_solid(start.x, start.y):
		return start
	for r in range(1, 12):
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				var p := start + Vector2i(ox, oy)
				if in_bounds(p.x, p.y) and not is_solid(p.x, p.y):
					return p
	return start

# --- Gebaute Karte sichern ---------------------------------------------------

const SAVE_PATH := "user://karte.dat"
const SAVE_MAGIC := 0x484C4154   ## "TALH"
const SAVE_VERSION := 3          ## 1 = roh, 2 = Zstd, 3 = nur noch drei Typen

## Alte Karten weiterverwenden.
##
## Bis Fassung 2 gab es neun Bodentypen mit anderen Nummern. Statt solche
## Dateien zu verwerfen, werden die Nummern umgeschrieben: alles, was weder
## Sand noch Wasser war, wird Gras.
const V2_TO_V3 := {0: Tile.GRASS, 1: Tile.GRASS, 2: Tile.GRASS, 3: Tile.GRASS,
	4: Tile.SAND, 5: Tile.GRASS, 6: Tile.WATER, 7: Tile.WATER, 8: Tile.GRASS}

## Schreibt die gebaute Karte. Bei 2048 x 2048 sind das roh 4,2 MB; eine Karte,
## auf der erst ein paar Häuser stehen, ist fast überall Gras und schrumpft mit
## Zstd auf wenige Kilobyte.
func save_user() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Karte konnte nicht gespeichert werden: %s" % SAVE_PATH)
		return false
	var packed := tiles.compress(FileAccess.COMPRESSION_ZSTD)
	f.store_32(SAVE_MAGIC)
	f.store_32(SAVE_VERSION)
	f.store_32(Config.MAP_W)
	f.store_32(Config.MAP_H)
	f.store_32(tiles.size())
	f.store_buffer(packed)
	f.close()
	return true

## Liest die gespeicherte Karte und passt sie notfalls an Weltgrösse und
## Bodentypen von heute an. Nur bei kaputten Dateien kommt nichts zurück.
static func load_user() -> PackedByteArray:
	if not FileAccess.file_exists(SAVE_PATH):
		return PackedByteArray()
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null or f.get_length() < 16:
		return PackedByteArray()
	var magic := f.get_32()
	var version := f.get_32()
	var sw := f.get_32()
	var sh := f.get_32()
	if magic != SAVE_MAGIC or version > SAVE_VERSION or sw <= 0 or sh <= 0:
		print("Gespeicherte Karte nicht lesbar (Fassung %d) — sie wird übergangen." % version)
		return PackedByteArray()

	var data := PackedByteArray()
	if version == 1:
		data = f.get_buffer(sw * sh)
	else:
		var raw := f.get_32()
		data = f.get_buffer(f.get_length() - f.get_position()).decompress(
			raw, FileAccess.COMPRESSION_ZSTD)
	f.close()
	if data.size() != sw * sh:
		print("Gespeicherte Karte unvollständig — sie wird übergangen.")
		return PackedByteArray()

	if version < 3:
		var changed := 0
		for i in data.size():
			var new_t: int = V2_TO_V3.get(data[i], Tile.GRASS)
			if new_t != data[i]:
				changed += 1
			data[i] = new_t
		print("Alte Karte übernommen: %d Felder auf Gras, Sand oder Wasser umgesetzt." % changed)

	if sw == Config.MAP_W and sh == Config.MAP_H:
		return data
	return _fit(data, sw, sh)

## Setzt eine Karte anderer Größe mittig in die heutige ein.
static func _fit(data: PackedByteArray, sw: int, sh: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(Config.MAP_W * Config.MAP_H)
	out.fill(Tile.GRASS)
	var ox := (Config.MAP_W - sw) / 2
	var oy := (Config.MAP_H - sh) / 2
	for y in sh:
		var ty := oy + y
		if ty < 0 or ty >= Config.MAP_H:
			continue
		for x in sw:
			var tx := ox + x
			if tx < 0 or tx >= Config.MAP_W:
				continue
			out[ty * Config.MAP_W + tx] = data[y * sw + x]
	print("Gespeicherte Karte war %d x %d — mittig in %d x %d übernommen." % [
		sw, sh, Config.MAP_W, Config.MAP_H])
	return out

## Gibt es überhaupt eine gebaute Karte? Das Hauptmenü zeigt „Fortsetzen" nur
## dann an.
static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Löscht die gespeicherte Karte (der Selbsttest räumt damit hinter sich auf).
static func clear_user() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
