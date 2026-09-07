extends UiScreen
## Hauptmenü.
##
## Vier Wege hinaus, klar sortiert: weitermachen, neu anfangen, einstellen,
## beenden. „Fortsetzen" steht nur da, wenn es wirklich etwas fortzusetzen
## gibt — eine Schaltfläche, die nichts tut, ist schlimmer als keine.

signal continue_pressed
signal new_world_pressed
signal options_pressed
signal quit_pressed

var _continue: UiButton

func _configure() -> void:
	# Das Titelbild soll zu sehen bleiben, deshalb nur leicht abdunkeln — aber
	# kräftig genug, dass die Schrift darüber ruhig steht.
	framed = false
	scrim_alpha = 0.46

func _background() -> void:
	var bg := TextureRect.new()
	bg.name = "Titelbild"
	bg.texture = MenuArt.title_background()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(preload("res://src/ui/cloud_layer.gd").new())

func _build() -> void:
	content.add_child(UiTheme.title("TALHAIN", UiTheme.FONT_TITLE))
	content.add_child(UiTheme.rule(180))
	content.add_child(UiTheme.text_label(
		"Bauen in einer offenen Welt aus Gras, Sand und Wasser"))
	content.add_child(UiTheme.gap(UiTheme.SPACE_XL))

	_continue = add_button("FORTSETZEN", func() -> void: continue_pressed.emit())
	add_button("NEUE WELT", func() -> void: new_world_pressed.emit())
	add_button("EINSTELLUNGEN", func() -> void: options_pressed.emit())
	add_button("SPIEL VERLASSEN", func() -> void: quit_pressed.emit())

	content.add_child(UiTheme.gap(UiTheme.SPACE_L))
	content.add_child(UiTheme.text_label(
		"WASD – Laufen    ·    E – Inventar    ·    ESC – Pause", UiTheme.FONT_TINY))

## Wird vor jedem Öffnen aufgerufen: gibt es eine gebaute Karte?
func refresh() -> void:
	if is_instance_valid(_continue):
		_continue.visible = MapData.has_save()
