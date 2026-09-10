class_name TileShapes
extends RefCounted

## 47er-"Blob"-Autotiling. Die Form eines Tiles wird ausschliesslich aus den
## acht *tatsächlichen* Nachbarzellen abgeleitet — deshalb kann eine echte
## Lücke im Weltraster niemals visuell zuwachsen.
##
## Bitbelegung (im Uhrzeigersinn ab oben):
##   0 N · 1 NE · 2 E · 3 SE · 4 S · 5 SW · 6 W · 7 NW
## Eine Diagonale zählt nur, wenn *beide* angrenzenden Kardinalrichtungen
## ebenfalls gesetzt sind. Damit fallen die 256 rohen Kombinationen auf genau
## 47 unterscheidbare Formen zusammen.

const N := 1
const NE := 2
const E := 4
const SE := 8
const S := 16
const SW := 32
const W := 64
const NW := 128

static var _configs: Array[int] = []
static var _lookup := {}


static func _build() -> void:
	if not _configs.is_empty():
		return
	var seen := {}
	for raw in 256:
		var norm := normalize(raw)
		if not seen.has(norm):
			seen[norm] = true
			_configs.append(norm)
	_configs.sort()
	for i in _configs.size():
		_lookup[_configs[i]] = i


## Diagonalbits streichen, die keine zwei Kardinalnachbarn haben.
static func normalize(mask: int) -> int:
	var out := mask
	if (mask & N) == 0 or (mask & E) == 0:
		out &= ~NE
	if (mask & E) == 0 or (mask & S) == 0:
		out &= ~SE
	if (mask & S) == 0 or (mask & W) == 0:
		out &= ~SW
	if (mask & W) == 0 or (mask & N) == 0:
		out &= ~NW
	return out


## Anzahl der Formen (47).
static func config_count() -> int:
	_build()
	return _configs.size()


## Rohe Nachbarschaftsmaske → Spaltenindex im Atlas.
static func config_index(mask: int) -> int:
	_build()
	return _lookup.get(normalize(mask), 0)


## Spaltenindex → normalisierte Maske (fürs Zeichnen des Atlas).
static func config_mask(index: int) -> int:
	_build()
	return _configs[index] if index >= 0 and index < _configs.size() else 0


static func has_bit(mask: int, bit: int) -> bool:
	return (mask & bit) != 0
