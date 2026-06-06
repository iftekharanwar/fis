import SwiftUI

/// v2.1 Chapter — lesson + scenario list. Anton bleed-left headline,
/// italic Barlow Condensed subhead, system rows below. No decorative
/// rules. Crimson reserved for miss state only.
struct ChapterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerProfileStore.self) private var profile

    let chapter: Chapter
    let onOpenScenario: (String) -> Void

    /// Drives the expanding lesson reader (replaces the old full-screen push).
    @State private var lessonExpanded = false

    /// True iff this chapter's lesson has been read at least once. Drives
    /// the first-play gating per CONCEPT_v2.1 §3 — scenarios are locked
    /// until the user consumes the lesson.
    private var lessonRead: Bool {
        profile.profile.completedLessons.contains(chapter.lesson.id)
    }

    private var practiceScenarioIDs: [String] {
        chapter.progressScenarioIDs
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.arclabBlack.ignoresSafeArea()

            // Poster background, anchored to the top, occupies roughly the
            // upper two-thirds. A vertical gradient fades it into pure
            // black at the bottom so the lesson card + scenario row sit
            // cleanly against the dark surface, no contrast fight.
            if let bgName = chapter.backgroundImageName,
               let uiImage = UIImage(named: bgName) {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height * 0.72)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.arclabBlack.opacity(0),
                                    Color.arclabBlack.opacity(0),
                                    Color.arclabBlack.opacity(0.85),
                                    Color.arclabBlack
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .ignoresSafeArea(edges: .top)

                // Top scrim — fades the very top of the image to near-
                // black so the TopBar's back button + chapter label don't
                // fight the formula text in the upper-left of the diagram.
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color.arclabBlack.opacity(0.95),
                            Color.arclabBlack.opacity(0.7),
                            Color.arclabBlack.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 110)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }

            AdaptiveContentContainer(maxWidth: 680) {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Chapter recedes behind the expanding reader.
            .opacity(lessonExpanded ? 0 : 1)
            .scaleEffect(lessonExpanded ? 0.96 : 1)
            .animation(.easeOut(duration: 0.42), value: lessonExpanded)
        }
        .lessonReader(
            isPresented: $lessonExpanded,
            lesson: chapter.lesson,
            chapterTitle: chapter.title,
            chapterIndex: chapter.index,
            onClose: { finished in
                if finished {
                    profile.mutate { $0.completedLessons.insert(chapter.lesson.id) }
                }
                lessonExpanded = false
            }
        )
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
        Button(action: { lessonExpanded = true }) {
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
                    .foregroundColor(.arclabWhite)
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
        .buttonStyle(PressableButtonStyle())
    }

    private var practiceList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if practiceScenarioIDs.isEmpty {
                emptyPractice
            } else if lessonRead {
                // Practice unlocks only after the lesson is read — the live
                // button appears on finish rather than sitting disabled first.
                ForEach(Array(practiceScenarioIDs.enumerated()), id: \.offset) { (idx, scenarioId) in
                    scenarioRow(index: idx + 1, scenarioId: scenarioId)
                }
            }
            // Lesson not yet read → nothing here; reading it reveals the button.
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.3), value: lessonRead)
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
        // Only rendered once the lesson is read (see practiceList), so the row
        // is always the live, tappable state — there is no locked variant.
        Button(action: { onOpenScenario(scenarioId) }) {
            HStack(spacing: Spacing.sm) {
                Text(String(format: "%02d", index))
                    .font(.sfMono(size: 13))
                    .foregroundColor(.arclabRimOrange)
                    .tracking(2.0)
                Text(scenarioTitle(for: scenarioId))
                    .font(.barlowCondensed(size: 20))
                    .foregroundColor(.arclabRimOrange)
                Spacer()
                Text("→")
                    .font(.sfMono(size: 17, weight: .medium))
                    .foregroundColor(.arclabRimOrange)
                    .tracking(2.0)
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 66)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.pillRadius, style: .continuous)
                    .stroke(Color.arclabRimOrange, lineWidth: Sizing.borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(scenarioTitle(for: scenarioId)). Tap to play.")
    }

    /// Look up a human-readable archetype title for the scenario. Dispatches
    /// by id prefix because archery + soccer scenarios live in separate
    /// static catalogs rather than the JSON-on-disk basketball pipeline.
    private func scenarioTitle(for scenarioId: String) -> String {
        if scenarioId.hasPrefix("arc-") {
            return ArcheryScenarioCatalog.title(for: scenarioId)
        }
        if scenarioId.hasPrefix("soc-") {
            return SoccerScenarioCatalog.title(for: scenarioId)
        }
        if let scenario = try? ScenarioLoader.load(ScenarioID(scenarioId)) {
            return scenario.meta.title
        }
        return scenarioId
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

#Preview {
    ChapterView(
        chapter: ArcheryCurriculum.chapters[0],
        onOpenScenario: { _ in }
    )
}

#Preview("Basketball Chapter") {
    ChapterView(
        chapter: BasketballCurriculum.chapters[0],
        onOpenScenario: { _ in }
    )
}
