import AVFoundation
import AppKit
import QuickLookThumbnailing

/// Erzeugt und puffert Vorschaubilder für Bilder und Videos (Video: ein Standbild) über QuickLook
/// sowie Filmstreifen (mehrere Standbilder eines Videos) über `AVAssetImageGenerator`.
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSURL, NSImage>()
    private let size = CGSize(width: 160, height: 90)
    private var filmstrips: [FilmstripKey: [NSImage]] = [:]

    func thumbnail(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 2, representationTypes: .thumbnail)
        guard let image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage else {
            return nil
        }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// `count` Standbilder, gleichmäßig über `length` Sekunden verteilt (jeweils Mitte des Abschnitts).
    func filmstrip(for url: URL, count: Int, length: TimeInterval) async -> [NSImage] {
        let key = FilmstripKey(url: url, count: count)
        if let cached = filmstrips[key] { return cached }
        let times = (0..<count).map { CMTime(seconds: length * (Double($0) + 0.5) / Double(count)) }
        let images = await Self.frames(of: url, at: times, size: size)
        if !images.isEmpty, !Task.isCancelled { filmstrips[key] = images }
        return images
    }

    @concurrent
    nonisolated private static func frames(of url: URL, at times: [CMTime], size: CGSize) async -> [NSImage] {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: size.width * 2, height: size.height * 2)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5)
        var images: [NSImage] = []
        for time in times {
            guard !Task.isCancelled, let frame = try? await generator.image(at: time) else { break }
            images.append(NSImage(cgImage: frame.image, size: .zero))
        }
        return images
    }
}

private struct FilmstripKey: Hashable {
    let url: URL
    let count: Int
}
