import Foundation

struct SituationDefinition: Codable, Sendable, Equatable {
    let outcome: String
    let questionRevealed: String
    let variables: [VariableSpec]

    struct VariableSpec: Codable, Sendable, Equatable {
        let symbol: String           // "d", "h_h", "g"
        let value: Double
        let unit: String
        let label: String
    }
}
