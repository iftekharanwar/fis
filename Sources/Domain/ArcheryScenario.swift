import Foundation

/// A single archery scenario — enough state to render the scene, run the
/// inline projectile sim, and resolve a verdict. Decoupled from the
/// basketball SimulationConfig / ScenarioDefinition schema on purpose:
/// archery only needs projectile motion + target-plane hit detection, and
/// the basketball schema's rim-contact / hoop-pass machinery doesn't apply.
///
/// When archery's needs converge with the broader schema (multi-attempt
/// recording, ghost arcs, hints) we can unify; for now keeping it small
/// and standalone is the right move.
struct ArcheryScenario: Sendable, Equatable, Identifiable {
    let id: String

    /// User-visible name on the chapter list row.
    let title: String

    /// Phenomenon headline shown on the reveal card (Anton, big).
    let phenomenon: String

    /// 2–3 sentence reveal copy explaining WHY the arrow landed where it did.
    let explainer: String

    // MARK: - World geometry (meters)

    /// Height of the bow at full draw — the arrow's release point.
    let releaseHeight: Double

    /// Distance from archer to the target plane.
    let targetDistance: Double

    /// Height of the bullseye center on the target.
    let bullseyeHeight: Double

    /// Radius around the bullseye that still counts as a hit.
    let bullseyeRadius: Double

    /// Arrow muzzle velocity (fixed by the bow, not the archer's input).
    let arrowVelocity: Double

    let gravity: Double

    // MARK: - The lie

    /// Distance the sight pin is calibrated for. The pin appears on the
    /// bullseye visually because the archer is aiming there — but the bow
    /// is angled for THIS distance, not `targetDistance`. The gap between
    /// the two is the whole teaching point of the scenario.
    let pinSightedFor: Double

    // MARK: - Archer's paradox (Ch2)

    /// Bow's draw weight (arbitrary 0–100 scale). Drives how hard the
    /// string snaps the arrow forward — and how much lateral force the
    /// shaft has to flex around. Matched to `arrowSpine` means clean
    /// flight; mismatched means the arrow visibly oscillates.
    /// Zero on Ch1 scenarios (no wobble behavior).
    var bowDraw: Double = 0

    /// Arrow's spine / stiffness (arbitrary 0–100 scale). Match to `bowDraw`
    /// = arrow flexes just enough to clear the riser and recovers straight.
    /// Mismatch = arrow wobbles in flight, impacts at an angle.
    /// Zero on Ch1 scenarios.
    var arrowSpine: Double = 0

    /// Signed spine mismatch. Positive = arrow too stiff, negative = too
    /// soft. Magnitude drives wobble amplitude.
    var spineMismatch: Double { arrowSpine - bowDraw }

    /// True iff this scenario teaches the archer's paradox (Ch2). Used by
    /// the play view to swap HUD stats and the stance prompt copy.
    var usesParadoxMechanic: Bool { bowDraw > 0 }

    /// Stance-screen prompt copy. Defaults to the Ch1 pin-gap framing;
    /// paradox scenarios reframe around clean-flight prediction.
    var stancePrompt: String {
        usesParadoxMechanic ? "WILL THIS FLY CLEAN?" : "WILL THIS HIT BULLSEYE?"
    }

    // MARK: - Derived truth

    /// Launch angle the bow holds when the user "aims at the bullseye"
    /// through a pin sighted for `pinSightedFor`. Closed-form for the
    /// level-shot case (release height == bullseye height):
    ///   sin(2θ) = g·d / v²
    var pinLaunchAngleRadians: Double {
        let argument = (gravity * pinSightedFor) / (arrowVelocity * arrowVelocity)
        let clamped = min(max(argument, -1), 1)
        return asin(clamped) / 2.0
    }

    /// Where the arrow actually lands on the target plane, given the pin's
    /// launch angle. Used to bake the truth into the scenario data so the
    /// view's call-correctness check stays trivial.
    var actualImpactY: Double {
        let theta = pinLaunchAngleRadians
        let vx = arrowVelocity * cos(theta)
        let vy = arrowVelocity * sin(theta)
        let t = targetDistance / vx
        return releaseHeight + vy * t - 0.5 * gravity * t * t
    }

    /// True iff the actual impact y is inside the bullseye tolerance.
    var actuallyHitsBullseye: Bool {
        abs(actualImpactY - bullseyeHeight) <= bullseyeRadius
    }
}
