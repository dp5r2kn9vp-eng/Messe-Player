# CueView

![CueView](Branding/CueView/cueview-wortmarke.png)


CueView ist der Messe-Player von KlangNIVEAU Veranstaltungstechnik – macOS-Software zur Ausspielung von Videos, Bildern und Texten auf einem externen Bildschirm (Messe/Event).

## Entwicklung

Voraussetzung: Xcode 26, macOS 26. `MessePlayer.xcodeproj` öffnen und starten – oder:

```sh
xcodebuild -scheme MessePlayer -destination 'platform=macOS' build
xcodebuild -scheme MessePlayer -destination 'platform=macOS' test
```

Ohne externen Bildschirm läuft der Ausgang im Vollbild auf dem MacBook-Bildschirm, sobald etwas abgespielt wird – Esc beendet. Regeln für die Mitarbeit: `CLAUDE.md`, `docs/STYLEGUIDE.md`, `docs/ARCHITEKTUR.md`.

## Release

Der Ablauf für ein Release (Version, Changelog, Build, Zip, GitHub-Release) steht in [`docs/RELEASE.md`](docs/RELEASE.md).
