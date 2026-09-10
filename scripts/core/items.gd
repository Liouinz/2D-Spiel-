class_name Items
extends RefCounted

## Die Schnellleisten-Einträge. Bewusst schlank gehalten: laut Auftrag sind
## Sand/Gras/Wasser Prototyp-Werkzeuge, kein Loot-System. Wichtig ist nur, dass
## Auswahl, Icon und Setzen/Entfernen verlässlich funktionieren.

enum Kind { TERRAIN, TORCH, TRIBE, POWER }

enum Power { LIGHTNING, RAIN, BLESSING, METEOR }

const ITEMS: Array[Dictionary] = [
	{"name": "Gras", "kind": Kind.TERRAIN, "type": Terrain.T_GRASS, "cost": 0.0,
		"tip": "Malt Grasland. Sammler finden hier Nahrung."},
	{"name": "Wald", "kind": Kind.TERRAIN, "type": Terrain.T_FOREST, "cost": 0.0,
		"tip": "Pflanzt Wald. Holzfäller schlagen hier Holz; Wald breitet sich selbst aus."},
	{"name": "Sand", "kind": Kind.TERRAIN, "type": Terrain.T_SAND, "cost": 0.0,
		"tip": "Streut Sand. Regen lässt ihn wieder ergrünen."},
	{"name": "Wasser", "kind": Kind.TERRAIN, "type": Terrain.T_WATER_DEEP, "cost": 0.0,
		"tip": "Flutet Land. Flaches Ufer entsteht automatisch am Rand."},
	{"name": "Fels", "kind": Kind.TERRAIN, "type": Terrain.T_ROCK, "cost": 0.0,
		"tip": "Türmt Fels auf. Unfruchtbar, aber begehbar."},
	{"name": "Fackel", "kind": Kind.TORCH, "type": -1, "cost": 0.0,
		"tip": "Setzt eine Fackel: warmes, flackerndes Licht mit begrenzter Reichweite."},
	{"name": "Volk", "kind": Kind.TRIBE, "type": -1, "cost": 0.0,
		"tip": "Setzt ein neues Volk aus. Es gründet ein benanntes Lager."},
	{"name": "Blitz", "kind": Kind.POWER, "type": Power.LIGHTNING, "cost": 10.0,
		"tip": "Erschlägt Siedler, zerstört Hütten, verbrennt Land."},
	{"name": "Regen", "kind": Kind.POWER, "type": Power.RAIN, "cost": 6.0,
		"tip": "Lässt Sand ergrünen, Wald sprießen und kühlt Lava zu Fels."},
	{"name": "Segen", "kind": Kind.POWER, "type": Power.BLESSING, "cost": 8.0,
		"tip": "Füllt die Speicher eines Dorfes und macht es fruchtbar."},
	{"name": "Meteor", "kind": Kind.POWER, "type": Power.METEOR, "cost": 40.0,
		"tip": "Schlägt ein, hinterlässt einen glühenden Krater."},
]


static func count() -> int:
	return ITEMS.size()


static func get_item(index: int) -> Dictionary:
	return ITEMS[clampi(index, 0, ITEMS.size() - 1)]


static func item_name(index: int) -> String:
	return get_item(index).name


## Kleines 16×16-Icon je Eintrag, aus derselben Palette wie die Welt.
static func build_icon(index: int) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var item := get_item(index)
	match item.kind:
		Kind.TERRAIN:
			_fill_terrain(img, item.type)
		Kind.TORCH:
			_rect(img, 7, 5, 2, 10, Palette.TORCH_STICK)
			_rect(img, 6, 2, 4, 4, Palette.LIGHT_TORCH)
			_rect(img, 7, 1, 2, 2, Color(1.0, 0.94, 0.72))
		Kind.TRIBE:
			_rect(img, 6, 6, 4, 6, Palette.TUNIC_GATHERER)
			_rect(img, 7, 3, 3, 3, Palette.SKIN)
			_rect(img, 4, 12, 8, 2, Palette.SHADOW)
		Kind.POWER:
			_power_icon(img, item.type)
	return ImageTexture.create_from_image(img)


static func _fill_terrain(img: Image, type: int) -> void:
	var kind: int = Terrain.GROUND_KIND[type]
	var ground := Palette.SAND
	match kind:
		TileArt.K_SEABED: ground = Palette.SEABED_DEEP
		TileArt.K_GRASS: ground = Palette.GRASS
		TileArt.K_ROCK: ground = Palette.ROCK
	for y in 16:
		for x in 16:
			var shade := 0.06 if y < 3 else (-0.09 if y > 12 else 0.0)
			img.set_pixel(x, y, Palette.shade(ground, shade))
	match type:
		Terrain.T_WATER_DEEP, Terrain.T_WATER_SHALLOW:
			for y in range(2, 14):
				for x in range(2, 14):
					if Vector2(x - 7.5, y - 7.5).length() < 6.0:
						img.set_pixel(x, y, Palette.WATER_DEEP)
			_rect(img, 4, 5, 5, 1, Palette.WATER_FOAM)
		Terrain.T_FOREST:
			for y in range(2, 12):
				for x in range(3, 13):
					if Vector2(x - 7.5, y - 6.5).length() < 4.6:
						img.set_pixel(x, y, Palette.CANOPY)
			_rect(img, 7, 10, 2, 4, Palette.TRUNK)
		Terrain.T_GRASS:
			for i in 4:
				_rect(img, 3 + i * 3, 5 + (i % 2) * 3, 1, 3, Palette.GRASS_LIGHT)
		Terrain.T_ROCK:
			_rect(img, 4, 7, 4, 3, Palette.ROCK_LIGHT)
			_rect(img, 9, 9, 3, 3, Palette.ROCK_DARK)
		Terrain.T_SAND:
			for i in 5:
				img.set_pixel(3 + i * 2, 6 + (i % 3) * 3, Palette.SAND_DARK)


static func _power_icon(img: Image, power: int) -> void:
	match power:
		Power.LIGHTNING:
			var pts := [Vector2i(9, 1), Vector2i(8, 5), Vector2i(10, 5), Vector2i(6, 14)]
			for i in 3:
				_line(img, pts[i], pts[i + 1], Palette.FLASH, 2)
		Power.RAIN:
			_rect(img, 3, 3, 10, 4, Palette.RAIN_CLOUD)
			_rect(img, 5, 2, 6, 2, Palette.shade(Palette.RAIN_CLOUD, 0.10))
			for i in 4:
				_rect(img, 4 + i * 3, 9 + (i % 2) * 2, 1, 3, Palette.SPARK_WATER)
		Power.BLESSING:
			for y in 16:
				for x in 16:
					var d := Vector2(x - 7.5, y - 7.5).length()
					if d < 4.0:
						img.set_pixel(x, y, Palette.BLESSING)
					elif d < 6.5 and (x + y) % 2 == 0:
						img.set_pixel(x, y, Color(Palette.BLESSING.r, Palette.BLESSING.g, Palette.BLESSING.b, 0.55))
		Power.METEOR:
			for y in 16:
				for x in 16:
					if Vector2(x - 9.5, y - 6.5).length() < 4.2:
						img.set_pixel(x, y, Palette.LAVA)
					elif Vector2(x - 9.5, y - 6.5).length() < 5.4:
						img.set_pixel(x, y, Palette.LAVA_HOT)
			_line(img, Vector2i(4, 14), Vector2i(8, 9), Palette.IMPACT_OUTER, 2)


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, mini(y + h, 16)):
		for px in range(x, mini(x + w, 16)):
			if px >= 0 and py >= 0:
				img.set_pixel(px, py, color)


static func _line(img: Image, from: Vector2i, to: Vector2i, color: Color, width: int) -> void:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i in range(steps + 1):
		var t := float(i) / maxf(steps, 1)
		var p := Vector2(from).lerp(Vector2(to), t)
		_rect(img, int(p.x), int(p.y), width, width, color)
