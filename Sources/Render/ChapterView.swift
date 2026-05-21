import SwiftUI

/// v2.1 Chapter — lesson + scenario list. Anton bleed-left headline,
/// italic Barlow Condensed subhead, system rows below. No decorative
/// rules. Crimson reserved for miss state only.
struct ChapterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerProfileStore.self) private var profile

    let chapter: Chapter
    let onOpenLesson: (LessonStub) -> Void
    let onOpenScenario: (String) -> Void

    /// True iff this chapter's lesson has been read at least once. Drives
    /// the first-play gating per CONCEPT_v2.1 §3 — scenarios are locked
    /// until the user consumes the lesson.
    private var lessonRead: Bool {
        profile.profile.completedLessons.contains(chapter.lesson.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer().frame(height: Spacing.xxl)

            heading

            Spacer().frame(height: Spacing.sm)

            subhead

            Spacer()

            lessonRow

            Spacer().frame(height: Spacing.md)

            practiceList
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
    }

    private var topBar: some View {
        TopBar(
            leading: .back(label: chapter.sport.displayName, action: { dismiss() }),
            trailing: .label("CHAPTER \(chapter.index)")
        )
    }

    private var heading: some View {
        Text(chapter.title.uppercased())
            .font(.anton(size: 64))
            .foregroundColor(.arclabWhite)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subhead: some View {
        Text(chapter.subtitle)
            .font(.barlowCondensed(size: 16, italic: true))
            .foregroundColor(.arclabMidGrey)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var lessonRow: some View {
        Button(action: { onOpenLesson(chapter.lesson) }) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("LESSON · \(chapter.lesson.estimatedReadSeconds)s")
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)

                Text(chapter.lesson.title)
                    .font(.anton(size: 22))
                    .foregroundColor(.arclabWhite)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Text(chapter.lesson.oneLiner)
                    .font(.barlowCondensed(size: 14, italic: true))
                    .foregroundColor(.arclabMidGrey)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Spacer().frame(height: Spacing.xxs)

                HStack {
                    Spacer()
                    Text(lessonRead ? "READ  ✓" : "READ  →")
                        .font(.sfMono(size: 12, weight: .medium))
                        .foregroundColor(.arclabWhite)
                        .tracking(2.0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Sizing.cardRadius)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var practiceList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if chapter.scenarioIDs.isEmpty {
                emptyPractice
            } else {
                ForEach(Array(chapter.scenarioIDs.enumerated()), id: \.offset) { (idx, scenarioId) in
                    scenarioRow(index: idx + 1, scenarioId: scenarioId)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyPractice: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("PRACTICE")
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
            Text("Scenarios for this chapter arrive soon.")
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabMidGrey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 44)
    }

    private func scenarioRow(index: Int, scenarioId: String) -> some View {
        let locked = !lessonRead
        return Button(action: { if !locked { onOpenScenario(scenarioId) } }) {
            HStack(spacing: Spacing.sm) {
                Text(String(format: "%02d", index))
                    .font(.sfMono(size: 11))
                    .foregroundColor(locked ? .arclabBorderGrey : .arclabMidGrey)
                    .tracking(2.0)
                Text(scenarioTitle(for: scenarioId))
                    .font(.barlowCondensed(size: 16))
                    .foregroundColor(locked ? .arclabBorderGrey : .arclabWhite)
                Spacer()
                Text(locked ? "READ FIRST" : "→")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(locked
            ? "\(scenarioTitle(for: scenarioId)). Locked — read the lesson first."
            : "\(scenarioTitle(for: scenarioId)). Tap to play.")
    }

    /// Look up a human-readable archetype title for the scenario. Falls back
    /// to a humanized form of the id if the scenario isn't loadable yet
    /// (e.g. authoring stage).
    private func scenarioTitle(for scenarioId: String) -> String {
        if let scenario = try? ScenarioLoader.load(ScenarioID(scenarioId)) {
            return scenario.meta.title
        }
        // Fallback: humanize the id, e.g. "bb-freethrow-001" → "Bb Freethrow 001"
        return scenarioId
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

#Preview {
    ChapterView(
        chapter: BasketballCurriculum.chapters[0],
        onOpenLesson: { _ in },
        onOpenScenario: { _ in }
    )
}
