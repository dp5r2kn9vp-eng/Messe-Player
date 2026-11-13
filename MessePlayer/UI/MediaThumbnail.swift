import SwiftUI

/// Vorschaubild eines Mediums in 16:9, schwarz hinterlegt. Defekte Dateien werden markiert,
/// was gerade auf dem Ausgang läuft, bekommt einen orangen Rahmen.
struct MediaThumbnail: View {
    let url: URL?
    var isLive = false

    @State private var image: NSImage?
    @State private var didFail = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.button)
        ZStack {
            Color.black
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else if didFail {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.brandRed)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(shape)
        .overlay { shape.stroke(isLive ? Color.brandOrange : .clear, lineWidth: 2) }
        .task(id: url) { await load() }
    }

    private func load() async {
        image = nil
        didFail = false
        guard let url else {
            didFail = true
            return
        }
        image = await ThumbnailService.shared.thumbnail(for: url)
        didFail = image == nil
    }
}
