# Cue-Liste

Die Cue-Liste ist die Hauptansicht. Jede Zeile ist ein Cue, und die Show läuft von oben nach unten.

## Spalten

Die Spalten sind Status, Nr., Name, Ausgang, Warten, Dauer, Danach und Restzeit. Blende Spalten per Rechtsklick auf die Kopfzeile oder über das Spalten-Menü ein oder aus.

## Bearbeiten in der Zeile

- Nummer, Name, Ausgang und Danach änderst du direkt in der Zeile.
- Warten und Dauer gibst du als Sekunden oder als m:ss.cc ein, zum Beispiel 42, 1:05 oder 0:42.3.
- Bei mehreren markierten Cues gelten Ausgang, Warten, Dauer und Danach für alle.

## Danach

- Halten: Der Cue bleibt am Ende stehen. Ein Video geht am Ende auf Schwarz.
- Weiter nach Ende: Der nächste Cue startet, wenn dieser fertig ist.
- Mit nächstem starten: Der nächste Cue startet zusammen mit diesem.
- Nachwarten: Bei „Mit nächstem starten“ startet der nächste Cue erst so viele Sekunden nach diesem. Die Spalte „Nachw.“ blendest du über das Spalten-Menü ein, im Inspektor steht sie unter „Zeit & Ablauf“.

## Gruppen & Loop

- Markiere zusammenhängende Cues und drücke **⌘G**, um eine Gruppe zu bilden. **⇧⌘G** löst sie wieder auf.
- Die Gruppenzeile zeigt Name, Loop (∞ oder n-mal), Zufall, Überblendung, Ausgang und die Summe der Dauer.
- Mit dem Zufall-Symbol laufen die Cues der Gruppe in zufälliger Reihenfolge. Jeder Durchlauf zeigt jeden Cue einmal, und kein Cue kommt direkt zweimal hintereinander.

## Abspielkopf

- Der Abspielkopf (▷) zeigt den Cue, den GO als Nächstes startet.
- Mit ↑ und ↓ bewegst du den Abspielkopf, ohne zu starten.
- Ein Doppelklick oder Return startet einen Cue sofort.
