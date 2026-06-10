import Foundation

/// Static catalog of F1 scenarios. One source of truth for both the
/// chapter-list title lookup and (next pass) the play surface. JSON-on-disk
/// authoring can come later — mirrors `ArcheryScenarioCatalog`, kept small and
/// standalone while the play loop settles.
enum F1ScenarioCatalog {
    static let scenarios: [String: F1Scenario] = [

        // Ch1 — "The limit." A calibrated corner taken right on the edge.
        // The driver commits at 95 km/h into a corner that grips to ~98, so
        // the car holds the apex — a satisfying YES that lets the player feel
        // where the limit is. The grip-gap teaching lives in the lesson cards.
        "f1-limit-001": F1Scenario(
            id: "f1-limit-001",
            title: "Hold the apex.",
            phenomenon: "The limit.",
            explainer: "A fifty-metre corner on dry slicks. Grip caps it near 98 km/h — v = √(μ·g·r), and nothing the driver does with the throttle moves that number. The car commits at 95 and holds the apex, right on the edge. One more gear of entry speed and the front would have washed wide.",
            cornerRadius: 50.0,
            gripMu: 1.5,
            entrySpeed: 26.4,   // ≈ 95 km/h, just under the ~27.1 m/s limit
            gravity: 9.8
        )

    ]

    static func scenario(for id: String) -> F1Scenario? {
        scenarios[id]
    }

    /// Title shown on the chapter-list scenario row. Fallback humanizes the id
    /// for any not-yet-authored entry.
    static func title(for id: String) -> String {
        if let scenario = scenarios[id] { return scenario.title }
        return id.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
