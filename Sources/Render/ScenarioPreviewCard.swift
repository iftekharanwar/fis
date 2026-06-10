import SwiftUI
import UIKit

/// Hero scenario-preview card for the home surface.
///
/// Loads an AI-generated illustration from `Resources/Illustrations/`
/// (file: `scenario_<id>.png`). If the asset is missing, shows a quiet
/// placeholder so the card layout still works during authoring.
struct ScenarioPreviewCard: View {
    let scenarioId: String         // used to look up the illustration
    let titleAbove: String         // "TODAY"
    let bigTitle: String           // "THE FLAT-ARC CORNER THREE."
    let subhead: String            // "A guard releasing from the corner..."
    let actionLabel: String        // "CALL IT"
    let onTap: () -> Void

    @State private var tapCount: Int = 0

    var body: some View {
        Button(action: { tapCount += 1; onTap() }) {
            VStack(alignment: .leading, spacing: 0) {
                illustration
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()

                content
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.md)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.arclabCardBlack)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.cardRadius)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sizing.cardRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(haptic: .impact(weight: .medium)))
        .accessibilityLabel("\(titleAbove). \(bigTitle). \(actionLabel).")
    }

    // MARK: - Illustration

    private var illustration: some View {
        Group {
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        // Decorative — the card's combined label already names the scenario;
        // keep Smart Invert from negating the illustration.
        .accessibilityIgnoresInvertColors()
    }

    /// Quiet placeholder shown when the AI-generated illustration is missing.
    /// Mirrors the card palette so it doesn't visually scream "broken." Debug
    /// builds show the scenarioId; release builds show only the neutral panel.
    private var placeholder: some View {
        ZStack {
            Color.arclabSceneBg
            #if DEBUG
            Text("ILLUSTRATION · \(scenarioId.uppercased())")
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabBorderGrey)
                .tracking(2.0)
            #endif
        }
    }

    private var imageName: String {
        "scenario_\(scenarioId)"
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titleAbove)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)

            Spacer().frame(height: Spacing.xs)

            Text(bigTitle)
                .font(.anton(size: 30))
                .foregroundColor(.arclabWhite)
                .tracking(-0.5)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: Spacing.xs)

            Text(subhead)
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabMidGrey)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: Spacing.md)

            HStack {
                Spacer()
                Text("\(actionLabel)  →")
                    .font(.sfMono(size: 13, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(2.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
