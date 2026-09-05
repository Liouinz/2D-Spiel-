class_name ActorArt
extends RefCounted
## Erzeugt die Spielerfigur: 3 Blickrichtungen (unten/oben/seitlich),
## Idle-Atmen (2 Bilder) und Laufzyklus (4 Bilder). Rechts = gespiegelt links.

enum Dir { DOWN, UP, SIDE }

const W := 16
const H := 24
const EYE := Color8(46, 40, 52)

## -> {"idle": [dir][2] Texture, "walk": [dir][4] Texture, "shadow": Texture}
static func build() -> Dictionary:
	var idle: Array = []
	var walk: Array = []
	for dir in 3:
		var i_frames: Array[Texture2D] = []
		i_frames.append(Pixel.tex(_frame(dir, 0, 0, 0)))
		i_frames.append(Pixel.tex(_frame(dir, 0, 1, 0)))
		idle.append(i_frames)
		var w_frames: Array[Texture2D] = []
		var phases := [0, 1, 0, -1]
		for f in 4:
			w_frames.append(Pixel.tex(_frame(dir, phases[f], 1 if f % 2 == 1 else 0, phases[f])))
		walk.append(w_frames)
	return {"idle": idle, "walk": walk, "shadow": Pixel.tex(_shadow())}

static func _shadow() -> Image:
	var img := Pixel.make(14, 7)
	Pixel.ellipse(img, 7, 3.5, 6.0, 3.0, Color(0, 0, 0, 0.30))
	Pixel.ellipse(img, 7, 3.5, 4.0, 2.0, Color(0, 0, 0, 0.16))
	return img

## leg: -1/0/1 = Beinstellung, bob: 0/1 = Auf-und-ab, arm: Armschwung
static func _frame(dir: int, leg: int, bob: int, arm: int) -> Image:
	var img := Pixel.make(W, H)
	var top := 2 + bob
	_draw_legs(img, dir, leg)
	_draw_body(img, dir, top, arm)
	_draw_head(img, dir, top)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _draw_legs(img: Image, dir: int, leg: int) -> void:
	if dir == Dir.SIDE:
		var front := 6 + leg
		var back := 7 - leg
		Pixel.rect(img, back, 19, 3, 3, Palette.PANTS)
		Pixel.rect(img, back, 22, 3, 2, Palette.BOOTS)
		Pixel.rect(img, front, 19, 3, 3, Color(Palette.PANTS.r * 1.2, Palette.PANTS.g * 1.2, Palette.PANTS.b * 1.2, 1.0))
		Pixel.rect(img, front, 22, 4, 2, Palette.BOOTS)
		return
	var l_dy := absi(leg)
	var r_dy := 1 - absi(leg) if leg != 0 else 0
	Pixel.rect(img, 5, 19 + (l_dy if leg > 0 else 0), 3, 3, Palette.PANTS)
	Pixel.rect(img, 5, 22, 3, 2, Palette.BOOTS)
	Pixel.rect(img, 8, 19 + (r_dy if leg < 0 else 0), 3, 3, Palette.PANTS)
	Pixel.rect(img, 8, 22, 3, 2, Palette.BOOTS)

static func _draw_body(img: Image, dir: int, top: int, arm: int) -> void:
	var y := top + 9
	if dir == Dir.SIDE:
		Pixel.rect(img, 5, y, 6, 7, Palette.TUNIC)
		Pixel.rect(img, 9, y, 2, 7, Palette.TUNIC_DARK)
		Pixel.rect(img, 5, y + 6, 6, 1, Palette.BOOTS)
		# ein sichtbarer Arm, schwingt
		Pixel.rect(img, 6, y + 1 + arm, 2, 4, Palette.TUNIC_DARK)
		Pixel.rect(img, 6, y + 5 + arm, 2, 2, Palette.SKIN)
		return
	Pixel.rect(img, 4, y, 8, 7, Palette.TUNIC)
	Pixel.rect(img, 10, y, 2, 7, Palette.TUNIC_DARK)
	Pixel.rect(img, 4, y + 6, 8, 1, Palette.BOOTS)
	if dir == Dir.DOWN:
		Pixel.vline(img, 7, y + 1, 5, Palette.TUNIC_DARK)
	# Arme links/rechts
	Pixel.rect(img, 2, y + 1 - arm, 2, 4, Palette.TUNIC_DARK)
	Pixel.rect(img, 2, y + 5 - arm, 2, 2, Palette.SKIN)
	Pixel.rect(img, 12, y + 1 + arm, 2, 4, Palette.TUNIC_DARK)
	Pixel.rect(img, 12, y + 5 + arm, 2, 2, Palette.SKIN)

static func _draw_head(img: Image, dir: int, top: int) -> void:
	match dir:
		Dir.DOWN:
			Pixel.rect(img, 4, top + 2, 8, 7, Palette.SKIN)
			Pixel.rect(img, 4, top + 8, 8, 1, Palette.SKIN_SHADE)
			Pixel.rect(img, 3, top, 10, 3, Palette.HAIR)
			Pixel.rect(img, 3, top + 3, 1, 3, Palette.HAIR)
			Pixel.rect(img, 12, top + 3, 1, 3, Palette.HAIR)
			Pixel.rect(img, 4, top + 2, 8, 1, Palette.HAIR_LIGHT)
			Pixel.px(img, 6, top + 5, EYE)
			Pixel.px(img, 9, top + 5, EYE)
			Pixel.px(img, 7, top + 7, Palette.SKIN_SHADE)
			Pixel.px(img, 8, top + 7, Palette.SKIN_SHADE)
		Dir.UP:
			Pixel.rect(img, 4, top + 2, 8, 7, Palette.SKIN_SHADE)
			Pixel.rect(img, 3, top, 10, 7, Palette.HAIR)
			Pixel.rect(img, 4, top, 8, 2, Palette.HAIR_LIGHT)
			Pixel.rect(img, 4, top + 7, 8, 2, Palette.HAIR)
		Dir.SIDE:
			Pixel.rect(img, 4, top + 2, 8, 7, Palette.SKIN)
			Pixel.rect(img, 4, top + 8, 8, 1, Palette.SKIN_SHADE)
			Pixel.rect(img, 3, top, 9, 4, Palette.HAIR)
			Pixel.rect(img, 3, top + 3, 3, 4, Palette.HAIR)
			Pixel.rect(img, 4, top + 1, 7, 1, Palette.HAIR_LIGHT)
			Pixel.px(img, 9, top + 5, EYE)
			Pixel.px(img, 11, top + 6, Palette.SKIN_SHADE)
