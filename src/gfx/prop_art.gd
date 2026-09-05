class_name PropArt
extends RefCounted
## Erzeugt alle Objekt-Grafiken. Jede Art hat mehrere Varianten, damit kein
## Baum und kein Haus wie eine Kopie des Nachbarn aussieht.
##
## Aufbau eines Eintrags:  name -> { "variants": [ variante, ... ] }
## Eine Variante:          { "tex", "size", "foot", "shadow" }
##   foot   = halbe Ausdehnung der Kollision am Boden (0 = begehbar)
##   shadow = Radien des eingebackenen Bodenschattens (0 = kein Schatten)

## Licht kommt aus der oberen linken Ecke — für ALLE Objekte gleich.
const LIGHT := Vector2(-0.55, -0.8)

static func build(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 91
	var d := {}

	# --- Laubbäume ---------------------------------------------------------
	var green := [Palette.LEAF_HI, Palette.LEAF_LIGHT, Palette.LEAF, Palette.LEAF_DARK, Palette.LEAF_DEEP]
	var deep_green := [Palette.LEAF_LIGHT, Palette.LEAF, Palette.LEAF_DARK, Palette.LEAF_DEEP, Palette.PINE_DEEP]
	var autumn := [Palette.AUTUMN_HI, Palette.AUTUMN_LIGHT, Palette.AUTUMN, Palette.AUTUMN_DARK, Palette.AUTUMN_DEEP]

	d["oak"] = _entry(_series(rng, 4, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 38, 48, green, 5, 1.0)))
	d["oak_dark"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 36, 46, deep_green, 5, 0.95)))
	d["oak_autumn"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 36, 46, autumn, 5, 0.95)))
	d["oak_small"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 26, 32, green, 4, 0.72)))
	d["birch"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 32, 42, green, 5, 0.86, true)))
	d["old_tree"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 46, 52, deep_green, 6, 1.25)))
	d["sapling"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _sapling(r)))

	# --- Nadelbäume --------------------------------------------------------
	d["pine"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _conifer(r, 30, 54, 5)))
	d["pine_small"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _conifer(r, 22, 36, 4)))

	# --- Unterholz und Steine ---------------------------------------------
	d["bush"] = _entry(_series(rng, 4, func(r: RandomNumberGenerator) -> Dictionary:
		return _bush(r)))
	d["fern"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _fern(r)))
	d["rock_big"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _rock(r, 28, 22)))
	d["rock_small"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _rock(r, 15, 12)))

	# --- Gebäude und Dorf ---------------------------------------------------
	_add_buildings(d, rng)

	d["well"] = _entry([_well()])
	d["fence_h"] = _entry([_fence(true)])
	d["fence_v"] = _entry([_fence(false)])
	d["barrel"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary: return _barrel(r)))
	d["crate"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary: return _crate(r)))
	d["sign"] = _entry([_sign()])
	d["bench"] = _entry([_bench()])
	d["lantern"] = _entry([_lantern()])
	d["woodpile"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary: return _woodpile(r)))
	d["planter"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary: return _planter(r)))
	d["stump"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary: return _stump(r)))
	d["log"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary: return _log(r)))
	d["reeds"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary: return _reeds(r)))
	d["cattail"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary: return _cattail(r)))
	return d

# --- Gerüst ------------------------------------------------------------------

## Ruft `maker` n-mal auf und sammelt die Varianten ein.
static func _series(rng: RandomNumberGenerator, n: int, maker: Callable) -> Array:
	var out: Array = []
	for i in n:
		out.append(maker.call(rng))
	return out

static func _entry(variants: Array) -> Dictionary:
	return {"variants": variants}

static func _variant(img: Image, foot: Vector2, shadow: Vector2) -> Dictionary:
	return {
		"tex": Pixel.tex(img),
		"size": Vector2(img.get_width(), img.get_height()),
		"foot": foot,
		"shadow": shadow,
	}

## Wählt eine Variante zufällig aus.
static func pick(props: Dictionary, name: String, rng: RandomNumberGenerator) -> int:
	var list: Array = props[name]["variants"]
	return rng.randi() % list.size()

static func variant(props: Dictionary, name: String, index: int) -> Dictionary:
	var list: Array = props[name]["variants"]
	return list[index % list.size()]

# --- Bäume -------------------------------------------------------------------

## Zeichnet einen Stamm mit Wurzelanlauf, Rindenstruktur und leichter Neigung.
static func _trunk(img: Image, base_x: float, base_y: float, top_y: float, width: float,
		lean: float, rng: RandomNumberGenerator, birch: bool) -> void:
	var deep := Palette.BIRCH_SHADE.darkened(0.18) if birch else Palette.BARK_DEEP
	var dark := Palette.BIRCH_SHADE if birch else Palette.BARK_DARK
	var mid := Palette.BIRCH.darkened(0.06) if birch else Palette.BARK
	var light := Palette.BIRCH if birch else Palette.BARK_LIGHT
	var height := base_y - top_y
	for i in int(height) + 1:
		var t := float(i) / maxf(height, 1.0)
		var y := base_y - i
		# Wurzelanlauf: unten breiter
		var w := width + (1.0 - t) * (1.0 - t) * 3.2
		var cx := base_x + lean * t * t
		var x0 := int(round(cx - w * 0.5))
		var iw := maxi(int(round(w)), 2)
		Pixel.rect(img, x0, int(y), iw, 1, mid)
		Pixel.px(img, x0, int(y), dark)
		Pixel.px(img, x0 + iw - 1, int(y), deep)
		if iw > 3:
			Pixel.px(img, x0 + 1, int(y), light)
	# Rindenzeichnung: bei der Birke waagerechte Striche, sonst senkrechte Maserung
	if birch:
		for i in int(height * 0.40):
			var y := int(base_y - rng.randf() * height * 0.95)
			var t := (base_y - y) / maxf(height, 1.0)
			var cx := base_x + lean * t * t
			var len := rng.randi_range(2, 3)
			var x := int(cx - width * 0.5) + rng.randi_range(0, 2)
			Pixel.rect(img, x, y, len, 1, Palette.BARK_DEEP)
	else:
		for i in int(height * 0.5):
			var y := int(base_y - rng.randf() * height)
			var t := (base_y - y) / maxf(height, 1.0)
			var cx := base_x + lean * t * t
			Pixel.px(img, int(cx + rng.randf_range(-width * 0.4, width * 0.4)), y, dark)

static func _deciduous(rng: RandomNumberGenerator, w: int, h: int, ramp: Array,
		blob_count: int, scale: float, birch: bool = false) -> Dictionary:
	var img := Pixel.make(w, h)
	var trunk_w := (5.0 if not birch else 3.0) * scale
	var lean := rng.randf_range(-2.5, 2.5)
	# Die Birke bekommt eine tiefer sitzende, größere Krone — sonst wirkt der
	# helle Stamm wie ein Pfahl mit einem Blattball obendrauf.
	var crown_cy := h * (rng.randf_range(0.32, 0.40) if birch else rng.randf_range(0.30, 0.38))
	var crown_bottom := h * (rng.randf_range(0.70, 0.78) if birch else rng.randf_range(0.62, 0.70))
	_trunk(img, w * 0.5, h - 1.0, crown_bottom - 2.0, trunk_w, lean, rng, birch)

	# Krone aus überlappenden Ballen, danach Kerben in die Silhouette
	var cx := w * 0.5 + lean
	var rx := w * 0.5 - 2.0
	var ry := (crown_bottom - crown_cy * 0.35) * 0.5
	var mid: Color = ramp[2]
	for i in blob_count:
		var a := TAU * float(i) / blob_count + rng.randf_range(-0.3, 0.3)
		var bx := cx + cos(a) * rx * rng.randf_range(0.30, 0.52)
		var by := crown_cy + sin(a) * ry * rng.randf_range(0.30, 0.55)
		Pixel.ellipse(img, bx, by, rx * rng.randf_range(0.48, 0.66), ry * rng.randf_range(0.52, 0.72), mid)
	Pixel.ellipse(img, cx, crown_cy, rx * 0.62, ry * 0.72, mid)
	Pixel.notch(img, rng, blob_count + 4, cx, crown_cy, rx, ry)

	# Licht von oben links, Verlauf über die ganze Krone
	var light := Vector2(cx + LIGHT.x * rx, crown_cy + LIGHT.y * ry)
	Pixel.shade_ramp(img, ramp, light, maxf(rx, ry) * 2.15)
	# Der Stamm darf nicht mitschattiert werden -> nachträglich neu zeichnen
	_trunk(img, w * 0.5, h - 1.0, crown_bottom - 2.0, trunk_w, lean, rng, birch)
	# Blattbüschel: Streulichter oben links, Tiefen unten rechts
	Pixel.speckle_opaque(img, rng, int(w * 0.7), ramp[0], 0, int(crown_cy))
	Pixel.speckle_opaque(img, rng, int(w * 0.5), ramp[4], int(crown_cy), int(crown_bottom))
	Pixel.outline(img, Palette.OUTLINE)

	var foot := Vector2(maxf(trunk_w * 0.9, 4.0), 4.0)
	var shadow := Vector2(rx * 0.62, rx * 0.28)
	return _variant(img, foot, shadow)

static func _conifer(rng: RandomNumberGenerator, w: int, h: int, tiers: int) -> Dictionary:
	var img := Pixel.make(w, h)
	var cx := w * 0.5
	var base := h - 1.0
	var trunk_top := h * 0.30
	_trunk(img, cx, base, h * 0.62, 3.4, 0.0, rng, false)

	var ramp := [Palette.PINE_HI, Palette.PINE_LIGHT, Palette.PINE, Palette.PINE_DARK, Palette.PINE_DEEP]
	var top := h * rng.randf_range(0.03, 0.09)
	var bottom := h * rng.randf_range(0.72, 0.80)
	for i in tiers:
		var t := float(i) / float(tiers - 1)
		var y := lerpf(bottom, top + h * 0.16, t)
		var half := lerpf(w * 0.48, w * 0.14, t) * rng.randf_range(0.92, 1.06)
		var tip := y - h * lerpf(0.24, 0.16, t)
		Pixel.triangle(img, cx - half, y, cx + half, y, cx, tip, Palette.PINE)
		# gezackte Unterkante statt gerader Linie
		var steps := int(half * 2.0)
		for s in steps:
			var sx := cx - half + s
			if rng.randf() < 0.5:
				Pixel.vline(img, int(sx), int(y), rng.randi_range(1, 2), Palette.PINE)
	Pixel.triangle(img, cx - w * 0.13, top + h * 0.20, cx + w * 0.13, top + h * 0.20, cx, top, Palette.PINE)

	var light := Vector2(cx + LIGHT.x * w * 0.5, top + h * 0.15)
	Pixel.shade_ramp(img, ramp, light, h * 0.95)
	_trunk(img, cx, base, h * 0.62, 3.4, 0.0, rng, false)
	Pixel.speckle_opaque(img, rng, int(h * 0.4), Palette.PINE_DEEP, int(h * 0.35), int(bottom))
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(4.0, 4.0), Vector2(w * 0.34, w * 0.15))

static func _sapling(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(20, 28)
	var lean := rng.randf_range(-1.5, 1.5)
	_trunk(img, 10.0, 27.0, 15.0, 2.4, lean, rng, false)
	var ramp := [Palette.LEAF_HI, Palette.LEAF_LIGHT, Palette.LEAF, Palette.LEAF_DARK, Palette.LEAF_DEEP]
	var cx := 10.0 + lean
	for i in 3:
		var a := TAU * float(i) / 3.0 + rng.randf()
		Pixel.ellipse(img, cx + cos(a) * 3.2, 11.0 + sin(a) * 2.8, rng.randf_range(4.0, 5.5), rng.randf_range(3.5, 4.8), Palette.LEAF)
	Pixel.notch(img, rng, 4, cx, 11.0, 7.0, 6.0)
	Pixel.shade_ramp(img, ramp, Vector2(cx - 3.5, 6.0), 15.0)
	_trunk(img, 10.0, 27.0, 15.0, 2.4, lean, rng, false)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(3.0, 3.0), Vector2(5.0, 2.4))

static func _bush(rng: RandomNumberGenerator) -> Dictionary:
	var w := rng.randi_range(18, 24)
	var h := rng.randi_range(14, 18)
	var img := Pixel.make(w, h)
	var ramp := [Palette.LEAF_HI, Palette.LEAF_LIGHT, Palette.LEAF, Palette.LEAF_DARK, Palette.LEAF_DEEP]
	for i in 4:
		var a := TAU * float(i) / 4.0 + rng.randf_range(-0.4, 0.4)
		Pixel.ellipse(img, w * 0.5 + cos(a) * w * 0.20, h * 0.58 + sin(a) * h * 0.18,
			w * rng.randf_range(0.26, 0.34), h * rng.randf_range(0.30, 0.40), Palette.LEAF)
	Pixel.notch(img, rng, 5, w * 0.5, h * 0.58, w * 0.5, h * 0.42)
	Pixel.shade_ramp(img, ramp, Vector2(w * 0.24, h * 0.16), w * 0.95)
	if rng.randf() < 0.55:
		for i in rng.randi_range(2, 4):
			Pixel.px(img, rng.randi_range(3, w - 4), rng.randi_range(3, h - 4),
				Palette.FLOWER_RED if rng.randf() < 0.6 else Palette.FLOWER_WHITE)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(w * 0.32, 3.0), Vector2(w * 0.36, 2.6))

static func _fern(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(24, 20)
	var count := rng.randi_range(7, 9)
	for i in count:
		var a := lerpf(-2.75, -0.35, float(i) / float(count - 1)) + rng.randf_range(-0.12, 0.12)
		var length := rng.randf_range(9.0, 13.0)
		var mid := Palette.LEAF_LIGHT if i % 2 == 0 else Palette.LEAF
		var prev := Vector2(12.0, 19.0)
		for s in int(length):
			var t := float(s) / length
			# Wedel biegen sich nach außen und hängen an der Spitze ab
			var ang := a + t * 0.55 * signf(cos(a))
			var p := prev + Vector2(cos(ang), sin(ang) * 0.85)
			Pixel.px(img, int(p.x), int(p.y), mid)
			# Fiederblättchen
			if s >= 2 and s % 2 == 0:
				var side := Vector2(-sin(ang), cos(ang)) * (1.0 - t) * 2.6
				Pixel.px(img, int(p.x + side.x), int(p.y + side.y), Palette.LEAF_DARK)
				Pixel.px(img, int(p.x - side.x), int(p.y - side.y), mid)
			prev = p
	Pixel.outline(img, Color(Palette.OUTLINE.r, Palette.OUTLINE.g, Palette.OUTLINE.b, 0.5))
	return _variant(img, Vector2.ZERO, Vector2(6.0, 2.2))

# --- Felsen ------------------------------------------------------------------

static func _rock(rng: RandomNumberGenerator, w: int, h: int) -> Dictionary:
	var img := Pixel.make(w, h)
	var cx := w * 0.5
	var cy := h * 0.56
	var ramp := [
		Palette.STONE_LIGHT.lightened(0.16), Palette.STONE_LIGHT, Palette.STONE,
		Palette.STONE_DARK, Palette.STONE_DARK.darkened(0.34),
	]
	for i in rng.randi_range(2, 4):
		Pixel.ellipse(img, cx + rng.randf_range(-w * 0.18, w * 0.18), cy + rng.randf_range(-h * 0.12, h * 0.12),
			w * rng.randf_range(0.30, 0.44), h * rng.randf_range(0.30, 0.42), Palette.STONE)
	Pixel.notch(img, rng, 4, cx, cy, w * 0.46, h * 0.44)
	Pixel.shade_ramp(img, ramp, Vector2(cx - w * 0.30, cy - h * 0.46), w * 0.70)
	# Obere Facette: eine klare helle Fläche macht aus dem Klecks einen Stein
	Pixel.triangle(img, cx - w * 0.30, cy - h * 0.16, cx + w * 0.14, cy - h * 0.30,
		cx - w * 0.06, cy - h * 0.42, Palette.STONE_LIGHT.lightened(0.10))
	# Dunkler Fuß
	for x in range(int(cx - w * 0.5), int(cx + w * 0.5)):
		for y in range(int(cy + h * 0.16), h):
			if img.get_pixel(clampi(x, 0, w - 1), clampi(y, 0, h - 1)).a > 0.0:
				Pixel.px(img, x, y, Color(0, 0, 0, 0.16))
	# Risse
	for i in rng.randi_range(1, 3):
		var x := rng.randi_range(int(w * 0.3), int(w * 0.7))
		var y := rng.randi_range(int(h * 0.35), int(h * 0.7))
		for s in rng.randi_range(2, 4):
			Pixel.px(img, x + (s % 2), y + s, Palette.STONE_DARK.darkened(0.35))
	if rng.randf() < 0.4:
		Pixel.ellipse(img, cx + rng.randf_range(-3, 3), cy - h * 0.28, w * 0.14, h * 0.10, Palette.LEAF_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(w * 0.40, 4.0), Vector2(w * 0.46, h * 0.20))

# --- Gebäude -----------------------------------------------------------------

## Alle Haustypen. Jeder Typ hat mehrere Varianten mit anderem Wandmaterial,
## anderem Dach und anderer Fensterzahl.
static func _add_buildings(d: Dictionary, rng: RandomNumberGenerator) -> void:
	var types := {
		"house_small": [
			{"w": 46, "wall_h": 24, "roof_h": 26, "wall": "timber", "roof": "tile", "windows": 2},
			{"w": 44, "wall_h": 22, "roof_h": 24, "wall": "plaster", "roof": "thatch", "windows": 2},
			{"w": 48, "wall_h": 24, "roof_h": 26, "wall": "plank", "roof": "slate", "windows": 1},
		],
		"house_big": [
			{"w": 64, "wall_h": 28, "roof_h": 32, "wall": "timber", "roof": "tile", "windows": 3, "chimney": true},
			{"w": 62, "wall_h": 30, "roof_h": 30, "wall": "plaster", "roof": "slate", "windows": 3, "chimney": true},
			{"w": 66, "wall_h": 28, "roof_h": 34, "wall": "stone", "roof": "tile", "windows": 2, "chimney": true},
		],
		"farmhouse": [
			{"w": 74, "wall_h": 26, "roof_h": 30, "wall": "timber", "roof": "thatch", "windows": 3, "chimney": true},
			{"w": 70, "wall_h": 28, "roof_h": 32, "wall": "plank", "roof": "thatch", "windows": 2, "chimney": true},
		],
		"barn": [
			{"w": 80, "wall_h": 32, "roof_h": 34, "wall": "plank", "roof": "slate", "windows": 0, "big_door": true},
			{"w": 76, "wall_h": 30, "roof_h": 36, "wall": "plank", "roof": "thatch", "windows": 1, "big_door": true},
		],
		"workshop": [
			{"w": 54, "wall_h": 26, "roof_h": 24, "wall": "plank", "roof": "slate", "windows": 2, "awning": true},
			{"w": 52, "wall_h": 24, "roof_h": 26, "wall": "timber", "roof": "tile", "windows": 2, "awning": true},
		],
		"inn": [
			{"w": 70, "wall_h": 42, "roof_h": 32, "wall": "timber", "roof": "tile", "windows": 3,
				"rows": 2, "chimney": true, "sign": true},
		],
		"smithy": [
			{"w": 56, "wall_h": 28, "roof_h": 26, "wall": "stone", "roof": "slate", "windows": 1,
				"chimney": true, "big_chimney": true, "awning": true},
		],
		"shed": [
			{"w": 34, "wall_h": 20, "roof_h": 18, "wall": "plank", "roof": "thatch", "windows": 1},
			{"w": 32, "wall_h": 18, "roof_h": 18, "wall": "plank", "roof": "slate", "windows": 0},
		],
	}
	for name: String in types:
		var variants: Array = []
		for cfg: Dictionary in types[name]:
			variants.append(_building(rng, cfg))
		d[name] = _entry(variants)

static func _wall_colors(kind: String) -> Array:
	match kind:
		"plaster":
			return [Palette.PLASTER_WARM, Palette.PLASTER_WARM_SHADE]
		"timber":
			return [Palette.PLASTER_COOL, Palette.PLASTER_COOL_SHADE]
		"plank":
			return [Palette.PLANK, Palette.PLANK_SHADE]
		_:
			return [Palette.MASONRY, Palette.MASONRY_SHADE]

static func _roof_ramp(kind: String) -> Array:
	match kind:
		"slate":
			return [Palette.SLATE_LIGHT, Palette.SLATE, Palette.SLATE_DARK, Palette.SLATE_DEEP]
		"thatch":
			return [Palette.THATCH_LIGHT, Palette.THATCH, Palette.THATCH_DARK, Palette.THATCH_DEEP]
		_:
			return [Palette.ROOF_LIGHT, Palette.ROOF, Palette.ROOF_DARK, Palette.ROOF_DEEP]

static func _building(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var w: int = cfg["w"]
	var wall_h: int = cfg["wall_h"]
	var roof_h: int = cfg["roof_h"]
	var wall_kind: String = cfg["wall"]
	var roof_kind: String = cfg["roof"]
	var rows: int = int(cfg.get("rows", 1))
	var over := 5
	var total_w := w + over * 2
	var chimney_h := 14 if bool(cfg.get("big_chimney", false)) else 10
	var top_pad := chimney_h if bool(cfg.get("chimney", false)) else 0
	var img := Pixel.make(total_w, top_pad + roof_h + wall_h + 3)
	var x0 := over
	var wall_y := top_pad + roof_h

	if bool(cfg.get("chimney", false)):
		_chimney(img, x0 + w - (20 if bool(cfg.get("big_chimney", false)) else 15),
			top_pad - chimney_h + 2, chimney_h + roof_h / 2, bool(cfg.get("big_chimney", false)))

	_wall(img, rng, x0, wall_y, w, wall_h, wall_kind)
	_wall_openings(img, rng, x0, wall_y, w, wall_h, cfg, rows)
	_roof(img, rng, total_w, top_pad, roof_h, roof_kind)

	# Traufschatten: das Dach wirft einen Schatten auf die Wand darunter
	for y in range(wall_y, mini(wall_y + 4, img.get_height())):
		var a := 0.34 - (y - wall_y) * 0.08
		Pixel.rect(img, x0, y, w, 1, Color(0, 0, 0, a))

	if bool(cfg.get("awning", false)):
		_awning(img, x0, wall_y + wall_h - 16, w)
	if bool(cfg.get("sign", false)):
		_hanging_sign(img, x0 + w - 12, wall_y + 6)

	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(w * 0.5, wall_h * 0.5), Vector2(w * 0.52, wall_h * 0.24))

static func _wall(img: Image, rng: RandomNumberGenerator, x0: int, y0: int, w: int, h: int, kind: String) -> void:
	var cols := _wall_colors(kind)
	var base: Color = cols[0]
	var shade: Color = cols[1]
	Pixel.rect(img, x0, y0, w, h, base)
	# Licht von links: rechte Wandhälfte etwas dunkler
	for x in range(x0 + int(w * 0.62), x0 + w):
		var t := float(x - (x0 + w * 0.62)) / maxf(w * 0.38, 1.0)
		if t > Pixel.bayer(x, 0):
			Pixel.vline(img, x, y0, h, base.lerp(shade, 0.55))
	# Sockel
	Pixel.rect(img, x0, y0 + h - 4, w, 4, shade)
	Pixel.rect(img, x0, y0 + h - 2, w, 2, Palette.STONE_DARK)

	match kind:
		"plaster":
			for i in int(w * h * 0.05):
				Pixel.px(img, rng.randi_range(x0, x0 + w - 1), rng.randi_range(y0, y0 + h - 5),
					base.darkened(0.06))
		"timber":
			# Fachwerk: Ständer, Riegel und Streben
			for i in range(0, 5):
				var bx := x0 + int(w * i / 4.0)
				Pixel.vline(img, mini(bx, x0 + w - 2), y0, h - 4, Palette.WOOD_DARK)
				Pixel.vline(img, mini(bx + 1, x0 + w - 1), y0, h - 4, Palette.WOOD)
			Pixel.rect(img, x0, y0, w, 2, Palette.WOOD_DARK)
			Pixel.rect(img, x0, y0 + int(h * 0.55), w, 2, Palette.WOOD_DARK)
			for i in 2:
				var bx := x0 + int(w * (0.12 + i * 0.62))
				for s in int(h * 0.4):
					Pixel.px(img, bx + s, y0 + int(h * 0.55) - s, Palette.WOOD_DARK)
		"plank":
			for y in range(y0, y0 + h - 4, 4):
				Pixel.rect(img, x0, y, w, 1, shade.darkened(0.15))
				Pixel.rect(img, x0, y + 1, w, 1, base.lightened(0.08))
			for i in int(w * 0.25):
				Pixel.px(img, rng.randi_range(x0, x0 + w - 1), rng.randi_range(y0, y0 + h - 5), shade)
		_:
			# Bruchstein: versetzte Quader
			var y := y0
			var row := 0
			while y < y0 + h - 4:
				var x := x0 - (3 if row % 2 == 1 else 0)
				while x < x0 + w:
					var bw := rng.randi_range(6, 10)
					var col := base.lerp(shade, rng.randf_range(0.0, 0.5))
					Pixel.rect(img, maxi(x, x0), y, mini(bw, x0 + w - maxi(x, x0)), 4, col)
					Pixel.rect(img, maxi(x, x0), y, mini(bw, x0 + w - maxi(x, x0)), 1, col.lightened(0.12))
					x += bw + 1
				y += 5
				row += 1

static func _wall_openings(img: Image, rng: RandomNumberGenerator, x0: int, y0: int, w: int, h: int,
		cfg: Dictionary, rows: int) -> void:
	var count: int = int(cfg["windows"])
	var big_door: bool = bool(cfg.get("big_door", false))
	var door_w := 18 if big_door else 10
	var door_h := 20 if big_door else 15
	var door_x := x0 + w / 2 - door_w / 2
	_door(img, door_x, y0 + h - door_h - 2, door_w, door_h, big_door)

	# Fenster im Erdgeschoss links und rechts der Tür verteilen
	var row_h := (h - 4) / rows
	for r in rows:
		var wy := y0 + 5 + r * row_h
		var n := count if r == 0 else maxi(count, 2)
		for i in n:
			var slot := float(i + 1) / float(n + 1)
			var wx := x0 + int(w * slot) - 4
			if r == 0 and absi(wx + 4 - (door_x + door_w / 2)) < door_w / 2 + 7:
				continue
			_window(img, rng, wx, wy, r == 0)

static func _window(img: Image, rng: RandomNumberGenerator, x: int, y: int, shutters: bool) -> void:
	# Rahmen
	Pixel.rect(img, x - 1, y - 1, 10, 11, Palette.WOOD_DARK)
	# Glas mit Verlauf von oben links nach unten rechts
	for gy in 9:
		for gx in 8:
			var t := (gx / 8.0 + gy / 9.0) * 0.5
			var c := Palette.GLASS_HI.lerp(Palette.GLASS_DARK, clampf(t * 1.4, 0.0, 1.0))
			Pixel.px(img, x + gx, y + gy, c)
	# Spiegelung
	for i in 4:
		Pixel.px(img, x + 1 + i, y + 4 - i, Palette.GLASS_HI)
		Pixel.px(img, x + 2 + i, y + 4 - i, Palette.GLASS_HI)
	# Sprossen
	Pixel.vline(img, x + 3, y, 9, Palette.WOOD_DARK)
	Pixel.rect(img, x, y + 4, 8, 1, Palette.WOOD_DARK)
	# Fensterbank
	Pixel.rect(img, x - 2, y + 10, 12, 2, Palette.WOOD_LIGHT)
	Pixel.rect(img, x - 2, y + 12, 12, 1, Palette.WOOD_DARK)
	if shutters and rng.randf() < 0.5:
		Pixel.rect(img, x - 4, y - 1, 3, 11, Palette.WOOD)
		Pixel.rect(img, x + 9, y - 1, 3, 11, Palette.WOOD_DARK)

static func _door(img: Image, x: int, y: int, w: int, h: int, big: bool) -> void:
	Pixel.rect(img, x - 1, y - 1, w + 2, h + 1, Palette.WOOD_DARK)
	Pixel.rect(img, x, y, w, h, Palette.WOOD)
	for i in range(1, w, 3):
		Pixel.vline(img, x + i, y, h, Palette.WOOD_DARK.lerp(Palette.WOOD, 0.4))
	Pixel.rect(img, x, y, w, 1, Palette.WOOD_LIGHT)
	if big:
		# Scheunentor: Diagonalstreben
		for s in mini(w, h):
			Pixel.px(img, x + s, y + h - 1 - s, Palette.WOOD_LIGHT)
			Pixel.px(img, x + w - 1 - s, y + h - 1 - s, Palette.WOOD_LIGHT)
		Pixel.vline(img, x + w / 2, y, h, Palette.WOOD_DARK)
	else:
		Pixel.px(img, x + w - 3, y + h / 2, Palette.UI_ACCENT)
		Pixel.px(img, x + w - 3, y + h / 2 + 1, Palette.WOOD_DARK)
	# Trittstein
	Pixel.rect(img, x - 2, y + h, w + 4, 2, Palette.STONE)
	Pixel.rect(img, x - 2, y + h + 1, w + 4, 1, Palette.STONE_DARK)

static func _roof(img: Image, rng: RandomNumberGenerator, total_w: int, y0: int, roof_h: int, kind: String) -> void:
	var ramp := _roof_ramp(kind)
	var mid: Color = ramp[1]
	var dark: Color = ramp[2]
	var light: Color = ramp[0]
	var ridge_half := 6.0
	# Dachfläche
	for i in roof_h:
		var t := float(i) / float(roof_h)
		var half := lerpf(ridge_half, total_w * 0.5, pow(t, 0.72))
		Pixel.hline(img, int(total_w * 0.5 - half), y0 + i, int(half * 2.0), mid)

	if kind == "thatch":
		# Reet: senkrechte Halme statt Ziegelreihen
		for x in total_w:
			var col := mid.lerp(light, rng.randf_range(0.0, 0.7))
			for i in roof_h:
				var t := float(i) / float(roof_h)
				var half := lerpf(ridge_half, total_w * 0.5, pow(t, 0.72))
				if absf(x - total_w * 0.5) <= half:
					Pixel.px(img, x, y0 + i, col if (i + x) % 7 != 0 else dark)
		Pixel.hline(img, int(total_w * 0.5 - ridge_half), y0, int(ridge_half * 2.0), light)
	else:
		# Ziegel-/Schieferreihen mit einzeln erkennbaren Steinen
		var row := 0
		var y := y0 + 2
		while y < y0 + roof_h:
			var t := float(y - y0) / float(roof_h)
			var half := lerpf(ridge_half, total_w * 0.5, pow(t, 0.72))
			var x := int(total_w * 0.5 - half) - (2 if row % 2 == 1 else 0)
			while x < total_w * 0.5 + half:
				var sw := rng.randi_range(4, 6)
				var c := mid.lerp(light, rng.randf_range(0.0, 0.45))
				for sx in sw:
					var px_x := x + sx
					if absf(px_x - total_w * 0.5) > half:
						continue
					Pixel.px(img, px_x, y, c)
					Pixel.px(img, px_x, y + 1, c.lerp(dark, 0.35))
				Pixel.px(img, x + sw, y, dark)
				Pixel.px(img, x + sw, y + 1, dark)
				x += sw + 1
			Pixel.hline(img, int(total_w * 0.5 - half), y - 1, int(half * 2.0), dark)
			y += 3
			row += 1

	# Licht von oben links — ausdrücklich NUR auf der Dachfläche
	Pixel.shade_ramp(img, ramp, Vector2(total_w * 0.30, y0 - roof_h * 0.25), total_w * 1.05,
		Rect2i(0, y0, total_w, roof_h))
	# Firstbalken und Traufkante
	Pixel.hline(img, int(total_w * 0.5 - ridge_half), y0, int(ridge_half * 2.0), light)
	Pixel.hline(img, int(total_w * 0.5 - ridge_half), y0 + 1, int(ridge_half * 2.0), mid)
	Pixel.hline(img, 0, y0 + roof_h - 1, total_w, ramp[3])
	Pixel.hline(img, 0, y0 + roof_h - 2, total_w, dark)

static func _chimney(img: Image, x: int, y: int, h: int, big: bool) -> void:
	var w := 9 if big else 7
	Pixel.rect(img, x, y, w, h, Palette.STONE_DARK)
	Pixel.rect(img, x + 1, y + 1, w - 2, h - 1, Palette.STONE)
	for i in range(y + 2, y + h, 3):
		Pixel.rect(img, x + 1, i, w - 2, 1, Palette.STONE_DARK)
	Pixel.rect(img, x - 1, y, w + 2, 2, Palette.STONE_LIGHT)
	Pixel.rect(img, x + 1, y + 1, w - 2, 1, Color(0, 0, 0, 0.45))

static func _awning(img: Image, x: int, y: int, w: int) -> void:
	Pixel.rect(img, x + 2, y, w - 4, 4, Palette.WOOD_DARK)
	for i in range(x + 2, x + w - 4, 6):
		Pixel.rect(img, i, y, 3, 4, Palette.FLOWER_RED.darkened(0.15))
	Pixel.rect(img, x + 2, y + 4, w - 4, 1, Palette.WOOD_DARK)
	Pixel.rect(img, x + 3, y + 5, w - 6, 3, Color(0, 0, 0, 0.28))

static func _hanging_sign(img: Image, x: int, y: int) -> void:
	Pixel.rect(img, x, y, 8, 2, Palette.WOOD_DARK)
	Pixel.vline(img, x + 4, y + 2, 3, Palette.STONE_DARK)
	Pixel.rect(img, x - 1, y + 5, 11, 9, Palette.WOOD_DARK)
	Pixel.rect(img, x, y + 6, 9, 7, Palette.WOOD)
	Pixel.rect(img, x + 2, y + 8, 5, 1, Palette.UI_ACCENT)
	Pixel.rect(img, x + 2, y + 10, 3, 1, Palette.UI_ACCENT)

# --- Dorfinventar ------------------------------------------------------------

static func _well() -> Dictionary:
	var img := Pixel.make(28, 32)
	Pixel.ellipse(img, 14, 23, 11.0, 6.0, Palette.STONE_DARK)
	Pixel.ellipse(img, 14, 22.5, 10.0, 5.2, Palette.STONE)
	Pixel.ellipse(img, 14, 22, 7.5, 3.8, Palette.WATER_DEEP)
	Pixel.ellipse(img, 12.5, 21.4, 4.0, 1.8, Palette.WATER)
	Pixel.rect(img, 3, 23, 22, 5, Palette.STONE)
	Pixel.rect(img, 3, 27, 22, 2, Palette.STONE_DARK)
	for i in range(4, 24, 4):
		Pixel.vline(img, i, 23, 5, Palette.STONE_DARK)
		Pixel.px(img, i + 1, 23, Palette.STONE_LIGHT)
	Pixel.rect(img, 4, 8, 3, 16, Palette.WOOD_DARK)
	Pixel.vline(img, 4, 8, 16, Palette.WOOD)
	Pixel.rect(img, 21, 8, 3, 16, Palette.WOOD_DARK)
	Pixel.triangle(img, 0, 10, 28, 10, 14, 1, Palette.ROOF)
	Pixel.triangle(img, 0, 10, 14, 10, 14, 1, Palette.ROOF_LIGHT)
	for i in range(2, 10, 2):
		Pixel.hline(img, int(1.5 * i), i, 28 - 3 * i, Palette.ROOF_DARK)
	Pixel.rect(img, 12, 10, 4, 5, Palette.WOOD)
	Pixel.rect(img, 12, 15, 4, 3, Palette.STONE_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(11.0, 6.0), Vector2(12.0, 5.0))

static func _fence(horizontal: bool) -> Dictionary:
	var img := Pixel.make(16, 18) if horizontal else Pixel.make(10, 18)
	if horizontal:
		Pixel.rect(img, 0, 6, 16, 2, Palette.WOOD)
		Pixel.rect(img, 0, 7, 16, 1, Palette.WOOD_DARK)
		Pixel.rect(img, 0, 11, 16, 2, Palette.WOOD)
		Pixel.rect(img, 0, 12, 16, 1, Palette.WOOD_DARK)
		for bx: int in [2, 11]:
			Pixel.rect(img, bx, 3, 3, 14, Palette.WOOD_DARK)
			Pixel.vline(img, bx, 3, 14, Palette.WOOD_LIGHT)
			Pixel.px(img, bx + 1, 3, Palette.WOOD_LIGHT)
	else:
		Pixel.rect(img, 3, 0, 4, 18, Palette.WOOD_DARK)
		Pixel.vline(img, 3, 0, 18, Palette.WOOD_LIGHT)
		Pixel.rect(img, 1, 5, 8, 2, Palette.WOOD)
		Pixel.rect(img, 1, 11, 8, 2, Palette.WOOD)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(8.0, 2.0) if horizontal else Vector2(2.5, 7.0), Vector2.ZERO)

static func _barrel(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(16, 22)
	var ramp := [
		Palette.WOOD_LIGHT.lightened(0.14), Palette.WOOD_LIGHT, Palette.WOOD,
		Palette.WOOD_DARK, Palette.WOOD_DARK.darkened(0.28),
	]
	# Bauchige Silhouette
	for y in range(4, 21):
		var t := (y - 4) / 17.0
		var half := 6.0 + sin(t * PI) * 1.6
		Pixel.rect(img, int(8.0 - half), y, int(half * 2.0), 1, Palette.WOOD)
	Pixel.ellipse(img, 8, 4, 6.2, 2.6, Palette.WOOD)
	Pixel.shade_ramp(img, ramp, Vector2(3.0, 3.0), 17.0)
	# Dauben
	for x: int in [4, 8, 12]:
		Pixel.vline(img, x, 5, 15, Palette.WOOD_DARK.lerp(Palette.WOOD, 0.45))
	# Deckel
	Pixel.ellipse(img, 8, 4.2, 5.2, 2.1, Palette.WOOD_LIGHT)
	Pixel.ellipse(img, 8, 4.2, 3.2, 1.2, Palette.WOOD)
	# Eisenreifen
	for y: int in [7, 17]:
		Pixel.hline(img, 1, y, 14, Palette.STONE_DARK)
		Pixel.hline(img, 1, y + 1, 14, Palette.STONE)
	if rng.randf() < 0.5:
		Pixel.px(img, 12, 12, Palette.STONE_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(6.0, 3.0), Vector2(7.0, 3.0))

static func _crate(rng: RandomNumberGenerator) -> Dictionary:
	var s := rng.randi_range(13, 16)
	var img := Pixel.make(s, s + 2)
	var ramp := [
		Palette.WOOD_LIGHT.lightened(0.16), Palette.WOOD_LIGHT, Palette.WOOD,
		Palette.WOOD_DARK, Palette.WOOD_DARK.darkened(0.22),
	]
	Pixel.rect(img, 1, 2, s - 2, s - 2, Palette.WOOD)
	Pixel.shade_ramp(img, ramp, Vector2(2.0, 2.0), float(s) * 1.5)
	# Deckel als eigene helle Fläche
	Pixel.rect(img, 1, 2, s - 2, 3, Palette.WOOD_LIGHT)
	Pixel.rect(img, 1, 4, s - 2, 1, Palette.WOOD_DARK)
	# Bretter und Eckpfosten
	for y in range(6, s, 4):
		Pixel.hline(img, 1, y, s - 2, Palette.WOOD_DARK)
	Pixel.vline(img, 1, 2, s - 2, Palette.WOOD_DARK)
	Pixel.vline(img, s - 2, 2, s - 2, Palette.WOOD_DARK)
	Pixel.vline(img, 2, 5, s - 5, Palette.WOOD_LIGHT)
	for i in 2:
		Pixel.px(img, 2 + i * (s - 5), 6, Palette.STONE_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(s * 0.42, 4.0), Vector2(s * 0.46, 3.0))

static func _sign() -> Dictionary:
	var img := Pixel.make(16, 21)
	Pixel.rect(img, 7, 10, 3, 10, Palette.WOOD_DARK)
	Pixel.vline(img, 7, 10, 10, Palette.WOOD)
	Pixel.rect(img, 1, 3, 14, 9, Palette.WOOD_DARK)
	Pixel.rect(img, 2, 4, 12, 7, Palette.WOOD)
	Pixel.rect(img, 2, 4, 12, 1, Palette.WOOD_LIGHT)
	Pixel.hline(img, 4, 6, 8, Palette.WOOD_DARK)
	Pixel.hline(img, 4, 8, 6, Palette.WOOD_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(4.0, 2.0), Vector2(5.0, 2.0))

static func _bench() -> Dictionary:
	var img := Pixel.make(28, 20)
	# Rückenlehne
	Pixel.rect(img, 3, 2, 22, 3, Palette.WOOD)
	Pixel.rect(img, 3, 2, 22, 1, Palette.WOOD_LIGHT)
	Pixel.rect(img, 3, 4, 22, 1, Palette.WOOD_DARK)
	Pixel.rect(img, 3, 6, 22, 2, Palette.WOOD)
	Pixel.rect(img, 3, 7, 22, 1, Palette.WOOD_DARK)
	# Sitzfläche
	Pixel.rect(img, 1, 10, 26, 4, Palette.WOOD)
	Pixel.rect(img, 1, 10, 26, 1, Palette.WOOD_LIGHT)
	Pixel.rect(img, 1, 13, 26, 1, Palette.WOOD_DARK)
	# Beine und Lehnenpfosten
	for bx: int in [4, 22]:
		Pixel.rect(img, bx, 2, 2, 12, Palette.WOOD_DARK)
		Pixel.rect(img, bx, 14, 2, 5, Palette.BARK_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(12.0, 3.0), Vector2(13.0, 2.8))

static func _lantern() -> Dictionary:
	var img := Pixel.make(12, 34)
	Pixel.rect(img, 5, 8, 2, 24, Palette.STONE_DARK)
	Pixel.vline(img, 5, 8, 24, Palette.STONE)
	Pixel.ellipse(img, 6, 32, 4.0, 2.0, Palette.STONE_DARK)
	Pixel.rect(img, 3, 3, 7, 7, Palette.WOOD_DARK)
	Pixel.rect(img, 4, 4, 5, 5, Palette.UI_ACCENT)
	Pixel.rect(img, 5, 5, 3, 3, Color8(255, 244, 200))
	Pixel.triangle(img, 2, 3, 10, 3, 6, 0, Palette.STONE)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(2.5, 2.0), Vector2(4.0, 2.0))

static func _woodpile(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(28, 22)
	# Stirnseiten von Scheitholz: runde Enden, dazwischen dunkle Fugen
	for row in 3:
		var y := 18.0 - row * 5.0
		var count := 5 - row
		var x_off := 3.0 + row * 2.5
		for i in count:
			var cx := x_off + i * 5.0
			var bark := Palette.BARK.lerp(Palette.BARK_DARK, rng.randf_range(0.0, 0.6))
			Pixel.ellipse(img, cx, y, 2.8, 2.6, bark)
			Pixel.ellipse(img, cx - 0.4, y - 0.4, 1.9, 1.8, Palette.WOOD_LIGHT)
			Pixel.ellipse(img, cx - 0.4, y - 0.4, 1.0, 0.9, Palette.WOOD)
			# Jahresringe
			Pixel.px(img, int(cx), int(y) - 1, Palette.WOOD_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(12.0, 4.0), Vector2(13.0, 3.4))

static func _planter(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(18, 18)
	Pixel.rect(img, 2, 10, 14, 7, Palette.WOOD)
	Pixel.rect(img, 2, 10, 14, 1, Palette.WOOD_LIGHT)
	Pixel.rect(img, 2, 15, 14, 2, Palette.WOOD_DARK)
	Pixel.rect(img, 3, 8, 12, 3, Palette.DIRT_DARK)
	for i in rng.randi_range(4, 6):
		var x := rng.randi_range(3, 14)
		var h := rng.randi_range(3, 6)
		Pixel.vline(img, x, 9 - h, h, Palette.LEAF)
		Pixel.px(img, x, 9 - h, [Palette.FLOWER_RED, Palette.FLOWER_YELLOW, Palette.FLOWER_WHITE][rng.randi() % 3])
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(7.0, 3.0), Vector2(8.0, 2.6))

static func _stump(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(18, 15)
	Pixel.rect(img, 2, 5, 14, 9, Palette.BARK_DARK)
	Pixel.rect(img, 2, 5, 4, 9, Palette.BARK)
	Pixel.ellipse(img, 9, 5, 7.0, 3.4, Palette.BARK_LIGHT)
	Pixel.ellipse(img, 9, 5, 4.5, 2.1, Palette.WOOD_LIGHT)
	Pixel.ellipse(img, 9, 5, 2.0, 0.9, Palette.BARK)
	if rng.randf() < 0.5:
		Pixel.ellipse(img, 4, 11, 3.0, 2.0, Palette.LEAF_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(7.0, 3.0), Vector2(8.0, 3.0))

static func _log(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(26, 14)
	Pixel.rect(img, 2, 4, 22, 8, Palette.BARK)
	Pixel.rect(img, 2, 4, 22, 2, Palette.BARK_LIGHT)
	Pixel.rect(img, 2, 10, 22, 2, Palette.BARK_DEEP)
	for i in rng.randi_range(3, 5):
		Pixel.rect(img, rng.randi_range(4, 20), rng.randi_range(6, 9), 3, 1, Palette.BARK_DARK)
	Pixel.ellipse(img, 3, 8, 2.6, 4.0, Palette.BARK_LIGHT)
	Pixel.ellipse(img, 3, 8, 1.3, 2.0, Palette.WOOD_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(11.0, 3.0), Vector2(12.0, 3.0))

static func _reeds(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(16, 22)
	for i in rng.randi_range(6, 9):
		var x := rng.randi_range(2, 13)
		var h := rng.randi_range(9, 19)
		var c := Palette.LEAF_LIGHT if i % 2 == 0 else Palette.LEAF
		var bend := rng.randi_range(-1, 1)
		for s in h:
			Pixel.px(img, x + int(float(s) / h * bend * 2.0), 21 - s, c)
		Pixel.px(img, x + bend, 21 - h, Palette.LEAF_DARK)
	return _variant(img, Vector2.ZERO, Vector2.ZERO)

static func _cattail(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(14, 24)
	for i in rng.randi_range(2, 4):
		var x := 3 + i * 3
		var h := rng.randi_range(14, 22)
		Pixel.vline(img, x, 23 - h, h, Palette.LEAF)
		Pixel.rect(img, x - 1, 23 - h, 3, 5, Palette.BARK_DARK)
		Pixel.px(img, x - 1, 24 - h, Palette.BARK)
	Pixel.outline(img, Color(Palette.OUTLINE.r, Palette.OUTLINE.g, Palette.OUTLINE.b, 0.5))
	return _variant(img, Vector2.ZERO, Vector2.ZERO)
