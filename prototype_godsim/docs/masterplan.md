# 🌍 PROJEKT „TERRARIA MUNDI" — Masterplan für ein extrem hochwertiges 2D-Spiel

> **Arbeitstitel:** Terraria Mundi (später umbenennen, Name nur Platzhalter)
> **Genre:** 2D God-Sim / Aufbau-Sandbox mit lebendiger Zivilisations-Simulation
> **Elevator Pitch:** *„Du bist keine Figur im Spiel — du bist die Welt selbst. Forme Kontinente, setze Völker aus, und schau zu, wie aus drei Hütten ein Imperium wird, das dich irgendwann anbetet… oder verflucht."*

---

## 1. Vision & Kernidee

### Was macht das Spiel besonders?
Die meisten God-Sims (WorldBox etc.) sind reine Sandkästen: Man wirft Sachen rein und schaut zu. **Terraria Mundi geht einen Schritt weiter:** Die Völker *erinnern sich*. Jedes Dorf schreibt seine eigene Geschichte — Kriege, Helden, Katastrophen, die DU ausgelöst hast — und diese Geschichte beeinflusst, wie sich die Zivilisation entwickelt.

**Die drei Säulen:**
1. **Emergente Geschichten** — Kein Spieldurchlauf gleicht dem anderen. Ein Blitz, den du aus Langeweile wirfst, kann eine Religion gründen.
2. **Langsames, befriedigendes Wachstum** — Vom ersten Lagerfeuer bis zur Stadt mit Mauern, Handel und Politik. Man kann stundenlang einfach nur zuschauen.
3. **Konsequenzen** — Die Welt reagiert auf dich. Völker bauen Tempel für dich oder rebellieren gegen dich.

### Zielgruppe
- Fans von WorldBox, RimWorld, Dwarf Fortress, Songs of Syx
- Leute, die gern „Ameisenfarm-Feeling" haben: zuschauen, eingreifen, staunen
- Spielbar in kurzen Sessions (10 min) UND langen Sessions (4 h+)

---

## 2. Gameplay im Detail

### 2.1 Der Kern-Loop
```
Welt formen → Leben aussetzen → Beobachten → Eingreifen → Konsequenzen erleben → wieder von vorn
```

### 2.2 Weltgestaltung (Terraforming)
- Pinsel-basiertes Terrain: Erde, Wasser, Sand, Fels, Lava, Schnee
- Biome entstehen **automatisch** aus Nachbarschaften (Wasser + Erde + Wärme = Sumpf)
- Höhenstufen (3 Ebenen: Tiefland, Hügel, Gebirge) für taktische Vielfalt
- Flüsse fließen physikalisch korrekt bergab (vereinfachte Fluid-Sim auf Tile-Basis)

### 2.3 Die Völker
- 4 Startvölker mit klar unterschiedlichen Spielstilen:
  - **Menschen** — ausgewogen, expandieren schnell
  - **Waldlinge** — leben mit der Natur, langsam aber zäh
  - **Aschgeborene** — lieben Vulkane und Lava, aggressiv
  - **Tiefsee-Volk** — siedeln an/unter Wasser (Alleinstellungsmerkmal!)
- Jede Einheit ist ein **Individuum** mit Name, Alter, Beruf, 2–3 Charakterzügen und Beziehungen
- Dörfer entwickeln sich in Stufen: Lager → Dorf → Stadt → Königreich

### 2.4 Simulation (das Herzstück)
- **Bedürfnisse:** Nahrung, Schutz, Glaube, Sicherheit
- **Wirtschaft light:** Ressourcen (Holz, Stein, Nahrung, Erz) werden real transportiert — man sieht Träger laufen
- **Diplomatie:** Bündnisse, Handel, Kriege, Tribut — entsteht aus Nachbarschaft + Ereignissen
- **Religion:** Völker deuten deine Eingriffe. Wirfst du oft Blitze → Sturmgott-Kult mit eigenen Priestern und Tempeln
- **Chroniken-System (Killer-Feature):** Jedes Dorf führt ein automatisch generiertes Geschichtsbuch („Im Jahr 34 zerstörte der Große Blitz die Ernte. Seither fürchten wir den Himmel.")

### 2.5 Deine Kräfte als Gottheit
- **Schöpfung:** Regen, Sonnenschein, Tiere, Segen, Fruchtbarkeit
- **Zerstörung:** Blitz, Meteor, Erdbeben, Vulkan, Seuche
- **Subtil:** Träume einflüstern, einzelne Helden inspirieren, Wetter lenken
- Kräfte kosten „Glauben" — den bekommst du von Völkern, die an dich glauben → eleganter Balancing-Loop

### 2.6 Spielmodi
- **Sandbox** — alles frei, unendlich
- **Szenarien** — z. B. „Führe ein Volk durch eine Eiszeit" (gibt dem Spiel Struktur & Ziele)
- **Beobachter-Modus** — null Eingriffe, reine Simulation (für die Hardcore-Fans)

---

## 3. Art Direction — „extrem hochwertig" konkret gemacht

### Stil
- **Handgemachtes Pixel-Art** in moderner Ausführung (Vergleich: Songs of Syx, Eastward, Dome Keeper)
- Tile-Größe: 16×16 Basis, Charaktere 16×24
- **Farbpalette:** Eine feste, warme Palette (ca. 48 Farben) für visuellen Zusammenhalt
- Weiche Tag/Nacht-Zyklen mit dynamischem Licht (Fackeln, Lava, Blitze leuchten real)
- Wetter-Effekte mit Partikeln: Regen, Schnee, Ascheregen, Nebelbänke

### Animation = Lebendigkeit
- Alles bewegt sich subtil: Gras wiegt im Wind, Wasser glitzert, Rauch steigt aus Kaminen
- Einheiten haben Idle-Animationen (Bauern wischen sich den Schweiß ab, Kinder spielen)
- „Juice": Screenshake bei Meteor, Lichtblitz bei Blitzschlag, Zeitlupe bei epischen Momenten

### UI
- Minimalistisch, Holz/Pergament-Optik, blendet sich aus wenn man nur zuschaut
- Tooltips für ALLES (Dwarf-Fortress-Tiefe, aber zugänglich)

---

## 4. Sound & Musik

- **Adaptive Musik:** Ruhige Ambient-Tracks, die sich bei Krieg/Katastrophe dynamisch verdichten
- Jedes Biom hat eine eigene Klanglandschaft (Vogelgezwitscher, Wind, Meeresrauschen)
- Satisfying Sound-Feedback: „Plopp" beim Terrain-Malen, Donnergrollen, Dorfglocken
- Kostenlos starten: Freesound.org + eigene Aufnahmen; später ggf. Komponist:in aus der Indie-Szene

---

## 5. Technik

### Engine-Entscheidung: **Godot 4.x** ✅
Warum Godot und nicht Phaser/Unity:
- Kostenlos, Open Source, kein Abo, keine Lizenzgebühren
- Exzellent für 2D (TileMapLayer, Partikel, Licht-System eingebaut)
- GDScript ist leicht zu lernen, wenn man schon JavaScript/Node.js kann
- Export für Windows, Linux, macOS und sogar Web mit einem Klick

### Architektur-Grundsätze
- **Simulation vom Rendering trennen** — die Welt tickt in festen Schritten (z. B. 10 Ticks/Sek.), Grafik interpoliert dazwischen → ermöglicht Zeitraffer ×1/×3/×10
- **Daten-orientiert:** Einheiten als leichte Datenobjekte, nicht als schwere Nodes → tausende Einheiten möglich
- Chunk-System für die Karte (nur sichtbare/aktive Bereiche voll simulieren)
- Speichersystem von Tag 1 an mitdenken (JSON → später binär)

### Tools drumherum
- **Aseprite** (oder kostenlos: LibreSprite/Pixelorama) für Pixel-Art
- **Git + GitHub** für Versionierung (kennst du ja schon)
- **Tiled** optional für Szenario-Karten

---

## 6. Roadmap — vom Prototyp zum fertigen Spiel

### 🥚 Phase 0: Prototyp (Wochen 1–6)
**Ziel: Beweisen, dass der Kern Spaß macht.**
- [ ] Terrain malen (3 Tile-Typen reichen)
- [ ] Ein Volk aussetzen, das Hütten baut und Nahrung sammelt
- [ ] Eine Gottheit-Kraft (Blitz)
- [ ] Kamera: Zoomen, Schwenken, Zeitraffer
- **Meilenstein:** 10 Minuten zuschauen, ohne dass es langweilig wird? → weiter!

### 🐣 Phase 1: Vertical Slice (Monate 2–5)
**Ziel: Ein kleines Stück vom fertigen Spiel in voller Qualität.**
- [ ] Finaler Art-Style steht (Palette, erste hübsche Tiles + Animationen)
- [ ] 1 Volk komplett: Wachstumsstufen Lager → Dorf
- [ ] 5 Gottheit-Kräfte, Glauben-Ressource
- [ ] Tag/Nacht, Wetter, Sound-Grundgerüst
- [ ] Speichern/Laden
- **Meilenstein:** Ein 2-Minuten-Gameplay-Video, das man stolz zeigen kann

### 🐥 Phase 2: Content & Tiefe (Monate 6–12)
- [ ] Alle 4 Völker
- [ ] Diplomatie, Kriege, Handel
- [ ] Religionssystem + Chroniken
- [ ] 10+ Kräfte, Katastrophen
- [ ] Erste Szenarien
- **Meilenstein:** Closed Beta mit 10–20 Testern (z. B. aus deiner Community)

### 🐔 Phase 3: Polish & Early Access (Monate 13–18)
- [ ] Balancing, Performance (Ziel: 2000+ Einheiten flüssig)
- [ ] Steam-Seite, Trailer, Demo fürs Steam Next Fest
- [ ] Achievements, Statistik-Bildschirme, Mod-Freundlichkeit (Daten in lesbaren Dateien)
- **Meilenstein:** Early-Access-Release auf Steam / itch.io

### 🦅 Phase 4: Live & Wachstum (ab Monat 18)
- Community-Feedback einbauen, Updates in festen Zyklen (alle 6–8 Wochen)
- Große kostenlose Updates > viele kleine DLCs (baut Vertrauen auf, siehe Terraria/Stardew)

---

## 7. Scope-Kontrolle (der wichtigste Abschnitt!)

Der Killer Nr. 1 für Indie-Spiele ist nicht Talent, sondern **zu großer Scope**. Regeln:

1. **Der Prototyp muss in 6 Wochen stehen.** Wenn nicht → Konzept verkleinern, nicht Zeitplan verlängern.
2. **„Nice to have"-Liste führen:** Jede coole Idee kommt erst auf die Liste, nie direkt ins Spiel.
3. **Ein Feature ist erst fertig, wenn es sich gut ANFÜHLT** — nicht wenn es nur funktioniert.
4. Multiplayer, 3D-Effekte, Mobile-Port: **explizit NICHT in Version 1.0.**
5. Lieber ein kleines Spiel, das sich hochwertig anfühlt, als ein großes, das sich leer anfühlt.

---

## 8. Risiken & Gegenmittel

| Risiko | Gegenmittel |
|---|---|
| Motivation verpufft nach Wochen | Kleine, sichtbare Wochenziele; jeden Freitag ein GIF vom Fortschritt posten |
| Performance bricht bei vielen Einheiten ein | Von Anfang an mit 1000 Dummy-Einheiten testen, nicht erst am Ende |
| „Zuschauen wird langweilig" | Chroniken + Events sorgen dafür, dass immer etwas *erzählt* wird |
| Pixel-Art dauert ewig | Erst mit Platzhalter-Grafik bauen, Art in Phase 1 nachziehen |
| Vergleich mit WorldBox | Klare Abgrenzung: Individuen + Erinnerung + Konsequenzen statt reiner Sandbox |

---

## 9. Budget-Realität (Indie, quasi 0 €)

- Engine, Git, Sound-Bibliotheken: **kostenlos**
- Pixelorama statt Aseprite: **kostenlos** (Aseprite ~20 € wäre die einzige lohnende Investition)
- Steam-Release später: einmalig 100 $ Steam-Direct-Gebühr (verrechnet sich mit Verkäufen)
- itch.io-Release: **kostenlos** → perfekt für die ersten öffentlichen Versionen

---

## 10. Erster konkreter Schritt (heute machbar)

1. Godot 4 herunterladen (läuft auch auf schwächeren Laptops gut)
2. Neues Projekt „terraria-mundi", GitHub-Repo anlegen
3. Eine TileMapLayer mit 3 Farben (Gras/Wasser/Sand) + Maus-Malen implementieren
4. Screenshot machen. **Das ist Tag 1 der Weltgeschichte.** 🌍

---

*„Große Spiele entstehen nicht aus großen Plänen, sondern aus kleinen Schritten, die man wirklich geht."*
