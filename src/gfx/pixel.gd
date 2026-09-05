class_name Pixel
extends RefCounted
## Kleine Zeichen-Werkzeuge für Images. Basis aller Grafiken (§3: ein Stil für alles).

const FMT := Image.FORMAT_RGBA8

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
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height() or c.a <= 0.0:
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
## 32er-Grafiken hat jede Requisite die vierfache Pixelzahl; der Unterschied
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

## --- Schattierung -----------------------------------------------------------

## Geordnete 4x4-Bayer-Matrix: erzeugt Pixel-Art-Verläufe statt weicher Kanten.
const BAYER := [
	[0.0, 8.0, 2.0, 10.0],
	[12.0, 4.0, 14.0, 6.0],
	[3.0, 11.0, 1.0, 9.0],
	[15.0, 7.0, 13.0, 5.0],
]

static func bayer(x: int, y: int) -> float:
	return BAYER[posmod(y, 4)][posmod(x, 4)] / 16.0

## Ersetzt sichtbare Pixel durch eine Farbrampe, abhängig vom Abstand zur
## Lichtquelle. Zwischen den Stufen wird gedithert — das ist der Kern des Stils.
## `region` begrenzt die Wirkung; leer = ganzes Bild.
static func shade_ramp(img: Image, ramp: Array, light: Vector2, radius: float,
		region: Rect2i = Rect2i()) -> void:
	var steps := ramp.size()
	var r := region
	if r.size.x <= 0 or r.size.y <= 0:
		r = Rect2i(0, 0, img.get_width(), img.get_height())
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var w := img.get_width()
	var data := img.get_data()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if data[(y * w + x) * 4 + 3] == 0:
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(light) / maxf(radius, 0.001)
			var v := clampf(d, 0.0, 0.999) * (steps - 1)
			var band := int(v)
			# Dithering am Übergang zweier Stufen
			if v - band > bayer(x, y) and band < steps - 1:
				band += 1
			var col: Color = ramp[band]
			img.set_pixel(x, y, Color(col.r, col.g, col.b, data[(y * w + x) * 4 + 3] / 255.0))

## Radiert kleine Kerben in die Silhouette, damit nichts wie ein Kreis aussieht.
static func notch(img: Image, rng: RandomNumberGenerator, count: int, cx: float, cy: float, rx: float, ry: float) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var px := cx + cos(a) * rx * rng.randf_range(0.75, 1.05)
		var py := cy + sin(a) * ry * rng.randf_range(0.75, 1.05)
		clear_ellipse(img, px, py, rng.randf_range(1.2, 2.6), rng.randf_range(1.2, 2.4))

static func clear_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for iy in range(y0, y1 + 1):
		for ix in range(x0, x1 + 1):
			if ix < 0 or iy < 0 or ix >= img.get_width() or iy >= img.get_height():
				continue
			var dx := (ix + 0.5 - cx) / maxf(rx, 0.001)
			var dy := (iy + 0.5 - cy) / maxf(ry, 0.001)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(ix, iy, Color(0, 0, 0, 0))

## Streut Farbtupfer nur innerhalb bereits sichtbarer Flächen.
static func speckle_opaque(img: Image, rng: RandomNumberGenerator, count: int, c: Color, y_min: int = 0, y_max: int = -1) -> void:
	var hi := img.get_height() if y_max < 0 else mini(y_max, img.get_height())
	for i in count:
		var x := rng.randi_range(0, img.get_width() - 1)
		var y := rng.randi_range(y_min, maxi(hi - 1, y_min))
		if img.get_pixel(x, y).a > 0.5:
			px(img, x, y, c)
