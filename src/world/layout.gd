class_name Layout
extends RefCounted
## Von Hand gesetzte Weltstruktur. Alles hier ist bewusst gestaltet und nicht
## zufällig — daran hängt, ob das Dorf wie ein Ort wirkt oder wie ein Haufen
## Häuser auf einer Wiese.

const SPAWN := Vector2i(51, 41)          ## Startkachel: Südrand des Dorfplatzes

const PLAZA := Rect2i(48, 34, 7, 5)      ## gepflasterter Dorfplatz (Kacheln)
const WELL := Vector2i(51, 36)

## Gebäude: Kachel oben-links, Größe in Kacheln, Typ und ein feiner Versatz in
## Pixeln, damit nichts wie am Lineal ausgerichtet wirkt.
const BUILDINGS = [
	{"pos": Vector2i(44, 28), "size": Vector2i(5, 3), "type": "inn", "offset": Vector2(-2, 1)},
	{"pos": Vector2i(38, 30), "size": Vector2i(4, 3), "type": "house_big", "offset": Vector2(3, -2)},
	{"pos": Vector2i(57, 29), "size": Vector2i(3, 2), "type": "house_small", "offset": Vector2(-3, 2)},
	{"pos": Vector2i(63, 30), "size": Vector2i(2, 2), "type": "shed", "offset": Vector2(2, 0)},
	{"pos": Vector2i(58, 31), "size": Vector2i(4, 3), "type": "smithy", "offset": Vector2(1, 1)},
	{"pos": Vector2i(40, 38), "size": Vector2i(4, 3), "type": "workshop", "offset": Vector2(-1, -1)},
	{"pos": Vector2i(44, 41), "size": Vector2i(3, 2), "type": "house_small", "offset": Vector2(2, 2)},
	{"pos": Vector2i(55, 41), "size": Vector2i(4, 3), "type": "house_big", "offset": Vector2(-2, 0)},
	{"pos": Vector2i(36, 44), "size": Vector2i(5, 3), "type": "farmhouse", "offset": Vector2(0, 2)},
	{"pos": Vector2i(62, 44), "size": Vector2i(5, 3), "type": "barn", "offset": Vector2(1, -1)},
	{"pos": Vector2i(54, 45), "size": Vector2i(2, 2), "type": "shed", "offset": Vector2(-1, 1)},
]

## Wegenetz. Zwischen zwei Wegpunkten wird achsparallel gebaut (erst die
## längere Achse, dann die kürzere) — daraus entstehen gerade Strecken, saubere
## Ecken und echte Kreuzungen statt mäandernder Trampelpfade.
const ROADS = [
	# Hauptachsen durch das Dorf, sie kreuzen sich auf dem Platz
	{"points": [Vector2i(51, 13), Vector2i(51, 53)], "width": 3},
	{"points": [Vector2i(32, 36), Vector2i(75, 36)], "width": 3},
	# Ausfallstraßen
	{"points": [Vector2i(51, 15), Vector2i(38, 15), Vector2i(33, 19)], "width": 2},
	{"points": [Vector2i(51, 24), Vector2i(70, 24), Vector2i(84, 20)], "width": 2},
	{"points": [Vector2i(75, 36), Vector2i(84, 45), Vector2i(86, 55)], "width": 2},
	{"points": [Vector2i(51, 53), Vector2i(37, 53), Vector2i(27, 59)], "width": 2},
	# Stichwege zu den Höfen
	{"points": [Vector2i(46, 35), Vector2i(46, 31)], "width": 2},
	{"points": [Vector2i(59, 35), Vector2i(59, 34)], "width": 2},
	{"points": [Vector2i(38, 53), Vector2i(38, 47)], "width": 2},
	{"points": [Vector2i(51, 49), Vector2i(64, 49), Vector2i(64, 47)], "width": 2},
	{"points": [Vector2i(43, 41), Vector2i(43, 38)], "width": 2},
]

## Zaunlinien: Vorgärten und eine Koppel am Bauernhof.
const FENCES = [
	{"from": Vector2i(34, 42), "to": Vector2i(41, 42)},
	{"from": Vector2i(34, 48), "to": Vector2i(41, 48)},
	{"from": Vector2i(34, 43), "to": Vector2i(34, 47)},
	{"from": Vector2i(41, 43), "to": Vector2i(41, 44)},
	{"from": Vector2i(60, 48), "to": Vector2i(67, 48)},
	{"from": Vector2i(67, 44), "to": Vector2i(67, 47)},
	{"from": Vector2i(57, 27), "to": Vector2i(61, 27)},
]

## Kleininventar des Dorfes. Reihenfolge egal, Position ist entscheidend.
const DETAILS = [
	# Am Brunnen: Bänke und Laternen
	{"pos": Vector2i(49, 38), "kind": "bench"},
	{"pos": Vector2i(54, 37), "kind": "bench"},
	{"pos": Vector2i(48, 34), "kind": "lantern"},
	{"pos": Vector2i(54, 34), "kind": "lantern"},
	{"pos": Vector2i(48, 39), "kind": "lantern"},
	{"pos": Vector2i(54, 39), "kind": "lantern"},
	{"pos": Vector2i(51, 39), "kind": "sign"},
	# Marktkram auf dem Platz
	{"pos": Vector2i(50, 34), "kind": "crate"},
	{"pos": Vector2i(53, 35), "kind": "barrel"},
	{"pos": Vector2i(52, 38), "kind": "crate"},
	# Gasthaus und Wohnhäuser
	{"pos": Vector2i(43, 31), "kind": "barrel"},
	{"pos": Vector2i(49, 31), "kind": "planter"},
	{"pos": Vector2i(37, 33), "kind": "woodpile"},
	{"pos": Vector2i(56, 31), "kind": "planter"},
	{"pos": Vector2i(60, 31), "kind": "woodpile"},
	# Werkstatt und Schmiede
	{"pos": Vector2i(45, 38), "kind": "crate"},
	{"pos": Vector2i(46, 39), "kind": "barrel"},
	{"pos": Vector2i(40, 38), "kind": "log"},
	{"pos": Vector2i(62, 36), "kind": "barrel"},
	{"pos": Vector2i(57, 36), "kind": "crate"},
	# Bauernhof und Scheune
	{"pos": Vector2i(35, 47), "kind": "woodpile"},
	{"pos": Vector2i(40, 46), "kind": "planter"},
	{"pos": Vector2i(61, 47), "kind": "crate"},
	{"pos": Vector2i(66, 46), "kind": "barrel"},
	{"pos": Vector2i(43, 44), "kind": "stump"},
	{"pos": Vector2i(58, 44), "kind": "bench"},
]
