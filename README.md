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

**Welt** — Eine Insel aus 96 × 72 Kacheln mit klar erkennbaren Gebieten: gepflasterter Dorfplatz
mit Brunnen und fünf Häusern, dichter Nadel- und Laubwald im Nordwesten, blühende Wiese im
Nordosten, Felsland im Osten und eine Bucht mit Sandstrand im Südwesten. Trampelpfade verbinden
alles miteinander.

**Grafik** — Alle Texturen entstehen zur Laufzeit aus **einer** Farbpalette: Bodenkacheln in vier
Varianten, weiche Übergänge zwischen den Bodentypen, gestreute Blumen, Pilze, Steine und Zweige,
Bäume, Felsen, Häuser, Zäune, Fässer, Brunnen, Schilf — dazu eingebackene Schatten. Das Wasser
glitzert und der Uferschaum bewegt sich.

**Spieler** — Eigene Figur mit Idle- und Laufanimation in drei Blickrichtungen (die vierte wird
gespiegelt), Beschleunigung und Reibung, Schrittgeräusche.

**Kamera** — Folgt weich, bleibt innerhalb der Weltgrenzen.

**Kollision** — Bäume, Felsen, Häuser, Zäune und Wasser blockieren; Wege, Wiesen und Strand sind
begehbar. Die Kollisionsflächen des Wassers werden zu wenigen großen Rechtecken zusammengefasst.

**UI** — Hauptmenü, Pause-Menü und Optionen (Musik, Effekte, Vollbild, Hinweise) in einem
gemeinsamen Theme; Einstellungen werden gespeichert.

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

src/gfx/pixel.gd           Zeichen-Werkzeuge auf Images (Rechteck, Ellipse, Outline, Dither)
src/gfx/tile_art.gd        Bodenkacheln, Übergangskanten, Streudekoration
src/gfx/prop_art.gd        Bäume, Felsen, Häuser, Zäune, Kleinkram
src/gfx/actor_art.gd       Spielerfigur (Idle + Laufzyklus, 3 Richtungen)

src/world/layout.gd        Von Hand gesetzte Weltstruktur (Dorf, Wege, Zäune)
src/world/map_data.gd      Kartendaten: Bodentypen, Inselform, Begehbarkeit
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

src/audio/audio.gd         Autoload: prozedurale Musik und Effekte
src/dev/self_test.gd       Automatischer Selbsttest

prototype_godsim/          Früherer God-Sim-Prototyp, unverändert archiviert
```

## Selbsttest

Das Spiel prüft sich auf Wunsch selbst — Start, Karte, Bewegung, Kollision, Kamera,
Weltgrenzen, Audio und alle Menüwechsel:

```bash
godot --headless --path . --import      # nur beim allerersten Mal nötig
godot --headless --path . -- --selftest
```

Der Exit-Code ist 0, wenn alles in Ordnung ist. Mit einer echten Anzeige lassen sich zusätzlich
Screenshots ablegen:

```bash
godot --path . -- --selftest --shots=/tmp/shots
```

## Nächste Schritte

Die Architektur ist auf Erweiterung ausgelegt, aber bewusst noch schlank. Naheliegend wären
NPCs mit Dialogen, ein Speicherstand, Innenräume der Häuser, ein Tag-/Nacht-Zyklus und
mehr Gebiete. Erst danach lohnen sich größere Systeme.

---

*Der frühere God-Sim-Prototyp „Terraria Mundi" liegt unverändert in `prototype_godsim/`
und ist über die Git-Historie jederzeit wieder erreichbar.*
