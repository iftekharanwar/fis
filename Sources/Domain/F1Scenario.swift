import Foundation

/// A single F1 cornering scenario — enough state to render the corner, run
/// the grip-limit check, and resolve a verdict. Decoupled from the
/// basketball `SimulationConfig` / `ScenarioDefinition` schema *and* from the
/// projectile-based `ArcheryScenario` on purpose: F1 teaches centripetal grip
/// (`v = √(μ·g·r)`), not projectile motion, so it needs a corner radius and a
/// friction coefficient rather than a launch angle and a drop.
///
/// Mirrors the `ArcheryScenario` shape (id + reveal copy + world geometry +
/// derived truth) so the call-then-reveal play surface can stay uniform across
/// sports. The play surface itself lands in the next pass; for now this type
/// backs the chapter-list row title and the reveal copy.
struct F1Scenario: Sendable, Equatable, Identifiable {
    let id: String

    /// User-visible name on the chapter list row.
    let title: String

    /// Phenomenon headline shown on the reveal card (Anton, big).
    let phenomenon: String

    /// 2–3 sentence reveal copy explaining WHY the car held — or didn't.
    let explainer: String

    // MARK: - Corner geometry & grip

    /// Radius of the corner's arc, in metres. Smaller = tighter = slower limit.
    let cornerRadius: Double

    /// Tyre–track grip coefficient (μ). Dry racing slicks ≈ 1.5; wet ≈ 0.8.
    let gripMu: Double

    /// Speed the driver commits to through the corner, in m/s. The "call" is
    /// whether this sits at or under the grip limit.
    let entrySpeed: Double

    let gravity: Double

    // MARK: - Derived truth

    /// The grip-limited maximum cornering speed: `v = √(μ·g·r)`. The single
    /// number the whole chapter teaches — nothing the driver does with the
    /// throttle changes it.
    var limitSpeed: Double {
        (gripMu * gravity * cornerRadius).squareRoot()
    }

    /// True iff the committed entry speed is within the grip limit — the car
    /// holds the apex. Over the limit, the front washes wide (understeer).
    var willHold: Bool {
        entrySpeed <= limitSpeed
    }

    /// Stance-screen prompt copy for the call beat.
    var stancePrompt: String { "WILL IT HOLD?" }

    // MARK: - Display convenience (km/h reads more like a speedo than m/s)

    var entrySpeedKmh: Double { entrySpeed * 3.6 }
    var limitSpeedKmh: Double { limitSpeed * 3.6 }
}
