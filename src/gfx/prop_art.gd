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
		return _deciduous(r, 76, 96, green, 6, 2.0)))
	d["oak_dark"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 72, 92, deep_green, 6, 1.9)))
	d["oak_autumn"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 72, 92, autumn, 6, 1.9)))
	d["oak_small"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 52, 64, green, 5, 1.44)))
	d["birch"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 68, 80, green, 7, 1.8, true)))
	d["old_tree"] = _entry(_series(rng, 2, func(r: RandomNumberGenerator) -> Dictionary:
		return _deciduous(r, 92, 104, deep_green, 7, 2.5)))
	d["sapling"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _sapling(r)))

	# --- Nadelbäume --------------------------------------------------------
	d["pine"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _conifer(r, 66, 96, 6)))
	d["pine_small"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _conifer(r, 50, 64, 5)))

	# --- Unterholz und Steine ---------------------------------------------
	d["bush"] = _entry(_series(rng, 4, func(r: RandomNumberGenerator) -> Dictionary:
		return _bush(r)))
	d["fern"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _fern(r)))
	d["rock_big"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _rock(r, 56, 44)))
	d["rock_small"] = _entry(_series(rng, 3, func(r: RandomNumberGenerator) -> Dictionary:
		return _rock(r, 30, 24)))

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

## Weicher Bodenschatten. Wird je Requisite skaliert statt für jede Größe
## einzeln gezeichnet — ein unscharfer Fleck verträgt das problemlos.
static func shadow_texture() -> ImageTexture:
	var img := Pixel.make(64, 32)
	Pixel.ellipse(img, 32, 16, 31.0, 15.0, Color(0, 0, 0, 0.11))
	Pixel.ellipse(img, 32, 16, 26.0, 12.5, Color(0, 0, 0, 0.17))
	Pixel.ellipse(img, 32, 16, 20.0, 9.5, Color(0, 0, 0, 0.20))
	Pixel.ellipse(img, 30, 15, 12.0, 5.5, Color(0, 0, 0, 0.14))
	return Pixel.tex(img)

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
	var trunk_w := (5.0 if not birch else 4.2) * scale
	var lean := rng.randf_range(-2.5, 2.5)
	# Die Birke bekommt eine tiefer sitzende, größere Krone — sonst wirkt der
	# helle Stamm wie ein Pfahl mit einem Blattball obendrauf.
	var crown_cy := h * (rng.randf_range(0.32, 0.40) if birch else rng.randf_range(0.30, 0.38))
	var crown_bottom := h * (rng.randf_range(0.76, 0.84) if birch else rng.randf_range(0.62, 0.70))
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
	# Stammbreite haengt an der Baumbreite. Ein fester Wert war hier der Fehler:
	# nach der Verdopplung der Aufloesung blieb ein 3-Pixel-Faden uebrig.
	var trunk_w := w * 0.115
	_trunk(img, cx, base, h * 0.62, trunk_w, 0.0, rng, false)

	var ramp := [Palette.PINE_HI, Palette.PINE_LIGHT, Palette.PINE, Palette.PINE_DARK, Palette.PINE_DEEP]
	var top := h * rng.randf_range(0.03, 0.09)
	var bottom := h * rng.randf_range(0.72, 0.80)
	for i in tiers:
		var t := float(i) / float(tiers - 1)
		var y := lerpf(bottom, top + h * 0.16, t)
		var half := lerpf(w * 0.54, w * 0.17, t) * rng.randf_range(0.92, 1.06)
		var tip := y - h * lerpf(0.30, 0.20, t)
		Pixel.triangle(img, cx - half, y, cx + half, y, cx, tip, Palette.PINE)
		# zweite, leicht versetzte Lage macht die Zweigetagen dichter
		Pixel.triangle(img, cx - half * 0.86, y - h * 0.03, cx + half * 0.86, y - h * 0.03,
			cx, tip - h * 0.02, Palette.PINE)
		# gezackte Unterkante statt gerader Linie
		var steps := int(half * 2.0)
		for s in steps:
			var sx := cx - half + s
			if rng.randf() < 0.5:
				Pixel.vline(img, int(sx), int(y), rng.randi_range(1, 2), Palette.PINE)
	Pixel.triangle(img, cx - w * 0.13, top + h * 0.20, cx + w * 0.13, top + h * 0.20, cx, top, Palette.PINE)

	var light := Vector2(cx + LIGHT.x * w * 0.5, top + h * 0.15)
	Pixel.shade_ramp(img, ramp, light, h * 0.95)
	_trunk(img, cx, base, h * 0.62, trunk_w, 0.0, rng, false)
	Pixel.speckle_opaque(img, rng, int(h * 0.4), Palette.PINE_DEEP, int(h * 0.35), int(bottom))
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(4.0, 4.0), Vector2(w * 0.34, w * 0.15))

static func _sapling(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(40, 56)
	var lean := rng.randf_range(-3.0, 3.0)
	var ramp := [Palette.LEAF_HI, Palette.LEAF_LIGHT, Palette.LEAF, Palette.LEAF_DARK, Palette.LEAF_DEEP]
	_trunk(img, 20.0, 55.0, 30.0, 4.6, lean, rng, false)
	var cx := 20.0 + lean
	for i in 4:
		var a := TAU * float(i) / 4.0 + rng.randf()
		Pixel.ellipse(img, cx + cos(a) * 6.4, 22.0 + sin(a) * 5.6,
			rng.randf_range(8.0, 11.0), rng.randf_range(7.0, 9.6), Palette.LEAF)
	Pixel.notch(img, rng, 6, cx, 22.0, 14.0, 12.0)
	Pixel.shade_ramp(img, ramp, Vector2(cx - 7.0, 12.0), 30.0)
	_trunk(img, 20.0, 55.0, 30.0, 4.6, lean, rng, false)
	Pixel.speckle_opaque(img, rng, 12, Palette.LEAF_HI, 0, 22)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(6.0, 6.0), Vector2(10.0, 4.8))

static func _bush(rng: RandomNumberGenerator) -> Dictionary:
	var w := rng.randi_range(36, 48)
	var h := rng.randi_range(28, 36)
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
	var img := Pixel.make(48, 42)
	var count := rng.randi_range(7, 9)
	for i in count:
		var a := lerpf(-2.55, -0.55, float(i) / float(count - 1)) + rng.randf_range(-0.10, 0.10)
		var length := rng.randf_range(20.0, 28.0)
		var mid := Palette.LEAF_LIGHT if i % 2 == 0 else Palette.LEAF
		var prev := Vector2(24.0, 41.0)
		for s in int(length):
			var t := float(s) / length
			# Wedel biegen sich nach außen und hängen an der Spitze ab
			var ang := a + t * 0.55 * signf(cos(a))
			var p := prev + Vector2(cos(ang), sin(ang) * 0.85)
			# Mittelstiel zwei Pixel breit, sonst verschwindet der Wedel
			Pixel.px(img, int(p.x), int(p.y), mid)
			Pixel.px(img, int(p.x), int(p.y) + 1, Palette.LEAF_DARK)
			# Fiederblättchen paarweise nach beiden Seiten
			if s >= 2 and s % 2 == 0:
				var normal := Vector2(-sin(ang), cos(ang))
				var reach := (1.0 - t * 0.7) * 5.5
				for k in 3:
					var f := (k + 1) / 3.0
					var o := normal * reach * f
					Pixel.px(img, int(p.x + o.x), int(p.y + o.y), mid if k < 2 else Palette.LEAF_DARK)
					Pixel.px(img, int(p.x - o.x), int(p.y - o.y), Palette.LEAF_LIGHT if k < 2 else mid)
			prev = p
	Pixel.outline(img, Color(Palette.OUTLINE.r, Palette.OUTLINE.g, Palette.OUTLINE.b, 0.55))
	return _variant(img, Vector2.ZERO, Vector2(13.0, 5.0))

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
			{"w": 92, "wall_h": 48, "roof_h": 52, "wall": "timber", "roof": "tile", "windows": 2},
			{"w": 88, "wall_h": 44, "roof_h": 48, "wall": "plaster", "roof": "thatch", "windows": 2},
			{"w": 96, "wall_h": 48, "roof_h": 52, "wall": "plank", "roof": "slate", "windows": 1},
		],
		"house_big": [
			{"w": 128, "wall_h": 56, "roof_h": 64, "wall": "timber", "roof": "tile", "windows": 3, "chimney": true},
			{"w": 124, "wall_h": 60, "roof_h": 60, "wall": "plaster", "roof": "slate", "windows": 3, "chimney": true},
			{"w": 132, "wall_h": 56, "roof_h": 68, "wall": "stone", "roof": "tile", "windows": 2, "chimney": true},
		],
		"farmhouse": [
			{"w": 148, "wall_h": 52, "roof_h": 60, "wall": "timber", "roof": "thatch", "windows": 3, "chimney": true},
			{"w": 140, "wall_h": 56, "roof_h": 64, "wall": "plank", "roof": "thatch", "windows": 2, "chimney": true},
		],
		"barn": [
			{"w": 160, "wall_h": 64, "roof_h": 68, "wall": "plank", "roof": "slate", "windows": 0, "big_door": true},
			{"w": 152, "wall_h": 60, "roof_h": 72, "wall": "plank", "roof": "thatch", "windows": 1, "big_door": true},
		],
		"workshop": [
			{"w": 108, "wall_h": 52, "roof_h": 48, "wall": "plank", "roof": "slate", "windows": 2, "awning": true},
			{"w": 104, "wall_h": 48, "roof_h": 52, "wall": "timber", "roof": "tile", "windows": 2, "awning": true},
		],
		"inn": [
			{"w": 140, "wall_h": 84, "roof_h": 64, "wall": "timber", "roof": "tile", "windows": 3,
				"rows": 2, "chimney": true, "sign": true},
		],
		"smithy": [
			{"w": 112, "wall_h": 56, "roof_h": 52, "wall": "stone", "roof": "slate", "windows": 1,
				"chimney": true, "big_chimney": true, "awning": true},
		],
		"shed": [
			{"w": 68, "wall_h": 40, "roof_h": 36, "wall": "plank", "roof": "thatch", "windows": 1},
			{"w": 64, "wall_h": 36, "roof_h": 36, "wall": "plank", "roof": "slate", "windows": 0},
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
	var rows: int = int(cfg.get("rows", 1))
	var big_chimney := bool(cfg.get("big_chimney", false))
	var over := 10
	var total_w := w + over * 2
	var chimney_h := 28 if big_chimney else 20
	var top_pad := chimney_h if bool(cfg.get("chimney", false)) else 0
	var img := Pixel.make(total_w, top_pad + roof_h + wall_h + 6)
	var x0 := over
	var wall_y := top_pad + roof_h

	if bool(cfg.get("chimney", false)):
		_chimney(img, x0 + w - (40 if big_chimney else 30), top_pad - chimney_h + 4,
			chimney_h + roof_h / 2, big_chimney)

	_wall(img, rng, x0, wall_y, w, wall_h, cfg["wall"])
	_wall_openings(img, rng, x0, wall_y, w, wall_h, cfg, rows)
	_roof(img, rng, total_w, top_pad, roof_h, cfg["roof"])

	# Traufschatten: das Dach wirft einen Schatten auf die Wand darunter
	for y in range(wall_y, mini(wall_y + 8, img.get_height())):
		Pixel.rect(img, x0, y, w, 1, Color(0, 0, 0, 0.34 - (y - wall_y) * 0.04))

	if bool(cfg.get("awning", false)):
		_awning(img, x0, wall_y + wall_h - 32, w)
	if bool(cfg.get("sign", false)):
		_hanging_sign(img, x0 + w - 26, wall_y + 12)

	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(w * 0.5, wall_h * 0.5), Vector2(w * 0.52, wall_h * 0.24))

static func _wall(img: Image, rng: RandomNumberGenerator, x0: int, y0: int, w: int, h: int, kind: String) -> void:
	var cols := _wall_colors(kind)
	var base: Color = cols[0]
	var shade: Color = cols[1]
	Pixel.rect(img, x0, y0, w, h, base)
	# Licht von links: rechte Wandhälfte gedithert abgedunkelt
	for x in range(x0 + int(w * 0.60), x0 + w):
		var t := float(x - (x0 + w * 0.60)) / maxf(w * 0.40, 1.0)
		if t > Pixel.bayer(x, 0):
			Pixel.vline(img, x, y0, h, base.lerp(shade, 0.55))
	# Steinsockel
	Pixel.rect(img, x0, y0 + h - 9, w, 9, shade)
	Pixel.rect(img, x0, y0 + h - 5, w, 5, Palette.MASONRY_SHADE)
	for sx in range(x0, x0 + w, 11):
		Pixel.vline(img, sx, y0 + h - 5, 5, Palette.STONE_DARK)
		Pixel.rect(img, sx, y0 + h - 5, mini(10, x0 + w - sx), 1, Palette.MASONRY)

	match kind:
		"plaster":
			for i in int(w * h * 0.04):
				Pixel.px(img, rng.randi_range(x0, x0 + w - 1), rng.randi_range(y0, y0 + h - 10),
					base.darkened(0.06))
		"timber":
			# Fachwerk: Ständer, Riegel und Streben
			for i in range(0, 5):
				var bx := mini(x0 + int(w * i / 4.0), x0 + w - 5)
				Pixel.rect(img, bx, y0, 5, h - 9, Palette.WOOD_DARK)
				Pixel.vline(img, bx, y0, h - 9, Palette.WOOD)
				Pixel.vline(img, bx + 1, y0, h - 9, Palette.WOOD_LIGHT)
			Pixel.rect(img, x0, y0, w, 5, Palette.WOOD_DARK)
			Pixel.rect(img, x0, y0, w, 1, Palette.WOOD)
			Pixel.rect(img, x0, y0 + int(h * 0.55), w, 5, Palette.WOOD_DARK)
			Pixel.rect(img, x0, y0 + int(h * 0.55), w, 1, Palette.WOOD)
			for i in 2:
				var bx2 := x0 + int(w * (0.12 + i * 0.62))
				for st in int(h * 0.4):
					Pixel.rect(img, bx2 + st, y0 + int(h * 0.55) - st, 3, 1, Palette.WOOD_DARK)
		"plank":
			for y in range(y0, y0 + h - 9, 8):
				Pixel.rect(img, x0, y, w, 1, shade.darkened(0.18))
				Pixel.rect(img, x0, y + 1, w, 2, base.lightened(0.08))
				for kx in range(x0 + rng.randi_range(4, 12), x0 + w, rng.randi_range(26, 40)):
					Pixel.px(img, kx, y + 4, shade)   # Astloch
					Pixel.px(img, kx + 1, y + 4, shade.darkened(0.2))
		_:
			# Bruchstein: versetzte Quader
			var y := y0
			var row := 0
			while y < y0 + h - 9:
				var x := x0 - (6 if row % 2 == 1 else 0)
				while x < x0 + w:
					var bw := rng.randi_range(13, 21)
					var col := base.lerp(shade, rng.randf_range(0.0, 0.5))
					var cw := mini(bw, x0 + w - maxi(x, x0))
					Pixel.rect(img, maxi(x, x0), y, cw, 8, col)
					Pixel.rect(img, maxi(x, x0), y, cw, 2, col.lightened(0.14))
					Pixel.rect(img, maxi(x, x0), y + 7, cw, 1, col.darkened(0.18))
					x += bw + 2
				y += 10
				row += 1

static func _wall_openings(img: Image, rng: RandomNumberGenerator, x0: int, y0: int, w: int, h: int,
		cfg: Dictionary, rows: int) -> void:
	var count: int = int(cfg["windows"])
	var big_door: bool = bool(cfg.get("big_door", false))
	var door_w := 36 if big_door else 22
	var door_h := 42 if big_door else 32
	var door_x := x0 + w / 2 - door_w / 2
	_door(img, door_x, y0 + h - door_h - 5, door_w, door_h, big_door)

	var row_h := (h - 10) / rows
	for r in rows:
		var wy := y0 + 11 + r * row_h
		var n := count if r == 0 else maxi(count, 2)
		for i in n:
			var slot := float(i + 1) / float(n + 1)
			var wx := x0 + int(w * slot) - 10
			if r == 0 and absi(wx + 10 - (door_x + door_w / 2)) < door_w / 2 + 16:
				continue
			_window(img, rng, wx, wy, r == 0)

## Fenster mit Rahmen, Sprossenkreuz, Glasverlauf, Spiegelung und Bank.
static func _window(img: Image, rng: RandomNumberGenerator, x: int, y: int, shutters: bool) -> void:
	Pixel.rect(img, x - 2, y - 2, 24, 26, Palette.WOOD_DARK)
	Pixel.rect(img, x - 1, y - 1, 22, 24, Palette.WOOD)
	# Glas mit Verlauf von oben links nach unten rechts
	for gy in 22:
		for gx in 20:
			var t := (gx / 20.0 + gy / 22.0) * 0.5
			Pixel.px(img, x + gx, y + gy, Palette.GLASS_HI.lerp(Palette.GLASS_DARK, clampf(t * 1.4, 0.0, 1.0)))
	# Spiegelung als Diagonalband
	for i in 9:
		Pixel.rect(img, x + 2 + i, y + 11 - i, 3, 1, Palette.GLASS_HI)
	# Sprossenkreuz
	Pixel.rect(img, x + 9, y, 2, 22, Palette.WOOD_DARK)
	Pixel.rect(img, x, y + 10, 20, 2, Palette.WOOD_DARK)
	# Fensterbank
	Pixel.rect(img, x - 4, y + 23, 28, 4, Palette.WOOD_LIGHT)
	Pixel.rect(img, x - 4, y + 26, 28, 2, Palette.WOOD_DARK)
	if shutters and rng.randf() < 0.5:
		for sx: int in [x - 9, x + 22]:
			Pixel.rect(img, sx, y - 2, 7, 26, Palette.WOOD)
			Pixel.vline(img, sx, y - 2, 26, Palette.WOOD_LIGHT)
			for ly in range(y + 1, y + 22, 4):
				Pixel.rect(img, sx + 1, ly, 5, 1, Palette.WOOD_DARK)

## Tür mit Rahmen, Brettern, Beschlägen, Griff und Trittstein.
static func _door(img: Image, x: int, y: int, w: int, h: int, big: bool) -> void:
	Pixel.rect(img, x - 3, y - 3, w + 6, h + 3, Palette.WOOD_DARK)
	Pixel.rect(img, x, y, w, h, Palette.WOOD)
	for i in range(2, w, 6):
		Pixel.vline(img, x + i, y, h, Palette.WOOD_DARK.lerp(Palette.WOOD, 0.45))
		Pixel.vline(img, x + i + 1, y, h, Palette.WOOD.lightened(0.08))
	Pixel.rect(img, x, y, w, 2, Palette.WOOD_LIGHT)
	if big:
		# Scheunentor: Diagonalstreben und Mittelfuge
		for st in mini(w, h):
			Pixel.rect(img, x + st, y + h - 2 - st, 2, 2, Palette.WOOD_LIGHT)
			Pixel.rect(img, x + w - 2 - st, y + h - 2 - st, 2, 2, Palette.WOOD_LIGHT)
		Pixel.rect(img, x + w / 2 - 1, y, 2, h, Palette.WOOD_DARK)
	else:
		# Bänder und Griff
		for by: int in [y + 6, y + h - 10]:
			Pixel.rect(img, x + 1, by, w - 2, 3, Palette.STONE_DARK)
			Pixel.rect(img, x + 1, by, w - 2, 1, Palette.STONE)
			Pixel.px(img, x + 2, by + 1, Palette.STONE_LIGHT)
		Pixel.ellipse(img, x + w - 5, y + h * 0.5, 2.2, 2.2, Palette.UI_ACCENT)
		Pixel.px(img, x + w - 6, y + int(h * 0.5) - 1, Palette.UI_ACCENT.lightened(0.3))
	# Trittstein
	Pixel.rect(img, x - 5, y + h, w + 10, 5, Palette.STONE)
	Pixel.rect(img, x - 5, y + h, w + 10, 1, Palette.STONE_LIGHT)
	Pixel.rect(img, x - 5, y + h + 3, w + 10, 2, Palette.STONE_DARK)

static func _roof(img: Image, rng: RandomNumberGenerator, total_w: int, y0: int, roof_h: int, kind: String) -> void:
	var ramp := _roof_ramp(kind)
	var mid: Color = ramp[1]
	var dark: Color = ramp[2]
	var light: Color = ramp[0]
	var ridge_half := 12.0
	for i in roof_h:
		var t := float(i) / float(roof_h)
		var half := lerpf(ridge_half, total_w * 0.5, pow(t, 0.72))
		Pixel.hline(img, int(total_w * 0.5 - half), y0 + i, int(half * 2.0), mid)

	if kind == "thatch":
		# Reet: senkrechte Halmbündel
		for x in total_w:
			var col := mid.lerp(light, rng.randf_range(0.0, 0.7))
			for i in roof_h:
				var t := float(i) / float(roof_h)
				var half := lerpf(ridge_half, total_w * 0.5, pow(t, 0.72))
				if absf(x - total_w * 0.5) <= half:
					Pixel.px(img, x, y0 + i, col if (i + x) % 11 != 0 else dark)
		# Firstwulst
		Pixel.rect(img, int(total_w * 0.5 - ridge_half), y0, int(ridge_half * 2.0), 3, light)
	else:
		# Ziegel-/Schieferreihen mit einzeln erkennbaren Steinen
		var row := 0
		var y := y0 + 4
		while y < y0 + roof_h:
			var t := float(y - y0) / float(roof_h)
			var half := lerpf(ridge_half, total_w * 0.5, pow(t, 0.72))
			var x := int(total_w * 0.5 - half) - (5 if row % 2 == 1 else 0)
			while x < total_w * 0.5 + half:
				var sw := rng.randi_range(8, 12)
				var c := mid.lerp(light, rng.randf_range(0.0, 0.45))
				for sx in sw:
					var px_x := x + sx
					if absf(px_x - total_w * 0.5) > half:
						continue
					Pixel.px(img, px_x, y, c)
					Pixel.px(img, px_x, y + 1, c)
					Pixel.px(img, px_x, y + 2, c.lerp(dark, 0.30))
					Pixel.px(img, px_x, y + 3, c.lerp(dark, 0.55))
				Pixel.rect(img, x + sw, y, 1, 4, dark)
				x += sw + 1
			Pixel.hline(img, int(total_w * 0.5 - half), y - 1, int(half * 2.0), dark)
			y += 6
			row += 1

	# Licht von oben links — ausdrücklich NUR auf der Dachfläche
	Pixel.shade_ramp(img, ramp, Vector2(total_w * 0.30, y0 - roof_h * 0.25), total_w * 1.05,
		Rect2i(0, y0, total_w, roof_h))
	# Firstbalken und Traufkante
	Pixel.rect(img, int(total_w * 0.5 - ridge_half), y0, int(ridge_half * 2.0), 2, light)
	Pixel.rect(img, int(total_w * 0.5 - ridge_half), y0 + 2, int(ridge_half * 2.0), 2, mid)
	Pixel.rect(img, 0, y0 + roof_h - 3, total_w, 3, ramp[3])
	Pixel.rect(img, 0, y0 + roof_h - 5, total_w, 2, dark)

static func _chimney(img: Image, x: int, y: int, h: int, big: bool) -> void:
	var w := 18 if big else 14
	Pixel.rect(img, x, y, w, h, Palette.STONE_DARK)
	Pixel.rect(img, x + 2, y + 2, w - 4, h - 2, Palette.STONE)
	for i in range(y + 4, y + h, 6):
		Pixel.rect(img, x + 2, i, w - 4, 1, Palette.STONE_DARK)
		Pixel.px(img, x + 3 + (i % 5), i + 2, Palette.STONE_LIGHT)
	Pixel.rect(img, x - 2, y, w + 4, 4, Palette.STONE_LIGHT)
	Pixel.rect(img, x - 2, y + 3, w + 4, 1, Palette.STONE_DARK)
	Pixel.rect(img, x + 2, y + 4, w - 4, 2, Color(0, 0, 0, 0.5))

static func _awning(img: Image, x: int, y: int, w: int) -> void:
	Pixel.rect(img, x + 4, y, w - 8, 8, Palette.WOOD_DARK)
	for i in range(x + 4, x + w - 8, 12):
		Pixel.rect(img, i, y, 6, 8, Palette.FLOWER_RED.darkened(0.15))
		Pixel.rect(img, i, y, 6, 2, Palette.FLOWER_RED)
	Pixel.rect(img, x + 4, y + 8, w - 8, 2, Palette.WOOD_DARK)
	# Zackensaum und Schatten darunter
	for i in range(x + 4, x + w - 8, 6):
		Pixel.rect(img, i, y + 10, 3, 2, Palette.WOOD_DARK)
	Pixel.rect(img, x + 6, y + 12, w - 12, 6, Color(0, 0, 0, 0.26))

static func _hanging_sign(img: Image, x: int, y: int) -> void:
	Pixel.rect(img, x, y, 18, 4, Palette.WOOD_DARK)
	Pixel.rect(img, x, y, 18, 1, Palette.WOOD)
	Pixel.vline(img, x + 8, y + 4, 6, Palette.STONE_DARK)
	Pixel.vline(img, x + 9, y + 4, 6, Palette.STONE)
	Pixel.rect(img, x - 3, y + 10, 24, 20, Palette.WOOD_DARK)
	Pixel.rect(img, x - 1, y + 12, 20, 16, Palette.WOOD)
	Pixel.rect(img, x - 1, y + 12, 20, 2, Palette.WOOD_LIGHT)
	# Krug als Wirtshauszeichen
	Pixel.rect(img, x + 4, y + 17, 8, 9, Palette.UI_ACCENT)
	Pixel.rect(img, x + 4, y + 17, 8, 2, Palette.FLOWER_WHITE)
	Pixel.rect(img, x + 12, y + 19, 3, 4, Palette.UI_ACCENT)

# --- Dorfinventar ------------------------------------------------------------

static func _well() -> Dictionary:
	var img := Pixel.make(56, 64)
	# Schacht
	Pixel.ellipse(img, 28, 46, 22.0, 12.0, Palette.STONE_DARK)
	Pixel.ellipse(img, 28, 45, 20.0, 10.4, Palette.STONE)
	Pixel.ellipse(img, 28, 44, 15.0, 7.6, Palette.WATER_DEEP)
	Pixel.ellipse(img, 25, 42.6, 8.0, 3.6, Palette.WATER)
	Pixel.ellipse(img, 23, 42.0, 3.4, 1.4, Palette.WATER_LIGHT)
	# Mauerkranz mit einzelnen Steinen
	Pixel.rect(img, 6, 46, 44, 10, Palette.STONE)
	Pixel.rect(img, 6, 54, 44, 3, Palette.STONE_DARK)
	var x := 7
	while x < 49:
		var w := 6 + (x % 3)
		Pixel.rect(img, x, 46, mini(w, 49 - x), 1, Palette.STONE_LIGHT)
		Pixel.vline(img, x, 46, 10, Palette.STONE_DARK)
		x += w + 1
	# Pfosten und Dach
	for px_x: int in [8, 44]:
		Pixel.rect(img, px_x, 16, 5, 32, Palette.WOOD_DARK)
		Pixel.vline(img, px_x, 16, 32, Palette.WOOD)
		Pixel.vline(img, px_x + 1, 16, 32, Palette.WOOD_LIGHT)
	Pixel.triangle(img, 0, 20, 56, 20, 28, 2, Palette.ROOF)
	Pixel.triangle(img, 0, 20, 28, 20, 28, 2, Palette.ROOF_LIGHT)
	for i in range(3, 20, 3):
		Pixel.hline(img, int(1.55 * i), i, 56 - 3 * i, Palette.ROOF_DARK)
	# Seilwinde und Eimer
	Pixel.rect(img, 24, 20, 8, 4, Palette.WOOD)
	Pixel.rect(img, 24, 20, 8, 1, Palette.WOOD_LIGHT)
	Pixel.vline(img, 28, 24, 8, Palette.STONE_DARK)
	Pixel.rect(img, 24, 32, 9, 8, Palette.WOOD_DARK)
	Pixel.rect(img, 25, 33, 7, 6, Palette.WOOD)
	Pixel.hline(img, 24, 35, 9, Palette.STONE_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(22.0, 12.0), Vector2(24.0, 10.0))

static func _fence(horizontal: bool) -> Dictionary:
	var img := Pixel.make(32, 36) if horizontal else Pixel.make(20, 36)
	if horizontal:
		for y: int in [12, 22]:
			Pixel.rect(img, 0, y, 32, 4, Palette.WOOD)
			Pixel.rect(img, 0, y, 32, 1, Palette.WOOD_LIGHT)
			Pixel.rect(img, 0, y + 3, 32, 1, Palette.WOOD_DARK)
		for bx: int in [4, 22]:
			Pixel.rect(img, bx, 6, 6, 28, Palette.WOOD_DARK)
			Pixel.vline(img, bx, 6, 28, Palette.WOOD_LIGHT)
			Pixel.vline(img, bx + 1, 6, 28, Palette.WOOD)
			Pixel.rect(img, bx, 6, 6, 1, Palette.WOOD_LIGHT)
			Pixel.px(img, bx + 4, 14, Palette.STONE_DARK)
			Pixel.px(img, bx + 4, 24, Palette.STONE_DARK)
	else:
		Pixel.rect(img, 6, 0, 8, 36, Palette.WOOD_DARK)
		Pixel.vline(img, 6, 0, 36, Palette.WOOD_LIGHT)
		Pixel.vline(img, 7, 0, 36, Palette.WOOD)
		for y: int in [10, 22]:
			Pixel.rect(img, 2, y, 16, 4, Palette.WOOD)
			Pixel.rect(img, 2, y, 16, 1, Palette.WOOD_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(16.0, 4.0) if horizontal else Vector2(5.0, 14.0), Vector2.ZERO)

static func _barrel(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(32, 44)
	var ramp := [
		Palette.WOOD_LIGHT.lightened(0.14), Palette.WOOD_LIGHT, Palette.WOOD,
		Palette.WOOD_DARK, Palette.WOOD_DARK.darkened(0.28),
	]
	for y in range(8, 42):
		var t := (y - 8) / 34.0
		var half := 12.0 + sin(t * PI) * 3.2
		Pixel.rect(img, int(16.0 - half), y, int(half * 2.0), 1, Palette.WOOD)
	Pixel.ellipse(img, 16, 8, 12.4, 5.2, Palette.WOOD)
	Pixel.shade_ramp(img, ramp, Vector2(6.0, 6.0), 34.0)
	# Dauben
	for dx: int in [6, 11, 16, 21, 26]:
		Pixel.vline(img, dx, 10, 30, Palette.WOOD_DARK.lerp(Palette.WOOD, 0.45))
	Pixel.ellipse(img, 16, 8.4, 10.4, 4.2, Palette.WOOD_LIGHT)
	Pixel.ellipse(img, 16, 8.4, 6.4, 2.4, Palette.WOOD)
	Pixel.ellipse(img, 13, 7.2, 3.0, 1.2, Palette.WOOD_LIGHT.lightened(0.2))
	# Eisenreifen mit Nietenreihe
	for y: int in [14, 34]:
		Pixel.hline(img, 2, y, 28, Palette.STONE_DARK)
		Pixel.hline(img, 2, y + 1, 28, Palette.STONE)
		Pixel.hline(img, 2, y + 2, 28, Palette.STONE_DARK)
		for nx in range(4, 30, 6):
			Pixel.px(img, nx, y + 1, Palette.STONE_LIGHT)
	if rng.randf() < 0.5:
		Pixel.px(img, 24, 24, Palette.STONE_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(12.0, 6.0), Vector2(14.0, 6.0))

static func _crate(rng: RandomNumberGenerator) -> Dictionary:
	var s := rng.randi_range(26, 32)
	var img := Pixel.make(s, s + 4)
	var ramp := [
		Palette.WOOD_LIGHT.lightened(0.16), Palette.WOOD_LIGHT, Palette.WOOD,
		Palette.WOOD_DARK, Palette.WOOD_DARK.darkened(0.22),
	]
	Pixel.rect(img, 2, 4, s - 4, s - 4, Palette.WOOD)
	Pixel.shade_ramp(img, ramp, Vector2(4.0, 4.0), float(s) * 1.5)
	# Deckel
	Pixel.rect(img, 2, 4, s - 4, 6, Palette.WOOD_LIGHT)
	Pixel.rect(img, 2, 9, s - 4, 2, Palette.WOOD_DARK)
	# Bretter und Eckpfosten
	for y in range(13, s, 7):
		Pixel.hline(img, 2, y, s - 4, Palette.WOOD_DARK)
		Pixel.hline(img, 2, y + 1, s - 4, Palette.WOOD_LIGHT.darkened(0.1))
	Pixel.rect(img, 2, 4, 3, s - 4, Palette.WOOD_DARK)
	Pixel.rect(img, s - 5, 4, 3, s - 4, Palette.WOOD_DARK)
	Pixel.vline(img, 3, 10, s - 11, Palette.WOOD_LIGHT)
	for i in 2:
		Pixel.px(img, 4 + i * (s - 9), 12, Palette.STONE_LIGHT)
		Pixel.px(img, 4 + i * (s - 9), s - 4, Palette.STONE_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(s * 0.42, 8.0), Vector2(s * 0.46, 6.0))

static func _sign() -> Dictionary:
	var img := Pixel.make(32, 42)
	Pixel.rect(img, 14, 20, 5, 20, Palette.WOOD_DARK)
	Pixel.vline(img, 14, 20, 20, Palette.WOOD)
	Pixel.rect(img, 2, 6, 28, 18, Palette.WOOD_DARK)
	Pixel.rect(img, 4, 8, 24, 14, Palette.WOOD)
	Pixel.rect(img, 4, 8, 24, 2, Palette.WOOD_LIGHT)
	Pixel.rect(img, 4, 21, 24, 1, Palette.WOOD_DARK)
	# angedeutete Schrift
	Pixel.hline(img, 8, 12, 16, Palette.WOOD_DARK)
	Pixel.hline(img, 8, 15, 12, Palette.WOOD_DARK)
	Pixel.hline(img, 8, 18, 14, Palette.WOOD_DARK)
	for nx: int in [5, 26]:
		Pixel.px(img, nx, 9, Palette.STONE_LIGHT)
		Pixel.px(img, nx, 21, Palette.STONE_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(8.0, 4.0), Vector2(10.0, 4.0))

static func _bench() -> Dictionary:
	var img := Pixel.make(56, 40)
	# Rückenlehne
	for y: int in [4, 12]:
		Pixel.rect(img, 6, y, 44, 5, Palette.WOOD)
		Pixel.rect(img, 6, y, 44, 1, Palette.WOOD_LIGHT)
		Pixel.rect(img, 6, y + 4, 44, 1, Palette.WOOD_DARK)
	# Sitzfläche
	Pixel.rect(img, 2, 20, 52, 7, Palette.WOOD)
	Pixel.rect(img, 2, 20, 52, 2, Palette.WOOD_LIGHT)
	Pixel.rect(img, 2, 26, 52, 1, Palette.WOOD_DARK)
	Pixel.hline(img, 2, 23, 52, Palette.WOOD_DARK.lerp(Palette.WOOD, 0.5))
	# Beine und Pfosten
	for bx: int in [8, 44]:
		Pixel.rect(img, bx, 4, 4, 24, Palette.WOOD_DARK)
		Pixel.vline(img, bx, 4, 24, Palette.WOOD)
		Pixel.rect(img, bx, 27, 4, 11, Palette.BARK_DARK)
		Pixel.vline(img, bx, 27, 11, Palette.BARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(24.0, 6.0), Vector2(26.0, 6.0))

static func _lantern() -> Dictionary:
	var img := Pixel.make(24, 68)
	# Mast
	Pixel.rect(img, 10, 18, 5, 46, Palette.STONE_DARK)
	Pixel.vline(img, 10, 18, 46, Palette.STONE)
	Pixel.vline(img, 11, 18, 46, Palette.STONE_LIGHT)
	Pixel.ellipse(img, 12, 64, 8.0, 3.6, Palette.STONE_DARK)
	Pixel.ellipse(img, 12, 63, 7.0, 2.8, Palette.STONE)
	# Laternenkorpus mit Glas
	Pixel.rect(img, 5, 6, 15, 15, Palette.WOOD_DARK)
	Pixel.rect(img, 7, 8, 11, 11, Palette.UI_ACCENT.darkened(0.2))
	Pixel.rect(img, 8, 9, 9, 9, Palette.UI_ACCENT)
	Pixel.rect(img, 9, 10, 6, 6, Color8(255, 244, 200))
	Pixel.vline(img, 12, 8, 11, Palette.WOOD_DARK)
	Pixel.hline(img, 7, 13, 11, Palette.WOOD_DARK)
	# Dach und Knauf
	Pixel.triangle(img, 3, 6, 21, 6, 12, 0, Palette.STONE)
	Pixel.triangle(img, 3, 6, 12, 6, 12, 0, Palette.STONE_LIGHT)
	Pixel.rect(img, 5, 20, 15, 2, Palette.STONE_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(5.0, 4.0), Vector2(8.0, 4.0))

static func _woodpile(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(56, 44)
	for row in 3:
		var y := 36.0 - row * 10.0
		var count := 5 - row
		var x_off := 6.0 + row * 5.0
		for i in count:
			var cx := x_off + i * 10.0
			var bark := Palette.BARK.lerp(Palette.BARK_DARK, rng.randf_range(0.0, 0.6))
			Pixel.ellipse(img, cx, y, 5.6, 5.2, bark)
			Pixel.ellipse(img, cx - 0.8, y - 0.8, 4.0, 3.6, Palette.WOOD_LIGHT)
			Pixel.ellipse(img, cx - 0.8, y - 0.8, 2.6, 2.4, Palette.WOOD)
			Pixel.ellipse(img, cx - 0.8, y - 0.8, 1.2, 1.0, Palette.WOOD_LIGHT)
			# Jahresringe
			for r in 2:
				Pixel.px(img, int(cx - 0.8), int(y - 0.8) - 2 + r * 4, Palette.WOOD_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(24.0, 8.0), Vector2(26.0, 7.0))

static func _planter(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(36, 36)
	Pixel.rect(img, 4, 20, 28, 14, Palette.WOOD)
	Pixel.rect(img, 4, 20, 28, 2, Palette.WOOD_LIGHT)
	Pixel.rect(img, 4, 31, 28, 3, Palette.WOOD_DARK)
	for bx in range(6, 32, 7):
		Pixel.vline(img, bx, 21, 12, Palette.WOOD_DARK.lerp(Palette.WOOD, 0.4))
	Pixel.rect(img, 6, 16, 24, 5, Palette.DIRT_DARK)
	Pixel.rect(img, 6, 16, 24, 1, Palette.DIRT)
	for i in rng.randi_range(6, 9):
		var x := rng.randi_range(7, 29)
		var h := rng.randi_range(6, 13)
		Pixel.vline(img, x, 17 - h, h, Palette.LEAF)
		Pixel.px(img, x, 17 - h + 1, Palette.LEAF_LIGHT)
		var c: Color = [Palette.FLOWER_RED, Palette.FLOWER_YELLOW, Palette.FLOWER_WHITE][rng.randi() % 3]
		Pixel.rect(img, x - 1, 16 - h, 3, 2, c)
		Pixel.px(img, x, 16 - h, c.lightened(0.25))
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(14.0, 6.0), Vector2(16.0, 5.0))

static func _stump(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(36, 30)
	Pixel.rect(img, 4, 10, 28, 18, Palette.BARK_DARK)
	Pixel.rect(img, 4, 10, 9, 18, Palette.BARK)
	Pixel.rect(img, 27, 10, 5, 18, Palette.BARK_DEEP)
	# Wurzelanlauf
	Pixel.ellipse(img, 6, 27, 5.0, 3.0, Palette.BARK_DARK)
	Pixel.ellipse(img, 30, 27, 5.0, 3.0, Palette.BARK_DEEP)
	# Schnittfläche mit Jahresringen
	Pixel.ellipse(img, 18, 10, 14.0, 7.0, Palette.BARK_LIGHT)
	Pixel.ellipse(img, 18, 10, 11.0, 5.4, Palette.WOOD_LIGHT)
	Pixel.ellipse(img, 18, 10, 7.0, 3.4, Palette.WOOD)
	Pixel.ellipse(img, 18, 10, 3.4, 1.6, Palette.WOOD_LIGHT)
	Pixel.ellipse(img, 18, 10, 1.4, 0.8, Palette.BARK)
	if rng.randf() < 0.5:
		Pixel.ellipse(img, 8, 22, 5.0, 3.4, Palette.LEAF_DARK)
		Pixel.ellipse(img, 7, 21, 3.0, 2.0, Palette.LEAF)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(14.0, 6.0), Vector2(16.0, 6.0))

static func _log(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(52, 28)
	Pixel.rect(img, 5, 8, 44, 16, Palette.BARK)
	Pixel.rect(img, 5, 8, 44, 4, Palette.BARK_LIGHT)
	Pixel.rect(img, 5, 21, 44, 3, Palette.BARK_DEEP)
	for i in rng.randi_range(5, 8):
		var x := rng.randi_range(9, 42)
		var y := rng.randi_range(12, 20)
		Pixel.rect(img, x, y, rng.randi_range(4, 7), 1, Palette.BARK_DARK)
	# Stirnfläche links
	Pixel.ellipse(img, 6, 16, 5.4, 8.4, Palette.BARK_LIGHT)
	Pixel.ellipse(img, 6, 16, 4.0, 6.4, Palette.WOOD_LIGHT)
	Pixel.ellipse(img, 6, 16, 2.2, 3.6, Palette.WOOD)
	Pixel.ellipse(img, 6, 16, 0.9, 1.4, Palette.WOOD_LIGHT)
	if rng.randf() < 0.5:
		Pixel.ellipse(img, 34, 10, 6.0, 3.0, Palette.LEAF_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return _variant(img, Vector2(22.0, 6.0), Vector2(24.0, 6.0))

static func _reeds(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(32, 44)
	for i in rng.randi_range(9, 13):
		var x := rng.randi_range(3, 28)
		var h := rng.randi_range(18, 38)
		var c := Palette.LEAF_LIGHT if i % 2 == 0 else Palette.LEAF
		var bend := rng.randi_range(-2, 2)
		for s in h:
			var t := float(s) / h
			Pixel.px(img, x + int(t * t * bend * 3.0), 43 - s, c)
		Pixel.px(img, x + bend * 3, 43 - h, Palette.LEAF_DARK)
		Pixel.px(img, x + bend * 3, 44 - h, c)
	return _variant(img, Vector2.ZERO, Vector2.ZERO)

static func _cattail(rng: RandomNumberGenerator) -> Dictionary:
	var img := Pixel.make(28, 48)
	for i in rng.randi_range(3, 5):
		var x := 5 + i * 5
		var h := rng.randi_range(28, 44)
		Pixel.vline(img, x, 47 - h, h, Palette.LEAF)
		Pixel.vline(img, x + 1, 47 - h, h, Palette.LEAF_DARK)
		# Kolben
		Pixel.rect(img, x - 1, 47 - h, 4, 10, Palette.BARK_DARK)
		Pixel.rect(img, x - 1, 47 - h, 1, 10, Palette.BARK)
		Pixel.rect(img, x - 1, 46 - h, 4, 1, Palette.BARK)
	Pixel.outline(img, Color(Palette.OUTLINE.r, Palette.OUTLINE.g, Palette.OUTLINE.b, 0.5))
	return _variant(img, Vector2.ZERO, Vector2.ZERO)
