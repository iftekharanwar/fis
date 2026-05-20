import Foundation

/// File-backed, versioned player profile.
struct PlayerProfile: Codable, Sendable, Equatable {
    /// Bumped on any breaking schema change.
    var profileSchemaVersion: Int

    /// Cached rank rung; `totalXP` is authoritative. Call `recomputeRank()` after XP mutations.
    var rankRung: RankRung

    /// Monotonically grows; drives `rankRung`.
    var totalXP: Int

    var completedScenarios: [ScenarioID: ScenarioRecord]

    /// True until the first START tap on the first scenario; gates IntroView's first-run choreography.
    var firstRun: Bool

    /// True until the first scenario is played; drives INTRO's theatrical reveal.
    var firstEverScenario: Bool

    /// Counter 0…3; increments each INTRO appearance that showed the briefing-hint dot.
    var firstThreeScenariosBriefingHintSeen: Int

    /// Drives RootView first-launch routing (false → OnboardingView, true → SportPickerView).
    var hasSeenOnboarding: Bool

    static func newProfile() -> PlayerProfile {
        PlayerProfile(
            profileSchemaVersion: PlayerProfile.currentSchemaVersion,
            rankRung: RankRung.from(xp: 0),
            totalXP: 0,
            completedScenarios: [:],
            firstRun: true,
            firstEverScenario: true,
            firstThreeScenariosBriefingHintSeen: 0,
            hasSeenOnboarding: false
        )
    }

    static let currentSchemaVersion = 2

    mutating func recomputeRank() {
        self.rankRung = RankRung.from(xp: totalXP)
    }
}
