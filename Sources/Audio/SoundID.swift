import Foundation

/// Catalog of one-shot sounds; cases map to `.wav` files in `Resources/Audio/{Sport}/`.
enum SoundID: String, Sendable, CaseIterable {
    case brandMark   = "brand-mark"
    case shoot       = "shoot-release"
    case swish       = "swish-net"
    case glass       = "glass-bounce"
    case rimDrop     = "rim-drop"
    case rimHit      = "rim-hit"
    case missTone    = "miss-tone"
    case airball     = "airball"

    var filename: String { "\(rawValue).wav" }

    /// Linear gain (0...1) applied to the player node.
    var gain: Float {
        switch self {
        case .brandMark: return 0.71   // -3 dB
        case .shoot:     return 0.50   // -6 dB
        case .swish:     return 0.71   // -3 dB
        case .glass:     return 0.50   // -6 dB
        case .rimDrop:   return 0.50   // -6 dB
        case .rimHit:    return 0.35   // -9 dB
        case .missTone:  return 0.35   // -9 dB
        case .airball:   return 0.25   // -12 dB
        }
    }

    var bundleSubdirectory: String { "Audio/Basketball" }
}

/// Catalog of looping sounds with start/stop lifecycle.
enum LoopID: String, Sendable, CaseIterable {
    case dribbleLoop = "dribble-loop"

    var filename: String { "\(rawValue).wav" }

    var gain: Float { 0.13 }

    var bundleSubdirectory: String { "Audio/Basketball" }
}
