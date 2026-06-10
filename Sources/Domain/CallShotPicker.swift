import Foundation

/// Picks the shot fired on the CALL beat. The ghost-arc canonical always
/// scores (the smoke tests guarantee it), so firing it every time would make
/// YES the right call forever. Half the time this picker perturbs the
/// velocity and verifies via a headless simulation run that the shot really
/// misses — so the call is a genuine read, not a ritual.
///
/// Streak-breaker: a fair coin still throws runs (1 in 8 sessions see the
/// same truth three times straight), which players read as rigged. Callers
/// pass the recent truth history; after two identical truths the picker
/// forces the opposite, so the truth never repeats three times in a row
/// while staying 50/50 overall.
enum CallShotPicker {
    struct Pick: Equatable, Sendable {
        let answer: ProjectileAnswer
        let goesIn: Bool
    }

    /// Session-scoped truth history (true = went in), newest last. Owned
    /// here so every call surface shares one streak.
    @MainActor static var recentTruths: [Bool] = []

    static func pick(
        for scenario: ScenarioDefinition,
        using rng: inout some RandomNumberGenerator,
        recentTruths: [Bool] = []
    ) -> Pick {
        guard case .projectile2D(_, let params) = scenario.simulation,
              let ghost = scenario.outcome.ghostArc,
              let theta = ghost.answer["theta"],
              let v = ghost.answer["v"] else {
            // No verified canonical to perturb from — fall back to the
            // legacy defaults rather than guessing at a miss.
            return Pick(answer: ProjectileAnswer(thetaDegrees: 52, velocity: 7.5), goesIn: true)
        }

        let canonical = ProjectileAnswer(thetaDegrees: theta, velocity: v)

        let wantIn: Bool
        let lastTwo = recentTruths.suffix(2)
        if lastTwo.count == 2, lastTwo.first == lastTwo.last, let last = lastTwo.last {
            wantIn = !last   // break the streak
        } else {
            wantIn = Bool.random(using: &rng)
        }
        if wantIn {
            return Pick(answer: canonical, goesIn: true)
        }

        // Miss candidates: velocity scaled down (short) or up (long), mildest
        // first so the arc still looks like a plausible shot. Each candidate
        // is verified headlessly; the first that actually misses wins.
        let module = Projectile2DModule()
        let short = [0.90, 0.85, 0.80]
        let long = [1.10, 1.15, 1.20]
        let factors = Bool.random(using: &rng) ? short + long : long + short
        for factor in factors {
            let candidate = ProjectileAnswer(thetaDegrees: theta, velocity: v * factor)
            let history = module.headlessRun(
                params: params,
                answer: candidate,
                fixedDt: params.fixedDtSeconds
            )
            if case .miss = module.evaluate(history: history, params: params) {
                return Pick(answer: candidate, goesIn: false)
            }
        }

        // Every perturbation somehow still scored — fire the canonical.
        return Pick(answer: canonical, goesIn: true)
    }
}
