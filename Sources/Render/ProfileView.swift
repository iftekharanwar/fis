import SwiftUI

/// Profile — a calm, digestible read on the player's progress.
///
/// Three plain blocks, top to bottom:
///   1. Sports IQ hero — one big number, the tier it earns, a progress bar
///      to the next tier, and a one-line plain-language explainer (so the
///      number isn't mysterious).
///   2. Two stat tiles — STREAK (habit) and SCENARIOS played (volume).
///   3. By sport — chapters explored per unlocked sport, so an archery- or
///      soccer-first player sees THEIR progress, not a wall of empty
///      basketball badges.
///
/// Reads from the live player profile; owns no state of its own.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerProfileStore.self) private var profile

    var body: some View {
        AdaptiveContentContainer(maxWidth: 640) {
            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        Spacer().frame(height: Spacing.md)

                        iqHero
                        statTiles
                        bySport

                        Spacer().frame(height: Spacing.xxl)
                    }
                    .padding(.top, Spacing.sm)
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

    // MARK: - Sports IQ hero

    private var iqHero: some View {
        let iq = SportsIQTier.iq(fromXP: profile.profile.totalXP)
        let tier = SportsIQTier.from(iq: iq)
        let next = tier.next

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPORTS IQ")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)

            // The number is the hero; the tier sits under it as a badge so a
            // long tier name ("STUDENT OF THE GAME") never fights the figure.
            Text("\(iq)")
                .font(.anton(size: 72))
                .foregroundColor(.arclabWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(tier.rawValue)
                .font(.sfMono(size: 14, weight: .medium))
                .foregroundColor(.arclabWhite)
                .tracking(1.5)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                progressBar(fraction: tierFraction(iq: iq, tier: tier, next: next))
                Text(tierCaption(iq: iq, next: next))
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.top, Spacing.xxs)

            Text("Your read on the game. It climbs every time you call a shot — right or wrong — and see why it flew.")
                .font(.barlowCondensed(size: 15, italic: true))
                .foregroundColor(.arclabMidGrey)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Progress through the current tier toward the next one, 0…1. Full bar
    /// at the top tier (nothing left to climb).
    private func tierFraction(iq: Int, tier: SportsIQTier, next: SportsIQTier?) -> Double {
        guard let next else { return 1.0 }
        let span = Double(next.threshold - tier.threshold)
        guard span > 0 else { return 1.0 }
        return max(0, min(1, Double(iq - tier.threshold) / span))
    }

    private func tierCaption(iq: Int, next: SportsIQTier?) -> String {
        guard let next else { return "TOP TIER REACHED" }
        return "\(next.threshold - iq) IQ TO \(next.rawValue)"
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        let streak = profile.profile.currentStreak
        let atRisk = isStreakAtRisk() && streak > 0
        let played = profile.profile.completedScenarios.count

        return HStack(spacing: Spacing.sm) {
            statTile(
                label: "STREAK",
                value: "\(streak)",
                unit: streak == 1 ? "day" : "days",
                flag: atRisk ? "AT RISK" : nil
            )
            statTile(
                label: "SCENARIOS",
                value: "\(played)",
                unit: "played",
                flag: nil
            )
        }
    }

    private func statTile(label: String, value: String, unit: String, flag: String?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(label)
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer(minLength: 0)
                if let flag {
                    // White/grey treatment — crimson stays sacred to the miss
                    // state per the palette rules.
                    Text(flag)
                        .font(.sfMono(size: 9, weight: .medium))
                        .foregroundColor(.arclabWhite)
                        .tracking(1.5)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                                .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                        )
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: Spacing.xxs) {
                Text(value)
                    .font(.anton(size: 40))
                    .foregroundColor(.arclabWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit)
                    .font(.barlowCondensed(size: 15, italic: true))
                    .foregroundColor(.arclabMidGrey)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Sizing.cardRadius)
                .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
        )
    }

    // MARK: - By sport

    private var bySport: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("BY SPORT")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                Text("CHAPTERS")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }

            VStack(spacing: 0) {
                ForEach(Array(unlockedSports.enumerated()), id: \.element) { idx, sport in
                    if idx > 0 {
                        Rectangle()
                            .fill(Color.arclabBorderGrey.opacity(0.4))
                            .frame(height: Sizing.borderWidth)
                    }
                    sportRow(sport)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.cardRadius)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sportRow(_ sport: Sport) -> some View {
        let p = sportProgress(sport)
        let fraction = p.total > 0 ? Double(p.done) / Double(p.total) : 0
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(sport.displayName)
                    .font(.sfMono(size: 13, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(1.5)
                Spacer()
                Text("\(p.done) / \(p.total)")
                    .font(.sfMono(size: 13, weight: .medium))
                    .foregroundColor(p.done > 0 ? .arclabWhite : .arclabMidGrey)
            }
            progressBar(fraction: fraction, height: 4)
        }
        .padding(Spacing.sm)
        .frame(minHeight: 44)
    }

    /// Per-sport progress as (chapters explored, playable chapters). A
    /// chapter counts as explored once any released practice item has a
    /// completion record. Empty/unreleased chapters are excluded so the
    /// denominator reflects what's actually playable today.
    private func sportProgress(_ sport: Sport) -> (done: Int, total: Int) {
        let playable = sport.chapters.filter(\.hasPlayablePractice)
        let done = playable.filter { chapter in
            chapter.progressScenarioIDs.contains { profile.profile.completedScenarios[ScenarioID($0)] != nil }
        }.count
        return (done, playable.count)
    }

    private var unlockedSports: [Sport] {
        Sport.allCases.filter { sport in
            sport.isUnlocked && sport.chapters.contains { $0.hasPlayablePractice }
        }
    }

    // MARK: - Shared bits

    /// Thin editorial progress bar — white fill on a faint track.
    private func progressBar(fraction: Double, height: CGFloat = 6) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.arclabBorderGrey.opacity(0.4))
                Capsule()
                    .fill(Color.arclabWhite)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((max(0, min(1, fraction)) * 100).rounded())) percent")
    }

    /// Streak is "at risk" if it's > 0 but the user hasn't played today yet.
    private func isStreakAtRisk() -> Bool {
        guard let last = profile.profile.lastPlayedDate else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: last) != cal.startOfDay(for: Date())
    }
}

#Preview {
    ProfileView()
        .environment(PlayerProfileStore())
}
