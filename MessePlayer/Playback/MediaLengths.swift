import AVFoundation
import Observation

/// Länge von Videos und Audios, einmal je Datei asynchron geladen und gemerkt.
/// Liefert `nil`, solange die Länge noch lädt oder nicht lesbar ist.
@Observable
final class MediaLengths {
    private(set) var lengths: [URL: TimeInterval] = [:]
    @ObservationIgnored private var requested: Set<URL> = []
    @ObservationIgnored private let load: (URL) async -> TimeInterval?

    init(load: @escaping (URL) async -> TimeInterval? = MediaLengths.loadLength) {
        self.load = load
    }

    func length(of url: URL?) -> TimeInterval? {
        guard let url else { return nil }
        if let length = lengths[url] { return length }
        request(url)
        return nil
    }

    static func loadLength(_ url: URL) async -> TimeInterval? {
        guard let duration = try? await AVURLAsset(url: url).load(.duration), duration.isNumeric else { return nil }
        return duration.seconds
    }

    private func request(_ url: URL) {
        guard requested.insert(url).inserted else { return }
        Task { [weak self, load] in
            guard let length = await load(url) else { return }
            self?.lengths[url] = length
        }
    }
}
