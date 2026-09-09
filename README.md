# 🌍 Terraria Mundi — Prototyp

> **Arbeitstitel** für ein 2D God-Sim / Aufbau-Sandbox-Spiel.
> Der Zukunfts-Plan steht in [`docs/masterplan.md`](docs/masterplan.md).
> **Diese Datei beschreibt ausschließlich, was HEUTE im Code steht — nicht, was geplant ist.**

Du bist keine Figur im Spiel — du bist die Welt selbst. Du malst Land, setzt Völker aus und schaust zu.

---

## ⚡ Kurzüberblick: Was ist wirklich drin?

| Bereich | Drin? | Umfang |
|---|---|---|
| Terrain malen | ✅ | **7 Typen**, davon **5 malbar** (siehe unten) |
| Insel-Generator | ✅ | einmalig beim Start, kein Neu-Würfeln zur Laufzeit |
| Siedler | ✅ | 2 Berufe, Name, Alter, Lebensspanne |
| Dörfer | ✅ | Hüttenbau, Geburten, 3 Wachstumsstufen |
| Gottheit-Kräfte | ✅ | 4 Stück (Blitz, Regen, Segen, Meteor) + Volk aussetzen |
| Glauben-Ressource | ✅ | Einnahme passiv + pro Lieferung, Ausgabe pro Kraft |
| Tag/Nacht | ✅ | Farbtönung + bis zu 48 Punktlichter |
| Wetter | ⚠️ | nur Regen — und nur als Spieler-Kraft, kein eigenes Wettersystem |
| Chronik | ⚠️ | globaler Ticker, **nur die letzten 8 Zeilen**, kein Verlauf |
| Minimap | ✅ | live, Update alle 0,5 s |
| Kamera | ✅ | Zoom, Schwenken, Grenzen, Screenshake |
| Zeitraffer | ✅ | Pause / 1× / 3× / 10× |
| **Sound / Musik** | ❌ | **komplett nicht vorhanden** — kein einziger Audio-Knoten |
| **Speichern / Laden** | ❌ | **komplett nicht vorhanden** — Schließen = Welt weg |
| **Grafik-Assets** | ❌ | **keine einzige Bilddatei** — alle Grafik wird im Code gemalt |
| Shader / Partikel-Nodes | ❌ | nichts davon; alle Effekte laufen über `_draw()` |
| Undo / Rückgängig | ❌ | nicht vorhanden |
| Menü / Startbildschirm | ❌ | nicht vorhanden, Spiel startet direkt |

---

## 🎨 Die 7 Terrain-Typen

Definiert in `scripts/terrain.gd:8`. **Alle 7 existieren, aber nicht alle sind malbar:**

| # | Typ | Malbar? | Wie entsteht er sonst? |
|---|---|---|---|
| 0 | **Tiefwasser** | ✅ Taste `4` | Insel-Generator |
| 1 | **Flachwasser** | ❌ | **automatisch** — jede Wasserkachel mit Landnachbar wird Flachwasser |
| 2 | **Sand** | ✅ Taste `3` | Insel-Generator (Strand); Blitz/Meteor verbrennen Gras & Wald zu Sand |
| 3 | **Gras** | ✅ Taste `1` | Insel-Generator; Regen macht Sand zu Gras; Holzfäller roden Wald zu Gras |
| 4 | **Wald** | ✅ Taste `2` | Insel-Generator; wächst selbst auf Gras neben Wald; Regen |
| 5 | **Fels** | ✅ Taste `5` | Insel-Generator (Gebirge); Lava kühlt zu Fels ab |
| 6 | **Lava** | ❌ | **nur durch Meteor-Einschlag**, kühlt nach 400 Ticks zu Fels ab |

> **Hinweis zur Reduktion:** Wenn der Prototyp nur Gras/Sand/Wasser haben soll (Masterplan Phase 0: *„Terrain malen (3 Tile-Typen reichen)"*), müssen Wald, Fels und Lava aus `terrain.gd`, `main.gd`, `game_ui.gd` **und** aus der Siedler-Wirtschaft entfernt werden — der Beruf *Holzfäller* und die Ressource *Holz* hängen direkt am Wald. Das ist derzeit **nicht** so; aktuell sind alle 7 aktiv.

---

## 🧍 Was die Siedler wirklich tun

Ein Siedler ist **kein Node**, sondern ein leichtes Datenobjekt (`scripts/settler.gd`, 21 Zeilen). Er hat:
Name, Beruf, Dorf-ID, Geburts-Tick, Lebensspanne, Zustand, Traglast, Position, Ziel.

**Die komplette KI besteht aus genau diesem Kreislauf** (`simulation.gd:208-271`):

```
Ziel suchen  →  in gerader Linie hinlaufen  →  angekommen?
                                                   ↓
                        Boden = mein Rohstoff?  ja → aufnehmen, zum Dorf laufen
                                                nein → neues Ziel würfeln
```

- **Zielsuche ist reines Würfeln:** 12 Zufallsversuche im Umkreis ±16 Kacheln ums Dorf, dann 8 Versuche ±6 Kacheln um sich selbst. **Keine Wegfindung, kein A\*, kein Ausweichen.**
- **Bewegung ist eine Gerade** mit 3 Pixel pro Tick. Trifft der nächste Schritt auf Wasser, wird einfach ein neues Ziel gewürfelt.
- **Zwei Berufe:** *Sammler* nimmt Nahrung von Gras, *Holzfäller* nimmt Holz von Wald (und rodet ihn zu 30 %).
- **Tod:** nur durch Alter (Zufall, nachdem die Lebensspanne überschritten ist), Blitz, Meteor oder Betreten von Lava.
- **Nicht drin:** Hunger, Schlaf, Beziehungen, Charakterzüge, Kämpfe, Krankheit, Häuser bewohnen.

## 🏘 Was die Dörfer wirklich tun

Ein Dorf (`scripts/village.gd`, 18 Zeilen) hat: Name, Zentrum, Nahrung, Holz, Hüttenliste, Fruchtbarkeits-Timer, Stufe, „verlassen"-Flag.

Alle 10 Ticks (`simulation.gd:274-290`) passiert genau das:
1. Bevölkerung = 0? → Dorf gilt als verlassen, Chronik-Eintrag, Ende.
2. Genug Nahrung (6) **und** Holz (5) **und** Bevölkerung ≥ Hütten×2 **und** < 40 Hütten? → eine Hütte bauen.
3. Bevölkerung unter Kapazität (Hütten×3+4) und Nahrung ≥ 2? → mit 6 % (bzw. 25 % nach Segen) ein Kind.

**Stufen:** 3 Hütten → „Dorf", 8 Hütten → „Stadt". Die Stufe hat **keinerlei Auswirkung** — sie erzeugt nur eine Chronikzeile.

**Nicht drin:** Handel, Diplomatie, Krieg, Religion, Grenzen, Straßen, mehrere Völker.

---

## ⚡ Die Kräfte

| Taste | Kraft | Kosten | Wirkung im Code |
|---|---|---|---|
| `6` | Volk aussetzen | **0** | Gründet ein Dorf mit 4 Siedlern. Nicht auf Wasser/Lava. Wald/Fels wird zu Gras. |
| `7` | Blitz | 10 | Verbrennt Gras/Wald zu Sand (Radius 2 Kacheln), tötet Siedler und zerstört Hütten (Radius 28 px). Trifft er nichts, gibt es +2 Glauben. |
| `8` | Regen | 6 | 80 Ticks lang: Sand→Gras, Gras→Wald, Lava→Fels im Radius 90 px. |
| `9` | Segen | 8 | Nächstes Dorf (max. 150 px) bekommt +12 Nahrung und 600 Ticks hohe Geburtenrate. |
| `0` | Meteor | 40 | Fällt 14 Ticks lang, dann: Krater (Radius 4 Kacheln verbrannt), 3×3 Lava, tötet im Radius 52 px. |

**Glauben:** Start 20, Maximum 200. Einnahme: 0,002 pro Siedler pro Tick **plus** 0,05 pro abgelieferter Ressource.

---

## 🖼 Wie die Grafik entsteht (wichtig!)

**Es gibt keine einzige Bilddatei im Projekt.** Alles wird beim Start oder pro Frame im Code gemalt:

| Was | Wie | Datei |
|---|---|---|
| Terrain-Kacheln | 7 Typen × 4 Varianten × 16×16 px werden beim Start pixelweise in ein `Image` gemalt und zu einem TileSet gebacken | `terrain.gd:146-213` |
| Hütten, Lagerfeuer, Siedler | jeden Frame neu mit `draw_rect` / `draw_circle` / `draw_polygon` | `world_render.gd` |
| Blitz, Feuer, Glitzern, Funken | jeden Frame, additiv überblendet | `fx_glow.gd` |
| Wolken, Regen, Meteor | jeden Frame, normal überblendet | `fx_overlay.gd` |
| Tag/Nacht + Lichter | `CanvasModulate` + bis zu 48 `PointLight2D` | `light_manager.gd` |
| Minimap | 192×112 `Image`, alle 0,5 s pixelweise neu befüllt | `game_ui.gd:190-208` |

Ein Siedler besteht aus **3 Rechtecken** (Schatten, Rumpf, Kopf) plus optional 1 Rechteck für die Traglast.
Eine Hütte besteht aus **3 Rechtecken + 1 Dreieck**.
Ein Baum ist **1 Kreis + 2 Pixelspalten Stamm**, fest in die Kachel gemalt.

---

## 🎮 Steuerung

| Eingabe | Aktion |
|---|---|
| **1 – 5** | Terrain malen: Gras / Wald / Sand / Wasser / Fels |
| **6** | Volk aussetzen |
| **7 / 8 / 9 / 0** | Blitz / Regen / Segen / Meteor |
| **Linke Maustaste** | Werkzeug anwenden (Malen auch per Ziehen) |
| **+ / −** | Pinselgröße 1–8 |
| **Mausrad** | Zoomen (0,5× bis 8×) |
| **Mittlere Maustaste / WASD / Pfeiltasten** | Kamera schwenken |
| **Leertaste** | Pause an/aus |
| **UI-Buttons** | dasselbe per Maus |

> ⚠️ Die Zifferntasten nutzen logische Keycodes — **auf AZERTY-Tastaturen funktionieren 1–0 nicht.** WASD nutzt physische Tasten und funktioniert überall.

---

## 🔢 Alle Balancing-Zahlen an einem Ort

Alle aus `scripts/simulation.gd:12-36` und `scripts/terrain.gd:10-14`.

| Wert | Zahl | Bedeutung |
|---|---|---|
| Kartengröße | 192 × 112 Kacheln | = 3072 × 1792 Pixel |
| Kachelgröße | 16 px | 4 Zufallsvarianten pro Typ |
| Ticks pro Sekunde | 10 | fest, unabhängig von der Bildrate |
| Ticks pro Jahr | 200 | = 20 s bei Tempo 1× |
| Ticks pro Tag/Nacht | 600 | = 60 s bei Tempo 1× |
| Siedler-Tempo | 3 px / Tick | ≈ 1,9 Kacheln pro Sekunde |
| Hütte kostet | 6 Nahrung + 5 Holz | max. 40 Hütten pro Dorf |
| Geburt kostet | 2 Nahrung | Kapazität = Hütten × 3 + 4 |
| Lebensspanne | 55–85 „Jahre" | danach 0,2 % Sterbechance pro Tick |
| Lava kühlt ab nach | 400 Ticks | zu Fels |

> ⚠️ **Ein „Jahr" (200 Ticks) ist kürzer als ein „Tag" (600 Ticks).** Ein Siedler mit 70 Jahren hat rund 23 Tage erlebt. Die Jahreszahlen in der Chronik sind dadurch inhaltlich sinnlos.

---

## 🐞 Bekannte Fehler (Stand: aktuelle Analyse)

Die vollständige Liste mit Zeilennummern steht in der Fehleranalyse. Die schwerwiegendsten:

1. **Malen bleibt hängen:** Lässt man die Maustaste über einem UI-Panel oder außerhalb des Fensters los, malt das Spiel danach ohne gedrückte Taste weiter.
2. **Träger liefern am falschen Ort ab:** Wird ein heimkehrender Siedler von Wasser blockiert, bucht er seine Last dort, wo er gerade steht.
3. **Siedler können dauerhaft einfrieren**, wenn kein erreichbares Ziel gefunden wird.
4. **Terraforming hat keine Konsequenz:** Malt man Wasser über ein Dorf, schwimmen Hütten und Lagerfeuer weiter und das Dorf wächst normal.
5. **Nahrung ist unendlich** — Gras wird beim Ernten nicht verbraucht.
6. **Glaube saturiert** — ab einigen hundert Siedlern sind alle Kräfte praktisch kostenlos.
7. **Baumstämme sind zu 2/3 von der Krone verdeckt** — sichtbar bleibt exakt 1 Pixel.
8. **Siedler-Kopf sitzt 0,5 px rechts versetzt** auf dem Rumpf; die Traglast schwebt 1 px über dem Kopf.
9. **Siedler wippen weiter, während das Spiel pausiert ist.**
10. **Kein Culling:** Es wird immer die ganze Karte gezeichnet, auch was außerhalb des Bildes liegt.

---

## 🚀 Starten

1. [Godot 4.3+](https://godotengine.org/download) herunterladen (keine Installation nötig)
2. Godot öffnen → **Importieren** → diesen Ordner (`project.godot`) auswählen
3. **F5** drücken

Renderer ist auf **GL Compatibility** eingestellt, läuft also auch auf schwacher Hardware.

---

## 📁 Projektstruktur

```
project.godot                 Godot-4.3-Projektdatei (Nearest-Filter für Pixel-Art)
scenes/main.tscn              Hauptszene — enthält NUR den Wurzelknoten,
                              die gesamte Hierarchie entsteht in main.gd zur Laufzeit
scripts/main.gd          120  Einstiegspunkt, Werkzeuge, Tastatur/Maus
scripts/terrain.gd       221  TileMapLayer, 7 Typen, Insel-Generator, Küsten, Kachel-Grafik
scripts/simulation.gd    497  Fester Tick: Dörfer, Siedler, Glauben, Kräfte, Wetter, Lava
scripts/settler.gd        21  Siedler als reines Datenobjekt
scripts/village.gd        18  Dorf als reines Datenobjekt
scripts/names.gd          29  40 Vornamen, 15 Präfixe × 12 Suffixe für Dorfnamen
scripts/world_render.gd   75  Hütten, Lagerfeuer, Siedler — ein Draw-Pass, interpoliert
scripts/fx_glow.gd       110  Additiv: Blitz, Feuer, Glitzern, Funken, Einschlag
scripts/fx_overlay.gd     75  Normal: Wolken, Regen, Meteor-Sturz
scripts/light_manager.gd  73  Tag/Nacht-Tönung + bis zu 48 Punktlichter
scripts/camera_controller.gd 64  Zoom, Schwenken, Kartengrenzen, Screenshake
scripts/game_ui.gd       251  Werkzeugleiste, Statuszeile, Chronik, Minimap
docs/masterplan.md       200  Der Zukunfts-Plan (NICHT der Ist-Zustand)
```

**Gesamt: ~1.550 Zeilen GDScript, 0 Asset-Dateien, 0 Tests.**

---

## 📍 Ehrlicher Stand gegenüber der Roadmap

**Phase 0 (Prototyp):** erfüllt — Terrain malen ✓, Volk mit Hütten & Nahrung ✓, Gottheit-Kraft ✓, Kamera mit Zoom/Schwenken/Zeitraffer ✓

**Aus Phase 1 angefangen:** 4 Kräfte + Glauben ✓ · Tag/Nacht ✓ · Wachstumsstufen ✓ (ohne Wirkung) · sichtbarer Transport ✓ (mit Fehler)

**Aus Phase 1 komplett offen:** finaler Art-Style · Sound-Grundgerüst · Speichern/Laden

**Aus Phase 2 komplett offen:** weitere Völker · Diplomatie · Religion · echte Dorf-Chroniken · Szenarien

---

*„Große Spiele entstehen nicht aus großen Plänen, sondern aus kleinen Schritten, die man wirklich geht."*
