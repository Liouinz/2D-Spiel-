class_name GroundTileSet
extends RefCounted
## Baut das TileSet für den Boden und bemalt die TileMapLayer.
##
## Drei Schichten, von unten nach oben: Gras füllt die ganze Karte, darüber
## liegen Sand und Wasser als Auflage. Sand liegt auch unter dem Wasser, damit
## die Brandung auf Sand trifft statt auf Gras.

## Zeichenreihenfolge von unten nach oben. Index 0 ist die Grundfüllung.
const STACK := [
	MapData.Tile.GRASS,
	MapData.Tile.SAND,
	MapData.Tile.WATER,
]

const NAMES := MapData.NAMES

## Gebaute Flächen bekämen eckige Übergänge — davon gibt es zurzeit keine.
const HARD := []

## Wasser verläuft nicht, es belegt genau seine Felder.
##
## Das Eck-Autotiling legt die Geländegrenze auf das Eckraster — eine halbe
## Kachel versetzt zum Blockraster. Für Sand ist das richtig, der soll weich in
## Gras übergehen. Für die Uferlinie nicht: Uferband und Brandung sitzen am
## Block, der weiche Auslauf aber darüber hinaus, und die Brandung landete auf
## dem Sand statt im Wasser.
const SHARP := [MapData.Tile.WATER]

## Gehört ein Bodentyp zu einer Schicht des Stapels?
##
## Diese Regel ist die einzige Wahrheit darüber, welche Schicht wo liegt.
static func in_layer(pos: int, t: int) -> bool:
	match pos:
		0:
			return true                                  # Gras füllt alles
		1:
			# Sand liegt auch unter dem Wasser: so trifft die Brandung auf Sand.
			return t == MapData.Tile.SAND or t == MapData.Tile.WATER
		_:
			return t == MapData.Tile.WATER

## Reihenfolge muss zur Bitfolge in TerrainAtlas passen.
const CORNERS := [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
]

var tileset: TileSet
var _sources: Array[int] = []          ## Quellen-ID je Stapelposition
var _slots: Array = []                 ## Array[Vector2i] je Stapelposition
var _full_count: int = 0               ## Vollkacheln je Bodentyp
var _table := PackedByteArray()
var _shade: FastNoiseLite               ## grossflaechige Bodenhelligkeit
var edges: EdgeArt                      ## Uferkanten

## Streu-Dekoration: Quelle im Kachelsatz und die Plätze je Bodentyp.
var decor_source: int = -1
var decor_slots: Array = []
var decor_grass: Array = []
var decor_sand: Array = []
var _sharp: Array[bool] = []            ## Schichten ohne weichen Übergang

## Hinter den drei Bodenschichten liegt die Kantenschicht (Uferband und
## Tiefenband). Die Reihenfolge muss zu ChunkStreamer.setup() passen.
const LAYER_EDGE := 3

## Ganz oben die Streu-Dekoration: Büschel, Blumen, Kiesel. Sie liegt über den
## Kanten, damit ein Grasbüschel am Ufer nicht vom Uferband durchschnitten wird.
const LAYER_DECOR := 4
const LAYER_COUNT := 5

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
				var mask := (i / TerrainAtlas.EDGE_VARIANTS) if i < TerrainAtlas.FULL_START else 15
				for c in 4:
					if mask & (1 << c):
						td.set_terrain_peering_bit(CORNERS[c], terrain)

		g._sources.append(sid)
		g._slots.append(slots)

	# Dekor als eigene Atlasquelle im selben Kachelsatz.
	var decor: Dictionary = DecorArt.build(seed_value)
	var decor_src := TileSetAtlasSource.new()
	decor_src.texture = decor["texture"]
	decor_src.texture_region_size = Vector2i(Config.TILE, Config.TILE)
	for coords: Vector2i in decor["slots"]:
		decor_src.create_tile(coords)
	g.decor_source = ts.add_source(decor_src)
	g.decor_slots = decor["slots"]
	g.decor_grass = decor["grass"]
	g.decor_sand = decor["sand"]

	g.edges = EdgeArt.build(ts)
	g._build_table()
	for pos in STACK.size():
		g._sharp.append(SHARP.has(STACK[pos]))
	g._shade = FastNoiseLite.new()
	g._shade.seed = seed_value + 809
	g._shade.frequency = 0.030
	g.tileset = ts
	return g

## Die Tabelle ist über den ganzen Bytebereich aufgespannt, nicht nur über die
## bekannten Bodentypen: dadurch darf `_paint_cell` direkt in `map.tiles`
## greifen, ohne dass ein beschädigter Wert aus einer Speicherdatei die
## Kachelsuche aus dem Ruder laufen lässt. Kostet 2304 statt 81 Bytes.
const TABLE_STRIDE := 256

func _build_table() -> void:
	_table.resize(STACK.size() * TABLE_STRIDE)
	for pos in STACK.size():
		for t in TABLE_STRIDE:
			var known := t < MapData.Tile.COUNT and in_layer(pos, t)
			# Unbekannte Werte verhalten sich wie Gras: die Grundfüllung greift,
			# alles darüber nicht.
			_table[pos * TABLE_STRIDE + t] = 1 if (known or pos == 0) else 0

## Helligkeitsstufe und Variante einer Kachel — frueher einmal ueber die ganze
## Karte vorberechnet, jetzt bei Bedarf. Dieselbe Formel, damit sich am
## Aussehen nichts aendert.
func variant_at(x: int, y: int) -> int:
	var n := _shade.get_noise_2d(x, y) * 0.5 + 0.5
	var shade := clampi(int(n * TileArt.SHADES), 0, TileArt.SHADES - 1)
	# Streuwert statt Takt. `(x * 7 + y * 13) % 6` war streng periodisch:
	# dieselbe Variante kehrte diagonal alle sechs Felder wieder, und das sah
	# man der Fläche als Muster an.
	return shade * TileArt.VARIANTS + Config.hash2(x, y) % TileArt.VARIANTS

## Malt einen Chunk auf alle neun Bodenschichten.
##
## Ein Feld, das zur Schicht gehört, bekommt IMMER eine Vollkachel. Der
## Übergang wird nicht aus ihm herausgeschnitten, sondern wächst in die
## Nachbarfelder hinein: dort wird eine Ecke gesetzt, wenn eines der drei an
## ihr liegenden Felder dazugehört.
##
## Godots eigene Eckregel („alle vier Felder müssen dazugehören") war hier
## falsch. Sie taugt zum Malen von Flächen, nicht zum Setzen einzelner Blöcke:
## bei einer ein Feld breiten Reihe ist keine Ecke je bedeckt, jede Kachel
## bekam Maske 0 — und Maske 0 ist ein Klecks in der Kachelmitte. Eine gesetzte
## Reihe zerfiel dadurch in einzelne Punkte.
##
## Gelesen wird direkt aus der Karte statt aus zwischengespeicherten Rastern:
## die 3 × 3-Nachbarschaft einmal je Kachel, danach neun Tabellenzugriffe je
## Schicht. Dadurch stimmen die Eckmasken auch an Chunk-Grenzen, ohne dass der
## Nachbarchunk geladen sein muss.
func paint_chunk(layers: Array[TileMapLayer], map: MapData, chunk: Vector2i) -> void:
	var cs := Config.CHUNK
	var count := STACK.size()
	for pos in count:
		layers[pos].tile_set = tileset
	for oy in cs:
		var y := chunk.y * cs + oy
		for ox in cs:
			var x := chunk.x * cs + ox
			# Ein frisch geladener Chunk ist auf allen Schichten leer — das
			# Löschen entfällt und spart rund 51 000 Aufrufe je Chunk.
			_paint_cell(layers, map, x, y, false)

## Löscht die Kacheln eines Chunks wieder aus allen Schichten.
func erase_chunk(layers: Array[TileMapLayer], chunk: Vector2i) -> void:
	var cs := Config.CHUNK
	for pos in layers.size():
		var layer := layers[pos]
		for oy in cs:
			for ox in cs:
				layer.erase_cell(Vector2i(chunk.x * cs + ox, chunk.y * cs + oy))

## Setzt eine einzelne Kachel neu — der Kern der Bau-Leiste.
##
## Weil der Boden aus neun Schichten mit Eck-Autotiling besteht, ändert eine
## einzige geänderte Kachel die Eckmasken im 3 × 3-Umfeld auf jeder Schicht.
## Mehr aber auch nicht: eine Ecke hängt nur von den vier Kacheln ab, die an
## ihr zusammenstoßen.
func update_cell(layers: Array[TileMapLayer], map: MapData, cell: Vector2i) -> void:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var x := cell.x + ox
			var y := cell.y + oy
			if x >= 0 and y >= 0 and x < Config.MAP_W and y < Config.MAP_H:
				_paint_cell(layers, map, x, y, true)

func _paint_cell(layers: Array[TileMapLayer], map: MapData, x: int, y: int, erase: bool) -> void:
	# Die 3 × 3-Nachbarschaft einmal lesen — danach kostet jede Schicht nur
	# noch Tabellenzugriffe. Innerhalb der Karte wird direkt im Puffer gelesen,
	# das spart neun Funktionsaufrufe je Kachel.
	var w := Config.MAP_W
	var t0: int; var t1: int; var t2: int
	var t3: int; var t4: int; var t5: int
	var t6: int; var t7: int; var t8: int
	if x > 0 and y > 0 and x < w - 1 and y < Config.MAP_H - 1:
		var buf := map.tiles
		var i := y * w + x
		t0 = buf[i - w - 1]; t1 = buf[i - w]; t2 = buf[i - w + 1]
		t3 = buf[i - 1];     t4 = buf[i];     t5 = buf[i + 1]
		t6 = buf[i + w - 1]; t7 = buf[i + w]; t8 = buf[i + w + 1]
	else:
		t0 = _tile(map, x - 1, y - 1); t1 = _tile(map, x, y - 1); t2 = _tile(map, x + 1, y - 1)
		t3 = _tile(map, x - 1, y);     t4 = _tile(map, x, y);     t5 = _tile(map, x + 1, y)
		t6 = _tile(map, x - 1, y + 1); t7 = _tile(map, x, y + 1); t8 = _tile(map, x + 1, y + 1)

	var cell := Vector2i(x, y)
	var count := STACK.size()
	_paint_decor(layers, cell, t4, erase)

	# Häufigster Fall, gerade auf einer noch leeren Karte: ringsum derselbe
	# Bodentyp. Dann ist jede Ecke bedeckt und die Eckrechnung entfällt.
	if t0 == t4 and t1 == t4 and t2 == t4 and t3 == t4 \
			and t5 == t4 and t6 == t4 and t7 == t4 and t8 == t4:
		var full := _full_for(t4, x, y)
		for pos in count:
			if _table[pos * TABLE_STRIDE + t4] == 0:
				if erase:
					layers[pos].erase_cell(cell)
			else:
				layers[pos].set_cell(cell, _sources[pos], full[pos])
		if erase:
			layers[LAYER_EDGE].erase_cell(cell)
		return

	var variant := -1
	for pos in count:
		var layer := layers[pos]
		var base := pos * TABLE_STRIDE

		# Ein gesetzter Block füllt sein Feld — immer.
		if _table[base + t4] != 0:
			if variant < 0:
				variant = variant_at(x, y)
			layer.set_cell(cell, _sources[pos], _full(pos, variant))
			continue

		# Wasser bekommt keinen Saum, seine Kante sitzt hart am Block.
		if _sharp[pos]:
			if erase:
				layer.erase_cell(cell)
			continue

		# Der Übergang wächst aus den Nachbarn HERAUS: eine Ecke wird gesetzt,
		# wenn EINES der drei dort anliegenden Felder dazugehört.
		var mask := 0
		if _table[base + t0] != 0 or _table[base + t1] != 0 or _table[base + t3] != 0:
			mask |= 1                                   # oben links
		if _table[base + t1] != 0 or _table[base + t2] != 0 or _table[base + t5] != 0:
			mask |= 2                                   # oben rechts
		if _table[base + t5] != 0 or _table[base + t7] != 0 or _table[base + t8] != 0:
			mask |= 4                                   # unten rechts
		if _table[base + t3] != 0 or _table[base + t6] != 0 or _table[base + t7] != 0:
			mask |= 8                                   # unten links
		if mask == 0:
			if erase:
				layer.erase_cell(cell)
		else:
			# Welche Ausführung der Maske? Der Streuwert des Feldes entscheidet:
			# ortsfest, also gleich nach jedem Nachladen des Chunks.
			var edge := Config.hash2(x, y) % TerrainAtlas.EDGE_VARIANTS
			layer.set_cell(cell, _sources[pos],
				(_slots[pos] as Array[Vector2i])[mask * TerrainAtlas.EDGE_VARIANTS + edge])

	_paint_edges(layers, cell, t1, t3, t4, t5, t7, erase)

## Streu-Dekoration auf ein Feld.
##
## Ob und was dort steht, ergibt sich allein aus der Feldposition. Dadurch ist
## es ortsfest: derselbe Kiesel liegt nach dem Nachladen eines Chunks wieder an
## derselben Stelle, ohne dass irgendwo eine Liste geführt werden müsste.
##
## Zwei verschiedene Streuwerte: einer entscheidet OB, der andere WAS. Mit
## einem einzigen wären beide Entscheidungen gekoppelt und man sähe es der
## Verteilung an.
func _paint_decor(layers: Array[TileMapLayer], cell: Vector2i, tile: int, erase: bool) -> void:
	if layers.size() <= LAYER_DECOR or decor_source < 0:
		return
	var layer := layers[LAYER_DECOR]
	var choices: Array = []
	match tile:
		MapData.Tile.GRASS: choices = decor_grass
		MapData.Tile.SAND: choices = decor_sand
	var chance := Graphics.decor_chance(tile)
	if choices.is_empty() or chance <= 0 \
			or Config.hash2(cell.x * 3 + 1, cell.y * 7 + 2) % 1000 >= chance:
		if erase:
			layer.erase_cell(cell)
		return
	var pick: int = choices[Config.hash2(cell.y * 5 + 3, cell.x * 11 + 9) % choices.size()]
	layer.set_cell(cell, decor_source, decor_slots[pick])

## Uferkanten: das Land hört sichtbar auf, im Wasser fällt der Grund weg.
func _paint_edges(layers: Array[TileMapLayer], cell: Vector2i,
		north: int, west: int, here: int, east: int, south: int, erase: bool) -> void:
	var edge_layer := layers[LAYER_EDGE]
	var mask := 0
	var slots: Array[Vector2i] = []
	if _is_water(here):
		# Tiefenband: gezählt wird, wo Land liegt.
		if not _is_water(north): mask |= EdgeArt.N
		if not _is_water(east): mask |= EdgeArt.E
		if not _is_water(south): mask |= EdgeArt.S
		if not _is_water(west): mask |= EdgeArt.W
		slots = edges.depth
	else:
		# Uferkante auf dem Land: gezählt wird, wo Wasser liegt.
		if _is_water(north): mask |= EdgeArt.N
		if _is_water(east): mask |= EdgeArt.E
		if _is_water(south): mask |= EdgeArt.S
		if _is_water(west): mask |= EdgeArt.W
		slots = edges.bank

	if mask == 0:
		if erase:
			edge_layer.erase_cell(cell)
	else:
		edge_layer.set_cell(cell, edges.source, slots[mask])

static func _is_water(t: int) -> bool:
	return t == MapData.Tile.WATER

## Die Vollkacheln aller Schichten für eine Kachel ohne abweichende Nachbarn.
func _full_for(tile: int, x: int, y: int) -> Array:
	var variant := variant_at(x, y)
	var out := []
	out.resize(STACK.size())
	for pos in STACK.size():
		out[pos] = _full(pos, variant) if _table[pos * TABLE_STRIDE + tile] != 0 else Vector2i.ZERO
	return out

## Bodentyp mit Fortsetzung über den Kartenrand hinaus — sonst würde jede
## Schicht am Rand ausfransen.
static func _tile(map: MapData, x: int, y: int) -> int:
	return map.get_tile(clampi(x, 0, Config.MAP_W - 1), clampi(y, 0, Config.MAP_H - 1))

func _full(pos: int, variant: int) -> Vector2i:
	var slots: Array[Vector2i] = _slots[pos]
	return slots[TerrainAtlas.FULL_START + posmod(variant, _full_count)]
