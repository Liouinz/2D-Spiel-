class_name GridOverlay
extends Node2D
## Zeichnet Block- und Chunk-Raster über die Karte.
##
## Das Raster ist im fertigen Spiel unsichtbar — hier wird es absichtlich
## gezeigt, damit sich planen lässt, wie viele Blöcke ein Objekt belegt.
## Rot = einzelne Blöcke, Gelb = Chunk-Grenzen mit Nummer.
##
## Umschalten mit G. Wichtig: G schaltet nur die LINIEN aus, nicht den Knoten.
## Die Bauvorschau unter dem Mauszeiger bleibt immer sichtbar — das Raster
## dient dem Nachsehen, die Vorschau dem Bauen, und das sind zwei Dinge.
##
## Gezeichnet wird nur der sichtbare Ausschnitt.

## Die Rasterfarben sind bewusst zurückgenommen.
##
## Vorher waren die Blocklinien kräftig rot bei 30 % Deckkraft und die
## Chunk-Linien gelb bei 80 %. Über den ganzen Bildschirm gelegt sah die Welt
## damit aus wie Millimeterpapier — das ist der Eindruck eines
## Entwicklerwerkzeugs, nicht der eines Spiels. Zum Planen reicht eine Linie,
## die man sieht, wenn man sie sucht; sie muss nicht ins Auge springen.
##
## Die Funktion bleibt unverändert: G schaltet die Linien, die Bauvorschau
## bleibt davon unberührt, und der Block unter der Figur ist weiter markiert.
const BLOCK_LINE := Color(1.00, 1.00, 1.00, 0.055)
const CHUNK_LINE := Color(1.00, 0.85, 0.35, 0.30)
const CHUNK_TEXT := Color(1.00, 0.90, 0.50, 0.22)
const PLAYER_FILL := Color(1.00, 0.85, 0.45, 0.10)
const PLAYER_LINE := Color(1.00, 0.85, 0.45, 0.45)
## Die Bauvorschau war reinweiss bei 95 %. Auf einem Bildschirmfoto sahen die
## vier Eckwinkel aus wie vergessene Marker neben der Figur — sie hatten weder
## eine Farbe, die zum Spiel gehoert, noch etwas, worauf sie sich sichtbar
## bezogen. Warm statt weiss bindet sie an die uebrige Oberflaeche (dieselbe
## Akzentfarbe wie die gewaehlte Kachel in der Leiste), und der schwache
## Schleier im Feld gibt ihnen etwas, das sie einrahmen.
const CURSOR_LINE := Color(1.00, 0.86, 0.55, 0.85)
const CURSOR_GHOST := Color(1.00, 1.00, 1.00, 0.62)   ## Deckkraft des Geistbilds
## Ohne diesen Schleier ist die Vorschau unsichtbar, sobald das gewaehlte
## Material dem Boden darunter gleicht — Gras auf Gras. Dann standen nur noch
## die Winkel im Bild und zeigten auf nichts.
const CURSOR_FILL := Color(1.00, 0.90, 0.62, 0.10)
const BORDER := Color(1.00, 0.55, 0.25, 0.75)

## Linienstärken sind in BILDSCHIRMpunkten gemeint, nicht in Weltpixeln: eine
## Linie soll beim Hineinzoomen nicht mitwachsen. `_w()` rechnet sie um.
const LINE_THIN := 1.0
const LINE_THICK := 3.0
const BORDER_THICK := 3.0    ## Weltrand, ebenfalls in Bildschirmpunkten

var camera: GameCamera
var player: Node2D
var show_grid := Config.SHOW_BLOCK_GRID   ## nur die Linien, nicht die Vorschau
var cursor_block := Vector2i(-1, -1)      ## Vorschau der Bau-Leiste, -1 = aus
var cursor_tex: Texture2D                 ## gewählte Bodenkachel als Geistbild

func _init() -> void:
	z_index = 500          ## über allem, auch über Bäumen

## Bodenmarken: die Bauvorschau und der Block unter der Figur.
##
## Sie liegen UNTER der Spielfigur, während Raster, Chunk-Nummern und Weltrand
## darüber bleiben. Vorher lag alles zusammen bei z_index 500 — auch die
## Bauvorschau. Die ist aber eine halbdurchsichtige Kachel im Zielfeld, und das
## Zielfeld grenzt fast immer an die Figur: dadurch lag ein grüner Schleier über
## ihrer unteren Hälfte und die weissen Eckwinkel liefen quer durchs Gesicht.
## Die Figur sah durchsichtig aus.
##
## Eine Markierung auf dem Boden gehört auf den Boden. Sie darf von dem verdeckt
## werden, was darauf steht — genau das erwartet man auch.
class GroundMarks:
	extends Node2D
	var overlay: GridOverlay
	func _draw() -> void:
		if is_instance_valid(overlay):
			overlay.draw_marks(self)

var _marks: GroundMarks

func _ready() -> void:
	_marks = GroundMarks.new()
	_marks.name = "Bodenmarken"
	_marks.overlay = self
	# Über Boden (-20 … -15) und Wasserwirkung (-10), unter Schatten (-1) und
	# Figur (0). ABSOLUT, nicht relativ: sonst zählte Godot die 500 des
	# Rasters dazu und die Marken lägen wieder ganz oben.
	_marks.z_as_relative = false
	_marks.z_index = -2
	add_child(_marks)

var _last_view := Rect2(Vector2.INF, Vector2.ZERO)
var _last_cursor := Vector2i(-2, -2)
var _last_player := Vector2i(-9999, -9999)

## Nur neu zeichnen, wenn sich wirklich etwas geändert hat.
##
## Vorher lief `_draw()` jedes Bild: rund 45 Linien, der Weltrand und bis zu
## sechs Chunk-Nummern über den Textserver. Beim Stillstehen ist das reine
## Arbeit für nichts, und auf einem schwachen Rechner fällt sie auf.
func _process(_delta: float) -> void:
	var view := camera.visible_world_rect() if is_instance_valid(camera) else Rect2()
	var pb := block_at(player.global_position) if is_instance_valid(player) else Vector2i.ZERO
	if view == _last_view and cursor_block == _last_cursor and pb == _last_player:
		return
	_last_view = view
	_last_cursor = cursor_block
	_last_player = pb
	queue_redraw()
	_marks.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_grid"):
		return
	show_grid = not show_grid
	_last_view = Rect2(Vector2.INF, Vector2.ZERO)   # erzwingt ein neues Bild
	queue_redraw()
	_marks.queue_redraw()
	get_viewport().set_input_as_handled()

## Der Block, auf dem eine Weltposition liegt.
static func block_at(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / Config.TILE)), int(floor(pos.y / Config.TILE)))

## Der Chunk, in dem ein Block liegt.
static func chunk_of(block: Vector2i) -> Vector2i:
	return Vector2i(floori(float(block.x) / Config.CHUNK), floori(float(block.y) / Config.CHUNK))

## Position des Blocks innerhalb seines Chunks (0 .. CHUNK-1).
static func block_in_chunk(block: Vector2i) -> Vector2i:
	return Vector2i(posmod(block.x, Config.CHUNK), posmod(block.y, Config.CHUNK))

func _draw() -> void:
	var t := float(Config.TILE)
	var rect: Rect2
	if is_instance_valid(camera):
		rect = camera.visible_world_rect().grow(t)
	else:
		rect = Config.fallback_view()
	var x0 := maxi(int(rect.position.x / t), 0)
	var y0 := maxi(int(rect.position.y / t), 0)
	var x1 := mini(int(rect.end.x / t) + 1, Config.MAP_W)
	var y1 := mini(int(rect.end.y / t) + 1, Config.MAP_H)

	if show_grid:
		_draw_grid(t, x0, y0, x1, y1)

## Was auf dem Boden liegt: Bauvorschau und der Block unter der Figur.
## Gezeichnet wird auf `c`, den Knoten unter der Figur.
func draw_marks(c: CanvasItem) -> void:
	var t := float(Config.TILE)
	if show_grid and is_instance_valid(player):
		var b := block_at(player.global_position)
		var cell := Rect2(b.x * t, b.y * t, t, t)
		c.draw_rect(cell, PLAYER_FILL, true)
		c.draw_rect(cell, PLAYER_LINE, false, _w(2.0))
	_draw_cursor(c, t)

## Alles, was G umschaltet und ÜBER der Welt liegt: Linien, Chunk-Nummern,
## Weltrand. Der Block unter der Figur gehört zu den Bodenmarken.
func _draw_grid(t: float, x0: int, y0: int, x1: int, y1: int) -> void:
	# Blocklinien
	for bx in range(x0, x1 + 1):
		if bx % Config.CHUNK != 0:
			draw_line(Vector2(bx * t, y0 * t), Vector2(bx * t, y1 * t), BLOCK_LINE, _w(LINE_THIN))
	for by in range(y0, y1 + 1):
		if by % Config.CHUNK != 0:
			draw_line(Vector2(x0 * t, by * t), Vector2(x1 * t, by * t), BLOCK_LINE, _w(LINE_THIN))

	# Chunk-Grenzen darüber
	var cs := Config.CHUNK
	for bx in range(x0 - x0 % cs, x1 + cs, cs):
		draw_line(Vector2(bx * t, y0 * t), Vector2(bx * t, y1 * t), CHUNK_LINE, _w(LINE_THICK))
	for by in range(y0 - y0 % cs, y1 + cs, cs):
		draw_line(Vector2(x0 * t, by * t), Vector2(x1 * t, by * t), CHUNK_LINE, _w(LINE_THICK))

	_draw_chunk_numbers(t, x0, y0, x1, y1)

	# Weltrand: hier steht die unsichtbare Wand.
	#
	# Nur die Stücke zeichnen, die wirklich im Bild sind. Als ein Rechteck über
	# die ganze Welt kostete das bei 65 536 px Kantenlänge rund 17 ms je Bild —
	# der Rasterizer muss die Linien auch dann durchrechnen, wenn sie weit
	# ausserhalb liegen.
	_draw_border(t, x0, y0, x1, y1)

## Die Bauvorschau — unabhängig vom Raster, sonst baut man blind.
##
## Gezeichnet wird nicht nur der Rahmen, sondern die gewählte Bodenkachel
## halbdurchsichtig darin: so sieht man nicht nur wohin, sondern auch was.
##
## Der Rahmen besteht aus vier Eckwinkeln statt aus einem geschlossenen Kasten.
## Ein Kasten legt sich wie ein zweites Raster über die Welt und schluckt die
## Kachel darunter; Winkel zeigen dasselbe Feld, lassen es aber frei. Bewusst
## ohne Pulsieren: das Raster zeichnet sich nur neu, wenn sich etwas ändert, und
## dieser Sparzweck ist mehr wert als eine atmende Linie.
func _draw_cursor(c: CanvasItem, t: float) -> void:
	if cursor_block.x < 0:
		return
	var box := Rect2(cursor_block.x * t, cursor_block.y * t, t, t)
	if cursor_tex != null:
		c.draw_texture_rect(cursor_tex, box, false, CURSOR_GHOST)
	c.draw_rect(box, CURSOR_FILL, true)
	var arm := t * 0.28
	for corner: Array in [[box.position, 1.0, 1.0], [Vector2(box.end.x, box.position.y), -1.0, 1.0],
			[Vector2(box.position.x, box.end.y), 1.0, -1.0], [box.end, -1.0, -1.0]]:
		var p: Vector2 = corner[0]
		var dx: float = corner[1]
		var dy: float = corner[2]
		# Erst dunkel und dick, dann hell und dünn: der Winkel bleibt auf jedem
		# Untergrund lesbar, auch auf hellem Sand.
		for pass_i in 2:
			var col: Color = Color(0, 0, 0, 0.45) if pass_i == 0 else CURSOR_LINE
			var w: float = _w(3.0 if pass_i == 0 else 2.0)
			c.draw_line(p, p + Vector2(arm * dx, 0.0), col, w)
			c.draw_line(p, p + Vector2(0.0, arm * dy), col, w)

## Weltbreite für eine gewünschte Bildschirmbreite.
func _w(screen_px: float) -> float:
	var zoom := camera.zoom.x if is_instance_valid(camera) else 1.0
	return screen_px / zoom

func _draw_border(t: float, x0: int, y0: int, x1: int, y1: int) -> void:
	var lo := t
	var hi_x := (Config.MAP_W - 1) * t
	var hi_y := (Config.MAP_H - 1) * t
	var left := x0 * t
	var right := x1 * t
	var top := y0 * t
	var bottom := y1 * t
	# Durch `_w`, wie jede andere Linie hier: Staerken sind in
	# BILDSCHIRMpunkten gemeint. Roh uebergeben wuchs der Weltrand als einzige
	# Linie beim Hineinzoomen mit und war bei Zoom 2 doppelt so dick wie die
	# Chunk-Linien daneben.
	var w := _w(BORDER_THICK)
	if lo >= top and lo <= bottom:
		draw_line(Vector2(left, lo), Vector2(right, lo), BORDER, w)
	if hi_y >= top and hi_y <= bottom:
		draw_line(Vector2(left, hi_y), Vector2(right, hi_y), BORDER, w)
	if lo >= left and lo <= right:
		draw_line(Vector2(lo, top), Vector2(lo, bottom), BORDER, w)
	if hi_x >= left and hi_x <= right:
		draw_line(Vector2(hi_x, top), Vector2(hi_x, bottom), BORDER, w)

## Chunk-Nummer in die obere linke Ecke jedes sichtbaren Chunks.
##
## In der Mitte wäre sie meistens unsichtbar: ein Chunk ist 512 Pixel hoch, der
## Bildausschnitt bei Zoom 2 aber nur rund 360 — die Mitte liegt also oft
## ausserhalb. An der Ecke steht die Nummer direkt am gelben Kreuz.
func _draw_chunk_numbers(t: float, x0: int, y0: int, x1: int, y1: int) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var cs := Config.CHUNK
	var cx0 := floori(float(x0) / cs)
	var cy0 := floori(float(y0) / cs)
	var cx1 := floori(float(x1) / cs)
	var cy1 := floori(float(y1) / cs)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			if cx < 0 or cy < 0 or cx * cs >= Config.MAP_W or cy * cs >= Config.MAP_H:
				continue
			var pos := Vector2(cx * cs * t + 8.0, cy * cs * t + 26.0)
			# Die Schrift steht in WELTkoordinaten und wird deshalb mit der
			# Kamera vergrössert. Bei Zoom 2 wären 20 Punkt vierzig hoch —
			# quer durch das halbe Bild. Durch den Zoom geteilt bleibt sie
			# unabhängig davon immer gleich gross auf dem Bildschirm.
			var zoom := camera.zoom.x if is_instance_valid(camera) else 1.0
			draw_string(font, pos, "Chunk %d | %d" % [cx, cy],
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(20.0 / zoom)), CHUNK_TEXT)
