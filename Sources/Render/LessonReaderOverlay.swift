import SwiftUI
import UIKit

/// The expanding lesson reader. Replaces the old full-screen `LessonView`
/// push: tapping the lesson card on a chapter screen *expands* this reader in
/// place — the chapter title rises and pins at the top, the card grows into a
/// full-bleed poster reader, and the same left/right tap paging drives the
/// story cards. Closing collapses it back.
///
/// Hosted via the `.lessonReader(...)` modifier so every sport's `ChapterView`
/// and diagnostics get the identical interaction.
/// The host owns the `isPresented` binding and decides what to do
/// on close — `onClose(finished:)` reports whether the reader was finished
/// (reached the end / tapped Begin) vs. dismissed early, so the host applies
/// the first-play gating (mark the lesson read only on finish).
///
/// Motion mirrors the approved mockup: a scale-from-near-bottom + fade, on
/// Apple's default ease curve, ~0.42s. No `matchedGeometryEffect` — the card
/// and reader are separate layers; the chapter fades out behind the reader.
struct LessonReaderOverlay: View {
    let lesson: LessonContent
    /// Chapter title + index shown in the pinned header (the title that
    /// "moved up" from the chapter screen).
    let chapterTitle: String
    let chapterIndex: Int
    /// Reports dismissal. `finished == true` when the reader reached the last
    /// card (or the user tapped Begin); `false` on an early close (✕).
    let onClose: (_ finished: Bool) -> Void

    @State private var cardIndex: Int = 0
    @State private var showCoachmark: Bool = false
    @AppStorage("arclab.lesson.coachmark.seen") private var coachmarkSeen: Bool = false

    private var currentCard: LessonContent.Card { lesson.cards[cardIndex] }
    private var isLastCard: Bool { cardIndex >= lesson.cards.count - 1 }

    var body: some View {
        ZStack(alignment: .top) {
            Color.arclabBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                progressHairline
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)

                ZStack {
                    cardContent
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .id(cardIndex)   // re-trigger transition on each advance
                    tapZones
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
        // This reader is one fixed (non-scrolling) poster per card; cap the
        // largest accessibility steps so a card's text + full-size illustration
        // still fit together instead of the picture getting squeezed.
        .dynamicTypeSize(.large ... .accessibility1)
        .overlay {
            if showCoachmark {
                coachmarkOverlay.transition(.opacity)
            }
        }
        .onAppear {
            cardIndex = 0
            if !coachmarkSeen { showCoachmark = true }
        }
    }

    // MARK: - Pinned header (the chapter title, shrunk up)

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(chapterTitle.uppercased())
                    .font(.anton(size: 20))
                    .foregroundColor(.arclabWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("CHAPTER \(chapterIndex) · \(cardIndex + 1)/\(lesson.cards.count)")
                    .font(.sfMono(size: 10, weight: .medium))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }
            Spacer()
            Button(action: { close(finished: false) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.arclabMidGrey)
                    .frame(width: Sizing.minTapTarget, height: Sizing.minTapTarget)
                    .overlay(
                        Circle().stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Close lesson")
        }
        .padding(.top, Spacing.sm)
    }

    /// Segmented progress hairline — one tick per card, white up to current.
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

    // MARK: - Card body

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            if let illustration = currentCard.illustrationName,
               let uiImage = UIImage(named: illustration) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    // A stable size band + high layout priority so the
                    // illustration holds its size instead of being squeezed
                    // smaller when the text grows with Dynamic Type.
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 180, maxHeight: 220)
                    .layoutPriority(1)
                    .clipShape(RoundedRectangle(cornerRadius: Sizing.cardRadius))
                    .padding(.bottom, Spacing.lg)
                    // Decorative per the lesson style — the card text carries
                    // the content; never let VoiceOver read an asset name.
                    .accessibilityHidden(true)
            }

            textBlock
                // The invisible tap zones are gesture-only, so the card itself
                // is the screen-reader paging control: one combined element,
                // adjustable like a page control (swipe up/down = next/back),
                // with named actions for Voice Control and Switch Control.
                .accessibilityElement(children: .combine)
                .accessibilityValue("Card \(cardIndex + 1) of \(lesson.cards.count)")
                .accessibilityHint("Swipe up or down to change cards.")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: advance()
                    case .decrement: back()
                    @unknown default: break
                    }
                }
                .accessibilityAction(named: "Next card") { advance() }
                .accessibilityAction(named: "Previous card") { back() }

            if isLastCard {
                Spacer().frame(height: Spacing.xl)
                PrimaryButton(label: "Begin", action: { close(finished: true) })
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Headline + optional body + optional math — the text content of the
    /// card, grouped so VoiceOver reads it as one element.
    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(currentCard.headline)
                .font(.anton(size: 44))
                .textCase(.uppercase)
                .foregroundColor(.arclabWhite)
                .lineLimit(4)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)

            if let body = currentCard.body {
                Spacer().frame(height: Spacing.md)
                Text(body)
                    .font(.barlowCondensed(size: 17, italic: true))
                    .foregroundColor(.arclabWhite)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Left third → back, right two-thirds → next. Bottom 80pt excluded so the
    /// Begin button + thumb-rest taps don't fire navigation.
    private var tapZones: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: geo.size.width * 0.33)
                    .contentShape(Rectangle())
                    .onTapGesture { back() }
                Color.clear
                    .frame(width: geo.size.width * 0.67)
                    .contentShape(Rectangle())
                    .onTapGesture { advance() }
            }
            .frame(height: max(0, geo.size.height - 80))
        }
        // Gesture-only zones are invisible to assistive tech by nature;
        // hide them so they never shadow the card's paging actions.
        .accessibilityHidden(true)
    }

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

    private func advance() {
        dismissCoachmarkIfNeeded()
        if isLastCard {
            close(finished: true)
        } else {
            withAnimation(.easeOut(duration: 0.22)) { cardIndex += 1 }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            announceCurrentCard()
        }
    }

    private func back() {
        dismissCoachmarkIfNeeded()
        guard cardIndex > 0 else { return }
        withAnimation(.easeOut(duration: 0.22)) { cardIndex -= 1 }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        announceCurrentCard()
    }

    /// The card swap is an in-place transition VoiceOver can't see — speak
    /// the new card's content. Queued so the adjustable "Card N of M" value
    /// callout lands first.
    private func announceCurrentCard() {
        let card = lesson.cards[cardIndex]
        let body = card.body.map { " \($0)" } ?? ""
        Announce.post("\(card.headline).\(body)", priority: .queued)
    }

    private func close(finished: Bool) {
        dismissCoachmarkIfNeeded()
        onClose(finished)
    }

    private func dismissCoachmarkIfNeeded() {
        guard showCoachmark else { return }
        withAnimation(.easeOut(duration: 0.3)) { showCoachmark = false }
        coachmarkSeen = true
    }
}

// MARK: - Host modifier

extension View {
    /// Presents the expanding `LessonReaderOverlay` above the host chapter
    /// screen. The host fades/recedes behind it (apply `.blur`/`.opacity` keyed
    /// on the same binding if desired). Motion matches the approved mockup:
    /// scale-from-near-bottom + fade on Apple's default curve.
    func lessonReader(
        isPresented: Binding<Bool>,
        lesson: LessonContent,
        chapterTitle: String,
        chapterIndex: Int,
        onClose: @escaping (_ finished: Bool) -> Void
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                LessonReaderOverlay(
                    lesson: lesson,
                    chapterTitle: chapterTitle,
                    chapterIndex: chapterIndex,
                    onClose: onClose
                )
                .transition(
                    .scale(scale: 0.90, anchor: UnitPoint(x: 0.5, y: 0.72))
                        .combined(with: .opacity)
                )
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.42), value: isPresented.wrappedValue)
    }
}
