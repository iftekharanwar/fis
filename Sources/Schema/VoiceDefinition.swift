import Foundation

/// All player-facing strings the engine can render, owned by the scenario JSON.
struct VoiceDefinition: Codable, Sendable, Equatable {
    let intro: IntroVoice
    let success: SuccessVoice
    let miss: MissVoice

    let hintBottomCopy: String           // shown when 0 hints revealed this attempt
    let hintCta: String                  // "REVEAL (−{cost}%)"
    let solutionLabel: String
    let nextLabel: String
    let replayLabel: String
    let tryThisAnswerLabel: String
    let closeLabel: String
    let shootLabel: String

    struct IntroVoice: Codable, Sendable, Equatable {
        let headline: String
        let subhead: String
    }

    struct SuccessVoice: Codable, Sendable, Equatable {
        let headlineByFlavor: [String: String]
        let flavorCaption: [String: String]
        let subheadByFlavor: [String: String]
        let statLabels: StatLabels
    }

    struct StatLabels: Codable, Sendable, Equatable {
        let theta: String   // "ANGLE"
        let v: String       // "m/s"
        let score: String   // "PTS"
    }

    struct MissVoice: Codable, Sendable, Equatable {
        let headline: String                            // "MISSED"
        let attemptLabel: String                        // "ATTEMPT {n}"
        let retryLabel: String                          // "TRY AGAIN"
        let diagnosticByCategory: [String: String]
        let bracketHintByCategory: [String: String]
        let afterAllHintsCopy: String
    }
}
