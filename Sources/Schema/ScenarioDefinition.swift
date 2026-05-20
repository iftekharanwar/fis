import Foundation

/// Top-level shape of a scenario JSON file. One file = one scenario.
struct ScenarioDefinition: Codable, Sendable, Equatable {
    let schemaVersion: SemVer
    let scenarioId: ScenarioID
    let meta: MetaDefinition
    let situation: SituationDefinition
    let input: InputDefinition
    let simulation: SimulationConfig
    let outcome: OutcomeDefinition
    let hints: [HintDefinition]
    let solution: SolutionDefinition?         // v1.1 — older v1.0 scenarios may not have this
    let animations: AnimationsDefinition
    let voice: VoiceDefinition
    let smokeTest: SmokeTestDefinition

    /// Explicit keys so a leading `$comment` field in JSON (used for designer notes) is tolerated.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, scenarioId, meta, situation, input, simulation,
             outcome, hints, solution, animations, voice, smokeTest
    }
}
