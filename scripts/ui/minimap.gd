class_name Minimap
extends PanelContainer

## Minimap aus *denselben* Weltdaten wie die Darstellung (`Terrain.types_buffer`)
## — beides kann nicht mehr auseinanderlaufen.
##
## Das Bild entsteht über einen rohen Bytepuffer statt über 21 504 einzelne
## set_pixel-Aufrufe, und das Gelände wird nur neu gezeichnet, wenn sich die
## Welt tatsächlich geändert hat.

const SETTLER_COLOR := Color(0.95, 0.95, 0.92)
const VILLAGE_COLOR := Color(1.0, 0.85, 0.30)
const TORCH_COLOR := Color(1.0, 0.70, 0.35)
const VIEW_COLOR := Color(1.0, 1.0, 1.0, 0.55)

var terrain: Terrain
var sim: Simulation
var camera: CameraController
var quality: Quality

var _img: Image
var _tex: ImageTexture
var _base := PackedByteArray()
var _frame := PackedByteArray()
var _palette := PackedByteArray()
var _known_version := -1
var _timer := 0.0
var _rect: TextureRect
var _frame_node: Control


func _init(terrain_ref: Terrain, sim_ref: Simulation, quality_ref: Quality) -> void:
	terrain = terrain_ref
	sim = sim_ref
	quality = quality_ref


func _ready() -> void:
	var count := Terrain.W * Terrain.H
	_base.resize(count * 3)
	_frame.resize(count * 3)
	_palette.resize(Terrain.TYPE_COUNT * 3)
	for i in Terrain.TYPE_COUNT:
		var c: Color = Terrain.MINIMAP_COLORS[i]
		_palette[i * 3] = int(c.r * 255.0)
		_palette[i * 3 + 1] = int(c.g * 255.0)
		_palette[i * 3 + 2] = int(c.b * 255.0)
	_img = Image.create(Terrain.W, Terrain.H, false, Image.FORMAT_RGB8)
	_tex = ImageTexture.create_from_image(_img)

	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UiTheme.text_label("KARTE", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	_rect = TextureRect.new()
	_rect.texture = _tex
	_rect.custom_minimum_size = Vector2(Terrain.W, Terrain.H)
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_rect)
	_frame_node = Control.new()
	_frame_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.add_child(_frame_node)
	_frame_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame_node.draw.connect(_draw_viewport_frame)


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	var interval: float = quality.get_value("minimap_interval", 0.7) if quality != null else 0.7
	if _timer > 0.0:
		_frame_node.queue_redraw()
		return
	_timer = interval
	_refresh()
	_frame_node.queue_redraw()


func _refresh() -> void:
	if terrain.version != _known_version:
		_known_version = terrain.version
		var types := terrain.types_buffer()
		for i in types.size():
			var o := i * 3
			var p: int = types[i] * 3
			_base[o] = _palette[p]
			_base[o + 1] = _palette[p + 1]
			_base[o + 2] = _palette[p + 2]
	_frame = _base.duplicate()
	for torch in sim.torches:
		_dot(torch.cell.x, torch.cell.y, TORCH_COLOR)
	for s in sim.settlers:
		var cell := terrain.local_to_map(s.pos)
		_dot(cell.x, cell.y, SETTLER_COLOR)
	for v in sim.villages:
		if v.fallen:
			continue
		for dy in 2:
			for dx in 2:
				_dot(v.center.x + dx, v.center.y + dy, VILLAGE_COLOR)
	_img.set_data(Terrain.W, Terrain.H, false, Image.FORMAT_RGB8, _frame)
	_tex.update(_img)


func _dot(x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= Terrain.W or y >= Terrain.H:
		return
	var o := (y * Terrain.W + x) * 3
	_frame[o] = int(color.r * 255.0)
	_frame[o + 1] = int(color.g * 255.0)
	_frame[o + 2] = int(color.b * 255.0)


## Der weisse Rahmen zeigt, welchen Teil der Welt die Kamera gerade sieht.
func _draw_viewport_frame() -> void:
	if camera == null:
		return
	var view := camera.visible_world_rect()
	var scale := Vector2(1.0 / Terrain.TILE, 1.0 / Terrain.TILE)
	var r := Rect2(view.position * scale, view.size * scale)
	_frame_node.draw_rect(r, VIEW_COLOR, false, 1.0)
