class_name AssetSheet
extends RefCounted
## Legt alle erzeugten Grafiken als Kontaktbogen ab. Nur für die Sichtprüfung
## während der Entwicklung — im Spiel wird davon nichts benutzt.

const PAD := 6
const COLS_MAX_W := 1400

## Schreibt props.png und actor.png nach `dir` und liefert die Reihenfolge zurück.
static func dump(dir: String, seed_value: int) -> Array[String]:
	var order: Array[String] = []
	var props := PropArt.build(seed_value)
	var images: Array[Image] = []
	var names: Array[String] = []
	var keys: Array = props.keys()
	keys.sort()
	for name: String in keys:
		var variants: Array = props[name]["variants"]
		for i in variants.size():
			var tex: Texture2D = variants[i]["tex"]
			images.append(tex.get_image())
			names.append("%s#%d" % [name, i])
		order.append("%s (%d)" % [name, variants.size()])
	_grid(images, dir.path_join("props.png"))

	var actor := ActorArt.build()
	var frames: Array[Image] = []
	for set_name: String in ["idle", "walk"]:
		var dirs: Array = actor[set_name]
		for d in dirs.size():
			var list: Array = dirs[d]
			for f: Texture2D in list:
				frames.append(f.get_image())
	_grid(frames, dir.path_join("actor.png"))
	print("Kontaktbogen: ", ", ".join(names))
	return order

static func _grid(images: Array[Image], path: String) -> void:
	if images.is_empty():
		return
	var cell_w := 0
	var cell_h := 0
	for im: Image in images:
		cell_w = maxi(cell_w, im.get_width())
		cell_h = maxi(cell_h, im.get_height())
	cell_w += PAD * 2
	cell_h += PAD * 2
	var cols := maxi(int(COLS_MAX_W / cell_w), 1)
	var rows := int(ceil(float(images.size()) / cols))
	var sheet := Image.create(cols * cell_w, rows * cell_h, false, Pixel.FMT)
	# Schachbrett als Hintergrund, damit Silhouetten und Ränder sichtbar sind
	for y in sheet.get_height():
		for x in sheet.get_width():
			var dark := ((x / 8) + (y / 8)) % 2 == 0
			sheet.set_pixel(x, y, Color8(64, 68, 76) if dark else Color8(78, 82, 92))
	for i in images.size():
		var im: Image = images[i]
		var cx := (i % cols) * cell_w + (cell_w - im.get_width()) / 2
		var cy := (i / cols) * cell_h + (cell_h - im.get_height()) / 2
		sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(cx, cy))
	sheet.save_png(path)
