# Architekturentscheidung

> **Hinweis zum Lesen.** Dieses Dokument ist ein Entscheidungstagebuch: die
> Abschnitte stehen in der Reihenfolge, in der sie entstanden sind, und
> beschreiben jeweils den Stand ihrer Runde. Der **letzte** Nachtrag
> („Rückbau auf drei Materialien“) gilt. Alles, was davor über Wiese,
> Waldboden, Weg, Pflaster, Fels, Tiefwasser, Requisiten, Dorf, Insel,
> Höhenstufen, Klippen oder Klangeffekte steht, ist Geschichte — diese Teile
> sind seither vollständig entfernt.

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

## Nachtrag: grosse Welt, Klippen, Ufer, Schwimmen

**Die Bauvorschau hing am Raster.** `GridOverlay` setzte beim Umschalten
`visible = false`; damit lief `_draw()` gar nicht mehr und der Zeigerkasten
verschwand mit. Jetzt schaltet **G** ein eigenes Feld `show_grid`, das nur die
Linien betrifft. Die Vorschau zeichnet zusätzlich die gewählte Bodenkachel
halbdurchsichtig in den Block.

**128 × 128 Chunks = 4,2 Millionen Kacheln.** Godot hat für TileMaps kein
eingebautes Chunk-Laden (Issue #72458, „not planned"), also `ChunkStreamer`:
5 × 5 Chunks um die Figur, höchstens zwei Ladevorgänge je Bild, Kacheln und
Kollisionsformen werden beim Entladen freigegeben. Die Karte selbst bleibt
vollständig im Speicher (4,2 MB) — sonst stimmten die Eckmasken an den Grenzen
zu ungeladenen Chunks nicht.

**Sechs ganzseitige Datenfelder mussten weg**, zusammen rund 66 MB: die
Begehbarkeit (wird gerechnet), die Helligkeitsvarianten, die Dekorationskarte,
die Ufermaske und neun Zugehörigkeitsraster (ersetzt durch eine
Nachschlagtabelle von 2304 Bytes). Die Dekoration entscheidet jetzt ein
Streuwert aus den Koordinaten statt ein fortlaufender Zufallsgenerator — sonst
sähe dieselbe Kachel je nach Ladereihenfolge anders aus.

**Der Kachelaufbau ging von 5,9 auf 2,2 ms je Chunk.** Drei Sachen: die 3 × 3-
Nachbarschaft wird direkt im Puffer gelesen statt über neun Funktionsaufrufe,
ein frisch geladener Chunk braucht kein Löschen, und Kacheln ohne abweichende
Nachbarn überspringen die Eckrechnung ganz. Damit die direkte Pufferlesung auch
bei einer beschädigten Speicherdatei sicher bleibt, ist die Nachschlagtabelle
über den ganzen Bytebereich aufgespannt statt nur über die bekannten Bodentypen.

**Klippen und Ufer.** Recherchiert bei Slynyrd („Top Down Tiles"): Höhe entsteht
durch eine Wandfläche nach unten plus einen Schlagschatten, der *immer gleich
lang* ist, egal wie hoch die Wand ist. `EdgeArt` baut drei Kachelsätze über eine
4-Bit-Nachbarmaske, dazu zwei Schichten (Kanten, Schatten). Die Wand läuft über
die Blockkante: 16 px auf der Felskachel, 7 px auf der Kachel darunter, danach
10 px Schatten. Drei Ausführungen je Maske, nach Position gestreut — mit einer
wiederholte sich dieselbe Wand an jeder Kachel.

**Fels und flaches Wasser verlaufen nicht mehr.** Das Eck-Autotiling legt die
Geländegrenze auf das Eckraster, eine halbe Kachel versetzt zum Blockraster.
Für Wiese, Waldboden und Sand ist das richtig. Für Klippe und Uferlinie nicht:
Wand, Uferband und Brandung sassen am Block, der weiche Auslauf aber darüber
hinaus — die Brandung landete auf dem Sand statt im Wasser. Diese beiden
Bodentypen belegen jetzt genau ihre Blöcke, den Übergang machen die
Kantenkacheln. Tiefwasser bleibt weich, dort geht es um Tiefe statt um eine
Kante.

**Schwimmen.** Flaches Wasser hält nicht mehr auf, Tiefwasser schon — die
Trennung gab es im Bodentyp bereits. Das Schwimmbild ist das Laufbild, an der
Wasserlinie abgeschnitten, mit einem Wellenkragen darunter; `player.gd`
verschiebt das Bild um denselben Betrag nach unten, damit der Kopf an seiner
Stelle bleibt. Dadurch bleibt die Figur in jeder Blickrichtung dieselbe Person,
ohne acht neue Bilder von Hand.

**Speichern in Fassung 2.** 4,2 MB roh, mit Zstd auf wenige Kilobyte. Eine Karte
anderer Grösse wird mittig in die neue übernommen statt verworfen — eine
gewachsene Welt darf niemandem seine Arbeit kosten.

## Nachtrag: gesetzte Blöcke verbinden sich

**Der Fehler.** Eine Reihe gesetzter Blöcke zerfiel in einzelne Klekse. Ursache:
Godots Eck-Autotiling entscheidet über die vier Ecken einer Kachel, und eine
Ecke gilt dort als bedeckt, wenn ALLE VIER an ihr zusammenstossenden Felder
dazugehören. Bei einer ein Feld breiten Reihe ist das nirgends der Fall — jede
Kachel bekam Maske 0, und Maske 0 ist in `terrain_atlas.gd` absichtlich ein
runder Fleck in der Kachelmitte (`_blob`).

Das Verfahren ist richtig zum Malen von Flächen und falsch zum Setzen von
Blöcken. Die Regel ist deshalb umgedreht: **ein Feld, das zur Schicht gehört,
bekommt immer eine Vollkachel**, und der Übergang wächst aus ihm HERAUS in die
Nachbarfelder — dort wird eine Ecke gesetzt, wenn EINES der drei an ihr
liegenden Felder dazugehört. Die vorhandenen Übergangskacheln werden unverändert
weiterbenutzt, nur anders angesprochen; der Klecks-Fall wird nie mehr
gezeichnet. Sichtbare Folge: eine Fläche wächst optisch um eine halbe Kachel
nach aussen. Das ist der Preis und er ist es wert.

**Fels ist eine Höhenstufe.** `MapData.level_at()` liefert 1 auf Fels, sonst 0.
Bewusst KEINE Kollisionskörper: eine Stufe ist keine Wand, man muss ja
hinaufkommen. Stattdessen prüft `player.gd` vor der Bewegung, ob das Zielfeld
höher liegt, und lässt nur durch, wenn die Figur im Sprung über der
Kletterhöhe ist. Herunter geht immer, mit einem kurzen sichtbaren Fallen.

**Fels sah blass und flach aus.** Weiche Ellipsen plus Körnung ergaben fleckiges
Grau. Jetzt Platten mit heller Kante oben links und dunkler unten rechts, dazu
eine Fuge dazwischen. Zwei Zwischenschritte waren nötig: mit neun kleinen
Platten je Kachel sah es aus wie Mosaik, und mit einer sehr dunklen Fuge wie
Pflaster in Teer. Vier grössere Platten und eine nur leicht abgedunkelte Fuge
lesen sich als gewachsener Fels.

**Inventar.** `BuildBar.TYPES` war eine Konstante und ist jetzt ein änderbares
Feld; `equip()` tauscht Typ, Vorschaubild und Beschriftung eines Feldes. Die
Belegung liegt bei den Einstellungen in `user://`. Das Inventar pausiert den
Baum wie das Pausenmenü — anders lässt sich nicht in Ruhe klicken.

**Getrennte Schalter.** Vorher hing alles an G. Jetzt G für die Rasterlinien,
M für die Minimap, H für die Anzeige oben links.

**Sprung ins Wasser.** `_update_swimming()` brach den Sprung ab, sobald die
Figur über Wasser war — sie klappte mitten in der Luft ins Schwimmbild um. Jetzt
wird der Sprung zu Ende geflogen; beim Aufkommen kommt der Klang und ein
Wellenring, den `water_fx.gd` als Kranz kurzer Striche zeichnet.

## Nachtrag: Eingabetrennung, Kollision, Klippenkante

Sieben Fehler, alle mit einer gemeinsamen Eigenschaft: sie waren nicht dort, wo
man sie sah.

**Die Welt lief bei pausiertem Baum weiter.** `Main` setzt für sich
`PROCESS_MODE_ALWAYS`, damit Menüs bedienbar bleiben. Die Welt hängt als Kind
darunter, hatte `PROCESS_MODE_INHERIT` und erbte das still mit —
`get_tree().paused` hatte auf sie überhaupt keine Wirkung. Bei offenem Menü oder
Inventar lief also alles weiter. Die Welt ist jetzt ausdrücklich
`PROCESS_MODE_PAUSABLE`, das Inventar ausdrücklich `ALWAYS`.

**Das Bauwerkzeug fragte den rohen Maustastenzustand ab.**
`Input.is_mouse_button_pressed()` lief an der Ereigniskette vorbei: kein
`set_input_as_handled()` konnte es abfangen, keine Oberfläche es abschirmen. Ein
Klick auf „Fortsetzen" setzte deshalb gleichzeitig einen Block. Gesetzt wird
jetzt auf das Press-Ereignis; gemalt nur, solange ein Druck gehalten wird, der
in der Welt begonnen hat. Nebeneffekt: sehr kurze Klicks, die innerhalb eines
Bildes begannen und endeten, gingen vorher verloren und kommen jetzt an.

**Die Figur wurde beim Verlassen einer Felsstufe hochgeschleudert.** `lift()`
schlug dem Bildversatz schlagartig die volle Wandhöhe auf und blendete sie dann
weg — die Figur schoss erst 16 Pixel nach OBEN und sank dann. Doppelt falsch:
sie soll herunter, und die Höhe steckt ohnehin in der Kachelgrafik. Der Versatz
ist ersatzlos weg; `lift()` ist jetzt ausschliesslich der Sprung.

**Die Kantenprüfung sah nur einen Punkt.** Geprüft wurde der Fusspunkt der
Figur, nicht ihr Fussabdruck — sie schob sich bis zur halben Breite in den Fels,
bevor sie anhielt. Jetzt werden die vier Ecken eines 24 × 24-Fussabdrucks
geprüft, und das Anhalten ist aus allen vier Richtungen gleich.

**Die Klippenwand ragte in das Nachbarfeld.** Sie belegte 16 Pixel der
Felskachel und 7 Pixel der Kachel darunter. Damit stand sie in fremden Feldern —
bei Fels über Wasser mitten im Wasser — und die sichtbare Kante lag 7 Pixel
tiefer als die Stelle, an der die Figur anhält. Von Süden sah es aus, als bliebe
man in der Wand stecken, von Norden richtig. Genau das war die
richtungsabhängige Merkwürdigkeit. Jetzt bleibt die Wand vollständig auf ihrer
Kachel: **sichtbare Kante = Blockkante = Kollisionskante**. Auf das Feld darunter
kommt nur der Schlagschatten, und ein Schatten behauptet keine feste Fläche.

**Ein fester Block liess sich in die eigene Figur setzen.** Die neue
Kollisionsform lag mitten im Körper, und `move_and_slide()` drückte ihn im
nächsten Bild mit voller Kraft heraus — in eine vom Zufall der Überlappung
abhängige Richtung. Wird jetzt abgelehnt, geprüft über denselben Fussabdruck.

**Schnelles Ziehen liess Lücken.** Zwischen zwei Bildern liegen bei schneller
Maus mehrere Felder; gesetzt wurde nur das aktuelle. Jetzt wird die Linie
aufgefüllt — gedeckelt auf zwölf Felder, damit ein springender Zeiger keine
lange Spur zieht.

**Die Bauvorschau blieb im Menü stehen.** Folgefehler der ersten Behebung: das
Bauwerkzeug läuft bei pausiertem Baum zu Recht nicht mehr und kam nicht mehr
dazu, den Zeigerkasten zu löschen. Das macht jetzt der Zustandswechsel selbst.

## Nachtrag: Eingaben zentral, Steuerungsanzeige, Leistungsanzeige

**Alle Tasten liegen jetzt in der InputMap.** Im Bauwerkzeug standen zuletzt
noch `KEY_1` bis `KEY_8` und `KEY_F5` fest im Code, die Maustasten ebenso.
Beides sind jetzt Aktionen (`build_slot_1` … `build_slot_8`, `save_map`,
`build_place`, `build_remove`), angelegt an einer Stelle in
`Config.setup_input()`. Die Belegung hat sich nicht geändert, nur ihr Ort.

**Die Steuerungsübersicht kann nicht veralten.** `Config.CONTROL_ROWS` enthält
ausschliesslich Beschriftungen; welche Taste dazugehört, holt
`Config.keys_for()` zur Laufzeit aus der InputMap
(`InputMap.action_get_events()` → `OS.get_keycode_string()`). Ändert jemand
eine Belegung, ändert sich die Anzeige mit. Ein Selbsttest prüft ausserdem,
dass jede aufgeführte Aktion existiert und eine Taste hat.

**Leistungsanzeige: nur gemessene Werte.** Godot liefert keine
Systemauslastung, sondern Renderzeiten — deshalb steht dort „CPU Render" und
„GPU Render" in Millisekunden und keine erfundene Prozentzahl. Gemessen wird
über `RenderingServer.viewport_set_measure_render_time()` und die beiden
zugehörigen Abfragen; dass es diese Methoden gibt, wurde aus der laufenden
Engine geprüft, nicht angenommen. Liefert ein Treiber keinen Wert — im
Testcontainer ist das bei beiden Renderzeiten so — steht „—" statt einer
glatten Null, die wie ein Messwert aussähe. Die Anzeige ist bewusst **nicht
gespeichert**: sie ist bei jedem Start aus.

**Entwicklerinfo auf F3** ist etwas anderes und liegt getrennt davon: Chunk,
Feld, Bodentyp, Höhenstufe, begehbar, Kollisionsformen, Zustand der Figur.

**Zur Y-Sortierung, ehrlich:** Requisiten und Figur liegen seit Langem in einem
sortierten Knoten, Häuser und Bäume verdecken die Figur also korrekt. Für die
Klippe habe ich beide Fälle im Bild geprüft — Figur oberhalb und unterhalb der
Wand — und beide werden richtig gezeichnet. Die Wand ist 16 Pixel hoch und
sitzt am unteren Rand ihrer eigenen Kachel; eine Lage, in der sie die Figur
verdecken müsste, gibt es dadurch nicht. Ich habe deshalb keine zusätzliche
Sortierung eingebaut, die nichts zu tun hätte.

## Nachtrag: Rückbau auf drei Materialien

Der Auftrag war diesmal Abriss, nicht Ausbau: *„Reduziere das Spiel auf genau
drei Materialien: Gras, Sand, Wasser."* Dazu Inventar als sauber getrennter
UI-Zustand, E als echter Umschalter, Kachelsatz und Texturen technisch prüfen,
Wasser und Kollision reparieren, Klangeffekte raus und Musik behalten.

**Warum das die richtige Richtung war.** Neun Bodentypen brachten neun mal so
viele Kombinationen an Übergängen, drei Sonderregeln im Gelände (Höhenstufe,
Klippenwand, Tiefwasser als Wand) und eine Handvoll Fehler, die alle an den
Rändern zwischen diesen Regeln sassen: das Hochschleudern am Fels, die
unsichtbare Kollision entfernter Felskacheln, das richtungsabhängige Anhalten
an der Kante. Keiner davon war ein Bug in einer Zeile — sie waren die
Wechselwirkung von Regeln, die es nun nicht mehr gibt.

**Was ersatzlos entfernt wurde.** Die Bodentypen Wiese, Waldboden, Weg,
Pflaster, Fels, Tiefwasser. Damit auch: das Höhenstufen-System
(`MapData.level_at`, `Player._level`, `_block_ledges`, `_foot_blocked`,
`_update_level`), die Klippengrafik in `EdgeArt`, die Schattenschicht, die
Dekorationsschicht, `PropArt` mit allen Requisiten, `Layout` mit Dorf und
Wegenetz, `asset_sheet.gd`, der Schalter `Config.EMPTY_WORLD` samt der
Insel-Erzeugung, und 52 ungenutzt gewordene Farben aus der Palette. `MapData`
schrumpfte von 333 auf 197 Zeilen, `WorldBuilder` von über 300 auf 26.

**Speicherstände bleiben lesbar.** Die Speicherfassung steht auf 3. Ein Stand
der Fassung 2 wird beim Laden über eine feste Tabelle umgesetzt: Wiese,
Waldboden, Weg und Pflaster werden Gras, Fels wird Gras, Tiefwasser wird
Wasser. Nichts geht verloren ausser der Unterscheidung, die es nicht mehr gibt.

**E schloss nie.** Der Umschalter lag im Bauwerkzeug, einem Kind der Welt. Die
Welt ist `PROCESS_MODE_PAUSABLE`, damit bei offenem Fenster nichts mehr in ihr
passiert — genau dadurch bekam das Bauwerkzeug bei offenem Inventar keine
Eingaben mehr und konnte es nie wieder schliessen. E öffnete, E schloss nicht.
Der Umschalter liegt jetzt in `Main._unhandled_input`, dem einzigen Knoten, der
immer läuft. Der Selbsttest drückt E dreimal hintereinander und prüft die Folge
„offen, zu, offen".

**`TileSetAtlasSource` legte keine Kacheln an.** `create_tile()` stand vor
`texture` und `texture_region_size`. Ohne Textur hält die Quelle jede Kachel
für ausserhalb liegend und legt schweigend keine an — 49 Fehlermeldungen je
Weltaufbau. Reihenfolge umgedreht, in `EdgeArt` steht jetzt ein Kommentar
darüber.

**Der Kachelsatz wird geprüft, nicht behauptet.** Neu im Selbsttest: Kachelgröße
im `TileSet`, Zahl der Atlasquellen, Textur und Bereichsgröße je Quelle, dass
jeder Kachelbereich vollständig innerhalb der Textur liegt, dass kein
`texture_origin` von null abweicht, dass keine Schicht verschoben, gedreht oder
skaliert ist, dass alle Schichten denselben Kachelsatz und Nearest-Filter
benutzen, dass die Z-Werte aufsteigen, dass keine gesetzte Zelle auf eine
unbekannte Kachel zeigt und dass `map_to_local()` für ein Feld genau dessen
Mittelpunkt in Weltkoordinaten liefert. Ein verrutschtes Bild wäre damit keine
Geschmacksfrage mehr, sondern ein fehlgeschlagener Test.

**Wasser und Kollision.** Keiner der drei Böden hält auf; die einzige feste
Fläche ist der Kartenrand. Damit kann kein gesetzter Block die Figur mehr
einschliessen, und die Prüfung dagegen (`_blocks_player`) entfiel. `lift()`
liefert nur noch die Sprunghöhe. Der Selbsttest läuft aus allen vier Richtungen
ins Wasser und misst dabei den grössten Positionssprung je Bild und den
grössten Bildversatz — beide müssen null bzw. unter einer halben Kachel
bleiben. Zusätzlich prüft er, dass keine Kollisionsform ohne festes Feld
zurückbleibt: alte Formen entfernter Blöcke als unsichtbare Wand waren ein
ausdrücklicher Punkt des Auftrags.

**Klangeffekte raus, Musik bleibt.** `Audio` hat keine `play_ui()` und keine
`play_step()` mehr, keine Stimmen, keine Tongeneratoren. Der „Effekte"-Regler
und `Settings.sfx_volume` sind weg. Der Musikpfad ist unangetastet. Der
Selbsttest prüft beides: dass Menü- und Weltmusik erzeugt werden und der
Musikspieler eine Spur hat — und dass weder die Schnittstelle noch irgendeine
Aufrufstelle im Quelltext übrig ist.

**Keine Leichen im Quelltext.** Eine Prüfung durchsucht alle `.gd`-Dateien nach
`Tile.MEADOW`, `Tile.FOREST`, `Tile.PATH`, `Tile.COBBLE`, `Tile.ROCK`,
`Tile.DEEP_WATER`, `EMPTY_WORLD`, `level_at`, `LAYER_SHADOW`, `PropArt` und
`Layout`. Ein einziger Treffer lässt den Test fehlschlagen. Sie hat beim ersten
Lauf zwei vergessene Kommentare gefunden.

**Stand dieses Nachtrags:** 155 Prüfungen, alle grün, Godot-Konsole beim Import und beim Lauf
ohne Fehler. Kachelnähte: Gras 1,16, Sand 0,66, Wasser 0,82 (1,0 = so glatt wie
das Kachelinnere). Weltaufbau 260 ms, ein Chunk in 1,5 ms, Physik 0,5 ms je
Bild.

## Nachtrag: Inventar und Bauleiste als ein Oberflächensystem

Das Inventar funktionierte, sah aber aus wie ein Entwicklerfenster: zwei
Erklärsätze übereinander, eine dünne gelbe Linie als einzige Auswahlmarkierung,
in ein Rechteck gestreckte Vorschaubilder und darunter eine zweite Leiste, die
anders aussah als die echte. Der Umbau war deshalb keine Farbkorrektur, sondern
eine Umstellung der Struktur.

**Ein Feld, zwei Ansichten.** Vorher hatte jede Ansicht ihre eigenen Rahmen,
Abstände und Beschriftungen — `Inventory._card()`, `Inventory._slot_card()` und
`BuildBar._make_slot()` bauten dreimal ungefähr dasselbe, aber nie ganz gleich.
Genau daher kam der Eindruck von „mehreren einzelnen Schaltflächen nebeneinander"
statt von einem System. Das ist jetzt eine Klasse: `ItemSlot`, ein `Control`,
das alles in `_draw()` zeichnet — Rahmen, Kachelbild, Nummer, Name. Zwei
Ausprägungen (`Kind.CARD` für die Materialkarten, `Kind.SLOT` für die
Leistenfelder) unterscheiden sich in Grösse und Beschriftung, nicht im
Aussehen. Damit gibt es auch keine verschachtelten Knoten und keine NodePaths
mehr, die brechen können; das alte `get_node("Name")` im Inventar ist weg.

**Vier Zustände statt einer Linie.** `NORMAL`, `HOVER`, `SELECTED`, `DISABLED`
liegen an einer Stelle und werden über zwei Werte (`_hover`, `_sel`)
ineinander überblendet. Gewählt heisst jetzt: kräftigerer Rahmen in der
Akzentfarbe, wärmere Fläche, weicher Schein (`StyleBoxFlat.shadow_size`) und
zwei Bildpunkte Wachstum. Der Selbsttest prüft das nicht am Bild, sondern an
den Werten: `frame_style()` des gewählten Feldes muss einen breiteren Rahmen,
einen Schein und eine andere Fläche haben als das eines ungewählten. Das
Überfahren wird mit einem echten `InputEventMouseMotion` durch den Viewport
ausgelöst und muss wieder abfallen.

**Bilder, die nicht verzerren können.** Die alte Vorschau zog eine 32er-Kachel
in ein 56 × 42 grosses Rechteck — nicht quadratisch und kein ganzzahliger
Faktor, also genau die ungleich breiten Bildpunkte, die das Projekt sonst
vermeidet. `TileIcon` baut stattdessen aus vier echten Bodenkacheln ein
64 × 64 grosses Stück Fläche und die Oberfläche zeichnet es 1:1. Weil die
Kacheln nahtlos sind, ist zwischen ihnen keine Naht zu sehen. Der Test hält
fest, dass die Kantenlänge ein ganzes Vielfaches von `Config.TILE` ist und
jedes Bild quadratisch bleibt.

**Eine Auswahl statt zweier.** Das Inventar hatte ein eigenes `target_slot`
neben `BuildBar.selected`. Zwei Auswahlen, die dasselbe meinten — deshalb war
der Satz „Feld unten wählen, dann oben einen Boden anklicken" überhaupt nötig.
`target_slot` ist jetzt eine reine Ableitung von `bar.selected`. Dadurch lassen
sich das gewählte Feld **und** das Material darauf gleichzeitig hervorheben,
und die Beziehung ist zu sehen statt zu lesen. Übrig sind drei kurze Texte:
`INVENTAR`, `Bauleiste`, `E – Schließen`. Der Test zählt sie und misst ihre
Länge.

**Getrennt bleiben sie trotzdem.** Das Inventar bestückt, die Leiste wählt im
Spiel schnell aus. Sie werden nie gleichzeitig angezeigt — bei offenem Inventar
zeigt das Inventar die Leiste selbst, `BuildBar` wird ausgeblendet. Vorher
standen beide übereinander auf dem Bild.

**Ein Weg auf, ein Weg zu.** `toggle_inventory()` gibt jetzt zurück, ob der
Zustand wirklich gewechselt hat, und nur dann gilt der Tastendruck als
verbraucht — vorher schluckte E die Taste in jedem Zustand, auch im Hauptmenü,
wo sie nichts bewirkte. `open_inventory()` und `close_inventory()` prüfen beide
ihren Ausgangszustand, bevor sie ihn setzen; doppeltes Öffnen oder Schliessen
ist damit unmöglich, egal ob der Anstoss von E, von ESC oder aus dem Selbsttest
kommt. Die Sichtbarkeit läuft über `Inventory.set_open()`, das ebenfalls
abbricht, wenn sich nichts ändert, und die kurze Einblendung anstösst.

**Keine durchsickernden Eingaben.** Jedes Feld ist `MOUSE_FILTER_STOP` und
`FOCUS_NONE`: der Klick endet im Feld, und die Tastatur landet nie darin, wo
Leertaste oder Eingabe es unabsichtlich auslösen könnten. Die Abdunkelung
hinter der Tafel ist ebenfalls `STOP` und fängt jeden Klick daneben ab.
Zusätzlich baut `BuildTool` weiterhin nur im Zustand `PLAYING` — zwei
unabhängige Sperren für dieselbe Sache, weil eine davon still ausfallen kann.
`BuildBar.covers()` meldet jetzt `false`, solange die Leiste unsichtbar ist.

**Weniger Dauertext im Spiel.** Unter der Leiste stand eine Zeile mit vier
Bedienhinweisen („Gras gewählt · 1–3 oder Mausrad wechseln · links setzen ·
rechts entfernen · E – Inventar"). Sie ist weg; das Label bleibt nur für kurze
Rückmeldungen wie „Karte gespeichert". Die Steuerung steht in der HUD und
vollständig im Optionsmenü.

**Stand:** 181 Prüfungen, alle grün.

## Nachtrag: Eine Designsprache, Menüs und echte Einstellungen

Nach dem Inventar war die Lage schief: EIN Fenster sah aus wie ein fertiges
Spiel, die übrigen Menüs weiter nach Prototyp — Holzrahmen aus Pixelgrafik
neben flachen Tafeln, drei verschiedene Radien, vier verschiedene Abstände.
Dieser Abschnitt zieht alle Oberflächen auf dieselbe Sprache und macht aus den
vier Schaltern ein Einstellungsmenü, hinter dem wirklich etwas hängt.

**Ein Ort für die Werte.** `UiTheme` ist keine Sammlung von Hilfsfunktionen
mehr, sondern die Designsprache: fünf Abstandsstufen (Vielfache von 4), drei
Radien, fünf Schriftgrößen, benannte Flächen- und Rahmenfarben, drei
Bewegungsdauern. Wer etwas braucht, das es dort nicht gibt, trägt es dort ein —
dann haben es alle. Die Pixel-Holzrahmen (`MenuArt.button_frame()`,
`panel_frame()`) sind ersatzlos weg; zwei Designsprachen nebeneinander waren
genau das Problem.

**Die Falle mit dem Theme.** Godot vererbt ein Theme nur entlang der
Control-Kette. JEDE Oberfläche dieses Spiels liegt aber unter einer
`CanvasLayer`, und die unterbricht die Kette. Ein Theme am Fenster wirkt
deshalb nicht — die Tafeln bekamen still Godots graue Voreinstellung
(0.1, 0.1, 0.1, 0.6) und waren halb durchsichtig, ohne dass irgendwo ein Fehler
stand. `UiTheme.attach()` hängt das gemeinsame Theme jetzt ausdrücklich an die
oberste Control jeder CanvasLayer, und eine Prüfung im Selbsttest fällt darauf
herein, bevor es jemand sieht.

**Ein Grundgerüst für Menüs.** `UiScreen` bringt Abdunkelung, mittige Tafel,
Innenrand und Ein-/Ausblenden mit; ein Menü füllt nur noch `_build()`. Ein
Menü bleibt undurchlässig für Mausklicks, SOLANGE es zu sehen ist — auch
während es ausblendet. Dadurch kann der Klick auf „Fortsetzen" nicht in der
Welt landen, bevor das Menü ganz weg ist.

**Schaltflächen mit Zuständen.** `UiButton` animiert Überfahren und Drücken
über dieselben Werte wie die Felder im Inventar, und behandelt Tastaturfokus
wie Mauszeiger. `size_flags_horizontal = SHRINK_CENTER` musste sein: ohne das
zieht ein VBoxContainer jede Schaltfläche auf die Breite der breitesten — aus
„ZURÜCK" wurde ein Balken über die ganze Tafel. Auch dafür gibt es jetzt eine
Prüfung.

**Auswahl statt Kästchen.** `UiChoice` zeigt alle Stufen nebeneinander und hebt
die geltende hervor. Damit sehen „Aus / An", „Einfach / Mittel / Hoch" und
„30 / 60 / 90 / …" gleich aus, statt Kästchen neben Aufklappmenüs zu mischen.
Die Feldbreiten kommen aus der Textbreite — „Unbegrenzt" braucht mehr Platz als
„60", und gleich breite Felder würden entweder abschneiden oder gähnen.

**Hauptmenü mit echten Wegen.** „Fortsetzen" steht nur da, wenn
`MapData.has_save()` etwas findet. „Neue Welt" geht über eine Rückfrage, wenn
dabei eine gebaute Karte verloren ginge — die Datei wird dabei NICHT gelöscht,
sie wird erst beim nächsten Speichern überschrieben. `MapData.generate()` hat
dafür ein `fresh`-Kennzeichen bekommen, das über `WorldBuilder` und `World`
durchgereicht wird.

**Einstellungen: getrennt gespeichert, getrennt angewendet.** `Settings` ist
jetzt reine Datenhaltung plus Persistenz. Das Anwenden macht `Graphics` — ein
zweiter Autoload, der die Auswahllisten für die Oberfläche UND die Werte
liefert, mit denen gerechnet wird. Dadurch kann keine Beschriftung entstehen,
hinter der kein Wert steht. `Config.LOAD_RADIUS` ist von `const` zu
`static var` geworden, weil die Sichtweite eine Einstellung ist; der
ChunkStreamer hängt an `Graphics.applied` und bestimmt seine Sollmenge neu,
sobald sie sich ändert.

**Was geprüft wird.** Nicht, ob ein Wert gespeichert wurde, sondern ob sich das
System dahinter ändert: `Engine.max_fps` nach dem Umstellen der Bildratengrenze,
die Zahl geladener Chunks nach dem Umstellen der Sichtweite (25 → 49 → 9), die
gezeichneten Rechtecke der Wasserwirkung auf der Stufe „Einfach" (0), die
Sichtbarkeit des Bodenschattens. Dazu ein echter Schreib-Lese-Vergleich für den
Neustart. Eine weitere Prüfung misst jede Kategorieseite gegen die Fläche, die
für sie da ist — sie hat sofort gefunden, dass die Leistungsseite mit ihren
sieben Bildratenstufen 652 statt 478 Bildpunkte breit war und die Tafel beim
Wechsel gesprungen wäre.

**Stand:** 196 Prüfungen, alle grün.

## Nachtrag: Bewegung in der Welt — und ein Boden, der wie Boden aussieht

**Wind und Wasserlicht als Shader auf der Schicht.** Der Boden sind vier
`TileMapLayer` über einer Karte mit 4,2 Millionen Feldern. Jede Kachel einzeln
zu animieren ist nicht bezahlbar, ein Knoten je bewegtem Halm erst recht nicht.
Ein Shader auf der Schicht kostet dagegen genau drei Materialien, unabhängig von
der Weltgrösse.

**Der Vertex-Schritt, nicht das Fragment.** Die erste Fassung rechnete die
Wellen je Bildpunkt. Gemessen auf dem Software-Rasterizer bei 1280 x 720: 13,8 ms
je Bild ohne Bewegung, **66 ms mit** — und die Physikzeit stieg von 0,3 auf
9,8 ms mit, weil Godot bei langsamen Bildern mehrere Physikschritte nachholt.
Dieselbe Wirkung im `vertex()` kostet wieder rund 17 ms. Eine Kachel hat vier
Eckpunkte und 1024 Bildpunkte; die Wellenlänge liegt bei mehreren hundert
Bildpunkten, die lineare Interpolation über eine 32er-Kachel sieht man nicht.
Es gibt bewusst kein `fragment()` — ohne eines nimmt Godot das voreingestellte
`COLOR *= texture(TEXTURE, UV)`, genau das, was gebraucht wird.

**Helligkeit statt Verschiebung.** Die Kacheln kommen aus einem Atlas. Ein
verschobenes UV griffe in die Nachbarkachel im Atlasbild; an jeder Kachelkante
entstünden Streifen fremder Farbe. Eine wandernde Aufhellung liest sich als Böe
über einem Feld und kann das nicht.

**„Aus" muss nichts kosten.** Bei Stufe 0 wird das Material ABGEHÄNGT, nicht auf
Stärke null gesetzt — ein Shader mit Faktor null rechnet trotzdem. Dasselbe beim
Staub: die Punkte werden entfernt, nicht unsichtbar geschaltet. Beides prüft der
Selbsttest, weil man einer Einstellung sonst nicht ansieht, ob sie hält, was sie
verspricht.

**Was die Messung wert ist.** Eine erste Prüfung verglich „mit" und „ohne"
direkt und schlug fehl, sobald die Zahlen um zwei Millisekunden streuten — sie
mass Rauschen. Die vier Kombinationen liegen alle bei 17 bis 21 ms; der
Unterschied ist auf einem Software-Rasterizer nicht auflösbar. Geprüft wird
deshalb die Grössenordnung: die Bewegung darf das Bild nicht um ein Vielfaches
teurer machen. Die Fragment-Fassung wäre daran gescheitert, das Rauschen ist es
nicht. Ausserdem wird ein erster Messdurchlauf weggeworfen — ein frisch
angehängter Shader wird beim ersten Bild übersetzt, diese eine Spitze (gemessen:
100 ms) gehört nicht in die Zahl.

**Der Boden.** Die Gras- und Sandkacheln trugen 230 deckende Einzelpixel auf
1024 — knapp ein Viertel der Fläche. Das war kein Gras, sondern Bildrauschen,
und es überdeckte jede grössere Struktur; im Bild las sich der Boden als
Fernsehschnee. Jetzt sind es rund 70, eingeblendet statt gesetzt, und die Halme
stehen in Büscheln von zwei bis drei. Damit fielen die Helligkeitsstufen je
Kachel auf, die das Korn vorher verdeckt hatte — `SHADE_STEP` ist von 0,035 auf
0,018 zurückgenommen, die grosse Helligkeitsbewegung kommt ohnehin vom Wind und
läuft über Kachelkanten hinweg weich durch. Die gemessenen Kachelnähte sind
dabei besser geworden: Gras 1,16 → 0,51, Sand 0,66 → 0,54.

**Stand:** 207 Prüfungen, alle grün.

## Nachtrag: Baugefühl und die Form, die das Gelände erkennt

**Zielwinkel statt Kasten.** Die Bauvorschau war ein geschlossener weisser
Rahmen um den Block. Der legt sich wie ein zweites Raster über die Welt und
schluckt genau die Kachel, die er zeigen soll. Vier Eckwinkel zeigen dasselbe
Feld und lassen es frei. Bewusst ohne Pulsieren: `GridOverlay` zeichnet sich nur
neu, wenn sich wirklich etwas geändert hat — dieser Sparzweck ist mehr wert als
eine atmende Linie, und eine pulsierende Vorschau hätte ihn zunichtegemacht.

**Ein Zeichen für „das habe ich getan".** `BuildFx` hält eine kurze Liste
vergänglicher Marken: ein Rahmen, der aus dem gesetzten Block herauswächst und
in 0,22 Sekunden verblasst, und eine kleine Staubwolke beim Aufkommen nach einem
Sprung. Ohne so etwas fühlt sich Bauen an wie das Ausfüllen einer Tabelle. Die
Liste ist auf 24 Marken begrenzt — beim schnellen Ziehen entstehen sonst
hunderte, und die verdecken am Ende die Welt, die sie zeigen sollen. Ist die
Liste leer, laufen weder `_process` noch `_draw`.

**Die Form steckt schon in der Maske.** Das Eck-Autotiling war da, geprüft wurde
bisher aber nur, DASS Übergänge entstehen. Der Kachelindex eines Übergangsfeldes
IST seine Eckmaske (0 – 14; 15 ist die Vollkachel), und daraus lässt sich die
Form direkt ablesen:

| Bits | Bedeutung |
|---|---|
| 1 | Aussenecke — nur diagonal berührt |
| 2 | gerade Kante |
| 3 | Innenecke |
| 4 | Vollkachel |

Der Selbsttest baut ein Einzelfeld, eine 3 x 3-Fläche, eine L-Form und ein
Wasserfeld und liest die Masken der Nachbarn ab. Er prüft nicht nur die Anzahl
der Bits, sondern welche: über einem Einzelblock muss Maske 12 stehen (die
beiden unteren Ecken), schräg darüber Maske 4 (nur unten rechts), in der Kerbe
einer L-Form Maske 11 (alles ausser der abgewandten Ecke). Neben Wasser darf gar
nichts auf der Wasserschicht liegen — seine Kante sitzt hart am Block, sonst
landete die Brandung auf dem Sand statt im Wasser.

Das ist ein Bildvergleich ohne Bilder: ein Ausrutscher im Autotiling fällt als
falsche Zahl auf, nicht erst jemandem beim Spielen.

**Nichts rechnet, wenn es nichts zu rechnen gibt.** Das ist die Regel, an der
Wirkungen in einem Sandkastenspiel scheitern: sie laufen weiter, auch wenn sie
abgeschaltet sind oder gar nichts zu tun haben. Für Bau-Rückmeldung, Staub und
Wasserwirkung wird deshalb `is_processing()` geprüft, nicht die Sichtbarkeit.

Ausserdem wirft die Leistungsmessung jetzt einen ersten Durchlauf weg. Auch nach
90 Aufwärmbildern fiel im ersten Messfenster noch eine Spitze an — zuletzt 56 ms
statt 17, aus Shader-Übersetzung und Texturuploads, die erst dort fällig werden.
Eine Zahl, die in der Dokumentation landet, darf davon nicht stammen.

**Stand:** 229 Prüfungen, alle grün. Weltaufbau 208 ms, ein Chunk in 1,1 ms, die
Minimap in 0,8 ms, Physik 0,7 ms je Bild, 50 Zeichenaufrufe.

## Nachtrag: Jede Seite einmal ansehen

Bis hierher waren mehrere Bildschirme nie angesehen worden — die
Einstellungsseiten „Leistung", „Steuerung" und „Ton", die Rückfrage vor einer
neuen Welt und das Hauptmenü mit vorhandener Karte. Sie sind jetzt Teil des
Selbsttests, der von jeder ein Bild ablegt. Das war kein Selbstzweck: drei der
fünf waren schlecht.

**„Ton" war eine Zeile in einem leeren Kasten.** Ein Thema, das aus einem
Regler besteht, ist kein Thema. Die Musik steht jetzt bei „Allgemein" — vier
Kategorien statt fünf — und der Regler zeigt seinen Wert in Prozent, statt raten
zu lassen.

**Die Steuerungsübersicht schwebte.** Sie lag als schmale Tabelle mitten in der
Fläche, rechts blieb totes Feld, und sie fing an einer anderen x-Position an als
die Zeilen der übrigen Seiten — beim Wechsel der Kategorie sprang alles. Jetzt
ist sie eine Tabelle über die volle Breite mit abwechselnd hinterlegten Zeilen.

**Der Seitenkasten war zu zwei Dritteln leer.** Er muss so hoch sein wie die
längste Kategorie; auf einer Seite mit drei Zeilen sah man vor allem seinen
leeren Boden, und ein sichtbar leerer Kasten liest sich als unfertig. Der Rahmen
ist weg: die Zeilen stehen als Streifen direkt auf der Tafel, eine dünne
senkrechte Linie trennt Kategorien und Inhalt, und der Platz darunter ist
einfach Rand. Die feste Grösse bleibt — sie hält die Tafel ruhig, wenn man die
Kategorie wechselt.

**Die Rückfrage wurde doppelt abgedunkelt.** Sie liegt über dem Hauptmenü, das
sich bereits selbst abdunkelt; zusammen war das Titelbild praktisch schwarz und
es sah aus, als sei das Spiel ausgegangen. Ihre eigene Abdunkelung ist auf 0,34
zurückgenommen.

**Und zwei Dinge ausserhalb der Menüs.** Das Blockraster war kräftig rot bei
30 % über dem ganzen Bild, die Chunk-Linien gelb bei 80 % — die Welt sah aus wie
Millimeterpapier. Die Entwicklerzeile oben links stand in 20 Punkt vollem Weiss
und war das Erste, was man im Bild sah. Beides ist zurückgenommen, beides
funktioniert unverändert. Das ist der Unterschied zwischen einem Werkzeug mit
Weltansicht und einem Spiel.

**Stand:** 233 Prüfungen, alle grün.

## Nachtrag: die visuelle Generalüberholung

Der Auftrag war, das ganze Bild auf das Niveau eines modernen 2D-Pixel-Spiels
zu bringen — nicht einzelne Grafiken, sondern alles, was zum Aussehen gehört.
Angefangen wurde deshalb nicht bei den Kacheln, sondern beim Rendering: eine
Kachel, die auf dem Bildschirm verzerrt ankommt, wird durch Nachzeichnen nicht
besser.

**Die Pixel waren nicht quadratisch.** `CAMERA_ZOOM` stand auf 1,5. Bei Faktor
1,5 wird aus einem Weltpixel mal ein, mal zwei Bildschirmpunkte — nachgewiesen
an einer zwölffachen Vergrösserung des Figurenkopfes, auf der Reihen
abwechselnd ein und zwei Punkte hoch sind. Das ist die Ursache für „unsaubere
Kanten", die man sonst der Zeichnung anlastet. Zoom 2 macht jeden Weltpixel
exakt zwei Punkte breit und hoch. Das Sichtfeld wird dabei kleiner (20 × 11
statt 27 × 15 Felder) — das ist der Preis, und er ist es wert. Alles, was in
Bildschirmpunkten gemeint ist (Rasterlinien, Eckwinkel), rechnet seither über
`_w()` in Weltbreite um, damit es beim Zoomen nicht mitwächst.

**Die Kachelkanten waren ein Schachbrett.** Die Übergänge zwischen zwei Böden
entstanden über eine geordnete 4 × 4-Bayer-Matrix. Die ist regelmässig, und
genau so sah die Kante auch aus: ein Schachbrett aus Einzelpixeln quer über
jeden Übergang. Bei Zoom 1,5 ging das unter, bei Zoom 2 war es das
Künstlichste im ganzen Bild. Jetzt verschiebt zusammenhängendes Rauschen
(`FastNoiseLite`, Frequenz 0,13) die Schwelle — daraus werden Zungen und
Buchten, wie von Hand gesetzt. Dazu gibt es jede Eckmaske in drei
Ausführungen; vorher bestand jede Küstenlinie im Spiel aus fünfzehn immer
gleichen Bausteinen. Welche Ausführung ein Feld bekommt, entscheidet sein
ortsfester Streuwert, nicht der Zufall beim Laden.

**Die Welt bekam Dinge.** Büschel, Blumen, Klee, Steine, Kiesel, Muscheln und
Treibholz liegen in einer eigenen Kachelschicht (`LAYER_DECOR`, z = −15) unter
der Kantenschicht. Ein Knoten je Büschel wäre bei 5 × 5 geladenen Chunks
sechsstellig gewesen; eine Kachelschicht kostet dasselbe wie der Boden darunter.
Auf Gras steht deutlich mehr als auf Sand — ein gleichmässig bestreuter Strand
sähe falsch aus.

**Die Welt war flach ausgeleuchtet.** Jede Kachel zu jeder Zeit gleich hell —
das ist der Unterschied zwischen einer Textur und einem Ort. Der `LightManager`
bringt drei Mittel mit, alle billig: ein `CanvasModulate` färbt und dunkelt die
ganze Welt über einen Tag von acht Minuten, ein `PointLight2D` auf Brusthöhe
folgt der Figur, und eine Vignette dunkelt die Bildränder. Der Schein blendet
**nach Helligkeit** auf, nicht nach Uhrzeit — dadurch passt er automatisch,
wenn sich der Verlauf einmal ändert. Das Licht liegt auf der Welt, nicht auf
der Oberfläche: `CanvasModulate` wirkt nur in seiner eigenen `CanvasLayer`, und
HUD (5), Bauleiste (6) und Inventar (8) liegen auf eigenen; die Vignette hängt
auf Ebene 1. Auf Stufe „Aus" werden alle drei Knoten unsichtbar geschaltet und
der Prozessschritt abgestellt — ein `CanvasModulate` in Weiss würde sonst
weiterhin über jeden Bildpunkt gerechnet.

**Die Figur war halb durchsichtig — und niemandem war es aufgefallen.** Das
ganze Raster lag bei `z_index` 500 über allem, auch die Bauvorschau. Die ist
aber eine halbdurchsichtige Kachel im Zielfeld, und das Zielfeld grenzt fast
immer an die Figur: über ihrer unteren Hälfte lag ein Schleier, und die weissen
Eckwinkel liefen quer durchs Gesicht. Gefunden wurde das erst bei einer
fünffachen Vergrösserung eines Testbildes. Bauvorschau und markiertes Feld
liegen jetzt auf einem eigenen Knoten mit `z_as_relative = false` und
`z_index = -2` — über Boden und Wasserwirkung, unter Schatten und Figur.
Rasterlinien, Chunk-Nummern und Weltrand bleiben oben.

**Das Raster ist beim Start aus.** Eingeschaltet legt es ein gelbes Kreuz über
den ganzen Bildschirm und schreibt „Chunk 64 | 64" quer neben die Figur. Wer
das Spiel zum ersten Mal startete, sah eine Karte mit Gitternetz, keinen Ort.
G schaltet es an, die Steuerungshilfe sagt das in der ersten Zeile. Aus
demselben Grund ist die Anzeige oben links auf eine Zeile zusammengezogen: die
zweite nannte Kachelgrösse und Kartenmasse — Zahlen, die eine ganze Sitzung
lang dieselben bleiben. Sie stehen auf F3.

**Die Figur steckte im Wasser in einem gestanzten Loch.** Unter der Wasserlinie
wurde alles gelöscht und darüber eine gerade Schaumlinie über die volle Breite
gelegt — über einer 32 Pixel breiten Figur liest sich das als Brett. Jetzt
bleibt der Körper unter Wasser durchscheinend und zur Wasserfarbe hin
verschoben, und der Wellenkragen ist ein Ring: vorn läuft er über den Körper,
hinten verschwindet er dahinter. Der Bodenschatten sitzt einen Pixel nach unten
rechts versetzt — das Licht kommt in dieser Welt von oben links, bei jeder
Kachel und an der Figur selbst.

**Und eine Messung, die nichts mass.** Die Prüfung „Physikzeit pro Bild unter
8 ms" schlug einmal mit 11,46 ms fehl und lief beim nächsten Lauf bei sonst
unverändertem Code mit 4,75 ms durch. Godot zählt in `TIME_PHYSICS_PROCESS` die
Zeit ALLER Physikschritte einer Hauptschleifen-Runde; wird ein Bild langsamer,
holt Godot die feste Schrittrate mit mehreren Schritten nach, und die Zahl
misst die Auslastung der Maschine statt der Physik. Sie wird jetzt durch die
Zahl der Schritte je Bild geteilt. Dieselbe Falle beim Licht: „aus" kam mit
49,45 ms teurer heraus als „voll" mit 41,77 ms. Statt Millisekunden zählt der
Test dort Zeichenaufrufe — 53 ohne, 56 mit Beleuchtung — denn die eigentliche
Gefahr eines 2D-Lichts ist, dass es jeden Knoten in seinem Umkreis ein zweites
Mal zeichnen lässt.

**Stand:** 251 Prüfungen, alle grün.

## Nachtrag: messen statt raten

Der Auftrag hiess: die Nacht kostet auf einem echten Rechner zwei Drittel der
Bildrate, findet den Engpass, und zwar durch Profilieren statt Raten.

**Die erste Erkenntnis war, dass die letzte Messung keine war.** Die Kosten der
Beleuchtung wurden mit `Performance.TIME_PROCESS` bestimmt. Das ist die Zeit im
`_process`-Schritt der Hauptschleife; das Zeichnen läuft danach und steckt
nicht darin. Herausgekommen war deshalb, die Beleuchtung koste nichts — „aus"
sogar teurer als „voll". Die Zahl war nicht ungenau, sie war das falsche Mass.

Es gibt jetzt einen Messharness (`--profile`), der die Engine selbst fragt:
`viewport_get_measured_render_time_cpu` und `…_gpu`. Damit steht der Engpass
in einer Tabelle statt in einer Vermutung:

    Beleuchtung aus      CPU  6,07 ms   GPU 2,66 ms
    nur Toenung          CPU  6,06 ms   GPU 2,75 ms    <- gratis
    + Figurenlicht       CPU  9,48 ms   GPU 2,57 ms    <- +3,43 ms CPU
    + Vignette           CPU 11,58 ms   GPU 4,72 ms    <- +1,69 / +1,80

Zwei Ursachen: ein `Light2D` zwingt den Canvas-Renderer in den beleuchteten
Pfad und lässt jedes Element in seinem Umkreis ein zweites Mal einreihen — und
weil das Licht der Figur jedes Bild nachgeführt wird, fällt diese Arbeit auch
jedes Bild neu an. Dazu ein Vollbild-Fragment-Shader über 921 600 Bildpunkte.

Ersetzt durch: `CanvasModulate` (gemessen gratis, bleibt), ein additives Sprite
je Lichtquelle, und eine einmal gebackene Verlaufstextur. Am Tag hängt die
ganze Nachtschicht ab. Der Selbsttest hält fest, dass **kein einziges
`Light2D`** in der Welt existiert — das ist die Prüfung, die den Aufschlag
fernhält, und sie ist wichtiger als jede Millisekundenmessung, weil
Millisekunden auf dieser Maschine zwischen zwei Läufen um mehr als das Doppelte
schwanken.

**Vier Stufen statt eines Schalters.** Der Nutzer wollte mehrere Möglichkeiten
für schwache Rechner. Weil die drei Mittel sehr unterschiedlich kosten, sind
sie einzeln abstufbar: „Einfach" behält den vollen Tagesverlauf (gratis) und
verliert nur die beiden Flächen, die Füllrate kosten.

## Nachtrag: eine Lücke, die keine war

    [SAND][SAND][ leer ][SAND][SAND]

Das leere Feld hat ringsum Sand, also Eckmaske 15 — und die Tabelle der
Teilkacheln endete bei 14. Maske 15 griff damit hinter die Teilkacheln in die
Vollkacheln: das leere Feld bekam eine volle Sandkachel, und die Lücke war weg.

Derselbe Fehler traf jeden einzeln entfernten Block mitten in einer Fläche:
acht Nachbarn ringsum, Maske 15, Vollkachel. Man klickte, der Block war in der
Karte weg — und man sah es nicht. Gemessen: **0 von 1024 Bildpunkten offen**.

Maske 15 hat jetzt eine eigene Form mit Öffnung, und wohin die Öffnung läuft,
entscheiden die echten Nachbarn: liegt der Boden links und rechts, läuft die
Lücke senkrecht weiter und die Öffnung ist ein senkrechter Schlitz. Ein rundes
Loch stünde dort mitten in einem durchgehenden Spalt. Jetzt: **468 von 1024**.

Der Test dazu prüft nicht die Maske — die ist in beiden Fällen 15 — sondern ob
wirklich eine Vollkachel gesetzt wurde und wie viele Bildpunkte der Kachel
durchsichtig sind. Eine Prüfung auf die Maske wäre an genau diesem Fehler
vorbeigelaufen.

## Nachtrag: die Steuerung gehört dem Spieler

`W` `A` `S` `D` ist der Auslieferungszustand, nicht die Steuerung. Die
Spiellogik fragte schon vorher Aktionen ab statt Tasten; was fehlte, war das
Menü, das Speichern und die Konflikterkennung.

Zwei Entscheidungen, die nicht offensichtlich sind:

**Gespeichert werden PHYSISCHE Tastencodes.** Auf einer französischen Tastatur
liegt an der Stelle von `W` ein `Z`, und genau die Taste soll dann vorwärts
laufen — sonst müsste jeder mit einer anders angeordneten Tastatur die
Steuerung von Hand neu belegen. Angezeigt wird trotzdem der Buchstabe, der
wirklich auf der Taste steht.

**Die letzte Eingabe einer Aktion lässt sich nicht wegnehmen.** Eine Aktion
ohne Eingabe wäre unerreichbar, und im Menü sähe man ihr das nicht an.

Der Selbsttest prüft nicht, dass das Menü Knöpfe hat, sondern dass in Welt,
Figur, Kamera und Kern **kein einziger `KEY_`-Code** steht. Wer dort eine feste
Taste stehen lässt, macht jede Umbelegung zur Lüge.

## Nachtrag: was nicht gemacht wurde

**Die Wasserkante ist noch blockgenau.** Wasser bekommt als einzige Schicht
keine weichen Übergangskacheln — das Eck-Autotiling legt die Geländegrenze eine
halbe Kachel versetzt zum Blockraster, Uferband und Brandung sitzen aber am
Block. Mit weichem Auslauf landete die Brandung auf dem Sand. Das sauber zu
lösen heisst, die Uferzeichnung auf dasselbe Eckraster umzustellen; das ist
eine eigene Runde und keine Zeile nebenbei. Was stattdessen dazukam: eine
Kielwelle hinter jedem, der sich durchs Wasser bewegt.

**Stand:** 297 Prüfungen, alle grün.

## Nachtrag: eine Anzeige, die sich selbst misst

Auf einem Bildschirmfoto vom Spieler war es eindeutig: die Entwicklerinfo hatte
eine feste Grösse (452 x 340), der Text war höher, und die letzten drei
Abschnitte standen ungerahmt über der Welt. Bei der Leistungsanzeige lag die
letzte Zeile („Speicher 51 MiB") halb ausserhalb.

Eine feste Zahl kann das nicht lösen: die Höhe hängt an der Schriftgrösse, an
der Sprache und daran, wie viele Zeilen gerade Sinn ergeben. Der Inhalt steht
jetzt in echten Containern, und die Tafel übernimmt deren Mindestgrösse. Passt
sie trotzdem nicht auf den Bildschirm, wird die Schrift eine Stufe kleiner —
abschneiden ist keine Antwort.

Der Selbsttest vergleicht seither die Rahmengrösse mit der Inhaltsgrösse. Das
ist die Prüfung, die vorher gefehlt hat: dass die Anzeige die richtigen Zahlen
NENNT, wurde geprüft, dass man sie SIEHT, nicht.

## Nachtrag: das Wasser zieht sich zurück

Wasser war die einzige Schicht mit harter Kante, und der Auftrag hiess: „keine
perfekten rechteckigen Wasserbecken". Weiche Übergänge wie bei Sand gingen
nicht, aus zwei Gründen — die Karte weiss, welches Feld Wasser ist, und daran
hängt das Schwimmen; und Uferband und Brandung sassen am Blockrand.

Die Lösung dreht die Frage um. Beim normalen Übergang gilt eine Ecke, sobald
EINES der drei dort anliegenden Felder dazugehört: die Fläche wächst heraus.
Beim Wasser gilt sie nur, wenn ALLE drei dazugehören: die Fläche zieht sich
zurück. Dieselben Kacheln, dieselbe Rauschkante, nur die Frage ist umgekehrt.
Darunter liegt Sand, der dabei zum Vorschein kommt.

Damit stimmen Karte und Bild weiterhin überein — Wasser liegt nie auf einem
Feld, das keines ist —, und ein einzelnes Wasserfeld wird eine runde Pfütze
statt eines Quadrats.

**Und dann musste die Kantenschicht weg.** Uferband und Tiefenband sassen am
Blockrand, genau dort, wovon sich das Wasser jetzt zurückzieht. Auf dem ersten
Bild danach lief um jeden Teich ein schnurgerades dunkles Rechteck durch den
Sand, während die Wasserlinie daneben geschwungen verlief: zwei Beschreibungen
derselben Küste, die sich widersprechen. Schaum und Tiefe stehen seither in der
Wasserkachel selbst (`TerrainAtlas.Rim.SHORE`) — eine Quelle, kein Widerspruch.
`EdgeArt` ist gelöscht.

## Nachtrag: der Sprung war eine Verschiebung

Dasselbe Standbild, ein Stück weiter oben. Jetzt gibt es drei gezeichnete
Stellungen: gehockt (Absprung UND Landung — in beiden geht die Figur in die
Knie), gestreckt, fallend. Gezeichnet und nicht skaliert: eine Figur, die auf
1,08 gestreckt wird, hat ungleich breite Pixel, und genau dieser Fehler war der
Grund, den Zoom ganzzahlig zu machen.

Die Handfackel hängt an derselben Dunkelheit wie die Beleuchtung, nicht an
einer eigenen Uhr — sonst hielte die Figur bei abgeschalteter Beleuchtung
mitten am Tag eine brennende Fackel.

## Nachtrag: ein Test, der vom letzten Test abhing

Die Prüfung „Mit Staub rechnet er wieder" schlug in jedem Lauf fehl, ohne dass
sich am Code etwas geändert hätte. Ursache: der Lauf erbte die `settings.cfg`,
und ein früherer Lauf hatte dort den Staub auf 0 stehen lassen — die Prüfung
stellte ihn also auf 0 zurück und erwartete, dass er an ist.

Der Lauf startet jetzt auf den Auslieferungswerten, geholt aus einer frischen
Instanz von `settings.gd`. Damit steht im Test keine zweite Liste, die
irgendwann von den echten Vorgaben abweicht. Am Ende bekommt der Spieler seine
Datei zurück: ein Testlauf darf niemandem seine Grafikstufen umstellen.

Dabei fiel noch etwas auf: die automatische Qualitätsanpassung regelte MITTEN
im Testlauf herunter, weil die Bildzeit auf dieser Maschine schlecht genug ist.
Sie ist für den Lauf abgeschaltet; ihre eigene Wirkung prüft `_check_quality()`
direkt, ohne auf eine langsame Maschine zu warten.

**Stand:** 327 Prüfungen, alle grün.

## Nachtrag: was groß ist, muss überall gleich sein

Der Selbsttest prüfte seit langem, ob eine Kachel mit **sich selbst** nahtlos
ist: letzte Spalte gegen erste Spalte. Das ist nötig, aber es ist nicht die
Frage, die auf dem Bildschirm gestellt wird — dort liegt neben Variante 3 die
Variante 7, und ob DIE zusammenpassen, hat nie etwas gemessen.

Genau da saß ein Fehler, den man auf jedem Bild sehen konnte, sobald man wusste,
wonach man sucht. Die Tiefenbänder im Wasser wurden je Variante neu ausgewürfelt.
Ein Band läuft über die volle Kachelbreite und hört an der Kante auf; stieß dort
eine Kachel ohne Band an, sprang die Helligkeit. Über eine ruhige Wasserfläche
hinweg war das ein Gitter — gemessen 1,94, der schlechteste Wert im Projekt.

`_check_variant_seams()` misst das jetzt: jede Variante gegen jede andere
derselben Helligkeitsstufe, Farbsprung an der Stoßkante geteilt durch den Sprung
zweier benachbarter Punkte im Kachelinneren.

| | vorher | jetzt |
|---|---|---|
| Gras | 1,59 | 1,43 |
| Sand | 1,35 | 1,05 |
| Wasser | 1,94 | 1,11 |

Die Regel, die daraus folgt, steht im Code an drei Stellen: **was groß ist, muss
in allen Varianten gleich sein, sonst sieht man die Fuge. Was sich unterscheiden
darf, muss klein oder weich sein.** Die Tiefenbänder stehen deshalb in jeder
Variante an derselben Stelle, und die neuen Farbtöne von Gras und Sand stecken
in den Halmen und Körnern statt in den großen Flecken.

Bemerkenswert daran ist die Reihenfolge: die Verfeinerung kam zuerst, sie hat
die Naht von 1,59 auf 1,72 verschlechtert, und erst die *Messung* hat gezeigt,
wo die Farbe hingehört. Ohne die Prüfung wäre die reichere Wiese mit einem
sichtbaren Raster ausgeliefert worden.

## Nachtrag: die Nacht war grün

In der Farbtabelle stand seit der ersten Fassung `Color(0.26, 0.30, 0.50)` mit
dem Kommentar „tiefe Nacht, blau". Auf dem Bildschirm war sie dunkelgrün, und
das über mehrere Runden hinweg, ohne dass es jemandem auffiel — auch mir nicht,
obwohl ich die Nacht in derselben Runde profiliert und umgebaut habe.

Der Grund ist eine Zeile Rechnung. `CanvasModulate` multipliziert. Gras ist
(78, 138, 68); darin steckt fast kein Blau, das sich verstärken ließe. Das
Ergebnis ist (20, 41, 34). Eine blaue Tönung kann aus einer grünen Wiese keine
blaue Nacht machen — sie kann sie nur dunkler machen.

Der Kommentar war also nicht falsch geschrieben, sondern falsch **geglaubt**:
er beschrieb die Absicht, und niemand hat das Ergebnis dagegen gehalten. Die
neue Prüfung tut genau das — sie rechnet Gras mal Nachttönung und schaut nach,
ob dabei etwas Blaues herauskommt.

Blau kommt jetzt dazu statt durchmultipliziert zu werden: eine
halbdurchsichtige Fläche über der Welt, unter den Scheinen. Ein Viereck, kein
Shader. Gemessen (llvmpipe, 1280 × 720): ein zusätzlicher Zeichenaufruf,
**+0,19 ms Bildzeit**. Der Profiler hat dafür eine eigene Zeile bekommen —
jede Zeile schaltet genau ein Mittel dazu, sonst ist die Differenz nicht der
Preis dieses einen Mittels.

## Nachtrag: was wie eine Markierung aussieht, ist eine

Auf einem Bildschirmfoto standen drei helle Formen in der Welt, die ein Spieler
für vergessene Entwicklermarken hielt und deren Entfernung er verlangte. Es
waren drei verschiedene Sachen: ein blockgenauer Schaumsaum (ein echter Fehler,
Geschwister des dunklen Rechtecks von EdgeArt), weiße Blüten (fünf Punkte im
Kreuz mit dem hellsten in der Mitte) und die Bauvorschau (vier Eckwinkel in
reinem Weiß bei 95 %).

Nur das erste war ein Fehler im engeren Sinn. Die anderen beiden funktionierten
genau wie vorgesehen — sie sahen nur aus wie etwas anderes. Das ist derselbe
Fehler, und er ist schwerer zu finden, weil kein Test darauf anspringt: die
Blüte war eine Blüte, die Vorschau war eine Vorschau, jede Prüfung grün.

Was hilft, ist eine Prüfung, die nicht nach Absicht fragt, sondern nach
Wirkung. Für den Staub in der Luft steht sie jetzt da: *blasser als der hellste
Boden, den es in dieser Welt gibt.* Der erste Versuch, ihn zu entschärfen, ist
daran gescheitert — er war immer noch heller als Sand.

## Lizenzlage

Das Projekt enthält keine fremden Asset-Dateien. Eine Prüfung im Selbsttest
durchsucht `res://` nach Bild-, Ton- und Schriftdateien und schlägt fehl,
sobald eine auftaucht. Details in `CREDITS.md`.
