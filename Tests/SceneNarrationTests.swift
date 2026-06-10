import XCTest
@testable import PhysicsGame

/// SceneNarration — the VoiceOver scene reads. The contract under test:
/// the frozen read carries real signal (canonical vs verified-miss shots
/// sound different), never leaks the canonical numbers, and the labels
/// carry the geometry a sighted player sees.
final class SceneNarrationTests: XCTestCase {

    // MARK: - Basketball

    /// Same gate CallShotPicker uses: every velocity perturbation verified
    /// to miss must produce a different apex read than the canonical —
    /// otherwise a blind player gets noise instead of evidence.
    func test_frozenRead_discriminatesCanonicalFromVerifiedMisses() throws {
        let scenario = try ScenarioLoader.load("bb-1-baseline")
        guard case .projectile2D(_, let params) = scenario.simulation,
              let ghost = scenario.outcome.ghostArc,
              let theta = ghost.answer["theta"],
              let v = ghost.answer["v"] else {
            return XCTFail("bb-1-baseline must carry a ghost-arc canonical")
        }

        let canonical = ProjectileAnswer(thetaDegrees: theta, velocity: v)
        let canonicalRead = SceneNarration.basketballFrozenRead(params: params, shot: canonical)

        let module = Projectile2DModule()
        var verifiedMisses = 0
        for factor in [0.90, 0.85, 0.80, 1.10, 1.15, 1.20] {
            let candidate = ProjectileAnswer(thetaDegrees: theta, velocity: v * factor)
            let history = module.headlessRun(
                params: params, answer: candidate, fixedDt: params.fixedDtSeconds
            )
            guard case .miss = module.evaluate(history: history, params: params) else { continue }
            verifiedMisses += 1
            let read = SceneNarration.basketballFrozenRead(params: params, shot: candidate)
            XCTAssertNotEqual(
                read, canonicalRead,
                "velocity ×\(factor) misses but reads identically to the canonical"
            )
        }
        XCTAssertGreaterThan(verifiedMisses, 0, "no perturbation missed — picker test fixture broken?")
    }

    /// The read gives evidence, never the answer: no digits at all.
    func test_frozenRead_neverLeaksNumbers() throws {
        let scenario = try ScenarioLoader.load("bb-1-baseline")
        guard case .projectile2D(_, let params) = scenario.simulation,
              let ghost = scenario.outcome.ghostArc,
              let theta = ghost.answer["theta"],
              let v = ghost.answer["v"] else {
            return XCTFail("bb-1-baseline must carry a ghost-arc canonical")
        }
        let read = SceneNarration.basketballFrozenRead(
            params: params,
            shot: ProjectileAnswer(thetaDegrees: theta, velocity: v)
        )
        XCTAssertNil(read.rangeOfCharacter(from: .decimalDigits),
                     "frozen read leaked a number: \(read)")
    }

    func test_basketballLabel_carriesGeometry() throws {
        let scenario = try ScenarioLoader.load("bb-1-baseline")
        guard case .projectile2D(_, let params) = scenario.simulation else {
            return XCTFail("not projectile2D")
        }
        let label = SceneNarration.basketballLabel(params: params)
        XCTAssertTrue(label.contains("meters"), label)
        XCTAssertTrue(label.localizedCaseInsensitiveContains("hoop"), label)
    }

    // MARK: - Archery

    func test_archeryLabelAndRead() throws {
        let scenario = try XCTUnwrap(ArcheryScenarioCatalog.scenario(for: "arc-pingap-001"))
        let label = SceneNarration.archeryLabel(scenario)
        XCTAssertTrue(label.contains("meters"), label)
        XCTAssertTrue(label.localizedCaseInsensitiveContains("pin sighted for"), label)

        let read = SceneNarration.archeryFrozenRead(scenario)
        XCTAssertTrue(read.localizedCaseInsensitiveContains("arrow frozen"), read)
        XCTAssertTrue(read.localizedCaseInsensitiveContains("line to the bullseye"), read)
    }

    /// Paradox scenarios add the wobble evidence sighted players see.
    func test_archeryParadoxRead_mentionsShaft() throws {
        let scenario = try XCTUnwrap(ArcheryScenarioCatalog.scenario(for: "arc-paradox-001"))
        let read = SceneNarration.archeryFrozenRead(scenario)
        XCTAssertTrue(read.localizedCaseInsensitiveContains("shaft"), read)
    }

    // MARK: - Soccer

    func test_soccerLabelAndStanceRead() throws {
        let scenario = try XCTUnwrap(SoccerScenarioCatalog.scenario(for: "soc-curve-001"))
        let label = SceneNarration.soccerLabel(scenario, keeperOffset: 0.4)
        XCTAssertTrue(label.localizedCaseInsensitiveContains("free kick"), label)
        XCTAssertTrue(label.localizedCaseInsensitiveContains("keeper"), label)

        let read = SceneNarration.soccerStanceRead(scenario)
        XCTAssertTrue(read.localizedCaseInsensitiveContains("aimed"), read)
        XCTAssertTrue(read.localizedCaseInsensitiveContains("curve"), read)
    }
}
