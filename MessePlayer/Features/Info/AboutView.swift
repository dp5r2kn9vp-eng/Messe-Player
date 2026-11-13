import SwiftUI

/// Fenster „Über CueView“.
struct AboutView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            AppIconImage(size: 128)
            CueViewWordmark(height: 64)
            Text("Version \(AppInfo.version) (Build \(AppInfo.build))")
                .font(.callout)
                .foregroundStyle(Color.mutedLight)
            Text("Der Messe-Player von KlangNIVEAU Veranstaltungstechnik")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brandPaper)
            BrandLogo(width: 150)
                .padding(.vertical, Theme.Spacing.s)
            if let website = AppInfo.website {
                Link("klangniveau.de", destination: website)
                    .foregroundStyle(Color.brandOrange)
            }
            Text(AppInfo.copyright)
                .font(.caption)
                .foregroundStyle(Color.mutedLight)
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: 400)
        .background(Color.brandDark)
        .preferredColorScheme(.dark)
    }
}
