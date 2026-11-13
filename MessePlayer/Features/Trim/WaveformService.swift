import AVFoundation
import CryptoKit

/// Spitzenwerte (0…1) einer Tonspur, gleichmäßig über die ganze Länge verteilt.
nonisolated struct Waveform: Codable, Equatable {
    static let peakCount = 600

    var peaks: [Float]
}

/// Sammelt Samples zu Spitzenwerten: je `samplesPerPeak` Samples der größte Betrag.
nonisolated struct PeakAccumulator {
    let samplesPerPeak: Int
    private(set) var peaks: [Float] = []
    private var current: Float = 0
    private var count = 0

    init(totalSamples: Int, peakCount: Int) {
        samplesPerPeak = max(totalSamples / max(peakCount, 1), 1)
    }

    mutating func add(_ samples: UnsafeBufferPointer<Float>) {
        for sample in samples {
            current = max(current, min(abs(sample), 1))
            count += 1
            if count == samplesPerPeak { flush() }
        }
    }

    /// Schließt den letzten, unvollständigen Spitzenwert ab.
    mutating func finish() -> [Float] {
        if count > 0 { flush() }
        return peaks
    }

    private mutating func flush() {
        peaks.append(current)
        current = 0
        count = 0
    }
}

/// Berechnet Wellenformen einmal je Datei über `AVAssetReader` und merkt sie im Speicher und
/// im Cache-Ordner des Benutzers (nicht im Projektpaket).
final class WaveformService {
    static let shared = WaveformService()

    /// Niedrige Abtastrate genügt für die Anzeige und hält das Lesen schnell.
    private static let sampleRate = 8000.0

    private var memory: [URL: Waveform] = [:]

    func waveform(for url: URL) async -> Waveform? {
        if let cached = memory[url] { return cached }
        let cacheURL = Self.cacheURL(for: url)
        let waveform: Waveform?
        if let cacheURL, let stored = Self.load(from: cacheURL) {
            waveform = stored
        } else {
            waveform = await Self.compute(url)
            if let waveform, let cacheURL { Self.store(waveform, at: cacheURL) }
        }
        memory[url] = waveform
        return waveform
    }

    /// Liest die erste Tonspur als Mono-Float-PCM und verdichtet sie zu Spitzenwerten.
    @concurrent
    nonisolated private static func compute(_ url: URL) async -> Waveform? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let duration = try? await asset.load(.duration), duration.isNumeric,
              let reader = try? AVAssetReader(asset: asset)
        else { return nil }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: sampleRate,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        guard reader.startReading() else { return nil }
        var accumulator = PeakAccumulator(totalSamples: Int(duration.seconds * sampleRate), peakCount: Waveform.peakCount)
        while !Task.isCancelled, let buffer = output.copyNextSampleBuffer() {
            readSamples(of: buffer) { accumulator.add($0) }
        }
        reader.cancelReading()
        guard !Task.isCancelled else { return nil }
        return Waveform(peaks: accumulator.finish())
    }

    nonisolated private static func readSamples(of buffer: CMSampleBuffer, _ body: (UnsafeBufferPointer<Float>) -> Void) {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return }
        var length = 0
        var pointer: UnsafeMutablePointer<CChar>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: nil, dataPointerOut: &pointer) == kCMBlockBufferNoErr,
              let pointer
        else { return }
        pointer.withMemoryRebound(to: Float.self, capacity: length / MemoryLayout<Float>.size) { floats in
            body(UnsafeBufferPointer(start: floats, count: length / MemoryLayout<Float>.size))
        }
    }

    // MARK: Datei-Cache

    /// Schlüssel aus Pfad, Größe und Änderungsdatum, damit eine ersetzte Datei neu berechnet wird.
    private static func cacheURL(for url: URL) -> URL? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let folder = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else { return nil }
        let key = "\(url.path)|\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder
            .appending(path: Bundle.main.bundleIdentifier ?? "CueView")
            .appending(path: "Waveforms")
            .appending(path: "\(hash).json")
    }

    private static func load(from url: URL) -> Waveform? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Waveform.self, from: data)
    }

    private static func store(_ waveform: Waveform, at url: URL) {
        guard let data = try? JSONEncoder().encode(waveform) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
