import Foundation

/// v3 §7.5 — picks the next situation in the player's current mastery push.
/// Rules per locked spec:
///   1. Don't repeat any situation seen in the last 5 attempts (variation)
///   2. Bias toward situations the player hasn't seen this session
///   3. After 10+ attempts in the active level type, 30% interleave from
///      another unlocked level type (research-mandated, Rohrer & Taylor 2007)
///   4. After mastery threshold hit + ≥1 hard variant: one "victory lap"
///      situation before unlocking next level type (caller handles routing)
enum NextSituationPicker {

    struct Pick {
        let situationId: String   // ScenarioID raw value
        let levelType: LevelTypeID
        let isInterleaved: Bool
    }

    /// Pick the next situation for `activeLevelType` given:
    ///   - the seed pool for each level type (chapterId × levelType → [scenarioId])
    ///   - the player's mastery state
    ///   - a random source (injected for tests)
    static func nextPick(
        chapterId: String,
        activeLevelType: LevelTypeID,
        seedPool: [LevelTypeID: [String]],
        masteries: [String: LevelTypeMastery],
        difficultyBySituation: [String: DifficultyBucket] = [:],
        rng: inout some RandomNumberGenerator
    ) -> Pick? {
        let activeKey = MasteryService.key(chapterId: chapterId, levelType: activeLevelType)
        let activeMastery = masteries[activeKey]
        let activeAttemptCount = activeMastery?.attemptHistory.count ?? 0

        // Mastery requires a hard variant in the rolling six-attempt window.
        // Without this assist, a player can make clean shots indefinitely and
        // still not promote if random selection keeps missing the hard seeds.
        if let pool = seedPool[activeLevelType],
           let pick = chooseHardIfNeeded(
               pool,
               mastery: activeMastery,
               difficultyBySituation: difficultyBySituation,
               rng: &rng
           ) {
            return Pick(situationId: pick, levelType: activeLevelType, isInterleaved: false)
        }

        // Rule 3 — after 10+ attempts, 30% interleave from another unlocked type.
        if activeAttemptCount >= 10,
           Double.random(in: 0..<1, using: &rng) < 0.30 {
            let unlockedOthers = seedPool.keys
                .filter { $0 != activeLevelType }
                .filter { lt in
                    let k = MasteryService.key(chapterId: chapterId, levelType: lt)
                    let status = masteries[k]?.status ?? .locked
                    return status == .active || status == .mastered || status == .inReview
                }
            if let interleaveLT = unlockedOthers.randomElement(using: &rng),
               let pool = seedPool[interleaveLT],
               let pick = chooseFromPool(
                   pool,
                   avoiding: lastNSituationIds(masteries[MasteryService.key(chapterId: chapterId, levelType: interleaveLT)], n: 5),
                   difficultyBySituation: difficultyBySituation,
                   rng: &rng
               ) {
                return Pick(situationId: pick, levelType: interleaveLT, isInterleaved: true)
            }
            // Fall through to active level type if no eligible interleave.
        }

        // Active level type pick.
        guard let pool = seedPool[activeLevelType] else { return nil }
        guard let pick = chooseFromPool(
            pool,
            avoiding: lastNSituationIds(activeMastery, n: 5),
            difficultyBySituation: difficultyBySituation,
            rng: &rng
        ) else { return nil }
        return Pick(situationId: pick, levelType: activeLevelType, isInterleaved: false)
    }

    // MARK: - Helpers

    private static func lastNSituationIds(_ mastery: LevelTypeMastery?, n: Int) -> Set<String> {
        guard let mastery else { return [] }
        return Set(mastery.attemptHistory.suffix(n).map(\.situationId))
    }

    /// Choose a seed from `pool` that isn't in `avoiding`. Falls back to any
    /// seed in the pool if every option was recently seen.
    private static func chooseFromPool(
        _ pool: [String],
        avoiding: Set<String>,
        difficultyBySituation: [String: DifficultyBucket],
        rng: inout some RandomNumberGenerator
    ) -> String? {
        guard !pool.isEmpty else { return nil }
        let fresh = pool.filter { !avoiding.contains($0) }
        if let pick = fresh.randomElement(using: &rng) {
            return pick
        }
        // Last-5 covered every seed in a small pool — accept a repeat.
        return pool.randomElement(using: &rng)
    }

    /// If the player has filled five slots of the six-attempt mastery window
    /// without a hard variant, force the sixth pick to be hard when metadata
    /// is available. This keeps the mastery gate meaningful without letting
    /// random selection create a dead-feeling loop.
    private static func chooseHardIfNeeded(
        _ pool: [String],
        mastery: LevelTypeMastery?,
        difficultyBySituation: [String: DifficultyBucket],
        rng: inout some RandomNumberGenerator
    ) -> String? {
        guard let mastery else { return nil }
        let recent = Array(mastery.attemptHistory.suffix(LevelTypeMastery.masteryWindowSize - 1))
        guard recent.count == LevelTypeMastery.masteryWindowSize - 1 else { return nil }
        guard !recent.contains(where: { $0.difficultyBucket == .hard }) else { return nil }

        let hardPool = pool.filter { difficultyBySituation[$0] == .hard }
        guard !hardPool.isEmpty else { return nil }
        let recentlySeen = Set(recent.map(\.situationId))
        let freshHard = hardPool.filter { !recentlySeen.contains($0) }
        return freshHard.randomElement(using: &rng) ?? hardPool.randomElement(using: &rng)
    }
}
