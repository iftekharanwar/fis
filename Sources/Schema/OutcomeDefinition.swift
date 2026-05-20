import Foundation

struct OutcomeDefinition: Codable, Sendable, Equatable {
    let successPredicate: String      // module-registered, e.g. "BALL_INTO_HOOP"
    let scoreFunction: String         // app-registered, e.g. "EFFICIENCY_DECAY"
    let baseScore: Int
    let successFlavors: [SuccessFlavor]
    let missCategories: [MissCategory]
    let ghostArc: GhostArc?

    struct SuccessFlavor: Codable, Sendable, Equatable {
        let id: String                // "SWISH" | "GLASS" | "RIM_DROP" | …
        let when: String              // DSL expression on final state
        let scoreMultiplier: Double
    }

    struct MissCategory: Codable, Sendable, Equatable {
        let id: String
        let when: String
        /// Attempt-keyed subheads; keys are "1", "2", "3+"; falls back to "1".
        let subheadVariants: [String: String]
    }

    struct GhostArc: Codable, Sendable, Equatable {
        let source: Source            // "computed" deferred
        let answer: [String: Double]
        let description: String?

        enum Source: String, Codable, Sendable {
            case authored
            case computed
        }
    }
}
