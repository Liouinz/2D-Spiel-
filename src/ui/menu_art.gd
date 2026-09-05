class_name MenuArt
extends RefCounted
## Hintergrundbild des Hauptmenüs — dieselbe Palette wie die Spielwelt.

const W := 320
const H := 180

static func title_background() -> ImageTexture:
	var img := Pixel.make(W, H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	# Himmel: Abendverlauf
	var top := Color8(96, 150, 200)
	var bottom := Color8(246, 206, 158)
	for y in H:
		var t := clampf(float(y) / (H * 0.72), 0.0, 1.0)
		Pixel.hline(img, 0, y, W, top.lerp(bottom, t * t))

	# Abendsonne mit weichem Hof
	Pixel.circle(img, 232, 58, 26.0, Color(1.0, 0.85, 0.55, 0.10))
	Pixel.circle(img, 232, 58, 20.0, Color(1.0, 0.87, 0.58, 0.16))
	Pixel.circle(img, 232, 58, 15.0, Color8(255, 214, 142))
	Pixel.circle(img, 232, 58, 12.0, Color8(255, 234, 176))
	Pixel.circle(img, 232, 58, 8.0, Color8(255, 250, 224))

	# Wolken
	for i in 3:
		var cx := rng.randf_range(10, W - 10)
		var cy := rng.randf_range(16, 66)
		var c := Color(1, 1, 1, rng.randf_range(0.35, 0.6))
		for b in 4:
			Pixel.ellipse(img, cx + b * rng.randf_range(5, 9) - 12.0, cy + rng.randf_range(-2, 2),
				rng.randf_range(6, 11), rng.randf_range(3, 5), c)

	# Ferne Hügelschichten mit Dunstschleiern dazwischen — das gibt Tiefe
	_hills(img, 104, 11.0, 0.038, Color8(132, 166, 172), rng)
	_mist(img, 100, 12, 0.16)
	_hills(img, 116, 9.0, 0.052, Color8(102, 144, 148), rng)
	_mist(img, 113, 10, 0.11)
	_hills(img, 128, 8.0, 0.070, Color8(72, 120, 110), rng)
	_mist(img, 126, 8, 0.07)
	_hills(img, 144, 7.0, 0.100, Palette.PINE, rng)

	# Vogelschwarm
	for i in 6:
		_bird(img, rng.randf_range(30, W - 30), rng.randf_range(24, 62), rng)

	# Baumsilhouetten auf dem vorderen Hügel
	for i in 26:
		var x := rng.randf_range(-4, W + 4)
		var base := 142.0 + sin(x * 0.10) * 7.0 + 3.0
		_tree_silhouette(img, x, base, rng.randf_range(9, 17), Palette.PINE_DARK)

	# Vordergrund: Wiese
	for y in range(152, H):
		var t := float(y - 152) / float(H - 152)
		Pixel.hline(img, 0, y, W, Palette.GRASS.lerp(Palette.GRASS_DARK, t))
	for i in 260:
		var x := rng.randi_range(0, W - 1)
		var y := rng.randi_range(152, H - 1)
		Pixel.px(img, x, y, Palette.GRASS_LIGHT if rng.randf() < 0.6 else Palette.GRASS_HI)
	for i in 34:
		var x := rng.randi_range(2, W - 3)
		var y := rng.randi_range(156, H - 6)
		var c: Color = [Palette.FLOWER_RED, Palette.FLOWER_YELLOW, Palette.FLOWER_WHITE][rng.randi() % 3]
		Pixel.px(img, x, y, c)
		Pixel.px(img, x, y + 1, Palette.GRASS_DARK)

	# Vordergrund: einzelne Halme am unteren Bildrand, dunkel gegen die Wiese
	for i in 150:
		var x := rng.randi_range(0, W - 1)
		var hgt := rng.randi_range(3, 9)
		var lean := rng.randi_range(-1, 1)
		for s in hgt:
			Pixel.px(img, x + int(float(s) / hgt * lean), H - 1 - s, Palette.GRASS_DARK.darkened(0.25))
	return Pixel.tex(img)

## Waagerechter Dunstschleier — trennt die Hügelschichten voneinander.
static func _mist(img: Image, y: int, height: int, strength: float) -> void:
	for i in height:
		var a := strength * (1.0 - float(i) / height)
		Pixel.hline(img, 0, y + i, W, Color(1.0, 0.96, 0.90, a))

static func _bird(img: Image, x: float, y: float, rng: RandomNumberGenerator) -> void:
	var s := rng.randi_range(1, 2)
	var c := Color(0.16, 0.18, 0.24, 0.72)
	for i in s + 1:
		Pixel.px(img, int(x - 1 - i), int(y - i), c)
		Pixel.px(img, int(x + 1 + i), int(y - i), c)
	Pixel.px(img, int(x), int(y), c)

static func _hills(img: Image, base: int, amp: float, freq: float, c: Color, rng: RandomNumberGenerator) -> void:
	var off := rng.randf_range(0.0, 10.0)
	for x in W:
		var y := int(base + sin((x + off) * freq) * amp + sin((x + off) * freq * 2.7) * amp * 0.35)
		Pixel.rect(img, x, y, 1, H - y, c)

static func _tree_silhouette(img: Image, x: float, base: float, h: float, c: Color) -> void:
	Pixel.rect(img, int(x), int(base - 2.0), 1, 3, c)
	var tiers := 3
	for i in tiers:
		var ty := base - 2.0 - h * (float(i) / tiers)
		var half := (h * 0.32) * (1.0 - float(i) / (tiers + 0.6))
		Pixel.triangle(img, x - half, ty, x + half, ty, x, ty - h * 0.42, c)

# --- Pixel-Art-Rahmen für die Menüs -----------------------------------------

const FRAME := 32
const MARGIN := 10

## Holzrahmen für Schaltflächen. `state`: 0 normal, 1 überfahren, 2 gedrückt.
static func button_frame(state: int) -> ImageTexture:
	var img := Pixel.make(FRAME, FRAME)
	var body := Color8(74, 56, 42)
	var bevel := Color8(112, 86, 60)
	var border := Palette.UI_BORDER
	if state == 1:
		body = Color8(98, 74, 48)
		bevel = Color8(146, 114, 74)
		border = Palette.UI_BORDER_HI
	elif state == 2:
		body = Color8(52, 40, 32)
		bevel = Color8(74, 56, 42)
		border = Palette.UI_BORDER

	Pixel.rect(img, 0, 0, FRAME, FRAME, body)
	# Maserung
	for y in range(3, FRAME - 3, 4):
		Pixel.hline(img, 2, y, FRAME - 4, body.darkened(0.12))
	# Fase: Licht oben links, Schatten unten rechts
	Pixel.hline(img, 1, 1, FRAME - 2, bevel if state != 2 else body.darkened(0.2))
	Pixel.vline(img, 1, 1, FRAME - 2, bevel if state != 2 else body.darkened(0.2))
	Pixel.hline(img, 1, FRAME - 2, FRAME - 2, body.darkened(0.25) if state != 2 else bevel)
	Pixel.vline(img, FRAME - 2, 1, FRAME - 2, body.darkened(0.25) if state != 2 else bevel)
	# Außenkante
	Pixel.hline(img, 0, 0, FRAME, border)
	Pixel.hline(img, 0, FRAME - 1, FRAME, border)
	Pixel.vline(img, 0, 0, FRAME, border)
	Pixel.vline(img, FRAME - 1, 0, FRAME, border)
	# Nieten in den Ecken
	for p: Vector2i in [Vector2i(3, 3), Vector2i(FRAME - 4, 3), Vector2i(3, FRAME - 4), Vector2i(FRAME - 4, FRAME - 4)]:
		Pixel.px(img, p.x, p.y, Palette.UI_BORDER_HI)
		Pixel.px(img, p.x, p.y + 1, Palette.UI_BG_DEEP)
	return Pixel.tex(img)

## Dunkle Tafel mit Holzrahmen für Pause- und Optionsfenster.
static func panel_frame() -> ImageTexture:
	var img := Pixel.make(FRAME, FRAME)
	Pixel.rect(img, 0, 0, FRAME, FRAME, Palette.UI_BG)
	Pixel.rect(img, 0, 0, FRAME, 4, Palette.UI_BORDER)
	Pixel.rect(img, 0, FRAME - 4, FRAME, 4, Palette.UI_BORDER)
	Pixel.rect(img, 0, 0, 4, FRAME, Palette.UI_BORDER)
	Pixel.rect(img, FRAME - 4, 0, 4, FRAME, Palette.UI_BORDER)
	Pixel.hline(img, 0, 0, FRAME, Palette.UI_BORDER_HI)
	Pixel.vline(img, 0, 0, FRAME, Palette.UI_BORDER_HI)
	Pixel.hline(img, 0, FRAME - 1, FRAME, Palette.UI_BG_DEEP)
	Pixel.vline(img, FRAME - 1, 0, FRAME, Palette.UI_BG_DEEP)
	Pixel.rect(img, 4, 4, FRAME - 8, 1, Palette.UI_BG_DEEP)
	Pixel.rect(img, 4, 4, 1, FRAME - 8, Palette.UI_BG_DEEP)
	for p: Vector2i in [Vector2i(1, 1), Vector2i(FRAME - 3, 1), Vector2i(1, FRAME - 3), Vector2i(FRAME - 3, FRAME - 3)]:
		Pixel.rect(img, p.x, p.y, 2, 2, Palette.UI_BORDER_HI)
	return Pixel.tex(img)

## Wolkenband, das im Hauptmenü langsam vorbeizieht.
static func cloud_band(width: int, height: int) -> ImageTexture:
	var img := Pixel.make(width, height)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for i in 4:
		var cx := rng.randf_range(10, width - 10)
		var cy := rng.randf_range(8, height - 10)
		var a := rng.randf_range(0.20, 0.36)
		for b in 5:
			Pixel.ellipse(img, cx + (b - 2) * rng.randf_range(5, 9), cy + rng.randf_range(-2, 2),
				rng.randf_range(6, 12), rng.randf_range(3, 5), Color(1, 1, 1, a))
	return Pixel.tex(img)
