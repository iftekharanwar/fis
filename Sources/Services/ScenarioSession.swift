import Foundation
import Observation
import CoreGraphics

/// Per-scenario session state. `attemptCounter` persists across app kills; everything else is in-memory.
@Observable
@MainActor
final class ScenarioSession {

    let scenarioId: ScenarioID
    let definition: ScenarioDefinition

    var currentPhase: Phase = .idle

    /// Appended in `SKScene.update(_:)`; retained through OUTCOME for the failed-arc render; cleared on REPLAY.
    var snapshotHistory: [ProjectileSnapshot] = []

    /// Pre-computed once at init from the scenario's ghost answer; read by MISSED for the ideal-arc render.
    let cachedGhostTrajectory: [CGPoint]

    /// Powers v1.1 pre-fill; nil in MVP.
    var lastSubmittedAnswer: ProjectileAnswer?

    var matchedMissCategory: String?
    var matchedSuccessFlavor: String?

    /// Mirrored from profile; persists across app kills.
    private(set) var attemptCounter: Int

    private let profileStore: PlayerProfileStore

    init(definition: ScenarioDefinition, profileStore: PlayerProfileStore) {
        self.scenarioId = definition.scenarioId
        self.definition = definition
        self.profileStore = profileStore

        let record = profileStore.profile.completedScenarios[definition.scenarioId]
        self.attemptCounter = record?.attemptCounter ?? 1

        self.cachedGhostTrajectory = Self.computeGhostTrajectory(for: definition)

        profileStore.mutate { profile in
            var rec = profile.completedScenarios[definition.scenarioId] ?? ScenarioRecord.newRecord()
            rec.lastPlayedAt = Date()
            profile.completedScenarios[definition.scenarioId] = rec
        }
    }

    /// Call from view's `.onDisappear`. Swift 6 strict isolation forbids a MainActor
    /// deinit reading state, so this must be invoked manually.
    func flush() {
        let id = scenarioId
        let count = attemptCounter
        profileStore.mutate { profile in
            var rec = profile.completedScenarios[id] ?? ScenarioRecord.newRecord()
            rec.attemptCounter = count
            profile.completedScenarios[id] = rec
        }
    }

    /// Persists so a mid-struggle app kill doesn't reset SOLUTION unlock or diagnostic scaling.
    func incrementAttempt() {
        attemptCounter += 1
        let id = scenarioId
        let count = attemptCounter
        profileStore.mutate { profile in
            var rec = profile.completedScenarios[id] ?? ScenarioRecord.newRecord()
            rec.attemptCounter = count
            profile.completedScenarios[id] = rec
        }
    }

    func resetForNewAttempt() {
        snapshotHistory.removeAll(keepingCapacity: true)
        matchedMissCategory = nil
        matchedSuccessFlavor = nil
        currentPhase = .idle
    }

    private static func computeGhostTrajectory(for definition: ScenarioDefinition) -> [CGPoint] {
        guard let ghost = definition.outcome.ghostArc else { return [] }
        switch definition.simulation {
        case .projectile2D(_, let params):
            let answer = ProjectileAnswer(
                thetaDegrees: ghost.answer["theta"] ?? 0,
                velocity: ghost.answer["v"] ?? 0
            )
            let snapshots = Projectile2DModule().headlessRun(
                params: params,
                answer: answer,
                fixedDt: params.fixedDtSeconds
            )
            return snapshots.map { $0.ballPosition }
        }
    }
}

extension ScenarioSession {
    enum Phase: Sendable, Equatable {
        case idle
        case action
        case outcome(Resolution)

        enum Resolution: Sendable, Equatable {
            case success(flavor: String)
            case miss(category: String)
        }
    }
}
