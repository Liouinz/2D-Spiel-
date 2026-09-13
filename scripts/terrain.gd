class_name Terrain
extends TileMapLayer

## Die Welt als Typ-Raster (`_types`) — das ist die *einzige* Quelle der
## Wahrheit. Grafik, Minimap und Simulation lesen alle dasselbe Array.
##
## Gezeichnet wird in vier Ebenen:
##   0 Boden   — deckend (Meeresgrund / Sand / Gras / Fels), mit Kantenlicht
##   1 Wasser  — transparente Auflage über dem Boden, animiert
##   2 Tiefe   — dunkler Wasserkern, ebenfalls Auflage
##   3 Aufsatz — Laubdach und Lava als transparente Auflage
##
## Weil Wasser und Wald *über* dem Boden liegen und ihre Silhouette aus den
## echten Nachbarn geschnitten wird, verlieren sie die Quadratform: Ufer werden
## rund, Waldränder ausgefranst — und eine Lücke bleibt garantiert eine Lücke.

enum { T_WATER_DEEP, T_WATER_SHALLOW, T_SAND, T_GRASS, T_FOREST, T_ROCK, T_LAVA }

const TILE := 16
const W := 192
const H := 112
const TYPE_COUNT := 7

const TYPE_NAMES := ["Tiefwasser", "Flachwasser", "Sand", "Gras", "Wald", "Fels", "Lava"]

## Farbe im Minimap-Bild — bewusst aus derselben Palette wie die Tiles.
const MINIMAP_COLORS := [
	Color(0.11, 0.25, 0.44),
	Color(0.21, 0.42, 0.63),
	Color(0.81, 0.72, 0.50),
	Color(0.34, 0.57, 0.25),
	Color(0.19, 0.38, 0.17),
	Color(0.45, 0.46, 0.49),
	Color(0.94, 0.42, 0.10),
]

## Ebene 0: welche deckende Bodenart liegt unter einem Typ?
const GROUND_KIND := [
	TileArt.K_SEABED,
	TileArt.K_SAND,
	TileArt.K_SAND,
	TileArt.K_GRASS,
	TileArt.K_GRASS,
	TileArt.K_ROCK,
	TileArt.K_ROCK,
]

## Gruppen-Bits je Tile-Typ. Index 7 steht für "ausserhalb der Karte":
## dort setzt sich Wasser fort, Land nicht — sonst bekäme die Insel einen
## unmotivierten Rahmen aus Kantenlicht.
const B_SEABED := 1
const B_SAND := 2
const B_GRASS := 4
const B_ROCK := 8
const B_WATER := 16
const B_DEEP := 32
const B_FOREST := 64
const B_LAVA := 128
const OUTSIDE := 7

const GROUP_BITS := [
	B_SEABED | B_WATER | B_DEEP,   # Tiefwasser
	B_SAND | B_WATER,              # Flachwasser
	B_SAND,                        # Sand
	B_GRASS,                       # Gras
	B_GRASS | B_FOREST,            # Wald
	B_ROCK,                        # Fels
	B_ROCK | B_LAVA,               # Lava
	B_SEABED | B_WATER | B_DEEP,   # ausserhalb
]

## Bodenart → Gruppen-Bit, mit dem sich der Boden verbindet.
const GROUND_BIT := [B_SEABED, B_SAND, B_GRASS, B_ROCK]

var water_layer: TileMapLayer
var deep_layer: TileMapLayer
var decor_layer: TileMapLayer

var _types := PackedByteArray()
var _dirty := {}
var _batching := false
## Zählt jede abgeschlossene Änderung. Die Minimap baut ihr Bild nur neu auf,
## wenn sich die Welt seit dem letzten Mal wirklich verändert hat.
var version := 0


func _init() -> void:
	_types.resize(W * H)
	var ts := TileArt.build_tile_set()
	tile_set = ts
	z_index = 0
	water_layer = _make_layer(ts, 1)
	deep_layer = _make_layer(ts, 2)
	decor_layer = _make_layer(ts, 3)


func _ready() -> void:
	add_child(water_layer)
	add_child(deep_layer)
	add_child(decor_layer)
	generate_island()


func _make_layer(ts: TileSet, order: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	layer.z_index = order
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer


# --- Abfragen ---------------------------------------------------------------

static func is_water(type: int) -> bool:
	return type == T_WATER_DEEP or type == T_WATER_SHALLOW


static func is_walkable(type: int) -> bool:
	return type == T_SAND or type == T_GRASS or type == T_FOREST or type == T_ROCK


## Flachwasser darf durchwatet werden — daher die Wellen hinter den Siedlern.
static func is_wadeable(type: int) -> bool:
	return type == T_WATER_SHALLOW


static func type_name(type: int) -> String:
	return TYPE_NAMES[type] if type >= 0 and type < TYPE_NAMES.size() else "?"


func world_size() -> Vector2:
	return Vector2(W, H) * TILE


func world_center() -> Vector2:
	return world_size() * 0.5


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < W and cell.y >= 0 and cell.y < H


func get_type(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= W or cell.y < 0 or cell.y >= H:
		return T_WATER_DEEP
	return _types[cell.y * W + cell.x]


func random_cell() -> Vector2i:
	return Vector2i(randi() % W, randi() % H)


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


# --- Verändern --------------------------------------------------------------

## Einzelzelle setzen. Die Grafik der Zelle *und ihrer acht Nachbarn* wird
## neu bestimmt, denn deren Form hängt von dieser Zelle ab.
func set_type(cell: Vector2i, type: int) -> void:
	if not in_bounds(cell):
		return
	var index := cell.y * W + cell.x
	if _types[index] == type:
		return
	_types[index] = type
	_mark(cell)
	if not _batching:
		flush()


## Mehrere Änderungen sammeln und die Grafik erst am Ende einmal nachziehen —
## spart bei Pinselstrichen ein Vielfaches der Arbeit.
func begin_batch() -> void:
	_batching = true


func flush() -> void:
	_batching = false
	if _dirty.is_empty():
		return
	for cell in _dirty:
		_paint_cell(cell)
	_dirty.clear()
	version += 1


func _mark(cell: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var neighbour := cell + Vector2i(dx, dy)
			if in_bounds(neighbour):
				_dirty[neighbour] = true


func paint_circle(center: Vector2i, radius: int, type: int) -> int:
	begin_batch()
	var changed := 0
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var cell := center + Vector2i(dx, dy)
			if in_bounds(cell) and get_type(cell) != type:
				set_type(cell, type)
				changed += 1
	update_shorelines(center, radius + 2)
	flush()
	return changed


## Blitz/Meteor: verbrennt Bewuchs zu Sand, Wasser bleibt unberührt.
func burn_circle(center: Vector2i, radius: int) -> void:
	begin_batch()
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var cell := center + Vector2i(dx, dy)
			var t := get_type(cell)
			if in_bounds(cell) and (t == T_GRASS or t == T_FOREST):
				set_type(cell, T_SAND)
	flush()


## Wasser wird automatisch in Flachwasser (Küste) und Tiefwasser unterteilt.
func update_shorelines(center: Vector2i, radius: int) -> void:
	var was_batching := _batching
	begin_batch()
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
	if not was_batching:
		flush()


# --- Grafik -----------------------------------------------------------------

## Deterministische Variante: dieselbe Zelle sieht nach jedem Neusetzen
## gleich aus (vorher würfelte jeder Pinselstrich neu).
static func _variant(cell: Vector2i) -> int:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	return posmod(h, TileArt.VARIANTS)


## Baut aus acht bereits gelesenen Nachbar-Bitfeldern die Blob-Maske.
## Diagonalen zählen nur mit beiden Kardinalnachbarn — genau das verhindert,
## dass getrennte Strukturen optisch zusammenwachsen.
static func _mask_of(g: int, bn: int, be: int, bs: int, bw: int, bne: int, bse: int, bsw: int, bnw: int) -> int:
	var mask := 0
	var n := (bn & g) != 0
	var e := (be & g) != 0
	var s := (bs & g) != 0
	var w := (bw & g) != 0
	if n:
		mask |= TileShapes.N
	if e:
		mask |= TileShapes.E
	if s:
		mask |= TileShapes.S
	if w:
		mask |= TileShapes.W
	if n and e and (bne & g) != 0:
		mask |= TileShapes.NE
	if s and e and (bse & g) != 0:
		mask |= TileShapes.SE
	if s and w and (bsw & g) != 0:
		mask |= TileShapes.SW
	if n and w and (bnw & g) != 0:
		mask |= TileShapes.NW
	return mask


## Zeichnet eine Zelle auf allen vier Ebenen neu. Liest die neun beteiligten
## Typen genau einmal — die Form entsteht ausschliesslich aus echten Nachbarn.
func _paint_cell(cell: Vector2i, erase_empty: bool = true) -> void:
	var x := cell.x
	var y := cell.y
	var base := y * W + x
	var has_n := y > 0
	var has_s := y < H - 1
	var has_w := x > 0
	var has_e := x < W - 1
	var t: int = _types[base]
	var bn: int = GROUP_BITS[_types[base - W] if has_n else OUTSIDE]
	var bs: int = GROUP_BITS[_types[base + W] if has_s else OUTSIDE]
	var bw: int = GROUP_BITS[_types[base - 1] if has_w else OUTSIDE]
	var be: int = GROUP_BITS[_types[base + 1] if has_e else OUTSIDE]
	var bnw: int = GROUP_BITS[_types[base - W - 1] if has_n and has_w else OUTSIDE]
	var bne: int = GROUP_BITS[_types[base - W + 1] if has_n and has_e else OUTSIDE]
	var bsw: int = GROUP_BITS[_types[base + W - 1] if has_s and has_w else OUTSIDE]
	var bse: int = GROUP_BITS[_types[base + W + 1] if has_s and has_e else OUTSIDE]
	var variant := _variant(cell)

	var ground: int = GROUND_KIND[t]
	var ground_bit: int = GROUND_BIT[ground]
	set_cell(cell, 0, TileArt.atlas_coords(ground, TileShapes.config_index(
		_mask_of(ground_bit, bn, be, bs, bw, bne, bse, bsw, bnw)), variant))

	if t == T_WATER_DEEP or t == T_WATER_SHALLOW:
		water_layer.set_cell(cell, 0, TileArt.atlas_coords(TileArt.K_WATER, TileShapes.config_index(
			_mask_of(B_WATER, bn, be, bs, bw, bne, bse, bsw, bnw)), variant))
	elif erase_empty:
		water_layer.erase_cell(cell)

	if t == T_WATER_DEEP:
		deep_layer.set_cell(cell, 0, TileArt.atlas_coords(TileArt.K_WATER_DEEP, TileShapes.config_index(
			_mask_of(B_DEEP, bn, be, bs, bw, bne, bse, bsw, bnw)), variant))
	elif erase_empty:
		deep_layer.erase_cell(cell)

	if t == T_FOREST:
		decor_layer.set_cell(cell, 0, TileArt.atlas_coords(TileArt.K_CANOPY, TileShapes.config_index(
			_mask_of(B_FOREST, bn, be, bs, bw, bne, bse, bsw, bnw)), variant))
	elif t == T_LAVA:
		decor_layer.set_cell(cell, 0, TileArt.atlas_coords(TileArt.K_LAVA, TileShapes.config_index(
			_mask_of(B_LAVA, bn, be, bs, bw, bne, bse, bsw, bnw)), variant))
	elif erase_empty:
		decor_layer.erase_cell(cell)


## Kompletter Neuaufbau (nur bei Weltgenerierung).
func rebuild_all() -> void:
	clear()
	water_layer.clear()
	deep_layer.clear()
	decor_layer.clear()
	_dirty.clear()
	for y in H:
		for x in W:
			_paint_cell(Vector2i(x, y), false)
	version += 1


# --- Weltgenerierung --------------------------------------------------------

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
			_types[y * W + x] = type
	_classify_all_water()
	rebuild_all()


## Küstenlinien für die gesamte Karte in einem Durchgang.
func _classify_all_water() -> void:
	var updates := PackedInt32Array()
	for y in H:
		for x in W:
			var index := y * W + x
			var t: int = _types[index]
			if not is_water(t):
				continue
			var wanted := T_WATER_DEEP
			for ny in range(-1, 2):
				for nx in range(-1, 2):
					if nx == 0 and ny == 0:
						continue
					if not is_water(get_type(Vector2i(x + nx, y + ny))):
						wanted = T_WATER_SHALLOW
			if wanted != t:
				updates.append(index)
				updates.append(wanted)
	for i in range(0, updates.size(), 2):
		_types[updates[i]] = updates[i + 1]


# --- Statistik fürs Entwickler-Overlay --------------------------------------

## Rohdaten für die Minimap — dieselbe Quelle wie die Weltdarstellung.
func types_buffer() -> PackedByteArray:
	return _types
