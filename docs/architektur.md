# Architekturentscheidung

## Ausgangslage (Phase 0)

Im Projekt lag bereits ein Godot-4.3-Prototyp — allerdings ein **anderes Spiel**: eine
God-Sim („Terraria Mundi", 1760 Zeilen GDScript), in der man die Welt formt und Völker
beobachtet. Der Auftrag beschreibt dagegen ein Top-Down-Spiel mit einer steuerbaren Figur.

Vorgefunden:

- Engine: Godot 4.3, GL Compatibility, Nearest-Filter (Pixel-Look voreingestellt)
- Sprache: GDScript
- Assets: keine — alle Grafiken wurden zur Laufzeit erzeugt
- Abhängigkeiten: keine

## Entscheidungen

**Engine bleibt Godot 4.3.** Sie ist für ein 2D-Top-Down-Spiel gut geeignet, und ein
Wechsel wäre reine Verschwendung.

**Der alte Prototyp wird archiviert, nicht überschrieben.** Er liegt vollständig unter
`prototype_godsim/` mit einer `.gdignore`-Datei, damit die Engine ihn nicht mitlädt und
keine Klassennamen kollidieren. Die Git-Historie bleibt ohnehin erhalten.

**Grafik wird weiterhin prozedural erzeugt.** Statt zusammengesuchter Fremd-Assets erzeugt
`src/gfx/` alle Texturen aus einer einzigen Palette (`src/core/palette.gd`). Das garantiert
einen einheitlichen Stil, hält das Repository klein und macht jedes Detail nachvollziehbar
änderbar.

**Der Boden wird in eine einzige Textur gebacken.** 96 × 72 Kacheln als 6912 Sprites zu
zeichnen wäre Verschwendung; stattdessen entsteht beim Weltstart ein Bild von 1536 × 1152
Pixeln, das als ein Sprite gezeichnet wird. Kachelübergänge, Streudekoration und die
Schatten der Objekte werden gleich mit eingebacken. Aufbauzeit: rund 370 ms.

**Kollision aus zusammengefassten Rechtecken.** Die Wasserflächen werden per Greedy-
Rechteckzerlegung zu wenigen großen Formen verschmolzen, Objekte bekommen einen
Fußabdruck am Boden. So bleiben es einige hundert statt tausender Formen, und die
Kollision fühlt sich natürlich an, weil der Spieler an den Füßen kollidiert, nicht am Bild.

**Zustände liegen an einer Stelle.** `src/core/main.gd` kennt MENÜ, SPIEL, PAUSE und
OPTIONEN und schaltet Menüs, Pause und Weltsichtbarkeit gemeinsam um. Die Welt weiß
nichts von Menüs, die Menüs nichts von der Welt.

**Getestet wird automatisch.** `src/dev/self_test.gd` startet das Spiel, läuft mit
simulierten Tastendrücken herum, prüft Kollision, Kameragrenzen, Karte, Audio und alle
Menüwechsel und beendet sich mit einem Exit-Code. Damit gilt keine Änderung als fertig,
bevor sie einmal wirklich gelaufen ist.

## Bewusst nicht gebaut

NPCs, Dialoge, Quests, Inventar, Speichern/Laden, Tag-/Nacht-Zyklus, Gegner, Kämpfe,
Mehrspieler und Mobile-Steuerung. Erst wenn die Basis stabil steht, lohnen sich diese
Systeme — und dann jedes einzeln.

---

## Nachtrag: die grafische Überarbeitung

**Jede Requisite hat Varianten.** `PropArt.build()` liefert je Art eine Liste von Varianten
(`{tex, size, foot, shadow}`); der `WorldBuilder` würfelt beim Platzieren eine davon aus und
merkt sich den Index. Dadurch sieht kein Baum aus wie sein Nachbar, ohne dass mehr Texturen
im Speicher liegen als nötig — 26 Baum- und 17 Gebäudevarianten kosten zusammen wenige
hundert Kilobyte.

**Eine Lichtrichtung für alles.** `Pixel.shade_ramp()` ersetzt die sichtbaren Pixel einer Fläche
durch eine Farbrampe, abhängig vom Abstand zu einer Lichtquelle, und dithert zwischen den Stufen
mit einer 4×4-Bayer-Matrix. Kronen, Felsen, Dächer, Fässer und die Spielfigur benutzen dieselbe
Funktion und dieselbe Richtung (oben links). Das ist der Grund, warum die Objekte
zusammengehören, obwohl sie von verschiedenen Zeichenroutinen stammen.

Die Funktion nimmt ausdrücklich einen Bereich entgegen. Das war nicht immer so: In der ersten
Fassung färbte sie das ganze Bild ein und übermalte damit bei den Häusern Wände, Fenster und
Türen mit der Dachfarbe — die Gebäude waren einfarbige Kuppeln. Der Fehler fiel erst im
Screenshot auf, nicht im Test.

**Bewuchs nach Dichtefeldern.** Statt pro Kachel unabhängig zu würfeln, liest der `WorldBuilder`
drei Rauschfelder aus: Dichte (Baumgruppen), Lichtungen und Artenverteilung (Nadel- oder
Laubwald). So entstehen Bestände, Lichtungen und ausgedünnte Ränder statt eines gleichmäßigen
Teppichs.

**Wege als Kurven.** Die Wegpunkte in `Layout.ROADS` werden mit einer Catmull-Rom-Kurve
verbunden und mit schwankendem Radius gestempelt. Vorher waren es gerade Strecken zwischen den
Punkten, was man deutlich sah.

**Der Wasser-Effekt wurde teuer und ist es nicht mehr.** Der pixelweise Uferschaum lief über
jede sichtbare Wasserkachel und rechnete pro Pixel einen Sinus — rund 25 000 Durchläufe pro
Bild. Jetzt werden die Uferkanten einmal beim Weltaufbau in eine Bitmaske geschrieben, der
Schaum in Segmenten von vier Pixeln gezeichnet und das Ganze nur 24-mal pro Sekunde neu
gezeichnet: rund 260 Rechtecke pro Bild.

**Zur Messung:** Auf dem Software-Renderer der Testumgebung kostet allein das Hauptmenü über
50 ms `TIME_PROCESS`. Der Absolutwert sagt dort nichts über das Spiel aus, deshalb misst der
Selbsttest den *Aufschlag* der Spielwelt gegenüber dem Menü und die Zahl der gezeichneten
Wasser-Rechtecke. Auf echter Hardware sind beide Werte unkritisch.

---

## Nachtrag: vom gebackenen Bild zum echten Kachelraster

Der Boden war eine einzige gebackene Textur. Die Übergänge zwischen zwei Bodentypen entstanden
aus geditherten Streifen an den vier Kachelseiten — ohne Eckkacheln. Küstenlinien und Wegränder
liefen dadurch treppenförmig, und die Karte war weder inspizierbar noch von Hand nachzubearbeiten.

**Jetzt neun `TileMapLayer`.** Gras füllt die Karte, darüber liegen Wiese, Waldboden, Fels, Sand,
Wasser, Tiefwasser, Weg und Pflaster. Jede Schicht blendet sich per Eck-Autotiling in die
darunterliegende ein. Weil Gras die Grundfüllung ist, muss von jeder weiteren Schicht nur die
tatsächlich sichtbare Fläche gesetzt werden.

**Die Übergangskacheln entstehen rechnerisch.** Für jede der 15 Eckmasken wird die Deckung durch
bilineare Interpolation der vier Eckwerte bestimmt und mit einer geditherten Schwelle
freigestellt — daraus ergeben sich runde Aussen- und Innenecken von selbst. Gebaute Flächen (Weg,
Pflaster) verwenden stattdessen ganze Quadranten mit leicht aufgerauter Innenkante: ein
gepflasterter Platz hat gerade Kanten, eine Wiese nicht. Für freistehende Kacheln gibt es eine
eigene Form; ohne sie würde eine Kachel ohne gleichartige Nachbarn verschwinden.

**Zur Engine-Frage.** Godots Terrain-System im Modus `TERRAIN_MODE_MATCH_CORNERS` wurde zuerst
direkt verwendet. Ein Probelauf hat die Zuordnung Maske → Kachel Bit für Bit festgehalten: eine
Ecke gilt als bedeckt, wenn alle vier dort zusammenstoßenden Kacheln zur Schicht gehören.
`set_cells_terrain_connect()` über alle Zellen kostete allerdings **4119 ms**. Dieselbe Regel
selbst gerechnet liefert dieselbe Ausgabe in **127 ms**, weil die Kachelsuche entfällt. Das
`TileSet` deklariert die Terrains trotzdem vollständig mit Namen und Eck-Bits — die Karte lässt
sich also im Godot-Editor mit dem Terrain-Pinsel weiterbearbeiten.

**Wege sind achsparallel.** Zwischen zwei Wegpunkten wird erst entlang der längeren, dann entlang
der kürzeren Achse gebaut. Das ergibt gerade Strecken, rechte Winkel und echte T-Kreuzungen. Die
vorherigen Catmull-Rom-Kurven mäanderten und zerfielen beim Autotiling in Punkte: unterhalb von
zwei Kacheln Breite hat eine Fläche keine vollständig bedeckte Ecke mehr.

**Was beim Umbau kaputtging und wieder repariert wurde**
- Wege zerfielen zu einzelnen Punkten (zu schmal für Eck-Autotiling)
- Waldboden und Wiese verschwanden: die Regionen-Verwischung mit 42 % zerlegte sie in
  Einzelkacheln. Sie war ein Notbehelf gegen harte Kachelkanten und steht jetzt auf 16 %
- Die Helligkeitsstufen zeichneten die Höhenlinie des Rauschens als sichtbares Rechteck nach,
  bis die Stufenwahl pro Kachel verrauscht wurde
- Der Uferschaum zeichnete die Kachelkante nach, statt der neuen Wasserkante zu folgen

**Zur Leistungsmessung.** Die Prüfung „Weltdarstellung unter 12 ms" bewertete einen Wert, der auf
dem Software-Rasterizer der Testumgebung zwischen −10 ms und +20 ms schwankt — er misst dort die
Füllrate, nicht das Spiel. Geprüft werden jetzt Ladezeit, Physikzeit, Wasserlast und die Zahl der
Zeichenaufrufe (38, die Kachelschichten werden also gebündelt). Bricht das Batching, fällt es dort
sofort auf. Der Prozesszeit-Wert wird nur noch berichtet.

---

## Nachtrag: Verdopplung der Auflösung

Der Auftrag verlangte mindestens die doppelte Auflösung. Die Kachelgröße ging
von 16 auf 32 Pixel, der Kamerazoom von 3,0 auf 1,5 — das Sichtfeld bleibt
damit exakt gleich (rund 27 × 15 Kacheln), aber jede Kachel hat die vierfache
Pixelfläche.

**Neu gezeichnet, nicht hochskaliert.** Bloßes Verdoppeln hätte nur klotzigere
Pixel ergeben. Die parametrischen Grafiken (Bäume, Felsen, Büsche) rechnen
ohnehin in Fließkomma und werden auf der größeren Leinwand von selbst feiner.
Alles mit festen Pixelkoordinaten — Gebäude, Dorfinventar, Spielfigur,
Bodenkacheln, Dekoration — wurde von Hand neu aufgebaut, mit Details, die bei
16 Pixeln schlicht keinen Platz hatten: Sprossenfenster mit Fensterbank und
Laden, Türbeschläge, Jahresringe im Holzstapel, ein Gesicht mit Augen und
Wangen bei der Spielfigur.

**Bodenkacheln bekommen Textur auf zwei Ebenen.** Weiche Farbflecken geben der
Fläche die grobe Struktur, feines Korn darüber die Materialwirkung. Nur Korn
sieht aus wie Rauschen, nur Flecken wie Filz.

**Die Dekoration wanderte in eine eigene Rasterschicht.** Vorher lagen Blumen,
Grasbüschel und Schatten in einer gebackenen Auflagetextur über der Welt. Bei
32er-Kacheln wäre die 3072 × 2304 Pixel groß gewesen — 28 MB und 0,8 Sekunden
Backzeit. Jetzt gibt es fertig bestückte Dekorationskacheln in einer eigenen
`TileMapLayer` (zwölf Varianten je Sorte, die Objekte darin an zufälligen
Stellen), und die Bodenschatten sind skalierte Sprites.

**Was dabei kaputtging.** Das Kachelraster wurde sichtbar: auf Sand und Wasser
zeichnete sich ein Schachbrett ab. Die großflächigen Helligkeitsstufen hatten
8,5 % Abstand und zusätzlich einen Zufallswert je Kachel — bei 16 Pixeln fiel
das nicht auf, bei 32 Pixeln ist jede Kachel eine große einfarbige Fläche.
Jetzt 3,5 % Abstand ohne Per-Kachel-Zufall, dafür sechs statt vier Varianten je
Stufe. Außerdem schlugen die Bewegungsprüfungen des Selbsttests fehl, weil sie
absolute Pixelwerte verglichen; sie hängen jetzt an `Config.TILE`.

**Leistung.** Der Weltaufbau stieg zunächst von 0,8 auf 2,4 Sekunden. Die
Dekorationsschicht sparte 0,8 s, und `Pixel.outline` und `shade_ramp` lesen den
Alphakanal jetzt als Rohpuffer statt über `get_pixel` je Pixel — zusammen
1,5 Sekunden. Bei vierfacher Pixelzahl je Grafik ist das vertretbar.

## Nachtrag: Chunks, Sprung und Bau-Leiste

**Die Figur schaute falsch herum.** `player.gd` spiegelte beim Laufen nach
rechts. Die Seitenansicht in `actor_art.gd` ist aber bereits nach rechts
gezeichnet — Auge auf x17–19, Nase auf x23, Hinterkopfhaar auf x6–11.
Gespiegelt wird jetzt beim Laufen nach links. Der Selbsttest prüft beide
Richtungen, damit der Dreher nicht zurückkommt.

**Der Klick auf „Spielen" fror das Fenster ein.** Zwei Ursachen, beide
gemessen: `WorldBuilder.build()` erzeugte immer rund 90 Requisitengrafiken
(464–519 ms), die im Aufbaumodus nie platziert werden — das entfällt dort
jetzt. Und `Main.start_game()` baute alles in einem einzigen Bild. Jetzt wird
erst „Lädt …" eingeblendet und zwei Bilder gewartet, damit der Hinweis
tatsächlich gezeichnet wird. Aus 800 ms Einfrieren wurden 340 ms sichtbarer
Ladevorgang. Die Shader-Übersetzung beim allerersten Start bleibt.

**Ein Chunk ist 16 × 16 Blöcke.** `MAP_H` ging von 72 auf 80, damit die Karte
mit 96 × 80 Blöcken in genau 6 × 5 = 30 vollständige Chunks aufgeht. Die
frühere Staffelung (jede fünfte Linie kräftiger) entfiel dafür — Chunk-Grenzen
sind die bessere Orientierung. Die Nummer steht in der oberen linken Ecke des
Chunks, nicht in seiner Mitte: ein Chunk ist 512 px hoch, der Bildausschnitt
bei Zoom 1,5 aber nur rund 480 — die Mitte wäre meistens ausserhalb.

**Der Sprung ist reine Darstellung.** Von oben gesehen gibt es keine Höhe, die
kollidieren könnte. Die Figur folgt einer Wurfparabel (0,45 s, 14 px), ihr
Schatten bleibt am Boden und wird kleiner und blasser. Position und Kollision
bleiben unverändert — über Wände oder Wasser kommt man nicht. Später kann
daraus ein echtes Überspringen von Lücken werden.

**Blöcke setzen: neun Schichten, neun Zellen.** Weil der Boden aus neun
`TileMapLayer` mit Eck-Autotiling besteht, ändert eine einzige geänderte Kachel
die Eckmasken im 3 × 3-Umfeld auf jeder Schicht — mehr aber auch nicht, weil
eine Ecke nur von den vier an ihr zusammenstoßenden Kacheln abhängt.
`GroundTileSet.update_cell()` schreibt deshalb die beim Aufbau angelegten
Zugehörigkeitsraster fort und rechnet 9 × 9 Zellen neu, statt die Karte
durchzugehen. Die Eckregel `_corner_mask()` ist dieselbe wie beim Weltaufbau,
und die Frage, welcher Bodentyp zu welcher Schicht gehört, steht jetzt nur noch
an einer Stelle (`GroundTileSet.in_layer()`) statt zweimal.

**Kollision beim Bauen.** Das zusammengefasste Rechteck-Verfahren lohnt sich
nur beim Aufbau. Ein einzeln gesetzter Wasserblock bekommt stattdessen eine
eigene `CollisionShape2D`, verwaltet über ein Dictionary `Vector2i -> Shape`;
beim Entfernen verschwindet sie wieder. Der Kartenrand bleibt in jedem Fall
gesperrt. Die Brandung rechnet ihre Ufermaske für die betroffene Kachel und
ihre vier Nachbarn neu, statt die ganze Karte abzusuchen.

**Speichern.** `user://karte.dat` enthält Kennung, Fassung, Kartenmaße und die
Bodentypen als `PackedByteArray`. Die Begehbarkeit wird daraus abgeleitet statt
mitgespeichert. Passen Fassung oder Maße nicht, wird die Datei übergangen statt
zu stürzen. Der Selbsttest legt eine vorhandene Karte vorher beiseite und
schreibt sie danach zurück — ein Testlauf darf niemandem seine Arbeit löschen.

## Lizenzlage

Das Projekt enthält keine fremden Asset-Dateien. Eine Prüfung im Selbsttest
durchsucht `res://` nach Bild-, Ton- und Schriftdateien und schlägt fehl,
sobald eine auftaucht. Details in `CREDITS.md`.
