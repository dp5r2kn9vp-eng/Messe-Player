import AppKit

/// Versions- und Herstellerangaben für Info-Fenster und Hilfe.
enum AppInfo {
    static let website = URL(string: "https://klangniveau.de")
    static let copyright = "© 2026 KlangNIVEAU Veranstaltungstechnik"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    /// Läuft als Gastgeber der Unit-Tests: dann keinen Start merken und nichts wiederherstellen.
    static var isTestHost: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    }
}

/// IDs der Zusatzfenster.
enum WindowID {
    static let welcome = "welcome"
    static let about = "about"
    static let help = "help"
    static let shortcuts = "shortcuts"
}
