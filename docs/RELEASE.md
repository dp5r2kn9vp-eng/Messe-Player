# Release-Prozess

Versionierung nach SemVer: MAJOR bei inkompatiblen Änderungen (z. B. Projektformat), MINOR bei neuen Funktionen, PATCH bei Fehlerbehebungen. Changelog nach Keep a Changelog.

1. Version im Xcode-Projekt erhöhen: `MARKETING_VERSION` in `MessePlayer.xcodeproj` (X.Y.Z).
2. `CHANGELOG.md`: Abschnitt `## [Unreleased]` in `## [X.Y.Z] – JJJJ-MM-TT` umbenennen, darüber einen neuen leeren `## [Unreleased]` anlegen, Vergleichslinks am Dateiende aktualisieren.
3. Release Notes für Anwender schreiben: `docs/releases/vX.Y.Z.md` aus dem Changelog ableiten (z. B. per Haiku-Agent, Vorlage: `docs/releases/v1.0.0.md`).
4. Release-Build:
   ```sh
   xcodebuild -scheme MessePlayer -configuration Release -destination 'platform=macOS' -derivedDataPath build build
   ```
5. Zip erstellen:
   ```sh
   ditto -c -k --keepParent build/Build/Products/Release/MessePlayer.app Messe-Player-X.Y.Z.zip
   ```
6. Änderungen per PR auf `main` mergen.
7. Tag setzen und pushen: `git tag vX.Y.Z && git push origin vX.Y.Z`.
8. GitHub-Release erstellen:
   ```sh
   gh release create vX.Y.Z Messe-Player-X.Y.Z.zip --title "Messe-Player X.Y.Z" --notes-file docs/releases/vX.Y.Z.md
   ```
