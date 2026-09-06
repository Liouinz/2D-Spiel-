class_name WorldBuilder
extends RefCounted
## Verteilt die Requisiten, backt den Boden in EINE Textur und baut die Kollision.
## Ein Draw-Call für den Boden -> auch auf schwachen Laptops flüssig.

const T := Config.TILE

var map: MapData
var art: TileArt
var props: Dictionary                 ## name -> {"variants": [...]}
var placed: Array[Dictionary] = []    ## {name, variant, pos (px, Fußpunkt)}
var ground: GroundTileSet            ## Kachelsatz mit Terrain-Übergängen
var collision_rects: Array[Rect2] = []

var _rng := RandomNumberGenerator.new()
var _occupied := PackedByteArray()
var _density: FastNoiseLite
var _clearing: FastNoiseLite
var _species: FastNoiseLite
var _shade: FastNoiseLite
var timings: Dictionary = {}   ## Dauer der Bauphasen in ms (Diagnose)
var _variants := PackedByteArray()

func _phase(name: String, started: int) -> int:
	timings[name] = Time.get_ticks_msec() - started
	return Time.get_ticks_msec()

func build(seed_value: int) -> void:
	var t := Time.get_ticks_msec()
	_rng.seed = seed_value
	map = MapData.new()
	map.generate(seed_value)
	t = _phase("karte", t)
	art = TileArt.build(seed_value)
	t = _phase("kacheln", t)
	# Im Aufbaumodus wird nichts platziert — die rund 90 Requisitengrafiken
	# kosteten dort eine halbe Sekunde Ladezeit für nichts.
	props = {} if Config.EMPTY_WORLD else PropArt.build(seed_value)
	t = _phase("requisiten", t)
	_occupied.resize(Config.MAP_W * Config.MAP_H)
	_setup_noise(seed_value)
	# Im Aufbaumodus bleibt die Karte leer — nur Boden und Raster.
	if not Config.EMPTY_WORLD:
		_place_village()
		_place_nature()
	t = _phase("platzierung", t)
	ground = GroundTileSet.build(art, seed_value)
	t = _phase("kachelsatz", t)
	_build_collision()
	t = _phase("kollision", t)

func _setup_noise(seed_value: int) -> void:
	_density = _noise(seed_value + 301, 0.10)    ## Baumgruppen
	_clearing = _noise(seed_value + 457, 0.055)  ## Lichtungen
	_species = _noise(seed_value + 613, 0.045)   ## Nadel- oder Laubwald
	_shade = _noise(seed_value + 809, 0.030)     ## großflächige Bodenhelligkeit

func _noise(s: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.frequency = freq
	return n

## Rauschwert im Bereich 0..1
func _n01(n: FastNoiseLite, x: int, y: int) -> float:
	return n.get_noise_2d(x, y) * 0.5 + 0.5

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
	placed.append({
		"name": name,
		"variant": PropArt.pick(props, name, _rng),
		"pos": pos_px,
	})

func _tile_center(x: int, y: int) -> Vector2:
	return Vector2(x * T + T * 0.5, y * T + T * 0.5)

func _place_village() -> void:
	for h: Dictionary in Layout.BUILDINGS:
		var pos: Vector2i = h["pos"]
		var size: Vector2i = h["size"]
		var name: String = h["type"]
		for y in range(pos.y - 1, pos.y + size.y + 2):
			for x in range(pos.x - 1, pos.x + size.x + 1):
				_occupy(x, y)
		# Feiner Versatz: die Häuser stehen nicht wie am Lineal ausgerichtet
		var off: Vector2 = h.get("offset", Vector2.ZERO)
		_add(name, Vector2((pos.x + size.x * 0.5) * T, (pos.y + size.y) * T) + off)

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

	for h: Dictionary in Layout.HEDGES:
		var ha: Vector2i = h["from"]
		var hb: Vector2i = h["to"]
		var hstep := Vector2i(signi(hb.x - ha.x), signi(hb.y - ha.y))
		var hsteps := maxi(absi(hb.x - ha.x), absi(hb.y - ha.y))
		for s in hsteps + 1:
			var cell := ha + hstep * s
			var t := map.get_tile(cell.x, cell.y)
			if map.is_water(cell.x, cell.y) or t == MapData.Tile.PATH or t == MapData.Tile.COBBLE:
				continue
			var wobble := Vector2(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.0, 1.0))
			_add("bush", _tile_center(cell.x, cell.y) + Vector2(0, T * 0.42) + wobble)
			_occupy(cell.x, cell.y)

	for d: Dictionary in Layout.DETAILS:
		var p: Vector2i = d["pos"]
		if map.is_water(p.x, p.y):
			continue
		var jitter := Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-1.0, 1.0))
		_add(d["kind"], _tile_center(p.x, p.y) + Vector2(0, T * 0.3) + jitter)
		_occupy(p.x, p.y)

	_occupy(Layout.SPAWN.x, Layout.SPAWN.y, 2)

## Bewuchs nach Dichtefeldern statt gleichmäßigem Würfeln: dadurch entstehen
## Gruppen, dichte Bestände, Lichtungen und ausgedünnte Waldränder.
func _place_nature() -> void:
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			if _is_occupied(x, y):
				continue
			var t := map.get_tile(x, y)
			if t == MapData.Tile.PATH or t == MapData.Tile.COBBLE or map.is_water(x, y):
				continue
			if _touches_water(x, y):
				if _rng.randf() < 0.38:
					_spawn("reeds" if _rng.randf() < 0.6 else "cattail", x, y, 5.0)
				continue

			var dens := _n01(_density, x, y)
			var clear := _n01(_clearing, x, y)
			var factor := 0.20 + 1.75 * dens * dens
			if clear > 0.68:
				factor *= 0.10          # Lichtung
			elif clear > 0.60:
				factor *= 0.40          # ausgedünnter Rand
			_populate(x, y, t, factor)

func _populate(x: int, y: int, t: int, factor: float) -> void:
	var conifer := _n01(_species, x, y) > 0.52
	var tree_chance := 0.0
	var under_chance := 0.0
	match t:
		MapData.Tile.FOREST:
			tree_chance = 0.42
			under_chance = 0.30
		MapData.Tile.GRASS:
			tree_chance = 0.050
			under_chance = 0.100
		MapData.Tile.MEADOW:
			tree_chance = 0.020
			under_chance = 0.095
		MapData.Tile.ROCK:
			tree_chance = 0.030
			under_chance = 0.230
		MapData.Tile.SAND:
			under_chance = 0.030

	if _rng.randf() < tree_chance * factor:
		_spawn(_tree_name(t, conifer), x, y, 6.0)
		# In dichten Beständen darf ein zweiter Baum dazukommen
		if t == MapData.Tile.FOREST and factor > 1.2 and _rng.randf() < 0.30:
			_spawn(_tree_name(t, conifer), x, y, 6.5)
		return
	if _rng.randf() < under_chance * factor:
		_spawn(_undergrowth(t), x, y, 5.0)

func _tree_name(t: int, conifer: bool) -> String:
	if t == MapData.Tile.ROCK:
		return "pine_small" if _rng.randf() < 0.6 else "pine"
	if t == MapData.Tile.FOREST:
		if conifer:
			return "pine" if _rng.randf() < 0.72 else "pine_small"
		var r := _rng.randf()
		if r < 0.34:
			return "oak"
		elif r < 0.56:
			return "oak_dark"
		elif r < 0.68:
			return "oak_autumn"
		elif r < 0.80:
			return "birch"
		elif r < 0.90:
			return "oak_small"
		return "old_tree"
	# Offenes Land: einzelne, große Bäume wirken am besten
	var r2 := _rng.randf()
	if r2 < 0.40:
		return "oak"
	elif r2 < 0.58:
		return "old_tree"
	elif r2 < 0.74:
		return "birch"
	elif r2 < 0.88:
		return "pine"
	return "oak_small"

func _undergrowth(t: int) -> String:
	match t:
		MapData.Tile.FOREST:
			var r := _rng.randf()
			if r < 0.34:
				return "bush"
			elif r < 0.58:
				return "fern"
			elif r < 0.74:
				return "sapling"
			elif r < 0.86:
				return "stump"
			elif r < 0.94:
				return "log"
			return "rock_small"
		MapData.Tile.ROCK:
			return "rock_big" if _rng.randf() < 0.42 else "rock_small"
		MapData.Tile.SAND:
			return "rock_small"
	var r2 := _rng.randf()
	if r2 < 0.42:
		return "bush"
	elif r2 < 0.62:
		return "sapling"
	elif r2 < 0.78:
		return "fern"
	elif r2 < 0.90:
		return "rock_small"
	return "stump"

func _spawn(name: String, x: int, y: int, jitter: float) -> void:
	var off := Vector2(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter * 0.6, jitter * 0.6))
	_add(name, _tile_center(x, y) + Vector2(0, T * 0.35) + off)
	_occupy(x, y)

func _touches_water(x: int, y: int) -> bool:
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.is_water(x + o.x, y + o.y):
			return true
	return false

# --- Boden und Auflagen ------------------------------------------------------

## Welche Kacheln zu welcher Schicht des Bodenstapels gehören.
## Sand liegt unter allem Land, Gras darüber (ausser auf Sand) — dadurch
## entsteht der Strandsaum von selbst, ohne Sonderfälle in der Karte.
func cells_for(pos: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			if GroundTileSet.in_layer(pos, map.get_tile(x, y)):
				out.append(Vector2i(x, y))
	return out

## Helligkeitsstufe und Variante je Kachel, einmal vorberechnet. Ein Byte je
## Kachel ist deutlich billiger als ein Callable-Aufruf pro Kachel und Schicht.
func variant_map() -> PackedByteArray:
	if not _variants.is_empty():
		return _variants
	_variants.resize(Config.MAP_W * Config.MAP_H)
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			# Nur weiches Rauschen, kein Zufall pro Kachel: einzelne abweichende
			# Kacheln fallen bei 32 Pixeln sofort als Schachbrett auf.
			var shade := clampi(int(_n01(_shade, x, y) * TileArt.SHADES), 0, TileArt.SHADES - 1)
			_variants[y * Config.MAP_W + x] = shade * TileArt.VARIANTS + (x * 7 + y * 13) % TileArt.VARIANTS
	return _variants

## Bestimmt je Kachel, welche Dekorationskachel dort liegt (oder -1).
## Die Dekoration ist damit Teil des Rasters statt einer gebackenen Textur:
## das spart bei 32er-Kacheln eine 3072x2304-Auflage und rund 0,8 Sekunden.
func decor_map() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(Config.MAP_W * Config.MAP_H)
	out.fill(-1)
	if Config.EMPTY_WORLD:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.seed + 5
	for y in Config.MAP_H:
		for x in Config.MAP_W:
			var t := map.get_tile(x, y)
			var set_name := ""
			var chance := 0.0
			match t:
				MapData.Tile.GRASS:
					set_name = "grass"
					chance = 0.44
				MapData.Tile.MEADOW:
					set_name = "grass"
					chance = 0.88
				MapData.Tile.FOREST:
					set_name = "forest"
					chance = 0.52
				MapData.Tile.SAND:
					set_name = "sand"
					chance = 0.24
				MapData.Tile.PATH:
					# Gras wächst über den Wegrand
					if _borders_grass(x, y):
						set_name = "edge"
						chance = 0.55
					else:
						set_name = "path"
						chance = 0.05
				MapData.Tile.WATER:
					set_name = "water"
					chance = 0.05
			if set_name == "" or rng.randf() > chance:
				continue
			var range_of: Vector2i = ground.decor_ranges[set_name]
			out[y * Config.MAP_W + x] = range_of.x + rng.randi() % range_of.y
	return out

func _borders_grass(x: int, y: int) -> bool:
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var t := map.get_tile(x + o.x, y + o.y)
		if t == MapData.Tile.GRASS or t == MapData.Tile.MEADOW or t == MapData.Tile.FOREST:
			return true
	return false

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
		var e: Dictionary = PropArt.variant(props, p["name"], p["variant"])
		var foot: Vector2 = e["foot"]
		if foot == Vector2.ZERO:
			continue
		var pos: Vector2 = p["pos"]
		collision_rects.append(Rect2(pos.x - foot.x, pos.y - foot.y * 2.0, foot.x * 2.0, foot.y * 2.0))
