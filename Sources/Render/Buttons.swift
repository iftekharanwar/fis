import SwiftUI

/// Primary CTA — filled, high-contrast, hero-button-shaped. Used for the
/// single most important action on a screen (BEGIN onboarding, PRACTICE
/// after a lesson, CALL IT on the hero card if it ever becomes a separate
/// button).
///
/// Visual treatment: pill shape (rounded `pillRadius`), filled with white,
/// black SF Mono label. Reads as "the thing you came here to do."
struct PrimaryButton: View {
    let label: String
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.sfMono(size: 16, weight: .medium))
                .foregroundColor(.arclabBlack)
                .tracking(3.2)
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.pillButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: Sizing.pillRadius)
                        .fill(Color.arclabWhite)
                )
                .opacity(isEnabled ? 1.0 : 0.4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .sensoryFeedback(.impact(weight: .heavy), trigger: tapCount)
    }

    @State private var tapCount: Int = 0
}

/// Accent CTA — orange-filled, reserved for the SINGLE hero moment per
/// screen. Use sparingly: if it's on more than one button at the same
/// time, the meaning evaporates and orange just becomes "another button
/// color." Reserved for moments where we genuinely want the user to act:
///
///   • Lesson's final "Practice" button (commit to play)
///   • RevealOverlay's "See why →" (push into the depth path)
///   • Walkthrough's "Watch it land" (final payoff)
///   • Onboarding's "Begin"
///
/// Visual treatment: pill shape, filled with arclabRimOrange (#E8782B),
/// pure black SF Mono label for maximum contrast (~5:1 ratio).
struct AccentButton: View {
    let label: String
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.sfMono(size: 16, weight: .medium))
                .foregroundColor(.arclabBlack)
                .tracking(3.2)
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.pillButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: Sizing.pillRadius)
                        .fill(Color.arclabRimOrange)
                )
                .opacity(isEnabled ? 1.0 : 0.4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .sensoryFeedback(.impact(weight: .heavy), trigger: tapCount)
    }

    @State private var tapCount: Int = 0
}

/// Secondary CTA — outlined ghost button, lower visual weight. Used for
/// alternate actions next to a primary (READ vs PRACTICE, REPLAY vs NEXT,
/// CANCEL vs CONFIRM). Also used when a screen has only one action but it's
/// not the hero action of the flow.
///
/// Visual treatment: pill shape, transparent fill, mid-grey 1pt border, white
/// SF Mono label.
struct SecondaryButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.sfMono(size: 16, weight: .medium))
                .foregroundColor(.arclabWhite)
                .tracking(3.2)
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.pillButtonHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.pillRadius)
                        .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 24) {
        PrimaryButton(label: "Begin", action: {})
        SecondaryButton(label: "Cancel", action: {})
        AccentButton(label: "See why →", action: {})
        PrimaryButton(label: "Practice", action: {}, isEnabled: false)
    }
    .padding()
    .background(Color.arclabBlack)
}
