import Foundation

/// Catalog of one-shot sounds. Cases map to `.wav` files in
/// `Resources/Audio/{Sport}/`. The sport folder is chosen per-case via
/// `bundleSubdirectory` so basketball and archery don't bleed into each
/// other.
enum SoundID: String, Sendable, CaseIterable {
    // Basketball
    case brandMark   = "brand-mark"
    case shoot       = "shoot-release"
    case swish       = "swish-net"
    case glass       = "glass-bounce"
    case rimDrop     = "rim-drop"
    case rimHit      = "rim-hit"
    case missTone    = "miss-tone"
    case airball     = "airball"

    // Archery
    case bowRelease   = "bow-release"     // bowstring twang — file pending
    case arrowWhoosh  = "arrow-whoosh"
    case targetThud   = "target-thud"
    case bullseyeHit  = "bullseye-hit"

    var filename: String { "\(rawValue).wav" }

    /// Linear gain (0...1) applied to the player node.
    var gain: Float {
        switch self {
        // Basketball
        case .brandMark:    return 0.71   // -3 dB
        case .shoot:        return 0.50   // -6 dB
        case .swish:        return 0.71   // -3 dB
        case .glass:        return 0.50   // -6 dB
        case .rimDrop:      return 0.50   // -6 dB
        case .rimHit:       return 0.35   // -9 dB
        case .missTone:     return 0.35   // -9 dB
        case .airball:      return 0.25   // -12 dB

        // Archery
        case .bowRelease:   return 0.55   // punchy release attack
        case .arrowWhoosh:  return 0.40   // subtle, sits under the release
        case .targetThud:   return 0.45   // muted miss thud
        case .bullseyeHit:  return 0.71   // the reward
        }
    }

    var bundleSubdirectory: String {
        switch self {
        case .brandMark, .shoot, .swish, .glass, .rimDrop, .rimHit, .missTone, .airball:
            return "Audio/Basketball"
        case .bowRelease, .arrowWhoosh, .targetThud, .bullseyeHit:
            return "Audio/Archery"
        }
    }
}

/// Catalog of looping sounds with start/stop lifecycle.
enum LoopID: String, Sendable, CaseIterable {
    case dribbleLoop = "dribble-loop"

    var filename: String { "\(rawValue).wav" }

    var gain: Float { 0.13 }

    var bundleSubdirectory: String { "Audio/Basketball" }
}
