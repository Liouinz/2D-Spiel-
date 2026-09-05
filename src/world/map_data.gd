class_name MapData
extends RefCounted
## Die Karte als Daten: Bodentyp je Kachel + Begehbarkeit. Kein Rendering hier.

enum Tile { GRASS, MEADOW, FOREST, PATH, SAND, ROCK, WATER, DEEP_WATER, COUNT }

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

## Baut die komplette Karte auf: Insel, Regionen, Bucht, Wege, Dorfplatz.
func generate(seed_value: int) -> void:
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

	_carve_roads()
	_carve_plaza()
	_mark_solid()

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

func _carve_roads() -> void:
	for chain: Array in Layout.ROADS:
		for i in chain.size() - 1:
			_road_segment(chain[i], chain[i + 1])

func _road_segment(a: Vector2i, b: Vector2i) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	for s in steps + 1:
		var t := float(s) / float(maxi(steps, 1))
		var p := Vector2(a).lerp(Vector2(b), t)
		var px := int(round(p.x))
		var py := int(round(p.y))
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				# leicht unregelmäßige Wegbreite
				if absi(ox) + absi(oy) > 1 and (px + py) % 3 == 0:
					continue
				if not is_water(px + ox, py + oy) and get_tile(px + ox, py + oy) != Tile.SAND:
					set_tile(px + ox, py + oy, Tile.PATH)

func _carve_plaza() -> void:
	var r := Layout.PLAZA
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			# abgerundete Ecken -> wirkt handgemacht statt wie ein Rechteck
			var ex := absf(x - (r.position.x + r.size.x * 0.5 - 0.5)) / (r.size.x * 0.5)
			var ey := absf(y - (r.position.y + r.size.y * 0.5 - 0.5)) / (r.size.y * 0.5)
			if ex * ex + ey * ey <= 1.05 and not is_water(x, y):
				set_tile(x, y, Tile.PATH)

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
