class_name ActorArt
extends RefCounted
## Erzeugt die Spielerfigur: 3 Blickrichtungen (unten/oben/seitlich),
## Idle-Atmen (2 Bilder) und Laufzyklus (4 Bilder). Rechts = gespiegelt links.
##
## 32 x 48 Pixel. Das Licht kommt wie bei allen Objekten von oben links: linke
## Körperseite heller, rechte abgedunkelt.

enum Dir { DOWN, UP, SIDE }

const W := 32
const H := 48
## Wie tief die Figur beim Schwimmen einsinkt. player.gd verschiebt das Bild
## um denselben Wert nach unten, damit der Kopf an seiner Stelle bleibt.
const SWIM_SINK := 16

const EYE := Color8(46, 40, 52)
const EYE_WHITE := Color8(236, 232, 226)

## -> {"idle": [dir][2], "walk": [dir][4], "swim": [dir][2], "shadow": Texture}
static func build() -> Dictionary:
	var idle: Array = []
	var walk: Array = []
	var swim: Array = []
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
		var s_frames: Array[Texture2D] = []
		s_frames.append(Pixel.tex(_swim_frame(dir, 0)))
		s_frames.append(Pixel.tex(_swim_frame(dir, 1)))
		swim.append(s_frames)
	return {"idle": idle, "walk": walk, "swim": swim, "shadow": Pixel.tex(_shadow())}

## Schwimmbild: dasselbe Laufbild, nur eingetaucht.
##
## Dieselbe Figur statt einer eigenen: so bleibt sie in jeder Blickrichtung
## dieselbe Person, und die Wasserlinie sitzt garantiert an derselben Stelle
## wie der Versatz, mit dem player.gd die Figur einsinken lässt.
static func _swim_frame(dir: int, phase: int) -> Image:
	var img := _frame(dir, 0, phase, 1 if phase == 0 else -1)
	var line := H - SWIM_SINK
	_submerge(img, line)
	_collar(img, line, phase)
	return img

## Unter der Wasserlinie wird die Figur nicht ABGESCHNITTEN, sondern
## eingetaucht: durchscheinend und zur Wasserfarbe hin verschoben, nach unten
## hin immer weniger.
##
## Vorher wurde alles darunter gelöscht. Das sah aus, als steckte die Figur in
## einem gestanzten Loch — man sah einen Oberkörper auf einer Fläche, keinen
## Körper im Wasser. Sichtbar bleiben heisst hier: man ahnt die Beine, ohne sie
## zu erkennen, und genau so sieht ein Körper unter Wasser aus.
static func _submerge(img: Image, line: int) -> void:
	for y in range(line, H):
		var depth := float(y - line) / float(maxi(H - line, 1))
		var fade := lerpf(0.38, 0.08, depth)
		for x in W:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			img.set_pixel(x, y, Color(c.lerp(Palette.WATER_DEEP, 0.60), c.a * fade))

## Wellenkragen: ein Ring um die Taille, keine gerade Linie.
##
## Vorher waren es drei waagerechte Reihen über die ganze Bildbreite. Über
## einer 32 Pixel breiten Figur liest sich das als Brett, auf dem sie steht.
## Ein Ring hat eine Vorder- und eine Rückseite: vorne läuft er über den
## Körper, hinten verschwindet er dahinter — daran erkennt man, dass die Figur
## IM Wasser ist und nicht davor.
static func _collar(img: Image, line: int, phase: int) -> void:
	var cx := W * 0.5
	var cy := float(line) + 0.5
	for y in range(line - 4, mini(line + 6, H)):
		if y < 0:
			continue
		for x in W:
			var dx := (x + 0.5 - cx) / 13.0
			var dy := (y + 0.5 - cy) / 3.6
			var d := sqrt(dx * dx + dy * dy)
			if d > 1.0 or d < 0.60:
				continue
			# Hinter der Figur verdeckt der Rücken die Welle.
			if y < line and img.get_pixel(x, y).a > 0.5:
				continue
			# Lücken je Phase — ein geschlossener Ring wäre ein Reifen.
			if (x * 5 + y * 3 + phase * 7) % 9 == 0:
				continue
			var near := float(y) + 0.5 > cy
			var col := Palette.WATER_FOAM if near else Palette.WATER_LIGHT
			var a := (0.88 if near else 0.46) * (1.0 - absf(d - 0.80) * 1.8)
			if a <= 0.02:
				continue
			img.set_pixel(x, y, Color(col, a))

## Bodenschatten: drei Ellipsen ineinander, von aussen nach innen dunkler.
##
## Er sitzt leicht nach UNTEN RECHTS versetzt. Das Licht kommt in dieser Welt
## von oben links — bei jeder Kachel, bei jedem Grashalm, an der Figur selbst.
## Ein mittig gesetzter Schatten widerspräche dem und läse sich als Mittagssonne
## im Zenit; ein Pixel Versatz genügt, damit die Figur auf dem Boden steht,
## statt darüber zu schweben.
static func _shadow() -> Image:
	var img := Pixel.make(30, 14)
	Pixel.ellipse(img, 15.6, 7.6, 13.2, 6.2, Color(0, 0, 0, 0.11))
	Pixel.ellipse(img, 15.6, 7.6, 9.8, 4.5, Color(0, 0, 0, 0.18))
	Pixel.ellipse(img, 15.2, 7.2, 6.2, 2.8, Color(0, 0, 0, 0.22))
	return img

## leg: -1/0/1 = Beinstellung, bob: 0/1 = Auf-und-ab, arm: Armschwung
static func _frame(dir: int, leg: int, bob: int, arm: int) -> Image:
	var img := Pixel.make(W, H)
	var top := 4 + bob * 2
	_draw_legs(img, dir, leg)
	_draw_body(img, dir, top, arm * 2)
	_draw_head(img, dir, top)
	Pixel.outline(img, Palette.OUTLINE)
	return img

static func _draw_legs(img: Image, dir: int, leg: int) -> void:
	var lit := Palette.PANTS.lightened(0.18)
	var dark := Palette.PANTS.darkened(0.24)
	var boot := Palette.BOOTS
	var boot_dark := Palette.BOOTS.darkened(0.2)
	if dir == Dir.SIDE:
		var front := 11 + leg * 3
		var back := 14 - leg * 3
		# hinteres Bein
		Pixel.rect(img, back, 37, 7, 7, dark)
		Pixel.rect(img, back, 43, 8, 5, boot_dark)
		Pixel.rect(img, back, 43, 8, 1, Palette.BOOTS.lightened(0.1))
		# vorderes Bein
		Pixel.rect(img, front, 37, 7, 7, lit)
		Pixel.rect(img, front, 37, 2, 7, Palette.PANTS.lightened(0.3))
		Pixel.rect(img, front, 43, 9, 5, boot)
		Pixel.rect(img, front, 43, 9, 1, Palette.BOOTS.lightened(0.22))
		return
	var l_dy := 2 if leg > 0 else 0
	var r_dy := 2 if leg < 0 else 0
	# linkes Bein im Licht, rechtes im Schatten
	Pixel.rect(img, 10, 37 + l_dy, 6, 7 - l_dy, lit)
	Pixel.rect(img, 10, 37 + l_dy, 2, 7 - l_dy, Palette.PANTS.lightened(0.32))
	Pixel.rect(img, 10, 44, 6, 4, boot)
	Pixel.rect(img, 10, 44, 6, 1, Palette.BOOTS.lightened(0.22))
	Pixel.rect(img, 17, 37 + r_dy, 6, 7 - r_dy, dark)
	Pixel.rect(img, 17, 44, 6, 4, boot_dark)
	Pixel.rect(img, 17, 44, 6, 1, Palette.BOOTS)

static func _draw_body(img: Image, dir: int, top: int, arm: int) -> void:
	var y := top + 18
	var lit := Palette.TUNIC.lightened(0.16)
	var hi := Palette.TUNIC.lightened(0.30)
	var belt := Palette.BOOTS.darkened(0.12)
	if dir == Dir.SIDE:
		Pixel.rect(img, 10, y, 13, 15, Palette.TUNIC)
		Pixel.rect(img, 10, y, 4, 15, lit)
		Pixel.rect(img, 19, y, 4, 15, Palette.TUNIC_DARK)
		# Stoffwurf
		Pixel.rect(img, 14, y + 4, 1, 9, Palette.TUNIC_DARK)
		Pixel.rect(img, 17, y + 2, 1, 11, Palette.TUNIC.lightened(0.08))
		Pixel.rect(img, 10, y + 12, 13, 3, belt)
		Pixel.rect(img, 14, y + 12, 4, 3, Palette.UI_ACCENT)
		# Umhängetasche
		Pixel.rect(img, 19, y + 6, 7, 7, Palette.WOOD_DARK)
		Pixel.rect(img, 19, y + 6, 7, 2, Palette.WOOD)
		Pixel.rect(img, 20, y + 9, 3, 1, Palette.WOOD_LIGHT)
		# sichtbarer Arm
		Pixel.rect(img, 12, y + 2 + arm, 5, 9, Palette.TUNIC_DARK)
		Pixel.rect(img, 12, y + 10 + arm, 5, 5, Palette.SKIN)
		Pixel.rect(img, 12, y + 10 + arm, 2, 5, Palette.SKIN.lightened(0.1))
		return
	Pixel.rect(img, 8, y, 16, 15, Palette.TUNIC)
	Pixel.rect(img, 8, y, 5, 15, lit)
	Pixel.rect(img, 9, y, 2, 15, hi)
	Pixel.rect(img, 20, y, 4, 15, Palette.TUNIC_DARK)
	Pixel.rect(img, 8, y + 12, 16, 3, belt)
	if dir == Dir.DOWN:
		# Kragen, Schnürung und Gürtelschnalle
		Pixel.rect(img, 13, y, 6, 2, Palette.TUNIC_DARK)
		Pixel.vline(img, 15, y + 2, 10, Palette.TUNIC_DARK)
		for i in 3:
			Pixel.rect(img, 14, y + 3 + i * 3, 3, 1, Palette.WOOD_LIGHT)
		Pixel.rect(img, 14, y + 12, 4, 3, Palette.UI_ACCENT)
		Pixel.px(img, 15, y + 13, Palette.UI_ACCENT.lightened(0.3))
	else:
		# Rückenansicht: Riemen und Tasche
		Pixel.rect(img, 12, y, 2, 6, Palette.WOOD_DARK)
		Pixel.rect(img, 18, y, 2, 6, Palette.WOOD_DARK)
		Pixel.rect(img, 11, y + 5, 10, 8, Palette.WOOD_DARK)
		Pixel.rect(img, 11, y + 5, 10, 2, Palette.WOOD)
		Pixel.rect(img, 14, y + 9, 4, 1, Palette.WOOD_LIGHT)
	# Arme
	Pixel.rect(img, 4, y + 2 - arm, 5, 9, lit.darkened(0.06))
	Pixel.rect(img, 4, y + 10 - arm, 5, 5, Palette.SKIN)
	Pixel.rect(img, 23, y + 2 + arm, 5, 9, Palette.TUNIC_DARK)
	Pixel.rect(img, 23, y + 10 + arm, 5, 5, Palette.SKIN_SHADE)

static func _draw_head(img: Image, dir: int, top: int) -> void:
	var hair_dark := Palette.HAIR.darkened(0.24)
	match dir:
		Dir.DOWN:
			Pixel.rect(img, 8, top + 4, 16, 14, Palette.SKIN)
			Pixel.rect(img, 20, top + 6, 4, 12, Palette.SKIN_SHADE)
			Pixel.rect(img, 8, top + 16, 16, 2, Palette.SKIN_SHADE)
			# Haar
			Pixel.rect(img, 6, top, 20, 6, Palette.HAIR)
			Pixel.rect(img, 6, top + 6, 2, 6, Palette.HAIR)
			Pixel.rect(img, 24, top + 6, 2, 6, hair_dark)
			Pixel.rect(img, 8, top + 4, 16, 2, Palette.HAIR)
			Pixel.rect(img, 7, top, 9, 2, Palette.HAIR_LIGHT)
			Pixel.rect(img, 8, top + 2, 5, 1, Palette.HAIR_LIGHT)
			# Augen mit Weiß und Pupille
			for ex: int in [11, 18]:
				Pixel.rect(img, ex, top + 9, 3, 3, EYE_WHITE)
				Pixel.rect(img, ex + 1, top + 10, 2, 2, EYE)
				Pixel.rect(img, ex, top + 8, 3, 1, hair_dark)
			# Nase, Mund, Wangen
			Pixel.px(img, 15, top + 12, Palette.SKIN_SHADE)
			Pixel.rect(img, 14, top + 14, 4, 1, Palette.SKIN_SHADE.darkened(0.15))
			Pixel.px(img, 10, top + 12, Color8(226, 158, 140))
			Pixel.px(img, 21, top + 12, Color8(226, 158, 140))
		Dir.UP:
			Pixel.rect(img, 8, top + 4, 16, 14, Palette.SKIN_SHADE)
			Pixel.rect(img, 6, top, 20, 14, Palette.HAIR)
			Pixel.rect(img, 7, top, 10, 3, Palette.HAIR_LIGHT)
			Pixel.rect(img, 8, top + 3, 6, 2, Palette.HAIR_LIGHT)
			Pixel.rect(img, 22, top + 2, 4, 12, hair_dark)
			Pixel.rect(img, 8, top + 14, 16, 4, Palette.HAIR)
			Pixel.rect(img, 10, top + 17, 12, 1, hair_dark)
		Dir.SIDE:
			Pixel.rect(img, 8, top + 4, 16, 14, Palette.SKIN)
			Pixel.rect(img, 20, top + 6, 4, 10, Palette.SKIN_SHADE)
			Pixel.rect(img, 8, top + 16, 16, 2, Palette.SKIN_SHADE)
			# Haar seitlich, deckt Hinterkopf
			Pixel.rect(img, 6, top, 18, 8, Palette.HAIR)
			Pixel.rect(img, 6, top + 6, 6, 9, Palette.HAIR)
			Pixel.rect(img, 7, top + 1, 10, 2, Palette.HAIR_LIGHT)
			Pixel.px(img, 23, top + 6, hair_dark)
			# Profil: ein Auge, Nase, Mund
			Pixel.rect(img, 17, top + 9, 3, 3, EYE_WHITE)
			Pixel.rect(img, 18, top + 10, 2, 2, EYE)
			Pixel.rect(img, 17, top + 8, 3, 1, hair_dark)
			Pixel.rect(img, 23, top + 10, 2, 2, Palette.SKIN)
			Pixel.rect(img, 20, top + 14, 3, 1, Palette.SKIN_SHADE.darkened(0.15))
