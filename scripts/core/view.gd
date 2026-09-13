class_name View
extends RefCounted

## Der sichtbare Weltausschnitt — an *einer* Stelle.
##
## Fünf Zeichenebenen brauchen ihn zum Culling und die Minimap für ihren
## Sichtfeld-Rahmen. Vorher stand dieselbe Rechnung sechsmal im Projekt, jedes
## Mal minimal anders formuliert. Das ist genau die Art Kopie, die irgendwann
## auseinanderläuft.

const FALLBACK_SIZE := Vector2(1280, 720)


## Weltausschnitt, den `item` gerade sieht, optional um `margin` erweitert.
##
## `item` muss in der Welt hängen (nicht in einem UI-CanvasLayer) — dessen
## Canvas-Transformation beschreibt sonst die Oberfläche statt der Welt. Für
## eine Abfrage aus der UI heraus einfach die Kamera übergeben.
static func world_rect(item: CanvasItem, margin: float = 0.0) -> Rect2:
	if item == null:
		return Rect2(Vector2.ZERO, FALLBACK_SIZE)
	var viewport := item.get_viewport()
	if viewport == null:
		return Rect2(Vector2.ZERO, FALLBACK_SIZE)
	var transform := viewport.get_canvas_transform()
	var scale := transform.get_scale()
	if is_zero_approx(scale.x) or is_zero_approx(scale.y):
		return Rect2(Vector2.ZERO, FALLBACK_SIZE)
	var rect := Rect2(-transform.origin / scale, viewport.get_visible_rect().size / scale)
	return rect.grow(margin) if margin != 0.0 else rect
