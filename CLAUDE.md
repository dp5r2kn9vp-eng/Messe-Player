# Messe-Player – Regeln für alle Agents

Native macOS-App (Swift, SwiftUI + AVFoundation, macOS 26, Xcode 26.6) für KlangNIVEAU Veranstaltungstechnik. Details: `docs/STYLEGUIDE.md` (Code + UI/Marke), `docs/ARCHITEKTUR.md` (Module, Datenmodell, Zustandsautomat).

## Code-Prinzipien
- Clean Code, kleine Funktionen und Views, sprechende Namen.
- **Wiederverwendung vor Duplikat.** Vor neuem Code gezielt nach Vorhandenem suchen (`grep`/`find`). Gemeinsame Bausteine:
  - EIN Renderer für Ausgabe und Vorschau (`LayerRenderer`/`FrameView`).
  - EIN generisches Ebenen-Modell für Text und Bild (`Layer`).
  - EIN sortierbarer Listen-Baustein für Bibliothek und Gruppen (`ReorderableList`).
  - EIN Medien-Zugriff über das Projektpaket (`MediaStore`).
  - Farb-Tokens statt Hex-Werten im Code (`Theme`).
- Modell- und Loop-Logik ohne UI-Abhängigkeit, damit Unit-Tests möglich sind.

## Token-sparsam arbeiten
- Gezielt lesen (Zeilenbereiche, grep), keine großen Dumps, keine unnötigen Dateilesungen.
- Antworten knapp und präzise. Alles auf Deutsch.

## Modellwahl
- Entwicklung: Opus
- Planung / Tickets: Sonnet
- Dokumentation / Release Notes: Haiku

## Workflow
- Jedes Ticket = GitHub-Issue. Zuerst aktuellen Stand holen (`git pull`), dann arbeiten.
- Branch: `feature/<issue-nr>-kurzname` (Docs: `docs/<kurzname>`).
- PR mit `Closes #<nr>` in der Beschreibung. Kleine, eigenständige Pakete.
- Zusammengehörige Tickets (gleiche Dateien/Funktion/Ansicht) im selben Chat, unabhängige in eigener Session.
- Nie direkt auf `main` committen.
- Bei jedem Release: `CHANGELOG.md` pflegen und Release Notes erstellen (Haiku).

## Build und Test
```sh
xcodebuild -scheme MessePlayer -destination 'platform=macOS' build
xcodebuild -scheme MessePlayer -destination 'platform=macOS' test
```

## Definition of Done
- Build grün, Tests grün, Akzeptanzkriterien des Issues erfüllt.
- Kein Force-Unwrap, keine Hex-Farben im Code, kein duplizierter Baustein.
- CHANGELOG-Eintrag unter `Unreleased`, falls nutzersichtbar.
