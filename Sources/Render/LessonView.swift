import SwiftUI
import UIKit

/// v2.1 story-shaped lesson. Each card is a poster, not a slide.
///
/// Interaction (per design research):
/// - Tap the right two-thirds of the card to advance.
/// - Tap the left third to go back.
/// - Bottom ~80pt is a safe zone (no tap) — avoids accidental advances.
/// - Top hairline shows segmented progress (static, no animation).
/// - First-ever lesson shows a one-time "TAP TO CONTINUE" coachmark.
/// - Soft haptic on each advance.
/// - CLOSE in TopBar is always an escape.
struct LessonView: View {
    @Environment(\.dismiss) private var dismiss

    let lesson: LessonStub
    let onCompleted: () -> Void

    @State private var cardIndex: Int = {
        // Diagnostic: jump to a specific card. SIMCTL_CHILD_ARCLAB_LESSON_CARD=4
        if let raw = ProcessInfo.processInfo.environment["ARCLAB_LESSON_CARD"],
           let idx = Int(raw) {
            return max(0, idx - 1)   // 1-indexed input
        }
        return 0
    }()
    @State private var showCoachmark: Bool = false

    /// Tracks whether the user has seen the coachmark before, so it only
    /// fires once across the app's lifetime (not per-lesson).
    @AppStorage("arclab.lesson.coachmark.seen") private var coachmarkSeen: Bool = false

    private var currentCard: LessonContent.Card {
        lesson.cards[cardIndex]
    }

    private var isLastCard: Bool {
        cardIndex >= lesson.cards.count - 1
    }

    var body: some View {
        AdaptiveContentContainer(maxWidth: 700) {
            VStack(spacing: 0) {
                topBar
                progressHairline
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)

                ZStack {
                    // The story card.
                    cardContent
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .id(cardIndex)  // forces transition on every advance

                    // Invisible tap zones — left 33% goes back, right 67% advances.
                    // Bottom 80pt is excluded so accidental grip-line taps don't fire.
                    tapZones
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
        .overlay {
            if showCoachmark {
                coachmarkOverlay
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Show the coachmark on this lesson if the user has never seen it.
            if !coachmarkSeen {
                showCoachmark = true
            }
        }
    }

    private var topBar: some View {
        TopBar(
            leading: .back(label: "Back", action: { dismiss() }),
            trailing: .label("\(cardIndex + 1) / \(lesson.cards.count)")
        )
    }

    /// Segmented progress hairline — one tick per card, filled white for
    /// passed/current, mid-grey for upcoming. Static (no animation) so it
    /// reads as "where am I" not "how long until done."
    private var progressHairline: some View {
        HStack(spacing: 3) {
            ForEach(0..<lesson.cards.count, id: \.self) { i in
                Rectangle()
                    .fill(i <= cardIndex ? Color.arclabWhite : Color.arclabBorderGrey)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Card body — illustration (if present) on top, then headline,
    /// then optional body line, then optional math formula. Posters-first;
    /// type carries the weight when no illustration is provided.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.xl)

            if let illustration = currentCard.illustrationName,
               let uiImage = UIImage(named: illustration) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Sizing.cardRadius))
                    .padding(.bottom, Spacing.lg)
            }

            Text(currentCard.headline)
                .font(.anton(size: 44))
                .textCase(.uppercase)   // v3 playtest #PT5: Anton is a display face — always all caps.
                .foregroundColor(.arclabWhite)
                .lineLimit(4)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)

            if let body = currentCard.body {
                Spacer().frame(height: Spacing.md)
                Text(body)
                    .font(.barlowCondensed(size: 17, italic: true))
                    .foregroundColor(.arclabMidGrey)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let math = currentCard.math {
                Spacer().frame(height: Spacing.md)
                Text(math)
                    .font(.sfMono(size: 16))
                    .foregroundColor(.arclabWhite)
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: Sizing.cardRadius)
                            .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isLastCard {
                Spacer().frame(height: Spacing.xl)
                PrimaryButton(label: "Begin", action: handleComplete)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two invisible halves overlaid on the card area. Left third → back,
    /// right two-thirds → next. Excludes the bottom 80pt so PRACTICE button
    /// and accidental thumb-rest taps don't fire navigation.
    private var tapZones: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: geo.size.width * 0.33)
                    .contentShape(Rectangle())
                    .onTapGesture { handleBack() }
                Color.clear
                    .frame(width: geo.size.width * 0.67)
                    .contentShape(Rectangle())
                    .onTapGesture { handleAdvance() }
            }
            .frame(height: max(0, geo.size.height - 80))
        }
    }

    /// One-time onboarding affordance. Sits center-screen, fades out on
    /// first tap. Mid-grey + italic so it reads as a hint, not chrome.
    private var coachmarkOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: Spacing.xs) {
                Text("TAP TO CONTINUE")
                    .font(.sfMono(size: 11, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(2.5)
                Text("Tap left to go back.")
                    .font(.barlowCondensed(size: 13, italic: true))
                    .foregroundColor(.arclabMidGrey)
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Sizing.cardRadius)
                    .fill(Color.arclabCardBlack)
                    .overlay(
                        RoundedRectangle(cornerRadius: Sizing.cardRadius)
                            .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                    )
            )
            Spacer().frame(height: 120)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func handleAdvance() {
        dismissCoachmarkIfNeeded()
        if isLastCard {
            handleComplete()
        } else {
            withAnimation(.easeOut(duration: 0.22)) { cardIndex += 1 }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func handleBack() {
        dismissCoachmarkIfNeeded()
        guard cardIndex > 0 else { return }
        withAnimation(.easeOut(duration: 0.22)) { cardIndex -= 1 }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func handleComplete() {
        onCompleted()
    }

    private func dismissCoachmarkIfNeeded() {
        guard showCoachmark else { return }
        withAnimation(.easeOut(duration: 0.3)) { showCoachmark = false }
        coachmarkSeen = true
    }
}

#Preview {
    LessonView(
        lesson: BasketballCurriculum.chapters[0].lesson,
        onCompleted: {}
    )
}
