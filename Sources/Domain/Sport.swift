import Foundation

/// Sport / physics-domain chapter. MVP ships with `.basketball` unlocked.
enum Sport: String, Sendable, CaseIterable, Identifiable, Codable {
    case basketball
    case soccer
    case pool
    case archery
    case f1

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basketball: return "BASKETBALL"
        case .soccer:     return "SOCCER"
        case .pool:       return "POOL"
        case .archery:    return "ARCHERY"
        case .f1:         return "F1"
        }
    }

    /// v3 playtest fix #PT1: sport subheads drop academic vocabulary
    /// (per CONCEPT.md voice rules — no "projectile motion", no "Magnus force").
    /// Replaced with the actual sport-vocab idea each domain teaches.
    var physicsDomainSubhead: String {
        switch self {
        case .basketball: return "THE ARC"
        case .soccer:     return "THE CURVE"
        case .pool:       return "THE BREAK"
        case .archery:    return "THE DISTANCE"
        case .f1:         return "THE TURN"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .basketball: return "basketball.fill"
        case .soccer:     return "soccerball"
        case .pool:       return "circle.grid.cross.fill"  // 8-ball stand-in
        case .archery:    return "target"
        case .f1:         return "car.fill"
        }
    }

    var isUnlocked: Bool {
        // Temporarily unlocked for testing the archery flow end-to-end.
        // Flip back to `self == .basketball` before shipping.
        true
    }

    static var sortedForPicker: [Sport] {
        Sport.allCases
    }

    /// Curriculum for this sport. Returns an empty list for sports whose
    /// chapters haven't been authored yet — the UI treats that as a
    /// "coming soon" state rather than an error.
    var chapters: [Chapter] {
        switch self {
        case .basketball: return BasketballCurriculum.chapters
        case .archery:    return ArcheryCurriculum.chapters
        case .soccer, .pool, .f1: return []
        }
    }
}
