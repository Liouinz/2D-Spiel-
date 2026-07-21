class_name NameGen
extends RefCounted

## Namen machen aus anonymen Punkten Individuen — Grundstein für die
## Chroniken und das "Erinnerungs"-Feature aus dem Masterplan.

const FIRST_NAMES := [
	"Aldo", "Berta", "Coro", "Dara", "Emil", "Finn", "Greta", "Hano",
	"Ida", "Jorin", "Kara", "Lio", "Mira", "Nane", "Odo", "Pia",
	"Quirin", "Runa", "Sepp", "Tilda", "Ubbo", "Vera", "Wim", "Yara",
	"Zeno", "Alva", "Bruno", "Carla", "Doran", "Eila", "Falk", "Gesa",
	"Holm", "Ilva", "Jost", "Kuna", "Lasse", "Merle", "Nio", "Ola",
]
const VILLAGE_PREFIX := [
	"Grün", "Stein", "Wald", "See", "Berg", "Sonnen", "Nebel", "Rosen",
	"Eichen", "Fels", "Moor", "Wind", "Gold", "Raben", "Birken",
]
const VILLAGE_SUFFIX := [
	"feld", "furt", "heim", "hausen", "bach", "tal", "berg", "hof",
	"stedt", "au", "brück", "weiler",
]


static func settler_name() -> String:
	return FIRST_NAMES.pick_random()


static func village_name() -> String:
	return VILLAGE_PREFIX.pick_random() + VILLAGE_SUFFIX.pick_random()
