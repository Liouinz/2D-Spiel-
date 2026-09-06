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

## Fels und Wasser verlaufen überhaupt nicht: sie belegen genau ihre Blöcke.
##
## Das Eck-Autotiling legt die Geländegrenze auf das Eckraster — eine halbe
## Kachel versetzt zum Blockraster. Für Wiese, Waldboden und Sand ist das
## richtig, die sollen ineinander übergehen. Für eine Klippe und für eine
## Uferlinie nicht: Wand, Uferband und Brandung sitzen am Block, der weiche
## Auslauf aber darüber hinaus — die Brandung landete dadurch auf dem Sand
## statt im Wasser. Diese beiden Übergänge machen die Kantenkacheln.
##
## Tiefwasser bleibt weich: dort geht es nicht um eine Kante, sondern um Tiefe.
const SHARP := [MapData.Tile.ROCK, MapData.Tile.WATER]

## Gehört ein Bodentyp zu einer Schicht des Stapels?
##
## Diese Regel ist die einzige Wahrheit darüber, welche Schicht wo liegt —
## der Weltaufbau und die Bau-Leiste benutzen beide sie, damit ein von Hand
## gesetzter Block genauso aussieht wie ein erzeugter.
static func in_layer(pos: int, t: int) -> bool:
	if pos == 0:
		return true                                       # Gras füllt alles
	if pos == 4:
		# Sand liegt auch unter dem flachen Wasser, damit die Brandung auf Sand
		# trifft. Unter Tiefwasser wäre er nie zu sehen.
		return t == MapData.Tile.SAND or t == MapData.Tile.WATER
	if pos == 5:
		return t == MapData.Tile.WATER or t == MapData.Tile.DEEP_WATER
	return t == STACK[pos]

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
## Nachschlagtabelle Schicht x Bodentyp -> gehoert dazu (0/1). Ersetzt neun
## ganzseitige Zugehoerigkeitsraster: bei 2048 x 2048 Bloecken waeren das 37 MB
## gewesen, hier sind es 81 Bytes.
var _table := PackedByteArray()
var _shade: FastNoiseLite               ## grossflaechige Bodenhelligkeit
var edges: EdgeArt                      ## Klippen und Ufer
var _sharp: Array[bool] = []            ## Schichten ohne weichen Übergang

## Die Schichtenliste enthält hinter den neun Bodenschichten noch zwei:
## die Kanten (Klippenwand, Uferband) und die Schlagschatten darunter.
const LAYER_EDGE := 9
const LAYER_SHADOW := 10
const LAYER_COUNT := 11

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

	g.edges = EdgeArt.build(ts)
	g._build_table()
	for pos in STACK.size():
		g._sharp.append(SHARP.has(STACK[pos]))
	g._shade = FastNoiseLite.new()
	g._shade.seed = seed_value + 809
	g._shade.frequency = 0.030
	g._build_decor(ts, art, rng)
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
	return shade * TileArt.VARIANTS + (x * 7 + y * 13) % TileArt.VARIANTS

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
## Setzt die Dekorationsschicht eines Chunks. `at` liefert je Kachel den
## flachen Index einer Dekorationskachel oder -1.
func paint_decor_chunk(layer: TileMapLayer, chunk: Vector2i, at: Callable) -> void:
	layer.tile_set = tileset
	var cs := Config.CHUNK
	for oy in cs:
		for ox in cs:
			var x := chunk.x * cs + ox
			var y := chunk.y * cs + oy
			var i: int = at.call(x, y)
			if i >= 0:
				layer.set_cell(Vector2i(x, y), decor_source, decor_slots[i])

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
			layers[LAYER_SHADOW].erase_cell(cell)
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

		# Fels und Wasser bekommen keinen Saum, ihre Kante sitzt hart am Block.
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
			layer.set_cell(cell, _sources[pos], (_slots[pos] as Array[Vector2i])[mask])

	_paint_edges(layers, cell, t1, t3, t4, t5, t7, erase)

## Klippen und Ufer: alles, was Höhe zeigen soll.
##
## Der Schatten wird bewusst auf der Kachel UNTER der Wand gesetzt, aber von
## dieser Kachel aus nach oben geschaut — sonst würde eine Kachel in den
## Nachbarchunk schreiben, und beim Entladen bliebe der Schatten stehen.
func _paint_edges(layers: Array[TileMapLayer], cell: Vector2i,
		north: int, west: int, here: int, east: int, south: int, erase: bool) -> void:
	var edge_layer := layers[LAYER_EDGE]
	var shadow_layer := layers[LAYER_SHADOW]

	var mask := 0
	var slots: Array[Vector2i] = []
	if here == MapData.Tile.ROCK:
		# Klippe: gezählt wird, wo KEIN Fels liegt.
		if north != here: mask |= EdgeArt.N
		if east != here: mask |= EdgeArt.E
		if south != here: mask |= EdgeArt.S
		if west != here: mask |= EdgeArt.W
		slots = edges.cliff
	elif _is_water(here):
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

	# Ausführung nach Position streuen: sonst wiederholt sich dieselbe Wand an
	# jeder Kachel und die Klippe sieht gestempelt aus.
	var v := posmod(cell.x * 7 + cell.y * 13, EdgeArt.VARIANTS)
	if mask == 0:
		if erase:
			edge_layer.erase_cell(cell)
	elif here == MapData.Tile.ROCK:
		edge_layer.set_cell(cell, edges.source, slots[mask * EdgeArt.VARIANTS + v])
	else:
		edge_layer.set_cell(cell, edges.source, slots[mask])

	# Schlagschatten der Klippe auf dem Feld darunter. Nur ein Schatten — die
	# Wand selbst bleibt vollständig auf der Felskachel, damit sichtbare Kante
	# und Kollisionskante zusammenfallen.
	if north == MapData.Tile.ROCK and here != MapData.Tile.ROCK:
		shadow_layer.set_cell(cell, edges.source, edges.foot[v])
	elif erase:
		shadow_layer.erase_cell(cell)

static func _is_water(t: int) -> bool:
	return t == MapData.Tile.WATER or t == MapData.Tile.DEEP_WATER

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
