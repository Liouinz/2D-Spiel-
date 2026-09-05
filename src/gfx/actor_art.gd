class_name ActorArt
extends RefCounted
## Erzeugt die Spielerfigur: 3 Blickrichtungen (unten/oben/seitlich),
## Idle-Atmen (2 Bilder) und Laufzyklus (4 Bilder). Rechts = gespiegelt links.
##
## Das Licht kommt wie bei allen Objekten von oben links: linke Körperseite
## heller, rechte Seite abgedunkelt.

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
	var img := Pixel.make(16, 8)
	Pixel.ellipse(img, 8, 4.0, 7.0, 3.4, Color(0, 0, 0, 0.14))
	Pixel.ellipse(img, 8, 4.0, 5.4, 2.6, Color(0, 0, 0, 0.24))
	Pixel.ellipse(img, 7.4, 3.8, 3.4, 1.6, Color(0, 0, 0, 0.14))
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
	var pants_lit := Palette.PANTS.lightened(0.16)
	var pants_dark := Palette.PANTS.darkened(0.22)
	if dir == Dir.SIDE:
		var front := 6 + leg
		var back := 7 - leg
		Pixel.rect(img, back, 19, 3, 3, pants_dark)
		Pixel.rect(img, back, 22, 3, 2, Palette.BOOTS.darkened(0.18))
		Pixel.rect(img, front, 19, 3, 3, pants_lit)
		Pixel.rect(img, front, 22, 4, 2, Palette.BOOTS)
		Pixel.px(img, front, 22, Palette.BOOTS.lightened(0.2))
		return
	var l_dy := absi(leg)
	var r_dy := 1 - absi(leg) if leg != 0 else 0
	# linkes Bein liegt im Licht, rechtes im Schatten
	Pixel.rect(img, 5, 19 + (l_dy if leg > 0 else 0), 3, 3, pants_lit)
	Pixel.rect(img, 5, 22, 3, 2, Palette.BOOTS)
	Pixel.rect(img, 8, 19 + (r_dy if leg < 0 else 0), 3, 3, pants_dark)
	Pixel.rect(img, 8, 22, 3, 2, Palette.BOOTS.darkened(0.18))

static func _draw_body(img: Image, dir: int, top: int, arm: int) -> void:
	var y := top + 9
	var tunic_lit := Palette.TUNIC.lightened(0.14)
	var belt := Palette.BOOTS.darkened(0.1)
	if dir == Dir.SIDE:
		Pixel.rect(img, 5, y, 6, 7, Palette.TUNIC)
		Pixel.rect(img, 5, y, 2, 7, tunic_lit)
		Pixel.rect(img, 9, y, 2, 7, Palette.TUNIC_DARK)
		Pixel.rect(img, 5, y + 6, 6, 1, belt)
		Pixel.px(img, 7, y + 6, Palette.UI_ACCENT)
		# Umhängetasche
		Pixel.rect(img, 9, y + 3, 3, 3, Palette.WOOD_DARK)
		Pixel.px(img, 9, y + 3, Palette.WOOD)
		Pixel.rect(img, 6, y + 1 + arm, 2, 4, Palette.TUNIC_DARK)
		Pixel.rect(img, 6, y + 5 + arm, 2, 2, Palette.SKIN)
		return
	Pixel.rect(img, 4, y, 8, 7, Palette.TUNIC)
	Pixel.rect(img, 4, y, 3, 7, tunic_lit)
	Pixel.rect(img, 10, y, 2, 7, Palette.TUNIC_DARK)
	Pixel.rect(img, 4, y + 6, 8, 1, belt)
	if dir == Dir.DOWN:
		Pixel.vline(img, 7, y + 1, 5, Palette.TUNIC_DARK)
		Pixel.px(img, 7, y + 6, Palette.UI_ACCENT)
		Pixel.px(img, 8, y + 6, Palette.UI_ACCENT)
	else:
		# Rückenansicht: Riemen der Tasche
		Pixel.px(img, 6, y + 1, Palette.WOOD_DARK)
		Pixel.px(img, 9, y + 1, Palette.WOOD_DARK)
		Pixel.rect(img, 6, y + 2, 4, 3, Palette.WOOD_DARK)
		Pixel.rect(img, 6, y + 2, 4, 1, Palette.WOOD)
	# Arme links/rechts
	Pixel.rect(img, 2, y + 1 - arm, 2, 4, tunic_lit.darkened(0.05))
	Pixel.rect(img, 2, y + 5 - arm, 2, 2, Palette.SKIN)
	Pixel.rect(img, 12, y + 1 + arm, 2, 4, Palette.TUNIC_DARK)
	Pixel.rect(img, 12, y + 5 + arm, 2, 2, Palette.SKIN_SHADE)

static func _draw_head(img: Image, dir: int, top: int) -> void:
	var hair_dark := Palette.HAIR.darkened(0.22)
	match dir:
		Dir.DOWN:
			Pixel.rect(img, 4, top + 2, 8, 7, Palette.SKIN)
			Pixel.rect(img, 10, top + 3, 2, 6, Palette.SKIN_SHADE)
			Pixel.rect(img, 4, top + 8, 8, 1, Palette.SKIN_SHADE)
			Pixel.rect(img, 3, top, 10, 3, Palette.HAIR)
			Pixel.rect(img, 3, top + 3, 1, 3, Palette.HAIR)
			Pixel.rect(img, 12, top + 3, 1, 3, hair_dark)
			Pixel.rect(img, 4, top + 2, 8, 1, Palette.HAIR_LIGHT)
			Pixel.rect(img, 4, top, 4, 1, Palette.HAIR_LIGHT)
			Pixel.px(img, 6, top + 5, EYE)
			Pixel.px(img, 9, top + 5, EYE)
			Pixel.px(img, 7, top + 7, Palette.SKIN_SHADE)
			Pixel.px(img, 8, top + 7, Palette.SKIN_SHADE)
		Dir.UP:
			Pixel.rect(img, 4, top + 2, 8, 7, Palette.SKIN_SHADE)
			Pixel.rect(img, 3, top, 10, 7, Palette.HAIR)
			Pixel.rect(img, 4, top, 6, 2, Palette.HAIR_LIGHT)
			Pixel.rect(img, 11, top + 1, 2, 6, hair_dark)
			Pixel.rect(img, 4, top + 7, 8, 2, Palette.HAIR)
		Dir.SIDE:
			Pixel.rect(img, 4, top + 2, 8, 7, Palette.SKIN)
			Pixel.rect(img, 10, top + 3, 2, 5, Palette.SKIN_SHADE)
			Pixel.rect(img, 4, top + 8, 8, 1, Palette.SKIN_SHADE)
			Pixel.rect(img, 3, top, 9, 4, Palette.HAIR)
			Pixel.rect(img, 3, top + 3, 3, 4, Palette.HAIR)
			Pixel.rect(img, 4, top + 1, 5, 1, Palette.HAIR_LIGHT)
			Pixel.px(img, 11, top + 3, hair_dark)
			Pixel.px(img, 9, top + 5, EYE)
			Pixel.px(img, 11, top + 6, Palette.SKIN_SHADE)
