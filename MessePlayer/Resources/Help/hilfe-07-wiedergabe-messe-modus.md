# Wiedergabe & Messe-Modus

## Transportleiste

Unten steuerst du die Show: GO, „Als Nächstes“ (der Cue am Abspielkopf), Pause/Fortsetzen, Stopp alle und Black alle.

- GO startet den Cue am Abspielkopf.
- Stopp alle beendet die Wiedergabe. Der Abspielkopf bleibt stehen.
- Black alle schaltet alle Ausgänge auf Schwarz. Ein weiterer Druck zeigt wieder das Bild.
- „Loop beenden“ erscheint, solange eine Gruppe läuft. Es trifft die Gruppe am Abspielkopf, sonst alle laufenden Gruppen. Mit ⌥-Klick endet sie schon nach dem laufenden Cue. Die Gruppenzeile zeigt „endet nach Durchlauf“.

## Menü Wiedergabe

Das Menü Wiedergabe enthält GO, Pause/Fortsetzen, Loop beenden, Stopp alle, Black alle, Notfall-Stopp (⌘.), Messe-Modus und Zeitplan aktiv.

## Tasten

- **Leertaste**: GO
- **P**: Pause oder Fortsetzen
- **L**: Loop beenden – der laufende Durchlauf spielt zu Ende, danach gilt „Danach“ des letzten Cues der Gruppe
- **⇧L**: Loop nach dem laufenden Cue beenden
- **B**: Black alle
- **⇧B**: Black des Ausgangs vom Cue am Abspielkopf
- **⌘.**: Notfall-Stopp, wirkt immer
- **Esc**: Stoppt nur, wenn ein Ausgang auf dem Bildschirm des Steuerfensters liegt

Die Tasten wirken nicht, solange ein Textfeld aktiv ist.

## Messe-Modus

Schalte den Messe-Modus über das Menü Wiedergabe mit „Messe-Modus“ (⇧⌘M) oder das Schloss-Symbol in der Kopfzeile ein. Zum Verlassen nimmst du denselben Weg.

- Die Cue-Liste ist gesperrt. Ein Klick setzt nur den Abspielkopf, ein Doppelklick startet den Cue.
- Bearbeiten, Sortieren, Löschen und Drag & Drop sind aus.
- Medienbereich, Inspektor, Zeitstrahl und die Pause-Schaltfläche sind ausgeblendet.

## Start nach Uhrzeit

Ein Cue kann zu einer festen Uhrzeit starten, zum Beispiel täglich um 14:00 die Präsentation. Stelle das im Inspektor unter „Zeit & Ablauf“ ein: „Startet um Uhrzeit“, die Uhrzeit und optional die Wochentage. Ohne Auswahl gilt die Zeit täglich. In der Cue-Liste zeigt ein Uhr-Symbol solche Cues.

- Der Start wirkt wie GO auf diesen Cue. Er ersetzt den Inhalt seines Ausgangs, zum Beispiel einen Standloop. Andere Ausgänge und Ton laufen weiter.
- Der Zeitplan gilt im Messe-Modus oder mit „Zeitplan aktiv“ im Menü Wiedergabe.
- Die Transportleiste zeigt den nächsten geplanten Start.
- Eine verpasste Zeit wird nicht nachgeholt, zum Beispiel wenn CueView erst danach gestartet wurde.
- Während einer Pause entfällt der Start. Die Transportleiste meldet das. Nach „Stopp alle“ bleibt der Zeitplan aktiv.

## Hinweis beim ersten Start

Beim ersten Start zeigt die Transportleiste einmal einen Hinweis auf die geänderten Tasten Leertaste und P.
