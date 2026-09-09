class_name Config
extends RefCounted
## Zentrale Konstanten. Keine hart codierten Werte im restlichen Code (§11).

## Kachelgröße in Bildpunkten. 32 statt 16: bei halbem Kamerazoom bleibt das
## Sichtfeld gleich, aber jede Kachel hat die vierfache Pixelfläche für Details.
const TILE := 32
const WORLD_SEED := 20260904          ## fester Seed -> reproduzierbare Welt

## Weltgröße in Blöcken. Sie hängt vom Modus ab, deshalb statisch statt
## konstant.
##
## Aufbaumodus: 128 x 128 Chunks = 2048 x 2048 Blöcke = 4,2 Millionen Kacheln.
## Das geht nur, weil chunkweise geladen wird; im Speicher liegt davon allein
## die Karte selbst (4,2 MB).
##
const BUILD_CHUNKS := Vector2i(128, 128)

## Blockraster beim Start sichtbar. Im Spiel mit G umschaltbar.
##
## AUS beim Start. Das Raster ist ein Werkzeug zum Planen, kein Teil der Welt:
## eingeschaltet legt es ein gelbes Kreuz über den ganzen Bildschirm und
## schreibt „Chunk 64 | 64" quer neben die Figur. Wer das Spiel zum ersten Mal
## startet, sah bisher genau das — eine Karte mit Gitternetz, kein Ort. Es ist
## keine Zeile Funktion verloren: G schaltet es an, die Steuerungshilfe sagt
## das in der ersten Zeile, und die Minimap zeigt Gebautes auch ohne Raster.
const SHOW_BLOCK_GRID := false

## Kantenlänge eines Chunks in Blöcken — dieselbe Größe wie in Minecraft.
const CHUNK := 16

static var MAP_W: int = BUILD_CHUNKS.x * CHUNK
static var MAP_H: int = BUILD_CHUNKS.y * CHUNK

## Wie viele Chunks ringsum geladen bleiben.
##
## Statisch statt konstant: die Sichtweite ist eine Einstellung. `Graphics`
## setzt den Wert aus `Settings.render_range`, der ChunkStreamer liest ihn bei
## jeder Neuberechnung. Radius 2 (5 x 5 Chunks) ist die Voreinstellung — der
## Bildausschnitt ist bei Zoom 1,5 nur rund 27 x 15 Blöcke groß, das lässt
## ringsum mindestens einen ganzen Chunk Puffer.
static var LOAD_RADIUS: int = 2

## Höchstens so viele Chunks werden je Bild nachgeladen. Ein Chunk kostet ein
## paar Millisekunden — auf mehrere Bilder verteilt merkt man davon nichts.
const CHUNK_BUDGET := 2

const PLAYER_SPEED := 124.0           ## Gehen (px/s)
const PLAYER_RUN_SPEED := 216.0       ## Rennen (px/s)
const PLAYER_ACCEL := 1800.0
const PLAYER_FRICTION := 2200.0
const PLAYER_HITBOX := Vector2(18, 12)  ## Fußkollision (halbe Größe)

## Sprung. Von oben gesehen ist er reine Darstellung: die Figur hebt ab, der
## Schatten bleibt am Boden. Die Kollision bleibt unverändert — über Wände
## oder Wasser kommt man nicht.
const JUMP_TIME := 0.45               ## Dauer eines Sprungs in Sekunden
const JUMP_HEIGHT := 14.0             ## Scheitelhöhe in Bildpunkten

## Schwimmen. Im flachen Wasser kommt man durch, aber langsamer als an Land —
## rund 55 % der Gehgeschwindigkeit. Gerannt und gesprungen wird nicht.
const SWIM_SPEED := 68.0


## Kamerazoom. MUSS ganzzahlig sein.
##
## Vorher stand hier 1,5, damit das Sichtfeld bei der Verdopplung der
## Kachelgröße gleich blieb. Der Preis dafür war hoch und fiel erst beim
## Hineinzoomen ins Bild auf: bei Faktor 1,5 wird aus einem Weltpixel mal ein,
## mal zwei Bildschirmpunkte. Jede Kante einer Figur war dadurch abwechselnd
## ein und zwei Punkte dick, Augen waren unterschiedlich breit, Umrisse
## ausgefranst — genau das, was Pixel-Art nicht sein darf, und durch keine
## bessere Zeichnung zu heilen.
##
## Mit Faktor 2 ist jeder Weltpixel exakt zwei Bildschirmpunkte. Das Sichtfeld
## wird dabei kleiner (20 x 11 statt 27 x 15 Blöcke) — das ist die Gegenleistung
## und in etwa die Bildeinstellung, die Aufbauspiele dieser Art benutzen.
const CAMERA_ZOOM := 2.0

## Die wählbaren Zoomstufen. GANZZAHLIG, und das ist keine Bequemlichkeit.
##
## Bei einem Zoom von 1,5 wird aus einem Weltpixel mal ein, mal zwei
## Bildschirmpunkte — dieselbe Ursache, die weiter oben beschrieben ist und
## wegen der der Zoom überhaupt auf 2 gesetzt wurde. Stufen wie „85 %" oder
## „70 %" würden diesen Fehler zurückholen, und zwar sichtbar an jeder
## Figurenkante. Deshalb gibt es drei ganze Stufen statt Prozentwerten:
##
##   1x   weit    40 x 22 Blöcke im Bild
##   2x   normal  20 x 11 Blöcke
##   3x   nah     13 x 7 Blöcke
##
## Mehr braucht es nicht, und ein stufenloses Zoomen gäbe es hier nur um den
## Preis unsauberer Pixel.
## Zoomstufen — nur GERADE Werte.
##
## Die Figur wird mit doppelter Pixeldichte gezeichnet und mit Faktor 0,5
## dargestellt (siehe `ActorArt.ART`). Damit ein Kunstpixel auf eine ganze Zahl
## von Bildschirmpunkten faellt, muss `0,5 * Zoom` ganzzahlig sein — bei Zoom 3
## waeren es anderthalb, und die Kanten der Figur wuerden beim Laufen flimmern.
##
## Der Preis: die alte weiteste Ansicht (Zoom 1) gibt es nicht mehr. Mehr
## Bildpunkte auf derselben Flaeche UND mehr Flaeche im Bild schliessen sich
## aus; „Normal" ist heute, was frueher „Normal" war.
const ZOOM_STEPS := [2.0, 4.0, 6.0]
const ZOOM_NAMES := ["Normal", "Nah", "Sehr nah"]
const ZOOM_DEFAULT := 0        ## Index in ZOOM_STEPS

static func zoom_of(step: int) -> float:
	return float(ZOOM_STEPS[clampi(step, 0, ZOOM_STEPS.size() - 1)])
const CAMERA_SMOOTH := 6.0            ## Interpolationsgeschwindigkeit der Kamera

## Streuwert aus zwei Koordinaten — dieselbe Kachel bekommt immer denselben
## Wert, aber ohne sichtbares Muster. Die Primzahlen sind die üblichen aus
## Spatial-Hashing; das Durchmischen am Ende verhindert Streifen.
##
## Wird für Kachelvarianten und für die Verteilung der Dekoration gebraucht.
static func hash2(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))

static func world_size_px() -> Vector2i:
	return Vector2i(MAP_W * TILE, MAP_H * TILE)

## Wo die Figur startet: die Kartenmitte, dort ist ringsum gleich viel Platz.
static func spawn_block() -> Vector2i:
	return Vector2i(MAP_W / 2, MAP_H / 2)

## Legt die Tastenbelegung an. Was dabei worauf liegt, entscheidet `Keybinds` —
## hier steht nur noch der Aufruf, damit es genau eine Stelle gibt.
static func setup_input() -> void:
	Keybinds.setup()

## Lesbare Tastennamen einer Aktion. Die Arbeit macht `Keybinds`; das hier ist
## der Name, unter dem der Rest des Spiels danach fragt.
static func keys_for(action: String) -> String:
	return Keybinds.describe_action(action)

