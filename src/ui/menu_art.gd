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

	# Sonne
	Pixel.circle(img, 232, 58, 15.0, Color8(255, 238, 196))
	Pixel.circle(img, 232, 58, 11.0, Color8(255, 250, 226))

	# Wolken
	for i in 5:
		var cx := rng.randf_range(10, W - 10)
		var cy := rng.randf_range(16, 66)
		var c := Color(1, 1, 1, rng.randf_range(0.35, 0.6))
		for b in 4:
			Pixel.ellipse(img, cx + b * rng.randf_range(5, 9) - 12.0, cy + rng.randf_range(-2, 2),
				rng.randf_range(6, 11), rng.randf_range(3, 5), c)

	# Ferne Hügelschichten
	_hills(img, 108, 10.0, 0.045, Color8(108, 148, 150), rng)
	_hills(img, 124, 8.0, 0.07, Color8(74, 122, 110), rng)
	_hills(img, 142, 7.0, 0.10, Palette.PINE, rng)

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
		var y := rng.randi_range(156, H - 4)
		var c: Color = [Palette.FLOWER_RED, Palette.FLOWER_YELLOW, Palette.FLOWER_WHITE][rng.randi() % 3]
		Pixel.px(img, x, y, c)
		Pixel.px(img, x, y + 1, Palette.GRASS_DARK)
	return Pixel.tex(img)

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
