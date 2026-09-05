class_name Palette
extends RefCounted
## Eine einzige Farbpalette für ALLE Grafiken — das hält den Stil konsistent (§3).

# Gras / Wiese
const GRASS_DARK := Color8(58, 110, 60)
const GRASS := Color8(78, 138, 68)
const GRASS_LIGHT := Color8(104, 165, 82)
const GRASS_HI := Color8(134, 190, 100)
const FOREST_GROUND := Color8(50, 96, 56)
const MEADOW_GROUND := Color8(88, 148, 74)

# Erde / Weg
const DIRT_DARK := Color8(104, 78, 54)
const DIRT := Color8(140, 106, 72)
const DIRT_LIGHT := Color8(168, 134, 94)

# Sand / Strand
const SAND_DARK := Color8(196, 174, 116)
const SAND := Color8(222, 202, 144)
const SAND_LIGHT := Color8(240, 224, 172)

# Wasser
const WATER_DEEP := Color8(38, 78, 122)
const WATER := Color8(56, 108, 160)
const WATER_LIGHT := Color8(88, 150, 194)
const WATER_FOAM := Color8(198, 232, 240)

# Fels / Stein
const STONE_DARK := Color8(80, 84, 96)
const STONE := Color8(114, 118, 132)
const STONE_LIGHT := Color8(152, 156, 170)

# Dachvarianten
const SLATE_DEEP := Color8(48, 52, 68)
const SLATE_DARK := Color8(66, 72, 92)
const SLATE := Color8(88, 96, 118)
const SLATE_LIGHT := Color8(116, 124, 148)

const THATCH_DEEP := Color8(120, 96, 48)
const THATCH_DARK := Color8(158, 128, 64)
const THATCH := Color8(190, 158, 86)
const THATCH_LIGHT := Color8(216, 188, 120)

const ROOF_DEEP := Color8(96, 46, 44)

# Wandvarianten
const PLASTER_WARM := Color8(228, 214, 186)
const PLASTER_WARM_SHADE := Color8(198, 182, 154)
const PLASTER_COOL := Color8(212, 212, 204)
const PLASTER_COOL_SHADE := Color8(180, 182, 176)
const PLANK := Color8(150, 110, 70)
const PLANK_SHADE := Color8(120, 84, 52)
const MASONRY := Color8(146, 140, 128)
const MASONRY_SHADE := Color8(114, 110, 100)

const GLASS_DARK := Color8(84, 128, 158)
const GLASS_HI := Color8(206, 232, 244)

# Holz / Gebäude
const WOOD_DARK := Color8(92, 62, 44)
const WOOD := Color8(132, 92, 60)
const WOOD_LIGHT := Color8(170, 126, 84)
const ROOF_DARK := Color8(124, 62, 58)
const ROOF := Color8(166, 84, 74)
const ROOF_LIGHT := Color8(198, 116, 100)
const WALL := Color8(226, 214, 190)

# Laub — vier Stufen je Baumart, damit die Kronen echtes Licht bekommen
const LEAF_DEEP := Color8(28, 66, 44)
const LEAF_DARK := Color8(38, 84, 52)
const LEAF := Color8(56, 116, 62)
const LEAF_LIGHT := Color8(86, 152, 78)
const LEAF_HI := Color8(124, 186, 96)

const PINE_DEEP := Color8(22, 54, 46)
const PINE_DARK := Color8(30, 70, 58)
const PINE := Color8(44, 96, 72)
const PINE_LIGHT := Color8(68, 128, 92)
const PINE_HI := Color8(98, 158, 112)

# Herbstlicher Laubbaum als Abwechslung im Wald
const AUTUMN_DEEP := Color8(94, 62, 30)
const AUTUMN_DARK := Color8(134, 88, 38)
const AUTUMN := Color8(168, 118, 48)
const AUTUMN_LIGHT := Color8(198, 152, 70)
const AUTUMN_HI := Color8(224, 186, 104)

# Rinde
const BARK_DEEP := Color8(56, 38, 28)
const BARK_DARK := Color8(82, 56, 40)
const BARK := Color8(112, 80, 54)
const BARK_LIGHT := Color8(146, 110, 74)
const BIRCH := Color8(198, 192, 176)
const BIRCH_SHADE := Color8(154, 148, 134)

# Blumen & Details
const FLOWER_RED := Color8(206, 84, 78)
const FLOWER_YELLOW := Color8(240, 206, 98)
const FLOWER_WHITE := Color8(238, 238, 230)
const FLOWER_BLUE := Color8(122, 142, 214)

# Figur
const SKIN := Color8(238, 194, 152)
const SKIN_SHADE := Color8(206, 158, 118)
const HAIR := Color8(112, 72, 46)
const HAIR_LIGHT := Color8(148, 100, 62)
const TUNIC := Color8(84, 124, 176)
const TUNIC_DARK := Color8(58, 92, 138)
const PANTS := Color8(72, 62, 82)
const BOOTS := Color8(86, 60, 44)

# Allgemein
const SHADOW := Color8(0, 0, 0, 58)
const OUTLINE := Color8(32, 34, 44, 190)

# UI
const UI_BG := Color8(30, 34, 44, 235)
const UI_BG_DEEP := Color8(20, 23, 30, 245)
const UI_BORDER := Color8(122, 96, 62)
const UI_BORDER_HI := Color8(184, 150, 96)
const UI_TEXT := Color8(238, 232, 216)
const UI_TEXT_DIM := Color8(160, 154, 142)
const UI_ACCENT := Color8(232, 190, 106)
