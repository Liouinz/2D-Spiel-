class_name Lighting
extends Node2D

## Beleuchtung in *einem* Zeichenaufruf.
##
## Vorher: bis zu 48 PointLight2D. Die GL-Compatibility-Pipeline zeichnet jedes
## Canvas-Element einmal pro überlappendem Licht — Tilemap, Siedler und Effekte
## wurden nachts also dutzendfach neu gerastert. Gemessen kostete allein das
## +12,2 ms pro Bild und war damit der komplette Tag/Nacht-Unterschied.
##
## Jetzt: eine Lightmap in Kachelauflösung. Sie wird nur neu berechnet, wenn
## sich wirklich etwas ändert (Zeit, Kameraausschnitt, Lichtquellen) und nur
## für den sichtbaren Bereich plus Rand. Gezeichnet wird sie als eine einzige
## multiplizierende Textur über die Welt — konstante Kosten, unabhängig von
## der Zahl der Lichtquellen.

const CELL_PADDING := 2

## Umgebungslicht: Tag → warmes Abendlicht → tiefe, blaue Nacht.
const AMBIENT_DAY := Color(1.0, 1.0, 1.0)
const AMBIENT_DUSK := Color(0.86, 0.70, 0.58)
const AMBIENT_NIGHT := Color(0.13, 0.17, 0.32)

var sim: Simulation
var quality: Quality

var _tex: ImageTexture
var _img: Image
var _buf := PackedByteArray()
var _cells := Vector2i.ZERO
var _cell_size := 16.0
var _origin_px := Vector2.ZERO
var _timer := 0.0
var _ambient_buf := PackedByteArray()
var _ambient_key := Color.TRANSPARENT
var _bursts: Array = []
var _sources: Array = []
var _active_sources := 0
var _found_sources := 0
var _rebuild_texture := true
## Eigene Messwerte fürs Entwickler-Overlay: Wie teuer ist die Lightmap
## wirklich? Geraten wird hier nichts.
var last_update_ms := 0.0
var updates_per_second := 0.0
var _update_count := 0
var _stats_window := 0.0


func _init(sim_ref: Simulation, quality_ref: Quality) -> void:
	sim = sim_ref
	quality = quality_ref
	z_index = 90
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat


func _ready() -> void:
	quality.changed.connect(_on_quality_changed)
	_on_quality_changed()


func _on_quality_changed() -> void:
	var per_tile: int = quality.get_value("light_cells_per_tile")
	_cell_size = float(Terrain.TILE) / maxf(1.0, float(per_tile))
	_rebuild_texture = true


## Kurzlebige Lichtblitze (Blitzschlag, Meteor-Einschlag).
func add_burst(world_pos: Vector2, color: Color, radius: float, ttl: float, energy: float = 1.0) -> void:
	_bursts.append({
		"pos": world_pos, "color": color, "radius": radius,
		"ttl": ttl, "max_ttl": ttl, "energy": energy,
	})


func active_sources() -> int:
	return _active_sources


## Wie viele Quellen im Fenster lagen, bevor das Budget gegriffen hat.
func found_sources() -> int:
	return _found_sources


func lightmap_cells() -> int:
	return _cells.x * _cells.y


func _process(delta: float) -> void:
	var night := sim.night_factor()
	for i in range(_bursts.size() - 1, -1, -1):
		_bursts[i].ttl -= delta
		if _bursts[i].ttl <= 0.0:
			_bursts.remove_at(i)
	# Bei Tag ohne Blitz gibt es nichts abzudunkeln: Knoten komplett aus.
	if night <= 0.02 and _bursts.is_empty() and sim.rain_areas.is_empty():
		if visible:
			visible = false
			_active_sources = 0
			_found_sources = 0
		return
	visible = true
	var hz: float = quality.get_value("light_hz")
	_timer -= delta
	_update_window_stats(delta)
	# Neu gerechnet wird nur, wenn der Takt es verlangt, ein Blitz aktiv ist —
	# oder die Kamera aus dem berechneten Fenster gelaufen ist. Zwischendurch
	# bleibt die Textur *an ihrem Weltort stehen*; sie mit der Kamera
	# mitzuziehen, ohne sie neu zu rechnen, würde das Licht verschieben.
	if _timer > 0.0 and _bursts.is_empty() and _covers_view():
		return
	_timer = 1.0 / maxf(4.0, hz)
	_fit_window()
	var started := Time.get_ticks_usec()
	_render_lightmap(night)
	last_update_ms = (Time.get_ticks_usec() - started) * 0.001
	_update_count += 1
	queue_redraw()


func _update_window_stats(delta: float) -> void:
	_stats_window += delta
	if _stats_window >= 1.0:
		updates_per_second = _update_count / _stats_window
		_update_count = 0
		_stats_window = 0.0


## Deckt die zuletzt berechnete Lightmap den sichtbaren Bereich noch ab?
func _covers_view() -> bool:
	if _tex == null or _cells == Vector2i.ZERO:
		return false
	return Rect2(_origin_px, Vector2(_cells) * _cell_size).encloses(View.world_rect(self))


## Legt Fenster (Ursprung + Zellenzahl) für die nächste Berechnung fest:
## sichtbarer Bereich plus Rand, am Zellenraster ausgerichtet.
func _fit_window() -> void:
	var view := View.world_rect(self)
	var margin: int = quality.get_value("light_margin")
	var pad := float(margin) * Terrain.TILE
	var start := Vector2(
		floorf((view.position.x - pad) / _cell_size),
		floorf((view.position.y - pad) / _cell_size)
	)
	_origin_px = start * _cell_size
	var needed := Vector2i(
		int(ceilf((view.size.x + pad * 2.0) / _cell_size)) + CELL_PADDING,
		int(ceilf((view.size.y + pad * 2.0) / _cell_size)) + CELL_PADDING
	)
	if needed != _cells or _rebuild_texture or _tex == null:
		_cells = needed
		_buf.resize(_cells.x * _cells.y * 3)
		_ambient_buf.resize(_buf.size())
		_ambient_key = Color.TRANSPARENT
		_img = Image.create(_cells.x, _cells.y, false, Image.FORMAT_RGB8)
		_tex = ImageTexture.create_from_image(_img)
		_rebuild_texture = false


# --- Berechnung -------------------------------------------------------------

func _render_lightmap(night: float) -> void:
	var ambient := AMBIENT_DAY.lerp(AMBIENT_DUSK, clampf(night * 2.0, 0.0, 1.0)) \
		.lerp(AMBIENT_NIGHT, clampf(night * 2.0 - 1.0, 0.0, 1.0))
	var w := _cells.x
	var h := _cells.y
	# Der Umgebungs-Untergrund ändert sich nur langsam. Statt ihn jedes Mal
	# Zelle für Zelle zu schreiben, wird er einmal pro Farbwert gebaut und
	# danach nur noch kopiert (ein memcpy statt ~16 000 Einzelzugriffen).
	if not ambient.is_equal_approx(_ambient_key):
		_ambient_key = ambient
		var ar := int(ambient.r * 255.0)
		var ag := int(ambient.g * 255.0)
		var ab := int(ambient.b * 255.0)
		for i in w * h:
			var o := i * 3
			_ambient_buf[o] = ar
			_ambient_buf[o + 1] = ag
			_ambient_buf[o + 2] = ab
	_buf = _ambient_buf.duplicate()
	_collect_sources(night)
	for src in _sources:
		_splat(src)
	# Regen dämpft das Licht darunter. Additiv geht das nicht, deshalb ein
	# eigener, multiplikativer Durchgang über die Regengebiete im Fenster.
	if quality == null or bool(quality.get_value("rain_shading")):
		var rect := Rect2(_origin_px, Vector2(_cells) * _cell_size)
		for area in sim.rain_areas:
			var radius: float = area.radius
			if rect.intersects(Rect2(area.pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0)):
				_shade_splat(area.pos, radius, 0.30)
	_img.set_data(w, h, false, Image.FORMAT_RGB8, _buf)
	_tex.update(_img)


## Additiver Splat mit quadratischem Abfall. Nur Zellen innerhalb des Radius
## werden berührt — der Aufwand hängt am Lichtradius, nicht an der Kartengrösse.
func _splat(src: Dictionary) -> void:
	var w := _cells.x
	var h := _cells.y
	var local: Vector2 = (src.pos - _origin_px) / _cell_size
	var radius: float = src.radius / _cell_size
	if radius <= 0.5:
		return
	var x0 := maxi(int(floorf(local.x - radius)), 0)
	var x1 := mini(int(ceilf(local.x + radius)), w - 1)
	var y0 := maxi(int(floorf(local.y - radius)), 0)
	var y1 := mini(int(ceilf(local.y + radius)), h - 1)
	if x0 > x1 or y0 > y1:
		return
	var color: Color = src.color
	var energy: float = src.energy
	var inv_r2 := 1.0 / (radius * radius)
	var cr := color.r * energy * 255.0
	var cg := color.g * energy * 255.0
	var cb := color.b * energy * 255.0
	for cy in range(y0, y1 + 1):
		var dy := cy + 0.5 - local.y
		var dy2 := dy * dy
		var row := cy * w
		for cx in range(x0, x1 + 1):
			var dx := cx + 0.5 - local.x
			var d2 := (dx * dx + dy2) * inv_r2
			if d2 >= 1.0:
				continue
			var falloff := (1.0 - d2)
			falloff *= falloff
			var o := (row + cx) * 3
			_buf[o] = mini(_buf[o] + int(cr * falloff), 255)
			_buf[o + 1] = mini(_buf[o + 1] + int(cg * falloff), 255)
			_buf[o + 2] = mini(_buf[o + 2] + int(cb * falloff), 255)


## Multiplikativer Gegenpol zum Splat: dunkelt einen Bereich weich ab.
func _shade_splat(center: Vector2, radius_px: float, strength: float) -> void:
	var w := _cells.x
	var h := _cells.y
	var local := (center - _origin_px) / _cell_size
	var radius := radius_px / _cell_size
	if radius <= 0.5:
		return
	var x0 := maxi(int(floorf(local.x - radius)), 0)
	var x1 := mini(int(ceilf(local.x + radius)), w - 1)
	var y0 := maxi(int(floorf(local.y - radius)), 0)
	var y1 := mini(int(ceilf(local.y + radius)), h - 1)
	var inv_r2 := 1.0 / (radius * radius)
	for cy in range(y0, y1 + 1):
		var dy := cy + 0.5 - local.y
		var dy2 := dy * dy
		var row := cy * w
		for cx in range(x0, x1 + 1):
			var dx := cx + 0.5 - local.x
			var d2 := (dx * dx + dy2) * inv_r2
			if d2 >= 1.0:
				continue
			var factor := 1.0 - strength * (1.0 - d2)
			var o := (row + cx) * 3
			_buf[o] = int(_buf[o] * factor)
			_buf[o + 1] = int(_buf[o + 1] * factor)
			_buf[o + 2] = int(_buf[o + 2] * factor)


## Sammelt alle Lichtquellen im Fenster, sortiert nach Nähe zur Bildmitte und
## begrenzt sie auf das Budget des Grafikprofils.
func _collect_sources(night: float) -> void:
	_sources.clear()
	var max_sources: int = quality.get_value("light_max_sources")
	var rect := Rect2(_origin_px, Vector2(_cells) * _cell_size)
	var time := Time.get_ticks_msec() * 0.001
	var strength := clampf(night, 0.0, 1.0)

	for v in sim.villages:
		if v.fallen:
			continue
		_try_add(rect, v.center_pos + Vector2(0, -2), Palette.LIGHT_FIRE,
			9.0 * Terrain.TILE, 0.95 * strength, 0.16, time + v.id * 1.7)
		for hut in v.huts:
			_try_add(rect, Vector2(hut) * Terrain.TILE + Vector2(8, 9), Palette.LIGHT_WINDOW,
				3.6 * Terrain.TILE, 0.42 * strength, 0.05, time + hut.x * 0.7 + hut.y)

	for torch in sim.torches:
		_try_add(rect, torch.pos + Vector2(0, -6), Palette.LIGHT_TORCH,
			torch.radius, torch.energy * strength, 0.26, time + torch.phase)

	# Lava leuchtet auch tagsüber — deshalb ohne `strength`.
	for cell in sim.lava_cells():
		_try_add(rect, Vector2(cell) * Terrain.TILE + Vector2(8, 8), Palette.LIGHT_LAVA,
			3.2 * Terrain.TILE, 0.55, 0.22, time + cell.x * 0.3 + cell.y * 0.5)

	for burst in _bursts:
		var fade: float = clampf(burst.ttl / burst.max_ttl, 0.0, 1.0)
		_try_add(rect, burst.pos, burst.color, burst.radius, burst.energy * fade, 0.0, 0.0)

	_found_sources = _sources.size()
	if _sources.size() > max_sources:
		# Budget erschöpft: die Lichter nächst der Bildmitte gewinnen, damit
		# die Auswahl beim Schwenken ruhig bleibt statt zu flackern.
		var center := rect.position + rect.size * 0.5
		_sources.sort_custom(func(a, b):
			return a.pos.distance_squared_to(center) < b.pos.distance_squared_to(center))
		_sources.resize(max_sources)
	_active_sources = _sources.size()


func _try_add(rect: Rect2, pos: Vector2, color: Color, radius: float, energy: float, flicker: float, phase: float) -> void:
	if energy <= 0.01:
		return
	if not rect.intersects(Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0)):
		return
	var value := energy
	if flicker > 0.0:
		value *= 1.0 + sin(phase * 7.3) * flicker + sin(phase * 17.1) * flicker * 0.4
	_sources.append({"pos": pos, "color": color, "radius": radius, "energy": maxf(value, 0.0)})


func _draw() -> void:
	if _tex == null:
		return
	draw_texture_rect(_tex, Rect2(_origin_px, Vector2(_cells) * _cell_size), false)
