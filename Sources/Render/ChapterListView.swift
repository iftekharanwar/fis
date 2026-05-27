import SwiftUI

/// Chapter list for a single sport. Reached from SportPicker after the
/// user chooses which sport to dive into. Empty list (sport authored
/// but no chapters yet) renders as a "coming soon" surface.
struct ChapterListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerProfileStore.self) private var profile

    let sport: Sport
    let onOpenChapter: (Chapter) -> Void

    private var chapters: [Chapter] { sport.chapters }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer().frame(height: Spacing.xl)

            heading

            Spacer().frame(height: Spacing.lg)

            ScrollView(.vertical, showsIndicators: false) {
                if chapters.isEmpty {
                    emptyState
                } else {
                    chapterList
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
        .statusBarHidden(false)
    }

    private var topBar: some View {
        TopBar(
            leading: .back(label: "Sports", action: { dismiss() }),
            trailing: .label("CHAPTERS")
        )
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(sport.displayName + ".")
                .font(.anton(size: 32))
                .foregroundColor(.arclabWhite)

            Text(sport.physicsDomainSubhead)
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chapterList: some View {
        VStack(spacing: 0) {
            ForEach(chapters) { chapter in
                ChapterListRow(
                    chapter: chapter,
                    status: status(for: chapter),
                    onTap: { onOpenChapter(chapter) }
                )
                if chapter.id != chapters.last?.id {
                    Rectangle()
                        .fill(Color.arclabBorderGrey)
                        .frame(height: 1)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("COMING SOON.")
                .font(.anton(size: 28))
                .foregroundColor(.arclabWhite)
            Text("Chapters for this sport are in authoring.")
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabMidGrey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.lg)
    }

    private func status(for chapter: Chapter) -> ChapterStatus {
        if chapter.scenarioIDs.isEmpty { return .soon }
        let done = chapter.scenarioIDs.filter {
            profile.profile.completedScenarios[ScenarioID($0)] != nil
        }.count
        if done == 0 { return .ready }
        if done >= chapter.scenarioIDs.count { return .done }
        return .inProgress(done: done, total: chapter.scenarioIDs.count)
    }
}

enum ChapterStatus: Equatable {
    case ready
    case inProgress(done: Int, total: Int)
    case done
    case soon

    var label: String {
        switch self {
        case .ready:                       return "READY"
        case .inProgress(let d, let t):    return "\(d) / \(t)"
        case .done:                        return "DONE ✓"
        case .soon:                        return "SOON"
        }
    }
}

private struct ChapterListRow: View {
    let chapter: Chapter
    let status: ChapterStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text(String(format: "%02d", chapter.index))
                    .font(.sfMono(size: 14))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                    .frame(width: 32, alignment: .leading)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(chapter.title.uppercased())
                        .font(.anton(size: 28))
                        .foregroundColor(.arclabWhite)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(chapter.subtitle)
                        .font(.barlowCondensed(size: 14, italic: true))
                        .foregroundColor(.arclabMidGrey)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(status.label)
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                    .padding(.top, 6)
            }
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chapter \(chapter.index). \(chapter.title). \(chapter.subtitle). \(status.label).")
    }
}

#Preview {
    ChapterListView(
        sport: .basketball,
        onOpenChapter: { _ in }
    )
    .environment(PlayerProfileStore.shared)
}
