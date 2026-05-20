import Foundation

/// Seven-tier rank progression; tier gates content, rung is what's displayed.
enum Rank: String, CaseIterable, Codable, Sendable, Comparable {
    case rookie     = "ROOKIE"
    case starter    = "STARTER"
    case pro        = "PRO"
    case allStar    = "ALL-STAR"
    case mvp        = "MVP"
    case hallOfFame = "HALL OF FAME"
    case legend     = "LEGEND"

    /// Ordering = canonical advancement order.
    static func < (lhs: Rank, rhs: Rank) -> Bool {
        guard let li = Rank.allCases.firstIndex(of: lhs),
              let ri = Rank.allCases.firstIndex(of: rhs) else { return false }
        return li < ri
    }

    /// Three chrome-treatment bands across the seven tiers.
    enum Chrome: String, Sendable {
        case rookieChrome
        case proChrome
        case legendChrome
    }

    var chrome: Chrome {
        switch self {
        case .rookie, .starter:              return .rookieChrome
        case .pro, .allStar, .mvp:           return .proChrome
        case .hallOfFame, .legend:           return .legendChrome
        }
    }
}

enum SubTier: String, CaseIterable, Codable, Sendable {
    case I, II, III
}

/// A rung on the 21-rung ladder (7 tiers × 3 sub-tiers). Displayed as "ROOKIE II".
struct RankRung: Hashable, Codable, Sendable, CustomStringConvertible {
    let rank: Rank
    let subTier: SubTier

    var description: String { "\(rank.rawValue) \(subTier.rawValue)" }

    /// MVP curve: 200 XP per ROOKIE rung, growing ~50% per chrome tier; total ~10,500 XP.
    static let xpThresholds: [Int] = {
        var thresholds: [Int] = [0]
        var step = 200
        for tier in Rank.allCases {
            for _ in SubTier.allCases {
                thresholds.append(thresholds.last! + step)
            }
            // Bump step at chrome boundaries.
            if tier == .starter || tier == .mvp { step = Int(Double(step) * 1.5) }
        }
        return thresholds
    }()

    static func from(xp: Int) -> RankRung {
        let clamped = max(0, xp)
        var rungIndex = 0
        for (idx, threshold) in xpThresholds.enumerated() {
            if clamped >= threshold { rungIndex = idx } else { break }
        }
        // Clamp past the end of the curve to the last rung.
        let safeIndex = min(rungIndex, (Rank.allCases.count * SubTier.allCases.count) - 1)
        let rank = Rank.allCases[safeIndex / SubTier.allCases.count]
        let subTier = SubTier.allCases[safeIndex % SubTier.allCases.count]
        return RankRung(rank: rank, subTier: subTier)
    }

    /// nil once the player is at LEGEND III.
    static func xpToNext(currentXP: Int) -> Int? {
        let rung = from(xp: currentXP)
        guard let currentIndex = indexOf(rung) else { return nil }
        let maxRungIndex = (Rank.allCases.count * SubTier.allCases.count) - 1  // 20
        guard currentIndex < maxRungIndex else { return nil }
        return xpThresholds[currentIndex + 1] - currentXP
    }

    private static func indexOf(_ rung: RankRung) -> Int? {
        guard let rankIdx = Rank.allCases.firstIndex(of: rung.rank),
              let subIdx = SubTier.allCases.firstIndex(of: rung.subTier) else { return nil }
        return rankIdx * SubTier.allCases.count + subIdx
    }
}
