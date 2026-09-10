# 🌍 Terraria Mundi — Prototyp

> **Arbeitstitel** für ein 2D God-Sim / Aufbau-Sandbox-Spiel.
> Der vollständige Plan steht in [`docs/masterplan.md`](docs/masterplan.md),
> die Messwerte zur Leistung in [`docs/performance.md`](docs/performance.md).

Du bist keine Figur im Spiel — du bist die Welt selbst. Forme das Land, setze Völker aus und schau zu, wie aus einem Lagerfeuer eine Stadt wird — oder wirf einen Meteor und lies hinterher in der Chronik, was du angerichtet hast.

## Starten

1. [Godot 4.3+](https://godotengine.org/download) herunterladen (keine Installation nötig)
2. Godot öffnen → **Importieren** → diesen Ordner (`project.godot`) auswählen
3. **F5** drücken

## Steuerung — vollständig frei belegbar

Die Spiellogik kennt **keine festen Tasten**. Sie fragt ausschliesslich
*Actions* ab (`move_up`, `place_block`, `toggle_debug` …); welche Eingabe eine
Action auslöst, entscheidest du im Menü unter **Einstellungen → Steuerung**.

* Jede Action darf **mehrere** Eingaben haben — deshalb funktionieren WASD und
  die Pfeiltasten von Haus aus gleichzeitig.
* Tasten **und** Mausknöpfe sind belegbar.
* Doppelbelegungen werden erkannt und rot markiert (verboten sind sie nicht).
* Standard wiederherstellen · Änderungen verwerfen · Speichern — deine
  Belegung liegt in `user://keybinds.cfg` und überlebt den Neustart.

Die Standardbelegung:

| Eingabe | Action |
|---|---|
| **W A S D** / **Pfeiltasten** | Kamera bewegen |
| **Umschalt** | schneller bewegen |
| **Mausrad** | Zoom (feste Stufen 100 % / 85 % / 70 %) |
| **Maus Mitte** | Kamera ziehen |
| **Maus links** | Ausgewähltes Werkzeug anwenden (Malen auch per Ziehen) |
| **Maus rechts** | Entfernen: Fackel aufnehmen, Wald/Fels roden, Wasser trockenlegen |
| **1 – 0, Umschalt+1** | Schnellleisten-Slot wählen |
| **+ / −** | Pinselgrösse |
| **Leertaste** | Simulation anhalten |
| **Bild ↑ / Bild ↓** | Tempo eine Stufe hoch/runter (Pause · 1× · 3× · 10×) |
| **Esc** | Menü / zurück |
| **F3** | Entwickler-Overlay |
| **M · C · F1** | Minimap · Chronik · HUD ein-/ausblenden |
| **I / Tab** | Einstellungen |

## Was der Prototyp kann

**Welt formen**
- 7 Terrain-Typen: Tiefwasser, Flachwasser, Sand, Gras, Wald, Fels, Lava — Küstenlinien entstehen automatisch am Übergang zu Land
- Pinsel-Malen mit einstellbarer Grösse, prozedural generierte Start-Insel
- Der Wald lebt: Er breitet sich langsam auf angrenzendes Grasland aus; Holzfäller roden ihn

**Bausystem mit echter Autoconnection**
- Jedes Tile wählt seine Form aus **47 Blob-Varianten**, abgeleitet ausschliesslich aus den acht *tatsächlichen* Nachbarzellen
- Eine Diagonale zählt nur, wenn beide angrenzenden Kardinalrichtungen besetzt sind — deshalb kann eine echte Lücke im Raster niemals visuell zuwachsen
- Kanten, Aussen- und Innenecken, Übergänge und getrennte Strukturen erkennt das System selbst; es gibt keine manuellen Spezialblöcke
- Die Variante pro Zelle ist **deterministisch**: Dieselbe Zelle sieht nach jedem Neusetzen gleich aus
- Minimap, Weltlogik und Darstellung lesen dasselbe Typ-Raster

**Wasser, das nicht nach Raster aussieht**
- Wasser liegt als **transparente Auflage über dem Boden** (Meeresgrund/Sand), nicht als undurchsichtige Kachel — dadurch runde Ufer, weiche Ecken und echte Übergänge zu Sand und Gras
- Getrennte Ebene für den dunklen Tiefwasser-Kern: unterschiedliche Wasserstände mit eigener, weicher Grenze
- Ein Shader auf den Wasserebenen lässt die Fläche wandern und glitzern
- **Wellenringe**, wenn Siedler durch Flachwasser waten, Regen fällt oder etwas einschlägt — sie laufen weich aus
- Optionale Fische, die nur im sichtbaren Bereich leben (Anzahl aus dem Grafikprofil)

**Nacht & Licht**
- Tiefe, blaue Nächte mit begrenzter Sichtweite; Lagerfeuer, Hüttenfenster, Fackeln und Lava leuchten warm und flackern
- **Fackeln** als setzbare, tragbare Lichtquelle mit begrenzter Reichweite
- Technisch: eine Lightmap in Kachelauflösung, in *einem* Zeichenaufruf multiplikativ über die Welt gelegt — statt bis zu 48 Einzellichtern, die in der GL-Compatibility-Pipeline jedes Element mehrfach neu zeichnen liessen. Der Tag/Nacht-Aufschlag fiel dadurch von **+12,2 ms auf +3,1 ms pro Bild**. Details: [`docs/performance.md`](docs/performance.md)

**Völker mit Persönlichkeit**
- Jedes Dorf hat einen generierten Namen, jeder Siedler einen eigenen Namen, Beruf und eine Lebensspanne
- **Sammler** holen Nahrung vom Grasland, **Holzfäller** schlagen Wald — man sieht die Träger mit ihrer Last zum Lagerfeuer laufen
- Siedler waten durch Flachwasser (langsamer, mit Wellenspur), meiden aber Tiefwasser
- Dörfer wachsen in Stufen: **Lager → Dorf → Stadt**; fährt ein Dorf gegen die Wand, hält es die Chronik fest

**Kräfte der Gottheit (kosten Glauben)**
- **Blitz (10)** · **Regen (6)** · **Segen (8)** · **Meteor (40)**
- Glauben bekommst du passiv von jedem lebenden Siedler und für jede eingelagerte Ressource

**Hardware-Erkennung & adaptive Qualität**
- Beim Start werden CPU, Kernzahl, GPU, GPU-Typ, RAM und Bildschirm erkannt und daraus ein Profil abgeleitet: **HOCH / MITTEL / NIEDRIG**
- Jedes Profil steuert die Systeme **einzeln** (Lichtauflösung und -takt, Lichtbudget, Wolken, Funken, Regentropfen, Wasseranimation, Wellen, Fische, Schatten, Minimap-Takt, Render Scale) — nicht pauschal „alles auf LOW“
- Bricht die Bildrate länger ein, senkt die dynamische Qualität **gezielt und in dieser Reihenfolge**: Kosmetik am Bildrand → Lichtauflösung und -takt → Wasseranimation und Renderauflösung. Erholt sich die Rate, wird vorsichtig und mit Hysterese zurückgenommen
- Alles ist im Menü überschreibbar; Spieler-Einstellungen schlagen das Profil

**Entwickler-Overlay (F3)**
FPS und Ø-FPS · Frametime, Ø, 1 % Low, Spitze · CPU `_process` und `_physics` ·
Zeichenaufrufe, Objekte, Primitive · Auflösung, Render Scale, Zoom ·
Speicher (Spiel, Video, Texturen, RAM verfügbar/gesamt, Nodes/Objekte) ·
Kameraposition und Chunk · sichtbare Tiles und Tilemap-Blöcke ·
Siedler/Dörfer/Hütten (jeweils gesamt **und** gezeichnet) · Fackeln, Partikel,
Wellen, Fische · Lichtquellen (aktiv von gefunden), Lightmap-Zellen und
**Neuberechnungszeit in ms/Hz** · Grafikprofil und Dynamikstufe · erkannte Hardware.

> Es werden ausschliesslich **gemessene** Werte angezeigt. Was die
> GL-Compatibility-Pipeline nicht liefert — eine echte GPU-Zeit pro Bild —
> steht dort als `n/v` und wird nicht geschätzt.

**Oberfläche**
- Startbildschirm, Pausemenü, Einstellungen mit drei Reitern (Grafik · Steuerung · Spiel)
- HUD mit Statusleiste, Schnellleiste (Icons, belegte Taste je Slot, Tooltips, Glaubens-Warnfarbe), Chronik, Minimap mit Sichtfeld-Rahmen und Einblendungen
- Ein einziges Theme für alles: gleiche Rahmen, Farben, Pixelkanten, Abstände und Zustände

## Projektstruktur

```
project.godot                     Godot-4-Projektdatei (Pixel-Rendering voreingestellt)
scenes/main.tscn                  Hauptszene (nur Wurzel — alles Weitere entsteht im Code)
scripts/main.gd                   Einstiegspunkt, Werkzeuge, Eingabe (ohne feste Tasten)
scripts/simulation.gd             Fester Tick: Dörfer, Wirtschaft, Glauben, Kräfte, Wetter, Fackeln
scripts/terrain.gd                Typ-Raster + vier Zeichenebenen, Dirty-Region-Autotiling
scripts/settler.gd                Siedler als leichtes Datenobjekt
scripts/village.gd                Dorf mit Namen, Lagern und Wachstumsstufen
scripts/names.gd                  Namens-Generator
scripts/world_render.gd           Hütten, Feuer, Fackeln, Siedler — gecullt, nach Primitiv gruppiert
scripts/fx_glow.gd                Additive Effekte über der Lightmap: Blitz, Feuer, Funken
scripts/fx_overlay.gd             Wolken, Regen, Meteor — unter der Lightmap
scripts/camera_controller.gd      Feste Zoomstufen, Action-Steuerung, Kartengrenzen, Screenshake
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

tests/verify.gd                   46 Abnahmeprüfungen (headless, CI-tauglich)
tests/benchmark.tscn              Reproduzierbares Frametime-Messharness

docs/masterplan.md                Der vollständige Masterplan
docs/performance.md               Messaufbau, Engpass, Ergebnisse
```

## Prüfen und nachmessen

```bash
# 46 Abnahmeprüfungen (Steuerung, Grafikprofile, Autoconnection, Fackeln, Welt)
godot --headless --path . --script res://tests/verify.gd

# Frametimes mit und ohne einzelne Systeme — die Grundlage von docs/performance.md
godot --path . --rendering-driver opengl3 res://tests/benchmark.tscn
```

Alle Grafiken werden weiterhin **zur Laufzeit erzeugt** — Tile-Atlas, Item-Icons
und UI-Stile entstehen aus der Palette in `scripts/core/palette.gd`. Ein
Farbwechsel dort zieht sich automatisch durch das ganze Spiel.

## Stand gegenüber der Roadmap

**Phase 0 (Prototyp) — komplett:** Terrain malen ✓ · Volk mit Hütten & Nahrung ✓ · Gottheit-Kraft ✓ · Kamera ✓

**Aus Phase 1 & 2 bereits angezogen:** 5 Kräfte mit Glauben-Ressource ✓ · Tag/Nacht & Wetter ✓ · Wachstumsstufen ✓ · Chronik ✓ · sichtbarer Ressourcen-Transport ✓ · dynamisches Licht mit Fackeln ✓ · frei belegbare Steuerung ✓ · adaptive Grafikprofile ✓

**Als Nächstes:** Speichern/Laden · Sound-Grundgerüst · Religion (Völker deuten deine Eingriffe) · handgezeichnete Pixel-Art anstelle der prozeduralen Platzhalter

---

*„Große Spiele entstehen nicht aus großen Plänen, sondern aus kleinen Schritten, die man wirklich geht."*
