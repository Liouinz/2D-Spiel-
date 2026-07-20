# 🌍 Terraria Mundi — Prototyp (Phase 0)

> **Arbeitstitel** für ein 2D God-Sim / Aufbau-Sandbox-Spiel.
> Der vollständige Plan steht in [`docs/masterplan.md`](docs/masterplan.md).

Du bist keine Figur im Spiel — du bist die Welt selbst. Forme das Land, setze ein Volk aus und schau zu, was passiert.

## Was der Prototyp schon kann

- **Terrain malen** mit drei Tile-Typen (Gras, Wasser, Sand), Pinselgröße einstellbar
- **Start-Insel** wird per Noise generiert — kein leerer Bildschirm an Tag 1
- **Ein Volk aussetzen:** Siedler wandern umher, sammeln auf Gras Nahrung, bauen Hütten; Hütten bringen neue Siedler hervor
- **Erste Gottheit-Kraft: der Blitz** — tötet Siedler, zerstört Hütten, verbrennt Gras zu Sand (mit Screenshake und Lichteffekt)
- **Kamera:** Zoomen Richtung Mauszeiger, Schwenken, Zeitraffer ×1/×3/×10 und Pause
- **Chronik (Vorstufe):** Ereignisse werden als kleine Geschichtseinträge protokolliert („Jahr 3: Der Himmel schlug zu …")

Die Simulation tickt in festen Schritten (10 Ticks/Sek.) unabhängig vom Rendering, Siedler sind leichte Datenobjekte statt Nodes — beides Architektur-Vorgaben aus dem Masterplan, damit später tausende Einheiten möglich sind.

## Starten

1. [Godot 4.3+](https://godotengine.org/download) herunterladen (keine Installation nötig)
2. Godot öffnen → **Importieren** → diesen Ordner (`project.godot`) auswählen
3. **F5** drücken

## Steuerung

| Eingabe | Aktion |
|---|---|
| **1 / 2 / 3** | Werkzeug: Gras / Wasser / Sand malen |
| **4** | Volk aussetzen (3 Siedler) |
| **5** | Blitz werfen ⚡ |
| **Linke Maustaste** | Werkzeug anwenden (Malen auch per Ziehen) |
| **+ / −** | Pinselgröße ändern |
| **Mausrad** | Zoomen (Richtung Mauszeiger) |
| **Mittlere Maustaste / WASD / Pfeiltasten** | Kamera schwenken |
| **Leertaste** | Pause an/aus |
| **UI-Buttons** | Alles davon geht auch per Maus |

## Projektstruktur

```
project.godot            Godot-4-Projektdatei (Pixel-Rendering voreingestellt)
scenes/main.tscn         Hauptszene (nur Wurzel — alles Weitere entsteht im Code)
scripts/main.gd          Einstiegspunkt, Werkzeug-/Eingabe-Logik
scripts/terrain.gd       TileMapLayer, Tile-Typen, Insel-Generator, Malen
scripts/simulation.gd    Fester Simulations-Tick, Siedler-KI, Hütten, Blitz
scripts/settler.gd       Siedler als leichtes Datenobjekt
scripts/settler_layer.gd Rendering aller Siedler/Hütten/Effekte in einem Draw-Pass
scripts/camera_controller.gd  Zoom, Pan, Screenshake
scripts/game_ui.gd       Werkzeugleiste, Tempo, Statuszeile, Chronik
docs/masterplan.md       Der vollständige Masterplan
```

Alle Grafiken sind bewusst zur Laufzeit generierte Platzhalter — laut Masterplan (§8) kommt echte Pixel-Art erst in Phase 1, damit der Prototyp in 6 Wochen steht.

## Nächste Schritte (aus dem Masterplan, Phase 0 → 1)

- [x] Terrain malen (3 Tile-Typen)
- [x] Ein Volk aussetzen, das Hütten baut und Nahrung sammelt
- [x] Eine Gottheit-Kraft (Blitz)
- [x] Kamera: Zoomen, Schwenken, Zeitraffer
- [ ] **Meilenstein-Test:** 10 Minuten zuschauen, ohne dass es langweilig wird?
- [ ] Danach: Art-Style, Wachstumsstufen Lager → Dorf, Glauben-Ressource, Tag/Nacht, Speichern/Laden

---

*„Große Spiele entstehen nicht aus großen Plänen, sondern aus kleinen Schritten, die man wirklich geht."*
