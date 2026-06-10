import SwiftUI

/// Painted-plate background layer; falls back to black if image is missing.
struct ScenarioBackgroundView: View {
    let opacity: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.arclabBlack

                // UIImage (not SwiftUI Image) so it loads from folder refs, not just asset catalogs.
                if let uiImage = loadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(opacity)
                        // Decorative backdrop — keep it out of the a11y tree
                        // and don't let Smart Invert turn the photo to a
                        // negative.
                        .accessibilityHidden(true)
                        .accessibilityIgnoresInvertColors()
                }

                // Vignette protects corner typography from the bright light-shaft on the plate.
                LinearGradient(
                    colors: [
                        Color.arclabBlack.opacity(0.45),
                        Color.clear,
                        Color.clear,
                        Color.arclabBlack.opacity(0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    private var loadedImage: UIImage? {
        if let img = UIImage(named: "bg-basketball-gym-dusk") { return img }
        if let url = Bundle.main.url(
            forResource: "bg-basketball-gym-dusk",
            withExtension: "png",
            subdirectory: "Backgrounds/Basketball"
        ), let img = UIImage(contentsOfFile: url.path) {
            return img
        }
        // Last resort: Xcode sometimes flattens folder refs into the flat bundle.
        if let url = Bundle.main.url(
            forResource: "bg-basketball-gym-dusk",
            withExtension: "png"
        ), let img = UIImage(contentsOfFile: url.path) {
            return img
        }
        return nil
    }
}
