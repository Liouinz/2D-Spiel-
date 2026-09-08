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

## Bilder des Sprungs: 0 gehockt (Absprung und Landung), 1 gestreckt
## (Aufstieg), 2 fallend. Drei reichen — mehr sieht man in einer halben
## Sekunde nicht, weniger liest sich als verschobenes Bild.
const JUMP_CROUCH := 0
const JUMP_RISE := 1
const JUMP_FALL := 2

## Wie viele Bilder die Flamme der Handfackel hat.
const FLAME_FRAMES := 4

## -> {"idle": [dir][2], "walk": [dir][4], "swim": [dir][2], "jump": [dir][3],
##     "torch": [4], "shadow": Texture}
static func build() -> Dictionary:
	var idle: Array = []
	var walk: Array = []
	var swim: Array = []
	var jump: Array = []
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
		var j_frames: Array[Texture2D] = []
		for phase in 3:
			j_frames.append(Pixel.tex(_jump_frame(dir, phase)))
		jump.append(j_frames)
	var torch: Array[Texture2D] = []
	for f in FLAME_FRAMES:
		torch.append(Pixel.tex(_torch_frame(f)))
	return {"idle": idle, "walk": walk, "swim": swim, "jump": jump,
		"torch": torch, "shadow": Pixel.tex(_shadow())}

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

## Ein Sprungbild.
##
## Der Sprung war vorher NUR eine Verschiebung: dasselbe Standbild, ein Stück
## weiter oben. Das liest sich als Objekt, das jemand hochhebt, nicht als
## Figur, die springt. Drei Stellungen genügen, um daraus eine Bewegung zu
## machen:
##
##   gehockt    Beine angezogen, Körper tief — Absprung UND Landung
##   gestreckt  Beine zusammen, Körper hoch, Arme oben — der Aufstieg
##   fallend    Beine auseinander, Arme aussen — der Fall
##
## Absprung und Landung teilen sich ein Bild: in beiden geht die Figur in die
## Knie, und die paar Zehntel dazwischen sieht ohnehin niemand doppelt.
static func _jump_frame(dir: int, phase: int) -> Image:
	var img := Pixel.make(W, H)
	match phase:
		JUMP_RISE:
			# Angezogen und gestreckt: Beine hoch, Körper und Kopf zwei Pixel
			# höher als im Stand.
			_draw_legs(img, dir, 0, 5)
			_draw_body(img, dir, 2, -3)
			_draw_head(img, dir, 2)
		JUMP_FALL:
			_draw_legs(img, dir, 1, 2)
			_draw_body(img, dir, 3, 3)
			_draw_head(img, dir, 3)
		_:
			# Gehockt: Körper tief, Beine kurz, Arme unten.
			_draw_legs(img, dir, 0, 3)
			_draw_body(img, dir, 7, 1)
			_draw_head(img, dir, 7)
	Pixel.outline(img, Palette.OUTLINE)
	return img

## Die Handfackel: ein kurzer Stiel mit einer Flamme, die sich bewegt.
##
## Vier Bilder, und in jedem ist die Flamme eine Spur anders hoch, anders breit
## und anders hell. Eine Flamme, die stillsteht, ist kein Feuer — und eine, die
## in jedem Bild komplett anders aussieht, flackert wie eine kaputte Leuchte.
static func _torch_frame(f: int) -> Image:
	var img := Pixel.make(9, 15)
	# Stiel
	Pixel.rect(img, 4, 7, 2, 8, Palette.WOOD_DARK)
	Pixel.vline(img, 4, 7, 8, Palette.WOOD)
	Pixel.rect(img, 3, 5, 4, 3, Palette.WOOD_LIGHT.darkened(0.25))
	Pixel.rect(img, 3, 5, 4, 1, Palette.WOOD_LIGHT)
	# Flamme: je Bild eine andere Höhe und Breite.
	var tall: Array = [0.0, 1.0, 0.4, 1.4]
	var wide: Array = [0.0, -0.3, 0.4, -0.2]
	var h: float = 3.6 + float(tall[f % FLAME_FRAMES])
	var w: float = 2.6 + float(wide[f % FLAME_FRAMES])
	var cy: float = 4.2 - h * 0.25
	Pixel.ellipse(img, 4.5, cy, w, h, Color8(214, 84, 28))
	Pixel.ellipse(img, 4.5, cy + 0.5, w * 0.62, h * 0.66, Color8(244, 156, 44))
	Pixel.ellipse(img, 4.5, cy + 0.9, w * 0.34, h * 0.38, Color8(252, 224, 140))
	Pixel.outline(img, Palette.OUTLINE)
	return img

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

## `tuck` zieht die Beine an: der Ansatz bleibt, die Füsse kommen hoch. Damit
## wird aus derselben Zeichnung eine gehockte und eine gestreckte Stellung,
## ohne dass ein zweites Beinpaar gemalt werden müsste.
static func _draw_legs(img: Image, dir: int, leg: int, tuck: int = 0) -> void:
	var lit := Palette.PANTS.lightened(0.18)
	var dark := Palette.PANTS.darkened(0.24)
	var boot := Palette.BOOTS
	var boot_dark := Palette.BOOTS.darkened(0.2)
	if dir == Dir.SIDE:
		var front := 11 + leg * 3
		var back := 14 - leg * 3
		# hinteres Bein
		Pixel.rect(img, back, 37, 7, maxi(7 - tuck, 2), dark)
		Pixel.rect(img, back, 43 - tuck, 8, 5, boot_dark)
		Pixel.rect(img, back, 43 - tuck, 8, 1, Palette.BOOTS.lightened(0.1))
		# vorderes Bein
		Pixel.rect(img, front, 37, 7, maxi(7 - tuck, 2), lit)
		Pixel.rect(img, front, 37, 2, maxi(7 - tuck, 2), Palette.PANTS.lightened(0.3))
		Pixel.rect(img, front, 43 - tuck, 9, 5, boot)
		Pixel.rect(img, front, 43 - tuck, 9, 1, Palette.BOOTS.lightened(0.22))
		return
	var l_dy := 2 if leg > 0 else 0
	var r_dy := 2 if leg < 0 else 0
	# linkes Bein im Licht, rechtes im Schatten
	Pixel.rect(img, 10, 37 + l_dy, 6, maxi(7 - l_dy - tuck, 2), lit)
	Pixel.rect(img, 10, 37 + l_dy, 2, maxi(7 - l_dy - tuck, 2), Palette.PANTS.lightened(0.32))
	Pixel.rect(img, 10, 44 - tuck, 6, 4, boot)
	Pixel.rect(img, 10, 44 - tuck, 6, 1, Palette.BOOTS.lightened(0.22))
	Pixel.rect(img, 17, 37 + r_dy, 6, maxi(7 - r_dy - tuck, 2), dark)
	Pixel.rect(img, 17, 44 - tuck, 6, 4, boot_dark)
	Pixel.rect(img, 17, 44 - tuck, 6, 1, Palette.BOOTS)

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
