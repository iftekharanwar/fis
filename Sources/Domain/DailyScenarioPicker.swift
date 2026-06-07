import Foundation

/// v3 §HomeView — daily scenario picker for the TODAY hero card.
///
/// Replaces the hardcoded "always bb-1-baseline" wiring with a pick that
/// reflects where the player actually is. Three-tier priority:
///
///   1. **Review-due** — if any mastered level type has decayed to .inReview
///      (per spaced-repetition), surface a seed from that type. A daily
///      refresh is exactly the daily card's job.
///   2. **In-progress active level type** — pick a fresh seed from the
///      level type the player is currently grinding on.
///   3. **Brand-new player** — first chapter's first released practice seed.
///
/// The pick is deterministic per (player, calendar day) — same player sees
/// the same daily card all day, then it rotates at local midnight. The
/// determinism comes from seeding the RNG with `(day-of-year XOR profile
/// hash)`, so two players on the same day still see different seeds.
struct DailyScenarioPicker {

    struct Pick: Equatable {
        let scenarioId: String
        let chapterId: String
        let kind: Kind   // for analytics / future TODAY-card label theming

        enum Kind: String, Equatable {
            case review        // refresher pick from .inReview level type
            case active        // fresh seed from currently active level type
            case opener        // first scenario for a brand-new player
        }
    }

    /// Pick today's scenario for the given player.
    /// - Parameter today: usually `Date()`. Pass a fixed date in tests.
    /// - Parameter chapters: the curriculum to draw from. Picks only from
    ///   chapters with released practice so we never surface a placeholder.
    static func pick(
        for profile: PlayerProfile,
        chapters: [Chapter],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Pick {
        let masteries = profile.levelTypeMasteries
        let shippable = chapters.filter(\.hasPlayablePractice)
        let fallbackScenarioId = shippable.first?.progressScenarioIDs.first ?? "bb-c-wing-throw"
        // Fallback target — guarantees a valid pick even with empty state.
        let fallback = Pick(
            scenarioId: fallbackScenarioId,
            chapterId: shippable.first?.id ?? "bb-ch1-arc",
            kind: .opener
        )

        guard let firstChapter = shippable.first else { return fallback }

        // Seed an RNG from (day-of-year XOR mastery-state hash) so two
        // players with different progress see different daily seeds even
        // on the same day, and any single player sees the same seed all day.
        let dayOrdinal = calendar.ordinality(of: .day, in: .year, for: today) ?? 0
        let masteryHash = masteries.keys.sorted().joined().hashValue
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(dayOrdinal &* 31 &+ masteryHash)))

        // Tier 1 — review-due. Use the existing review queue logic.
        let reviewDue = MasteryService.dueForReview(in: profile, now: today)
        if !reviewDue.isEmpty {
            for masteryKey in reviewDue.shuffled(using: &rng) {
                // mastery key format = "<chapterId>.<levelTypeRawValue>"
                guard let dotIdx = masteryKey.firstIndex(of: ".") else { continue }
                let chapterId = String(masteryKey[..<dotIdx])
                let ltRaw = String(masteryKey[masteryKey.index(after: dotIdx)...])
                guard let chapter = shippable.first(where: { $0.id == chapterId }),
                      let lt = LevelTypeID(rawValue: ltRaw),
                      chapter.releasedPracticeLevelTypes.contains(lt) else { continue }
                let seeds = chapter.releasedPracticeSeeds(for: lt)
                if let pick = seeds.randomElement(using: &rng) {
                    return Pick(scenarioId: pick, chapterId: chapterId, kind: .review)
                }
            }
        }

        // Tier 2 — pick from the player's *active* level type: the first
        // unlocked level type in chapter order that isn't yet mastered.
        for chapter in shippable {
            for lt in chapter.releasedPracticeLevelTypes {
                let key = MasteryService.key(chapterId: chapter.id, levelType: lt)
                let status = masteries[key]?.status ?? .active
                if status != .mastered {
                    let seeds = chapter.releasedPracticeSeeds(for: lt)
                    if let pick = seeds.randomElement(using: &rng) {
                        return Pick(scenarioId: pick, chapterId: chapter.id, kind: .active)
                    }
                }
            }
        }

        // Tier 3 — everything mastered (rare end-state). Re-surface the
        // opener as a victory lap; the review tier should usually catch
        // this case but it's possible everything is fresh-mastered today.
        let openerLevelType = firstChapter.releasedPracticeLevelTypes.first ?? .findD
        let seeds = firstChapter.releasedPracticeSeeds(for: openerLevelType)
        if let pick = seeds.randomElement(using: &rng) {
            return Pick(scenarioId: pick, chapterId: firstChapter.id, kind: .opener)
        }
        return fallback
    }
}

/// Deterministic RNG seeded by Daily picker. Same seed → same pick. Used
/// across the picker so the player sees today's card identically all day.
private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
