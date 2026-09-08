class_name UiAnim
extends RefCounted
## Ein einziger Auf- und Abblendvorgang für alle Menüs.
##
## Jedes Menü blendet gleich ein: es wird sichtbar, wächst dabei minimal und
## wird undurchsichtig. Ohne einen gemeinsamen Ort dafür bekäme jedes Menü
## seine eigene Dauer und seine eigene Kurve — und genau das merkt man.
##
## Bewusst als Fortschrittswert statt als Tween: der Selbsttest kann so Bilder
## abwarten und den Endzustand prüfen, ohne auf einen laufenden Tween zu warten,
## und ein abgebrochener Wechsel lässt keinen halben Zustand zurück.

## Wie weit eine Tafel beim Einblenden von unten kommt.
const RISE := 0.04

## Rechnet den Fortschritt 0…1 in einen weichen Verlauf um.
static func ease_t(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)

## Wendet den Fortschritt auf eine Tafel an: Deckkraft und ein Hauch Wachstum.
## `panel` muss seinen Drehpunkt in der Mitte haben.
static func apply(panel: Control, t: float) -> void:
	if not is_instance_valid(panel):
		return
	var e := ease_t(t)
	panel.modulate.a = e
	panel.scale = Vector2.ONE * lerpf(1.0 - RISE, 1.0, e)

## Setzt den Drehpunkt einer Tafel in ihre Mitte — sonst wächst sie aus der
## linken oberen Ecke heraus.
static func center_pivot(panel: Control) -> void:
	if is_instance_valid(panel):
		panel.pivot_offset = panel.size * 0.5
