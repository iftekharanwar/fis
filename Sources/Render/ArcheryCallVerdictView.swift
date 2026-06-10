import SwiftUI

/// Verdict view for archery scenarios. Same shape as the basketball
/// `CallVerdictView` but sport-coded copy — the basketball strings ("net",
/// "shot", "ball") read wrong for archery.
///
/// `mode` switches the framing between Ch1's hit/miss judgement and Ch2's
/// clean/wobbled judgement. The reveal overlay slides up on top of this
/// ~900ms later.
struct ArcheryCallVerdictView: View {

    /// Which question the verdict is answering.
    enum Mode: Equatable {
        /// Pin-gap (Ch1): truth = did the arrow hit the bullseye?
        case hit
        /// Paradox (Ch2): truth = did the arrow fly clean (no significant
        /// wobble at impact)?
        case cleanFlight
    }

    let wasCorrect: Bool
    /// In `.hit` mode this is "did the arrow hit"; in `.cleanFlight` mode
    /// it's "did the arrow fly clean." Same axis, different framing.
    let outcomeAffirmative: Bool
    let mode: Mode

    init(wasCorrect: Bool, didHit: Bool, mode: Mode = .hit) {
        self.wasCorrect = wasCorrect
        self.outcomeAffirmative = didHit
        self.mode = mode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.xl)

            Text(verbCopy)
                .font(.anton(size: 96))
                .foregroundColor(.arclabWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, Spacing.md)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: Spacing.sm)

            Text(subheadCopy)
                .font(.barlowCondensed(size: 16, italic: true))
                .foregroundColor(.arclabMidGrey)
                .padding(.horizontal, Spacing.md)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundTint.ignoresSafeArea())
        // The verdict swaps in as an in-place ZStack — announce it, posted
        // here so the spoken copy is exactly the on-screen copy.
        .announceOnAppear { "\(verbCopy) \(subheadCopy)" }
    }

    private var verbCopy: String {
        switch mode {
        case .hit:
            switch (wasCorrect, outcomeAffirmative) {
            case (true,  true):  return "NAILED IT."
            case (true,  false): return "GOOD READ."
            case (false, true):  return "UNDER-CALLED."
            case (false, false): return "OVER-CALLED."
            }
        case .cleanFlight:
            switch (wasCorrect, outcomeAffirmative) {
            case (true,  true):  return "CLEAN."
            case (true,  false): return "GOOD READ."
            case (false, true):  return "OVER-CALLED."
            case (false, false): return "WOBBLED IT."
            }
        }
    }

    private var subheadCopy: String {
        switch mode {
        case .hit:
            switch (wasCorrect, outcomeAffirmative) {
            case (true,  true):  return "You called the hit. The arrow found home."
            case (true,  false): return "You called the miss. The arrow drifted off."
            case (false, true):  return "You said no — but the arrow split the bullseye."
            case (false, false): return "You said yes — but the arrow missed."
            }
        case .cleanFlight:
            switch (wasCorrect, outcomeAffirmative) {
            case (true,  true):  return "Spine match — no flex worth seeing. Straight flight."
            case (true,  false): return "You called the wobble. Mismatched spine, tumbled the shaft."
            case (false, true):  return "You expected wobble — but the spine was matched. Clean shot."
            case (false, false): return "You said it would fly straight — but the shaft oscillated the whole way."
            }
        }
    }

    /// Crimson tint reserved for the LOSS state (wrong call). Right calls
    /// stay on pure black — celebration belongs to the reveal card's
    /// RIGHT CALL chip, not a background flash.
    private var backgroundTint: Color {
        wasCorrect ? .arclabBlack : .arclabMissTint
    }
}

#Preview("Hit · Right + Hit") {
    ArcheryCallVerdictView(wasCorrect: true, didHit: true)
}

#Preview("Hit · Wrong + Hit") {
    ArcheryCallVerdictView(wasCorrect: false, didHit: true)
}

#Preview("Paradox · Right + Clean") {
    ArcheryCallVerdictView(wasCorrect: true, didHit: true, mode: .cleanFlight)
}

#Preview("Paradox · Wrong + Wobbled") {
    ArcheryCallVerdictView(wasCorrect: false, didHit: false, mode: .cleanFlight)
}
