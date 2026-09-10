# Performance — gemessen, nicht geraten

Dieses Dokument hält fest, **wie** gemessen wurde, **was** der Engpass war und
**was** die Änderungen gebracht haben. Es ist bewusst reproduzierbar
geschrieben: Wer die Zahlen anzweifelt, soll sie nachmessen können.

## Messaufbau

| | |
|---|---|
| Engine | Godot 4.3 stable, Renderer `gl_compatibility` |
| Auflösung | 1280 × 720, Render Scale 100 % |
| Grafikprofil | MITTEL, dynamische Qualität **aus** (sonst regelt sie gegen) |
| GPU | llvmpipe (Software-Rasterizer, Mesa 25.2) |
| Welt | 6 Völker, 4000 Ticks vorgelaufen, ~135–150 Siedler, ~71–79 Hütten |
| Verfahren | Wall-Clock-Frametime, 45 Bilder Aufwärmen, dann 320 Bilder gemittelt |

> **Zur GPU:** llvmpipe rastert auf der CPU. Das *überzeichnet* alles, was
> Füllrate kostet — genau deshalb ist es hier nützlich: Ein Renderfehler wie
> Mehrfach-Overdraw wird sofort sichtbar, statt in der Messtoleranz einer
> schnellen GPU zu verschwinden. Absolute FPS sind dadurch **nicht** auf echte
> Hardware übertragbar; die *Verhältnisse* sind es.

## Der Engpass

Erste Frage: Warum kostet die Nacht so viel? Statt zu raten wurden einzelne
Systeme abgeschaltet und einzeln gemessen.

| Szenario (vorher) | Frametime | FPS |
|---|---|---|
| Tag, alles an | 21,94 ms | 45,6 |
| **Nacht, alles an** | **34,10 ms** | **29,3** |
| **Nacht, Lichter aus** | **21,93 ms** | **45,6** |
| Nacht ohne WorldRender | 28,06 ms | 35,6 |
| Nacht nur Terrain | 12,67 ms | 79,0 |

Die dritte Zeile ist der ganze Befund: **Ohne die 2D-Lichter ist die Nacht
exakt so teuer wie der Tag.** Der komplette Tag/Nacht-Unterschied von
+12,16 ms steckte in den `PointLight2D`-Knoten — nicht in der Tönung, nicht
im Wetter, nicht in den Partikeln.

**Ursache:** Die GL-Compatibility-Pipeline beleuchtet 2D in *Mehrfachdurchgängen*.
Jedes Canvas-Element wird einmal pro überlappender Lichtquelle erneut
gezeichnet. Bei bis zu 48 Lichtern, die sich über einem Dorf stapeln, wurde
derselbe Tilemap-Block dutzendfach neu gerastert — dazu Siedler, Hütten und
Effekt-Ebenen. Die Kosten wuchsen mit *Lichtern × überdeckte Fläche*.

## Die Lösung: eine Lightmap statt vieler Lichter

`scripts/render/lighting.gd` ersetzt alle `PointLight2D` durch **eine einzige
multiplizierende Textur** über der Welt:

* Die Lightmap deckt nur den **sichtbaren Ausschnitt plus Rand** ab.
* Sie wird **nicht pro Bild** neu gerechnet, sondern mit 10–24 Hz je nach
  Grafikprofil — und zusätzlich dann, wenn die Kamera aus dem berechneten
  Fenster gelaufen ist oder ein Blitz zuckt.
* Lichtquellen werden **gecullt** (nur was ins Fenster ragt) und **gedeckelt**
  (Budget aus dem Grafikprofil, nächst der Bildmitte gewinnt).
* Der Umgebungs-Untergrund wird **einmal pro Farbwert** gebaut und danach nur
  noch kopiert.
* Gezeichnet wird das Ergebnis in **einem** Zeichenaufruf — unabhängig davon,
  ob 3 oder 300 Lichter im Bild sind.

Bei Tag ohne Blitz schaltet sich der Knoten komplett ab und kostet nichts.

## Ergebnis

| Szenario | vorher | nachher | |
|---|---|---|---|
| Tag, alles an | 21,94 ms · 45,6 fps | **18,62 ms · 53,7 fps** | −15 % Frametime |
| Nacht, alles an | 34,10 ms · 29,3 fps | **21,76 ms · 46,0 fps** | −36 % Frametime |
| **Aufschlag der Nacht** | **+12,16 ms (+55 %)** | **+3,14 ms (+17 %)** | **−74 %** |
| Zeichenaufrufe | 338 | 282 | trotz 4 statt 1 Tile-Ebene |
| Lichtquellen im Bild | 48 (Deckel) | 123 gefunden, 48 aktiv | mehr Licht, weniger Kosten |

Die Lightmap-Neuberechnung selbst kostet **2,11 ms — 12 × pro Sekunde**, also
rund 0,4 ms pro Bild bei 60 fps. Der verbleibende Nachtaufschlag ist auf
llvmpipe fast vollständig das *Vollbild-Multiplizieren* der Lightmap; auf einer
echten GPU ist genau dieser Anteil praktisch kostenlos.

> Ehrlichkeitshinweis: Der Nachher-Lauf hatte 135 Siedler / 71 Hütten, der
> Vorher-Lauf 150 / 79 (die Simulation ist zufallsbehaftet). Das erklärt einen
> kleinen Teil des Tag-Gewinns — **nicht** aber den Nachtaufschlag, denn der
> ist eine Differenz *innerhalb desselben Laufs*.

## Was sonst noch schneller wurde

| Änderung | Wirkung |
|---|---|
| Culling in `WorldRender`, `FxGlow`, `FxOverlay` | Es wird nur noch berührt, was im Bild liegt. Funken entstanden vorher über die ganze 192×112-Karte, also grösstenteils unsichtbar. |
| Zeichnen nach Primitivtyp gruppiert | Eine Hütte kostete drei Zeichenaufrufe (Rechteck → Polygon → Linie riss die Serie). Jetzt kosten *alle* Hütten zusammen drei. 516 → 282 Aufrufe. |
| Minimap über Bytepuffer statt `set_pixel` | 21 504 Einzelaufrufe pro Aktualisierung entfallen; das Gelände wird nur neu gezeichnet, wenn `Terrain.version` sich geändert hat. |
| Regen als echte Tropfen | Vorher 40 pro Bild neu gewürfelte Linien (flimmerte *und* kostete). Jetzt Partikel mit eigener Geschwindigkeit, Anzahl aus dem Profil, ausserhalb des Bildes gar keine. |
| Pinselstriche gebündelt | `begin_batch()` / `flush()`: Die Tile-Grafik wird nach einem Strich *einmal* nachgezogen statt pro Zelle. 40 Striche (r = 4) = 16 ms. |
| Atlas ohne Texture-Padding | `use_texture_padding = false` — jedes `create_tile()` baute sonst die Padding-Textur komplett neu auf. Atlasaufbau: > 120 s → 0,2 s. |
| Hover-Suche gedrosselt | Die Suche über alle Siedler läuft 10 ×/s statt 60 ×/s. |

## Selbst nachmessen

Das Entwickler-Overlay (Standard **F3**) zeigt dieselben Werte live, inklusive
`Neuberechnung` der Lightmap in ms und Hz. Es zeigt **nur gemessene Grössen** —
was die GL-Compatibility-Pipeline nicht liefert (echte GPU-Zeit pro Bild),
steht dort als `n/v` und wird nicht geschätzt.
