import XCTest
@testable import PhysicsGame

/// v3 §7.5 — NextSituationPicker behavior. Verifies the three variation
/// rules from GAME_v3_LOCKED.md §2.5/§2.6:
///   1. Don't repeat any seed seen in the last 5 attempts
///   2. After 10+ attempts in a level type, 30% of picks interleave from
///      another unlocked level type
///   3. Fallback to a repeat if all seeds were recently seen (small pool)
final class NextSituationPickerTests: XCTestCase {

    // MARK: - Helpers

    /// A 12-seed pool for find-θ (matches the live Ch 1 Level A pool size).
    private let thetaPool = (0..<12).map { "a-seed-\($0)" }
    /// Seeded RNG so picks are reproducible across runs.
    private var rng = SeededRNG(seed: 42)

    private func att(
        _ id: String,
        levelType: LevelTypeID = .findTheta,
        bucket: DifficultyBucket = .easy
    ) -> AttemptRecord {
        AttemptRecord(
            situationId: id, levelTypeId: levelType.rawValue,
            outcome: .swish, isFirstTry: true, hintsUsed: 0,
            timeToAnswerMs: 5_000, difficultyBucket: bucket,
            wasReview: false, wasInterleaved: false, timestamp: Date()
        )
    }

    private func mastery(_ key: String, attempts: [AttemptRecord], status: MasteryStatus) -> LevelTypeMastery {
        LevelTypeMastery(
            levelTypeId: key, attemptHistory: attempts, status: status,
            masteredAt: nil, lastPracticedAt: Date(),
            nextReviewAt: nil, easeFactor: 2.5
        )
    }

    // MARK: - Rule 1: no-repeat in last 5

    func test_avoids_seeds_seen_in_last_5_attempts() {
        // After 4 attempts (s0, s1, s2, s3), the next pick must be in {s4..s11}.
        let attempts: [AttemptRecord] = ["a-seed-0", "a-seed-1", "a-seed-2", "a-seed-3"].map { att($0) }
        let masteries: [String: LevelTypeMastery] = [
            MasteryService.key(chapterId: "ch1", levelType: .findTheta):
                mastery("ch1.A", attempts: attempts, status: .active)
        ]
        let seedPool: [LevelTypeID: [String]] = [.findTheta: thetaPool]
        // Repeat the pick many times — should never return one of the last 5.
        let recentSet: Set<String> = Set(attempts.map { $0.situationId })
        for _ in 0..<50 {
            let pick = NextSituationPicker.nextPick(
                chapterId: "ch1", activeLevelType: .findTheta,
                seedPool: seedPool, masteries: masteries, rng: &rng
            )
            XCTAssertNotNil(pick)
            XCTAssertFalse(recentSet.contains(pick!.situationId),
                "Picked \(pick!.situationId) which was in last-5")
        }
    }

    // MARK: - Rule 2: 30% interleave after 10 attempts

    func test_interleaves_from_other_levelType_after_10_attempts() {
        // 10 attempts on Level A. Level B is .active too.
        let aAttempts: [AttemptRecord] = (0..<10).map { att("a-seed-\($0)") }
        let masteries: [String: LevelTypeMastery] = [
            MasteryService.key(chapterId: "ch1", levelType: .findTheta):
                mastery("ch1.A", attempts: aAttempts, status: .active),
            MasteryService.key(chapterId: "ch1", levelType: .findV):
                mastery("ch1.B", attempts: [], status: .active)
        ]
        let seedPool: [LevelTypeID: [String]] = [
            .findTheta: thetaPool,
            .findV: (0..<12).map { "b-seed-\($0)" }
        ]
        var interleaveCount = 0
        let trials = 200
        for _ in 0..<trials {
            if let pick = NextSituationPicker.nextPick(
                chapterId: "ch1", activeLevelType: .findTheta,
                seedPool: seedPool, masteries: masteries, rng: &rng
            ) {
                if pick.isInterleaved { interleaveCount += 1 }
            }
        }
        // Spec says ~30%. Allow 20-40% wiggle room for stochastic.
        let rate = Double(interleaveCount) / Double(trials)
        XCTAssertGreaterThan(rate, 0.20, "Interleave rate \(rate) too low")
        XCTAssertLessThan(rate, 0.45, "Interleave rate \(rate) too high")
    }

    // MARK: - Rule 3: no interleave before 10 attempts

    func test_no_interleave_before_10_attempts() {
        let aAttempts: [AttemptRecord] = (0..<5).map { att("a-seed-\($0)") }
        let masteries: [String: LevelTypeMastery] = [
            MasteryService.key(chapterId: "ch1", levelType: .findTheta):
                mastery("ch1.A", attempts: aAttempts, status: .active),
            MasteryService.key(chapterId: "ch1", levelType: .findV):
                mastery("ch1.B", attempts: [], status: .active)
        ]
        let seedPool: [LevelTypeID: [String]] = [
            .findTheta: thetaPool,
            .findV: (0..<12).map { "b-seed-\($0)" }
        ]
        for _ in 0..<50 {
            if let pick = NextSituationPicker.nextPick(
                chapterId: "ch1", activeLevelType: .findTheta,
                seedPool: seedPool, masteries: masteries, rng: &rng
            ) {
                XCTAssertEqual(pick.levelType, .findTheta,
                    "Should never interleave before 10 attempts")
                XCTAssertFalse(pick.isInterleaved)
            }
        }
    }

    func test_forces_hard_variant_when_mastery_window_needs_it() {
        let attempts: [AttemptRecord] = (0..<5).map { att("easy-\($0)") }
        let masteries: [String: LevelTypeMastery] = [
            MasteryService.key(chapterId: "ch1", levelType: .findTheta):
                mastery("ch1.A", attempts: attempts, status: .active)
        ]
        let seedPool: [LevelTypeID: [String]] = [
            .findTheta: ["easy-5", "easy-6", "hard-0", "hard-1"]
        ]
        let difficultyBySituation: [String: DifficultyBucket] = [
            "easy-5": .easy,
            "easy-6": .easy,
            "hard-0": .hard,
            "hard-1": .hard
        ]

        for _ in 0..<20 {
            let pick = NextSituationPicker.nextPick(
                chapterId: "ch1",
                activeLevelType: .findTheta,
                seedPool: seedPool,
                masteries: masteries,
                difficultyBySituation: difficultyBySituation,
                rng: &rng
            )
            XCTAssertNotNil(pick)
            XCTAssertEqual(difficultyBySituation[pick!.situationId], .hard)
            XCTAssertFalse(pick!.isInterleaved)
        }
    }

    // MARK: - Rule 4: fallback to repeat when pool exhausted

    func test_accepts_repeat_when_all_pool_recently_seen() {
        // 3-seed pool, last 5 attempts cover them all (with one repeat).
        let smallPool: [String] = ["x", "y", "z"]
        let attempts: [AttemptRecord] = ["x", "y", "z", "x", "y"].map { att($0) }
        let masteries: [String: LevelTypeMastery] = [
            MasteryService.key(chapterId: "ch1", levelType: .findTheta):
                mastery("ch1.A", attempts: attempts, status: .active)
        ]
        let pick = NextSituationPicker.nextPick(
            chapterId: "ch1", activeLevelType: .findTheta,
            seedPool: [.findTheta: smallPool], masteries: masteries, rng: &rng
        )
        XCTAssertNotNil(pick, "Should return a repeat rather than nil when pool is exhausted")
        XCTAssertTrue(smallPool.contains(pick!.situationId))
    }
}

// MARK: - Seeded RNG for deterministic tests

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
