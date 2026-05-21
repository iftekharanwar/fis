import SwiftUI

/// v2.1 Home — landing surface after splash.
///
/// Composition:
/// 1. System header (ARCLAB / STREAK 0) — quiet identity.
/// 2. Hero ScenarioPreviewCard — illustrated scene + headline + subhead +
///    "CALL IT" affordance. Whole card is the primary tap target.
/// 3. CONTINUE row — secondary curriculum progression hook.
/// 4. PROFILE row — tertiary stats summary.
///
/// Visual hierarchy comes from card vs row vs row — not from type weight
/// alone. Crimson stays reserved for miss state.
struct HomeView: View {
    @Environment(PlayerProfileStore.self) private var profile

    let onPickDailyScenario: () -> Void
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

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer().frame(height: Spacing.md)

            heroCard

            Spacer().frame(height: Spacing.xl)

            continueRow

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

    // MARK: - Hero card

    private var heroCard: some View {
        ScenarioPreviewCard(
            scenarioId: "bb-01-freethrow",
            titleAbove: "TODAY",
            bigTitle: "THE FLAT-ARC CORNER THREE.",
            subhead: "A guard releasing from the corner. Fast release. Low arc.",
            actionLabel: "CALL IT",
            onTap: onPickDailyScenario
        )
    }

    // MARK: - Secondary rows

    private var continueRow: some View {
        Button(action: onOpenSportPicker) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONTINUE")
                        .font(.sfMono(size: 10))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)
                    Text("Basketball · Ch 1 · The arc")
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
        onPickDailyScenario: {},
        onOpenSportPicker: {},
        onOpenProfile: {}
    )
}
