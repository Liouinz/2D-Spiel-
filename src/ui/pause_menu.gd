extends UiScreen
## Pause-Menü. Dieselbe Tafel, dieselben Schaltflächen, dieselbe Einblendung
## wie überall — nur der Inhalt ist ein anderer.

signal resume_pressed
signal options_pressed
signal menu_pressed

func _build() -> void:
	add_heading("SPIEL PAUSIERT")
	add_button("FORTSETZEN", func() -> void: resume_pressed.emit())
	add_button("EINSTELLUNGEN", func() -> void: options_pressed.emit())
	add_button("HAUPTMENÜ", func() -> void: menu_pressed.emit())
	content.add_child(UiTheme.gap(UiTheme.SPACE_S))
	content.add_child(UiTheme.text_label("ESC schließt die Pause wieder", UiTheme.FONT_TINY))
