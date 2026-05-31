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
    @Environment(\.horizontalSizeClass) private var hSizeClass

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
        GeometryReader { geo in
            let ctx = LayoutContext.resolve(
                horizontalSizeClass: hSizeClass,
                size: geo.size,
                safeArea: geo.safeAreaInsets
            )
            Group {
                if ctx.isRegular && ctx.isWide {
                    twoColumnLayout      // iPad landscape: hero + side panel
                } else {
                    singleColumnLayout   // iPhone + iPad portrait (centered on iPad)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.arclabBlack.ignoresSafeArea())
        }
    }

    /// iPhone + iPad portrait. On iPad the column is capped + centered so the
    /// hero card and rows don't stretch the full width.
    private var singleColumnLayout: some View {
        AdaptiveContentContainer(maxWidth: 600) {
            VStack(spacing: 0) {
                header
                Spacer().frame(height: Spacing.md)
                heroCard
                Spacer().frame(height: Spacing.xl)
                continueRow
                // Bumped from 0.5 → 1.0 opacity per audit rec — at 50% the
                // hairline barely separated the two near-identical rows and the
                // user couldn't tell CONTINUE from PROFILE at a glance.
                Rectangle()
                    .fill(Color.arclabBorderGrey)
                    .frame(height: 1)
                profileRow
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    /// iPad landscape: the hero daily card takes the left two-thirds; the
    /// header + CONTINUE/PROFILE rows stack in a right-side panel.
    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                heroCard
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                header
                Spacer().frame(height: Spacing.xl)
                continueRow
                Rectangle()
                    .fill(Color.arclabBorderGrey)
                    .frame(height: 1)
                profileRow
                Spacer()
            }
            .frame(width: 380)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
    }

    // MARK: - Header

    private var header: some View {
        TopBar(leading: .word("ARCLAB"), trailing: .label("STREAK \(currentStreak)"))
    }

    // MARK: - Hero card

    /// Today's daily pick. Same player + same calendar day → same scenario.
    /// Recomputed on every body evaluation but DailyScenarioPicker is pure
    /// and cheap (~ O(chapters × levelTypes)) so this is fine.
    private var dailyPick: DailyScenarioPicker.Pick {
        DailyScenarioPicker.pick(
            for: profile.profile,
            chapters: BasketballCurriculum.chapters
        )
    }

    private var heroCard: some View {
        // Derive the card's headline + subhead from the picked scenario's
        // voice.intro block — keeps card honest about what the tap delivers.
        // Falls back to generic free-throw copy if the load fails, since the
        // card has to render something and a silent break would be worse.
        let pick = dailyPick
        let scenario = try? ScenarioLoader.load(ScenarioID(pick.scenarioId))
        let bigTitle = scenario?.voice.intro.headline ?? "THE FREE THROW."
        let subhead = scenario?.voice.intro.subhead
            ?? "Standard release. Solve the angle and speed."
        return ScenarioPreviewCard(
            scenarioId: pick.scenarioId,
            titleAbove: "TODAY",
            bigTitle: bigTitle,
            subhead: subhead,
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
                    Text(continueLabel)
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

    /// Furthest-along chapter the player can keep working on. v3 ship only
    /// has Ch 1 actually shippable (Ch 2-5 carry empty seed pools), so we
    /// surface the first chapter that's both shippable AND not yet fully
    /// mastered. Falls back to the last shippable chapter once everything
    /// is cleared. Derived from curriculum so it can't drift from spec.
    private var continueLabel: String {
        let chapters = BasketballCurriculum.chapters
        let target: Chapter = chapters.first { chapter in
            guard chapter.isShippableInV3 else { return false }
            let key = MasteryService.key(chapterId: chapter.id, levelType: .findBoth)
            return profile.profile.levelTypeMasteries[key]?.status != .mastered
        } ?? chapters.last(where: { $0.isShippableInV3 }) ?? chapters[0]
        return "Basketball · Ch \(target.index) · \(target.title)"
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
