import Foundation

struct MetaDefinition: Codable, Sendable, Equatable {
    let title: String
    let subtitle: String
    let topic: String
    let type: ScenarioType
    let difficulty: Int        // 1–10 within tier
    let rankTier: String
    let season: String?
    let tags: [String]
    let authorIntent: String   // dev-only

    enum ScenarioType: String, Codable, Sendable {
        case scenario  = "SCENARIO"
        case scene     = "SCENE"
        case challenge = "CHALLENGE"
    }
}
