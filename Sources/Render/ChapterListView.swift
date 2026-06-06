import SwiftUI
import UIKit

/// Chapter list — the bridge between SportPicker and each sport's chapter view.
/// Shows every chapter in a sport as a row; tapping a shippable chapter
/// pushes to the chapter detail screen. Locked chapters render dimmed with
/// `lock.fill` and "Locked. Future chapter." until they ship.
struct ChapterListView: View {
    @Environment(\.dismiss) private var dismiss

    let sport: Sport
    let chapters: [Chapter]
    let onSelectChapter: (Chapter) -> Void

    var body: some View {
        // Real status-bar height from the window, read once on the main actor.
        let windowTopInset = keyWindowTopInset
        return GeometryReader { proxy in
            // A view pushed into a NavigationStack with the nav bar hidden can
            // have its top safe-area inset collapsed to ~0 on some iOS versions,
            // which slides the back chip under the status bar. Add back exactly
            // the missing clearance; this resolves to 0 when the view's own
            // inset is already correct, so working devices are unchanged.
            let topClearance = max(0, windowTopInset - proxy.safeAreaInsets.top)

            AdaptiveContentContainer(maxWidth: 640) {
                VStack(spacing: 0) {
                    topBar

                    // Scrollable so the list stays reachable at large Dynamic
                    // Type sizes — the rows grow tall and would otherwise
                    // overflow the screen with no way to scroll down to them.
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer().frame(height: Spacing.md)
                            heading
                            Spacer().frame(height: Spacing.lg)
                            chapterList
                            Spacer().frame(height: Spacing.xl)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, topClearance)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.arclabBlack.ignoresSafeArea())
        }
        // The Anton display titles can't grow without bound on this dense list;
        // cap the largest accessibility steps so the layout scales and scrolls
        // instead of breaking. Text still grows substantially up to the cap.
        .dynamicTypeSize(.large ... .accessibility2)
    }

    /// The active key window's top safe-area inset — i.e. the true status-bar
    /// height, read from the scene rather than the (possibly collapsed) view
    /// inset. Used to restore top clearance when a hidden-nav-bar
    /// NavigationStack zeroes the pushed view's own top inset.
    @MainActor
    private var keyWindowTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
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
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("Five lenses on the same game.")
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabMidGrey)
                .fixedSize(horizontal: false, vertical: true)
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

    /// Sport-aware chapter unlock check. Basketball unlocks when the current
    /// release has level-type practice rows; Archery/Soccer unlock when they
    /// have at least one authored scenario.
    private func isChapterUnlocked(_ chapter: Chapter) -> Bool {
        switch chapter.sport {
        case .basketball, .archery, .soccer:
            return chapter.hasPlayablePractice
        case .pool:
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 44, alignment: .leading)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(chapter.title.uppercased())
                        .font(.anton(size: 28))
                        .foregroundColor(isUnlocked ? .arclabWhite : .arclabMidGrey)
                        .opacity(isUnlocked ? 1.0 : 0.5)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)

                    // Unlocked captions read as primary copy, not a muted label:
                    // the mid-grey italic was too low-contrast for some readers,
                    // so lift it toward white. Locked rows stay muted.
                    Text(isUnlocked ? chapter.subtitle : "Locked. Future chapter.")
                        .font(.barlowCondensed(size: 13, italic: true))
                        .foregroundColor(isUnlocked ? .arclabWhite.opacity(0.85) : .arclabMidGrey)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.xs)

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
