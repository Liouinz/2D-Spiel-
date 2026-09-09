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

## Schichten, deren Fläche sich an der Grenze ZURÜCKZIEHT, statt in den
## Nachbarn hineinzuwachsen.
##
## Für Sand auf Gras ist Hineinwachsen richtig: die beiden Böden sollen
## ineinander übergehen. Für Wasser nicht — und zwar aus zwei Gründen.
##
## 1. Die Karte weiss, welches Feld Wasser ist, und daran hängt das Schwimmen.
##    Wüchse das Wasser eine halbe Kachel auf das Nachbarfeld, liefe die Figur
##    sichtbar auf Wasser, ohne zu schwimmen.
## 2. Uferband und Brandung sitzen am Block. Ein weicher Auslauf darüber hinaus
##    legte die Brandung auf den Sand.
##
## Vorher war die Antwort darauf, die Wasserkante ganz hart zu lassen — und
## genau das sah man: rechteckige Becken mit lineargezogenen Ufern.
##
## Jetzt zieht sich das Wasser innerhalb SEINES EIGENEN Feldes zurück. Eine
## Ecke gilt nur, wenn alle drei dort anliegenden Felder Wasser sind; sonst
## frisst dieselbe Rauschkante wie überall sonst ein Stück davon weg. Darunter
## liegt Sand, der dabei zum Vorschein kommt — daraus wird eine geschwungene
## Uferlinie, ohne dass Karte und Bild auseinanderlaufen.
const SHRINK := [MapData.Tile.WATER]

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

## Streu-Dekoration: Quelle im Kachelsatz und die Plätze je Bodentyp.
var decor_source: int = -1
var decor_slots: Array = []
var decor_grass: Array = []
var decor_sand: Array = []
var _shrink: Array[bool] = []           ## Schichten, die sich zurückziehen

## Hinter den drei Bodenschichten lag einmal eine Kantenschicht mit Uferband
## und Tiefenband. Sie ist weg.
##
## Beides sass am BLOCKRAND — und genau davon zieht sich das Wasser jetzt
## zurück. Auf dem Bild war das Ergebnis eindeutig: um jeden Teich lief ein
## schnurgerades dunkles Rechteck durch den Sand, während die Wasserlinie
## daneben geschwungen verlief. Zwei Beschreibungen derselben Küste, die sich
## widersprechen, und die falsche war die gerade.
##
## Schaum und Tiefe stehen jetzt in der Wasserkachel selbst
## (`TerrainAtlas.Rim.SHORE`). Eine Quelle, kein Widerspruch.
##
## Der Platz bleibt frei: die Schicht selbst existiert weiter (leer), damit die
## Indizes von Boden und Dekoration nicht wandern.
const LAYER_EDGE := 3

## Ganz oben die Streu-Dekoration: Büschel, Blumen, Kiesel.
const LAYER_DECOR := 4
const LAYER_COUNT := 5

static func build(art: TileArt, seed_value: int) -> GroundTileSet:
	# Die Kantenschicht kommt DIREKT nach dem Bodenstapel, die Dekoration
	# darueber. GDScript laesst `STACK.size()` nicht als Konstante zu, also
	# steht die Zahl hier — und diese Zusicherung haelt sie an den Stapel
	# gebunden. Waechst er um einen Bodentyp, schlaegt sie an, statt dass
	# Kanten und Dekoration still auf die falsche Schicht zeigen.
	assert(LAYER_EDGE == STACK.size())
	assert(LAYER_DECOR == LAYER_EDGE + 1 and LAYER_COUNT == LAYER_DECOR + 1)
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
		# Wasser trägt seine Uferlinie in der Kachel: aussen Schaum, nach innen
		# ein Tiefenband. Zwei getrennt erzeugte Bilder können sich sonst
		# widersprechen, und genau das ist hier schon passiert.
		var rim: int = TerrainAtlas.Rim.SHORE if SHRINK.has(tile_type) \
			else TerrainAtlas.Rim.SOFT
		var atlas := TerrainAtlas.build(art.base[tile_type], rng, rim)
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

	g._build_table()
	for pos in STACK.size():
		g._shrink.append(SHRINK.has(STACK[pos]))
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

## Wie tief liegt dieses Wasserfeld?
##
## 0 = am Ufer, 1 = eine Kachel davon entfernt, 2 = draussen. Daraus wird die
## Helligkeitsstufe der Wasserkachel: aussen hell, in der Mitte dunkel — die
## Tiefenwirkung, die eine Pfuetze von einem See unterscheidet.
##
## Stufe 2 wird NICHT ueber den vollen 5 x 5 Umkreis geprueft (24 Nachbarn je
## Wasserfeld waeren beim Nachladen eines Chunks spuerbar), sondern nur ueber
## die vier Felder in zwei Schritten Abstand. Das ist eine Naeherung: eine
## schmale diagonale Bucht bekommt vielleicht eine Stufe zu viel. Auf dem
## Bildschirm sieht man den Unterschied nicht, im Ladebalken schon.
func water_depth(map: MapData, x: int, y: int, ring: Array) -> int:
	for t: int in ring:
		if t != MapData.Tile.WATER:
			return 0
	if not (map.is_water(x, y - 2) and map.is_water(x, y + 2)
			and map.is_water(x - 2, y) and map.is_water(x + 2, y)):
		return 1
	return 2

## Die Kachelnummer eines Wasserfeldes: Stufe aus der Tiefe, Variante aus dem
## Streuwert. Beim Wasser ersetzt die Tiefe das Rauschen — sonst laegen helle
## und dunkle Flecken quer ueber den See, statt der Kuestenlinie zu folgen.
func water_variant(map: MapData, x: int, y: int, ring: Array) -> int:
	return water_depth(map, x, y, ring) * TileArt.VARIANTS \
		+ Config.hash2(x, y) % TileArt.VARIANTS

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

## Malt einen Chunk auf alle Bodenschichten.
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
## Weil der Boden aus mehreren Schichten mit Eck-Autotiling besteht, ändert eine
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
		var full := _full_for(t4, x, y, map)
		for pos in count:
			if _table[pos * TABLE_STRIDE + t4] == 0:
				if erase:
					layers[pos].erase_cell(cell)
			else:
				layers[pos].set_cell(cell, _sources[pos], full[pos])
		if erase:
			layers[LAYER_EDGE].erase_cell(cell)
		return

	# Die Helligkeitsstufe aus dem Rauschen. Einmal gerechnet, danach nur
	# GELESEN — sie darf NICHT von einer Schicht ueberschrieben werden.
	#
	# Vorher stand hier eine Variable, die eine Schrumpf-Schicht durch die
	# Wassertiefe ersetzte. Heute faellt das nicht auf, weil Wasser im STACK
	# zuletzt kommt; sobald ein Bodentyp dahinter kaeme, bekaeme er die Tiefe
	# des Wassers als Helligkeit.
	var noise_variant := -1
	for pos in count:
		var layer := layers[pos]
		var base := pos * TABLE_STRIDE

		# Ein gesetzter Block füllt sein Feld — ausser er gehört zu einer
		# Schicht, die sich an der Grenze zurückzieht.
		if _table[base + t4] != 0:
			if _shrink[pos]:
				# Wasser bekommt seine Stufe aus der TIEFE statt aus dem
				# Rauschen — siehe `water_variant`.
				var depth := water_variant(map, x, y, [t0, t1, t2, t3, t5, t6, t7, t8])
				# Die Eckmaske ist hier ANDERSHERUM gemeint als beim Übergang:
				# dort gilt eine Ecke, sobald EINES der drei Felder dazugehört
				# (die Fläche wächst heraus), hier nur, wenn ALLE drei
				# dazugehören (die Fläche zieht sich zurück).
				var keep := 0
				if _all3(base, t0, t1, t3): keep |= 1     # oben links
				if _all3(base, t1, t2, t5): keep |= 2     # oben rechts
				if _all3(base, t5, t7, t8): keep |= 4     # unten rechts
				if _all3(base, t3, t6, t7): keep |= 8     # unten links
				layer.set_cell(cell, _sources[pos], _shrunk(pos, keep, x, y, depth))
			else:
				if noise_variant < 0:
					noise_variant = variant_at(x, y)
				layer.set_cell(cell, _sources[pos], _full(pos, noise_variant))
			continue

		# Wasser zieht sich zurück, statt hinauszuwachsen: auf einem Feld ohne
		# Wasser liegt kein Wasser, Punkt. Die weiche Kante entsteht im
		# Wasserfeld selbst, siehe oben beim Setzen der Vollkachel.
		if _shrink[pos]:
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
			# Welche Ausführung der Maske? Normalerweise entscheidet der
			# Streuwert des Feldes: ortsfest, also gleich nach jedem Nachladen
			# des Chunks.
			var edge := Config.hash2(x, y) % TerrainAtlas.EDGE_VARIANTS
			if mask == 15:
				# Maske 15 ist der Sonderfall: das Feld ist RINGSUM umgeben,
				# gehört aber selbst nicht dazu — eine Lücke also. Hier
				# entscheidet nicht der Zufall, sondern wohin die Lücke
				# weiterläuft; sonst stünde ein rundes Loch mitten in einem
				# durchgehenden Spalt.
				edge = _hole_kind(_table[base + t1] != 0, _table[base + t3] != 0,
					_table[base + t5] != 0, _table[base + t7] != 0)
			layer.set_cell(cell, _sources[pos],
				(_slots[pos] as Array[Vector2i])[mask * TerrainAtlas.EDGE_VARIANTS + edge])

	# Die Kantenschicht bleibt leer — siehe LAYER_EDGE.
	if erase and layers.size() > LAYER_EDGE:
		layers[LAYER_EDGE].erase_cell(cell)

## Die zurückgezogene Form eines Wasserfeldes zu einer Eckmaske. Dieselben
## Kacheln und dieselbe Rauschkante wie bei jedem anderen Übergang — nur die
## Frage, wann eine Ecke gilt, ist umgekehrt (siehe Aufrufstelle).
func _shrunk(pos: int, mask: int, x: int, y: int, variant: int) -> Vector2i:
	if mask == 15:
		return _full(pos, variant)               # ringsum Wasser: volle Kachel
	var edge := Config.hash2(x, y) % TerrainAtlas.EDGE_VARIANTS
	return (_slots[pos] as Array[Vector2i])[mask * TerrainAtlas.EDGE_VARIANTS + edge]

func _all3(base: int, a: int, b: int, c: int) -> bool:
	return _table[base + a] != 0 and _table[base + b] != 0 and _table[base + c] != 0

## Wohin läuft die Lücke weiter? Danach richtet sich die Öffnung.
##
## Liegt der Boden links UND rechts, aber nicht oben und unten, dann ist die
## Lücke ein senkrechter Spalt — und die Öffnung muss senkrecht durchlaufen.
## Umgekehrt genauso. Ist es in beiden Richtungen gleich (ein einzeln
## entferntes Feld mitten in einer Fläche), bleibt das runde Loch.
static func _hole_kind(north: bool, west: bool, east: bool, south: bool) -> int:
	var horizontal := west and east
	var vertical := north and south
	if horizontal and not vertical:
		return TerrainAtlas.HOLE_VERTICAL
	if vertical and not horizontal:
		return TerrainAtlas.HOLE_HORIZONTAL
	return TerrainAtlas.HOLE_ROUND

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

## Die Vollkacheln aller Schichten für eine Kachel ohne abweichende Nachbarn.
func _full_for(tile: int, x: int, y: int, map: MapData) -> Array:
	var variant := variant_at(x, y)
	# Dieser schnelle Weg gilt nur, wenn ringsum derselbe Boden liegt — beim
	# Wasser heisst das mindestens Tiefenstufe 1. Ohne diese Zeile bekaeme die
	# ganze Seemitte die Stufe aus dem Rauschen und nur der Rand die aus der
	# Tiefe; man saehe den Bruch als Ring um jeden See.
	var deep := -1
	if tile == MapData.Tile.WATER:
		deep = water_variant(map, x, y, [tile, tile, tile, tile, tile, tile, tile, tile])
	var out := []
	out.resize(STACK.size())
	for pos in STACK.size():
		if _table[pos * TABLE_STRIDE + tile] == 0:
			out[pos] = Vector2i.ZERO
			continue
		out[pos] = _full(pos, deep if (deep >= 0 and _shrink[pos]) else variant)
	return out

## Bodentyp mit Fortsetzung über den Kartenrand hinaus — sonst würde jede
## Schicht am Rand ausfransen.
static func _tile(map: MapData, x: int, y: int) -> int:
	return map.get_tile(clampi(x, 0, Config.MAP_W - 1), clampi(y, 0, Config.MAP_H - 1))

func _full(pos: int, variant: int) -> Vector2i:
	var slots: Array[Vector2i] = _slots[pos]
	return slots[TerrainAtlas.FULL_START + posmod(variant, _full_count)]
