# 🌾 Talhain

Ein kleines 2D-Top-Down-Abenteuer für Laptop und Desktop, gebaut mit **Godot 4.3**.
Du läufst als Wanderer durch eine überschaubare Insel: Dorf, Wiese, Wald, Felsen und eine Bucht mit Strand.

![Das Dorf](docs/bilder/dorf.png)

## Starten

1. [Godot 4.3+](https://godotengine.org/download) herunterladen (keine Installation nötig)
2. Godot öffnen → **Importieren** → diesen Ordner (`project.godot`) auswählen
3. **F5** drücken

## Steuerung

| Eingabe | Aktion |
|---|---|
| **W A S D** oder **Pfeiltasten** | Laufen |
| **Shift** | Rennen |
| **ESC** | Pause-Menü öffnen / schließen |
| **Maus** | Menüs bedienen |

## Was drin ist

**Welt** — Eine Insel aus 96 × 72 Kacheln mit klar erkennbaren Gebieten: ein Dorf mit
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
src/world/ground_tileset.gd TileSet mit benannten Terrains, bemalt die Kachelschichten
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
src/ui/hud.gd              Steuerungshinweis beim Start
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

Der Exit-Code ist 0, wenn alles in Ordnung ist (aktuell 35 Prüfungen; Weltaufbau ~790 ms,
616 Objekte, 572 Kollisionsformen, 38 Zeichenaufrufe). Mit einer echten Anzeige
lassen sich zusätzlich Screenshots und ein Kontaktbogen aller erzeugten Grafiken ablegen:

```bash
godot --path . -- --selftest --shots=/tmp/shots
```

![Alle Requisiten](docs/bilder/requisiten.png)

## Nächste Schritte

Die Architektur ist auf Erweiterung ausgelegt, aber bewusst noch schlank. Naheliegend wären
NPCs mit Dialogen, ein Speicherstand, Innenräume der Häuser, ein Tag-/Nacht-Zyklus und
mehr Gebiete. Erst danach lohnen sich größere Systeme.

---

*Der frühere God-Sim-Prototyp „Terraria Mundi" liegt unverändert in `prototype_godsim/`
und ist über die Git-Historie jederzeit wieder erreichbar.*
