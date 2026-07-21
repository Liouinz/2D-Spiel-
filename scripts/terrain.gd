class_name Terrain
extends TileMapLayer

## Tile-Terrain mit 7 Typen. Das TileSet wird zur Laufzeit prozedural gezeichnet
## (Basisfarbe + Rauschen + Dekor wie Bäume, Gischt, Risse) — Platzhalter-Art,
## die laut Masterplan erst in Phase 1 durch echte Pixel-Art ersetzt wird.

enum { T_WATER_DEEP, T_WATER_SHALLOW, T_SAND, T_GRASS, T_FOREST, T_ROCK, T_LAVA }

const TILE := 16
const W := 192
const H := 112
const VARIANTS := 4
const TYPE_COUNT := 7

const BASE_COLORS := {
	T_WATER_DEEP: Color(0.14, 0.33, 0.57),
	T_WATER_SHALLOW: Color(0.26, 0.49, 0.73),
	T_SAND: Color(0.87, 0.77, 0.52),
	T_GRASS: Color(0.38, 0.63, 0.26),
	T_FOREST: Color(0.23, 0.44, 0.19),
	T_ROCK: Color(0.49, 0.49, 0.51),
	T_LAVA: Color(0.80, 0.28, 0.08),
}
const CANOPY := Color(0.17, 0.38, 0.16)
const TRUNK := Color(0.35, 0.24, 0.14)

var _types := PackedByteArray()


func _init() -> void:
	_types.resize(W * H)
	tile_set = _build_tile_set()


func _ready() -> void:
	generate_island()


static func is_water(type: int) -> bool:
	return type == T_WATER_DEEP or type == T_WATER_SHALLOW


static func is_walkable(type: int) -> bool:
	return type == T_SAND or type == T_GRASS or type == T_FOREST or type == T_ROCK


func world_size() -> Vector2:
	return Vector2(W, H) * TILE


func world_center() -> Vector2:
	return world_size() * 0.5


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < W and cell.y >= 0 and cell.y < H


func get_type(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return T_WATER_DEEP
	return _types[cell.y * W + cell.x]


func set_type(cell: Vector2i, type: int) -> void:
	if not in_bounds(cell):
		return
	_types[cell.y * W + cell.x] = type
	set_cell(cell, 0, Vector2i(type, randi() % VARIANTS))


func random_cell() -> Vector2i:
	return Vector2i(randi() % W, randi() % H)


func paint_circle(center: Vector2i, radius: int, type: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var cell := center + Vector2i(dx, dy)
				if in_bounds(cell) and get_type(cell) != type:
					set_type(cell, type)
	update_shorelines(center, radius + 2)


## Blitz/Meteor: verbrennt Bewuchs zu Sand, Wasser bleibt unberührt.
func burn_circle(center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var cell := center + Vector2i(dx, dy)
				var t := get_type(cell)
				if in_bounds(cell) and (t == T_GRASS or t == T_FOREST):
					set_type(cell, T_SAND)


## Wasser wird automatisch in Flachwasser (Küste) und Tiefwasser unterteilt.
func update_shorelines(center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := center + Vector2i(dx, dy)
			if not in_bounds(cell):
				continue
			var t := get_type(cell)
			if not is_water(t):
				continue
			var wanted := T_WATER_DEEP
			for ny in range(-1, 2):
				for nx in range(-1, 2):
					if nx == 0 and ny == 0:
						continue
					if not is_water(get_type(cell + Vector2i(nx, ny))):
						wanted = T_WATER_SHALLOW
			if wanted != t:
				set_type(cell, wanted)


## Start-Insel: Höhen-Noise mit radialem Abfall, Vegetations-Noise für Wälder,
## Gebirge auf den höchsten Lagen.
func generate_island(seed_value: int = 0) -> void:
	var height_noise := FastNoiseLite.new()
	height_noise.seed = seed_value if seed_value != 0 else randi()
	height_noise.frequency = 0.025
	var veg_noise := FastNoiseLite.new()
	veg_noise.seed = height_noise.seed + 1337
	veg_noise.frequency = 0.06
	for y in H:
		for x in W:
			var n := height_noise.get_noise_2d(x, y) * 0.5 + 0.5
			var dist := Vector2(x - W * 0.5, y - H * 0.5).length() / (minf(W, H) * 0.62)
			var elevation := n - dist * dist * 0.85
			var type := T_GRASS
			if elevation < 0.26:
				type = T_WATER_DEEP
			elif elevation < 0.33:
				type = T_SAND
			elif elevation > 0.68:
				type = T_ROCK
			elif veg_noise.get_noise_2d(x, y) > 0.22:
				type = T_FOREST
			set_type(Vector2i(x, y), type)
	update_shorelines(Vector2i(W / 2, H / 2), maxi(W, H))


func _build_tile_set() -> TileSet:
	var img := Image.create(TYPE_COUNT * TILE, VARIANTS * TILE, false, Image.FORMAT_RGBA8)
	for type in TYPE_COUNT:
		for variant in VARIANTS:
			_paint_tile_art(img, type, variant)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TILE, TILE)
	for type in TYPE_COUNT:
		for variant in VARIANTS:
			src.create_tile(Vector2i(type, variant))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	return ts


func _paint_tile_art(img: Image, type: int, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = type * 131 + variant * 17 + 7
	var base: Color = BASE_COLORS[type]
	var ox := type * TILE
	var oy := variant * TILE
	for py in TILE:
		for px in TILE:
			var n := rng.randf_range(-0.035, 0.035)
			img.set_pixel(ox + px, oy + py, _shade(base, n))
	match type:
		T_GRASS:
			for i in 6:
				var p := Vector2i(rng.randi_range(1, 14), rng.randi_range(1, 14))
				img.set_pixel(ox + p.x, oy + p.y, _shade(base, -0.10))
				img.set_pixel(ox + p.x, oy + p.y - 1, _shade(base, -0.06))
		T_SAND:
			for i in 5:
				img.set_pixel(ox + rng.randi_range(0, 15), oy + rng.randi_range(0, 15), _shade(base, -0.08))
		T_WATER_DEEP:
			for i in 3:
				var p := Vector2i(rng.randi_range(1, 13), rng.randi_range(1, 14))
				img.set_pixel(ox + p.x, oy + p.y, _shade(base, 0.06))
				img.set_pixel(ox + p.x + 1, oy + p.y, _shade(base, 0.05))
		T_WATER_SHALLOW:
			for i in 4:
				var p := Vector2i(rng.randi_range(0, 14), rng.randi_range(0, 15))
				img.set_pixel(ox + p.x, oy + p.y, _shade(base, 0.14))
				img.set_pixel(ox + p.x + 1, oy + p.y, _shade(base, 0.10))
		T_FOREST:
			var cx := 8 + rng.randi_range(-1, 1)
			var cy := 7 + rng.randi_range(-1, 1)
			for py in TILE:
				for px in TILE:
					if Vector2(px - cx, py - cy).length() < 5.2:
						img.set_pixel(ox + px, oy + py, _shade(CANOPY, rng.randf_range(-0.05, 0.05)))
			for ty in range(cy + 4, mini(cy + 7, 15)):
				img.set_pixel(ox + cx, oy + ty, TRUNK)
				img.set_pixel(ox + cx + 1, oy + ty, _shade(TRUNK, -0.04))
		T_ROCK:
			for i in 5:
				var p := Vector2i(rng.randi_range(1, 14), rng.randi_range(1, 14))
				img.set_pixel(ox + p.x, oy + p.y, _shade(base, -0.14))
				img.set_pixel(ox + p.x + 1, oy + p.y + 1, _shade(base, -0.10))
			for i in 3:
				img.set_pixel(ox + rng.randi_range(0, 15), oy + rng.randi_range(0, 15), _shade(base, 0.10))
		T_LAVA:
			for i in 5:
				var p := Vector2i(rng.randi_range(1, 13), rng.randi_range(0, 15))
				img.set_pixel(ox + p.x, oy + p.y, Color(1.0, 0.72, 0.24))
				img.set_pixel(ox + p.x + 1, oy + p.y, Color(1.0, 0.55, 0.15))


func _shade(base: Color, amount: float) -> Color:
	return Color(
		clampf(base.r + amount, 0.0, 1.0),
		clampf(base.g + amount, 0.0, 1.0),
		clampf(base.b + amount, 0.0, 1.0)
	)
