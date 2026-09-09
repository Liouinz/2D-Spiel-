class_name Pixel
extends RefCounted
## Kleine Zeichen-Werkzeuge für Images. Basis aller Grafiken (§3: ein Stil für alles).

const FMT := Image.FORMAT_RGBA8

## Kantenumlauf für nahtlose Kacheln.
##
## Ist `wrap` grösser als null, laufen alle Zeichenoperationen am Rand um: was
## rechts hinausragt, kommt links wieder herein. Weil jede Zeichenoperation
## dieser Datei durch `px()` läuft, werden dadurch Ellipsen, Rechtecke, Linien,
## Körnung und Platten in einem Zug nahtlos — ohne dass eine einzige
## Kachelfunktion umgeschrieben werden muss.
##
## Nur die Bodenkacheln setzen das. Figuren und Oberfläche dürfen
## NICHT umlaufen, sonst klebte ein Baumwipfel unten am Bild.
static var wrap: int = 0

static func make(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, FMT)
	img.fill(Color(0, 0, 0, 0))
	return img

static func filled(w: int, h: int, c: Color) -> Image:
	var img := Image.create(w, h, false, FMT)
	img.fill(c)
	return img

## Setzt ein Pixel mit Alpha-Blending und Bereichsprüfung.
static func px(img: Image, x: int, y: int, c: Color) -> void:
	if c.a <= 0.0:
		return
	if wrap > 0:
		x = posmod(x, wrap)
		y = posmod(y, wrap)
	elif x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if c.a >= 1.0:
		img.set_pixel(x, y, c)
		return
	var dst := img.get_pixel(x, y)
	var a := c.a + dst.a * (1.0 - c.a)
	if a <= 0.0:
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var r := (c.r * c.a + dst.r * dst.a * (1.0 - c.a)) / a
	var g := (c.g * c.a + dst.g * dst.a * (1.0 - c.a)) / a
	var b := (c.b * c.a + dst.b * dst.a * (1.0 - c.a)) / a
	img.set_pixel(x, y, Color(r, g, b, a))

static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, y + h):
		for ix in range(x, x + w):
			px(img, ix, iy, c)

static func hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	rect(img, x, y, w, 1, c)

static func vline(img: Image, x: int, y: int, h: int, c: Color) -> void:
	rect(img, x, y, 1, h, c)

static func ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for iy in range(y0, y1 + 1):
		for ix in range(x0, x1 + 1):
			var dx := (ix + 0.5 - cx) / maxf(rx, 0.001)
			var dy := (iy + 0.5 - cy) / maxf(ry, 0.001)
			if dx * dx + dy * dy <= 1.0:
				px(img, ix, iy, c)

static func circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	ellipse(img, cx, cy, r, r, c)

## Gefülltes Dreieck über Zeilen-Interpolation (für Dächer und Tannen).
static func triangle(img: Image, ax: float, ay: float, bx: float, by: float, cx: float, cy: float, col: Color) -> void:
	var min_y := int(floor(minf(ay, minf(by, cy))))
	var max_y := int(ceil(maxf(ay, maxf(by, cy))))
	var min_x := int(floor(minf(ax, minf(bx, cx))))
	var max_x := int(ceil(maxf(ax, maxf(bx, cx))))
	var d := (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
	if is_zero_approx(d):
		return
	for iy in range(min_y, max_y + 1):
		for ix in range(min_x, max_x + 1):
			var pxf := ix + 0.5
			var pyf := iy + 0.5
			var w1 := ((by - cy) * (pxf - cx) + (cx - bx) * (pyf - cy)) / d
			var w2 := ((cy - ay) * (pxf - cx) + (ax - cx) * (pyf - cy)) / d
			var w3 := 1.0 - w1 - w2
			if w1 >= -0.001 and w2 >= -0.001 and w3 >= -0.001:
				px(img, ix, iy, col)

## Ein Pixel-Outline rund um alles Sichtbare — der wichtigste Stil-Klebstoff.
##
## Liest den Alphakanal einmal als Rohpuffer statt über get_pixel(). Bei den
## 32er-Grafiken hat eine 64er-Grafik die vierfache Pixelzahl; der Unterschied
## macht bei rund 90 Bildern mehrere hundert Millisekunden aus.
static func outline(img: Image, c: Color, threshold: float = 0.35) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var lim := int(threshold * 255.0)
	for y in h:
		var row := y * w
		for x in w:
			var i := row + x
			if data[i * 4 + 3] > lim:
				continue
			var touches := (x > 0 and data[(i - 1) * 4 + 3] > lim) \
				or (x < w - 1 and data[(i + 1) * 4 + 3] > lim) \
				or (y > 0 and data[(i - w) * 4 + 3] > lim) \
				or (y < h - 1 and data[(i + w) * 4 + 3] > lim)
			if touches:
				img.set_pixel(x, y, c)

static func tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

