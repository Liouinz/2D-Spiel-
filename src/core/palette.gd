class_name Palette
extends RefCounted
## Eine einzige Farbpalette für ALLE Grafiken — das hält den Stil konsistent (§3).

# Gras
#
# Vier Toene bilden die Helligkeit ab (dunkel bis Spitze), zwei weitere die
# FARBE: eine Wiese ist nirgends durchgehend derselbe Gruenton. Trockene
# Stellen ziehen ins Gelbe, beschattete ins Blaue. Beide bleiben nah am
# Grundton — sie sollen die Flaeche beleben, nicht flecken.
const GRASS_DARK := Color8(58, 110, 60)
const GRASS := Color8(78, 138, 68)
const GRASS_LIGHT := Color8(104, 165, 82)
const GRASS_HI := Color8(134, 190, 100)
const GRASS_DRY := Color8(146, 162, 78)      ## trocken, zieht ins Gelbe
const GRASS_SHADE := Color8(60, 116, 88)     ## beschattet, zieht ins Blaue

# Sand / Strand
#
# Wie beim Gras: drei Helligkeiten und zwei Farbabweichungen. SAND_WARM ist
# die sonnige, rotstichige Stelle, SAND_DAMP die feuchte, kuehle. Ohne die
# beiden bleibt eine Sandflaeche ein einziges beigefarbenes Rechteck.
const SAND_DARK := Color8(196, 174, 116)
const SAND := Color8(222, 202, 144)
const SAND_LIGHT := Color8(240, 224, 172)
const SAND_WARM := Color8(226, 192, 132)     ## sonnig, zieht ins Rote
const SAND_DAMP := Color8(186, 176, 140)     ## feucht, zieht ins Graugruene

# Wasser
const WATER_DEEP := Color8(38, 78, 122)
const WATER := Color8(56, 108, 160)
const WATER_LIGHT := Color8(88, 150, 194)
const WATER_FOAM := Color8(198, 232, 240)

# Holz (nur noch im Menübild)
const WOOD_DARK := Color8(92, 62, 44)
const WOOD := Color8(132, 92, 60)
const WOOD_LIGHT := Color8(170, 126, 84)

# Laub (nur noch im Menübild)
const PINE_DARK := Color8(30, 70, 58)
const PINE := Color8(44, 96, 72)

# Stein — Kiesel, Findlinge, Geröll am Ufer
const STONE_DARK := Color8(88, 88, 96)
const STONE := Color8(126, 126, 134)
const STONE_LIGHT := Color8(164, 164, 170)

# Blumen & Details
const FLOWER_RED := Color8(206, 84, 78)
const FLOWER_YELLOW := Color8(240, 206, 98)
const FLOWER_WHITE := Color8(238, 238, 230)

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
const OUTLINE := Color8(32, 34, 44, 190)

# UI
const UI_BG := Color8(30, 34, 44, 235)
const UI_BG_DEEP := Color8(20, 23, 30, 245)
const UI_BORDER := Color8(122, 96, 62)
const UI_BORDER_HI := Color8(184, 150, 96)
const UI_TEXT := Color8(238, 232, 216)
const UI_TEXT_DIM := Color8(160, 154, 142)
const UI_ACCENT := Color8(232, 190, 106)
