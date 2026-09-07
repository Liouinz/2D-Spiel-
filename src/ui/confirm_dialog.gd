extends UiScreen
## Rückfrage vor etwas, das sich nicht rückgängig machen lässt.
##
## Es gibt genau einen Fall dafür: eine neue Welt anfangen, obwohl schon eine
## gebaute Karte gespeichert ist. Ohne die Rückfrage wäre die alte Karte beim
## nächsten Speichern weg, ohne dass jemand danach gefragt wurde.

signal confirmed
signal cancelled

var title_text: String = ""
var message_text: String = ""
var confirm_text: String = "BESTÄTIGEN"

var _message: Label

func _build() -> void:
	add_heading(title_text, UiTheme.FONT_H1)
	_message = UiTheme.text_label(message_text, UiTheme.FONT_BODY, UiTheme.TEXT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(UiTheme.BUTTON_W, 0)
	content.add_child(_message)
	content.add_child(UiTheme.gap(UiTheme.SPACE_M))
	# Abbrechen steht zuerst und bekommt damit den Fokus: die harmlose Wahl ist
	# die, die eine unbedacht gedrückte Eingabetaste auslöst.
	add_button("ABBRECHEN", func() -> void: cancelled.emit())
	add_button(confirm_text, func() -> void: confirmed.emit())

func setup(title: String, message: String, confirm: String) -> void:
	title_text = title
	message_text = message
	confirm_text = confirm
