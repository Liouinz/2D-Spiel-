class_name MapData
extends RefCounted
## Die Karte als Daten: Bodentyp je Kachel + Begehbarkeit. Kein Rendering hier.

enum Tile { GRASS, MEADOW, FOREST, PATH, SAND, ROCK, WATER, DEEP_WATER, COBBLE, COUNT }

var tiles := PackedByteArray()

func _init() -> void:
	tiles.resize(Config.MAP_W * Config.MAP_H)

func idx(x: int, y: int) -> int:
	return y * Config.MAP_W + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < Config.MAP_W and y < Config.MAP_H

func get_tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Tile.DEEP_WATER
	# Unbekannte Werte hier abfangen statt beim Laden: eine beschädigte Datei
	# darf nicht in die Kachelsuche durchschlagen, aber 4,2 Millionen Bytes
	# beim Start durchzugehen kostete 100 ms für nichts.
	var t := tiles[idx(x, y)]
	return t if t < Tile.COUNT else Tile.GRASS

func set_tile(x: int, y: int, t: int) -> void:
	if in_bounds(x, y):
		tiles[idx(x, y)] = t

func is_water(x: int, y: int) -> bool:
	var t := get_tile(x, y)
	return t == Tile.WATER or t == Tile.DEEP_WATER

## Begehbarkeit wird gerechnet statt gespeichert.
##
## Früher lag daneben ein zweites ganzseitiges Feld; bei 2048 x 2048 Blöcken
## wären das 4,2 MB gewesen, die nach jedem gesetzten Block hätten nachgeführt
## werden müssen. Die Regel ist ohnehin kurz.
##
## FLACHES Wasser hält nicht mehr auf — dort wird geschwommen. Tiefwasser
## schon: das ist die Grenze, hinter der es nicht weitergeht, und im Inselmodus
## umschließt es die ganze Insel.
func is_solid(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	if x == 0 or y == 0 or x == Config.MAP_W - 1 or y == Config.MAP_H - 1:
		return true
	return get_tile(x, y) == Tile.DEEP_WATER

## Kann hier geschwommen werden?
func is_swimmable(x: int, y: int) -> bool:
	return in_bounds(x, y) and get_tile(x, y) == Tile.WATER

## Höhenstufe eines Feldes. Fels liegt eine Stufe höher als der übrige Boden —
## man muss hinaufspringen und kann wieder herunter. Damit bekommt die
## Leertaste einen Zweck.
##
## Absichtlich eine Zahl statt eines Wahrheitswerts: so lassen sich später
## weitere Stufen ergänzen, ohne die Bewegungsregel anzufassen.
func level_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return 0
	return 1 if get_tile(x, y) == Tile.ROCK else 0

## Baut die Karte auf. Im Aufbaumodus entsteht eine leere Fläche, sonst die
## komplette Insel.
func generate(seed_value: int) -> void:
	if Config.EMPTY_WORLD:
		_generate_flat()
		return
	_generate_island(seed_value)

## Leere Fläche mit unsichtbarer Wand am Rand. Der Boden bleibt Gras, damit das
## rote Raster darauf gut lesbar ist. Liegt eine gespeicherte Karte vor, wird
## stattdessen sie geladen.
func _generate_flat() -> void:
	# fill() statt einer Doppelschleife: bei 4,2 Millionen Kacheln wären das
	# sonst mehrere Sekunden, so ist es ein Speicherbefehl.
	tiles.fill(Tile.GRASS)
	var saved := load_user()
	if not saved.is_empty():
		tiles = saved

# --- Gebaute Karte sichern ---------------------------------------------------

const SAVE_PATH := "user://karte.dat"
const SAVE_MAGIC := 0x484C4154   ## "TALH"
const SAVE_VERSION := 2          ## 1 = unkomprimiert, 2 = Zstd

## Schreibt die gebaute Karte. Gespeichert werden nur die Bodentypen — die
## Begehbarkeit lässt sich daraus jederzeit wieder ableiten.
##
## Bei 2048 x 2048 Blöcken sind das roh 4,2 MB. Eine Karte, auf der erst ein
## paar Häuser stehen, ist fast überall Gras und schrumpft mit Zstd auf wenige
## Kilobyte — deshalb wird komprimiert, nicht roh geschrieben.
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

## Liest die gespeicherte Karte und passt sie notfalls auf die heutige
## Weltgröße an.
##
## Wächst die Welt zwischen zwei Fassungen, wäre es das Einfachste, die alte
## Datei zu verwerfen — aber dann ist die Arbeit weg. Stattdessen wird die alte
## Karte MITTIG in die neue eingesetzt. Nur bei kaputten oder unbekannten
## Dateien kommt ein leeres Ergebnis zurück.
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
	var copied := 0
	for y in sh:
		var ty := oy + y
		if ty < 0 or ty >= Config.MAP_H:
			continue
		for x in sw:
			var tx := ox + x
			if tx < 0 or tx >= Config.MAP_W:
				continue
			out[ty * Config.MAP_W + tx] = data[y * sw + x]
			copied += 1
	print("Gespeicherte Karte war %d x %d — mittig in %d x %d übernommen (%d Blöcke)." % [
		sw, sh, Config.MAP_W, Config.MAP_H, copied])
	return out

## Löscht die gespeicherte Karte (der Selbsttest räumt damit hinter sich auf).
static func clear_user() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _generate_island(seed_value: int) -> void:
	var shape := FastNoiseLite.new()
	shape.seed = seed_value
	shape.frequency = 0.035
	var region := FastNoiseLite.new()
	region.seed = seed_value + 17
	region.frequency = 0.05

	var cx := Config.MAP_W * 0.5
	var cy := Config.MAP_H * 0.5
	var rx := Config.MAP_W * 0.47
	var ry := Config.MAP_H * 0.46

	for y in Config.MAP_H:
		for x in Config.MAP_W:
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := sqrt(dx * dx + dy * dy) + shape.get_noise_2d(x, y) * 0.14
			d = maxf(d, _bay_distance(x, y, shape))
			var t: int
			if d > 1.12:
				t = Tile.DEEP_WATER
			elif d > 0.97:
				t = Tile.WATER
			elif d > 0.90:
				t = Tile.SAND
			else:
				t = _land_region(x, y, region)
			set_tile(x, y, t)

	_blur_regions()
	_carve_roads()
	_carve_plaza()

## Franst die Grenzen zwischen Gras, Wiese und Wald leicht aus. Früher musste
## das die harten Kachelkanten kaschieren; seit die Übergänge aus echten
## Terrain-Kacheln bestehen, genügt ein schwacher Anteil — zu viel davon
## zerlegt Wald und Wiese in Einzelkacheln, die als Flecken erscheinen.
func _blur_regions() -> void:
	const FAMILY := [Tile.GRASS, Tile.MEADOW, Tile.FOREST]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var copy := tiles.duplicate()
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			var t := copy[idx(x, y)]
			if not FAMILY.has(t):
				continue
			var others: Array[int] = []
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not in_bounds(x + o.x, y + o.y):
					continue
				var n: int = copy[idx(x + o.x, y + o.y)]
				if n != t and FAMILY.has(n):
					others.append(n)
			if not others.is_empty() and rng.randf() < 0.16:
				set_tile(x, y, others[rng.randi() % others.size()])

## Bucht im Südwesten: liefert einen „Abstandswert" wie die Inselmetrik.
func _bay_distance(x: int, y: int, shape: FastNoiseLite) -> float:
	var bx := (x + 0.5 - 21.0) / 15.0
	var by := (y + 0.5 - 57.0) / 11.0
	var d := sqrt(bx * bx + by * by) + shape.get_noise_2d(x * 1.3, y * 1.3) * 0.16
	# Innerhalb der Bucht ist der Wert groß (=Wasser), außerhalb klein.
	return 2.0 - d

func _land_region(x: int, y: int, region: FastNoiseLite) -> int:
	var n := region.get_noise_2d(x, y)
	# Wald: Nordwesten
	var forest := (40.0 - x) / 40.0 + (34.0 - y) / 34.0 + n * 1.1
	if forest > 0.55:
		return Tile.FOREST
	# Fels: Osten / Südosten
	var rock := (x - 64.0) / 26.0 + (y - 30.0) / 40.0 + n * 1.0
	if rock > 0.95:
		return Tile.ROCK
	# Wiese: Nordosten
	var meadow := (x - 54.0) / 34.0 + (28.0 - y) / 26.0 + n * 1.0
	if meadow > 0.75:
		return Tile.MEADOW
	return Tile.GRASS

## Wege werden achsparallel gebaut: zwischen zwei Wegpunkten erst entlang der
## längeren Achse, dann entlang der kürzeren. Das ergibt gerade Strecken,
## rechtwinklige Ecken und echte Kreuzungen, wo sich zwei Wege treffen.
func _carve_roads() -> void:
	for road: Dictionary in Layout.ROADS:
		var points: Array = road["points"]
		var w: int = road["width"]
		for i in points.size() - 1:
			_carve_leg(points[i], points[i + 1], w)

func _carve_leg(a: Vector2i, b: Vector2i, w: int) -> void:
	var corner := Vector2i(b.x, a.y) if absi(b.x - a.x) >= absi(b.y - a.y) else Vector2i(a.x, b.y)
	_carve_straight(a, corner, w)
	_carve_straight(corner, b, w)

func _carve_straight(a: Vector2i, b: Vector2i, w: int) -> void:
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	var off := w / 2
	for s in steps + 1:
		var c := a + step * s
		for dy in w:
			for dx in w:
				_path_tile(c.x - off + dx, c.y - off + dy)

func _path_tile(x: int, y: int) -> void:
	if not in_bounds(x, y) or is_water(x, y) or get_tile(x, y) == Tile.SAND:
		return
	set_tile(x, y, Tile.PATH)

func _carve_plaza() -> void:
	var r := Layout.PLAZA
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			# abgerundete Ecken -> wirkt handgemacht statt wie ein Rechteck
			var ex := absf(x - (r.position.x + r.size.x * 0.5 - 0.5)) / (r.size.x * 0.5)
			var ey := absf(y - (r.position.y + r.size.y * 0.5 - 0.5)) / (r.size.y * 0.5)
			if ex * ex + ey * ey <= 1.0 and not is_water(x, y):
				set_tile(x, y, Tile.COBBLE)

## Sucht ausgehend von `start` die nächste freie, begehbare Kachel.
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
