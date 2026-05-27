import SwiftUI

/// The pedagogical payoff after a call. Layered on top of the existing
/// SwishView / MissedView so the verdict moment lands first (Anton verb,
/// SWISH / MISSED), then this reveal slides up showing:
///   - whether the user's CALL was right or wrong
///   - the physics phenomenon at play
///   - a 2-3 sentence explainer
///
/// Stylistically: black surface with a single thin top border, off-grid
/// padding, SF Mono micro-labels + Barlow Condensed body, NEXT pill button.
/// Crimson is NOT used here — call correctness shows in white/mid-grey type
/// weight differential; crimson stays sacred to the miss state on the
/// underlying verdict screen.
struct RevealOverlay: View {
    let wasCorrect: Bool
    let actualWentIn: Bool
    let phenomenon: String
    let explainer: String
    let onContinue: () -> Void
    /// v2.1 §4 compute beat: optional second CTA that opens slider mode.
    /// nil hides the button entirely (e.g., when compute mode isn't unlocked
    /// for this scenario, or already exhausted attempts).
    let onTryCompute: (() -> Void)?

    /// Optional override for the chip's outcome text. nil → fall back to
    /// "IT WENT IN" / "IT MISSED" driven by `actualWentIn`. Used by paradox
    /// scenarios (Ch2) to show "IT FLEW CLEAN" / "IT WOBBLED" instead.
    var outcomeLabelOverride: String? = nil

    @State private var visible: Bool = false
    @State private var slideUpHapticCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            card
                .padding(.horizontal, Spacing.md)
                .offset(y: visible ? 0 : 40)
                .opacity(visible ? 1 : 0)
                .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Stronger gradient mask so the verdict screen behind doesn't
            // bleed through the reveal card. Top half stays clear (SWISH
            // verb still visible); lower half deepens to near-opaque so the
            // stat strip and any other v1 verdict chrome get cleanly veiled.
            LinearGradient(
                colors: [
                    Color.arclabBlack.opacity(0),
                    Color.arclabBlack.opacity(0.85)
                ],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.4)) { visible = true }
                slideUpHapticCount += 1
            }
        }
        // Soft tick when the reveal card slides up — like a polished sheet
        // settling into place. Light weight to not compete with the verdict.
        .sensoryFeedback(.impact(weight: .light), trigger: slideUpHapticCount)
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            callStatusRow
            phenomenonHeadline
            explainerBody
            continueButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Sizing.cardRadius)
                .fill(Color.arclabCardBlack)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.cardRadius)
                        .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                )
        )
    }

    private var callStatusRow: some View {
        HStack(spacing: Spacing.xs) {
            Text(wasCorrect ? "RIGHT CALL" : "WRONG CALL")
                .font(.sfMono(size: 11, weight: .medium))
                .foregroundColor(.arclabWhite)
                .tracking(2.5)
            Text("·")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabBorderGrey)
            Text(outcomeLabelOverride ?? (actualWentIn ? "IT WENT IN" : "IT MISSED"))
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
        }
    }

    private var phenomenonHeadline: some View {
        // Anton is an all-caps display face — render uppercased so
        // sentence-case source strings (lesson titles) don't fall back to
        // mixed-case Anton glyphs that ship as lowercase placeholders.
        Text(phenomenon.uppercased())
            .font(.anton(size: 28))
            .foregroundColor(.arclabWhite)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var explainerBody: some View {
        Text(explainer)
            .font(.barlowCondensed(size: 16))
            .foregroundColor(.arclabMidGrey)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var continueButton: some View {
        HStack(spacing: Spacing.sm) {
            if let onTryCompute {
                SecondaryButton(label: "Continue", action: onContinue)
                AccentButton(label: "See why  →", action: onTryCompute)
            } else {
                PrimaryButton(label: "Continue", action: onContinue)
            }
        }
        .padding(.top, Spacing.xs)
    }
}

#Preview {
    ZStack {
        Color.arclabBlack.ignoresSafeArea()
        VStack(alignment: .leading) {
            Text("SWISH")
                .font(.anton(size: 96))
                .foregroundColor(.arclabWhite)
                .padding(Spacing.md)
            Spacer()
        }
        RevealOverlay(
            wasCorrect: true,
            actualWentIn: true,
            phenomenon: "Why every shot is an arc.",
            explainer: "Once the ball leaves your hand, only gravity acts on it. The arc is fully determined by release angle and speed — the rest is geometry.",
            onContinue: {},
            onTryCompute: {}
        )
    }
}
