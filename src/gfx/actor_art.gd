class_name ActorArt
extends RefCounted
## Erzeugt die Spielerfigur: 3 Blickrichtungen (unten/oben/seitlich),
## Idle-Atmen (2 Bilder) und Laufzyklus (4 Bilder). Rechts = gespiegelt links.
##
## 32 x 48 Pixel. Das Licht kommt wie bei allen Objekten von oben links: linke
## Körperseite heller, rechte abgedunkelt.

enum Dir { DOWN, UP, SIDE }

## Bein- und Armstellung je Laufbild. Oeffentlich, weil der Selbsttest die
## Stellung des gerade gezeichneten Bildes nachrechnet: schwingt der Arm und
## Bein nicht zusammen, sieht man es beim Laufen sofort.
const WALK_ARM: Array[int] = [0, 1, 0, -1]

## Kunstpixel je Weltpixel.
##
## Die Figur wird mit DOPPELTER Dichte gezeichnet und mit Faktor 0,5
## dargestellt. Ihre Groesse in der Welt bleibt damit genau dieselbe wie vorher
## (32 x 48 Weltpixel), aber sie besteht aus viermal so vielen Bildpunkten.
##
## Das geht nur auf, solange `0,5 * Kamerazoom` ganzzahlig ist — sonst faellt
## ein Kunstpixel auf anderthalb Bildschirmpunkte und die Figur flimmert an den
## Kanten. Deshalb sind die Zoomstufen 2/4/6 statt 1/2/3 (siehe
## `Config.ZOOM_STEPS`): bei Zoom 2 ist ein Kunstpixel genau ein
## Bildschirmpunkt, bei 4 zwei, bei 6 drei.
##
## Der Preis steht in derselben Zeile: die weiteste Ansicht von frueher (Zoom 1)
## gibt es nicht mehr. Mehr Bildpunkte auf derselben Flaeche und gleichzeitig
## mehr Flaeche im Bild ist kein Kompromiss, den man schliessen kann.
const ART := 2

const W := 32 * ART
const H := 48 * ART

## Weltgroesse der Figur — was `scale` daraus macht.
const DRAW_SCALE := 1.0 / float(ART)
## Wie tief die Figur beim Schwimmen einsinkt. player.gd verschiebt das Bild
## um denselben Wert nach unten, damit der Kopf an seiner Stelle bleibt.
const SWIM_SINK := 16 * ART

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
##     "shadow": Texture}
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
	return {"idle": idle, "walk": walk, "swim": swim, "jump": jump,
		"shadow": Pixel.tex(_shadow())}

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
	for y in range(line - 8, mini(line + 12, H)):
		if y < 0:
			continue
		for x in W:
			var dx := (x + 0.5 - cx) / 26.0
			var dy := (y + 0.5 - cy) / 7.2
			var d := sqrt(dx * dx + dy * dy)
			if d > 1.0 or d < 0.60:
				continue
			# Hinter der Figur verdeckt der Rücken die Welle.
			if y < line and img.get_pixel(x, y).a > 0.5:
				continue
			# Lücken je Phase — ein geschlossener Ring wäre ein Reifen.
			if (x * 5 + y * 3 + phase * 7) % 11 == 0:
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
			# Angezogen und gestreckt: Beine hoch, Körper und Kopf höher als
			# im Stand. Alle Werte in Kunstpixeln, also doppelt so gross wie
			# frueher — die Stellung selbst ist dieselbe.
			_draw_legs(img, dir, 0, 10)
			_draw_body(img, dir, 4, -6)
			_draw_head(img, dir, 4)
		JUMP_FALL:
			_draw_legs(img, dir, 1, 4)
			_draw_body(img, dir, 6, 6)
			_draw_head(img, dir, 6)
		_:
			# Gehockt: Körper tief, Beine kurz, Arme unten.
			_draw_legs(img, dir, 0, 6)
			_draw_body(img, dir, 14, 2)
			_draw_head(img, dir, 14)
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
	var img := Pixel.make(60, 28)
	Pixel.ellipse(img, 31.2, 15.2, 26.4, 12.4, Color(0, 0, 0, 0.09))
	Pixel.ellipse(img, 31.2, 15.2, 19.6, 9.0, Color(0, 0, 0, 0.14))
	Pixel.ellipse(img, 30.4, 14.4, 12.4, 5.6, Color(0, 0, 0, 0.18))
	# Vierte Stufe, erst bei doppelter Dichte moeglich: der Kontaktschatten
	# direkt unter den Fuessen. Er ist der Grund, warum eine Figur auf dem
	# Boden STEHT statt darauf zu liegen.
	Pixel.ellipse(img, 30.0, 14.0, 6.4, 2.6, Color(0, 0, 0, 0.16))
	return img

## leg: -1/0/1 = Beinstellung, bob: 0/1 = Auf-und-ab, arm: Armschwung
static func _frame(dir: int, leg: int, bob: int, arm: int) -> Image:
	var img := Pixel.make(W, H)
	var top := 8 + bob * 4
	_draw_legs(img, dir, leg)
	_draw_body(img, dir, top, arm * 4)
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
	if y < 0 or y >= H - 2:
		return
	Pixel.rect(img, x, y, w, 2, Color(Palette.PANTS.darkened(0.34), 0.55))
	Pixel.rect(img, x, y - 2, w, 1, Color(Palette.PANTS.lightened(0.24), 0.32))

## Ein Stiefel: Schaft, Lichtkante, Sohle, Schnuerung.
##
## Bei einfacher Dichte war ein Stiefel ein Rechteck mit einer hellen und einer
## dunklen Reihe. Vier Bildpunkte mehr Hoehe reichen fuer das, was einen
## Stiefel ausmacht: eine Sohle, die vorsteht, und ein Schaft, der geschnuert
## ist.
static func _boot(img: Image, x: int, y: int, w: int, shaded: bool) -> void:
	var body := Palette.BOOTS.darkened(0.2) if shaded else Palette.BOOTS
	Pixel.rect(img, x, y, w, 8, body)
	Pixel.rect(img, x, y, w, 2, body.lightened(0.22))
	# Schnuerung: zwei Kreuze im Schaft.
	for i in 2:
		Pixel.px(img, x + 2, y + 2 + i * 2, body.darkened(0.30))
		Pixel.px(img, x + w - 3, y + 2 + i * 2, body.darkened(0.30))
	# Sohle: eine Reihe dunkel, eine Reihe fast schwarz — sie steht vor.
	Pixel.rect(img, x - 1, y + 6, w + 1, 1, body.darkened(0.35))
	Pixel.rect(img, x - 1, y + 7, w + 1, 1, body.darkened(0.55))

## `tuck` zieht die Beine an: der Ansatz bleibt, die Fuesse kommen hoch. Damit
## wird aus derselben Zeichnung eine gehockte und eine gestreckte Stellung.
static func _draw_legs(img: Image, dir: int, leg: int, tuck: int = 0) -> void:
	var lit := Palette.PANTS.lightened(0.18)
	var dark := Palette.PANTS.darkened(0.24)
	var seam := Palette.PANTS.darkened(0.40)
	if dir == Dir.SIDE:
		var front := 22 + leg * 6
		var back := 28 - leg * 6
		# hinteres Bein
		Pixel.rect(img, back, 74, 14, maxi(14 - tuck, 4), dark)
		_boot(img, back, 86 - tuck, 16, true)
		# vorderes Bein
		Pixel.rect(img, front, 74, 14, maxi(14 - tuck, 4), lit)
		Pixel.rect(img, front, 74, 4, maxi(14 - tuck, 4), Palette.PANTS.lightened(0.3))
		_seam(img, front + 12, 76, maxi(10 - tuck, 2), true, seam)
		_knee(img, front, 14, 80 - tuck)
		_boot(img, front, 86 - tuck, 18, false)
		return
	var l_dy := 4 if leg > 0 else 0
	var r_dy := 4 if leg < 0 else 0
	# linkes Bein im Licht, rechtes im Schatten
	Pixel.rect(img, 20, 74 + l_dy, 12, maxi(14 - l_dy - tuck, 4), lit)
	Pixel.rect(img, 20, 74 + l_dy, 4, maxi(14 - l_dy - tuck, 4), Palette.PANTS.lightened(0.32))
	_seam(img, 20, 76 + l_dy, maxi(10 - l_dy - tuck, 2), true, seam)
	_knee(img, 20, 12, 80 + l_dy - tuck)
	_boot(img, 20, 88 - tuck, 12, false)
	Pixel.rect(img, 34, 74 + r_dy, 12, maxi(14 - r_dy - tuck, 4), dark)
	_seam(img, 45, 76 + r_dy, maxi(10 - r_dy - tuck, 2), true, seam)
	_knee(img, 34, 12, 80 + r_dy - tuck)
	_boot(img, 34, 88 - tuck, 12, true)

## Stofffalten auf der Tunika.
##
## Der Rumpf bestand einmal aus drei senkrechten Streifen — hell, mittel,
## dunkel. Das ist BELEUCHTUNG, keine Textur: es sagt, woher das Licht kommt,
## aber nichts darueber, dass da Stoff haengt. Bei doppelter Dichte ist Platz
## fuer eine Falte mit Kante UND Lichtseite statt einer einzelnen Linie.
static func _folds(img: Image, x0: int, w: int, y: int) -> void:
	var shade := Color(Palette.TUNIC_DARK, 0.30)
	var glint := Color(Palette.TUNIC.lightened(0.34), 0.22)
	Pixel.rect(img, x0 + 5, y + 8, 2, 14, shade)
	Pixel.rect(img, x0 + 7, y + 10, 1, 10, glint)
	Pixel.rect(img, x0 + w - 10, y + 6, 2, 16, shade)
	Pixel.rect(img, x0 + w - 8, y + 8, 1, 12, glint)
	# Saum ueber dem Guertel, in dem der Stoff aufliegt.
	Pixel.rect(img, x0 + 2, y + 20, w - 4, 1, Color(Palette.TUNIC.lightened(0.20), 0.28))
	Pixel.rect(img, x0 + 2, y + 21, w - 4, 1, Color(Palette.TUNIC_DARK, 0.20))

## Eine Naht: zwei Bildpunkte Stich, einer Luecke. Bei einfacher Dichte war das
## nicht darstellbar — eine Naht war dort einfach eine Linie.
static func _seam(img: Image, x: int, y: int, length: int, vertical: bool, c: Color) -> void:
	for i in length:
		if i % 3 == 2:
			continue
		if vertical:
			Pixel.px(img, x, y + i, c)
		else:
			Pixel.px(img, x + i, y, c)

static func _draw_body(img: Image, dir: int, top: int, arm: int) -> void:
	var y := top + 36
	var lit := Palette.TUNIC.lightened(0.16)
	var hi := Palette.TUNIC.lightened(0.30)
	var belt := Palette.BOOTS.darkened(0.12)
	var stitch := Palette.TUNIC_DARK.darkened(0.25)
	if dir == Dir.SIDE:
		# Der Rucksack ZUERST — er liegt hinter dem Rumpf, und die Figur schaut
		# nach rechts (die Nase steht bei x 47 vor). Er sass vorher bei x 38
		# bis 51, also VOR der Brust: von der Seite ein brauner Klotz auf dem
		# Bauch. Hinten heisst hier kleines x.
		_pack_side(img, y)
		Pixel.rect(img, 20, y, 26, 30, Palette.TUNIC)
		Pixel.rect(img, 18, y + 2, 2, 6, Palette.TUNIC)
		Pixel.rect(img, 20, y, 8, 30, lit)
		Pixel.rect(img, 38, y, 8, 30, Palette.TUNIC_DARK)
		# Stoffwurf
		Pixel.rect(img, 28, y + 8, 2, 18, Palette.TUNIC_DARK)
		Pixel.rect(img, 34, y + 4, 2, 22, Palette.TUNIC.lightened(0.08))
		_folds(img, 20, 26, y)
		_seam(img, 27, y + 2, 22, true, stitch)
		Pixel.rect(img, 20, y + 24, 26, 6, belt)
		Pixel.rect(img, 20, y + 24, 26, 1, belt.lightened(0.22))
		Pixel.rect(img, 20, y + 22, 26, 2, Color(Palette.TUNIC_DARK, 0.45))
		# Schultergurt ueber der Brust — das Einzige, was von einem
		# Rucksack seitlich nach VORNE sichtbar ist.
		Pixel.rect(img, 26, y + 1, 3, 16, Palette.WOOD_DARK)
		Pixel.rect(img, 26, y + 1, 1, 16, Palette.WOOD)
		Pixel.rect(img, 26, y + 10, 3, 2, Palette.WOOD.darkened(0.25))
		# sichtbarer Arm mit Aermelbund
		Pixel.rect(img, 24, y + 4 + arm, 10, 18, Palette.TUNIC_DARK)
		Pixel.rect(img, 24, y + 20 + arm, 10, 2, Palette.TUNIC_DARK.darkened(0.25))
		Pixel.rect(img, 24, y + 22 + arm, 10, 8, Palette.SKIN)
		Pixel.rect(img, 24, y + 22 + arm, 4, 8, Palette.SKIN.lightened(0.1))
		_fingers(img, 24, y + 24 + arm, false)
		return
	Pixel.rect(img, 16, y, 32, 30, Palette.TUNIC)
	# Schultern eine Spur breiter als die Taille.
	Pixel.rect(img, 14, y + 2, 2, 6, Palette.TUNIC)
	Pixel.rect(img, 48, y + 2, 2, 6, Palette.TUNIC_DARK)
	Pixel.rect(img, 16, y, 10, 30, lit)
	Pixel.rect(img, 18, y, 4, 30, hi)
	Pixel.rect(img, 40, y, 8, 30, Palette.TUNIC_DARK)
	_folds(img, 16, 32, y)
	Pixel.rect(img, 16, y + 24, 32, 6, belt)
	Pixel.rect(img, 16, y + 24, 32, 1, belt.lightened(0.22))
	Pixel.rect(img, 16, y + 22, 32, 2, Color(Palette.TUNIC_DARK, 0.45))
	# Guertelgrat: eine Reihe Riefen im Leder.
	for gx in range(18, 46, 4):
		Pixel.px(img, gx, y + 27, belt.darkened(0.25))
	if dir == Dir.DOWN:
		# Von vorne ist von einem Rucksack fast nichts zu sehen — nur die
		# beiden Gurte, die ueber die Schultern nach vorne kommen, und ein
		# Streifen der Tasche, der seitlich hervorschaut. Ein Rucksack, den man
		# von vorne als Block sieht, sitzt nicht auf dem Ruecken.
		Pixel.rect(img, 22, y, 3, 22, Palette.WOOD_DARK)
		Pixel.rect(img, 22, y, 1, 22, Palette.WOOD)
		Pixel.rect(img, 39, y, 3, 22, Palette.WOOD_DARK.darkened(0.15))
		Pixel.rect(img, 22, y + 12, 3, 2, Palette.WOOD.darkened(0.25))
		Pixel.rect(img, 39, y + 12, 3, 2, Palette.WOOD.darkened(0.30))
		# Die Kante der Tasche links und rechts neben dem Rumpf.
		Pixel.rect(img, 14, y + 6, 2, 14, Palette.WOOD_DARK.darkened(0.10))
		Pixel.rect(img, 48, y + 6, 2, 14, Palette.WOOD_DARK.darkened(0.30))
		# Kragen mit Umschlag
		Pixel.rect(img, 26, y, 12, 4, Palette.TUNIC_DARK)
		Pixel.rect(img, 26, y, 12, 1, Palette.TUNIC.lightened(0.22))
		Pixel.rect(img, 24, y + 2, 4, 3, Palette.TUNIC_DARK)
		Pixel.rect(img, 36, y + 2, 4, 3, Palette.TUNIC_DARK.darkened(0.15))
		# Schnuerung: Oesen mit Band dazwischen
		Pixel.rect(img, 31, y + 4, 2, 18, Palette.TUNIC_DARK)
		for i in 3:
			var ly := y + 6 + i * 6
			Pixel.rect(img, 28, ly, 8, 2, Palette.WOOD_LIGHT)
			Pixel.px(img, 28, ly, Palette.WOOD_LIGHT.lightened(0.25))
			Pixel.px(img, 35, ly + 1, Palette.WOOD_DARK)
		# Guertelschnalle mit Dorn
		Pixel.rect(img, 28, y + 24, 8, 6, Palette.UI_ACCENT)
		Pixel.rect(img, 30, y + 26, 4, 2, belt.darkened(0.3))
		Pixel.rect(img, 28, y + 24, 8, 1, Palette.UI_ACCENT.lightened(0.3))
		Pixel.px(img, 33, y + 27, Palette.UI_ACCENT.lightened(0.4))
	else:
		_seam(img, 31, y + 2, 20, true, stitch)
		_pack_back(img, y)
	# Arme: Aermel, Bund, Hand
	Pixel.rect(img, 8, y + 4 - arm, 10, 18, lit.darkened(0.06))
	Pixel.rect(img, 8, y + 20 - arm, 10, 2, Palette.TUNIC_DARK.darkened(0.20))
	Pixel.rect(img, 8, y + 22 - arm, 10, 8, Palette.SKIN)
	_fingers(img, 8, y + 24 - arm, false)
	Pixel.rect(img, 46, y + 4 + arm, 10, 18, Palette.TUNIC_DARK)
	Pixel.rect(img, 46, y + 20 + arm, 10, 2, Palette.TUNIC_DARK.darkened(0.30))
	Pixel.rect(img, 46, y + 22 + arm, 10, 8, Palette.SKIN_SHADE)
	_fingers(img, 46, y + 24 + arm, true)

## Der Rucksack von hinten.
##
## Er soll wie ein getragener Rucksack aussehen, nicht wie ein zweiter Koerper:
## deshalb 22 von 32 Bildpunkten Rumpfbreite, mittig, und mit den Teilen, an
## denen man einen Rucksack erkennt — Haupttasche, Klappe darueber, zwei
## Schultergurte, die ueber die Schultern nach vorne laufen, zwei Schnallen und
## Naehte.
static func _pack_back(img: Image, y: int) -> void:
	var leather := Palette.WOOD_DARK
	var leather_hi := Palette.WOOD
	var cord := Palette.WOOD_DARK.darkened(0.35)

	# Schultergurte: sie beginnen OBEN am Rumpf und laufen ueber die Schulter.
	for gx: int in [22, 39]:
		Pixel.rect(img, gx, y - 2, 3, 14, leather)
		Pixel.rect(img, gx, y - 2, 1, 14, leather_hi)
		Pixel.rect(img, gx, y + 6, 3, 2, cord)

	# Haupttasche.
	Pixel.rect(img, 21, y + 8, 22, 16, leather)
	Pixel.rect(img, 21, y + 8, 2, 16, leather_hi.darkened(0.10))
	Pixel.rect(img, 41, y + 8, 2, 16, cord)
	Pixel.rect(img, 21, y + 22, 22, 2, cord)

	# Klappe darueber, mit Ueberstand — daran erkennt man den Deckel.
	Pixel.rect(img, 20, y + 6, 24, 7, leather_hi)
	Pixel.rect(img, 20, y + 6, 24, 1, leather_hi.lightened(0.18))
	Pixel.rect(img, 20, y + 12, 24, 1, cord)

	# Zwei kleine Verschluesse an der Klappe.
	for bx: int in [26, 36]:
		Pixel.rect(img, bx, y + 11, 3, 4, cord)
		Pixel.px(img, bx + 1, y + 12, Palette.UI_ACCENT.darkened(0.15))

	# Naehte: dezent, nur an der Kante der Tasche.
	_seam(img, 23, y + 15, 8, false, cord)
	_seam(img, 33, y + 15, 8, false, cord)

## Der Rucksack von der Seite.
##
## Er wird VOR dem Rumpf gezeichnet und danach von ihm ueberdeckt — dadurch
## sitzt er hinten und liegt am Koerper an, statt daneben zu schweben. Sichtbar
## bleibt nur, was ueber die Rueckenlinie hinausragt.
static func _pack_side(img: Image, y: int) -> void:
	var leather := Palette.WOOD_DARK
	var leather_hi := Palette.WOOD
	var cord := Palette.WOOD_DARK.darkened(0.35)
	# Koerpernah: die rechte Kante liegt IM Rumpf (der beginnt bei x 20).
	Pixel.rect(img, 10, y + 6, 14, 20, leather)
	Pixel.rect(img, 10, y + 6, 2, 20, leather_hi.darkened(0.15))
	Pixel.rect(img, 10, y + 24, 14, 2, cord)
	# Klappe mit Ueberstand nach hinten.
	Pixel.rect(img, 9, y + 4, 15, 7, leather_hi)
	Pixel.rect(img, 9, y + 4, 15, 1, leather_hi.lightened(0.18))
	Pixel.rect(img, 9, y + 10, 15, 1, cord)
	# Verschluss.
	Pixel.rect(img, 12, y + 9, 3, 4, cord)
	Pixel.px(img, 13, y + 10, Palette.UI_ACCENT.darkened(0.15))

## Finger an einer Hand: drei Fugen, damit sie nicht als Klotz liest.
static func _fingers(img: Image, x: int, y: int, shaded: bool) -> void:
	var line := (Palette.SKIN_SHADE.darkened(0.32) if shaded
		else Palette.SKIN_SHADE.darkened(0.12))
	for i in 3:
		Pixel.rect(img, x + 1 + i * 3, y, 1, 5, Color(line, 0.55))

## Der Kopf.
##
## Bei doppelter Dichte ist Platz fuer das, was ein Gesicht ausmacht und vorher
## nicht hineinpasste: eine Pupille mit Lichtpunkt, eine Braue mit Richtung,
## eine Nase mit Schattenseite, ein Mund mit Mundwinkeln, und ein Haaransatz
## aus einzelnen Straehnen statt eines Blocks.
static func _draw_head(img: Image, dir: int, top: int) -> void:
	var hair_dark := Palette.HAIR.darkened(0.24)
	var hair_deep := Palette.HAIR.darkened(0.42)
	match dir:
		Dir.DOWN:
			Pixel.rect(img, 16, top + 8, 32, 28, Palette.SKIN)
			Pixel.rect(img, 40, top + 12, 8, 24, Palette.SKIN_SHADE)
			Pixel.rect(img, 16, top + 32, 32, 4, Palette.SKIN_SHADE)
			# Ohren: zwei Bildpunkte breit, mit Schattenkerbe.
			Pixel.rect(img, 14, top + 18, 2, 6, Palette.SKIN)
			Pixel.rect(img, 48, top + 18, 2, 6, Palette.SKIN_SHADE)
			Pixel.px(img, 15, top + 20, Palette.SKIN_SHADE)
			_hair_cap(img, top, hair_dark, hair_deep)
			# Pony: einzelne Straehnen an der Haarlinie.
			#
			# Sie duerfen nur wenig unterschiedlich lang sein. Beim ersten
			# Versuch schwankten sie zwischen drei und acht Bildpunkten und
			# schnitten tief in die Stirn — das las sich nicht als Haar,
			# sondern als ausgefranste Kante. Zwei Punkte Unterschied reichen,
			# damit die Linie lebt, ohne dass sie zerfaellt.
			for lock: Array in [[17, 3], [21, 4], [26, 3], [31, 5], [36, 3], [41, 4], [46, 3]]:
				Pixel.rect(img, int(lock[0]), top + 10, 4, int(lock[1]), Palette.HAIR)
			Pixel.rect(img, 16, top + 8, 32, 2, Palette.HAIR)
			# Augen: Weiss, Pupille, Lichtpunkt, Braue.
			for ex: int in [22, 36]:
				Pixel.rect(img, ex, top + 18, 6, 6, EYE_WHITE)
				Pixel.rect(img, ex + 2, top + 20, 3, 4, EYE)
				Pixel.px(img, ex + 2, top + 20, EYE_WHITE)
				Pixel.rect(img, ex, top + 23, 6, 1, Palette.SKIN_SHADE)
				Pixel.rect(img, ex - 1, top + 15, 8, 2, hair_dark)
				Pixel.px(img, ex - 1, top + 16, hair_deep)
			# Nase mit Schattenseite.
			Pixel.rect(img, 31, top + 24, 2, 3, Palette.SKIN_SHADE)
			Pixel.px(img, 33, top + 26, Palette.SKIN_SHADE.darkened(0.18))
			# Mund mit Winkeln.
			Pixel.rect(img, 29, top + 29, 6, 1, Palette.SKIN_SHADE.darkened(0.22))
			Pixel.px(img, 28, top + 28, Palette.SKIN_SHADE.darkened(0.10))
			Pixel.px(img, 35, top + 28, Palette.SKIN_SHADE.darkened(0.10))
			# Wangen.
			Pixel.rect(img, 19, top + 25, 3, 2, Color8(226, 158, 140))
			Pixel.rect(img, 43, top + 25, 3, 2, Color8(216, 148, 132))
		Dir.UP:
			Pixel.rect(img, 16, top + 8, 32, 28, Palette.SKIN_SHADE)
			Pixel.rect(img, 12, top, 40, 28, Palette.HAIR)
			Pixel.rect(img, 14, top, 20, 6, Palette.HAIR_LIGHT)
			Pixel.rect(img, 16, top + 6, 12, 4, Palette.HAIR_LIGHT)
			Pixel.rect(img, 44, top + 4, 8, 24, hair_dark)
			Pixel.rect(img, 16, top + 28, 32, 8, Palette.HAIR)
			# Nackenhaar: einzelne Spitzen statt einer Kante.
			for lock: Array in [[18, 3], [24, 5], [31, 3], [38, 5], [44, 2]]:
				Pixel.rect(img, int(lock[0]), top + 36, 3, int(lock[1]), hair_dark)
			Pixel.rect(img, 20, top + 34, 24, 2, hair_deep)
		Dir.SIDE:
			Pixel.rect(img, 16, top + 8, 32, 28, Palette.SKIN)
			Pixel.rect(img, 40, top + 12, 8, 20, Palette.SKIN_SHADE)
			Pixel.rect(img, 16, top + 32, 32, 4, Palette.SKIN_SHADE)
			Pixel.rect(img, 14, top, 34, 16, Palette.HAIR)
			# Der Hinterkopf laeuft bis zur Schulter durch. Ohne das klaffte
			# zwischen Haar und Rumpf eine Luecke, und der Umriss las sich als
			# abgetrennter Kiefer.
			Pixel.rect(img, 14, top + 12, 12, 24, Palette.HAIR)
			Pixel.rect(img, 16, top + 2, 18, 4, Palette.HAIR_LIGHT)
			Pixel.rect(img, 15, top + 14, 8, 3, hair_dark)
			Pixel.rect(img, 26, top + 30, 8, 6, Palette.SKIN_SHADE)
			Pixel.px(img, 47, top + 12, hair_dark)
			# Ohr im Profil: klein und weit hinten, sonst liegt es auf der Wange.
			Pixel.rect(img, 28, top + 19, 3, 5, Palette.SKIN_SHADE)
			Pixel.px(img, 29, top + 21, Palette.SKIN_SHADE.darkened(0.22))
			# Ein Auge, Braue, Nase, Mund.
			Pixel.rect(img, 34, top + 18, 6, 6, EYE_WHITE)
			Pixel.rect(img, 36, top + 20, 3, 4, EYE)
			Pixel.px(img, 36, top + 20, EYE_WHITE)
			Pixel.rect(img, 33, top + 15, 8, 2, hair_dark)
			Pixel.rect(img, 47, top + 20, 3, 3, Palette.SKIN)
			Pixel.px(img, 49, top + 22, Palette.SKIN_SHADE)
			Pixel.rect(img, 42, top + 28, 5, 1, Palette.SKIN_SHADE.darkened(0.22))

## Haarkappe mit Lichtseite — bei allen Blickrichtungen dieselbe Form.
static func _hair_cap(img: Image, top: int, hair_dark: Color, hair_deep: Color) -> void:
	Pixel.rect(img, 14, top, 36, 12, Palette.HAIR)
	Pixel.rect(img, 14, top + 12, 3, 12, Palette.HAIR)
	Pixel.rect(img, 47, top + 12, 3, 12, hair_dark)
	# Lichtseite oben links, zwei Straehnen.
	Pixel.rect(img, 16, top, 16, 3, Palette.HAIR_LIGHT)
	Pixel.rect(img, 18, top + 3, 9, 2, Palette.HAIR_LIGHT)
	Pixel.rect(img, 21, top + 1, 2, 5, Palette.HAIR_LIGHT.lightened(0.12))
	# Schattenseite rechts — als Verlauf, nicht als Block.
	Pixel.rect(img, 42, top + 1, 8, 9, hair_dark)
	Pixel.rect(img, 46, top + 3, 4, 6, hair_deep)
