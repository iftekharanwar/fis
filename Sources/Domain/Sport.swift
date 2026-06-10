import Foundation

/// Sport / physics-domain chapter. MVP ships with `.basketball` unlocked.
enum Sport: String, Sendable, CaseIterable, Identifiable, Codable {
    case basketball
    case soccer
    case archery
    case formula1
    case pool

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basketball: return "BASKETBALL"
        case .soccer:     return "SOCCER"
        case .archery:    return "ARCHERY"
        case .formula1:   return "FORMULA 1"
        case .pool:       return "POOL"
        }
    }

    /// v3 playtest fix #PT1: sport subheads drop academic vocabulary
    /// (per CONCEPT.md voice rules — no "projectile motion", no "Magnus force").
    /// Replaced with the actual sport-vocab idea each domain teaches.
    var physicsDomainSubhead: String {
        switch self {
        case .basketball: return "THE ARC"
        case .soccer:     return "THE CURVE"
        case .archery:    return "THE DISTANCE"
        case .formula1:   return "THE LIMIT"
        case .pool:       return "THE BREAK"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .basketball: return "basketball.fill"
        case .soccer:     return "soccerball"
        case .archery:    return "target"
        case .formula1:   return "flag.checkered"
        case .pool:       return "8.circle.fill"
        }
    }

    /// Which sports have shippable content. Pool remains a stub (no
    /// curriculum, no scenarios) — it renders in the picker as "coming soon"
    /// rather than a tappable row that leads to a dead end.
    var isUnlocked: Bool {
        switch self {
        case .basketball, .archery, .soccer, .formula1: return true
        case .pool:                                     return false
        }
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
        case .soccer:     return SoccerCurriculum.chapters
        case .formula1:   return F1Curriculum.chapters
        case .pool:       return []
        }
    }
}
