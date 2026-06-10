import SwiftUI
import UIKit

/// The Daily Question — one bite-size physics question a day. Two states in one
/// screen: **guess** (tap an option) → **reveal** (the answer, the one-line why,
/// a fun fact). Answering counts toward the streak. Once answered, it stays in
/// the revealed state until tomorrow.
///
/// Reached as a push from the Home "DAILY" card — not a tab.
struct DailyQuestionView: View {
    @Environment(PlayerProfileStore.self) private var profile

    var onClose: (() -> Void)? = nil

    /// Today's question — frozen at first init via `@State`. The card derives
    /// from profile state that *answering mutates*, which makes SwiftUI
    /// re-evaluate this view's initializer; holding the question in `@State`
    /// means that re-init keeps the original value instead of swapping in a
    /// different question underneath the revealed answer.
    @State private var question: DailyQuestion?

    @State private var revealed: Bool = false
    @State private var pick: Int? = nil
    @State private var answerHaptic: Int = 0
    /// IQ earned on this answer (nil until answered; stays nil on a re-open, so
    /// the reward only ever shows once).
    @State private var iqGain: Int? = nil
    @State private var showGain: Bool = false

    init(onClose: (() -> Void)? = nil, question: DailyQuestion? = DailyQuestionPicker.todays()) {
        self.onClose = onClose
        self._question = State(initialValue: question)
    }

    var body: some View {
        AdaptiveContentContainer(maxWidth: 640) {
            VStack(spacing: 0) {
                TopBar(
                    leading: .back(label: "Home", action: { onClose?() }),
                    trailing: .label("DAILY")
                )

                if let question {
                    content(question)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
        .dynamicTypeSize(.large ... .accessibility5)
        .gameHaptic(trigger: answerHaptic) { _, _ in
            guard let pick, let question else { return .impact(weight: .light) }
            return question.isDisplayPickCorrect(pick) ? .success : .warning
        }
        .onAppear(perform: restoreIfAnswered)
    }

    // MARK: - Content

    private func content(_ q: DailyQuestion) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: Spacing.md)

                eyebrow(q)
                artwork(q)

                Text(q.prompt)
                    .font(.anton(size: revealed ? 24 : 30))
                    .foregroundColor(.arclabWhite)
                    .lineLimit(revealed ? 3 : nil)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)

                Spacer().frame(height: Spacing.lg)

                VStack(spacing: Spacing.xs) {
                    ForEach(q.displayOptions.indices, id: \.self) { idx in
                        optionRow(q, idx)
                    }
                }

                if revealed {
                    revealBlock(q)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: Spacing.lg)
                footer(q)
                Spacer().frame(height: Spacing.xxl)
            }
        }
    }

    private func eyebrow(_ q: DailyQuestion) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle().fill(Color.arclabRimOrange).frame(width: 4, height: 4)
            Text("\(q.sport.displayName) · \(q.principle.uppercased())")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private func artwork(_ q: DailyQuestion) -> some View {
        // Shows the bespoke illustration once it's bundled; until then the card
        // is clean type-only (no placeholder), so it ships before any art.
        if let name = q.imageName, UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .padding(.top, Spacing.md)
                // Curated alt text when the art informs; hidden otherwise —
                // VoiceOver must never read the raw asset filename.
                .accessibilityLabel(q.imageAlt ?? "")
                .accessibilityHidden(q.imageAlt == nil)
        }
    }

    // MARK: - Options

    private func optionRow(_ q: DailyQuestion, _ idx: Int) -> some View {
        let isAnswer = idx == q.displayAnswerIndex
        let isPick = pick == idx
        let showCorrect = revealed && isAnswer
        let showWrongPick = revealed && isPick && !isAnswer

        let textColor: Color = showCorrect ? .arclabRimOrange
            : (revealed ? .arclabMidGrey : .arclabWhite)
        let borderColor: Color = showCorrect ? .arclabRimOrange
            : (showWrongPick ? .arclabMidGrey : .arclabBorderGrey)
        let rowOpacity: Double = (revealed && !isAnswer && !isPick) ? 0.4 : 1.0

        return Button(action: { choose(q, idx) }) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text(q.displayOptions[idx])
                    .font(.barlowCondensed(size: 16))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showCorrect {
                    Text("✓").font(.sfMono(size: 15, weight: .medium)).foregroundColor(.arclabRimOrange)
                } else if showWrongPick {
                    Text("✗").font(.sfMono(size: 15)).foregroundColor(.arclabMidGrey)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: Sizing.minTapTarget)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.pillRadius)
                    .stroke(borderColor, lineWidth: showCorrect ? 1.5 : Sizing.borderWidth)
            )
            .opacity(rowOpacity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(haptic: .impact(weight: .medium)))
        .disabled(revealed)
    }

    // MARK: - Reveal

    private func revealBlock(_ q: DailyQuestion) -> some View {
        let correct = pick.map(q.isDisplayPickCorrect) ?? false
        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            HStack(alignment: .firstTextBaseline) {
                Text(correct ? "RIGHT." : "NOT QUITE.")
                    .font(.anton(size: 40))
                    .foregroundColor(.arclabWhite)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: Spacing.sm)
                if let iqGain {
                    Text("+\(iqGain) IQ")
                        .font(.sfMono(size: 14, weight: .medium))
                        .foregroundColor(.arclabRimOrange)
                        .tracking(1.0)
                        .opacity(showGain ? 1 : 0)
                        .offset(y: showGain ? 0 : 12)
                }
            }

            Text(q.why)
                .font(.barlowCondensed(size: 17))
                .foregroundColor(.arclabMidGrey)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.sm)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("FUN FACT")
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabRimOrange)
                    .tracking(2.0)
                Text(q.funFact)
                    .font(.barlowCondensed(size: 16, italic: true))
                    .foregroundColor(.arclabWhite)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Spacing.lg)
            .padding(.top, Spacing.xs)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.arclabBorderGrey).frame(height: 1)
            }
        }
        .announceOnAppear {
            "\(correct ? "Right." : "Not quite.") \(q.why) Fun fact: \(q.funFact)"
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(_ q: DailyQuestion) -> some View {
        if revealed {
            VStack(spacing: Spacing.sm) {
                HStack {
                    Text("STREAK \(profile.profile.currentStreak)")
                        .font(.sfMono(size: 11)).foregroundColor(.arclabMidGrey).tracking(1.5)
                    Spacer()
                    Text("BACK TOMORROW")
                        .font(.sfMono(size: 11)).foregroundColor(.arclabMidGrey).tracking(1.5)
                }
                SecondaryButton(label: "Done", action: { onClose?() })
            }
        } else {
            HStack {
                Text("TAP YOUR GUESS")
                    .font(.sfMono(size: 11)).foregroundColor(.arclabMidGrey).tracking(1.5)
                Spacer()
                HStack(spacing: Spacing.xs) {
                    Circle().stroke(Color.arclabRimOrange, lineWidth: 1.5).frame(width: 8, height: 8)
                    Text("\(profile.profile.currentStreak) DAY STREAK")
                        .font(.sfMono(size: 11)).foregroundColor(.arclabWhite).tracking(1.5)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Text("NOTHING NEW TODAY.")
                .font(.anton(size: 28)).foregroundColor(.arclabWhite)
            Text("Come back tomorrow.")
                .font(.barlowCondensed(size: 16, italic: true)).foregroundColor(.arclabMidGrey)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func choose(_ q: DailyQuestion, _ idx: Int) {
        guard !revealed else { return }
        let correct = q.isDisplayPickCorrect(idx)
        pick = idx
        iqGain = SportsIQTier.iq(fromXP: correct ? PlayerProfile.dailyCorrectXP : PlayerProfile.dailyWrongXP)
        answerHaptic += 1
        profile.mutate { $0.recordDailyAnswer(pick: idx, questionID: q.id, correct: correct) }
        withAnimation(.easeOut(duration: 0.3)) { revealed = true }
        // Pop the IQ gain in just after the answer reveals.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeOut(duration: 0.4)) { showGain = true }
        }
    }

    /// If the player already answered today, open straight into the revealed
    /// state with their pick — they can re-read the why and fun fact, but can't
    /// re-answer until tomorrow.
    private func restoreIfAnswered() {
        guard profile.profile.hasAnsweredDailyToday() else { return }
        pick = profile.profile.lastDailyAnsweredPick
        revealed = true
    }
}

#Preview {
    DailyQuestionView()
        .environment(PlayerProfileStore())
}
