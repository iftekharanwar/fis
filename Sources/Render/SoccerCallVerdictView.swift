import SwiftUI

/// Verdict view for soccer scenarios. Same shape as the basketball /
/// archery `CallVerdictView` but sport-coded copy — soccer's outcomes
/// (GOAL / SAVED / WIDE / OVER) need different verbs than "net found"
/// or "bullseye".
///
/// Crimson tint reserved for the LOSS state (wrong call). Right calls
/// stay on pure black — celebration belongs to the reveal card's RIGHT
/// CALL chip, not a background flash.
struct SoccerCallVerdictView: View {
    let wasCorrect: Bool
    let outcome: SoccerOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.xl)

            Text(outcome.verb)
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
        .announceOnAppear { "\(outcome.verb) \(subheadCopy)" }
    }

    private var subheadCopy: String {
        switch (wasCorrect, outcome) {
        case (true,  .goal):
            return "You called the goal. The spin bent the ball home."
        case (true,  .savedByKeeper):
            return "You called the save. The keeper read the curve."
        case (true,  .wideOfPost):
            return "You called it wide. The spin pulled too far past the post."
        case (true,  .overTheBar):
            return "You called it over. Not enough dip to drop it in."
        case (false, .goal):
            return "You said no — but the curve found the corner."
        case (false, .savedByKeeper):
            return "You said yes — but the keeper got there first."
        case (false, .wideOfPost):
            return "You said yes — but the curve carried it past the post."
        case (false, .overTheBar):
            return "You said yes — but the ball sailed over the bar."
        }
    }

    private var backgroundTint: Color {
        wasCorrect ? .arclabBlack : .arclabMissTint
    }
}

#Preview("Right + Goal") {
    SoccerCallVerdictView(wasCorrect: true, outcome: .goal)
}

#Preview("Wrong + Saved") {
    SoccerCallVerdictView(wasCorrect: false, outcome: .savedByKeeper)
}
