import SwiftUI
import SpriteKit

/// Screen 5 — SCENARIO PLAY. Composes HUD/Scene/Input; PlaySceneNode owns the SpriteKit drawing.
struct PlayView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(AudioService.self) private var audio

    let scenario: ScenarioDefinition

    /// Optional so diagnostic/standalone launches without a container still compile.
    var onClose: (() -> Void)? = nil

    /// @State so the scene isn't recreated on every SwiftUI re-render.
    @State private var scene: PlaySceneNode

    /// Prevents double-mutation when SwiftUI re-renders the outcome view.
    @State private var outcomeWritten: Bool = false

    @State private var thetaValue: String = ProcessInfo.processInfo.environment["ARCLAB_PRESET_THETA"] ?? ""
    @State private var velocityValue: String = ProcessInfo.processInfo.environment["ARCLAB_PRESET_V"] ?? ""
    @State private var activeField: PlayInputView.InputField = .theta

    @State private var phase: Phase = .idle

    @State private var attemptCounter: Int = 1

    @State private var solutionPresented: Bool = false

    @State private var isNumpadVisible: Bool = true

    /// Caps next score at 1pt — "paid is paid".
    @State private var solutionLocksAttemptAt1pt: Bool = false

    enum Phase: Sendable, Equatable {
        case idle
        case action
        case outcome(Resolution)

        enum Resolution: Sendable, Equatable {
            case success(flavor: String)
            case miss(category: String)
        }
    }

    init(scenario: ScenarioDefinition, onClose: (() -> Void)? = nil) {
        self.scenario = scenario
        self.onClose = onClose
        guard case .projectile2D(_, let params) = scenario.simulation else {
            fatalError("PlayView currently supports only PROJECTILE_2D scenarios")
        }
        // SpriteView resizes via didChangeSize once the SwiftUI layout pass settles.
        let initialSize = CGSize(width: 393, height: 340)
        _scene = State(initialValue: PlaySceneNode(projectileParams: params, size: initialSize))
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = PlayLayoutMetrics.compute(
                for: geometry.size,
                safeArea: geometry.safeAreaInsets
            )

            ZStack(alignment: .top) {
                // Z0 — full-bleed court canvas.
                Color.arclabBlack.ignoresSafeArea()
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)  // input overlays own taps

                // HUD overlay (top). Spacer is non-hit-testing so it doesn't
                // swallow taps belonging to the bottom overlay or the scene.
                VStack(spacing: 0) {
                    PlayHUDView(
                        scenario: scenario,
                        // CLOSE on IDLE+OUTCOME; hidden in ACTION (no escape mid-flight).
                        onClose: phase == .action ? nil : onClose
                    )
                    .frame(height: 140)
                    .opacity(phase == .action ? 0.5 : 1.0)
                    Spacer()
                        .allowsHitTesting(false)
                }
                .animation(.easeOut(duration: 0.25), value: phase)

                // Bottom overlay — input dock (.idle) or outcome (.outcome).
                VStack(spacing: 0) {
                    Spacer()
                        .allowsHitTesting(false)
                    if case .idle = phase {
                        PlayInputView(
                            scenario: scenario,
                            thetaValue: $thetaValue,
                            velocityValue: $velocityValue,
                            activeField: $activeField,
                            onShoot: handleShoot,
                            isNumpadVisible: $isNumpadVisible
                        )
                        .frame(height: 330)
                        .background(Color.arclabBlack)
                        .transition(.opacity)
                    } else if case let .outcome(resolution) = phase {
                        outcomeView(resolution: resolution)
                            .frame(height: 480)
                            .background(Color.arclabBlack)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.25), value: phase)
            }
            .onAppear {
                propagateLayout(metrics: metrics, phase: phase)
            }
            .onChange(of: phase) { _, newPhase in
                propagateLayout(metrics: metrics, phase: newPhase)
            }
            .onChange(of: geometry.size) { _, _ in
                propagateLayout(metrics: metrics, phase: phase)
            }
        }
        .statusBarHidden(true)
        .onChange(of: thetaValue) { _, newValue in
            scene.updateAngleIndicator(degrees: Double(newValue))
            updateDribbleForInputState()
        }
        .onChange(of: velocityValue) { _, _ in
            updateDribbleForInputState()
        }
        .onAppear {
            // Diagnostic env-preset path needs the indicator pushed once.
            if !thetaValue.isEmpty {
                scene.updateAngleIndicator(degrees: Double(thetaValue))
            }
            updateDribbleForInputState()
            // Scene fires audio events adjacent to physics; outcome SFX fire here adjacent to the phase transition.
            scene.audio = audio
            audio.startLoop(.dribbleLoop)

            scene.onOutcomeResolved = { outcome, _ in
                Task { @MainActor in
                    scene.freezeForOutcome()
                    switch outcome {
                    case .success(let flavor):
                        switch flavor {
                        case "SWISH":
                            audio.play(.swish)
                            scene.playNetFlex()
                        case "GLASS":
                            audio.play(.glass)
                        case "RIM_DROP":
                            audio.play(.rimDrop)
                        default:
                            audio.play(.swish)
                        }
                        phase = .outcome(.success(flavor: flavor))
                    case .miss(let category):
                        // AIRBALL gets its own sound; everything else gets the sacred sustained tone.
                        if category == "AIRBALL" {
                            audio.play(.airball)
                        } else {
                            audio.play(.missTone)
                        }
                        phase = .outcome(.miss(category: category))
                    case .inFlight:
                        break  // shouldn't happen — callback only fires on resolve
                    }
                }
            }
            // Diagnostic auto-fire for screenshot verification.
            if ProcessInfo.processInfo.environment["ARCLAB_AUTOSHOOT"] == "1",
               !thetaValue.isEmpty, !velocityValue.isEmpty {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    handleShoot()
                }
            }
        }
        .onDisappear {
            audio.stopLoop(.dribbleLoop)
        }
        .fullScreenCover(isPresented: $solutionPresented) {
            SolutionView(
                scenario: scenario,
                attempt: attemptCounter,
                onClose: handleSolutionClose,
                onTryCanonical: handleTryCanonical
            )
        }
    }

    private func handleShoot() {
        guard let theta = Double(thetaValue), let v = Double(velocityValue) else { return }
        phase = .action
        scene.startSimulation(answer: ProjectileAnswer(thetaDegrees: theta, velocity: v))
    }

    /// Hold the ball once the player starts typing (free-throw shooters
    /// don't keep bouncing during the math). Resume only on full clear.
    private func updateDribbleForInputState() {
        guard case .idle = phase else { return }
        if thetaValue.isEmpty && velocityValue.isEmpty {
            scene.resumeIdleDribble()
        } else {
            scene.pauseIdleDribble()
        }
    }

    /// Push current UI reserves to the scene so the world transform frames
    /// inside the unoccluded vertical band.
    private func propagateLayout(metrics: PlayLayoutMetrics, phase: Phase) {
        let bottom: CGFloat
        switch phase {
        case .idle:                bottom = metrics.bottomReserveIdle
        case .action:              bottom = metrics.bottomReserveAction
        case .outcome:             bottom = metrics.bottomReserveOutcome
        }
        scene.applyUIReserve(
            top: metrics.topReserve,
            bottom: bottom,
            safeTop: metrics.topReserve,        // top reserve already includes safe-area
            safeBottom: bottom
        )
    }

    @ViewBuilder
    private func outcomeView(resolution: Phase.Resolution) -> some View {
        switch resolution {
        case .success(let flavor):
            let isFirstTry = attemptCounter == 1 && flavor == "SWISH"
            let earnedXP = computeEarnedXP(flavor: flavor)
            SwishView(
                scenario: scenario,
                flavor: flavor,
                theta: Double(thetaValue) ?? 0,
                velocity: Double(velocityValue) ?? 0,
                score: computeScore(flavor: flavor),
                isFirstTryClean: isFirstTry,
                xpGained: earnedXP,
                onNextLevel: handleNextLevel,
                onReplay: handleReplay
            )
            .onAppear {
                persistSuccessOutcome(flavor: flavor, isFirstTry: isFirstTry, earnedXP: earnedXP)
            }
        case .miss(let category):
            MissedView(
                scenario: scenario,
                category: category,
                attempt: attemptCounter,
                onTryAgain: handleTryAgain,
                onSolution: handleSolutionRoute
            )
            .onAppear {
                scene.renderMissArcs(ghostTrajectory: cachedGhostTrajectory)
            }
        }
    }

    /// Idempotent — outcomeWritten guards against double-increment on SwiftUI re-renders.
    private func persistSuccessOutcome(flavor: String, isFirstTry: Bool, earnedXP: Int) {
        guard !outcomeWritten else { return }
        outcomeWritten = true

        let id = scenario.scenarioId
        let now = Date()

        profile.mutate { p in
            var record = p.completedScenarios[id] ?? ScenarioRecord.newRecord(now: now)
            let scoreNow = computeScore(flavor: flavor)
            let newBest = max(record.bestScore, scoreNow)
            record.bestScore = newBest
            if record.firstCompletedAt == nil {
                record.firstCompletedAt = now
            } else {
                record.replayAfterSuccessFlag = true
            }
            if isFirstTry {
                record.watermarkEarnedFlag = true
            }
            // Next time the player opens this scenario, they start fresh.
            record.attemptCounter = 1
            record.lastPlayedAt = now
            p.completedScenarios[id] = record

            // earnedXP already incorporates the anti-farming decay.
            p.totalXP += earnedXP
            p.recomputeRank()
        }
    }

    /// Full score on first success, 10% on subsequent attempts (anti-farming decay).
    private func computeEarnedXP(flavor: String) -> Int {
        let baseScore = computeScore(flavor: flavor)
        let alreadyCompleted = (profile.profile.completedScenarios[scenario.scenarioId]?.firstCompletedAt) != nil
        if alreadyCompleted {
            return Int((Double(baseScore) * 0.1).rounded())
        }
        return baseScore
    }

    /// Hard-locked at 1 if the player viewed SOLUTION this session ("paid is paid").
    private func computeScore(flavor: String) -> Int {
        if solutionLocksAttemptAt1pt { return 1 }
        let base = Double(scenario.outcome.baseScore)
        let multiplier = scenario.outcome.successFlavors.first(where: { $0.id == flavor })?.scoreMultiplier ?? 1.0
        return Int((base * multiplier).rounded())
    }

    /// Cached here until ScenarioSession lifecycle is wired into PlayView.
    private var cachedGhostTrajectory: [CGPoint] {
        guard let ghost = scenario.outcome.ghostArc,
              case .projectile2D(_, let params) = scenario.simulation else { return [] }
        let answer = ProjectileAnswer(
            thetaDegrees: ghost.answer["theta"] ?? 0,
            velocity: ghost.answer["v"] ?? 0
        )
        return Projectile2DModule()
            .headlessRun(params: params, answer: answer, fixedDt: params.fixedDtSeconds)
            .map { $0.ballPosition }
    }

    private func handleNextLevel() {
        // MVP has only one scenario — fall through to REPLAY for now.
        handleReplay()
    }

    private func handleReplay() {
        thetaValue = ""
        velocityValue = ""
        attemptCounter = 1
        outcomeWritten = false
        scene.resetForNewShot()
        phase = .idle
    }

    private func handleTryAgain() {
        thetaValue = ""
        velocityValue = ""
        attemptCounter += 1
        outcomeWritten = false
        scene.resetForNewShot()
        phase = .idle
    }

    private func handleSolutionRoute() {
        solutionLocksAttemptAt1pt = true
        solutionPresented = true
    }

    private func handleSolutionClose() {
        solutionPresented = false
    }

    private func handleTryCanonical(theta: Double, v: Double) {
        thetaValue = String(format: "%g", theta)
        velocityValue = String(format: "%g", v)
        solutionPresented = false
        // The pre-filled retry is itself an attempt.
        attemptCounter += 1
        outcomeWritten = false
        scene.resetForNewShot()
        phase = .idle
    }
}
