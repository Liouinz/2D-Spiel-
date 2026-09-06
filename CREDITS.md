# Credits und Nutzungsrechte

**Kurzfassung: Dieses Projekt enthält keine fremden Asset-Dateien.**
Sämtliche Grafiken und die Musik werden zur Laufzeit im Spiel selbst berechnet.
Es gibt im Repository keine `.png`, `.wav`, `.ogg` oder `.ttf` als Spielinhalt.

## Grafik

| Was | Herkunft | Autor | Lizenz |
|---|---|---|---|
| Bodenkacheln (Gras, Sand, Wasser) und Übergangskacheln | in diesem Projekt erzeugt (`src/gfx/tile_art.gd`, `src/gfx/terrain_atlas.gd`) | Projekt | frei verwendbar |
| Uferband und Tiefenband | in diesem Projekt erzeugt (`src/gfx/edge_art.gd`) | Projekt | frei verwendbar |
| Spielerfigur und Animationen | in diesem Projekt erzeugt (`src/gfx/actor_art.gd`) | Projekt | frei verwendbar |
| Menü-Hintergrund, Rahmen, Wolken | in diesem Projekt erzeugt (`src/ui/menu_art.gd`) | Projekt | frei verwendbar |

Jede dieser Grafiken entsteht aus Rechteck-, Ellipsen- und Dreiecksoperationen in
`src/gfx/pixel.gd` und aus der Farbpalette in `src/core/palette.gd`. Es wurde
nichts kopiert, nachgezeichnet oder aus fremden Bilddateien abgeleitet.

## Audio

| Was | Herkunft | Autor | Lizenz |
|---|---|---|---|
| Menü- und Weltmusik | in diesem Projekt berechnet (`src/audio/audio.gd`) | Projekt | frei verwendbar |

Die Musik wird als Sinussignal in eine `AudioStreamWAV` geschrieben. Es wurden
keine Aufnahmen und keine Samples verwendet. Klangeffekte gibt es keine mehr —
sie wurden bewusst entfernt, die Musik ist geblieben.

## Fremde Bestandteile

| Was | Autor | Lizenz | Anmerkung |
|---|---|---|---|
| Godot Engine 4.3 | Godot Engine contributors | MIT | Laufzeitumgebung, nicht Teil dieses Repositories |
| Standardschriftart der Oberfläche | Teil der Godot-Distribution | siehe Godot-Lizenzdatei | wird von der Engine gestellt, nicht von diesem Projekt mitgeliefert |

Das Projekt liefert keine eigene Schriftdatei aus. Die Menütexte werden mit der
Schrift gezeichnet, die Godot selbst mitbringt.

## Vorbilder

Als gestalterische Orientierung dienten Top-Down-Spiele wie Stardew Valley,
Moonlighter, Kynseed und A Short Hike. **Aus keinem dieser Spiele wurden
Grafiken, Farbwerte, Sprites oder sonstige Inhalte übernommen.** Die
Orientierung betrifft ausschließlich allgemeine Gestaltungsprinzipien —
Perspektive, Detailgrad, Lichtführung — die selbst nicht schutzfähig sind.

## Prüfung

Der Selbsttest meldet die Zahl der Asset-Dateien im Projekt. Wer es von Hand
prüfen möchte:

```bash
find . -path ./.godot -prune -o \( -name '*.png' -o -name '*.wav' -o -name '*.ogg' \
  -o -name '*.ttf' -o -name '*.jpg' \) -print
```

Treffer gibt es nur unter `docs/bilder/` — das sind Bildschirmfotos des Spiels
für die Dokumentation, keine Spielinhalte.
