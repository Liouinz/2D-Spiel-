class_name Settler
extends RefCounted

## Leichtes Datenobjekt statt schwerer Node — Architektur-Grundsatz aus dem
## Masterplan, damit später tausende Einheiten möglich sind.

var pos := Vector2.ZERO
var target := Vector2.ZERO
