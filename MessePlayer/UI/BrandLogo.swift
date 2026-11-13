import SwiftUI

/// KlangNIVEAU-Logo, helle Variante – nur auf dunklem Grund verwenden (siehe STYLEGUIDE).
struct BrandLogo: View {
    let width: CGFloat

    var body: some View {
        Image(.logoLight)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityLabel("KlangNIVEAU Veranstaltungstechnik")
    }
}
