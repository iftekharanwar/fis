import Foundation

/// CI runs the simulation with `answer` and asserts the predicate fires as `expectedOutcome`.
struct SmokeTestDefinition: Codable, Sendable, Equatable {
    let answer: [String: Double]
    let expectedOutcome: ExpectedOutcome
    let expectedFlavor: String?

    enum ExpectedOutcome: String, Codable, Sendable {
        case success
        case miss
    }
}
