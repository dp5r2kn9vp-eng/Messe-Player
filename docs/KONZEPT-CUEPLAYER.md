# Konzept: CueView als Cue-Player

Status: Entwurf zur Abstimmung · Zielversion: Schema 2 · Autor: Planungs-Agent

## 1 Ziel & Leitbild

CueView wird von einem Loop-Player (Gruppen mit Einträgen) zu einem **Cue-Player**: Eine komplette Messe-Show ist eine **Cue-Liste**, die per GO Zeile für Zeile abläuft, auf mehreren Bildschirmen gleichzeitig laufen kann und Bilder, Videos und Audio kennt.

Leitbild:
- **Eine Liste zeigt alles.** Was als Nächstes passiert, steht oben im Blick; jede Zeile ist direkt in der Liste bearbeitbar.
- **Einfach bleibt einfach.** Ein Loop aus Bildern ist weiter in wenigen Klicks gebaut (Cues markieren, „Gruppe bilden“, Loop). Die Defaults entsprechen dem heutigen Verhalten.
- **Verlässlich auf der Messe.** Notfall-Stopp, Black, Restzeit-Anzeige und Offline-Betrieb bleiben erhalten; die Engine ist ohne UI testbar.
- **Wiederverwendung** der vorhandenen Bausteine (Abschnitt 9), kein Neubau des Renderers.

Nutzerwünsche (Kurzfassung): Playlist-Ansicht, Gruppenklammer mit Loop, Inspektor, Ausgang je Inhalt, Spalten Warten/Dauer/Danach, „automatisch weiter“, Audio-Lautstärke, Audio-Dateien, Trimmen mit Zeitstrahl, komplette Cue-Show.

## 2 Begriffe

| Begriff | Bedeutung | Heute |
|---|---|---|
| **Cue** | Eine Zeile der Cue-Liste: ein Ereignis mit Nummer, Medium (optional), Ausgang, Zeiten, Folgeaktion | `Entry` |
| **Cue-Liste** | Geordnete Liste aller Cues der Show (genau eine pro Projekt) | Summe aller `MediaGroup` |
| **Medien** | Dateipool des Projekts (Bild, Video, Audio); Cues verweisen darauf | Medienbibliothek |
| **Gruppe** | Klammer um zusammenhängende Cues; hat Modus Loop/n-mal und Überblendung | `MediaGroup` |
| **Ausgang** | Logischer Bildausgang („Ausgang 1“, „Ausgang 2“), pro Rechner einem Bildschirm zugeordnet | Ausgabe-Bildschirm |
| **Abspielkopf** | Markierung des Cues, den das nächste GO startet („Als Nächstes“) | neu |
| **Warten** | Verzögerung vom Start des Cues bis zum Erscheinen des Inhalts | neu |
| **Dauer** | Wie lange der Inhalt läuft/steht (Bild 5 s, Video = Länge bzw. getrimmte Länge) | `imageDuration` |
| **Danach** (Folgeaktion) | Was nach dem Cue passiert, siehe 4.2 | neu |
| **Trim** | In-/Out-Punkt eines Video-/Audio-Cues | neu |

Nummer ist ein String („1“, „1.5“), damit Cues später eingefügt werden können, ohne umzunummerieren.

## 3 Bedienkonzept mit Mockups

### 3.1 Hauptfenster (Cue-Liste)

Links Medienbereich (einklappbar), Mitte Cue-Liste, rechts Inspektor (einklappbar), unten Transportleiste.

```
┌─ CueView · Messe2027.klangshow ──────────────────────────────────────────────────────────────┐
│ MEDIEN            │ CUE-LISTE                                         [+ Cue] [Gruppe bilden]│
│ ┌───────────────┐ │ St  Nr.  Name            Ausg.  Warten  Dauer   Danach           Restzeit│
│ │▣ logo.png     │ │ ▶   1    Begrüßung        A1    0:00.00 0:05.00 Halten                  │
│ │▣ intro.mov    │ │ ▷   2    Intro-Film       A1    0:00.00 0:42.30 Weiter nach Ende ███░░ 0:18│
│ │♪ musik.wav    │ │ ┌ GRUPPE „Standloop“  ⟲ Loop ∞   Überbl. 0,5 s   A1      Σ 0:25.00  [▾]│
│ │▣ produkt1.jpg │ │ │ 3  Produkt 1            A1    0:00.00 0:05.00 Weiter nach Ende       │
│ │▣ produkt2.jpg │ │ │ 4  Produkt 2            A1    0:00.00 0:05.00 Weiter nach Ende       │
│ │▣ produkt3.jpg │ │ └ 5  Produkt 3            A1    0:00.00 0:05.00 Weiter nach Ende       │
│ │               │ │   6  Hintergrundmusik ♪   –     0:00.00 3:12.00 Mit nächstem starten   │
│ │ [+ Medien]    │ │   7  Monitor links        A2    0:02.00 0:30.00 Halten                  │
│ └───────────────┘ │                                                                          │
├───────────────────┴──────────────────────────────────────────────────────────────────────────┤
│ [ GO ]  Als Nächstes: 2 „Intro-Film“ (A1)   [Stopp alle] [Pause] [Black A1] [Black A2] [Black alle]│
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

Elemente:
- **Status-Spalte (St):** ▶ läuft, ⏸ pausiert, ▷ Abspielkopf („Als Nächstes“), ⏳ wartet, ⚠ Medium fehlt.
- **Restzeit-Balken** je laufendem Cue (Wiederverwendung `StepProgressBar`/`StepProgress`); mehrere Cues können gleichzeitig laufen.
- **Gruppenklammer:** Cues einer Gruppe sind links durch eine Klammer (┌ │ └) verbunden und leicht eingerückt. Die **Gruppenkopfzeile** trägt Name, Modus (Loop ∞ / n-mal), Überblendung, Ausgang und die Summe der Dauern; ▾ klappt die Gruppe zu (dann nur eine Zeile). Auswahl mehrerer Cues → „Gruppe bilden“ (⌘G), „Gruppe auflösen“ (⇧⌘G).
- **Bearbeiten in der Zeile:** Doppelklick bzw. Tab in eine Zelle; Warten/Dauer über `DurationField`, Ausgang/Danach als Popup. Mehrfachauswahl setzt Werte für alle markierten Cues.
- **Drag & Drop:** Medien aus dem Medienbereich in die Liste erzeugt Cues (Bild: Dauer 5 s, Video/Audio: Länge); Zeilen sortierbar (`ReorderableList`).
- **Spalten** sind ein-/ausblendbar (Standard: alle sieben sichtbar), damit der Messe-Modus (Abschnitt 12, Frage 6) sie reduzieren kann.

### 3.2 Inspektor (rechts, für die Auswahl)

Reiter: Allgemein · Zeit & Ablauf · Ausgang & Bild · Audio · Trim · Texte & Ebenen. Nicht zutreffende Reiter sind ausgegraut (z. B. Bild bei Audio-Cue, Trim bei Bild).

```
┌ INSPEKTOR · Cue 2 „Intro-Film“ ────────┐
│ [Allgemein][Zeit][Ausgang][Audio][Trim][Ebenen]
│ ───────────────────────────────────────│
│ Zeit & Ablauf                          │
│  Warten        [ 0:00.00 ]             │
│  Dauer         [ 0:42.30 ]  (aus Trim) │
│  Danach        [ Weiter nach Ende  ▾ ] │
│  Blende ein    [ 0:00.50 ]             │
│  Blende aus    [ 0:00.50 ]             │
│ ───────────────────────────────────────│
│ Audio                                  │
│  Lautstärke    ──────●───── 40 %       │
│  Fade ein/aus  [0:01.00] [0:02.00]     │
│ ───────────────────────────────────────│
│ Ausgang & Bild                         │
│  Ausgang       [ Ausgang 1 (Hauptbild.) ▾ ]
│  Skalierung    [ Füllen ▾ ]            │
└────────────────────────────────────────┘
```

Reiter-Inhalte:
- **Allgemein:** Nummer, Name, Notiz, Farbe, Medium (ersetzen/relinken).
- **Zeit & Ablauf:** Warten, Dauer (bei Bild frei, bei Video/Audio abgeleitet aus Trim, überschreibbar nur kürzer), Danach, Blenden.
- **Ausgang & Bild:** Ausgang, Skalierung, Überblendung.
- **Audio:** Lautstärke 0–100 %, Fade ein/aus, Stumm; später Audio-Ausgabegerät.
- **Trim:** Trim-Editor (3.3).
- **Texte & Ebenen:** bestehender Ebenen-Editor mit Animationen (`LayerEditorView`, `LayerInspector`), unverändert, nur am Cue statt am Entry.

### 3.3 Trim-Editor (Reiter „Trim“)

```
┌ Trim · intro.mov · Original 1:12.40 ──────────────────────────────┐
│ ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐     │
│ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │ ▓▓ │  Filmstreifen
│ └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘     │
│ ░░░░░░[▌━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━▐]░░░░░░░░░░░░░░░░░     │
│       In 0:05.20            ▲ Kopf 0:20.00        Out 0:47.50      │
│ Audio: ╱╲╱╲╱╲╱╲╱╲  Wellenform (bei Audio-Cues statt Filmstreifen)   │
│ In [0:05.20] [Setzen auf Kopf]  Out [0:47.50] [Setzen auf Kopf]    │
│ Dauer = Out − In = 0:42.30     [▶ Vorhören]  [Zurücksetzen]        │
│ Fade-Rampen: ◢ ein 0:01.00          aus 0:02.00 ◣                  │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.4 Show-Zeitstrahl (spätere Phase)

Gantt-artige, schreibgeschützte Übersicht der simulierten Show; Klick auf einen Balken wählt den Cue in der Liste.

```
Zeit      0:00     0:10     0:20     0:30     0:40     0:50
A1  ─ [1 Begrüßung ][2 Intro-Film ━━━━━━━━━━━━━━━━][3·4·5 Standloop ⟲ →
A2  ─                 ·· 2 s ··[7 Monitor links ━━━━━━━━━━━━━━━━━━ →
Ton ─ [6 Hintergrundmusik ♪ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      ░ = Warten    ━ = Dauer    ⟲ = Loop    → = Halten (läuft offen)
```

## 4 Ablauflogik

### 4.1 Zeitmodell eines Cues

Beim Start (T0) eines Cues:
1. **Warten** läuft ab (Standard 0). Währenddessen ist der Cue „wartend“ (⏳); der Ausgang zeigt noch den alten Inhalt.
2. Danach erscheint der Inhalt (mit Blende ein bzw. Überblendung der Gruppe).
3. **Dauer** läuft: Bild Standard 5 s; Video/Audio = `outPoint − inPoint` (ohne Trim: volle Länge).
4. Am Dauerende greift **Danach**.

Zeiten sind relativ zum Start dieses Cues. Gesamtlänge = Warten + Dauer.

### 4.2 Folgeaktionen („Danach“)

| Wert | Verhalten | Gedanke |
|---|---|---|
| **Halten** (Standard) | Nach der Dauer endet der Cue. Bild bleibt stehen; Video geht am Ende auf Schwarz (Ausgang leer). Nächster Cue startet nur per GO. | wie heute bei Einzelanzeige; Messe: „bleibt, bis ich GO drücke“ |
| **Weiter nach Ende** (Auto-Follow) | Wenn dieser Cue (Warten + Dauer) fertig ist, startet der nächste Cue automatisch. Bild bleibt bis zum Eintreffen des nächsten Inhalts stehen (Überblendung); ein Video geht erst auf Schwarz, wenn kein Folgecue erscheint. | Diashow, Playlist |
| **Mit nächstem starten** (Auto-Continue) | Der nächste Cue startet sofort zusammen mit diesem (Start-Zeitpunkt T0, dessen eigenes Warten läuft parallel). Dieser Cue läuft für sich zu Ende; „Danach“ des nächsten Cues entscheidet über die Kette. | zwei Ausgänge gleichzeitig, Musik zum Bild |

Nutzerwunsch „ohne Auswahl bleiben Bilder stehen, Videos gehen auf Schwarz“ = Halten. Wunsch „automatisch weiter“ = Weiter nach Ende. „Mit nächstem starten“ ist Entwicklervorgabe für Parallelität.

Letzter Cue der Liste: „Weiter nach Ende“ wirkt wie Halten. Fehlendes Medium: Cue wird übersprungen (Auto-Follow) bzw. meldet Fehler, bei „Mit nächstem“ läuft der Rest weiter.

### 4.3 Beispielabläufe

| Beispiel | Cues | Ergebnis |
|---|---|---|
| Einzelbild halten | 1 Bild, Danach Halten | 5 s Dauer verstreichen, Bild bleibt stehen, nächster Cue erst bei GO |
| Video mit Schwarz | 1 Video, Halten | Video läuft, danach Schwarz auf Ausgang 1 |
| Diashow | 5 Bilder A1, alle „Weiter nach Ende“ | GO auf Cue 1, jede 5 s nächstes Bild, letztes bleibt stehen |
| Zwei Bildschirme | Cue 1 Bild A1 „Mit nächstem starten“, Cue 2 Video A2 | ein GO: A1 und A2 gleichzeitig |
| Verzögerter 2. Schirm | Cue 1 A1 „Mit nächstem“, Cue 2 A2 Warten 2 s | A2 erscheint 2 s nach GO |
| Musik zum Loop | Cue 1 Audio „Mit nächstem“, Gruppe Cue 2–4 Loop | Musik und Standloop starten zusammen; Musik endet nach Dauer, Loop läuft weiter |
| Loop-Gruppe | Gruppe 3–5 Loop ∞ | Cues 3, 4, 5, 3, 4, 5 … bis Stopp; „Danach“ der Mitglieder wird als „Weiter nach Ende“ behandelt (siehe Frage 4) |

### 4.4 Gruppen

- Eine Gruppe ist ein **zusammenhängender Bereich** der Cue-Liste (Start-Cue bis End-Cue), kein Container; Reihenfolge und Cue-Nummern bleiben unverändert.
- **Modus:** `Loop` (endlos) oder `Wiederholungen n` (1…99); danach greift „Danach“ des letzten Cues bzw. Halten.
- **Überblendung** (0–5 s, Standard 0,5 s wie `MediaGroup.crossfade`) zwischen den Cues der Gruppe.
- GO auf eine Gruppe (Abspielkopf auf Gruppenkopf oder einem Mitglied) startet beim ersten Mitglied, dann läuft die Kette automatisch (Mitglieder verhalten sich wie „Weiter nach Ende“).
- Im Loop-Modus ist der Cue-**Rücksprung** vom letzten auf den ersten Cue Teil der Engine, nicht der Liste.
- Gruppen sind nicht verschachtelbar (Phase 1); Gruppe über mehrere Ausgänge nicht erlaubt, sie hat genau einen Ausgang (Kopfzeile setzt ihn für alle Mitglieder).

### 4.5 Transport

| Aktion | Wirkung |
|---|---|
| **GO** | Startet den Cue am Abspielkopf; Abspielkopf springt auf den nächsten Cue (nach der Kette „Mit nächstem starten“ hinter den letzten mitgestarteten Cue) |
| **Stopp alle** | Beendet alle laufenden Cues und Loops, Ausgänge leer; Abspielkopf bleibt |
| **Pause / Fortsetzen** | Friert alle laufenden Cues samt Restzeit und Videos/Audio ein; Fortsetzen läuft weiter |
| **Black je Ausgang / global** | Schwarz über dem Inhalt, Cues laufen darunter weiter (wie heute) |
| **Notfall-Stopp ⌘.** | Bleibt: Stopp + Black global, sofort |
| **Abspielkopf setzen** | Klick auf Zeile, Pfeiltasten (↑/↓) bewegen den Kopf, ohne zu starten; Doppelklick = Cue sofort starten |

## 5 Mehrere Ausgänge

- `OutputDefinition`: logischer Ausgang (id, Name „Ausgang 1“, Farbe). Das **Projekt** kennt nur logische Ausgänge.
- **Zuordnung logisch → physisch** (`CGDirectDisplayID`/Name/UUID des Bildschirms) wird **pro Rechner** gespeichert (UserDefaults, nicht im `.klangshow`), damit ein Projekt auf anderem Rechner/anderer Bildschirmzahl sofort nutzbar bleibt. Nicht zugeordneter Ausgang: Fenster im Vorschau-Modus im Steuerfenster; Warnhinweis in der Transportleiste.
- Je Ausgang: ein Ausgabefenster (heute `OutputWindowController`, wird mehrfach instanziiert), eigener `OutputState` (Inhalt, Black), eigener Restzeit-Zustand.
- **Ersetzen:** Ein neuer Cue auf Ausgang X ersetzt den dort laufenden Bild-/Video-Cue (mit Überblendung); laufende Cues anderer Ausgänge bleiben unberührt. Audio-Cues belegen keinen Ausgang und laufen parallel.
- Standard für neue Cues: Ausgang 1. Mehrere Cues desselben Ausgangs können gleichzeitig „laufen“ nur, wenn einer wartet; der spätere ersetzt den früheren.
- Ebenen/Animationen gelten je Cue und werden im Fenster des Cue-Ausgangs gerendert (`FrameView`).
- Hotplug: Fehlt ein Bildschirm, wechselt der Ausgang in Vorschau, die Show läuft weiter (bestehende Bildschirmverwaltung in `System/`).

## 6 Audio

- **Lautstärke** je Cue 0–100 % (Standard 100 %), **Fade ein/aus** als lineare Rampe (Sekunden). Wirkt für Videos mit Ton und Audio-Cues.
- **Audio-Cues** (Medientyp `audio`: wav, aiff, mp3, m4a, …): Zeile ohne Ausgang, läuft parallel zu Bild-Cues, hat Wellenform im Trim-Reiter, Dauer = Trim-Länge.
- Umsetzung: `AVPlayer` je Audio-Cue bzw. Audiospur des Video-Players mit `volume` und Lautstärkerampe (`AVAudioMix`/`setVolumeRamp`). Gesamtlautstärke (Master) als Schieber in der Transportleiste (spätere Phase optional).
- **Audio-Ausgabegerät** (z. B. USB-Interface): später, pro Rechner gespeichert wie die Bildschirmzuordnung; Phase 1 = Systemausgabe.
- Pause friert Audio ein; Stopp mit kurzem Fade-out (z. B. 0,2 s), Notfall-Stopp hart.

## 7 Trim & Zeitstrahl

- **Trim:** `inPoint`/`outPoint` in Sekunden (Quelle). Dauer = `out − in`. Vorhören im Inspektor spielt nur den getrimmten Bereich. Die Dauer-Spalte zeigt den getrimmten Wert; manuelles Kürzen der Dauer setzt `outPoint` neu.
- **Filmstreifen:** Vorschaubilder via `AVAssetImageGenerator` (asynchron, gecacht, Wiederverwendung `ThumbnailService`). **Wellenform:** Peaks aus `AVAssetReader`, einmal berechnet und im Cache (nicht im Projektpaket).
- **Fades als Rampen** sind im Trim-Editor als Dreiecke sichtbar und ziehbar.
- **Zeitformat:** Eingabe/Anzeige `m:ss.cc` (Minuten:Sekunden.Hundertstel), z. B. `0:42.30`. Tolerante Eingabe: `42` = 42 s, `1:05` = 1 min 5 s, `0:42.3`. Intern immer `Double` Sekunden. Der Nutzerwunsch „0.00.00“ wird als dieses Format interpretiert (siehe Frage 1).
- **Show-Zeitstrahl** (Phase P8): Simulation der Liste ohne Ausgabe (Start-/Endzeiten aus Warten, Dauer, Folgeaktionen, Gruppen auf einen Durchlauf begrenzt), Darstellung wie 3.4; nur Ansicht, Bearbeitung weiter in der Liste. Cues mit „Halten“ erscheinen als offener Balken, da sie auf GO warten.

## 8 Datenmodell (Swift-Skizzen) & Migration v1 → v2

```swift
nonisolated struct Medium: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case image, video, audio }   // audio neu
    let id: UUID; let kind: Kind; let fileName: String; var displayName: String
}

nonisolated enum FollowAction: String, Codable {
    case hold          // Halten
    case followOnEnd   // Weiter nach Ende (Auto-Follow)
    case continueWithNext // Mit nächstem starten (Auto-Continue)
}

nonisolated struct Cue: Codable, Equatable, Identifiable {
    let id: UUID
    var number: String            // "1", "1.5"
    var name: String
    var mediumID: Medium.ID?      // nil = reiner Steuer-Cue (später: Black, Stopp)
    var outputID: OutputDefinition.ID?   // nil bei Audio
    var wait: TimeInterval = 0
    var inPoint: TimeInterval = 0
    var outPoint: TimeInterval?   // nil = bis Medienende
    var stillDuration: TimeInterval = 5   // nur Bilder
    var followAction: FollowAction = .hold
    var volume: Double = 1        // 0...1
    var fadeIn: TimeInterval = 0
    var fadeOut: TimeInterval = 0
    var layers: [Layer] = []      // unverändert, inkl. Animationen
    var notes: String = ""
    var color: RGBAColor?
    // Dauer ist abgeleitet: Bild stillDuration, sonst (outPoint ?? mediaLength) - inPoint
}

nonisolated struct CueGroup: Codable, Equatable, Identifiable {
    enum Mode: Codable, Equatable { case loop, repeatCount(Int) }
    let id: UUID
    var name: String
    var firstCueID: Cue.ID        // zusammenhängender Bereich
    var lastCueID: Cue.ID
    var mode: Mode = .loop
    var crossfade: TimeInterval = 0.5
    var isCollapsed = false
}

nonisolated struct OutputDefinition: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String              // "Ausgang 1"
    // KEINE Display-ID im Projekt; die liegt je Rechner in UserDefaults:
    // [OutputDefinition.ID: DisplayReference]
}

nonisolated struct Project: Codable, Equatable {
    static let currentSchemaVersion = 2
    var schemaVersion = 2
    var media: [Medium] = []
    var cues: [Cue] = []
    var groups: [CueGroup] = []
    var outputs: [OutputDefinition] = [.init(name: "Ausgang 1")]
}
```

Ableitung der Dauer und Validierung (Gruppen müssen zusammenhängen, Ausgang muss existieren) liegen in einer `nonisolated` Modell-Erweiterung mit Unit-Tests, wie bisher `Project`-Mutationen.

### Migration (`ProjectCodec.migrate`, Version 1 → 2)

| v1 | v2 |
|---|---|
| `MediaGroup` | `CueGroup` im Modus **Loop**, `crossfade` übernommen, Name übernommen |
| `Entry` je Gruppe, in Reihenfolge | `Cue`, Nummer fortlaufend 1…n über alle Gruppen |
| `Entry.imageDuration` | `stillDuration` (Bild); für Videos Dauer = Medienlänge |
| (Loop-Verhalten) | `followAction = .followOnEnd` für alle migrierten Cues |
| `Entry.layers` (inkl. Animationen) | `Cue.layers` unverändert |
| Ausgabe-Bildschirm (Projekt/Defaults) | Ausgang 1; Cues → `outputID` = Ausgang 1 |
| `wait`, `volume`, Fades, Trim | Standardwerte (0 / 1 / 0 / 0) |

Gruppen werden in der Cue-Liste hintereinander angeordnet. Eine Datei, die vorher in mehreren Gruppen vorkam, bleibt je Cue einzeln. Migration passiert beim Laden in `ProjectCodec` (JSON-Ebene, wie bisher), beim Speichern wird immer v2 geschrieben. **Ältere App-Versionen** können v2 nicht lesen: Beim Speichern eines v1-Projekts als v2 wird einmalig gewarnt und `project.v1.json` als Sicherung im Paket abgelegt (offene Frage in Abschnitt 10/Risiken). Tests: Fixture-v1-Projekt → erwartete v2-Struktur; Roundtrip; Codable-Defaults für fehlende Felder.

## 9 Architektur & Wiederverwendung

Neu bzw. umgebaut:
- `Core/Model`: `Cue`, `CueGroup`, `OutputDefinition`, `FollowAction`, Zeit-Formatierung (`TimeFormat`, `m:ss.cc`).
- `Playback/CueEngine` (Nachfolger von `OutputController`): hält je Ausgang einen `OutputController`-ähnlichen Zustand (`OutputChannel`), verwaltet laufende Cues (`RunningCue`: Start, Phase warten/läuft/beendet, `StepProgress`), Abspielkopf, GO, Folgeaktionen, Gruppen-Loop. Rein modellbasiert, Zeit über den injizierbaren `StepScheduler` und `now`-Closure, damit Unit-Tests ohne UI und Echtzeit laufen.
- `Playback/AudioCuePlayer`: `AVPlayer`-Wrapper für Audio und Lautstärke-Rampen.
- `Features/CueList` (Zeilen, Gruppenklammer, Kopfzeile), `Features/Inspector`, `Features/Trim`, `Features/Timeline`, `Features/Transport` (ersetzt `Features/Control` teilweise).
- `System/OutputRouting`: Zuordnung logischer Ausgang ↔ Bildschirm je Rechner.

Wiederverwendet (unverändert oder minimal angepasst):
- `FrameView`/`LayerView`/`AnimationClock`/`LayerRenderer`: EIN Renderer für Ausgabe und Vorschau, Ebenen/Animationen am Cue.
- `MediaStore` bleibt einziger Medienzugriff; neu nur `audio` als Kind.
- `StepScheduler`/`TaskStepScheduler`: Zeitgeber der Engine (mehrere gleichzeitige Schritte, ein Handle je Cue).
- `DurationField`: Basis für Warten/Dauer/Trim-Felder; erweitert auf `m:ss.cc` (Parser an einer Stelle).
- `ReorderableList`: Cue-Liste inklusive Mehrfachauswahl und Drag & Drop.
- `StepProgressBar`/`StepProgress`: Restzeit-Balken je Zeile.
- `ThumbnailService`: Filmstreifen.
- `Theme`: Farb-Tokens (kein Hex im Code), neue Tokens für Ausgangsfarben/Gruppenklammer.
- `ProjectCodec`/`ProjectPackage`: Migrationsrahmen und Paketformat unverändert (`Media/` + `project.json`).
- `OutputWindowController`: wird je Ausgang instanziiert (Manager-Klasse hält Dictionary).

Entfernt/ersetzt nach Abschluss: `Features/Groups` (durch `CueList`), `PlaybackCommands` (durch neue Belegung), `OutputController` (durch `CueEngine`). Architekturdokument (`ARCHITEKTUR.md`) und Zustandsautomat werden in P9 aktualisiert.

Hinweis zur Engine-Zustandsmaschine pro Cue: `Bereit → Wartet → Läuft → Beendet` (+ `Pausiert`, `Gestoppt`); Übergang `Beendet` löst Folgeaktion aus. Der Ausgangszustand ist unabhängig davon und enthält nur „was ist sichtbar“ (+ Black).

## 10 Risiken

| Risiko | Auswirkung | Gegenmaßnahme |
|---|---|---|
| **Gleichzeitige Videos** (Hardware-Decoder, Speicher) | Ruckeln bei 2× 4K | Messen früh in P4; Empfehlung/Hinweis zu H.264/HEVC 1080p; Vorladen begrenzen; Warnung bei zu vielen parallelen Videos |
| **Audio-Sync** (Bild + Ton verschiedene Player) | Lippen-Asynchronität, Versatz bei Pause | Start über gemeinsame `hostTime`/`setRate(_:time:atHostTime:)`; Pause/Fortsetzen über alle Player gleichzeitig; Toleranzmessung in Tests/Handtest |
| **Mehrbildschirm-Zuordnung zwischen Rechnern** | Falscher Schirm auf neuem Rechner | Zuordnung je Rechner, beim ersten Öffnen Dialog, Identifikations-Overlay („Ausgang 2“ je Bildschirm einblenden) |
| **Migration v1 → v2** | Datenverlust, Downgrade nicht möglich | Fixture-Tests, Sicherung `project.v1.json`, klare Warnung |
| **Komplexität der Bedienung auf der Messe** | Fehlbedienung unter Stress | Defaults wie heute, „einfacher Messe-Modus“ (nur GO/Stopp/Black, Liste gesperrt), Sicherheitsabfrage nur bei destruktiven Aktionen, Notfall-Stopp ⌘. |
| **Tastenbelegung ändert sich** (Leertaste) | Gewohnheit führt zu falschem Verhalten | Änderung im Changelog + Hilfe + einmaliger Hinweis; optional in Einstellungen umschaltbar |
| **Engine-Komplexität** (Warten, parallele Cues, Gruppen, Pause) | Fehler in Randfällen | Reine, testbare Engine mit Scheduler-Injektion; Tabelle aus 4.3 als Testfälle; Phasen klein halten |
| **Umfang** | zu großes Ticket | Phasen P1–P9, jedes eigenständig lieferbar |

## 11 Umsetzungsphasen

Jedes Paket = ein Ticket/PR (Größe S ≈ halber Tag, M ≈ 1–2 Tage, L ≈ 3+ Tage).

| Nr. | Paket | Ziel | Umfang | Abhängigkeiten | Größe |
|---|---|---|---|---|---|
| **P1** | Datenmodell + Migration + Tests | Schema 2, `Cue`, `CueGroup`, `OutputDefinition`, `FollowAction`, Medium `audio`, Zeitformat | Modell, `ProjectCodec.migrate` v1→v2, Fixtures, Unit-Tests; App nutzt vorerst Brücke (alte UI liest aus neuem Modell) | – | L |
| **P2** | Cue-Liste UI | Spalten (St, Nr., Name, Ausgang, Warten, Dauer, Danach, Restzeit), Bearbeiten in der Zeile, Gruppenklammer + Kopfzeile, Medienbereich als Quelle, Auswahl/„Gruppe bilden“ | `Features/CueList`, `DurationField` `m:ss.cc`, Drag & Drop | P1 | L |
| **P3** | Cue-Engine | GO, Abspielkopf, Warten, Dauer, Folgeaktionen, Gruppen-Loop, Pause, Stopp, Black (noch 1 Ausgang) | `CueEngine`, Unit-Tests mit Fake-Scheduler gemäß Tabelle 4.3, Anbindung an `FrameView` | P1 (P2 für Anzeige) | L |
| **P4** | Mehrere Ausgänge | Ausgänge definieren, Zuordnung je Rechner, je Ausgang Fenster/Zustand/Black, Ersetzen mit Überblendung, Identifikations-Overlay | `OutputRouting`, Mehrfach-`OutputWindowController`, Ausgangswahl in Liste | P3 | L |
| **P5** | Inspektor + Audio-Lautstärke/Fades | Rechte Leiste mit Reitern, Lautstärke 0–100 %, Fade ein/aus für Video | `Features/Inspector`, Anbindung `LayerEditor` als Reiter, Lautstärkerampen | P2, P3 | M |
| **P6** | Audio-Cues | Audiodateien importieren, Cue ohne Ausgang, parallel zu Bild | `AudioCuePlayer`, Import `audio`, Sync mit „Mit nächstem starten“ | P3, P5 | M |
| **P7** | Trim-Editor | In-/Out-Griffe, Filmstreifen, Wellenform, Vorhören, Dauer-Ableitung | `Features/Trim`, Peaks/Thumbnail-Cache | P5, P6 | L |
| **P8** | Show-Zeitstrahl | Gantt-Ansicht mit Warten/Dauer/Folgeaktionen, Klick-Navigation | `Features/Timeline`, Simulationsfunktion (UI-frei, getestet) | P3, P4 | M |
| **P9** | Tastenbelegung, Transportleiste, Hilfe/Doku | GO/Stopp/Pause/Black-Leiste, neue Tasten, `HelpContent`, `ARCHITEKTUR.md`, `CHANGELOG`, Release Notes | Transportleiste, Menü-Befehle, Doku | P2–P4 | M |

Reihenfolge: P1 → P2/P3 (parallel möglich, getrennt in Dateien) → P4 → P5 → P6 → P7 → P8 → P9 (P9 kann teilweise früh mit P2 starten). Nach P4 ist die App als Mehrbildschirm-Cue-Player brauchbar (erste Testversion), danach folgen Audio/Trim/Zeitstrahl.

### Tastenbelegung (Vorschlag, Änderung gegenüber heute)

| Taste | Heute | Neu |
|---|---|---|
| Leertaste | Pause/Fortsetzen | **GO** (Änderung) |
| P | – | **Pause/Fortsetzen** (Änderung) |
| B | Black | Black global; ⇧B Black des gewählten Ausgangs |
| Esc | Stopp nur, wenn ein Ausgang den Steuerbildschirm blockiert | unverändert (bewusst so festgelegt, siehe #38) |
| ⌘. | Notfall | unverändert, Notfall-Stopp |
| 1–9 | Gruppe/Eintrag starten | Ausgang 1–9 wählen für Black bzw. Cue-Ausgang in Auswahl (⌥1–9) – Vorschlag, siehe Frage 2 |
| ↑ / ↓ | – | Abspielkopf bewegen |
| ⌘G / ⇧⌘G | – | Gruppe bilden / auflösen |

## 12 Offene Fragen an den Nutzer

1. **Zeitformat „0.00.00“.** Vorschlag: `m:ss.cc` (z. B. `0:42.30`, Hundertstel), Eingabe tolerant (`42`, `1:05`). Passt das, oder soll es `h:mm:ss` (Stunden:Minuten:Sekunden) sein?
2. **Leertaste = GO.** Vorschlag: Leertaste startet den nächsten Cue (wie in Cue-Software), Pause wird `P`, Ziffern 1–9 wählen Ausgänge. Einverstanden, oder soll die Leertaste Pause bleiben und GO eine andere Taste (z. B. Return) bekommen?
3. **Gruppenkopf: endlos oder n-mal.** Vorschlag: Standard Loop endlos, alternativ „n-mal“ (1–99), danach Halten. Reicht das, oder braucht ihr „n-mal, dann weiter zum nächsten Cue“?
4. **„Danach“ innerhalb einer Loop-Gruppe.** Vorschlag: Innerhalb der Gruppe gilt automatisch „Weiter nach Ende“ (Einstellung wird ausgegraut); „Halten“ nur am Gruppenende nach den n Wiederholungen. Ist das gewünscht?
5. **Black je Ausgang oder global.** Vorschlag: Beides – Taste B = alle Ausgänge, Schaltfläche je Ausgang in der Transportleiste. Genügt global, oder soll Black je Ausgang Pflicht sein?
6. **Einfacher Messe-Modus.** Vorschlag: Umschalter, der nur Liste (gesperrt) + GO/Stopp/Black zeigt und Inspektor/Medienbereich ausblendet. Braucht ihr das schon in P9 oder erst später?
7. **Audio-Ausgabegerät.** Vorschlag: zunächst nur Systemausgabe; Geräteauswahl je Rechner erst nach P6 bei Bedarf. Nutzt ihr ein externes Audio-Interface auf der Messe, das gezielt angesprochen werden muss?
8. **Nummerierung der Cues.** Vorschlag: automatisch fortlaufend (1, 2, 3 …), manuell überschreibbar (z. B. „1.5“ zum Einfügen); beim Verschieben bleibt die Nummer erhalten. Oder immer automatisch neu durchnummerieren?
