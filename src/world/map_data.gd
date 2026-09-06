class_name MapData
extends RefCounted
## Die Karte als Daten: Bodentyp je Kachel + Begehbarkeit. Kein Rendering hier.

enum Tile { GRASS, MEADOW, FOREST, PATH, SAND, ROCK, WATER, DEEP_WATER, COBBLE, COUNT }

const W := Config.MAP_W
const H := Config.MAP_H

var tiles := PackedByteArray()
var solid := PackedByteArray()

func _init() -> void:
	tiles.resize(W * H)
	solid.resize(W * H)

func idx(x: int, y: int) -> int:
	return y * W + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H

func get_tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Tile.DEEP_WATER
	return tiles[idx(x, y)]

func set_tile(x: int, y: int, t: int) -> void:
	if in_bounds(x, y):
		tiles[idx(x, y)] = t

func is_water(x: int, y: int) -> bool:
	var t := get_tile(x, y)
	return t == Tile.WATER or t == Tile.DEEP_WATER

func is_solid(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	return solid[idx(x, y)] != 0

func block(x: int, y: int) -> void:
	if in_bounds(x, y):
		solid[idx(x, y)] = 1

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
	for y in H:
		for x in W:
			set_tile(x, y, Tile.GRASS)
	var saved := load_user()
	if not saved.is_empty():
		tiles = saved
	rebuild_solid()

## Begehbarkeit neu aus den Bodentypen ableiten: Wasser blockiert, der
## Kartenrand immer. Wird nach dem Laden gebraucht, weil dort nur die
## Bodentypen gespeichert sind.
func rebuild_solid() -> void:
	for y in H:
		for x in W:
			var edge := x == 0 or y == 0 or x == W - 1 or y == H - 1
			solid[idx(x, y)] = 1 if (edge or is_water(x, y)) else 0

# --- Gebaute Karte sichern ---------------------------------------------------

const SAVE_PATH := "user://karte.dat"
const SAVE_MAGIC := 0x484C4154   ## "TALH"
const SAVE_VERSION := 1

## Schreibt die gebaute Karte. Gespeichert werden nur die Bodentypen — die
## Begehbarkeit lässt sich daraus jederzeit wieder ableiten.
func save_user() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Karte konnte nicht gespeichert werden: %s" % SAVE_PATH)
		return false
	f.store_32(SAVE_MAGIC)
	f.store_32(SAVE_VERSION)
	f.store_32(W)
	f.store_32(H)
	f.store_buffer(tiles)
	f.close()
	return true

## Liest die gespeicherte Karte. Passt Version oder Größe nicht, kommt ein
## leeres Ergebnis zurück und die Datei wird schlicht ignoriert — ein
## geänderter Kartenschnitt darf das Spiel nicht zum Absturz bringen.
static func load_user() -> PackedByteArray:
	if not FileAccess.file_exists(SAVE_PATH):
		return PackedByteArray()
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	if f.get_length() < 16:
		return PackedByteArray()
	var magic := f.get_32()
	var version := f.get_32()
	var w := f.get_32()
	var h := f.get_32()
	if magic != SAVE_MAGIC or version != SAVE_VERSION or w != W or h != H:
		print("Gespeicherte Karte passt nicht (%d × %d, Fassung %d) — sie wird übergangen." % [w, h, version])
		return PackedByteArray()
	var data := f.get_buffer(W * H)
	f.close()
	if data.size() != W * H:
		return PackedByteArray()
	# Unbekannte Bodentypen abfangen, falls die Aufzählung später wächst.
	for i in data.size():
		if data[i] >= Tile.COUNT:
			data[i] = Tile.GRASS
	return data

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

	var cx := W * 0.5
	var cy := H * 0.5
	var rx := W * 0.47
	var ry := H * 0.46

	for y in H:
		for x in W:
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
	_mark_solid()

## Franst die Grenzen zwischen Gras, Wiese und Wald leicht aus. Früher musste
## das die harten Kachelkanten kaschieren; seit die Übergänge aus echten
## Terrain-Kacheln bestehen, genügt ein schwacher Anteil — zu viel davon
## zerlegt Wald und Wiese in Einzelkacheln, die als Flecken erscheinen.
func _blur_regions() -> void:
	const FAMILY := [Tile.GRASS, Tile.MEADOW, Tile.FOREST]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var copy := tiles.duplicate()
	for y in H:
		for x in W:
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

func _mark_solid() -> void:
	for y in H:
		for x in W:
			if is_water(x, y):
				block(x, y)

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
