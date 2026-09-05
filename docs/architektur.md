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
