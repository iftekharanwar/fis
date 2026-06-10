import XCTest
@testable import PhysicsGame

/// Tests for the scenario engine: loading, validation, simulation, and the
/// CI-style smoke-test contract (spec §2.7).
final class ScenarioEngineTests: XCTestCase {

    // MARK: - (a) Reference scenario decodes cleanly

    func test_referenceScenario_decodes() throws {
        let scenario = try loadReferenceScenario()
        XCTAssertEqual(scenario.scenarioId.rawValue, "bb-1-baseline")
        XCTAssertEqual(scenario.schemaVersion, SemVer(1, 1, 0))
        XCTAssertEqual(scenario.meta.title, "MAKE THE SHOT.")
        XCTAssertEqual(scenario.meta.subtitle, "CH 1 — THE ARC, BASELINE")
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

    func test_basketballRelease_manifest() throws {
        // The public release manifest. Deliberately pinned: growing this
        // list is a conscious release decision, not a side effect.
        let chapters = BasketballCurriculum.chapters
        let playable = chapters.filter(\.hasPlayablePractice)

        XCTAssertEqual(playable.map(\.id), ["bb-ch1-arc"])

        let chapter = try XCTUnwrap(chapters.first { $0.id == "bb-ch1-arc" })
        XCTAssertEqual(chapter.releasedPracticeLevelTypes, [.findTheta, .findV, .findD, .findBoth])
        // One scenario per question type — each calculation once (team
        // decision); distinct venues 4.6 / 7.5 / 5.8 m.
        XCTAssertEqual(chapter.progressScenarioIDs, [
            "bb-a-freethrow",
            "bb-b-stepback",
            "bb-c-wing-throw",
            "bb-1-logo-three"
        ])

        let locked = chapters.filter { $0.id != "bb-ch1-arc" }
        XCTAssertTrue(locked.allSatisfy { !$0.hasPlayablePractice })
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

    func test_referenceScenario_velocityStatLabel() throws {
        // The stat cell's VALUE already carries the unit ("8.2 m/s",
        // formatted in SwishView), so the label underneath is the quantity
        // name — matching ANGLE/PTS. The voice doc's lowercase-m/s rule
        // applies to the unit in the value, not this label.
        let s = try loadReferenceScenario()
        XCTAssertEqual(s.voice.success.statLabels.v, "SPEED")
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

    /// Universal smoke test: every scenario JSON shipped in the bundle must
    /// pass its own smoke test. If you add a scenario, this catches a wrong
    /// (θ, v) answer the moment you build. Failing here means the JSON's
    /// declared answer doesn't actually score in the simulation.
    func test_smokeTest_everyScenarioInBundle_passes() throws {
        let bundle = Bundle(for: type(of: self))
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) else {
            XCTFail("No scenario JSONs found in test bundle.")
            return
        }
        let scenarioURLs = urls.filter { $0.lastPathComponent.hasPrefix("bb-") }
        XCTAssertGreaterThan(scenarioURLs.count, 1, "Expected multiple scenarios in bundle.")
        for url in scenarioURLs {
            let stem = url.deletingPathExtension().lastPathComponent
            let data = try Data(contentsOf: url)
            let scenario = try ScenarioLoader.decode(data, scenarioId: ScenarioID(stem))
            let outcome = runSmokeTest(for: scenario)
            switch outcome {
            case .success(let flavor):
                XCTAssertEqual(flavor, scenario.smokeTest.expectedFlavor,
                               "[\(stem)] expected flavor \(scenario.smokeTest.expectedFlavor), got \(flavor)")
            case .miss(let category):
                let answer = answer(from: scenario.smokeTest.answer)
                XCTFail("[\(stem)] smoke test expected success, got miss(\(category)) — (θ=\(answer.thetaDegrees), v=\(answer.velocity))")
            case .inFlight:
                XCTFail("[\(stem)] smoke test still in-flight after timeout")
            }
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
        guard let url = bundle.url(forResource: "bb-1-baseline", withExtension: "json") else {
            XCTFail("bb-1-baseline.json not found in test bundle. Check project.yml resources.")
            throw ScenarioLoadError.notFound(scenarioId: "bb-1-baseline")
        }
        let data = try Data(contentsOf: url)
        return try ScenarioLoader.decode(data, scenarioId: "bb-1-baseline")
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

    // MARK: - (e) Call-surface guards

    /// The walkthrough's answer card must show the ghost-arc values — and
    /// that answer must actually score. Guards against the math screen
    /// drifting from the simulated shot (the hardcoded "θ ≈ 52°, v ≈ 7.5"
    /// regression caught on bb-c-wing-throw).
    func test_callWalkthrough_answerCard_matchesGhostArc_everyScenario() throws {
        for scenario in try allBundleScenarios() {
            guard let ghost = scenario.outcome.ghostArc?.answer,
                  let theta = ghost["theta"], let v = ghost["v"] else { continue }
            let stem = scenario.scenarioId.rawValue

            let cards = CallWalkthrough(scenario: scenario).cards
            let final = try XCTUnwrap(cards.last)
            XCTAssertTrue(final.math.contains(CallWalkthrough.trim(theta)),
                          "[\(stem)] answer card must show ghost-arc θ, got: \(final.math)")
            XCTAssertTrue(final.math.contains(CallWalkthrough.trim(v)),
                          "[\(stem)] answer card must show ghost-arc v, got: \(final.math)")

            let outcome = runProjectile(scenario, answer: ProjectileAnswer(thetaDegrees: theta, velocity: v))
            guard case .success = outcome else {
                XCTFail("[\(stem)] ghost-arc answer misses — the walkthrough would teach a shot that doesn't score")
                continue
            }
        }
    }

    /// The released Level C scenario asks for d — the walkthrough must lead
    /// with the real hoop distance from the sim world, not a defaulted
    /// variable lookup.
    func test_callWalkthrough_wingThrow_leadsWithRealHoopDistance() throws {
        let scenario = try loadScenario("bb-c-wing-throw")
        let d = try XCTUnwrap(CallWalkthrough.targetDistance(of: scenario))
        XCTAssertEqual(d, 5.82, accuracy: 0.001)

        let final = try XCTUnwrap(CallWalkthrough(scenario: scenario).cards.last)
        XCTAssertTrue(final.headline.contains("5.82"),
                      "find-d answer card should lead with d, got: \(final.headline)")
        XCTAssertFalse(final.headline.contains("52"),
                       "the hardcoded free-throw answer must be gone, got: \(final.headline)")
    }

    /// The call beat must be a genuine read: across many picks the shot
    /// sometimes scores and sometimes misses, `goesIn` always agrees with
    /// what the simulation resolves, and (with history threaded like the
    /// view does) the truth never repeats three times in a row.
    func test_callShotPicker_variesCall_andVerdictMatchesSimulation() throws {
        let scenario = try loadScenario("bb-c-wing-throw")
        var rng = SeededLCG(seed: 7)
        var history: [Bool] = []
        var truths: [Bool] = []

        for _ in 0..<40 {
            let pick = CallShotPicker.pick(for: scenario, using: &rng, recentTruths: history)
            history = Array((history + [pick.goesIn]).suffix(4))
            truths.append(pick.goesIn)
            switch runProjectile(scenario, answer: pick.answer) {
            case .success:
                XCTAssertTrue(pick.goesIn, "pick claimed a miss but the shot scored")
            case .miss:
                XCTAssertFalse(pick.goesIn, "pick claimed a make but the shot missed")
            case .inFlight:
                XCTFail("call shot never resolved")
            }
        }
        XCTAssertTrue(truths.contains(true), "expected some call shots to score")
        XCTAssertTrue(truths.contains(false), "expected some call shots to miss — always-YES regression")
        for i in 2..<truths.count {
            XCTAssertFalse(truths[i] == truths[i - 1] && truths[i - 1] == truths[i - 2],
                           "streak-breaker failed: same truth three times at index \(i)")
        }
    }

    /// Streak-breaker edge: two identical truths force the opposite next.
    func test_callShotPicker_breaksStreaksDeterministically() throws {
        let scenario = try loadScenario("bb-c-wing-throw")
        for seed in UInt64(1)...10 {
            var rng = SeededLCG(seed: seed)
            XCTAssertFalse(
                CallShotPicker.pick(for: scenario, using: &rng, recentTruths: [true, true]).goesIn,
                "after two makes the call shot must miss (seed \(seed))"
            )
            XCTAssertTrue(
                CallShotPicker.pick(for: scenario, using: &rng, recentTruths: [false, false]).goesIn,
                "after two misses the call shot must score (seed \(seed))"
            )
        }
    }

    /// The compute dock must lock the given quantity per level type: A
    /// locks the given speed (solve θ), B locks the given angle (solve v),
    /// C locks the whole shot (find your range). Only Level D / untyped
    /// scenarios keep both sliders free. A question needs a real unknown.
    func test_callComputePlan_locksTheGivenPerLevelType() throws {
        XCTAssertEqual(
            CallComputePlan.lock(for: try loadScenario("bb-a-freethrow")),
            .velocity(7.5)
        )
        XCTAssertEqual(
            CallComputePlan.lock(for: try loadScenario("bb-b-rainbow")),
            .theta(65.0)
        )
        XCTAssertEqual(
            CallComputePlan.lock(for: try loadScenario("bb-c-wing-throw")),
            .range
        )
        XCTAssertEqual(
            CallComputePlan.lock(for: try loadScenario("bb-1-baseline")),
            .none
        )
        // Every released seed must resolve its lock — a missing given would
        // silently degrade the question back to the sandbox.
        let chapter = try XCTUnwrap(BasketballCurriculum.chapters.first { $0.id == "bb-ch1-arc" })
        for id in chapter.releasedPracticeSeeds(for: .findTheta) {
            if case .velocity = CallComputePlan.lock(for: try loadScenario(id)) {} else {
                XCTFail("[\(id)] released Level A seed has no locked speed")
            }
        }
        for id in chapter.releasedPracticeSeeds(for: .findV) {
            if case .theta = CallComputePlan.lock(for: try loadScenario(id)) {} else {
                XCTFail("[\(id)] released Level B seed has no locked angle")
            }
        }
        for id in chapter.releasedPracticeSeeds(for: .findD) {
            let scenario = try loadScenario(id)
            guard case .range = CallComputePlan.lock(for: scenario) else {
                XCTFail("[\(id)] released Level C seed does not resolve range mode")
                continue
            }
            // The dealer must produce an answerable round 1 for every seed.
            var rng = SeededLCG(seed: 11)
            XCTAssertNotNil(PickSpotChallenge.round(for: scenario, attempt: 1, using: &rng),
                            "[\(id)] no dealable round 1")
        }
    }

    /// Pick-the-spot: the crossing distance must come from the real
    /// integrator and match the authored answer; round 1 is canonical,
    /// retries move the answer so the hoop can't be eyeballed.
    func test_pickSpotChallenge_crossingMatchesAuthoredAnswer() throws {
        let scenario = try loadScenario("bb-c-wing-throw")
        guard case .projectile2D(_, let params) = scenario.simulation else {
            return XCTFail("expected projectile scenario")
        }

        var rng = SeededLCG(seed: 3)
        let round1 = try XCTUnwrap(PickSpotChallenge.round(for: scenario, attempt: 1, using: &rng))
        XCTAssertEqual(round1.answer.thetaDegrees, 48.0)
        XCTAssertEqual(round1.answer.velocity, 8.2)
        // Semi-implicit Euler at dt≈8.3ms lands ~5cm short of the closed-form
        // 5.82 (O(dt) bias ≈ ½·g·dt·t). The rim tolerance (0.225m) absorbs
        // it, so a player who computes the textbook answer always hits —
        // asserted below. The crossing itself must match the renderer.
        XCTAssertEqual(round1.crossingD, 5.82, accuracy: 0.1,
                       "canonical crossing must track the authored d ≈ 5.82")
        XCTAssertTrue(PickSpotChallenge.isHit(markerD: 5.82, crossingD: round1.crossingD, params: params),
                      "the textbook answer must always count as a hit")

        let round2 = try XCTUnwrap(PickSpotChallenge.round(for: scenario, attempt: 2, using: &rng))
        XCTAssertNotEqual(round2.answer.velocity, round1.answer.velocity,
                          "retry rounds must perturb the givens")
        XCTAssertGreaterThan(abs(round2.crossingD - round1.crossingD), 0.05,
                             "perturbed round must move the crossing point")

        // Every dealt round must be answerable on the slider: 30 retries,
        // all inside the playable band shared with the range slider.
        let playable = PickSpotChallenge.playableRange(params: params)
        for n in 2...30 {
            let r = try XCTUnwrap(PickSpotChallenge.round(for: scenario, attempt: n, using: &rng))
            XCTAssertTrue(playable.contains(r.crossingD),
                          "round \(n) answer \(r.crossingD) is outside the playable band \(playable)")
        }

        XCTAssertTrue(PickSpotChallenge.isHit(markerD: round1.crossingD + 0.2,
                                              crossingD: round1.crossingD, params: params))
        XCTAssertFalse(PickSpotChallenge.isHit(markerD: round1.crossingD + 0.3,
                                               crossingD: round1.crossingD, params: params))
    }

    // MARK: - Call-guard helpers

    private func loadScenario(_ stem: String) throws -> ScenarioDefinition {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(bundle.url(forResource: stem, withExtension: "json"),
                                "\(stem).json not found in test bundle")
        return try ScenarioLoader.decode(Data(contentsOf: url), scenarioId: ScenarioID(stem))
    }

    private func allBundleScenarios() throws -> [ScenarioDefinition] {
        let bundle = Bundle(for: type(of: self))
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("bb-") }
        XCTAssertGreaterThan(urls.count, 1, "Expected multiple scenarios in bundle.")
        return try urls.map { url in
            let stem = url.deletingPathExtension().lastPathComponent
            return try ScenarioLoader.decode(Data(contentsOf: url), scenarioId: ScenarioID(stem))
        }
    }
}

/// Deterministic RNG for the picker test.
private struct SeededLCG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
