class_name WorldBuilder
extends RefCounted
## Backt den Boden in EINE Textur, verteilt Requisiten und baut die Kollision.
## Ein Draw-Call für den Boden -> auch auf schwachen Laptops flüssig (§7 der Prioritäten).

const T := Config.TILE
const EDGE_DEPTH := TileArt.EDGE_DEPTH

var map: MapData
var art: TileArt
var props: Dictionary                 ## name -> {tex, size, foot, shadow}
var placed: Array[Dictionary] = []    ## {name, pos (px, Fußpunkt)}
var ground_texture: ImageTexture
var collision_rects: Array[Rect2] = []

var _rng := RandomNumberGenerator.new()
var _occupied := PackedByteArray()

func build(seed_value: int) -> void:
	_rng.seed = seed_value
	map = MapData.new()
	map.generate(seed_value)
	art = TileArt.build(seed_value)
	props = PropArt.build(seed_value)
	_occupied.resize(Config.MAP_W * Config.MAP_H)
	_place_village()
	_place_nature()
	_bake_ground()
	_build_collision()

# --- Requisiten --------------------------------------------------------------

func _occupy(x: int, y: int, r: int = 0) -> void:
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			var px := x + ox
			var py := y + oy
			if map.in_bounds(px, py):
				_occupied[py * Config.MAP_W + px] = 1

func _is_occupied(x: int, y: int) -> bool:
	if not map.in_bounds(x, y):
		return true
	return _occupied[y * Config.MAP_W + x] != 0

func _add(name: String, pos_px: Vector2) -> void:
	placed.append({"name": name, "pos": pos_px})

func _tile_center(x: int, y: int) -> Vector2:
	return Vector2(x * T + T * 0.5, y * T + T * 0.5)

func _place_village() -> void:
	for h: Dictionary in Layout.HOUSES:
		var pos: Vector2i = h["pos"]
		var size: Vector2i = h["size"]
		var name := "house_big" if h["type"] == "big" else "house_small"
		# Bodenfläche für das Haus einebnen und freihalten
		for y in range(pos.y, pos.y + size.y):
			for x in range(pos.x, pos.x + size.x):
				if map.get_tile(x, y) != MapData.Tile.PATH:
					map.set_tile(x, y, MapData.Tile.GRASS)
		for y in range(pos.y - 1, pos.y + size.y + 1):
			for x in range(pos.x - 1, pos.x + size.x + 1):
				_occupy(x, y)
		var foot := Vector2((pos.x + size.x * 0.5) * T, (pos.y + size.y) * T)
		_add(name, foot)

	_add("well", _tile_center(Layout.WELL.x, Layout.WELL.y))
	_occupy(Layout.WELL.x, Layout.WELL.y, 1)

	for f: Dictionary in Layout.FENCES:
		var a: Vector2i = f["from"]
		var b: Vector2i = f["to"]
		var horizontal := a.y == b.y
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for s in steps + 1:
			var cell := a + step * s
			if map.is_water(cell.x, cell.y):
				continue
			_add("fence_h" if horizontal else "fence_v", _tile_center(cell.x, cell.y) + Vector2(0, T * 0.5))
			_occupy(cell.x, cell.y)

	for d: Dictionary in Layout.DETAILS:
		var p: Vector2i = d["pos"]
		if map.is_water(p.x, p.y):
			continue
		_add(d["kind"], _tile_center(p.x, p.y) + Vector2(0, T * 0.3))
		_occupy(p.x, p.y)

	# Startbereich des Spielers freihalten
	_occupy(Layout.SPAWN.x, Layout.SPAWN.y, 2)

func _place_nature() -> void:
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			if _is_occupied(x, y):
				continue
			var t := map.get_tile(x, y)
			if t == MapData.Tile.PATH or map.is_water(x, y):
				continue
			# Uferbewuchs
			if _touches_water(x, y):
				if _rng.randf() < 0.34:
					_add("reeds" if _rng.randf() < 0.6 else "cattail", _tile_center(x, y) + Vector2(0, T * 0.4))
				continue
			var roll := _rng.randf()
			match t:
				MapData.Tile.FOREST:
					if roll < 0.40:
						_spawn("pine" if _rng.randf() < 0.45 else ("oak" if _rng.randf() < 0.6 else "oak2"), x, y)
					elif roll < 0.50:
						_spawn("bush", x, y)
					elif roll < 0.55:
						_spawn("sapling", x, y)
					elif roll < 0.57:
						_spawn("rock_small", x, y)
				MapData.Tile.GRASS:
					if roll < 0.030:
						_spawn("oak" if _rng.randf() < 0.7 else "pine", x, y)
					elif roll < 0.065:
						_spawn("bush", x, y)
					elif roll < 0.085:
						_spawn("rock_small", x, y)
					elif roll < 0.095:
						_spawn("sapling", x, y)
				MapData.Tile.MEADOW:
					if roll < 0.020:
						_spawn("sapling", x, y)
					elif roll < 0.045:
						_spawn("bush", x, y)
					elif roll < 0.055:
						_spawn("rock_small", x, y)
				MapData.Tile.ROCK:
					if roll < 0.10:
						_spawn("rock_big", x, y)
					elif roll < 0.22:
						_spawn("rock_small", x, y)
					elif roll < 0.26:
						_spawn("pine", x, y)
				MapData.Tile.SAND:
					if roll < 0.025:
						_spawn("rock_small", x, y)

func _spawn(name: String, x: int, y: int) -> void:
	var jitter := Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 2.0))
	_add(name, _tile_center(x, y) + Vector2(0, T * 0.35) + jitter)
	_occupy(x, y)

func _touches_water(x: int, y: int) -> bool:
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.is_water(x + o.x, y + o.y):
			return true
	return false

# --- Boden backen ------------------------------------------------------------

func _bake_ground() -> void:
	var size := Config.world_size_px()
	var img := Image.create(size.x, size.y, false, Pixel.FMT)
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.seed + 5

	# 1) Grundkacheln
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			var t := map.get_tile(x, y)
			var variants: Array = art.base[t]
			var v: Image = variants[(x * 7 + y * 13 + t * 3) % variants.size()]
			img.blit_rect(v, Rect2i(0, 0, T, T), Vector2i(x * T, y * T))

	# 2) Weiche Übergänge zu Nachbarkacheln
	var offsets := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var dst_off := [
		Vector2i(0, 0), Vector2i(0, T - EDGE_DEPTH), Vector2i(0, 0), Vector2i(T - EDGE_DEPTH, 0)
	]
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			var t := map.get_tile(x, y)
			for d in 4:
				var o: Vector2i = offsets[d]
				var nt := map.get_tile(x + o.x, y + o.y)
				if nt == t or not map.in_bounds(x + o.x, y + o.y):
					continue
				var strip: Image = art.edge[nt][d]
				img.blend_rect(strip, Rect2i(Vector2i.ZERO, strip.get_size()),
					Vector2i(x * T, y * T) + dst_off[d])

	# 3) Streu-Dekoration
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			var t := map.get_tile(x, y)
			var set: Array[Image] = []
			var chance := 0.0
			match t:
				MapData.Tile.GRASS:
					set = art.decor_grass
					chance = 0.30
				MapData.Tile.MEADOW:
					set = art.decor_grass
					chance = 0.62
				MapData.Tile.FOREST:
					set = art.decor_forest
					chance = 0.34
				MapData.Tile.SAND:
					set = art.decor_sand
					chance = 0.14
				MapData.Tile.PATH:
					set = art.decor_path
					chance = 0.07
				MapData.Tile.WATER:
					set = art.decor_water
					chance = 0.05
			if set.is_empty() or rng.randf() > chance:
				continue
			var count := 1 if rng.randf() > 0.35 else 2
			for i in count:
				var dec: Image = set[rng.randi() % set.size()]
				var dx := rng.randi_range(0, T - dec.get_width())
				var dy := rng.randi_range(0, T - dec.get_height())
				img.blend_rect(dec, Rect2i(Vector2i.ZERO, dec.get_size()), Vector2i(x * T + dx, y * T + dy))

	# 4) Schatten der Requisiten in den Boden einbacken (statisch, kostet nichts)
	for p: Dictionary in placed:
		var e: Dictionary = props[p["name"]]
		var sh: Vector2 = e["shadow"]
		if sh == Vector2.ZERO:
			continue
		var pos: Vector2 = p["pos"]
		Pixel.ellipse(img, pos.x, pos.y - 2.0, sh.x, sh.y, Palette.SHADOW)

	ground_texture = ImageTexture.create_from_image(img)

# --- Kollision ---------------------------------------------------------------

func _build_collision() -> void:
	# a) Wasser/Rand als zusammengefasste Rechtecke (wenige Formen statt tausender)
	var used := PackedByteArray()
	used.resize(Config.MAP_W * Config.MAP_H)
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			if not map.is_solid(x, y) or used[y * Config.MAP_W + x] != 0:
				continue
			var w := 0
			while x + w < Config.MAP_W and map.is_solid(x + w, y) and used[y * Config.MAP_W + x + w] == 0:
				w += 1
			var h := 1
			while y + h < Config.MAP_H:
				var ok := true
				for i in w:
					if not map.is_solid(x + i, y + h) or used[(y + h) * Config.MAP_W + x + i] != 0:
						ok = false
						break
				if not ok:
					break
				h += 1
			for oy in h:
				for ox in w:
					used[(y + oy) * Config.MAP_W + x + ox] = 1
			collision_rects.append(Rect2(x * T, y * T, w * T, h * T))

	# b) Requisiten mit Fußabdruck
	for p: Dictionary in placed:
		var e: Dictionary = props[p["name"]]
		var foot: Vector2 = e["foot"]
		if foot == Vector2.ZERO:
			continue
		var pos: Vector2 = p["pos"]
		collision_rects.append(Rect2(pos.x - foot.x, pos.y - foot.y * 2.0, foot.x * 2.0, foot.y * 2.0))
