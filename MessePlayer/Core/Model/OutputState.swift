/// Was der Ausgang zeigen soll.
/// `isBlack` liegt über jedem Inhalt, damit nach dem Aufheben der vorherige Inhalt unverändert weiterläuft.
struct OutputState: Equatable {
    var content: OutputContent = .idle
    var isBlack = false
}

/// Inhalt des Ausgangs. Einzelanzeige und Loop folgen in eigenen Tickets.
enum OutputContent: Equatable {
    case idle
}
