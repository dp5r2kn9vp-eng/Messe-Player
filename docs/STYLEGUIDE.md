# Styleguide

## 1. Code-Style
- **Swift API Design Guidelines** gelten: Klarheit am Aufrufort, Methoden lesen sich als Satz, Typen `UpperCamelCase`, alles andere `lowerCamelCase`.
- **Ordnerstruktur nach Feature**, nicht nach Typ (siehe `docs/ARCHITEKTUR.md`). Geteiltes liegt in `Core/` bzw. `UI/`.
- **Benennung:** Modelle als Substantive (`Group`, `Entry`, `Layer`), Zustände als Enum (`OutputState`), Views mit Suffix `View`, Services mit Suffix `Service`/`Store`. Keine Abkürzungen außer etablierten (URL, ID).
- **Kleine Views:** eine View = eine Aufgabe, max. ca. 100 Zeilen `body`-Gesamtumfang; größere Teile in Subviews auslagern. Keine Logik in `body`, sondern in ViewModel/Modell.
- **Kein Force-Unwrap** (`!`, `try!`, `as!`). Stattdessen `guard let`, `if let`, `??`.
- **Fehlerbehandlung:** `throws` mit typisierten Fehler-Enums (`LocalizedError`); Fehler am Rand (UI) anzeigen, nie still verschlucken. Medien fehlen/defekt: Eintrag überspringen und markieren, Ausgabe läuft weiter.
- **Nebenläufigkeit:** `async/await`, UI-Typen `@MainActor`. Keine Timer-Logik in Views.
- **Tests:** Pflicht für Modell (Codable, Schema-Version, Migration) und Loop-Logik (Zustandsautomat, Dauer, Pause, Wrap-around). Loop-Engine mit injizierbarer Uhr testen. Keine UI-Tests für Trivialitäten.
- **Kommentare** nur für das *Warum*, nicht für das *Was*. Öffentliche Typen: kurze `///`-Doku.
- **Wiederverwendung:** vor neuem Code suchen; ein Baustein, mehrere Nutzer.

## 2. UI- und Marken-Style

### Farb-Tokens
Farben ausschließlich über `Theme` (Asset-Katalog), nie als Hex im Code.

| Token | Hex | Verwendung |
|---|---|---|
| `brandDark` | #151313 | Hintergrund Steuer-UI, Idle-Bild Ausgang |
| `brandRed` | #ee1c25 | Akzent, Black-Button, primäre Aktionen |
| `brandOrange` | #ff762f | Aktiv/Hervorhebung, „läuft gerade“ |
| `brandPaper` | #f2f1ef | Primärtext auf Dunkel, helle Flächen |
| `mutedLight` | #bdb6b3 | Sekundärtext auf Dunkel |
| `mutedDark` | #6f6866 | Trennlinien, deaktiviert, Sekundärtext auf Hell |
| `outputBlue` | #3d9bff | Kennfarbe Ausgang 2 (Ausgang 1 = `brandOrange`) |
| `outputGreen` | #3cc27a | Kennfarbe Ausgang 3 |
| `outputViolet` | #a57cff | Kennfarbe Ausgang 4 |

### Typografie
- UI: **SF Pro** (Systemschrift, `.font(.body)` etc.), Dynamic Type der macOS-Textstile nutzen.
- Überschriften `.headline`/`.title3`, Metadaten `.caption` in `mutedLight`.
- Ausgabe-Textebenen: frei wählbare Schrift, Standard SF Pro Bold.

### Logo
- Produktlogo **CueView**: Icon und Wortmarke unter `Branding/CueView/` (Generator `make_logo.py`). Wortmarke in der Kopfzeile, Icon als App-Icon.
- Firmenlogo KlangNIVEAU (unten) bleibt Absender: Ruhebild des Ausgangs, Logo-Ebene, neben der Wortmarke.
- `Branding/klangniveau-logo-hell.png` (helle Schrift) nur auf dunklem Grund, z. B. Header, Ausgang.
- `Branding/klangniveau-logo-dunkel.png` nur auf hellem Grund.
- Nie verzerren, einfärben oder beschneiden. Freiraum mindestens Logo-Höhe/4. Original 700x255.

### Abstände und Form
- 4-pt-Raster: 4, 8, 12, 16, 24, 32. Standard-Innenabstand 16, Elementabstand 8.
- Eckenradius 8 (Karten), 6 (Buttons). Mindest-Klickfläche 28 pt.

### Zustandsfarben
- Aktiv / läuft gerade: Orange. Black aktiv: Rot, Button gefüllt und deutlich.
- Fehler: Rot mit Symbol und Text (nie nur Farbe). Deaktiviert: `mutedDark`.
- Auswahl: Orange-Rahmen 2 pt.

### Ausgabe-Konventionen
- Ausgabefenster rahmenlos, Vollbild auf gewähltem externen Bildschirm; kein Cursor, keine Menüleiste.
- Hintergrund immer `brandDark` bzw. Schwarz bei Black; Standard-Idle: Logo zentriert auf #151313.
- Medien `aspect-fit` (Letterbox in Schwarz), 16:9 als Referenz.
- Ebenen-Positionen relativ (0–1), Schriftgröße relativ zur Ausgabehöhe, damit auflösungsunabhängig.
- Black-Button immer sichtbar und erreichbar (auch Taste B); wirkt sofort, ohne Überblendung.
