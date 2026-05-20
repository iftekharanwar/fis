import Foundation

/// One rung of the hint ladder; player must reveal in order.
struct HintDefinition: Codable, Sendable, Equatable {
    let tier: Int            // 1-indexed
    let costPct: Int         // percent reduction in max score
    let body: String
}
