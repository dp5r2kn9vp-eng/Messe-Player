# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach [SemVer](https://semver.org/lang/de/).

## [Unreleased]

### Geändert
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

[Unreleased]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/dp5r2kn9vp-eng/Messe-Player/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/dp5r2kn9vp-eng/Messe-Player/releases/tag/v1.0.0
