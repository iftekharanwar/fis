import XCTest
import CoreGraphics
@testable import PhysicsGame

/// Verifies the mid-flight call freeze added for the call-mid-action change:
/// a shot launched with `pauseAtMidflight` halts once near the midpoint,
/// fires `onReachedMidflight` exactly once, and only resolves its outcome
/// after `resumeFlight()`.
@MainActor
final class ArcheryMidflightFreezeTests: XCTestCase {

    /// A representative Ch1 pin-gap scenario (40 m target, 20 m pin).
    private func makeScenario() -> ArcheryScenario {
        ArcheryScenario(
            id: "test-pingap",
            title: "Test",
            phenomenon: "Test",
            explainer: "Test",
            releaseHeight: 1.5,
            targetDistance: 40,
            bullseyeHeight: 1.5,
            bullseyeRadius: 0.2,
            arrowVelocity: 80,
            gravity: 9.8,
            pinSightedFor: 20
        )
    }

    /// Drive the scene's frame loop with synthetic, monotonically increasing
    /// timestamps so the fixed-step integrator advances deterministically.
    private func advance(_ scene: ArcherySceneNode, seconds: Double, from start: Double) {
        let step = 1.0 / 60.0
        var t = start
        let end = start + seconds
        while t < end {
            scene.update(t)
            t += step
        }
    }

    func test_pauseAtMidflight_freezesOnceAndResolvesOnlyAfterResume() {
        let scene = ArcherySceneNode(scenario: makeScenario(), size: CGSize(width: 393, height: 340))

        var freezeCount = 0
        var outcome: ArcheryOutcome?
        scene.onReachedMidflight = { freezeCount += 1 }
        scene.onOutcomeResolved = { o, _ in outcome = o }

        scene.startSimulation(pauseAtMidflight: true)

        // Advance well past the time the arrow would reach the target if it
        // never froze (~0.5 s sim → a few seconds of real time at timeScale).
        advance(scene, seconds: 6.0, from: 1000)

        // The freeze must have fired exactly once, and the outcome must NOT
        // be resolved yet — the arrow is hanging mid-flight awaiting the call.
        XCTAssertEqual(freezeCount, 1, "freeze should fire exactly once")
        XCTAssertNil(outcome, "outcome must not resolve while frozen mid-flight")

        // Resume — now the arrow completes its flight and resolves.
        scene.resumeFlight()
        advance(scene, seconds: 6.0, from: 2000)

        XCTAssertEqual(freezeCount, 1, "freeze must not re-fire after resume")
        XCTAssertNotNil(outcome, "outcome must resolve after the flight finishes")
    }

    func test_noPause_resolvesWithoutFreezing() {
        let scene = ArcherySceneNode(scenario: makeScenario(), size: CGSize(width: 393, height: 340))

        var freezeCount = 0
        var outcome: ArcheryOutcome?
        scene.onReachedMidflight = { freezeCount += 1 }
        scene.onOutcomeResolved = { o, _ in outcome = o }

        // Compute/bonus-style shot: no mid-flight pause.
        scene.startSimulation(pauseAtMidflight: false)
        advance(scene, seconds: 6.0, from: 1000)

        XCTAssertEqual(freezeCount, 0, "no freeze when pauseAtMidflight is false")
        XCTAssertNotNil(outcome, "outcome resolves straight through")
    }
}
