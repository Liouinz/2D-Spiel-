class_name Village
extends RefCounted

## Ein Dorf mit eigenem Namen, Lagern und Wachstumsstufen
## (Lager → Dorf → Stadt, Masterplan §2.3).

enum Stage { CAMP, VILLAGE, TOWN }

var id := 0
var name := ""
var center := Vector2i.ZERO
var center_pos := Vector2.ZERO
var food := 5
var wood := 3
var huts: Array[Vector2i] = []
var fertile_until := 0
var stage: int = Stage.CAMP
var fallen := false
