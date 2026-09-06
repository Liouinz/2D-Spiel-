extends Control
## Entwicklerinfo auf F3 — bewusst getrennt von der Leistungsanzeige.
##
## Die Leistungsanzeige beantwortet „läuft es flüssig". Diese hier beantwortet
## „was liegt hier eigentlich": Chunk, Feld, Bodentyp, Höhenstufe, ob es
## begehbar ist, wie viele Kollisionsformen der Chunk hat und in welchem
## Zustand die Figur ist.

var map: MapData
var player: Player
var streamer: ChunkStreamer

var _label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_left = 20
	offset_top = 150
	custom_minimum_size = Vector2(330, 196)
	size = custom_minimum_size
	visible = false

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 8
	_label.offset_top = 6
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Palette.UI_TEXT)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_info"):
		return
	visible = not visible
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible or map == null or not is_instance_valid(player):
		return
	var b := GridOverlay.block_at(player.global_position)
	var c := GridOverlay.chunk_of(b)
	var t := map.get_tile(b.x, b.y)
	var state := "läuft"
	if player.is_swimming():
		state = "schwimmt"
	elif player.is_jumping():
		state = "springt"
	elif player.velocity.length() < 6.0:
		state = "steht"
	_label.text = "\n".join([
		"— Entwicklerinfo (F3) —",
		"Chunk        %d | %d   (geladen: %d)" % [c.x, c.y,
			streamer.loaded_count() if is_instance_valid(streamer) else 0],
		"Feld         %d | %d" % [b.x, b.y],
		"Boden        %s" % GroundTileSet.NAMES.get(t, "?"),
		"Höhenstufe   %d   (Figur: %d)" % [map.level_at(b.x, b.y), player.level()],
		"begehbar     %s%s" % ["nein" if map.is_solid(b.x, b.y) else "ja",
			"   schwimmbar" if map.is_swimmable(b.x, b.y) else ""],
		"Kollision    %d Formen geladen" % (
			streamer.shape_count() if is_instance_valid(streamer) else 0),
		"Figur        %s   %.0f px/s" % [state, player.velocity.length()],
	])
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 0.78), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.85, 0.55, 0.6), false, 2.0)
