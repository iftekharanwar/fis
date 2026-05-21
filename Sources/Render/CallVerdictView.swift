import SwiftUI

/// v2.1 verdict view for the call-first surface. Replaces v1's SwishView /
/// MissedView, which were written for the "you solved it" framing — surfacing
/// θ°/m·s⁻¹ stats and "+XP" lines that don't make sense when the user only
/// tapped YES/NO.
///
/// Composition:
///   - massive Anton verb keyed to the *call*, not the shot
///     ("NAILED IT.", "CLOSE.", "OFF.", "MISSED IT.")
///   - one-line italic subhead describing what happened
///   - the RevealOverlay slides up on top of this 900ms later
struct CallVerdictView: View {
    /// True iff the user's call matched the truth.
    let wasCorrect: Bool
    /// True iff the ball actually went in (regardless of call).
    let ballWentIn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.xl)

            verb
                .padding(.horizontal, Spacing.md)

            Spacer().frame(height: Spacing.sm)

            subhead
                .padding(.horizontal, Spacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundTint.ignoresSafeArea())
    }

    // MARK: - Copy

    /// Big Anton headline. Two axes (correct/incorrect × made/missed) → four
    /// possible verbs. Tone is short, confident, sport-coded.
    private var verbCopy: String {
        switch (wasCorrect, ballWentIn) {
        case (true,  true):  return "NAILED IT."
        case (true,  false): return "GOOD CALL."
        case (false, true):  return "MISSED IT."   // user said NO, ball went in
        case (false, false): return "WRONG."        // user said YES, ball missed
        }
    }

    /// Single italic line under the verb — explains the call vs the outcome
    /// in plain language, not stat-coded.
    private var subheadCopy: String {
        switch (wasCorrect, ballWentIn) {
        case (true,  true):  return "Your read was right. The shot went in."
        case (true,  false): return "Your read was right. The shot didn't fall."
        case (false, true):  return "Your read was off. It found the bottom of the net."
        case (false, false): return "Your read was off. The ball never made it home."
        }
    }

    private var verb: some View {
        Text(verbCopy)
            .font(.anton(size: 96))
            .foregroundColor(.arclabWhite)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var subhead: some View {
        Text(subheadCopy)
            .font(.barlowCondensed(size: 16, italic: true))
            .foregroundColor(.arclabMidGrey)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Wrong calls get the same crimson tint v1's MissedView uses — crimson
    /// stays sacred to the LOSS state (here = wrong prediction). Right calls
    /// get pure black, no celebratory tint (celebration belongs to the
    /// reveal card's RIGHT CALL chip).
    private var backgroundTint: Color {
        wasCorrect ? .arclabBlack : .arclabMissTint
    }
}

#Preview("Right + In") {
    CallVerdictView(wasCorrect: true, ballWentIn: true)
}

#Preview("Right + Out") {
    CallVerdictView(wasCorrect: true, ballWentIn: false)
}

#Preview("Wrong + In") {
    CallVerdictView(wasCorrect: false, ballWentIn: true)
}

#Preview("Wrong + Out") {
    CallVerdictView(wasCorrect: false, ballWentIn: false)
}
