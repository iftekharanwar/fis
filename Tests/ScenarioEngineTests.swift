import XCTest
@testable import PhysicsGame

/// Tests for the scenario engine: loading, validation, simulation, and the
/// CI-style smoke-test contract (spec §2.7).
final class ScenarioEngineTests: XCTestCase {

    // MARK: - (a) Reference scenario decodes cleanly

    func test_referenceScenario_decodes() throws {
        let scenario = try loadReferenceScenario()
        XCTAssertEqual(scenario.scenarioId.rawValue, "bb-freethrow-001")
        XCTAssertEqual(scenario.schemaVersion, SemVer(1, 1, 0))
        XCTAssertEqual(scenario.meta.title, "MAKE THE SHOT.")
        XCTAssertEqual(scenario.meta.subtitle, "FREE THROW — LEVEL 01")
        XCTAssertEqual(scenario.situation.variables.count, 4)
        XCTAssertEqual(scenario.input.mode, .numpadDual)
        XCTAssertEqual(scenario.input.fields.count, 2)
        XCTAssertEqual(scenario.hints.count, 3)
        XCTAssertEqual(scenario.outcome.successFlavors.count, 3)
        XCTAssertEqual(scenario.outcome.missCategories.count, 5)
        XCTAssertNotNil(scenario.outcome.ghostArc)
        XCTAssertNotNil(scenario.solution)
        XCTAssertEqual(scenario.solution?.equations.count, 2)
        XCTAssertEqual(scenario.solution?.workedSteps.count, 3)
    }

    func test_referenceScenario_v11FieldsPresent() throws {
        let s = try loadReferenceScenario()
        XCTAssertFalse(s.voice.hintBottomCopy.isEmpty)
        XCTAssertFalse(s.voice.solutionLabel.isEmpty)
        XCTAssertFalse(s.voice.replayLabel.isEmpty)
        XCTAssertFalse(s.voice.tryThisAnswerLabel.isEmpty)
        XCTAssertFalse(s.voice.closeLabel.isEmpty)
        XCTAssertFalse(s.voice.miss.afterAllHintsCopy.isEmpty)
        XCTAssertGreaterThan(s.voice.miss.diagnosticByCategory.count, 0)
        XCTAssertGreaterThan(s.voice.miss.bracketHintByCategory.count, 0)
        XCTAssertGreaterThan(s.voice.success.flavorCaption.count, 0)
        for cat in s.outcome.missCategories {
            XCTAssertFalse(cat.subheadVariants.isEmpty, "Missing subheadVariants for \(cat.id)")
            XCTAssertNotNil(cat.subheadVariants["1"], "Missing attempt-1 variant for \(cat.id)")
        }
        XCTAssertNotNil(s.animations.outcome.miss.tintBackgroundHexAirball)
    }

    func test_referenceScenario_voiceLowercaseMS() throws {
        let s = try loadReferenceScenario()
        XCTAssertEqual(s.voice.success.statLabels.v, "m/s",
                       "Per CONCEPT.md Voice doc, velocity label is lowercase m/s, not 'M / S'.")
    }

    // MARK: - (b) Validation error has useful path

    func test_malformedJSON_returnsErrorWithPath() {
        // Missing required field `meta.title`. Use a deliberately broken file
        // (assembled inline so we don't pollute the bundle).
        let badJSON = #"""
        {
          "schemaVersion": "1.1.0",
          "scenarioId": "test-bad",
          "meta": {
            "subtitle": "x",
            "topic": "x",
            "type": "SCENARIO",
            "difficulty": 1,
            "rankTier": "ROOKIE",
            "season": null,
            "tags": [],
            "authorIntent": ""
          }
        }
        """#
        let data = Data(badJSON.utf8)
        XCTAssertThrowsError(try ScenarioLoader.decode(data, scenarioId: "test-bad")) { error in
            guard case let ScenarioLoadError.validationFailed(_, path, _) = error else {
                return XCTFail("Expected validationFailed, got \(error)")
            }
            // The missing field could be "title" inside meta, or further down the tree.
            // We just want the path to be non-empty and informative.
            XCTAssertTrue(path.contains("/"), "Expected a JSON-pointer-style path, got '\(path)'")
        }
    }

    // MARK: - (c) CI smoke test contract

    /// The big one: every scenario's declared `smokeTest.answer` must, when
    /// run through the actual simulation, produce the `expectedOutcome` and
    /// (if success) the `expectedFlavor`. This is the contract CI will
    /// enforce for every scenario; failing it means the scenario is broken.
    func test_smokeTest_referenceScenario_actuallyProducesSWISH() throws {
        let scenario = try loadReferenceScenario()
        let outcome = runSmokeTest(for: scenario)
        switch outcome {
        case .success(let flavor):
            XCTAssertEqual(flavor, scenario.smokeTest.expectedFlavor)
        case .miss, .inFlight:
            XCTFail("Smoke test expected success, got \(outcome)")
        }
    }

    /// Verify the textbook-classical answer (θ=52°, v=7.52 derived from
    /// y(t) = h_h equation) actually produces SWISH. If this fails, the
    /// simulation is teaching physics the textbook doesn't recognize.
    func test_textbookClassicalAnswer_producesSWISH() throws {
        let scenario = try loadReferenceScenario()
        let params = projectileParams(from: scenario)
        let module = Projectile2DModule()
        let answer = ProjectileAnswer(thetaDegrees: 52.0, velocity: 7.52)
        let history = module.headlessRun(params: params, answer: answer, fixedDt: params.fixedDtSeconds)
        let outcome = module.evaluate(history: history, params: params)
        if case .success(let flavor) = outcome {
            XCTAssertEqual(flavor, "SWISH",
                           "Textbook-correct answer must produce SWISH, not \(flavor)")
        } else {
            XCTFail("Textbook-correct answer must produce SWISH, got \(outcome)")
        }
    }

    /// Helper to scan for (θ, v) pairs that produce a clean SWISH. Useful
    /// when re-tuning a scenario after geometry changes. Not a CI gate —
    /// intentionally permissive.
    func test_findSwishAnswer_helperForTuning() throws {
        let scenario = try loadReferenceScenario()
        let params = projectileParams(from: scenario)
        let module = Projectile2DModule()
        var found: [(Double, Double)] = []
        for theta in stride(from: 45.0, through: 70.0, by: 1.0) {
            for v in stride(from: 6.5, through: 9.0, by: 0.05) {
                let history = module.headlessRun(
                    params: params,
                    answer: ProjectileAnswer(thetaDegrees: theta, velocity: v),
                    fixedDt: params.fixedDtSeconds
                )
                let outcome = module.evaluate(history: history, params: params)
                if case .success(let flavor) = outcome, flavor == "SWISH" {
                    found.append((theta, v))
                }
            }
        }
        XCTAssertFalse(found.isEmpty,
                       "No swish-producing answer exists in scan range — physics is over-constrained")
    }

    // MARK: - (d) An off-target answer produces a categorized miss

    func test_lowAngleLowVelocity_producesShortMiss() throws {
        let scenario = try loadReferenceScenario()
        let outcome = runProjectile(scenario, answer: ProjectileAnswer(thetaDegrees: 20, velocity: 5))
        switch outcome {
        case .miss(let category):
            // 20° at 5m/s won't reach hoop height — should be SHORT or AIRBALL.
            XCTAssertTrue(["SHORT", "AIRBALL"].contains(category),
                          "Expected SHORT or AIRBALL, got \(category)")
        default:
            XCTFail("Expected miss, got \(outcome)")
        }
    }

    // MARK: - (e) headlessRun returns history within timeout

    func test_headlessRun_returnsNonEmptyHistoryWithinTimeout() throws {
        let scenario = try loadReferenceScenario()
        let params = projectileParams(from: scenario)
        let answer = answer(from: scenario.smokeTest.answer)
        let module = Projectile2DModule()
        let history = module.headlessRun(
            params: params,
            answer: answer,
            fixedDt: params.fixedDtSeconds,
            maxRuntime: 5.0
        )
        XCTAssertFalse(history.isEmpty)
        // 1.5–2.5s of simulated flight at 1/120 dt = ~180–300 snapshots.
        XCTAssertGreaterThan(history.count, 50)
        XCTAssertLessThan(history.count, 1000)
    }

    // MARK: - (f) Determinism — same answer twice = byte-identical history

    func test_determinism_sameAnswerProducesIdenticalHistory() throws {
        let scenario = try loadReferenceScenario()
        let params = projectileParams(from: scenario)
        let answer = answer(from: scenario.smokeTest.answer)
        let module = Projectile2DModule()

        let runA = module.headlessRun(params: params, answer: answer, fixedDt: params.fixedDtSeconds)
        let runB = module.headlessRun(params: params, answer: answer, fixedDt: params.fixedDtSeconds)

        XCTAssertEqual(runA.count, runB.count)
        for (a, b) in zip(runA, runB) {
            XCTAssertEqual(a, b, "Determinism violated at elapsed=\(a.elapsedSeconds)")
        }
    }

    // MARK: - Helpers

    private func loadReferenceScenario() throws -> ScenarioDefinition {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "bb-freethrow-001", withExtension: "json") else {
            XCTFail("bb-freethrow-001.json not found in test bundle. Check project.yml resources.")
            throw ScenarioLoadError.notFound(scenarioId: "bb-freethrow-001")
        }
        let data = try Data(contentsOf: url)
        return try ScenarioLoader.decode(data, scenarioId: "bb-freethrow-001")
    }

    private func runSmokeTest(for scenario: ScenarioDefinition) -> ProjectileOutcome {
        let params = projectileParams(from: scenario)
        let answer = answer(from: scenario.smokeTest.answer)
        return runOutcome(params: params, answer: answer)
    }

    private func runProjectile(_ scenario: ScenarioDefinition, answer: ProjectileAnswer) -> ProjectileOutcome {
        let params = projectileParams(from: scenario)
        return runOutcome(params: params, answer: answer)
    }

    private func runOutcome(params: Projectile2DParams, answer: ProjectileAnswer) -> ProjectileOutcome {
        let module = Projectile2DModule()
        let history = module.headlessRun(
            params: params,
            answer: answer,
            fixedDt: params.fixedDtSeconds
        )
        return module.evaluate(history: history, params: params)
    }

    private func projectileParams(from scenario: ScenarioDefinition) -> Projectile2DParams {
        switch scenario.simulation {
        case .projectile2D(_, let params): return params
        }
    }

    private func answer(from dict: [String: Double]) -> ProjectileAnswer {
        ProjectileAnswer(thetaDegrees: dict["theta"] ?? 0, velocity: dict["v"] ?? 0)
    }
}
