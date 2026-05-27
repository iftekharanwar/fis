import Foundation

/// Static catalog of archery scenarios. One source of truth for both the
/// chapter-list title lookup and the play surface. JSON-on-disk authoring
/// can come later — we'll do that pass once the play loop has settled and
/// we know what fields actually matter.
enum ArcheryScenarioCatalog {
    static let scenarios: [String: ArcheryScenario] = [

        "arc-pingap-001": ArcheryScenario(
            id: "arc-pingap-001",
            title: "Hold your pin.",
            phenomenon: "The arc.",
            explainer: "Your bow tilts up just over a degree — invisible to the eye, but the arc puts the arrow exactly on the bullseye 40 meters away. Gravity drops it by 1.22 metres in flight; the bow's angle lifts it by the same amount. Calibrated.",
            releaseHeight: 1.6,
            targetDistance: 40.0,
            bullseyeHeight: 1.6,
            bullseyeRadius: 0.10,
            arrowVelocity: 80.0,
            gravity: 9.8,
            // Pin matches the target — this is a calibrated shot. The pin
            // gap concept lives in the lesson cards and the formula
            // walkthrough; the call beat itself is a satisfying YES.
            pinSightedFor: 40.0
        ),

        "arc-paradox-001": ArcheryScenario(
            id: "arc-paradox-001",
            title: "Spine match.",
            phenomenon: "The archer's paradox.",
            explainer: "When the string releases, it shoves the back of the arrow — but the shaft is resting against the side of the bow. The arrow doesn't go around the bow. It flexes through it. Spine = the arrow's stiffness. Match it to the bow's draw and the arrow bends just enough to clear, then snaps back straight. Mismatched: the arrow wobbles all the way to the target.",
            releaseHeight: 1.6,
            targetDistance: 40.0,
            bullseyeHeight: 1.6,
            bullseyeRadius: 0.10,
            arrowVelocity: 80.0,
            gravity: 9.8,
            pinSightedFor: 40.0,   // calibrated for distance — gravity is solved
            bowDraw: 60,           // 60 lb draw
            arrowSpine: 85         // arrow too stiff — heavy wobble expected
        )

    ]

    static func scenario(for id: String) -> ArcheryScenario? {
        scenarios[id]
    }

    /// Title shown on the chapter-list scenario row. Fallback humanizes
    /// the id for any not-yet-authored entry.
    static func title(for id: String) -> String {
        if let scenario = scenarios[id] { return scenario.title }
        return id.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
