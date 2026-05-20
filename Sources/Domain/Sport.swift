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

    var physicsDomainSubhead: String {
        switch self {
        case .basketball: return "PROJECTILE MOTION"
        case .soccer:     return "MAGNUS FORCE"
        case .pool:       return "ELASTIC COLLISIONS"
        case .archery:    return "RANGE \u{00B7} DRAG"
        case .f1:         return "FRICTION \u{00B7} TRACTION"
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
        self == .basketball
    }

    static var sortedForPicker: [Sport] {
        Sport.allCases
    }
}
