# Messe-Player

KlangNIVEAU Veranstaltungstechnik – macOS-Software zur Ausspielung von Videos, Bildern und Texten auf einem externen Bildschirm (Messe/Event).

## Entwicklung

Voraussetzung: Xcode 26, macOS 26. `MessePlayer.xcodeproj` öffnen und starten – oder:

```sh
xcodebuild -scheme MessePlayer -destination 'platform=macOS' build
xcodebuild -scheme MessePlayer -destination 'platform=macOS' test
```

Ohne externen Bildschirm läuft der Ausgang als Testfenster. Regeln für die Mitarbeit: `CLAUDE.md`, `docs/STYLEGUIDE.md`, `docs/ARCHITEKTUR.md`.
