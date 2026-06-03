import Foundation

/// Outcome the soccer scene emits when the ball crosses the goal line.
/// Lives in its own file because both the SpriteKit scene (which emits
/// it from the physics resolution) and the SwiftUI verdict view (which
/// reads it to pick copy) depend on it — keeping the type free of any
/// rendering framework avoids a dependency loop between the two.
enum SoccerOutcome: Equatable, Sendable {
    case goal
    case savedByKeeper
    case wideOfPost
    case overTheBar

    var didScore: Bool {
        if case .goal = self { return true } else { return false }
    }

    /// Verb shown on the verdict screen.
    var verb: String {
        switch self {
        case .goal:          return "GOAL."
        case .savedByKeeper: return "SAVED."
        case .wideOfPost:    return "WIDE."
        case .overTheBar:    return "OVER."
        }
    }
}
