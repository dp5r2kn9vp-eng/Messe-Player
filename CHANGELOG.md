# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung nach [SemVer](https://semver.org/lang/de/).

## [Unreleased]

### Hinzugefügt
- Grundgerüst der App: Steuerfenster, Ausgabefenster auf externem Bildschirm (rahmenlos, ohne Mauszeiger) oder als Testfenster, Bildschirmauswahl, Black-Button (auch Taste B), KlangNIVEAU-Farb-Tokens.
- Projektformat `.klangshow`: ein Paket mit `project.json` und allen Medien im Ordner `Media/` – im Finder eine Datei, auf andere Macs kopierbar. Projekte aus neueren App-Versionen werden mit klarer Meldung abgelehnt.
- Medienbibliothek: Bilder und Videos per Drag & Drop aus dem Finder oder über + hinzufügen, Vorschaubilder, Reihenfolge per Drag & Drop, Entfernen per Löschtaste oder Kontextmenü. Nicht unterstützte Dateien werden gemeldet.
- Einzelanzeige: Doppelklick oder Return auf ein Medium zeigt es dauerhaft auf dem Ausgang (Videos in nahtloser Endlosschleife); das laufende Medium ist orange markiert. Black bleibt dabei aktiv.
- Gruppen: anlegen, umbenennen, sortieren, löschen. Einträge aus der Bibliothek hinzufügen (auch mehrfach) oder Dateien direkt aus dem Finder in eine Gruppe ziehen, Reihenfolge per Drag & Drop, Standdauer pro Bild (1–3600 s, Standard 8 s).
- Loop-Engine: Gruppe starten/stoppen, Doppelklick startet ab einem Eintrag. Bilder stehen ihre Dauer, Videos laufen komplett, danach 1 s Schwarz. Überblendung pro Gruppe einstellbar (0 = harter Schnitt), nächstes Bild wird vorgeladen, defekte Medien werden übersprungen. Änderungen an der laufenden Gruppe wirken sofort.
- Ebenen: Text- und Bild-Ebenen pro Eintrag werden über Bild und Video gezeichnet – Position und Größe relativ zum Bildschirm, Schrift, Größe, Farbe, Ausrichtung, Schatten und hinterlegte Box. Textänderungen am laufenden Eintrag erscheinen sofort.
- Ebenen-Editor: große 16:9-Vorschau, Ebenen mit der Maus verschieben, Text, Schrift, Größe, Fett, Farbe, Ausrichtung, Schatten, Box und Breite einstellen, Bilder aus der Bibliothek als Ebene (z. B. Logo). Vorschau-Videos laufen stumm.
- Restzeit-Balken: Am laufenden Eintrag zeigt ein oranger Balken mit „noch x s“, wie lange das Bild bzw. Video noch auf dem Ausgang steht.

### Behoben
- Ältere Projektdateien mit Gruppen ließen sich nach Einführung der Ebenen nicht mehr öffnen.
- Steuerfenster füllte die Fensterbreite nicht vollständig.

### Hinzugefügt
- Styleguide, Architektur-Dokumentation und Agent-Regeln.

### Geändert

### Behoben
