class_name PropArt
extends RefCounted
## Erzeugt alle Objekt-Grafiken (Bäume, Felsen, Häuser, Deko).
## Jede Requisite liefert Textur, Fußabdruck (Kollision) und Schattengröße.

## Baut ein Wörterbuch: name -> {tex, size, foot, shadow}
static func build(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 91
	var d := {}
	d["oak"] = _entry(_oak(rng, Palette.LEAF, Palette.LEAF_LIGHT, Palette.LEAF_DARK), Vector2(7, 4), Vector2(11, 5))
	d["oak2"] = _entry(_oak(rng, Palette.LEAF_DARK, Palette.LEAF, Palette.PINE_DARK), Vector2(7, 4), Vector2(11, 5))
	d["pine"] = _entry(_pine(rng), Vector2(6, 4), Vector2(9, 4))
	d["sapling"] = _entry(_sapling(rng), Vector2(4, 3), Vector2(6, 3))
	d["bush"] = _entry(_bush(rng), Vector2(7, 4), Vector2(8, 3))
	d["rock_big"] = _entry(_rock(rng, 26, 20), Vector2(11, 5), Vector2(12, 4))
	d["rock_small"] = _entry(_rock(rng, 14, 11), Vector2(6, 3), Vector2(7, 3))
	d["house_big"] = _entry(_house(64, 26, 30, true), Vector2(30, 10), Vector2(32, 8))
	d["house_small"] = _entry(_house(48, 22, 24, false), Vector2(22, 8), Vector2(24, 7))
	d["well"] = _entry(_well(), Vector2(11, 6), Vector2(12, 5))
	d["fence_h"] = _entry(_fence(true), Vector2(8, 2), Vector2.ZERO)
	d["fence_v"] = _entry(_fence(false), Vector2(2, 7), Vector2.ZERO)
	d["barrel"] = _entry(_barrel(), Vector2(5, 3), Vector2(6, 3))
	d["crate"] = _entry(_crate(), Vector2(6, 4), Vector2(7, 3))
	d["sign"] = _entry(_sign(), Vector2(5, 2), Vector2(6, 2))
	d["stump"] = _entry(_stump(), Vector2(6, 3), Vector2(7, 3))
	d["log"] = _entry(_log(), Vector2(10, 3), Vector2(11, 3))
	d["reeds"] = _entry(_reeds(rng), Vector2.ZERO, Vector2.ZERO)
	d["cattail"] = _entry(_cattail(rng), Vector2.ZERO, Vector2.ZERO)
	return d

static func _entry(img: Image, foot: Vector2, shadow: Vector2) -> Dictionary:
	return {
		"tex": Pixel.tex(img),
		"size": Vector2(img.get_width(), img.get_height()),
		"foot": foot,
		"shadow": shadow,
	}

# --- Bäume -------------------------------------------------------------------

static func _oak(rng: RandomNumberGenerator, mid: Color, light: Color, dark: Color) -> Image:
	var w := 34
	var h := 44
	var img := Pixel.make(w, h)
	# Stamm
	Pixel.rect(img, 15, 28, 5, 15, Palette.WOOD_DARK)
	Pixel.rect(img, 16, 28, 3, 15, Palette.WOOD)
	Pixel.px(img, 16, 34, Palette.WOOD_LIGHT)
	Pixel.px(img, 18, 38, Palette.WOOD_DARK)
	# Krone aus überlappenden Ballen
	var blobs := [
		Vector2(17, 16), Vector2(9, 20), Vector2(25, 20), Vector2(13, 11), Vector2(22, 12), Vector2(17, 24),
	]
	for i in blobs.size():
		var b: Vector2 = blobs[i]
		Pixel.circle(img, b.x, b.y, rng.randf_range(7.0, 9.0), mid)
	for i in blobs.size():
		var b: Vector2 = blobs[i]
		Pixel.circle(img, b.x - 1.5, b.y - 2.0, rng.randf_range(3.5, 5.0), light)
	Pixel.ellipse(img, 20.0, 25.0, 9.0, 5.0, Color(dark.r, dark.g, dark.b, 0.55))
	for i in 26:
		Pixel.px(img, rng.randi_range(3, w - 4), rng.randi_range(4, 28), Color(dark.r, dark.g, dark.b, 0.4))
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _pine(rng: RandomNumberGenerator) -> Image:
	var w := 28
	var h := 46
	var img := Pixel.make(w, h)
	Pixel.rect(img, 12, 34, 4, 11, Palette.WOOD_DARK)
	Pixel.rect(img, 13, 34, 2, 11, Palette.WOOD)
	var tiers := [
		{"y": 38.0, "half": 13.0, "top": 24.0},
		{"y": 30.0, "half": 11.0, "top": 16.0},
		{"y": 22.0, "half": 8.5, "top": 8.0},
		{"y": 14.0, "half": 6.0, "top": 1.0},
	]
	for t: Dictionary in tiers:
		var y: float = t["y"]
		var half: float = t["half"]
		Pixel.triangle(img, 14.0 - half, y, 14.0 + half, y, 14.0, t["top"], Palette.PINE)
		Pixel.triangle(img, 14.0 - half * 0.55, y - 1.0, 14.0, y - 1.0, 14.0 - half * 0.2, t["top"] + 2.0, Palette.PINE_LIGHT)
		Pixel.triangle(img, 14.0 + half * 0.3, y, 14.0 + half, y, 14.0 + half * 0.25, t["top"] + 3.0, Palette.PINE_DARK)
	for i in 18:
		Pixel.px(img, rng.randi_range(3, w - 4), rng.randi_range(4, 38), Color(Palette.PINE_DARK.r, Palette.PINE_DARK.g, Palette.PINE_DARK.b, 0.35))
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _sapling(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(18, 26)
	Pixel.rect(img, 8, 16, 2, 9, Palette.WOOD_DARK)
	Pixel.circle(img, 9, 11, 6.5, Palette.LEAF)
	Pixel.circle(img, 7, 9, 3.5, Palette.LEAF_LIGHT)
	Pixel.ellipse(img, 11, 14, 4.5, 3.0, Color(Palette.LEAF_DARK.r, Palette.LEAF_DARK.g, Palette.LEAF_DARK.b, 0.5))
	for i in 8:
		Pixel.px(img, rng.randi_range(3, 14), rng.randi_range(5, 16), Color(Palette.LEAF_DARK.r, Palette.LEAF_DARK.g, Palette.LEAF_DARK.b, 0.4))
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _bush(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(20, 16)
	Pixel.ellipse(img, 10, 9, 9.0, 6.0, Palette.LEAF)
	Pixel.ellipse(img, 7, 7, 5.0, 3.5, Palette.LEAF_LIGHT)
	Pixel.ellipse(img, 13, 11, 5.5, 3.0, Palette.LEAF_DARK)
	for i in 3:
		Pixel.px(img, rng.randi_range(4, 15), rng.randi_range(5, 12), Palette.FLOWER_RED)
	Pixel.outline(img, Palette.OUTLINE)
	return img

# --- Felsen ------------------------------------------------------------------

static func _rock(rng: RandomNumberGenerator, w: int, h: int) -> Image:
	var img := Pixel.make(w, h)
	var cx := w * 0.5
	var cy := h * 0.55
	Pixel.ellipse(img, cx, cy, w * 0.45, h * 0.42, Palette.STONE)
	Pixel.ellipse(img, cx - w * 0.14, cy - h * 0.18, w * 0.26, h * 0.22, Palette.STONE_LIGHT)
	Pixel.ellipse(img, cx + w * 0.16, cy + h * 0.20, w * 0.24, h * 0.18, Palette.STONE_DARK)
	for i in 3:
		var x := rng.randi_range(int(w * 0.25), int(w * 0.75))
		var y := rng.randi_range(int(h * 0.35), int(h * 0.75))
		Pixel.vline(img, x, y, rng.randi_range(2, 4), Palette.STONE_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return img

# --- Gebäude -----------------------------------------------------------------

static func _house(w: int, wall_h: int, roof_h: int, with_chimney: bool) -> Image:
	var over := 4
	var img := Pixel.make(w + over * 2, roof_h + wall_h + 4)
	var x0 := over
	var wall_y := roof_h
	# Wand
	Pixel.rect(img, x0, wall_y, w, wall_h, Palette.WALL)
	Pixel.rect(img, x0, wall_y + wall_h - 4, w, 4, Palette.WALL_SHADE)
	# Fachwerk
	for i in range(1, 4):
		Pixel.vline(img, x0 + int(w * i / 4.0), wall_y, wall_h, Palette.WOOD)
	Pixel.hline(img, x0, wall_y, w, Palette.WOOD_DARK)
	# Tür
	var dx := x0 + w / 2 - 4
	Pixel.rect(img, dx, wall_y + wall_h - 14, 8, 14, Palette.WOOD_DARK)
	Pixel.rect(img, dx + 1, wall_y + wall_h - 13, 6, 13, Palette.WOOD)
	Pixel.px(img, dx + 6, wall_y + wall_h - 7, Palette.UI_ACCENT)
	# Fenster
	for fx: int in [x0 + 6, x0 + w - 13]:
		Pixel.rect(img, fx, wall_y + 6, 7, 7, Palette.WOOD_DARK)
		Pixel.rect(img, fx + 1, wall_y + 7, 5, 5, Color8(140, 190, 214))
		Pixel.rect(img, fx + 1, wall_y + 7, 2, 2, Color8(196, 226, 240))
	# Dach
	var rw := w + over * 2
	for i in roof_h:
		var t := float(i) / float(roof_h)
		var half := lerpf(6.0, rw * 0.5, t)
		var c := Palette.ROOF if i % 4 != 3 else Palette.ROOF_DARK
		if i < roof_h * 0.35:
			c = Palette.ROOF_LIGHT if i % 4 != 3 else Palette.ROOF
		Pixel.hline(img, int(rw * 0.5 - half), i, int(half * 2.0), c)
	Pixel.hline(img, int(rw * 0.5) - 5, 0, 10, Palette.ROOF_LIGHT)
	if with_chimney:
		Pixel.rect(img, x0 + w - 18, 2, 7, 10, Palette.STONE_DARK)
		Pixel.rect(img, x0 + w - 17, 3, 5, 9, Palette.STONE)
		Pixel.rect(img, x0 + w - 18, 1, 7, 2, Palette.STONE_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _well() -> Image:
	var img := Pixel.make(26, 30)
	# Brunnenschacht
	Pixel.ellipse(img, 13, 22, 10.0, 5.5, Palette.STONE)
	Pixel.ellipse(img, 13, 21, 7.5, 3.8, Palette.WATER_DEEP)
	Pixel.ellipse(img, 12, 20.5, 4.0, 1.8, Palette.WATER)
	Pixel.rect(img, 3, 22, 20, 5, Palette.STONE)
	Pixel.rect(img, 3, 26, 20, 2, Palette.STONE_DARK)
	for i in range(4, 22, 4):
		Pixel.vline(img, i, 22, 5, Palette.STONE_DARK)
	# Pfosten und Dach
	Pixel.rect(img, 4, 8, 2, 15, Palette.WOOD_DARK)
	Pixel.rect(img, 20, 8, 2, 15, Palette.WOOD_DARK)
	Pixel.triangle(img, 1, 9, 25, 9, 13, 1, Palette.ROOF)
	Pixel.triangle(img, 1, 9, 13, 9, 13, 1, Palette.ROOF_LIGHT)
	Pixel.rect(img, 12, 9, 2, 6, Palette.WOOD)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _fence(horizontal: bool) -> Image:
	var img := Pixel.make(16, 18) if horizontal else Pixel.make(10, 18)
	if horizontal:
		Pixel.rect(img, 1, 6, 14, 2, Palette.WOOD)
		Pixel.rect(img, 1, 11, 14, 2, Palette.WOOD)
		Pixel.rect(img, 2, 3, 3, 14, Palette.WOOD_DARK)
		Pixel.rect(img, 11, 3, 3, 14, Palette.WOOD_DARK)
		Pixel.vline(img, 2, 3, 14, Palette.WOOD_LIGHT)
		Pixel.vline(img, 11, 3, 14, Palette.WOOD_LIGHT)
	else:
		Pixel.rect(img, 3, 0, 4, 18, Palette.WOOD_DARK)
		Pixel.vline(img, 3, 0, 18, Palette.WOOD_LIGHT)
		Pixel.rect(img, 1, 5, 8, 2, Palette.WOOD)
		Pixel.rect(img, 1, 11, 8, 2, Palette.WOOD)
	Pixel.outline(img, Palette.OUTLINE)
	return img

# --- Kleinkram ---------------------------------------------------------------

static func _barrel() -> Image:
	var img := Pixel.make(12, 17)
	Pixel.rect(img, 1, 3, 10, 13, Palette.WOOD)
	Pixel.rect(img, 1, 3, 3, 13, Palette.WOOD_LIGHT)
	Pixel.rect(img, 8, 3, 3, 13, Palette.WOOD_DARK)
	Pixel.hline(img, 1, 6, 10, Palette.STONE_DARK)
	Pixel.hline(img, 1, 12, 10, Palette.STONE_DARK)
	Pixel.ellipse(img, 6, 3, 5.0, 2.2, Palette.WOOD_LIGHT)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _crate() -> Image:
	var img := Pixel.make(14, 15)
	Pixel.rect(img, 1, 2, 12, 12, Palette.WOOD)
	Pixel.rect(img, 1, 2, 12, 2, Palette.WOOD_LIGHT)
	Pixel.rect(img, 1, 12, 12, 2, Palette.WOOD_DARK)
	Pixel.hline(img, 1, 8, 12, Palette.WOOD_DARK)
	Pixel.vline(img, 7, 2, 12, Palette.WOOD_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _sign() -> Image:
	var img := Pixel.make(14, 19)
	Pixel.rect(img, 6, 9, 2, 9, Palette.WOOD_DARK)
	Pixel.rect(img, 1, 3, 12, 8, Palette.WOOD)
	Pixel.rect(img, 1, 3, 12, 2, Palette.WOOD_LIGHT)
	Pixel.hline(img, 3, 6, 8, Palette.WOOD_DARK)
	Pixel.hline(img, 3, 8, 6, Palette.WOOD_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _stump() -> Image:
	var img := Pixel.make(16, 13)
	Pixel.rect(img, 2, 4, 12, 8, Palette.WOOD_DARK)
	Pixel.ellipse(img, 8, 4, 6.0, 3.0, Palette.WOOD_LIGHT)
	Pixel.ellipse(img, 8, 4, 3.0, 1.5, Palette.WOOD)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _log() -> Image:
	var img := Pixel.make(24, 13)
	Pixel.rect(img, 2, 4, 20, 7, Palette.WOOD)
	Pixel.rect(img, 2, 4, 20, 2, Palette.WOOD_LIGHT)
	Pixel.rect(img, 2, 9, 20, 2, Palette.WOOD_DARK)
	Pixel.ellipse(img, 3, 7.5, 2.4, 3.6, Palette.WOOD_LIGHT)
	Pixel.ellipse(img, 3, 7.5, 1.1, 1.7, Palette.WOOD_DARK)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _reeds(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(14, 20)
	for i in 7:
		var x := rng.randi_range(2, 11)
		var h := rng.randi_range(9, 17)
		var c := Palette.LEAF_LIGHT if i % 2 == 0 else Palette.LEAF
		Pixel.vline(img, x, 19 - h, h, c)
		Pixel.px(img, x + (1 if i % 2 == 0 else -1), 19 - h, c)
	return img

static func _cattail(rng: RandomNumberGenerator) -> Image:
	var img := Pixel.make(12, 22)
	for i in 3:
		var x := 3 + i * 3
		var h := rng.randi_range(13, 20)
		Pixel.vline(img, x, 21 - h, h, Palette.LEAF)
		Pixel.rect(img, x - 1, 21 - h, 3, 4, Palette.WOOD_DARK)
	Pixel.outline(img, Color(Palette.OUTLINE.r, Palette.OUTLINE.g, Palette.OUTLINE.b, 0.5))
	return img
