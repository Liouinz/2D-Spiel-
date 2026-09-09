class_name ActorArt
extends RefCounted
## Erzeugt die Spielerfigur: 3 Blickrichtungen (unten/oben/seitlich),
## Idle-Atmen (2 Bilder) und Laufzyklus (4 Bilder). Rechts = gespiegelt links.
##
## 32 x 48 Pixel. Das Licht kommt wie bei allen Objekten von oben links: linke
## Körperseite heller, rechte abgedunkelt.

enum Dir { DOWN, UP, SIDE }

## Bein- und Armstellung je Laufbild. Oeffentlich, weil die Handfackel
## denselben Werten folgen muss: schwingt der Arm und die Fackel nicht, haengt
## sie beim Laufen sichtbar hinterher.
const WALK_ARM: Array[int] = [0, 1, 0, -1]

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

## Wie viele Bilder die Flamme hat — der Handfackel wie der gesetzten.
##
## Vier waren zu wenig. Bei vier Bildern liest man den Takt: dieselbe Folge
## viermal je Sekunde, und das Auge findet den Rhythmus. Feuer hat keinen.
## Acht Bilder mit UNREGELMAESSIGEN Werten (siehe die Tabellen unten) sind der
## kleinste Satz, bei dem die Wiederholung nicht mehr auffaellt.
const FLAME_FRAMES := 8

# --- Die Flamme ---------------------------------------------------------------
#
# Vier Farbbaender von aussen nach innen. Drei sind zu wenig — dann fehlt
# entweder das Rot am Rand (die Flamme sieht aus wie eine gelbe Zunge) oder der
# weisse Kern (sie sieht aus wie Orange mit Rand). Fuenf kann man auf sechs
# Bildpunkten Breite nicht mehr unterscheiden.
const FLAME_OUT := Color8(198, 56, 22)      ## Rand: rot
const FLAME_MID := Color8(240, 128, 32)     ## orange
const FLAME_IN := Color8(250, 198, 76)      ## gelb
const FLAME_CORE := Color8(255, 244, 202)   ## Kern: weiss-gelb

## Je Bild ein anderer Wert fuer Hoehe, Breite und Neigung der Spitze.
##
## Die Zahlen sind bewusst UNGEORDNET. Eine Folge, die auf- und wieder absteigt,
## liest sich als Pulsieren — als atmete die Flamme. Feuer flackert aber
## sprunghaft: mal zuckt es zweimal kurz hintereinander hoch, mal bleibt es
## drei Bilder lang fast gleich.
const FLAME_TALL: Array[float] = [1.00, 1.15, 0.90, 1.07, 0.86, 1.19, 0.98, 1.09]
const FLAME_WIDE: Array[float] = [1.00, 0.93, 1.09, 0.96, 1.07, 0.89, 1.04, 0.95]
const FLAME_LEAN: Array[float] = [0.0, -0.6, 0.4, 1.0, -0.2, -0.9, 0.6, 0.1]

## In welchen Bildern ein Funke abgeht. Zwei von acht — mehr, und es sieht aus,
## als spruehte die Fackel dauernd Funken.
const FLAME_SPARK: Array[int] = [3, 6]

## Zeichnet eine Flamme.
##
## Die Form ist kein Stapel Ellipsen mehr. Eine Flamme ist ein Tropfen mit
## einer leckenden Spitze: unten am Docht schmal, auf halber Hoehe am
## breitesten, nach oben auslaufend — und die Spitze biegt sich, waehrend der
## Fuss stehen bleibt. Genau das macht `pow(1 - t, 1.8)` bei der Neigung: unten
## fast null, oben voll.
##
## `cx`/`base_y` ist der Fusspunkt (die Stelle, an der die Flamme aus der
## Wicklung tritt), `w`/`h` die Groesse in Bildpunkten.
static func draw_flame(img: Image, cx: float, base_y: float, w: float, h: float,
		frame: int) -> void:
	var f := frame % FLAME_FRAMES
	var hh: float = h * FLAME_TALL[f]
	var ww: float = w * FLAME_WIDE[f]
	var lean: float = FLAME_LEAN[f]
	var rows := int(round(hh))
	for i in rows:
		# t: 0 an der Spitze, 1 am Fuss.
		var t := float(i) / maxf(float(rows - 1), 1.0)
		# Tropfenform. `pow(t, 1.3)` schiebt die breiteste Stelle nach UNTEN —
		# eine Flamme ist ueber dem Docht am dicksten, nicht auf halber Hoehe.
		# Der zweite Summand haelt den Fuss schmal, wo sie aus der Wicklung
		# tritt. Ohne beides bekommt man einen Pilz.
		var hw: float = ww * (sin(pow(t, 1.3) * PI) * 0.86 + t * 0.24)
		if hw < 0.35:
			continue
		var mid: float = cx + lean * pow(1.0 - t, 1.8)
		var y := int(round(base_y - float(rows - 1 - i)))
		var x0 := int(floor(mid - hw))
		var x1 := int(ceil(mid + hw))
		for x in range(x0, x1 + 1):
			var d: float = absf(float(x) + 0.5 - mid) / maxf(hw, 0.5)
			if d > 1.05:
				continue
			Pixel.px(img, x, y, _flame_band(t, d))
	if FLAME_SPARK.has(f):
		# Ein einzelner Funke ueber der Spitze — losgeloest, damit man sieht,
		# dass da etwas aufsteigt.
		var sy := int(round(base_y - hh - 1.0 - float(f % 2)))
		Pixel.px(img, int(round(cx + lean * 1.4)), sy, Color(FLAME_IN, 0.85))

## Welches Farbband gilt an dieser Stelle?
##
## `t` ist die Hoehe (0 Spitze, 1 Fuss), `d` der Abstand von der Mittelachse
## (0 Mitte, 1 Rand). Der Kern sitzt UNTEN in der Mitte: dort, wo die Flamme am
## Docht sitzt, ist sie am heissesten. Die Spitze ist ganz aussen — sie ist der
## Teil, der abkuehlt und verweht.
static func _flame_band(t: float, d: float) -> Color:
	if t > 0.58 and t < 0.90 and d < 0.30:
		return FLAME_CORE
	if t > 0.26 and d < 0.56:
		return FLAME_IN
	if d < 0.88:
		return FLAME_MID
	return FLAME_OUT

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
		for f in 4:
			w_frames.append(Pixel.tex(_frame(dir, WALK_ARM[f], 1 if f % 2 == 1 else 0, WALK_ARM[f])))
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
## Die Fackel in der Hand.
##
## 11 x 20 Bildpunkte. Aufgebaut in der Reihenfolge, in der man sie sieht —
## das ist hier keine Formsache, sondern der ganze Unterschied zwischen
## „gehalten" und „danebengelegt":
##
##   1. Handruecken   HINTER dem Stiel — die Flaeche, gegen die er gedrueckt wird
##   2. Stiel         darueber, laeuft oben und unten aus der Faust heraus
##   3. Finger        VOR dem Stiel, drei Glieder mit Fugen dazwischen
##   4. Daumen        an der Lichtseite
##   5. Wicklung      Leder um den Kopf
##   6. Flamme        vor allem
##
## Nach Schritt 3 bleibt eine Spalte des Stiels zwischen Fingern und
## Handruecken sichtbar (x = 6). Genau daran liest man, dass die Hand DARUM
## greift und nicht DANEBEN liegt: es ist Haut davor, Holz in der Mitte, Haut
## dahinter.
##
## Die Fackel liegt auf einer eigenen Ebene ueber der Figur (`z_index = 1` in
## `player.gd`), damit sie sich mit der Hand bewegen kann, ohne dass jedes
## Laufbild der Figur eine zweite Fassung mit Fackel braeuchte.
const TORCH_W := 11
const TORCH_H := 20

## Wo in diesem Bild die greifende Hand sitzt. `player.gd` legt diesen Punkt
## auf die Hand der Figur — deshalb steht er hier und nicht dort: wer die
## Zeichnung aendert, verschiebt den Griff mit.
const TORCH_GRIP := Vector2(5.0, 14.5)

## Und wo die Flamme sitzt. Von hier geht das Licht aus, nicht von der Brust.
const TORCH_FLAME := Vector2(5.0, 4.0)

## Wo die greifende Hand IM FIGURENBILD sitzt (Mitte, Grundstellung).
##
## Diese Zahlen stehen genau einmal — hier. Vorher war die Fackelposition eine
## eigene Tabelle in `player.gd`, von Hand eingestellt, und sie lag zwei Punkte
## daneben: auf einem Bildschirmfoto sah man die Faust der Fackel NEBEN der
## Hand der Figur stehen, mit einem Streifen Haut dazwischen. Genau deshalb
## wirkte die Fackel angeklebt.
##
## Sie sind aus `_draw_body` abgelesen: die Hand ist ein 5 x 5 grosses Rechteck
## bei `y + 10`, mit `y = top + 18` und `top = 4`.
const HAND_AT := {
	Dir.DOWN: Vector2(25.5, 34.5),   ## rechte Hand, im Schatten
	Dir.UP: Vector2(6.5, 34.5),      ## linke Hand, im Licht
	Dir.SIDE: Vector2(14.5, 34.5),   ## der sichtbare Arm vor dem Koerper
}

## Wohin das Fackelbild gehoert, damit sein Griff auf der Hand liegt.
##
## Ergebnis in Ortskoordinaten der Figur: Nullpunkt zwischen den Fuessen,
## negatives y nach oben. `arm` und `bob` sind dieselben Werte, mit denen das
## Figurenbild gezeichnet wurde — dadurch wandert die Fackel mit dem Arm.
static func torch_offset(dir: int, arm: int, bob: int, flip: bool) -> Vector2:
	return hand_offset(dir, arm, bob, flip) - _grip_offset(TORCH_GRIP, flip)

## Wo die Flamme steht — dieselbe Rechnung, nur mit dem anderen Ankerpunkt.
static func torch_flame_offset(dir: int, arm: int, bob: int, flip: bool) -> Vector2:
	return hand_offset(dir, arm, bob, flip) \
		+ _grip_offset(TORCH_FLAME, flip) - _grip_offset(TORCH_GRIP, flip)

## Wo die greifende Hand in DIESEM Bild steht, in Ortskoordinaten der Figur.
##
## Eigene Funktion, weil zwei Dinge sie brauchen und keines von beiden die
## Formel noch einmal aufschreiben soll: die Fackel setzt ihren Griff darauf,
## und der Selbsttest prueft, dass er wirklich dort gelandet ist.
static func hand_offset(dir: int, arm: int, bob: int, flip: bool) -> Vector2:
	var hand: Vector2 = HAND_AT[dir]
	# Beim Blick nach oben greift die LINKE Hand, und die schwingt gegenlaeufig.
	hand.y += float(bob) * 2.0 + float(arm) * 2.0 * (-1.0 if dir == Dir.UP else 1.0)
	var local := Vector2(hand.x - W * 0.5, hand.y - H)
	if flip:
		local.x = -local.x
	return local

## Versatz eines Bildpunktes im Fackelbild gegenueber dessen Mitte.
##
## Das Bild ist mittig gesetzt, deshalb zaehlt der Abstand zur Mitte und nicht
## zur Ecke. Beim Spiegeln kippt er mit: der Griff sitzt eine halbe Spalte
## links der Mitte, gespiegelt eine halbe rechts.
static func _grip_offset(point: Vector2, flip: bool) -> Vector2:
	var dx := point.x - float(TORCH_W) * 0.5
	return Vector2(-dx if flip else dx, point.y - float(TORCH_H) * 0.5)

static func _torch_frame(f: int) -> Image:
	var img := Pixel.make(TORCH_W, TORCH_H)

	# 1. Handruecken HINTER dem Stiel. Nur drei Spalten breit und deutlich
	#    dunkler als die Finger: er liegt im Schatten der eigenen Hand, und
	#    ohne diesen Abstand im Tonwert verschmilzt die ganze Faust zu einem
	#    hellen Klumpen.
	Pixel.rect(img, 5, 12, 3, 6, Palette.SKIN_SHADE.darkened(0.30))

	# 2. Stiel. Drei Spalten: Licht, Mitte, Schatten — Licht von oben links.
	Pixel.vline(img, 4, 8, 12, Palette.WOOD_LIGHT)
	Pixel.vline(img, 5, 8, 12, Palette.WOOD)
	Pixel.vline(img, 6, 8, 12, Palette.WOOD_DARK)
	# Maserung: zwei kurze Kerben. Ohne sie ist der Stiel ein Balken.
	Pixel.px(img, 5, 18, Palette.WOOD_DARK)
	Pixel.px(img, 4, 11, Palette.WOOD)

	# 3. Finger VOR dem Stiel — drei Glieder mit dunkler Fuge dazwischen.
	#    Sie decken die Spalten 4 und 5 des Stiels; Spalte 6 bleibt sichtbar.
	for k in 3:
		var fy := 12 + k * 2
		Pixel.rect(img, 3, fy, 3, 2, Palette.SKIN)
		Pixel.rect(img, 3, fy, 3, 1, Palette.SKIN.lightened(0.10))
		Pixel.rect(img, 3, fy + 1, 3, 1, Palette.SKIN_SHADE.darkened(0.22))

	# 4. Daumen an der Lichtseite, eine Spalte breit.
	Pixel.rect(img, 2, 13, 1, 3, Palette.SKIN.lightened(0.14))
	Pixel.px(img, 2, 13, Palette.SKIN.lightened(0.26))

	# 5. Wicklung: Leder um den Kopf. Breiter als der Stiel, damit sie als
	#    Umwicklung liest und nicht als dickere Stelle im Holz — und in einem
	#    eigenen Ton, nicht nur dunkleres Holz.
	Pixel.rect(img, 3, 7, 5, 4, Color8(74, 52, 38))
	Pixel.rect(img, 3, 7, 5, 1, Color8(112, 82, 56))
	Pixel.px(img, 3, 8, Color8(96, 70, 48))
	# Schnur quer darueber.
	Pixel.px(img, 4, 9, Color8(52, 36, 26))
	Pixel.px(img, 5, 9, Color8(52, 36, 26))
	Pixel.px(img, 6, 9, Color8(52, 36, 26))
	Pixel.px(img, 7, 8, Color8(48, 34, 24))

	# Umriss NUR um Holz und Haut. Die Flamme bekommt keinen — ein schwarzer
	# Rand um Feuer laesst es wie einen Aufkleber aussehen.
	Pixel.outline(img, Palette.OUTLINE)

	# 6. Flamme, zuletzt und ohne Umriss.
	draw_flame(img, TORCH_FLAME.x, 7.0, 2.1, 9.0, f)
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
## Eine Kniefalte: eine Reihe Schatten, darueber eine Reihe Licht.
##
## Ein Hosenbein aus einer einzigen Farbe ist ein Balken. Zwei Reihen auf
## Kniehoehe geben ihm ein Gelenk — und damit liest man ein Bein, das sich
## beugen kann, statt eines Stuecks Holz.
static func _knee(img: Image, x: int, w: int, y: int) -> void:
	if y < 0 or y >= H - 1:
		return
	Pixel.rect(img, x, y, w, 1, Color(Palette.PANTS.darkened(0.34), 0.55))
	Pixel.rect(img, x, y - 1, w, 1, Color(Palette.PANTS.lightened(0.24), 0.32))

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
	_knee(img, 10, 6, 40 + l_dy - tuck)
	Pixel.rect(img, 10, 44 - tuck, 6, 4, boot)
	Pixel.rect(img, 10, 44 - tuck, 6, 1, Palette.BOOTS.lightened(0.22))
	Pixel.rect(img, 10, 47 - tuck, 6, 1, Palette.BOOTS.darkened(0.35))
	Pixel.rect(img, 17, 37 + r_dy, 6, maxi(7 - r_dy - tuck, 2), dark)
	_knee(img, 17, 6, 40 + r_dy - tuck)
	Pixel.rect(img, 17, 44 - tuck, 6, 4, boot_dark)
	Pixel.rect(img, 17, 44 - tuck, 6, 1, Palette.BOOTS)
	Pixel.rect(img, 17, 47 - tuck, 6, 1, Palette.BOOTS.darkened(0.35))

## Stofffalten auf der Tunika.
##
## Der Auftrag verlangte „leichte Schattierungen und Texturhinweise auf der
## Kleidung". Der Rumpf bestand vorher aus drei senkrechten Streifen — hell,
## mittel, dunkel. Das ist BELEUCHTUNG, keine Textur: es sagt, woher das Licht
## kommt, aber nichts darueber, dass da Stoff haengt.
##
## Falten sagen das. Sie muessen schwach bleiben (30 bzw. 22 Prozent): eine
## deutliche Falte auf einer 16 Bildpunkte breiten Brust liest sich als Naht
## oder als Schmutz. Und sie laufen nicht bis zum Guertel durch — Stoff wird
## nach unten hin von der Raffung glattgezogen.
static func _folds(img: Image, x0: int, w: int, y: int) -> void:
	var shade := Color(Palette.TUNIC_DARK, 0.30)
	var glint := Color(Palette.TUNIC.lightened(0.34), 0.22)
	# Zwei Falten, asymmetrisch gesetzt: symmetrische Falten wirken gedruckt.
	Pixel.vline(img, x0 + 2, y + 4, 7, shade)
	Pixel.vline(img, x0 + 3, y + 5, 5, glint)
	Pixel.vline(img, x0 + w - 5, y + 3, 8, shade)
	# Saum ueber dem Guertel: eine Reihe, in der der Stoff aufliegt.
	Pixel.rect(img, x0 + 1, y + 10, w - 2, 1, Color(Palette.TUNIC.lightened(0.20), 0.28))

static func _draw_body(img: Image, dir: int, top: int, arm: int) -> void:
	var y := top + 18
	var lit := Palette.TUNIC.lightened(0.16)
	var hi := Palette.TUNIC.lightened(0.30)
	var belt := Palette.BOOTS.darkened(0.12)
	if dir == Dir.SIDE:
		Pixel.rect(img, 10, y, 13, 15, Palette.TUNIC)
		Pixel.rect(img, 9, y + 1, 1, 3, Palette.TUNIC)
		Pixel.rect(img, 10, y, 4, 15, lit)
		Pixel.rect(img, 19, y, 4, 15, Palette.TUNIC_DARK)
		# Stoffwurf
		Pixel.rect(img, 14, y + 4, 1, 9, Palette.TUNIC_DARK)
		Pixel.rect(img, 17, y + 2, 1, 11, Palette.TUNIC.lightened(0.08))
		_folds(img, 10, 13, y)
		Pixel.rect(img, 10, y + 12, 13, 3, belt)
		Pixel.rect(img, 10, y + 12, 13, 1, belt.lightened(0.22))
		Pixel.rect(img, 10, y + 11, 13, 1, Color(Palette.TUNIC_DARK, 0.45))
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
	# Schultern eine Spur breiter als die Taille. Ein Rechteck von Hals bis
	# Guertel hat keine Haltung; schon ein einziger Bildpunkt Ausladung oben
	# macht aus dem Rumpf eine Gestalt mit Schultern.
	Pixel.rect(img, 7, y + 1, 1, 3, Palette.TUNIC)
	Pixel.rect(img, 24, y + 1, 1, 3, Palette.TUNIC_DARK)
	Pixel.rect(img, 8, y, 5, 15, lit)
	Pixel.rect(img, 9, y, 2, 15, hi)
	Pixel.rect(img, 20, y, 4, 15, Palette.TUNIC_DARK)
	_folds(img, 8, 16, y)
	Pixel.rect(img, 8, y + 12, 16, 3, belt)
	# Lichtkante oben auf dem Guertel, Schatten des Guertels auf dem Stoff
	# darueber: erst dadurch liegt er AUF der Tunika statt in ihr zu stecken.
	Pixel.rect(img, 8, y + 12, 16, 1, belt.lightened(0.22))
	Pixel.rect(img, 8, y + 11, 16, 1, Color(Palette.TUNIC_DARK, 0.45))
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
