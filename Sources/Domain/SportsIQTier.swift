import Foundation

/// Sports IQ tier ladder per CONCEPT_v2.1 §8. IQ score is derived from
/// totalXP (10 XP = 1 IQ). The tier is derived from the IQ score via the
/// `from(iq:)` lookup. Each tier has a user-visible label and a threshold.
enum SportsIQTier: String, CaseIterable, Sendable {
    case watcher           = "WATCHER"
    case student           = "STUDENT"
    case scholar           = "SCHOLAR"
    case studentOfTheGame  = "STUDENT OF THE GAME"
    case architect         = "ARCHITECT"

    /// Minimum IQ to earn this tier. Inclusive.
    var threshold: Int {
        switch self {
        case .watcher:           return 0
        case .student:           return 50
        case .scholar:           return 200
        case .studentOfTheGame:  return 500
        case .architect:         return 1000
        }
    }

    /// The next tier up, or nil if already at the top.
    var next: SportsIQTier? {
        let all = SportsIQTier.allCases
        guard let idx = all.firstIndex(of: self), idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }

    /// Look up the highest tier the given IQ qualifies for.
    static func from(iq: Int) -> SportsIQTier {
        SportsIQTier.allCases.reversed().first(where: { iq >= $0.threshold }) ?? .watcher
    }

    /// Convenience: convert XP into IQ via the 10:1 mapping.
    static func iq(fromXP xp: Int) -> Int {
        xp / 10
    }
}
