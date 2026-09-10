class_name Palette
extends RefCounted

## Eine einzige, feste Farbpalette für die ganze Welt — Terrain, Einheiten,
## Effekte und UI greifen ausschliesslich hier zu. Das ist der Grund, warum das
## Bild nicht "zusammengewürfelt" wirkt: Jede Farbe im Spiel stammt aus dieser
## Datei (Masterplan §3: eine warme Palette für visuellen Zusammenhalt).

# --- Terrain ----------------------------------------------------------------
const SEABED_DEEP := Color(0.16, 0.21, 0.30)
const SEABED_SHORE := Color(0.72, 0.64, 0.45)
const SAND := Color(0.85, 0.76, 0.53)
const SAND_DARK := Color(0.72, 0.62, 0.41)
const GRASS := Color(0.36, 0.60, 0.27)
const GRASS_DARK := Color(0.27, 0.47, 0.21)
const GRASS_LIGHT := Color(0.47, 0.70, 0.33)
const ROCK := Color(0.47, 0.48, 0.51)
const ROCK_DARK := Color(0.34, 0.35, 0.39)
const ROCK_LIGHT := Color(0.60, 0.61, 0.64)

# --- Overlays (liegen mit Alpha über dem Boden) -----------------------------
const WATER_DEEP := Color(0.13, 0.31, 0.55, 0.94)
const WATER_SHALLOW := Color(0.24, 0.50, 0.72, 0.80)
const WATER_FOAM := Color(0.78, 0.90, 0.98)
const CANOPY := Color(0.19, 0.40, 0.18)
const CANOPY_LIGHT := Color(0.27, 0.51, 0.23)
const TRUNK := Color(0.34, 0.23, 0.14)
const LAVA := Color(0.78, 0.26, 0.07)
const LAVA_HOT := Color(1.0, 0.68, 0.20)

# --- Einheiten & Bauten -----------------------------------------------------
const SHADOW := Color(0.0, 0.0, 0.0, 0.20)
const SKIN := Color(0.93, 0.82, 0.68)
const TUNIC_GATHERER := Color(0.44, 0.52, 0.25)
const TUNIC_LUMBERJACK := Color(0.56, 0.32, 0.20)
const CARRY_FOOD := Color(0.86, 0.75, 0.35)
const CARRY_WOOD := Color(0.51, 0.35, 0.20)
const HUT_WALL := Color(0.49, 0.34, 0.22)
const HUT_ROOF := Color(0.36, 0.24, 0.16)
const HUT_DOOR := Color(0.22, 0.14, 0.09)
const FIRE_STONE := Color(0.42, 0.42, 0.44)
const FIRE_LOG := Color(0.38, 0.26, 0.15)
const TORCH_STICK := Color(0.42, 0.28, 0.16)
const TORCH_HEAD := Color(0.28, 0.20, 0.12)

# --- Licht ------------------------------------------------------------------
const LIGHT_DAY := Color(1.0, 1.0, 1.0)
const LIGHT_DUSK := Color(1.0, 0.80, 0.62)
const LIGHT_NIGHT := Color(0.17, 0.22, 0.38)
const LIGHT_FIRE := Color(1.0, 0.72, 0.36)
const LIGHT_TORCH := Color(1.0, 0.76, 0.42)
const LIGHT_LAVA := Color(1.0, 0.48, 0.16)
const LIGHT_WINDOW := Color(1.0, 0.83, 0.52)

# --- Effekte ----------------------------------------------------------------
const CLOUD := Color(1.0, 1.0, 1.0, 0.07)
const RAIN_DROP := Color(0.66, 0.79, 0.95, 0.42)
const RAIN_CLOUD := Color(0.35, 0.38, 0.45, 0.22)
const SPARK_WATER := Color(0.76, 0.89, 1.0, 0.70)
const SPARK_LAVA := Color(1.0, 0.62, 0.18, 0.80)
const BLESSING := Color(1.0, 0.90, 0.45)
const FLASH := Color(1.0, 1.0, 0.85)
const IMPACT_OUTER := Color(1.0, 0.55, 0.20)
const IMPACT_INNER := Color(1.0, 0.85, 0.50)

# --- UI ---------------------------------------------------------------------
const UI_BG := Color(0.09, 0.08, 0.07, 0.94)
const UI_BG_DEEP := Color(0.06, 0.055, 0.05, 0.97)
const UI_PANEL := Color(0.145, 0.125, 0.10)
const UI_PANEL_HOVER := Color(0.20, 0.17, 0.13)
const UI_PANEL_ACTIVE := Color(0.30, 0.23, 0.14)
const UI_BORDER := Color(0.42, 0.33, 0.21)
const UI_BORDER_LIGHT := Color(0.60, 0.48, 0.30)
const UI_ACCENT := Color(0.93, 0.78, 0.44)
const UI_TEXT := Color(0.88, 0.85, 0.78)
const UI_TEXT_DIM := Color(0.62, 0.58, 0.50)
const UI_GOOD := Color(0.55, 0.82, 0.45)
const UI_WARN := Color(0.95, 0.72, 0.30)
const UI_BAD := Color(0.90, 0.42, 0.36)


## Farbe abdunkeln/aufhellen, ohne den Alphakanal zu verändern.
static func shade(base: Color, amount: float) -> Color:
	return Color(
		clampf(base.r + amount, 0.0, 1.0),
		clampf(base.g + amount, 0.0, 1.0),
		clampf(base.b + amount, 0.0, 1.0),
		base.a
	)
