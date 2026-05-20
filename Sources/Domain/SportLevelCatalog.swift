import Foundation

/// Static catalog of which levels belong to which sport.
enum SportLevelCatalog {
    struct LevelEntry: Sendable, Identifiable {
        var id: ScenarioID { scenarioId }
        let scenarioId: ScenarioID
        let levelNumber: Int
        let shortLabel: String
    }

    static func levels(for sport: Sport) -> [LevelEntry] {
        switch sport {
        case .basketball:
            return [
                LevelEntry(
                    scenarioId: "bb-freethrow-001",
                    levelNumber: 1,
                    shortLabel: "MAKE THE SHOT."
                )
            ]
        case .soccer, .pool, .archery, .f1:
            return []
        }
    }
}
