# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach [SemVer](https://semver.org/lang/de/).

## [Unreleased]

### Hinzugefügt
- Cue-Liste als Hauptansicht mit den Spalten Status, Nr., Name, Ausgang, Warten, Dauer, Danach und Restzeit; Spalten per Rechtsklick auf die Kopfzeile oder über das Spalten-Menü ein- und ausblendbar.
- Bearbeiten direkt in der Zeile: Nummer (z. B. „1.5“), Name, Ausgang und Danach als Auswahl, Warten und Dauer im Format `m:ss.cc` (Eingabe `42`, `1:05` oder `0:42.3`). Bei Mehrfachauswahl gelten Ausgang, Warten, Dauer und Danach für alle markierten Cues.
- Gruppenklammer: „Gruppe bilden“ (⌘G) aus zusammenhängenden Cues, „Gruppe auflösen“ (⇧⌘G); Kopfzeile mit Name, Loop ∞ oder n-mal, Überblendung, Ausgang, Σ Dauer und Zuklappen.
- Medien per Drag & Drop (aus dem Medienbereich über das Vorschaubild oder aus dem Finder) in die Liste ziehen erzeugt Cues: Bilder 5 s, Videos in voller Länge. Zeilen sind per Drag sortierbar, Cue-Nummern bleiben dabei erhalten.

- Cue-Engine: GO startet den Cue am Abspielkopf (▷) samt Kette „Mit nächstem starten“; Warten (⏳), Dauer, Danach (Halten, Weiter nach Ende, Mit nächstem starten), Gruppen mit Loop ∞ oder n-mal, Überblendung der Gruppe. Ein Video mit „Halten“ geht am Ende auf Schwarz. Fehlt ein Medium, wird der Cue übersprungen bzw. in der Transportleiste gemeldet.
- Transportleiste unten: GO, „Als Nächstes“, Pause/Fortsetzen, Stopp alle (Abspielkopf bleibt) und Black. Klick auf eine Zeile setzt den Abspielkopf, Doppelklick startet den Cue sofort.
- Mehrere Ausgänge: Unter „Ausgänge …“ Ausgänge anlegen, umbenennen und entfernen und auf diesem Rechner Bildschirmen zuordnen (gespeichert je Rechner, nicht im Projekt). Je Ausgang ein eigenes Vollbildfenster; ein neuer Cue ersetzt nur den Inhalt seines Ausgangs.
- Beim ersten Öffnen eines Projekts mit mehreren Ausgängen schlägt CueView eine Zuordnung vor und zeigt den Dialog zur Prüfung; „Bildschirme kennzeichnen“ blendet auf jedem Bildschirm den Ausgangsnamen ein.
- Ausgangsleiste über dem Transport: Bildschirm je Ausgang, Black je Ausgang (⇧B für den Ausgang des Cues am Abspielkopf). Ausgänge ohne Bildschirm oder mit abgestecktem Bildschirm laufen als Vorschau im Steuerfenster weiter, mit Warnhinweis. Warnung, wenn mehr als drei Videos gleichzeitig laufen.
- Inspektor rechts (ein-/ausklappbar über die Kopfzeile) mit sechs Reitern für die markierten Cues: Allgemein (Nummer, Name, Notiz, Farbe, Medium ersetzen oder neu verknüpfen), Zeit & Ablauf (Warten, Dauer, Danach, Blende ein/aus), Ausgang & Bild (Ausgang, Skalierung Einpassen/Füllen, Überblendung der Gruppe), Audio, Trim und Texte & Ebenen (bisheriger Ebenen-Editor). Nicht zutreffende Reiter sind ausgegraut; bei Mehrfachauswahl gelten Änderungen für alle markierten Cues.
- Lautstärke je Cue 0–100 % (Standard 100 %), Fade ein/aus als lineare Rampe und Stumm; wirkt bei Videos mit Ton sofort, auch während sie laufen.
- Audio-Cues: Audiodateien (wav, aiff, mp3, m4a …) lassen sich importieren und als Cue ohne Ausgang in die Liste ziehen. Sie laufen über die Systemausgabe parallel zu Bildern, enden mit der Datei und folgen Lautstärke, Fades, Pause/Fortsetzen und „Mit nächstem starten“ (gemeinsam gestartete Audio-Cues laufen synchron). „Stopp alle“ blendet Audio in 0,2 s aus, der Notfall-Stopp ⌘. schneidet hart.
- Trim-Editor im Inspektor-Reiter „Trim“: Filmstreifen (Video) bzw. Wellenform (Audio), einmal berechnet und gecacht; In-/Out-Punkt per Griff oder Eingabe (`m:ss.cc`), „Setzen auf Kopf“, Abspielkopf per Klick im Streifen, Zurücksetzen. Dauer = Out − In in Liste und Inspektor; Kürzen der Dauer setzt den Out-Punkt. „Vorhören“ spielt nur den getrimmten Bereich, Fade-Rampen sind als Dreiecke ziehbar. In der Show laufen Video- und Audio-Cues nur im getrimmten Bereich.
- Show-Zeitstrahl unter der Cue-Liste (Kopfzeile, Symbol „Zeitstrahl“): simuliert die Liste ab dem ersten Cue mit derselben Ablauflogik wie die Show und zeigt je Ausgang und Tonspur Warten (░), Dauer (━), stehende Bilder, Gruppen-Wiederholungen (⟲) und Halten bzw. offene Enden (→); Markierungen zeigen, wo ein GO nötig ist. Ein Klick auf einen Balken wählt den Cue (bzw. die Gruppe) in der Liste; Änderungen in der Liste wirken sofort.
- Messe-Modus (Menü Wiedergabe oder Schloss in der Kopfzeile, ⇧⌘M): Cue-Liste gesperrt (Klick setzt nur den Abspielkopf, Doppelklick startet), Medienbereich, Inspektor, Zeitstrahl und Pause ausgeblendet; sichtbar bleiben GO, „Als Nächstes“, Stopp alle und Black.
- Menü „Wiedergabe“ mit GO, Pause/Fortsetzen, Stopp alle, Black alle, Notfall-Stopp (⌘.) und Messe-Modus.
- Einmaliger Hinweis in der Transportleiste auf die geänderten Tasten (Leertaste/P).
- Hilfe und Tastenkürzel-Übersicht neu für den Cue-Player: Cue-Liste, Gruppen, Ausgänge, Audio, Trim, Zeitstrahl, Wiedergabe und Messe-Modus (neun Themen).

### Geändert
- **Tastenbelegung:** Leertaste = GO, P = Pause/Fortsetzen (bisher Leertaste). B (jetzt „Black alle“), Esc und ⌘. (Notfall-Stopp) wie bisher. Die Tasten 1–9 zum Starten von Gruppen entfallen.
- Doppelklick im Medienbereich legt einen Cue an (statt das Medium direkt auf dem Ausgang zu zeigen).
- Die Gruppen-Ansicht entfällt; der Medienbereich links ist über die Kopfzeile ein- und ausklappbar.
- Projektformat 2 (Cue-Liste): Gruppen und Einträge werden beim Öffnen verlustfrei in nummerierte Cues mit Loop-Gruppen auf Ausgang 1 umgewandelt. Beim Öffnen eines alten Projekts erscheint ein Hinweis; beim Speichern bleibt `project.v1.json` als Sicherung im Paket. Ältere CueView-Versionen können umgestellte Projekte nicht mehr öffnen.
- Neue Bilder in Gruppen stehen standardmäßig 5 statt 8 Sekunden.
- Die Bildschirmauswahl in der Kopfzeile wird durch „Ausgänge …“ ersetzt; der bisher gewählte Bildschirm wird für Ausgang 1 übernommen.

## [1.2.0] – 2026-11-13

### Hinzugefügt
- Über CueView: Icon, Wortmarke, Version, Copyright und Website.
- Hilfe (⌘?): Handbuch mit sieben Themen von „Erste Schritte“ bis „Checkliste Messe-Aufbau“, dazu die Tastenkürzel.
- Tastenkürzel-Übersicht (⌘/) im Hilfe-Menü.
- Willkommensfenster beim Start ohne offenes Projekt: Neues Projekt, Öffnen, Zuletzt geöffnet, Beispielprojekt, Hilfe.
- Beispielprojekt „CueView Beispiel“ mit Gruppe, Logo, Texten und Animationen.

### Geändert
- Kopfzeile: CueView-Icon und Wortmarke.
- Die Software heißt jetzt **CueView**: eigenes App-Icon (Bildschirm mit Play und KlangNIVEAU-Schwung), Wortmarke in der Kopfzeile, App-Datei `CueView.app`. Einstellungen und zuletzt geöffnetes Projekt bleiben erhalten.

## [1.1.1] – 2026-11-13

### Hinzugefügt
- Notfall-Stopp: Menü „Wiedergabe → Wiedergabe beenden“ mit ⌘. (Cmd+Punkt) beendet die Wiedergabe jederzeit.

### Geändert
- Esc beendet die Wiedergabe nur noch, wenn der Ausgang auf dem Bildschirm des Steuerfensters liegt (nur ein Bildschirm). Mit externem Bildschirm hat Esc keine Wirkung auf die Wiedergabe.

## [1.1.0] – 2026-11-13

### Hinzugefügt
- Ebenen-Animationen für Text, Bild und Logo: Erscheinen (Einblenden, von unten/oben/links/rechts, Zoom, Schreibmaschine), Verzögerung, Dauer, Dauereffekt Blinken oder Pulsieren, optional wieder ausblenden. Startet mit jedem Loop-Eintrag neu; im Editor per „Animation ansehen“ prüfbar.
- Editor: „Bild aus Datei …“ legt ein Bild direkt als Ebene an (wird dabei in die Bibliothek übernommen).

## [1.0.1] – 2026-11-13

### Hinzugefügt
- Mehrfachauswahl in Gruppen: Bei mehreren ausgewählten Einträgen erscheint im Gruppenkopf ein Dauerfeld für alle; auch eine Dauer-Änderung direkt an einem der ausgewählten Einträge gilt für alle ausgewählten Bilder.

## [1.0.0] – 2026-11-13

### Hinzugefügt
- Grundgerüst der App: Steuerfenster, Ausgabefenster auf externem Bildschirm (rahmenlos, ohne Mauszeiger), Bildschirmauswahl, Black-Button (auch Taste B), KlangNIVEAU-Farb-Tokens.
- Projektformat `.klangshow`: ein Paket mit `project.json` und allen Medien im Ordner `Media/` – im Finder eine Datei, auf andere Macs kopierbar. Projekte aus neueren App-Versionen werden mit klarer Meldung abgelehnt.
- Medienbibliothek: Bilder und Videos per Drag & Drop aus dem Finder oder über + hinzufügen, Vorschaubilder, Reihenfolge per Drag & Drop, Entfernen per Löschtaste oder Kontextmenü. Nicht unterstützte Dateien werden gemeldet.
- Einzelanzeige: Doppelklick oder Return auf ein Medium zeigt es dauerhaft auf dem Ausgang (Videos in nahtloser Endlosschleife); das laufende Medium ist orange markiert. Black bleibt dabei aktiv.
- Gruppen: anlegen, umbenennen, sortieren, löschen. Einträge aus der Bibliothek hinzufügen (auch mehrfach) oder Dateien direkt aus dem Finder in eine Gruppe ziehen, Reihenfolge per Drag & Drop, Standdauer pro Bild (1–3600 s, Standard 8 s).
- Loop-Engine: Gruppe starten/stoppen, Doppelklick startet ab einem Eintrag. Bilder stehen ihre Dauer, Videos laufen komplett, danach 1 s Schwarz. Überblendung pro Gruppe einstellbar (0 = harter Schnitt), nächstes Bild wird vorgeladen, defekte Medien werden übersprungen. Änderungen an der laufenden Gruppe wirken sofort.
- Ebenen: Text- und Bild-Ebenen pro Eintrag werden über Bild und Video gezeichnet – Position und Größe relativ zum Bildschirm, Schrift, Größe, Farbe, Ausrichtung, Schatten und hinterlegte Box. Textänderungen am laufenden Eintrag erscheinen sofort.
- Ebenen-Editor: große 16:9-Vorschau, Ebenen mit der Maus verschieben, Text, Schrift, Größe, Fett, Farbe, Ausrichtung, Schatten, Box und Breite einstellen, Bilder aus der Bibliothek als Ebene (z. B. Logo). Vorschau-Videos laufen stumm.
- Restzeit-Balken: Am laufenden Eintrag zeigt ein oranger Balken mit „noch x s“, wie lange das Bild bzw. Video noch auf dem Ausgang steht.
- Ausgang: Auswahl zeigt nur die angeschlossenen Bildschirme, der Ausgang läuft dort immer im Vollbild (Testfenster entfällt). Liegt er auf dem Bildschirm des Steuerfensters, erscheint er erst beim Start. Esc beendet Loop oder Einzelanzeige.
- KlangNIVEAU-Branding: App-Icon aus dem Logo, Logo in der Kopfzeile, Ruhebild des Ausgangs (Logo auf Dunkel) und fertige Logo-Ebene im Editor.
- Ablage → „Projekt als Zip exportieren …“ / „Projekt aus Zip importieren …“: komplettes Projekt inkl. Medien weitergeben oder sichern. Import prüft das Archiv, überschreibt nichts und öffnet das Projekt direkt.
- Messe-Absicherung: Mac und Bildschirm gehen nicht in den Ruhezustand, solange die App läuft. Beim Start werden letztes Projekt, Ausgabezustand (Loop, Einzelanzeige, Black) und Ausgabe-Bildschirm wiederhergestellt. Tastenkürzel: B Black, Leertaste Pause/Weiter, Esc Stopp, 1–9 Gruppe starten. Pause-/Weiter-Knopf im Gruppenkopf.

### Behoben
- Ältere Projektdateien mit Gruppen ließen sich nach Einführung der Ebenen nicht mehr öffnen.
- Steuerfenster füllte die Fensterbreite nicht vollständig.

### Hinzugefügt
- Styleguide, Architektur-Dokumentation und Agent-Regeln.

### Geändert

### Behoben

[Unreleased]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/dp5r2kn9vp-eng/Messe-Player/releases/tag/v1.0.0
