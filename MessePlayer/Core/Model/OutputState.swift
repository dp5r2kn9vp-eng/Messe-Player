import Foundation

/// Was der Ausgang zeigen soll.
/// `isBlack` liegt über jedem Inhalt, damit nach dem Aufheben der vorherige Inhalt unverändert weiterläuft.
struct OutputState: Equatable {
    var content: OutputContent = .idle
    var isBlack = false
}

/// Inhalt des Ausgangs. Der Loop folgt mit der Loop-Engine.
enum OutputContent: Equatable {
    case idle
    /// Ein Medium dauerhaft; Videos laufen in Endlosschleife.
    case single(PlayableMedium)
}

/// Ein Medium samt abspielbarer Adresse – alles, was der Renderer braucht.
struct PlayableMedium: Equatable {
    let medium: Medium
    let url: URL
}
