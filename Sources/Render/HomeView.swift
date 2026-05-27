import SwiftUI

/// v2.2 Home — landing surface after splash.
///
/// Composition:
/// 1. System header (ARCLAB / STREAK n) — quiet identity.
/// 2. TODAY card — featured/daily pick. Today this is the user's next
///    unplayed scenario (via NextUpFinder); once daily-pick video content
///    ships it becomes the curated card surface, no rename required.
/// 3. ALL SPORTS row — opens SportPicker → ChapterList per sport.
/// 4. PROFILE row — tertiary stats summary.
///
/// One door per intent. Copy on the TODAY card always matches what the
/// tap actually loads — no headline that lies about its destination.
struct HomeView: View {
    @Environment(PlayerProfileStore.self) private var profile

    /// Tap on the TODAY card. The router decides whether to present the
    /// scenario directly or push the chapter view (lesson-gating, no
    /// scenario authored, etc).
    let onTapTodayCard: (Chapter, String?) -> Void
    let onOpenSportPicker: () -> Void
    let onOpenProfile: () -> Void

    private var currentStreak: Int { profile.profile.currentStreak }
    private var iq: Int { SportsIQTier.iq(fromXP: profile.profile.totalXP) }
    private var tier: SportsIQTier { SportsIQTier.from(iq: iq) }
    private var badgesEarned: Int {
        BasketballCurriculum.chapters.filter { chapter in
            chapter.scenarioIDs.contains(where: {
                profile.profile.completedScenarios[ScenarioID($0)] != nil
            })
        }.count
    }

    private var todayPick: NextUp? {
        NextUpFinder.compute(
            chapters: BasketballCurriculum.chapters,
            completed: profile.profile.completedScenarios
        )
    }

    private var unlockedSportCount: Int {
        Sport.allCases.filter(\.isUnlocked).count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer().frame(height: Spacing.md)

            todayCard

            Spacer().frame(height: Spacing.xl)

            sportsRow

            Rectangle()
                .fill(Color.arclabBorderGrey.opacity(0.5))
                .frame(height: 1)

            profileRow

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        TopBar(leading: .word("ARCLAB"), trailing: .label("STREAK \(currentStreak)"))
    }

    // MARK: - TODAY card

    private var todayCard: some View {
        Button(action: handleTodayTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("TODAY")
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)

                Text(todayHeadline)
                    .font(.anton(size: 44))
                    .foregroundColor(.arclabWhite)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                Text(todaySubhead)
                    .font(.barlowCondensed(size: 16, italic: true))
                    .foregroundColor(.arclabMidGrey)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: Spacing.xs)

                HStack {
                    Spacer()
                    Text(todayCTA)
                        .font(.sfMono(size: 12, weight: .medium))
                        .foregroundColor(.arclabWhite)
                        .tracking(2.0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Sizing.cardRadius)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(todayPick == nil)
        .accessibilityLabel(todayAccessibilityLabel)
    }

    private var todayHeadline: String {
        guard let pick = todayPick else { return "ALL CAUGHT UP." }
        if pick.scenarioId != nil {
            return pick.chapter.title.uppercased() + "."
        }
        return "MORE COMING."
    }

    private var todaySubhead: String {
        guard let pick = todayPick else {
            return "Check back when new chapters land."
        }
        if pick.scenarioId != nil {
            return pick.chapter.subtitle
        }
        return "Chapter \(pick.chapter.index) — \(pick.chapter.title.lowercased()). In authoring."
    }

    private var todayCTA: String {
        guard let pick = todayPick else { return "—" }
        return pick.scenarioId != nil ? "PLAY  →" : "PREVIEW  →"
    }

    private var todayAccessibilityLabel: String {
        guard let pick = todayPick else { return "Today: nothing yet. Check back later." }
        if pick.scenarioId != nil {
            return "Today: \(pick.chapter.title). \(pick.chapter.subtitle) Tap to play."
        }
        return "Today: Chapter \(pick.chapter.index), \(pick.chapter.title). Coming soon. Tap to preview."
    }

    private func handleTodayTap() {
        guard let pick = todayPick else { return }
        onTapTodayCard(pick.chapter, pick.scenarioId)
    }

    // MARK: - Secondary rows

    private var sportsRow: some View {
        Button(action: onOpenSportPicker) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ALL SPORTS")
                        .font(.sfMono(size: 10))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)
                    Text("\(Sport.allCases.count) sports · \(unlockedSportCount) unlocked")
                        .font(.barlowCondensed(size: 16))
                        .foregroundColor(.arclabWhite)
                }
                Spacer()
                Text("→")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var profileRow: some View {
        Button(action: onOpenProfile) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.rawValue)
                        .font(.sfMono(size: 10))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)
                    Text("IQ \(iq) · \(badgesEarned) badge\(badgesEarned == 1 ? "" : "s")")
                        .font(.barlowCondensed(size: 16))
                        .foregroundColor(.arclabWhite)
                }
                Spacer()
                Text("→")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(
        onTapTodayCard: { _, _ in },
        onOpenSportPicker: {},
        onOpenProfile: {}
    )
    .environment(PlayerProfileStore.shared)
}
