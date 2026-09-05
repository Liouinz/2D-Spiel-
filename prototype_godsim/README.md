# 🌍 Terraria Mundi — Prototyp

> **Arbeitstitel** für ein 2D God-Sim / Aufbau-Sandbox-Spiel.
> Der vollständige Plan steht in [`docs/masterplan.md`](docs/masterplan.md).

Du bist keine Figur im Spiel — du bist die Welt selbst. Forme das Land, setze Völker aus und schau zu, wie aus einem Lagerfeuer eine Stadt wird — oder wirf einen Meteor und lies hinterher in der Chronik, was du angerichtet hast.

## Was der Prototyp kann

**Welt formen**
- 7 Terrain-Typen: Tiefwasser, Flachwasser, Sand, Gras, Wald, Fels, Lava — Küstenlinien (flaches Wasser) entstehen automatisch am Übergang zu Land
- Pinsel-Malen mit einstellbarer Größe, prozedural generierte Start-Insel mit Stränden, Wäldern und Gebirge
- Der Wald lebt: Er breitet sich langsam auf angrenzendes Grasland aus; Holzfäller roden ihn

**Völker mit Persönlichkeit**
- Jedes Dorf hat einen generierten Namen (Grünfeld, Steinfurt, Rabental …), jeder Siedler einen eigenen Namen, Beruf und eine Lebensspanne
- Zwei Berufe mit sichtbarer Arbeit: **Sammler** holen Nahrung vom Grasland, **Holzfäller** schlagen Wald — man sieht die Träger mit ihrer Last zum Lagerfeuer laufen (Wirtschaft light aus dem Masterplan)
- Dörfer wachsen in Stufen: **Lager → Dorf → Stadt**, Hütten kosten Nahrung + Holz, Geburten kosten Nahrung, Alte sterben friedlich
- Fährt ein Dorf gegen die Wand, wird es verlassen — und die Chronik hält es fest

**Kräfte der Gottheit (kosten Glauben)**
- **Blitz (10):** tötet, zerstört Hütten, verbrennt Land — trifft er nur Erde, wächst die Furcht (und dein Glaube)
- **Regen (6):** lässt Sand ergrünen, Wald sprießen und kühlt Lava zu Fels
- **Segen (8):** füllt die Speicher eines Dorfes und macht es eine Zeit lang fruchtbar
- **Meteor (40):** stürzt sichtbar vom Himmel, hinterlässt einen glühenden Lava-Krater, der über Jahre zu Fels erkaltet
- Glauben bekommst du passiv von jedem lebenden Siedler und für jede eingelagerte Ressource — der Balancing-Loop aus dem Masterplan

**Atmosphäre („extrem hochwertig" angefangen)**
- Tag/Nacht-Zyklus: warmes Abendlicht, blaue Nächte — Lagerfeuer und Hüttenfenster leuchten nachts mit echten 2D-Lichtern
- Wolkenschatten ziehen über das Land, Wasser glitzert, Lava glüht, Feuer flackern
- „Juice": Screenshake bei Blitz und Meteor, Einschlags-Feuerball, Segen-Funkenregen
- Siedler-Rendering wird zwischen den Simulations-Ticks interpoliert und wippt beim Gehen

**Bedienung & Überblick**
- Minimap (live), Chronik-Panel mit den letzten 8 Ereignissen, Statuszeile
- Hover über einen Siedler zeigt: *„→ Aldo (Holzfäller, 34 Jahre) aus Grünfeld"*
- Zeitraffer Pause/1×/3×/10×; die Simulation tickt fest mit 10 Ticks/Sek., getrennt vom Rendering

## Starten

1. [Godot 4.3+](https://godotengine.org/download) herunterladen (keine Installation nötig)
2. Godot öffnen → **Importieren** → diesen Ordner (`project.godot`) auswählen
3. **F5** drücken

## Steuerung

| Eingabe | Aktion |
|---|---|
| **1–5** | Terrain malen: Gras / Wald / Sand / Wasser / Fels |
| **6** | Volk aussetzen (gründet ein benanntes Dorf) |
| **7 / 8 / 9 / 0** | Blitz / Regen / Segen / Meteor |
| **Linke Maustaste** | Werkzeug anwenden (Malen auch per Ziehen) |
| **+ / −** | Pinselgröße ändern |
| **Mausrad** | Zoomen (Richtung Mauszeiger) |
| **Mittlere Maustaste / WASD / Pfeiltasten** | Kamera schwenken |
| **Leertaste** | Pause an/aus |
| **UI-Buttons** | Alles davon geht auch per Maus |

## Projektstruktur

```
project.godot                 Godot-4-Projektdatei (Pixel-Rendering voreingestellt)
scenes/main.tscn              Hauptszene (nur Wurzel — alles Weitere entsteht im Code)
scripts/main.gd               Einstiegspunkt, Werkzeuge, Eingabe
scripts/terrain.gd            TileMapLayer: 7 Typen, Insel-Generator, Küsten-Logik
scripts/simulation.gd         Fester Tick: Dörfer, Wirtschaft, Glauben, Kräfte, Wetter
scripts/settler.gd            Siedler als leichtes Datenobjekt
scripts/village.gd            Dorf mit Namen, Lagern und Wachstumsstufen
scripts/names.gd              Namens-Generator für Siedler und Dörfer
scripts/world_render.gd       Hütten, Lagerfeuer, Siedler — ein Draw-Pass, interpoliert
scripts/fx_glow.gd            Additive Effekte: Blitz, Feuer, Glitzern, Funken
scripts/fx_overlay.gd         Wolken, Regen, Meteor-Sturz
scripts/light_manager.gd      Tag/Nacht-Tönung + 2D-Lichter für Feuer und Hütten
scripts/camera_controller.gd  Zoom, Pan, Kartengrenzen, Screenshake
scripts/game_ui.gd            Werkzeugleiste, Statuszeile, Chronik, Minimap
docs/masterplan.md            Der vollständige Masterplan
```

Alle Grafiken sind bewusst zur Laufzeit generierte Platzhalter — laut Masterplan (§8) kommt echte Pixel-Art erst in Phase 1, damit der Prototyp schnell steht.

## Stand gegenüber der Roadmap

**Phase 0 (Prototyp) — komplett:** Terrain malen ✓ · Volk mit Hütten & Nahrung ✓ · Gottheit-Kraft ✓ · Kamera mit Zoom/Schwenken/Zeitraffer ✓

**Aus Phase 1 & 2 bereits angezogen:** 5 Kräfte mit Glauben-Ressource ✓ · Tag/Nacht & Wetter ✓ · Wachstumsstufen Lager → Dorf → Stadt ✓ · Chronik-Grundgerüst ✓ · sichtbarer Ressourcen-Transport ✓

**Als Nächstes:** Speichern/Laden · finaler Art-Style (Palette + Pixel-Art) · Sound-Grundgerüst · Religion (Völker deuten deine Eingriffe) · das 10-Minuten-Zuschau-Meilenstein-Video

---

*„Große Spiele entstehen nicht aus großen Plänen, sondern aus kleinen Schritten, die man wirklich geht."*
