import Foundation
import CoreGraphics

/// One round of the Level C "pick the spot" beat: a fully-given shot and
/// the distance where that shot actually crosses hoop height on the way
/// down. The player doesn't shape the shot — they predict its landing.
///
/// Round 1 fires the canonical givens. Retries perturb the speed, so the
/// crossing point moves and the visible hoop stops being a cheat-sheet —
/// the answer must come from the shown numbers, not from eyeballing the rim.
struct PickSpotChallenge: Equatable, Sendable {
    let answer: ProjectileAnswer
    /// Horizontal distance from the release point where the shot crosses
    /// the target height on descent, per the real integrator.
    let crossingD: Double

    static func round(
        for scenario: ScenarioDefinition,
        attempt: Int,
        using rng: inout some RandomNumberGenerator
    ) -> PickSpotChallenge? {
        guard case .projectile2D(_, let params) = scenario.simulation,
              let ghost = scenario.outcome.ghostArc,
              let theta = ghost.answer["theta"],
              let v = ghost.answer["v"] else { return nil }

        var factors: [Double] = [1.0]
        if attempt > 1 {
            factors = [0.94, 1.06, 0.92, 1.08, 0.96, 1.04].shuffled(using: &rng) + [1.0]
        }
        let playable = playableRange(params: params)
        for factor in factors {
            let candidate = ProjectileAnswer(thetaDegrees: theta, velocity: v * factor)
            if let d = crossingDistance(params: params, answer: candidate),
               playable.contains(d) {
                return PickSpotChallenge(answer: candidate, crossingD: d)
            }
        }
        return nil
    }

    /// Ranges a shooter can actually stand at: at least 1m out, and far
    /// enough from the world's left edge to stay on the visible court.
    /// Both the round dealer and the range slider use this, so every
    /// dealt round is answerable.
    static func playableRange(params: Projectile2DParams) -> ClosedRange<Double> {
        let maxRange = params.target.center[0] - params.world.xMin - 0.4
        return 1.0...max(maxRange, 2.0)
    }

    /// Descent crossing of the target height, linearly interpolated between
    /// integrator steps — the same trajectory the renderer plays back.
    static func crossingDistance(
        params: Projectile2DParams,
        answer: ProjectileAnswer
    ) -> Double? {
        let module = Projectile2DModule()
        let history = module.headlessRun(
            params: params,
            answer: answer,
            fixedDt: params.fixedDtSeconds
        )
        guard history.count >= 2 else { return nil }
        let targetY = CGFloat(params.target.center[1])
        for i in 1..<history.count {
            let prev = history[i - 1].ballPosition
            let cur = history[i].ballPosition
            if prev.y > targetY, cur.y <= targetY {
                let t = (prev.y - targetY) / max(0.0001, prev.y - cur.y)
                let x = prev.x + (cur.x - prev.x) * t
                return Double(x) - params.releasePosition[0]
            }
        }
        return nil
    }

    /// Swish-grade call: within the rim's inner radius of the true crossing.
    static func isHit(markerD: Double, crossingD: Double, params: Projectile2DParams) -> Bool {
        abs(markerD - crossingD) <= params.target.innerRadius
    }
}
