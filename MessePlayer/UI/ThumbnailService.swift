import AppKit
import QuickLookThumbnailing

/// Erzeugt und puffert Vorschaubilder für Bilder und Videos (Video: ein Standbild) über QuickLook.
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSURL, NSImage>()
    private let size = CGSize(width: 160, height: 90)

    func thumbnail(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 2, representationTypes: .thumbnail)
        guard let image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage else {
            return nil
        }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
