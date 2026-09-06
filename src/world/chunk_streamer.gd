class_name ChunkStreamer
extends Node2D
## Lädt und entlädt die Welt chunkweise um die Spielfigur herum.
##
## Bei 128 × 128 Chunks hat die Karte 4,2 Millionen Kacheln. Sie alle auf neun
## Bodenschichten zu malen wäre nach der heutigen Messung (7680 Kacheln in
## 50 ms) rund eine halbe Minute — und Godot hat für TileMaps kein eigenes
## Chunk-Laden, das Thema wurde als „not planned" geschlossen. Also von Hand.
##
## Gehalten wird ein Quadrat aus (2 · RADIUS + 1)² Chunks um die Figur. Der
## Bildausschnitt ist bei Zoom 1,5 nur rund 27 × 15 Blöcke groß, ein Radius von
## 2 lässt also ringsum mindestens einen ganzen Chunk Puffer.
##
## Wichtig: die Karte selbst (`MapData.tiles`) liegt immer vollständig im
## Speicher. Nur die Kacheln und Kollisionsformen kommen und gehen. Dadurch
## stimmen die Eck-Übergänge auch an den Grenzen zu noch nicht geladenen Chunks.

var map: MapData
var ground: GroundTileSet
var player: Node2D
var decor_at: Callable          ## (x, y) -> Index einer Dekorationskachel oder -1

## Neun Bodenschichten, danach Kanten und Schlagschatten
## (siehe GroundTileSet.LAYER_EDGE / LAYER_SHADOW).
var layers: Array[TileMapLayer] = []
var decor: TileMapLayer
var body: StaticBody2D                 ## Sammelknoten aller Kollisionsformen

var _loaded: Dictionary = {}           ## Vector2i -> Array[CollisionShape2D]
var _pending: Array[Vector2i] = []     ## noch zu ladende Chunks, nächster zuerst
var _last_chunk := Vector2i(-9999, -9999)

## Wie viele Chunks in dieser Sitzung geladen bzw. entladen wurden (Diagnose).
var loads: int = 0
var unloads: int = 0

func setup(m: MapData, g: GroundTileSet, p: Node2D) -> void:
	map = m
	ground = g
	player = p

	for pos in GroundTileSet.STACK.size():
		layers.append(_layer("L%d_%s" % [pos, GroundTileSet.NAMES[GroundTileSet.STACK[pos]]],
			-40 + pos, g))

	# Kanten und Schatten liegen über dem Boden, aber unter der Brandung:
	# Klippenwände und Uferbänder gehören zum Untergrund, die Wellen darüber.
	# Reihenfolge muss zu GroundTileSet.LAYER_EDGE / LAYER_SHADOW passen.
	layers.append(_layer("Kanten", -20, g))
	layers.append(_layer("Schatten", -21, g))

	decor = TileMapLayer.new()
	decor.name = "Decoration"
	decor.z_index = -25
	decor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.tile_set = g.tileset
	add_child(decor)

	body = StaticBody2D.new()
	body.name = "Collision"
	add_child(body)

func _layer(layer_name: String, z: int, g: GroundTileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.tile_set = g.tileset
	add_child(layer)
	return layer

## Baut sofort alles auf, was um die Figur herum liegen muss — ohne Budget,
## damit beim Betreten der Welt nichts fehlt.
func prime() -> void:
	_refresh_wanted()
	while not _pending.is_empty():
		_load(_pending.pop_back())

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var here := GridOverlay.chunk_of(GridOverlay.block_at(player.global_position))
	if here != _last_chunk:
		_last_chunk = here
		_refresh_wanted()
	# Entladen ist billig und passiert sofort; Laden kostet ein paar
	# Millisekunden je Chunk und wird deshalb über mehrere Bilder verteilt.
	for i in Config.CHUNK_BUDGET:
		if _pending.is_empty():
			return
		_load(_pending.pop_back())

## Bestimmt die Sollmenge neu: alles ausserhalb fliegt raus, alles fehlende
## kommt in die Warteschlange — das Nächstliegende zuletzt, weil hinten
## entnommen wird.
func _refresh_wanted() -> void:
	var here := GridOverlay.chunk_of(GridOverlay.block_at(player.global_position))
	var r := Config.LOAD_RADIUS
	var cw := Config.MAP_W / Config.CHUNK
	var ch := Config.MAP_H / Config.CHUNK

	for c: Vector2i in _loaded.keys():
		if absi(c.x - here.x) > r or absi(c.y - here.y) > r:
			_unload(c)

	_pending.clear()
	var wanted: Array[Vector2i] = []
	for cy in range(here.y - r, here.y + r + 1):
		for cx in range(here.x - r, here.x + r + 1):
			if cx < 0 or cy < 0 or cx >= cw or cy >= ch:
				continue
			if not _loaded.has(Vector2i(cx, cy)):
				wanted.append(Vector2i(cx, cy))
	# Weit entfernte zuerst in die Liste, nahe ans Ende: pop_back() nimmt
	# dadurch immer den Chunk, der am dringendsten gebraucht wird.
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - here).length_squared() > (b - here).length_squared())
	_pending = wanted

func _load(chunk: Vector2i) -> void:
	if _loaded.has(chunk):
		return
	ground.paint_chunk(layers, map, chunk)
	if decor_at.is_valid():
		ground.paint_decor_chunk(decor, chunk, decor_at)
	_loaded[chunk] = _collision_for(chunk)
	loads += 1

func _unload(chunk: Vector2i) -> void:
	ground.erase_chunk(layers, chunk)
	var cs := Config.CHUNK
	for oy in cs:
		for ox in cs:
			decor.erase_cell(Vector2i(chunk.x * cs + ox, chunk.y * cs + oy))
	for shape: CollisionShape2D in _loaded[chunk]:
		shape.queue_free()
	_loaded.erase(chunk)
	unloads += 1

## Kollision je Chunk: die festen Kacheln werden innerhalb des Chunks zu
## möglichst wenigen Rechtecken zusammengefasst. Dasselbe gierige Verfahren wie
## bisher über die ganze Karte, nur eben auf 16 × 16 Feldern.
func _collision_for(chunk: Vector2i) -> Array[CollisionShape2D]:
	var out: Array[CollisionShape2D] = []
	var cs := Config.CHUNK
	var bx := chunk.x * cs
	var by := chunk.y * cs
	var used := PackedByteArray()
	used.resize(cs * cs)

	for oy in cs:
		for ox in cs:
			if used[oy * cs + ox] != 0 or not map.is_solid(bx + ox, by + oy):
				continue
			var w := 0
			while ox + w < cs and used[oy * cs + ox + w] == 0 and map.is_solid(bx + ox + w, by + oy):
				w += 1
			var h := 1
			while oy + h < cs:
				var ok := true
				for i in w:
					if used[(oy + h) * cs + ox + i] != 0 or not map.is_solid(bx + ox + i, by + oy + h):
						ok = false
						break
				if not ok:
					break
				h += 1
			for iy in h:
				for ix in w:
					used[(oy + iy) * cs + ox + ix] = 1
			# Einen halben Pixel überlappen lassen. Zwei Rechtecke aus
			# Nachbarchunks stossen sonst stumpf aneinander, und
			# move_and_slide() kann an dieser Innenkante hängenbleiben —
			# das war das „an Terrain-Ecken festgehalten".
			out.append(_shape(Rect2(
				(bx + ox) * Config.TILE - 0.5, (by + oy) * Config.TILE - 0.5,
				w * Config.TILE + 1.0, h * Config.TILE + 1.0)))
	return out

func _shape(r: Rect2) -> CollisionShape2D:
	var box := RectangleShape2D.new()
	box.size = r.size
	var cs := CollisionShape2D.new()
	cs.shape = box
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)
	return cs

## Nach einer Bauänderung: Kacheln im 3 × 3-Umfeld und die Kollision der
## betroffenen Chunks neu setzen.
func refresh_cell(cell: Vector2i) -> void:
	ground.update_cell(layers, map, cell)
	var touched := {}
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var c := GridOverlay.chunk_of(cell + Vector2i(ox, oy))
			if _loaded.has(c):
				touched[c] = true
	for c: Vector2i in touched:
		for shape: CollisionShape2D in _loaded[c]:
			shape.queue_free()
		_loaded[c] = _collision_for(c)

## Anzahl geladener Chunks — für den Selbsttest.
func loaded_count() -> int:
	return _loaded.size()

func is_loaded(chunk: Vector2i) -> bool:
	return _loaded.has(chunk)

## Kollisionsformen insgesamt — für den Selbsttest.
func shape_count() -> int:
	return body.get_child_count()
