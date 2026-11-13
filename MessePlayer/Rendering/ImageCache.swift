import AppKit

/// Geladene Bilder für den Ausgang. Der Loop lädt das nächste Bild vor, damit beim Wechsel nichts aufblitzt.
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSURL, NSImage>()

    func image(for url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
