class_name GroundTileSet
extends RefCounted
## Baut das TileSet für den Boden und bemalt die TileMapLayer.
##
## Aufbau: eine Grundfüllung (Tiefwasser) und darüber gestapelte Schichten, die
## sich per Terrain-Autotiling in die jeweils darunterliegende einblenden.
## Dadurch entstehen echte Übergangskacheln mit runden Ecken statt harter
## Kachelkanten — Wasser→Sand→Gras→Wiese/Wald→Fels→Weg→Pflaster.
##
## Die Terrains sind im TileSet benannt und mit Eck-Bits versehen, das Raster
## lässt sich also im Godot-Editor auch von Hand mit dem Terrain-Pinsel malen.

## Zeichenreihenfolge von unten nach oben. Index 0 ist die Grundfüllung.
##
## Gras füllt die ganze Karte, alles andere liegt als Auflage darüber. So muss
## nur die tatsächlich sichtbare Fläche gesetzt werden statt jede Schicht über
## die ganze Insel zu ziehen.
const STACK := [
	MapData.Tile.GRASS,
	MapData.Tile.MEADOW,
	MapData.Tile.FOREST,
	MapData.Tile.ROCK,
	MapData.Tile.SAND,
	MapData.Tile.WATER,
	MapData.Tile.DEEP_WATER,
	MapData.Tile.PATH,
	MapData.Tile.COBBLE,
]

const NAMES := {
	MapData.Tile.DEEP_WATER: "Tiefwasser",
	MapData.Tile.WATER: "Wasser",
	MapData.Tile.SAND: "Sand",
	MapData.Tile.GRASS: "Gras",
	MapData.Tile.MEADOW: "Wiese",
	MapData.Tile.FOREST: "Waldboden",
	MapData.Tile.ROCK: "Fels",
	MapData.Tile.PATH: "Weg",
	MapData.Tile.COBBLE: "Pflaster",
}

## Gebaute Flächen bekommen eckige Übergänge statt runder.
const HARD := [MapData.Tile.PATH, MapData.Tile.COBBLE]

## Reihenfolge muss zur Bitfolge in TerrainAtlas passen.
const CORNERS := [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
]

## Wie viele fertig bestückte Dekorationskacheln je Sorte erzeugt werden.
## Bei 32 Pixeln je Kachel und zufälligen Positionen darin fällt die
## Wiederholung nicht auf.
const DECOR_VARIANTS := 12

var tileset: TileSet
var decor_source: int = -1
var decor_slots: Array[Vector2i] = []   ## flache Liste aller Dekorationskacheln
var decor_ranges: Dictionary = {}       ## sorte -> Vector2i(start, anzahl)
var _sources: Array[int] = []          ## Quellen-ID je Stapelposition
var _slots: Array = []                 ## Array[Vector2i] je Stapelposition
var _full_count: int = 0               ## Vollkacheln je Bodentyp

static func build(art: TileArt, seed_value: int) -> GroundTileSet:
	var g := GroundTileSet.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1234

	var ts := TileSet.new()
	ts.tile_size = Vector2i(Config.TILE, Config.TILE)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for i in STACK.size() - 1:
		ts.add_terrain(0)
		ts.set_terrain_name(0, i, NAMES[STACK[i + 1]])

	for pos in STACK.size():
		var tile_type: int = STACK[pos]
		var atlas := TerrainAtlas.build(art.base[tile_type], rng, HARD.has(tile_type))
		var slots: Array[Vector2i] = atlas["slots"]
		g._full_count = slots.size() - TerrainAtlas.FULL_START

		var src := TileSetAtlasSource.new()
		src.texture = atlas["texture"]
		src.texture_region_size = Vector2i(Config.TILE, Config.TILE)
		for coords: Vector2i in slots:
			src.create_tile(coords)
		var sid := ts.add_source(src)

		# Die Grundfüllung braucht kein Terrain, sie wird flächig gesetzt.
		if pos > 0:
			var terrain := pos - 1
			for i in slots.size():
				var td := src.get_tile_data(slots[i], 0)
				td.terrain_set = 0
				td.terrain = terrain
				var mask := i if i < TerrainAtlas.PARTIAL else 15
				for c in 4:
					if mask & (1 << c):
						td.set_terrain_peering_bit(CORNERS[c], terrain)

		g._sources.append(sid)
		g._slots.append(slots)

	g._build_decor(ts, art, rng)
	g.tileset = ts
	return g

## Baut aus den Streuobjekten fertige, durchsichtige Dekorationskacheln. Sie
## kommen in eine eigene TileMapLayer über dem Boden — dadurch entfällt die
## große gebackene Auflagetextur vollständig.
func _build_decor(ts: TileSet, art: TileArt, rng: RandomNumberGenerator) -> void:
	var sets := {
		"grass": art.decor_grass,
		"forest": art.decor_forest,
		"sand": art.decor_sand,
		"path": art.decor_path,
		"water": art.decor_water,
		"edge": art.decor_edge,
	}
	var tiles: Array[Image] = []
	for name: String in sets:
		var pool: Array[Image] = sets[name]
		decor_ranges[name] = Vector2i(tiles.size(), DECOR_VARIANTS)
		for v in DECOR_VARIANTS:
			var img := Pixel.make(Config.TILE, Config.TILE)
			if not pool.is_empty():
				for i in rng.randi_range(1, 3):
					var dec: Image = pool[rng.randi() % pool.size()]
					var dx := rng.randi_range(0, maxi(Config.TILE - dec.get_width(), 0))
					var dy := rng.randi_range(0, maxi(Config.TILE - dec.get_height(), 0))
					img.blend_rect(dec, Rect2i(Vector2i.ZERO, dec.get_size()), Vector2i(dx, dy))
			tiles.append(img)

	var cols := 8
	var rows := int(ceil(float(tiles.size()) / cols))
	var atlas := Pixel.make(cols * Config.TILE, rows * Config.TILE)
	var src := TileSetAtlasSource.new()
	for i in tiles.size():
		var pos := Vector2i(i % cols, i / cols)
		atlas.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()), pos * Config.TILE)
		decor_slots.append(pos)
	src.texture = Pixel.tex(atlas)
	src.texture_region_size = Vector2i(Config.TILE, Config.TILE)
	for pos: Vector2i in decor_slots:
		src.create_tile(pos)
	decor_source = ts.add_source(src)

## Setzt die Dekorationsschicht. `map` enthält je Kachel den flachen Index
## einer Dekorationskachel oder -1.
func paint_decor(layer: TileMapLayer, indices: PackedInt32Array) -> void:
	layer.tile_set = tileset
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			var i := indices[y * Config.MAP_W + x]
			if i >= 0:
				layer.set_cell(Vector2i(x, y), decor_source, decor_slots[i])

## Setzt eine Schicht.
##
## Die Kachelwahl folgt derselben Eckregel wie Godots Terrain-System: eine Ecke
## gilt als bedeckt, wenn alle vier an ihr liegenden Kacheln zur Schicht
## gehören. Diese Regel wurde gegen set_cells_terrain_connect() gemessen und
## stimmt Bit für Bit überein — nur ist die eigene Berechnung rund zehnmal so
## schnell, weil sie ohne Kachelsuche auskommt.
##
## Das TileSet deklariert die Terrains trotzdem mit Eck-Bits. Dadurch lässt
## sich dieselbe Karte im Godot-Editor von Hand mit dem Terrain-Pinsel
## weiterbearbeiten.
func paint(layer: TileMapLayer, pos: int, cells: Array[Vector2i], variants: PackedByteArray) -> void:
	layer.tile_set = tileset
	if cells.is_empty():
		return

	var sid: int = _sources[pos]
	var w := Config.MAP_W
	if pos == 0:
		for cell: Vector2i in cells:
			layer.set_cell(cell, sid, _full(pos, variants[cell.y * w + cell.x]))
		return

	var member := PackedByteArray()
	member.resize(w * Config.MAP_H)
	for cell: Vector2i in cells:
		member[cell.y * w + cell.x] = 1

	var slots: Array[Vector2i] = _slots[pos]
	for cell: Vector2i in cells:
		var mask := _corner_mask(member, cell.x, cell.y)
		if mask == 15:
			layer.set_cell(cell, sid, _full(pos, variants[cell.y * w + cell.x]))
		else:
			layer.set_cell(cell, sid, slots[mask])

## Eine Ecke ist bedeckt, wenn alle vier dort zusammenstoßenden Kacheln zur
## Schicht gehören. Am Kartenrand wird der Wert des Randfeldes fortgesetzt,
## sonst würde die Schicht dort ausfransen.
static func _corner_mask(member: PackedByteArray, x: int, y: int) -> int:
	var mask := 0
	if _at(member, x - 1, y - 1) and _at(member, x, y - 1) and _at(member, x - 1, y):
		mask |= 1                                   # oben links
	if _at(member, x, y - 1) and _at(member, x + 1, y - 1) and _at(member, x + 1, y):
		mask |= 2                                   # oben rechts
	if _at(member, x + 1, y) and _at(member, x, y + 1) and _at(member, x + 1, y + 1):
		mask |= 4                                   # unten rechts
	if _at(member, x - 1, y) and _at(member, x - 1, y + 1) and _at(member, x, y + 1):
		mask |= 8                                   # unten links
	return mask

static func _at(member: PackedByteArray, x: int, y: int) -> bool:
	var cx := clampi(x, 0, Config.MAP_W - 1)
	var cy := clampi(y, 0, Config.MAP_H - 1)
	return member[cy * Config.MAP_W + cx] != 0

func _full(pos: int, variant: int) -> Vector2i:
	var slots: Array[Vector2i] = _slots[pos]
	return slots[TerrainAtlas.FULL_START + posmod(variant, _full_count)]
