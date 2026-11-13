import SwiftUI

/// Filmstreifen eines Videos: Standbilder nebeneinander, asynchron geladen und gecacht (`ThumbnailService`).
struct FilmstripView: View {
    static let frameCount = 12

    let url: URL
    let length: TimeInterval

    @State private var frames: [NSImage] = []

    var body: some View {
        HStack(spacing: 1) {
            ForEach(frames.indices, id: \.self) { index in
                Image(nsImage: frames[index])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .overlay { if frames.isEmpty { ProgressView().controlSize(.small) } }
        .task(id: url) {
            frames = await ThumbnailService.shared.filmstrip(for: url, count: Self.frameCount, length: length)
        }
    }
}

/// Wellenform eines Audios aus Spitzenwerten, einmal berechnet und gecacht (`WaveformService`).
struct WaveformView: View {
    let url: URL

    @State private var waveform: Waveform?
    @State private var isLoading = true

    var body: some View {
        Canvas { context, size in
            guard let peaks = waveform?.peaks, !peaks.isEmpty else { return }
            let step = size.width / CGFloat(peaks.count)
            let middle = size.height / 2
            var path = Path()
            for (index, peak) in peaks.enumerated() {
                let height = max(CGFloat(peak) * size.height, 1)
                path.addRect(CGRect(x: CGFloat(index) * step, y: middle - height / 2, width: max(step, 1), height: height))
            }
            context.fill(path, with: .color(.mutedLight))
        }
        .background(Color.black)
        .overlay {
            if isLoading {
                ProgressView().controlSize(.small)
            } else if waveform == nil {
                Text("Wellenform nicht lesbar").font(.caption).foregroundStyle(Color.mutedLight)
            }
        }
        .task(id: url) {
            isLoading = true
            waveform = await WaveformService.shared.waveform(for: url)
            isLoading = false
        }
    }
}
