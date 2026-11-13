# Release-Prozess

Versionierung nach SemVer: MAJOR bei inkompatiblen Änderungen (z. B. Projektformat), MINOR bei neuen Funktionen, PATCH bei Fehlerbehebungen. Changelog nach Keep a Changelog.

1. Version im Xcode-Projekt erhöhen: `MARKETING_VERSION` in `MessePlayer.xcodeproj` (X.Y.Z).
2. `CHANGELOG.md`: Abschnitt `## [Unreleased]` in `## [X.Y.Z] – JJJJ-MM-TT` umbenennen, darüber einen neuen leeren `## [Unreleased]` anlegen, Vergleichslinks am Dateiende aktualisieren.
3. Release Notes für Anwender schreiben: `docs/releases/vX.Y.Z.md` aus dem Changelog ableiten (z. B. per Haiku-Agent, Vorlage: `docs/releases/v1.0.0.md`).
4. Release-Build:
   ```sh
   xcodebuild -scheme MessePlayer -configuration Release -destination 'platform=macOS' -derivedDataPath build build
   ```
   Der Build schreibt die Commit-ID in die App (`scripts/stamp-commit.sh`, Schlüssel `CueViewGitCommit`). Release-Builds nur aus dem gemergten, sauberen `main` erstellen (Reihenfolge: erst Schritt 6, dann Build, Zip, Tag), damit die ID dem getaggten Commit entspricht.
5. Zip erstellen:
   ```sh
   ditto -c -k --keepParent build/Build/Products/Release/CueView.app CueView-X.Y.Z.zip
   ```
6. Änderungen per PR auf `main` mergen.
7. Tag setzen und pushen: `git tag vX.Y.Z && git push origin vX.Y.Z`.
8. GitHub-Release erstellen:
   ```sh
   gh release create vX.Y.Z CueView-X.Y.Z.zip --title "CueView X.Y.Z" --notes-file docs/releases/vX.Y.Z.md
   ```
9. Lokale Ablage für das Messe-Team: Zip nach `~/KlangNIVEAU_Firma/Release/` kopieren und dort zusätzlich die aktuelle `CueView.app` entpacken (ersetzt die vorherige):
   ```sh
   R=~/KlangNIVEAU_Firma/Release
   mkdir -p "$R" && cp CueView-X.Y.Z.zip "$R/"
   rm -rf "$R/CueView.app" && ditto -x -k "$R/CueView-X.Y.Z.zip" "$R/"
   ```
10. Ausgelieferten Stand prüfen: In Zip (GitHub-Release) und `Release/CueView.app` müssen Version und Commit-ID zum Tag passen, ohne `-dirty`:
   ```sh
   plutil -extract CFBundleShortVersionString raw "$R/CueView.app/Contents/Info.plist"   # X.Y.Z
   plutil -extract CueViewGitCommit raw "$R/CueView.app/Contents/Info.plist"             # = git rev-parse --short=7 vX.Y.Z
   ```
