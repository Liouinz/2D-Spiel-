# 🌾 Talhain

Ein kleines 2D-Top-Down-Abenteuer für Laptop und Desktop, gebaut mit **Godot 4.3**.
Du läufst als Wanderer durch eine überschaubare Insel: Dorf, Wiese, Wald, Felsen und eine Bucht mit Strand.

![Das Dorf](docs/bilder/dorf.png)

## So wird das Spiel gestartet

1. [Godot 4.3+](https://godotengine.org/download) herunterladen — eine einzelne
   ausführbare Datei, keine Installation nötig
2. Godot öffnen → **Importieren** → diesen Ordner wählen (die Datei `project.godot`)
3. **F5** drücken

Es startet die Szene `scenes/main.tscn`. Danach erscheint das Hauptmenü,
**SPIELEN** lädt die Welt (rund 1,5 Sekunden), und die Figur steht am Dorfplatz.

### Ohne Editor, direkt im Terminal

Zwei Befehle. Der erste ist **nur beim allerersten Mal** nötig — er legt den
Import-Cache an. Ohne ihn bricht Godot mit `Identifier "Config" not declared`
ab, weil die Skripte sich ohne Cache gegenseitig nicht finden.

```bash
cd <Ordner mit project.godot>
godot --headless --import      # einmalig, dauert ein paar Sekunden
godot                          # Spiel starten
```

Heißt die Godot-Datei bei dir anders (etwa `Godot_v4.3-stable_win64.exe` oder
`Godot.app`), nimm diesen Namen statt `godot`:

| System | erster Befehl (einmalig) | danach jedes Mal |
|---|---|---|
| **Windows** | `.\Godot_v4.3-stable_win64.exe --headless --import` | `.\Godot_v4.3-stable_win64.exe` |
| **macOS** | `/Applications/Godot.app/Contents/MacOS/Godot --headless --import` | `/Applications/Godot.app/Contents/MacOS/Godot` |
| **Linux** | `./Godot_v4.3-stable_linux.x86_64 --headless --import` | `./Godot_v4.3-stable_linux.x86_64` |

Beim Öffnen über die Godot-Oberfläche entfällt der Import-Befehl — das erledigt
der Editor selbst.

Alle Grafiken und Klänge entstehen beim Start im Spiel selbst — es müssen
keine Assets heruntergeladen oder importiert werden. Die Lizenzlage ist in
[`CREDITS.md`](CREDITS.md) dokumentiert.

## Aufbaumodus (aktuell aktiv)

Das Spiel startet mit einer **leeren Karte und sichtbarem Blockraster**. Das
Raster ist das technische Skelett der Welt und im fertigen Spiel unsichtbar —
hier wird es absichtlich in Rot gezeigt, damit sich planen lässt, wie viele
Blöcke ein Objekt belegt.

- **Ein Block = 32 × 32 Pixel.** Die Karte ist **2048 × 2048 Blöcke** groß —
  65 536 × 65 536 Pixel. Einmal quer durchzulaufen dauert rennend rund vier
  Minuten.
- **Ein Chunk = 16 × 16 Blöcke** (512 px), also **128 × 128 = 16 384 Chunks**.
  Die Chunk-Grenzen sind gelb und tragen ihre Nummer in der oberen linken Ecke.
- Geladen sind immer nur **5 × 5 Chunks um die Figur**; beim Laufen kommen neue
  dazu und alte fallen weg. Ohne das wäre die Karte nicht darstellbar.
- Der Block unter der Figur ist hervorgehoben.
- Oben links steht Chunk, Block und Position innerhalb des Chunks.
- Oben rechts eine **Minimap** mit vier Chunks Umgebung.
- **G** schaltet nur die **Rasterlinien** um. Die Bauvorschau unter dem Zeiger
  bleibt immer sichtbar — sie zeigt die gewählte Kachel halbdurchsichtig im
  Block, damit man sieht, *wohin* und *was* man setzt.

Zum Größenvergleich: ein kleines Wohnhaus ist 92 px breit, belegt also rund
3 Blöcke in der Breite und 3 in der Höhe; die Scheune 5 × 3 Blöcke.

### Bauen

Unten steht eine Leiste mit acht Bodentypen. Jedes Feld zeigt die echte
Bodenkachel, nicht ein Ersatzsymbol.

- **1 – 8**, **Mausrad** oder ein **Klick auf das Feld** wählt den Bodentyp.
- **Linke Maustaste** setzt ihn auf den Block unter dem Zeiger, **rechte
  Maustaste** setzt zurück auf Gras. Gedrückt halten malt.
- Der Block unter dem Zeiger ist weiß umrandet.
- Gesetztes **Wasser lässt sich durchschwimmen** — die Figur sinkt ein, wird
  langsamer und bekommt einen Wellenkragen. **Tiefwasser** bleibt eine Wand.
- **Fels** sieht aus wie eine Klippe: Wandfläche nach unten, Lichtkante oben,
  Schlagschatten darunter. Begehbar bleibt er trotzdem.
- Die Übergänge zu den Nachbarn werden sofort mitgerechnet — ein gesetzter Weg
  bekommt saubere Kanten, ganz ohne Nacharbeit.

![Bauen mit der Leiste](docs/bilder/bauen.png)

Klippe mit Wand und Schlagschatten, Teich mit Uferkante, Minimap oben rechts.

![Schwimmen](docs/bilder/schwimmen.png)

Die gebaute Karte wird **beim Zurückgehen ins Hauptmenü und beim Beenden
automatisch gesichert**, mit **F5** auch von Hand. Sie liegt in
`user://karte.dat` (unter Linux `~/.local/share/godot/app_userdata/Talhain/`).
Passen Fassung oder Kartenmaße nicht, wird die Datei übergangen statt zu
stürzen.

Umschalten in `src/core/config.gd`:

```gdscript
const EMPTY_WORLD := true    # false = wieder die komplette Insel mit Dorf und Wald
```

Der Code für Insel, Dorf, Wald, Wege und Küste bleibt vollständig erhalten und
kommt mit `false` unverändert zurück.

## Steuerung

| Eingabe | Aktion |
|---|---|
| **W A S D** oder **Pfeiltasten** | Laufen |
| **Shift** | Rennen (nicht im Wasser) |
| **Leertaste** | Springen (nicht im Wasser) |
| **G** | Blockraster ein / aus |
| **1 – 8** / **Mausrad** | Bodentyp wählen (Aufbaumodus) |
| **Linke Maustaste** | Block setzen (Aufbaumodus) |
| **Rechte Maustaste** | Block zurücksetzen (Aufbaumodus) |
| **F5** | Karte speichern (Aufbaumodus) |
| **ESC** | Pause-Menü öffnen / schließen |
| **Maus** | Menüs bedienen |

## Was drin ist

**Welt** — Eine Insel aus 96 × 80 Kacheln (der Aufbaumodus ist 2048 × 2048) mit klar erkennbaren Gebieten: ein Dorf mit
gepflastertem Platz, Brunnen und elf Gebäuden, dichter Misch­wald im Nordwesten, blühende Wiese im
Nordosten, Felsland im Osten und eine Bucht mit Sandstrand im Südwesten. Getretene Erdwege
verbinden alles miteinander.

**Dorf** — Acht Gebäudetypen (Gasthaus, Schmiede, Werkstatt, Bauernhaus, Scheune, Wohnhäuser,
Schuppen) in insgesamt 17 Varianten: Fachwerk, Putz, Bretterwand oder Bruchstein, dazu Ziegel-,
Schiefer- oder Reetdächer, Schornsteine, Markisen, Wirtshausschild. Dazwischen Brunnen, Bänke,
Laternen, Holzstapel, Blumenkästen, Fässer, Kisten, Zäune und Vorgärten.

**Wald** — Neun Baumarten in 26 Varianten (Eiche, dunkle Eiche, Herbsteiche, Birke, alter Baum,
Jungbaum, große und kleine Fichte) plus Büsche, Farne, Baumstümpfe und Totholz. Die Verteilung
folgt Dichtefeldern statt gleichmäßigem Würfeln: es gibt Gruppen, dichte Bestände, Lichtungen und
ausgedünnte Waldränder.

**Auflösung** — 32 × 32 Pixel je Kachel bei Kamerazoom 1,5. Gegenüber der
ersten Fassung (16 px bei Zoom 3) ist das Sichtfeld unverändert, jede Kachel
hat aber die vierfache Pixelfläche. Alle Grafiken wurden dafür neu gezeichnet,
nicht hochskaliert.

**Boden** — Ein echtes Kachelraster aus neun `TileMapLayer`. Gras füllt die Karte, darüber liegen
Wiese, Waldboden, Fels, Sand, Wasser, Tiefwasser, Weg und Pflaster. Die Schichten blenden sich per
Terrain-Autotiling ineinander: Übergangskacheln entstehen aus bilinearer Eckinterpolation mit
gedithertem Schwellwert, gebaute Flächen wie Weg und Pflaster bekommen stattdessen eckige
Quadranten. Das `TileSet` wird prozedural erzeugt, hat benannte Terrains mit Eck-Bits und lässt
sich im Godot-Editor mit dem Terrain-Pinsel weitermalen. Im Spiel ist vom Raster nichts zu sehen.

**Wege** — Achsparallel gebaut: zwischen zwei Wegpunkten erst die längere, dann die kürzere Achse.
Daraus entstehen gerade Strecken, rechte Winkel und echte T-Kreuzungen. Zwei Hauptachsen kreuzen
sich auf dem Dorfplatz, davon zweigen Ausfallstraßen und Stichwege zu den Höfen ab.

**Grafik** — Alle Texturen entstehen zur Laufzeit aus **einer** Farbpalette. Jede Fläche wird über
eine Farbrampe schattiert, deren Licht bei allen Objekten aus derselben Richtung kommt (oben
links); zwischen den Stufen wird gedithert. Bodenkacheln gibt es in vier Varianten mal drei
großflächigen Helligkeitsstufen, dazu Streudekoration, Hecken als Grundstücksgrenzen und
eingebackene Schatten. Das Wasser glitzert, der Uferschaum bewegt sich.

**Spieler** — Eigene Figur mit Idle- und Laufanimation in drei Blickrichtungen (die vierte wird
gespiegelt), Beschleunigung und Reibung, Schrittgeräusche.

![Wald und Dorfrand](docs/bilder/wald.png)

**Kamera** — Folgt weich, bleibt innerhalb der Weltgrenzen.

**Kollision** — Bäume, Felsen, Häuser, Zäune und Wasser blockieren; Wege, Wiesen und Strand sind
begehbar. Jedes Objekt kollidiert nur mit seinem Fußabdruck am Boden, nicht mit der ganzen
Bildfläche — man läuft also hinter einer Baumkrone und einem Hausdach vorbei, aber nicht durch
Stamm oder Wand. Die Wasserflächen werden per Greedy-Zerlegung zu wenigen grossen Rechtecken
zusammengefasst.

**UI** — Hauptmenü, Pause-Menü und Optionen (Musik, Effekte, Vollbild, Hinweise) mit erzeugten
Pixel-Art-Rahmen: Holzknöpfe mit Fase und Nieten, gerahmte Tafeln. Das Titelbild hat gestaffelte
Hügel mit Dunstschleiern, ziehende Wolken und einen Vordergrund aus Halmen. Einstellungen werden
gespeichert.

**Audio** — Menü- und Weltmusik sowie alle Effekte werden rechnerisch erzeugt. Es gibt keine
Audiodateien im Projekt.

![Die Bucht](docs/bilder/strand.png)

## Projektstruktur

```
project.godot              Godot-4-Projekt (Nearest-Filter, GL Compatibility)
scenes/main.tscn           Einstiegsszene — alles Weitere entsteht im Code

src/core/config.gd         Konstanten (Kachelgröße, Tempo, Zoom) + Tastenbelegung
src/core/palette.gd        Die eine Farbpalette für alle Grafiken
src/core/settings.gd       Autoload: Einstellungen, persistent
src/core/main.gd           Zustandsautomat MENÜ / SPIEL / PAUSE / OPTIONEN

src/gfx/pixel.gd           Zeichen-Werkzeuge auf Images (Rechteck, Ellipse, Outline, Farbrampe)
src/gfx/tile_art.gd        Bodenkacheln, Helligkeitsstufen, Streudekoration
src/gfx/terrain_atlas.gd   Übergangskacheln für das Eck-Autotiling
src/gfx/prop_art.gd        Bäume, Felsen, Gebäude, Dorfinventar — alles mit Varianten
src/gfx/actor_art.gd       Spielerfigur (Idle + Laufzyklus, 3 Richtungen)

src/world/layout.gd        Von Hand gesetzte Weltstruktur (Dorf, Wege, Zäune, Hecken)
src/world/map_data.gd      Kartendaten: Bodentypen, Inselform, Wegenetz, Begehbarkeit
src/world/ground_tileset.gd TileSet mit Terrains und Dekorationskacheln, bemalt die Schichten
src/world/world_builder.gd Boden backen, Requisiten verteilen, Kollision bauen
src/world/water_fx.gd      Glitzern und Uferschaum (nur im Sichtbereich)
src/world/world.gd         Setzt die Spielwelt zusammen

src/player/player.gd       Bewegung und Animation
src/camera/game_camera.gd  Weiches Folgen, Weltgrenzen

src/ui/ui_theme.gd         Gemeinsames Theme
src/ui/menu_art.gd         Titelbild des Hauptmenüs
src/ui/main_menu.gd        Startmenü
src/ui/pause_menu.gd       Pause-Menü
src/ui/options_menu.gd     Optionen
src/ui/hud.gd              Steuerungshinweis, Chunk- und Blockanzeige
src/ui/build_bar.gd        Bau-Leiste mit acht Bodentypen
src/ui/minimap.gd          Übersichtskarte oben rechts
src/world/build_tool.gd    Blöcke setzen, Speichern
src/world/chunk_streamer.gd  Lädt und entlädt Chunks um die Figur
src/gfx/edge_art.gd        Klippenwände, Schlagschatten, Uferkanten
src/ui/cloud_layer.gd      Ziehende Wolken im Hauptmenü

src/audio/audio.gd         Autoload: prozedurale Musik und Effekte
src/dev/self_test.gd       Automatischer Selbsttest
src/dev/asset_sheet.gd     Kontaktbogen aller Grafiken zur Sichtprüfung

prototype_godsim/          Früherer God-Sim-Prototyp, unverändert archiviert
```

## Selbsttest

Das Spiel prüft sich auf Wunsch selbst — Start, Karte, Bewegung, Kollision, Kamera,
Weltgrenzen, Audio und alle Menüwechsel:

```bash
godot --headless --path . --import      # nur beim allerersten Mal nötig
godot --headless --path . -- --selftest
```

Der Exit-Code ist 0, wenn alles in Ordnung ist (aktuell 78 Prüfungen; im Aufbaumodus
Weltaufbau ~550 ms bei 2048 × 2048 Blöcken, auf der Insel ~1,5 s mit 616 Objekten).
Ein Chunk ist in 1,5 ms gemalt, die Minimap in 1,1 ms, die Physik braucht 0,3 ms je
Bild und der Boden kommt mit 72 Zeichenaufrufen aus. Eine der Prüfungen durchsucht das
Projekt nach fremden Asset-Dateien und schlägt fehl, sobald eine auftaucht — siehe
[`CREDITS.md`](CREDITS.md). Mit einer echten Anzeige
lassen sich zusätzlich Screenshots und ein Kontaktbogen aller erzeugten Grafiken ablegen:

```bash
godot --path . -- --selftest --shots=/tmp/shots
```

![Alle Requisiten](docs/bilder/requisiten.png)

## Vorher / Nachher

Links das 16-px-Raster der ersten Fassung, rechts das heutige 32-px-Raster.

| vorher | nachher |
|---|---|
| ![Dorf vorher](docs/bilder/vorher_dorf.png) | ![Dorf nachher](docs/bilder/dorf.png) |
| ![Wald vorher](docs/bilder/vorher_wald.png) | ![Wald nachher](docs/bilder/wald.png) |
| ![Strand vorher](docs/bilder/vorher_strand.png) | ![Strand nachher](docs/bilder/strand.png) |

## Nächste Schritte

Die Architektur ist auf Erweiterung ausgelegt, aber bewusst noch schlank. Naheliegend wären
NPCs mit Dialogen, ein Speicherstand, Innenräume der Häuser, ein Tag-/Nacht-Zyklus und
mehr Gebiete. Erst danach lohnen sich größere Systeme.

---

*Der frühere God-Sim-Prototyp „Terraria Mundi" liegt unverändert in `prototype_godsim/`
und ist über die Git-Historie jederzeit wieder erreichbar.*
