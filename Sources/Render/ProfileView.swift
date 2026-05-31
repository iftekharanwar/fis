import SwiftUI

/// v2.1 Profile — three layered metrics per CONCEPT_v2.1 §8: streak (habit),
/// IQ + tier (status), chapter badges (curriculum). Reads from the live
/// player profile; doesn't own any state of its own.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerProfileStore.self) private var profile

    var body: some View {
        AdaptiveContentContainer(maxWidth: 640) {
            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        Spacer().frame(height: Spacing.lg)

                        iqHeroBlock
                        streakBand
                        chapterBadges

                        Spacer().frame(height: Spacing.xxl)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
    }

    private var topBar: some View {
        TopBar(
            leading: .back(label: "Home", action: { dismiss() }),
            trailing: .label("PROFILE")
        )
    }

    // MARK: - IQ hero block

    private var iqHeroBlock: some View {
        let iq = SportsIQTier.iq(fromXP: profile.profile.totalXP)
        let tier = SportsIQTier.from(iq: iq)
        let nextTier = tier.next

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("SPORTS IQ")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)

            Text(tier.rawValue)
                .font(.anton(size: 56))
                .foregroundColor(.arclabWhite)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                Text("\(iq)")
                    .font(.sfMono(size: 24, weight: .medium))
                    .foregroundColor(.arclabWhite)
                Text("IQ")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                if let nextTier {
                    Text("\(nextTier.threshold - iq) TO \(nextTier.rawValue)")
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text("MAX TIER")
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Streak band

    private var streakBand: some View {
        let streak = profile.profile.currentStreak
        let atRisk = isStreakAtRisk()

        return HStack(alignment: .lastTextBaseline, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("STREAK")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text("\(streak)")
                        .font(.anton(size: 48))
                        .foregroundColor(.arclabWhite)
                    Text(streak == 1 ? "day" : "days")
                        .font(.barlowCondensed(size: 16, italic: true))
                        .foregroundColor(.arclabMidGrey)
                }
            }
            Spacer()
            if atRisk && streak > 0 {
                // v3 audit fix #7: crimson is sacred to miss state. Streak-at-risk
                // uses white/mid-grey treatment per CONCEPT.md palette rules.
                Text("AT RISK")
                    .font(.sfMono(size: 10, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(2.0)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .overlay(
                        RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                            .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Streak is "at risk" if it's > 0 but the user hasn't played today yet.
    private func isStreakAtRisk() -> Bool {
        guard let last = profile.profile.lastPlayedDate else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: last) != cal.startOfDay(for: Date())
    }

    // MARK: - Chapter badges

    private var chapterBadges: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("CHAPTER BADGES")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)

            VStack(spacing: Spacing.xs) {
                ForEach(BasketballCurriculum.chapters) { chapter in
                    badgeRow(for: chapter)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A chapter is "earned" once at least one scenario in it has a
    /// completion record in the profile. v1's `ScenarioRecord` exists per
    /// scenario id — checking any-match approximates "you've made progress
    /// here." Real mastery thresholds arrive with the scoring system.
    private func isEarned(_ chapter: Chapter) -> Bool {
        for scenarioId in chapter.scenarioIDs {
            if profile.profile.completedScenarios[ScenarioID(scenarioId)] != nil {
                return true
            }
        }
        return false
    }

    private func badgeRow(for chapter: Chapter) -> some View {
        // v3 playtest #PT3: respect chapter lock state. Unshippable chapters
        // (Ch 2-5 in v3 — no level-type seeds) show as locked, matching
        // ChapterListView's lock affordance instead of looking identical to
        // unearned-but-available rows.
        let locked = !chapter.isShippableInV3
        let earned = isEarned(chapter)
        let textColor: Color = locked
            ? .arclabBorderGrey
            : (earned ? .arclabWhite : .arclabBorderGrey)
        return HStack(spacing: Spacing.sm) {
            Text(String(format: "%02d", chapter.index))
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .opacity(locked ? 0.4 : 1.0)
                .tracking(2.0)
                .frame(width: 28, alignment: .leading)

            Text(chapter.title.uppercased())
                .font(.sfMono(size: 13, weight: .medium))
                .foregroundColor(textColor)
                .opacity(locked ? 0.5 : 1.0)
                .tracking(1.5)

            Spacer()

            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.arclabMidGrey)
                    .accessibilityLabel("Locked")
            } else {
                Text(earned ? "✓" : "—")
                    .font(.sfMono(size: 13))
                    .foregroundColor(earned ? .arclabWhite : .arclabBorderGrey)
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, Spacing.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Sizing.cardRadius)
                .stroke(locked
                        ? Color.arclabBorderGrey.opacity(0.25)
                        : (earned ? Color.arclabBorderGrey : Color.arclabBorderGrey.opacity(0.4)),
                        lineWidth: Sizing.borderWidth)
        )
    }
}

#Preview {
    ProfileView()
}
