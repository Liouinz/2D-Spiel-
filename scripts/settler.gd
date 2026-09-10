class_name Settler
extends RefCounted

## Leichtes Datenobjekt statt Node (Masterplan §5: tausende Einheiten möglich).
## prev_pos/pos erlauben interpoliertes Rendering zwischen Simulations-Ticks.

enum Job { GATHERER, LUMBERJACK }
enum State { SEEK, RETURN }
enum Carry { NONE, FOOD, WOOD }

var name := ""
var job: int = Job.GATHERER
var village_id := 0
var born_tick := 0
var lifespan_years := 70
var state: int = State.SEEK
var carrying: int = Carry.NONE
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var target := Vector2.ZERO
var bob_phase := 0.0
## Watet gerade durch Flachwasser (steuert Wellen und Darstellung).
var wading := false
