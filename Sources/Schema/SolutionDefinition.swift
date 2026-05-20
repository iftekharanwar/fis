import Foundation

/// Post-level SOLUTION screen content.
struct SolutionDefinition: Codable, Sendable, Equatable {
    /// Empty array hides the THE MATH section.
    let equations: [String]

    /// One line per element in the SUBSTITUTING section.
    let workedSteps: [String]
}
