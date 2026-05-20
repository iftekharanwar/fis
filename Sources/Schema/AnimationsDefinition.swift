import Foundation

/// Animation slot names; the engine resolves them via `AnimationRegistry`.
struct AnimationsDefinition: Codable, Sendable, Equatable {
    let idle: IdleAnimation
    let action: ActionAnimation
    let outcome: OutcomeAnimations

    struct IdleAnimation: Codable, Sendable, Equatable {
        let id: String
        let loop: Bool
        let framesPerSecond: Int
        let anchor: String
    }

    struct ActionAnimation: Codable, Sendable, Equatable {
        let id: String
        let driver: String
        let phases: [Phase]
    }

    struct Phase: Codable, Sendable, Equatable {
        let id: String
        let duration: Double?
        let trigger: String?
        let driver: String?
    }

    struct OutcomeAnimations: Codable, Sendable, Equatable {
        let success: SuccessAnimations
        let miss: MissAnimation
    }

    struct SuccessAnimations: Codable, Sendable, Equatable {
        let byFlavor: [String: String]
        let `default`: String
    }

    struct MissAnimation: Codable, Sendable, Equatable {
        let id: String
        let tintBackgroundHex: String
        let tintBackgroundHexAirball: String?
        let showGhostArc: Bool
        let showFailedArc: Bool
        let failedArcColor: String
        let ghostArcColor: String
    }
}
