import SwiftUI

/// Chapter list — the bridge between SportPicker and LevelTypePickerView.
/// Shows every chapter in a sport as a row; tapping a shippable chapter
/// pushes to its LevelTypePickerView. Ch 2-5 render in a locked state
/// (dimmed + lock.fill, "Locked. Future chapter.") until they ship.
struct ChapterListView: View {
    @Environment(\.dismiss) private var dismiss

    let sport: Sport
    let chapters: [Chapter]
    let onSelectChapter: (Chapter) -> Void

    var body: some View {
        AdaptiveContentContainer(maxWidth: 640) {
            VStack(spacing: 0) {
                topBar

                Spacer().frame(height: Spacing.xl)

                heading

                Spacer().frame(height: Spacing.lg)

                ScrollView(.vertical, showsIndicators: false) {
                    chapterList
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
    }

    private var topBar: some View {
        // When only one sport is unlocked, the router skips SportPicker, so
        // "← Sports" would back to a list-of-one we never showed. Label the
        // chip with the upstream surface the router is actually returning to.
        let backLabel = Sport.allCases.filter(\.isUnlocked).count > 1 ? "Sports" : "Home"
        return TopBar(
            leading: .back(label: backLabel, action: { dismiss() }),
            trailing: .label(sport.displayName.uppercased())
        )
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("FIVE CHAPTERS.")
                .font(.anton(size: 32))
                .foregroundColor(.arclabWhite)

            Text("Five lenses on the same game.")
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabMidGrey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chapterList: some View {
        VStack(spacing: 0) {
            ForEach(chapters) { chapter in
                ChapterRow(
                    chapter: chapter,
                    isUnlocked: isChapterUnlocked(chapter),
                    onTap: {
                        if isChapterUnlocked(chapter) { onSelectChapter(chapter) }
                    }
                )
                if chapter.id != chapters.last?.id {
                    Rectangle()
                        .fill(Color.arclabBorderGrey)
                        .frame(height: 1)
                }
            }
        }
    }

    /// Sport-aware chapter unlock check. Basketball uses v3 mastery state
    /// (isShippableInV3 — all 4 level types must have seed pools). Archery
    /// and soccer don't use level types yet, so a chapter is unlocked iff
    /// it has at least one scenario authored.
    private func isChapterUnlocked(_ chapter: Chapter) -> Bool {
        switch chapter.sport {
        case .basketball:
            return chapter.isShippableInV3
        case .archery, .soccer:
            return !chapter.scenarioIDs.isEmpty
        case .pool, .f1:
            return false
        }
    }
}

private struct ChapterRow: View {
    let chapter: Chapter
    let isUnlocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Text("\(chapter.index)")
                    .font(.anton(size: 36))
                    .foregroundColor(.arclabMidGrey)
                    .opacity(isUnlocked ? 1.0 : 0.4)
                    .frame(width: 44, alignment: .leading)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(chapter.title.uppercased())
                        .font(.anton(size: 28))
                        .foregroundColor(isUnlocked ? .arclabWhite : .arclabMidGrey)
                        .opacity(isUnlocked ? 1.0 : 0.5)
                        .lineLimit(2)

                    Text(isUnlocked ? chapter.subtitle : "Locked. Future chapter.")
                        .font(.barlowCondensed(size: 13, italic: true))
                        .foregroundColor(.arclabMidGrey)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.arclabMidGrey)
                        .accessibilityLabel("Locked")
                }
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Chapter \(chapter.index). \(chapter.title). \(chapter.subtitle). \(isUnlocked ? "Unlocked." : "Locked.")")
    }
}
