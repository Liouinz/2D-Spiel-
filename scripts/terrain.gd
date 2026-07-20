class_name Terrain
extends TileMapLayer

## Tile-basiertes Terrain mit drei Typen (Gras/Wasser/Sand).
## Das TileSet wird zur Laufzeit aus Farben generiert — keine Binär-Assets nötig,
## Platzhalter-Grafik wird laut Masterplan erst in Phase 1 durch Pixel-Art ersetzt.

enum { T_GRASS, T_WATER, T_SAND }

const TILE := 16
const W := 160
const H := 100
const VARIANTS := 4
const TYPE_COUNT := 3

var _types := PackedByteArray()


func _init() -> void:
	_types.resize(W * H)
	tile_set = _build_tile_set()


func _ready() -> void:
	generate_island()


func world_center() -> Vector2:
	return Vector2(W, H) * TILE * 0.5


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < W and cell.y >= 0 and cell.y < H


func get_type(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return T_WATER
	return _types[cell.y * W + cell.x]


func set_type(cell: Vector2i, type: int) -> void:
	if not in_bounds(cell):
		return
	_types[cell.y * W + cell.x] = type
	set_cell(cell, 0, Vector2i(type, randi() % VARIANTS))


func paint_circle(center: Vector2i, radius: int, type: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var cell := center + Vector2i(dx, dy)
				if in_bounds(cell) and get_type(cell) != type:
					set_type(cell, type)


## Blitzeinschlag: verbrennt nur Land zu Sand, Wasser bleibt Wasser.
func burn_circle(center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var cell := center + Vector2i(dx, dy)
				if in_bounds(cell) and get_type(cell) == T_GRASS:
					set_type(cell, T_SAND)


## Erzeugt eine Start-Insel per Noise, damit Tag 1 nicht mit leerer Fläche beginnt.
func generate_island(seed_value: int = 0) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value if seed_value != 0 else randi()
	noise.frequency = 0.04
	for y in H:
		for x in W:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var dist := Vector2(x - W * 0.5, y - H * 0.5).length() / (minf(W, H) * 0.55)
			var elevation := n - dist * dist * 0.8
			var type := T_GRASS
			if elevation < 0.28:
				type = T_WATER
			elif elevation < 0.36:
				type = T_SAND
			set_type(Vector2i(x, y), type)


func _build_tile_set() -> TileSet:
	var base_colors := {
		T_GRASS: Color8(106, 168, 79),
		T_WATER: Color8(52, 106, 168),
		T_SAND: Color8(222, 196, 132),
	}
	var img := Image.create(TYPE_COUNT * TILE, VARIANTS * TILE, false, Image.FORMAT_RGBA8)
	for type in TYPE_COUNT:
		for variant in VARIANTS:
			_fill_tile(img, type, variant, base_colors[type])
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


func _fill_tile(img: Image, type: int, variant: int, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = type * 131 + variant * 17 + 1
	for py in TILE:
		for px in TILE:
			var n := rng.randf_range(-0.04, 0.04)
			var c := Color(
				clampf(color.r + n, 0.0, 1.0),
				clampf(color.g + n, 0.0, 1.0),
				clampf(color.b + n, 0.0, 1.0)
			)
			img.set_pixel(type * TILE + px, variant * TILE + py, c)
