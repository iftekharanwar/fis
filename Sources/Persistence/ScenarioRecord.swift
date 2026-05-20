import Foundation

/// Per-scenario player state, keyed by `ScenarioID` inside `PlayerProfile.completedScenarios`.
struct ScenarioRecord: Codable, Sendable, Hashable {
    var bestScore: Int

    /// Persists across app kill so an interruption mid-struggle doesn't reset SOLUTION unlock.
    var attemptCounter: Int

    /// Hint tiers (1-indexed) revealed in the current attempt; reset on each new attempt.
    var hintTiersUsedThisAttempt: [Int]

    /// Cumulative score-cap penalty from hints this session; persists across attempts within the session.
    var scoreCapPenaltyThisAttempt: Int

    /// True after any attempt following an initial successful completion.
    var replayAfterSuccessFlag: Bool

    /// True if the player has ever achieved a first-try clean SWISH; suppresses ARCLAB watermark.
    var watermarkEarnedFlag: Bool

    /// Powers v1.1 pre-fill setting; nil in MVP.
    var lastAttemptInputs: [String: Double]?

    var firstCompletedAt: Date?

    /// Updated on every scenario open; used to pick "next scenario" recommendation.
    var lastPlayedAt: Date

    static func newRecord(now: Date = Date()) -> ScenarioRecord {
        ScenarioRecord(
            bestScore: 0,
            attemptCounter: 1,
            hintTiersUsedThisAttempt: [],
            scoreCapPenaltyThisAttempt: 0,
            replayAfterSuccessFlag: false,
            watermarkEarnedFlag: false,
            lastAttemptInputs: nil,
            firstCompletedAt: nil,
            lastPlayedAt: now
        )
    }
}
