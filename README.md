# 🌍 Terraria Mundi — Prototyp

> **Arbeitstitel** für ein 2D God-Sim / Aufbau-Sandbox-Spiel.
> Der Zukunfts-Plan steht in [`docs/masterplan.md`](docs/masterplan.md),
> die Leistungsmessungen in [`docs/performance.md`](docs/performance.md).
> **Diese Datei beschreibt ausschließlich, was HEUTE im Code steht — nicht, was geplant ist.**

Du bist keine Figur im Spiel — du bist die Welt selbst. Du malst Land, setzt Völker aus und schaust zu.

---

## ⚡ Kurzüberblick: Was ist wirklich drin?

| Bereich | Drin? | Umfang |
|---|---|---|
| Terrain malen | ✅ | **7 Typen**, davon **5 malbar** (siehe unten) |
| Bausystem / Autoconnection | ✅ | 47-Blob-Autotiling aus echten Nachbarn, Kanten/Ecken automatisch |
| Insel-Generator | ✅ | beim Start **und** über „Neue Welt erschaffen“ im Menü |
| Siedler | ✅ | 2 Berufe, Name, Alter, Lebensspanne, waten durch Flachwasser |
| Dörfer | ✅ | Hüttenbau, Geburten, 3 Wachstumsstufen |
| Gottheit-Kräfte | ✅ | 4 Stück (Blitz, Regen, Segen, Meteor) + Volk aussetzen + Fackel |
| Glauben-Ressource | ✅ | Einnahme passiv + pro Lieferung, Ausgabe pro Kraft |
| Tag/Nacht | ✅ | **Lightmap**, ein Zeichenaufruf statt bis zu 48 Punktlichter |
| Lokales Licht | ✅ | setzbare Fackeln, Lagerfeuer, Hüttenfenster, Lava, Blitz/Meteor |
| Wasser-Optik | ✅ | Auflage über dem Boden: runde Ufer, Shader-Bewegung, Wellenringe, Fische |
| Wetter | ⚠️ | nur Regen — und nur als Spieler-Kraft, kein eigenes Wettersystem |
| Chronik | ⚠️ | globaler Ticker, **nur die letzten 8 Zeilen**, kein Verlauf |
| Minimap | ✅ | live, mit Sichtfeld-Rahmen, Takt aus dem Grafikprofil |
| Kamera | ✅ | **feste Zoomstufen** 100/85/70 %, Schwenken, Grenzen, Screenshake |
| Zeitraffer | ✅ | Pause / 1× / 3× / 10× |
| Frei belegbare Steuerung | ✅ | Actions statt fester Tasten, mehrere Eingaben je Aktion, gespeichert |
| Menü / Startbildschirm | ✅ | Startbildschirm, Pausemenü, Einstellungen mit 3 Reitern |
| Entwickler-Overlay | ✅ | gemessene Leistungs-, Welt- und Hardwaredaten (F3) |
| Adaptive Grafikprofile | ✅ | HOCH/MITTEL/NIEDRIG aus erkannter Hardware + dynamische Absenkung |
| Shader | ✅ | einer: die Wasseranimation. Alles andere läuft weiter über `_draw()` |
| Tests | ✅ | **60 Abnahmeprüfungen**, headless ausführbar |
| **Sound / Musik** | ❌ | **komplett nicht vorhanden** — kein einziger Audio-Knoten |
| **Speichern / Laden** | ❌ | **nicht vorhanden** (außer der Tastenbelegung) — Schließen = Welt weg |
| **Grafik-Assets** | ❌ | **keine einzige Bilddatei** — alle Grafik wird im Code gemalt |
| Partikel-Nodes | ❌ | nicht verwendet; Effekte laufen über `_draw()` |
| Undo / Rückgängig | ❌ | nicht vorhanden |

---

## 🎨 Die 7 Terrain-Typen

Definiert in `scripts/terrain.gd`. **Alle 7 existieren, aber nicht alle sind malbar:**

| # | Typ | Malbar? | Wie entsteht er sonst? |
|---|---|---|---|
| 0 | **Tiefwasser** | ✅ Slot `4` | Insel-Generator |
| 1 | **Flachwasser** | ❌ | **automatisch** — jede Wasserkachel mit Landnachbar wird Flachwasser |
| 2 | **Sand** | ✅ Slot `3` | Insel-Generator (Strand); Blitz/Meteor verbrennen Gras & Wald zu Sand; Rechtsklick auf Wasser |
| 3 | **Gras** | ✅ Slot `1` | Insel-Generator; Regen macht Sand zu Gras; Holzfäller roden Wald; Rechtsklick auf Wald/Fels/Lava |
| 4 | **Wald** | ✅ Slot `2` | Insel-Generator; wächst selbst auf Gras neben Wald; Regen |
| 5 | **Fels** | ✅ Slot `5` | Insel-Generator (Gebirge); Lava kühlt zu Fels ab |
| 6 | **Lava** | ❌ | **nur durch Meteor-Einschlag**, kühlt nach 400 Ticks zu Fels ab |

> **Hinweis zur Reduktion:** Wenn der Prototyp nur Gras/Sand/Wasser haben soll (Masterplan Phase 0: *„Terrain malen (3 Tile-Typen reichen)“*), müssten Wald, Fels und Lava aus `terrain.gd`, `items.gd` **und** aus der Siedler-Wirtschaft entfernt werden — der Beruf *Holzfäller* und die Ressource *Holz* hängen direkt am Wald. Das ist derzeit **nicht** so; aktuell sind alle 7 aktiv.

---

## 🧱 Wie das Bausystem die Kachelform bestimmt

Jede Kachel wählt ihre Form aus **47 Blob-Varianten** (`scripts/world/tile_shapes.gd`). Die Maske entsteht aus den acht *tatsächlichen* Nachbarzellen; eine Diagonale zählt nur, wenn **beide** angrenzenden Kardinalrichtungen besetzt sind. Damit kann eine echte Lücke im Raster nicht visuell zuwachsen:

```
[FELS][FELS][ GRAS ][FELS][FELS]
        ↑ eigene Ostkante  ↑ eigene Westkante — keine Verbindung
```

Gezeichnet wird in **vier Ebenen**: Boden (deckend, mit Kantenlicht) · Wasser · Tiefwasser-Kern · Aufsatz (Laubdach, Lava). Weil Wasser und Wald als *transparente Auflage über dem Boden* liegen und ihre Silhouette aus den echten Nachbarn geschnitten wird, verlieren sie die Quadratform: Ufer werden rund, Waldränder ausgefranst.

Die Variante einer Zelle ist **deterministisch** aus ihrer Koordinate abgeleitet — dieselbe Zelle sieht nach jedem Neusetzen gleich aus.

---

## 🧍 Was die Siedler wirklich tun

Ein Siedler ist **kein Node**, sondern ein leichtes Datenobjekt (`scripts/settler.gd`). Er hat:
Name, Beruf, Dorf-ID, Geburts-Tick, Lebensspanne, Zustand, Traglast, Position, Ziel, Wat-Flag.

**Die komplette KI besteht aus genau diesem Kreislauf:**

```
Ziel suchen  →  in gerader Linie hinlaufen  →  angekommen?
                                                   ↓
                        Boden = mein Rohstoff?  ja → aufnehmen, zum Dorf laufen
                                                nein → neues Ziel würfeln
```

- **Zielsuche ist reines Würfeln:** 12 Zufallsversuche im Umkreis ±16 Kacheln ums Dorf, dann 8 Versuche ±6 Kacheln um sich selbst, sonst heimlaufen. **Keine Wegfindung, kein A\*, kein Ausweichen.**
- **Bewegung ist eine Gerade** mit 3 Pixel pro Tick. **Flachwasser wird durchwatet** (55 % Tempo, mit Wellenspur), Tiefwasser blockiert.
- **Zwei Berufe:** *Sammler* nimmt Nahrung von Gras, *Holzfäller* nimmt Holz von Wald (und rodet ihn zu 30 %).
- **Abgeliefert wird nur am Dorf** (Radius 26 px) — sonst wird weitergelaufen.
- **Tod:** nur durch Alter, Blitz, Meteor oder Betreten von Lava.
- **Nicht drin:** Hunger, Schlaf, Beziehungen, Charakterzüge, Kämpfe, Krankheit, Häuser bewohnen.

## 🏘 Was die Dörfer wirklich tun

Ein Dorf (`scripts/village.gd`) hat: Name, Zentrum, Nahrung, Holz, Hüttenliste, Fruchtbarkeits-Timer, Stufe, „verlassen“-Flag.

Alle 10 Ticks passiert genau das:
1. Bevölkerung = 0? → Dorf gilt als verlassen, Chronik-Eintrag, Ende.
2. Genug Nahrung (6) **und** Holz (5) **und** Bevölkerung ≥ Hütten×2 **und** < 40 Hütten? → eine Hütte bauen.
3. Bevölkerung unter Kapazität (Hütten×3+4) und Nahrung ≥ 2? → mit 6 % (bzw. 25 % nach Segen) ein Kind.

Alle 20 Ticks zusätzlich: **Hütten und Fackeln auf geflutetem oder verlavtem Grund verschwinden.**

**Stufen:** 3 Hütten → „Dorf“, 8 Hütten → „Stadt“. Die Stufe hat **keinerlei Auswirkung** — sie erzeugt nur eine Chronikzeile.

**Nicht drin:** Handel, Diplomatie, Krieg, Religion, Grenzen, Straßen, mehrere Völker.

---

## ⚡ Die Kräfte

| Slot | Kraft | Kosten | Wirkung im Code |
|---|---|---|---|
| `6` | Fackel | **0** | Setzt eine Fackel: warmes, flackerndes Licht, Radius 7 Kacheln. Nur auf begehbarem Grund, max. 240 Stück. |
| `7` | Volk aussetzen | **0** | Gründet ein Dorf mit 4 Siedlern. Nicht auf Wasser/Lava. Wald/Fels wird zu Gras. |
| `8` | Blitz | 10 | Verbrennt Gras/Wald zu Sand (Radius 2 Kacheln), tötet Siedler und zerstört Hütten (Radius 28 px). Trifft er nichts, gibt es +2 Glauben. |
| `9` | Regen | 6 | 80 Ticks lang: Sand→Gras, Gras→Wald, Lava→Fels im Radius 90 px. Dämpft dabei das Licht darunter. |
| `0` | Segen | 8 | Nächstes Dorf (max. 150 px) bekommt +12 Nahrung und 600 Ticks hohe Geburtenrate. |
| `Umschalt+1` | Meteor | 40 | Fällt 14 Ticks lang, dann: Krater (Radius 4 Kacheln verbrannt), 3×3 Lava, tötet im Radius 52 px. |

**Glauben:** Start 20, Maximum 200. Einnahme: 0,002 pro Siedler pro Tick **plus** 0,05 pro abgelieferter Ressource.

---

## 🖼 Wie die Grafik entsteht (wichtig!)

**Es gibt keine einzige Bilddatei im Projekt.** Alles wird beim Start oder pro Frame im Code gemalt — aus einer einzigen Palette (`scripts/core/palette.gd`), die auch die UI-Farben liefert.

| Was | Wie | Datei |
|---|---|---|
| Terrain-Kacheln | 8 Materialarten × 47 Formen × 3 Varianten, beim Start in rohe Bytepuffer gemalt und zu einem TileSet gebacken (~0,2 s) | `world/tile_art.gd` |
| Item-Icons | 16×16 px je Schnellleisten-Eintrag, beim Aufbau erzeugt | `core/items.gd` |
| Hütten, Lagerfeuer, Fackeln, Siedler | jeden Frame, **gecullt** und nach Primitivtyp gruppiert | `world_render.gd` |
| Blitz, Feuer, Glitzern, Funken | jeden Frame, additiv **über** der Lightmap | `fx_glow.gd` |
| Wolken, Regen, Meteor | jeden Frame, normal, **unter** der Lightmap | `fx_overlay.gd` |
| Tag/Nacht + Lichter | **eine Lightmap-Textur**, multiplizierend, 10–24 Hz statt pro Frame | `render/lighting.gd` |
| Wasserbewegung | Shader auf den beiden Wasserebenen | `world/water_fx.gd` |
| Minimap | 192×112 `Image` über einen Bytepuffer, nur bei echter Weltänderung neu | `ui/minimap.gd` |
| UI | ein Theme aus der Palette: Rahmen, Zustände, Abstände, Tooltips | `ui/ui_theme.gd` |

Ein Siedler besteht aus **3 Rechtecken** (Schatten, Rumpf, Kopf) plus optional 1 Rechteck für die Traglast.
Eine Hütte besteht aus **4 Rechtecken + 1 Dreieck + 1 Linie**.
Bäume sind eine transparente Laubdach-Auflage, deren Silhouette sich aus den Nachbarn ergibt.

---

## 🎮 Steuerung — vollständig frei belegbar

Die Spiellogik kennt **keine festen Tasten**. Sie fragt ausschließlich *Actions* ab (`move_up`, `place_block`, `toggle_debug` …); welche Eingabe eine Action auslöst, entscheidest du unter **Einstellungen → Steuerung**.

* Jede Action darf **mehrere** Eingaben haben — deshalb funktionieren WASD und die Pfeiltasten von Haus aus gleichzeitig.
* Tasten **und** Mausknöpfe sind belegbar.
* Doppelbelegungen werden erkannt und rot markiert (verboten sind sie nicht).
* Standard wiederherstellen · Änderungen verwerfen · Speichern — die Belegung liegt in `user://keybinds.cfg` und überlebt den Neustart.
* Alle Tasten laufen über **physische** Keycodes, funktionieren also auch auf AZERTY.

Die Standardbelegung:

| Eingabe | Aktion |
|---|---|
| **W A S D** / **Pfeiltasten** | Kamera bewegen |
| **Umschalt** | schneller bewegen |
| **Mausrad** | Zoom (feste Stufen 100 % / 85 % / 70 %) |
| **Maus Mitte** | Kamera ziehen |
| **Maus links** | Ausgewählten Slot anwenden (Malen auch per Ziehen) |
| **Maus rechts** | Entfernen: Fackel aufnehmen, Wald/Fels roden, Wasser trockenlegen |
| **1 – 0, Umschalt+1** | Schnellleisten-Slot wählen |
| **+ / −** | Pinselgröße 1–8 |
| **Leertaste** | Simulation anhalten |
| **Bild ↑ / Bild ↓** | Tempo eine Stufe hoch/runter |
| **Esc** | Menü / zurück |
| **F3** | Entwickler-Overlay |
| **M · C · F1** | Minimap · Chronik · HUD ein-/ausblenden |
| **I / Tab** | Einstellungen |

---

## 🔢 Alle Balancing-Zahlen an einem Ort

| Wert | Zahl | Bedeutung |
|---|---|---|
| Kartengröße | 192 × 112 Kacheln | = 3072 × 1792 Pixel |
| Kachelgröße | 16 px | 47 Formen × 3 Varianten pro Materialart |
| Ticks pro Sekunde | 10 | fest, unabhängig von der Bildrate |
| Ticks pro Jahr | 200 | = 20 s bei Tempo 1× |
| Ticks pro Tag/Nacht | 600 | = 60 s bei Tempo 1× |
| Siedler-Tempo | 3 px / Tick | ≈ 1,9 Kacheln pro Sekunde; im Flachwasser 55 % davon |
| Abliefer-Radius | 26 px | näher muss ein Träger ans Dorf |
| Hütte kostet | 6 Nahrung + 5 Holz | max. 40 Hütten pro Dorf |
| Geburt kostet | 2 Nahrung | Kapazität = Hütten × 3 + 4 |
| Lebensspanne | 55–85 „Jahre“ | danach 0,2 % Sterbechance pro Tick |
| Lava kühlt ab nach | 400 Ticks | zu Fels |
| Fackel-Radius | 7 Kacheln | max. 240 Fackeln |

> ⚠️ **Ein „Jahr“ (200 Ticks) ist kürzer als ein „Tag“ (600 Ticks).** Ein Siedler mit 70 Jahren hat rund 23 Tage erlebt. Die Jahreszahlen in der Chronik sind dadurch inhaltlich sinnlos.

---

## 🐞 Bekannte Fehler

Die Liste aus der Ist-Zustands-Analyse, mit aktuellem Stand:

| # | Fehler | Stand |
|---|---|---|
| 1 | Malen bleibt hängen, wenn die Maustaste über einem UI-Panel losgelassen wird | ✅ behoben — der Tastenzustand wird pro Frame gegengeprüft |
| 2 | Träger buchen ihre Last dort ein, wo sie gerade stehen | ✅ behoben — abgeliefert wird nur am Dorf (26 px), sonst wird weitergelaufen |
| 3 | Siedler können dauerhaft einfrieren | ✅ behoben — ohne erreichbares Ziel wird heimgelaufen, die eigene Zelle zählt nicht mehr als Ziel |
| 4 | Terraforming hat keine Konsequenz (Hütten schwimmen auf Wasser) | ✅ behoben für **Hütten und Fackeln**; Lagerfeuer und Dorfzentrum bleiben offen |
| 5 | Nahrung ist unendlich — Gras wird beim Ernten nicht verbraucht | ❌ offen (Balancing-Entscheidung) |
| 6 | Glaube saturiert — ab einigen hundert Siedlern sind Kräfte praktisch gratis | ❌ offen (Balancing-Entscheidung) |
| 7 | Baumstämme zu 2/3 von der Krone verdeckt | ✅ entfällt — das Laubdach ist jetzt eine eigene Auflage-Ebene |
| 8 | Siedler-Kopf 0,5 px versetzt, Traglast schwebt 1 px über dem Kopf | ✅ behoben |
| 9 | Siedler wippen weiter, während das Spiel pausiert ist | ✅ behoben |
| 10 | Kein Culling — es wird immer die ganze Karte gezeichnet | ✅ behoben in WorldRender, FxGlow, FxOverlay, Lightmap |
| — | Zifferntasten funktionieren nicht auf AZERTY | ✅ behoben — alle Tasten laufen über physische Keycodes |

Jeder behobene Punkt hat eine Prüfung in `tests/verify.gd`, außer #1 (braucht echten Eingabezustand) und #7/#9 (rein zeichnerisch).

---

## 🚀 Starten

1. [Godot 4.3+](https://godotengine.org/download) herunterladen (keine Installation nötig)
2. Godot öffnen → **Importieren** → diesen Ordner (`project.godot`) auswählen
3. **F5** drücken

Renderer ist auf **GL Compatibility** eingestellt, läuft also auch auf schwacher Hardware. Das Grafikprofil wird beim Start aus der erkannten Hardware abgeleitet.

## 🧪 Prüfen und nachmessen

```bash
# 60 Abnahmeprüfungen (Steuerung, Grafikprofile, Autoconnection, Fehlerrückfälle)
godot --headless --path . --script res://tests/verify.gd

# Frametimes mit und ohne einzelne Systeme — die Grundlage von docs/performance.md
godot --path . --rendering-driver opengl3 res://tests/benchmark.tscn
```

`verify.gd` endet mit Exit-Code 1, sobald eine Prüfung fehlschlägt — direkt CI-tauglich.

---

## 📁 Projektstruktur

```
project.godot                     Godot-4.3-Projektdatei (Nearest-Filter für Pixel-Art)
scenes/main.tscn                  Hauptszene — enthält NUR den Wurzelknoten,
                                  die gesamte Hierarchie entsteht in main.gd zur Laufzeit
scripts/main.gd                   Einstiegspunkt, Werkzeuge, Eingabe (ohne feste Tasten)
scripts/simulation.gd             Fester Tick: Dörfer, Siedler, Glauben, Kräfte, Wetter, Fackeln
scripts/terrain.gd                Typ-Raster + vier Zeichenebenen, Dirty-Region-Autotiling
scripts/settler.gd                Siedler als reines Datenobjekt
scripts/village.gd                Dorf als reines Datenobjekt
scripts/names.gd                  40 Vornamen, 15 Präfixe × 12 Suffixe für Dorfnamen
scripts/world_render.gd           Hütten, Feuer, Fackeln, Siedler — gecullt, nach Primitiv gruppiert
scripts/fx_glow.gd                Additiv über der Lightmap: Blitz, Feuer, Glitzern, Funken
scripts/fx_overlay.gd             Normal unter der Lightmap: Wolken, Regen, Meteor
scripts/camera_controller.gd      Feste Zoomstufen, Action-Steuerung, Grenzen, Screenshake
scripts/game_ui.gd                Klammer um alle Oberflächen-Teile

scripts/core/palette.gd           Die eine Farbpalette für Welt, Effekte und UI
scripts/core/input_actions.gd     Action-Registry, Belegung, Konflikte, Speichern/Laden
scripts/core/quality.gd           Hardware-Erkennung, Profile, dynamische Qualität
scripts/core/profiler.gd          Gemessene Leistungswerte (nichts geschätzt)
scripts/core/items.gd             Schnellleisten-Einträge + prozedurale Icons

scripts/world/tile_shapes.gd      47er-Blob-Autotiling: Maske → Form
scripts/world/tile_art.gd         Prozeduraler Tile-Atlas (Kantenlicht, runde Silhouetten)
scripts/world/water_fx.gd         Wasser-Shader, Wellenringe, Fische

scripts/render/lighting.gd        Lightmap: ein Zeichenaufruf statt vieler Lichter

scripts/ui/ui_theme.gd            Das gemeinsame Theme + verlässliche Verankerung
scripts/ui/hud.gd                 Statusleiste, Schnellleiste, Chronik, Einblendungen
scripts/ui/minimap.gd             Minimap aus denselben Weltdaten
scripts/ui/dev_overlay.gd         Entwickler-Overlay
scripts/ui/settings_window.gd     Einstellungen (Grafik · Steuerung · Spiel)
scripts/ui/keybind_page.gd        Vollständige Steuerungsseite
scripts/ui/menus.gd               Startbildschirm und Pausemenü

tests/verify.gd                   60 Abnahmeprüfungen (headless, CI-tauglich)
tests/benchmark.tscn              Reproduzierbares Frametime-Messharness

docs/masterplan.md                Der Zukunfts-Plan (NICHT der Ist-Zustand)
docs/performance.md               Messaufbau, Engpass, Ergebnisse
```

**Gesamt: ~5.000 Zeilen GDScript, 0 Asset-Dateien, 60 Tests.**

---

## 📍 Ehrlicher Stand gegenüber der Roadmap

**Phase 0 (Prototyp):** erfüllt — Terrain malen ✓, Volk mit Hütten & Nahrung ✓, Gottheit-Kraft ✓, Kamera mit Zoom/Schwenken/Zeitraffer ✓

**Aus Phase 1 angefangen:** 4 Kräfte + Glauben ✓ · Tag/Nacht mit dynamischem Licht ✓ · Wachstumsstufen ✓ (ohne Wirkung) · sichtbarer Transport ✓ · Menü & Einstellungen ✓ · frei belegbare Steuerung ✓

**Aus Phase 1 komplett offen:** handgezeichnete Pixel-Art statt prozeduraler Platzhalter · Sound-Grundgerüst · Speichern/Laden der Welt

**Aus Phase 2 komplett offen:** weitere Völker · Diplomatie · Religion · echte Dorf-Chroniken · Szenarien

---

*„Große Spiele entstehen nicht aus großen Plänen, sondern aus kleinen Schritten, die man wirklich geht."*
