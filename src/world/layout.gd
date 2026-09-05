class_name Layout
extends RefCounted
## Von Hand gesetzte Weltstruktur: Dorf, Wege, Zäune. Damit wirkt die Welt
## gestaltet und nicht zufällig zusammengewürfelt (§4).

const VILLAGE := Vector2i(51, 36)
const SPAWN := Vector2i(51, 41)          ## Startkachel des Spielers (Dorfplatz-Südrand)

const PLAZA := Rect2i(46, 33, 11, 8)     ## gepflasterter Dorfplatz (Kacheln)
const WELL := Vector2i(51, 36)

## Gebäude: Kachel oben-links + Größe in Kacheln + Typ
const HOUSES := [
	{"pos": Vector2i(42, 29), "size": Vector2i(4, 3), "type": "big"},
	{"pos": Vector2i(49, 27), "size": Vector2i(4, 3), "type": "big"},
	{"pos": Vector2i(58, 30), "size": Vector2i(3, 2), "type": "small"},
	{"pos": Vector2i(41, 39), "size": Vector2i(3, 2), "type": "small"},
	{"pos": Vector2i(58, 39), "size": Vector2i(4, 3), "type": "big"},
]

## Wege als Wegpunkt-Ketten (Kacheln)
const ROADS := [
	[Vector2i(51, 33), Vector2i(51, 26), Vector2i(46, 20), Vector2i(38, 16)],
	[Vector2i(56, 37), Vector2i(66, 40), Vector2i(75, 45), Vector2i(80, 52)],
	[Vector2i(48, 41), Vector2i(40, 48), Vector2i(31, 54), Vector2i(26, 58)],
	[Vector2i(56, 34), Vector2i(65, 28), Vector2i(75, 23), Vector2i(83, 21)],
]

## Zaunlinien (Gartenkoppel östlich des Dorfes): Start, Ende
const FENCES = [
	{"from": Vector2i(63, 33), "to": Vector2i(69, 33)},
	{"from": Vector2i(63, 38), "to": Vector2i(69, 38)},
	{"from": Vector2i(63, 33), "to": Vector2i(63, 36)},
	{"from": Vector2i(69, 33), "to": Vector2i(69, 38)},
]

## Kleine Requisiten von Hand: Position (Kachel) + Art
const DETAILS = [
	{"pos": Vector2i(47, 31), "kind": "barrel"},
	{"pos": Vector2i(48, 31), "kind": "crate"},
	{"pos": Vector2i(55, 40), "kind": "crate"},
	{"pos": Vector2i(45, 34), "kind": "sign"},
	{"pos": Vector2i(57, 33), "kind": "barrel"},
	{"pos": Vector2i(43, 42), "kind": "stump"},
	{"pos": Vector2i(66, 35), "kind": "log"},
	{"pos": Vector2i(60, 43), "kind": "stump"},
]
