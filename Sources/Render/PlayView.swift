import SwiftUI
import SpriteKit

/// Screen 5 — SCENARIO PLAY. Composes HUD/Scene/Input; PlaySceneNode owns the SpriteKit drawing.
struct PlayView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(AudioService.self) private var audio
    @Environment(AccessibilitySettings.self) private var accessibility
    @Environment(\.horizontalSizeClass) private var hSizeClass

    let scenario: ScenarioDefinition

    /// Optional so diagnostic/standalone launches without a container still compile.
    /// `onClose` fires on user-initiated bail (CLOSE chip or swipe back).
    /// `onRequestNext` fires on the v3 outcome action — router uses this to
    /// advance within a multi-seed push or return to the chapter for a
    /// single-scenario release. Both default to popping back to the picker.
    var onClose: (() -> Void)? = nil
    var onRequestNext: (() -> Void)? = nil

    /// Kept from init so VoiceOver scene narration can describe the court at
    /// the view layer (the scene itself is invisible to the accessibility tree).
    private let projectileParams: Projectile2DParams

    /// @State so the scene isn't recreated on every SwiftUI re-render.
    @State private var scene: PlaySceneNode

    /// Prevents double-mutation when SwiftUI re-renders the outcome view.
    @State private var outcomeWritten: Bool = false

    @State private var thetaValue: String = ProcessInfo.processInfo.environment["ARCLAB_PRESET_THETA"] ?? ""
    @State private var velocityValue: String = ProcessInfo.processInfo.environment["ARCLAB_PRESET_V"] ?? ""
    @State private var distanceValue: String = ""    // v3 — Level Type C
    @State private var activeField: PlayInputView.InputField = .theta

    /// v3 mastery telemetry: when the scenario was opened, for time-to-answer.
    @State private var scenarioOpenedAt: Date = Date()

    /// v3 §3.5 — queue of milestone celebrations fired after PlayView outcomes.
    /// Multiple can stack on one resolved shot (e.g. final Level D clear of
    /// Ch 1: level-type gate → chapter-mastery → maybe tier-up). The
    /// fullScreenCover binding fires them in order; each tap pops the next.
    @State private var pendingCelebrations: [Celebration] = []

    @State private var phase: Phase = .idle

    @State private var attemptCounter: Int = 1

    @State private var solutionPresented: Bool = false

    @State private var isNumpadVisible: Bool = true

    /// Haptic counters. Each event flips its own counter, so .sensoryFeedback
    /// fires once per occurrence (SwiftUI watches for value change).
    @State private var shootHapticCount: Int = 0
    @State private var swishHapticCount: Int = 0
    @State private var missHapticCount: Int = 0

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

    init(
        scenario: ScenarioDefinition,
        onClose: (() -> Void)? = nil,
        onRequestNext: (() -> Void)? = nil
    ) {
        self.scenario = scenario
        self.onClose = onClose
        self.onRequestNext = onRequestNext
        guard case .projectile2D(_, let params) = scenario.simulation else {
            fatalError("PlayView currently supports only PROJECTILE_2D scenarios")
        }
        self.projectileParams = params
        // SpriteView resizes via didChangeSize once the SwiftUI layout pass settles.
        let initialSize = CGSize(width: 393, height: 340)
        _scene = State(initialValue: PlaySceneNode(projectileParams: params, size: initialSize))
    }

    /// The live scene description VoiceOver reads off the court canvas.
    private var sceneAccessibilityValue: String {
        switch phase {
        case .idle:
            return "Shooter at the line, waiting on your numbers."
        case .action:
            return "Ball in flight."
        case .outcome(.success):
            return "Ball went through the net."
        case .outcome(.miss):
            return "Shot missed."
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = PlayLayoutMetrics.compute(
                for: geometry.size,
                safeArea: geometry.safeAreaInsets
            )
            let ctx = LayoutContext.resolve(
                horizontalSizeClass: hSizeClass,
                size: geometry.size,
                safeArea: geometry.safeAreaInsets
            )
            // iPad landscape: the chrome dock becomes a right-side column and
            // the court frames into the left band. Everywhere else (iPhone +
            // iPad portrait) keeps the legacy bottom-dock layout.
            let useSideDock = ctx.isRegular && ctx.isWide

            ZStack(alignment: .top) {
                // Z0 — full-bleed court canvas.
                Color.arclabBlack.ignoresSafeArea()
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)  // input overlays own taps
                    // SKScene content never reaches the accessibility tree —
                    // narrate the court so the numpad inputs have context.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(SceneNarration.basketballLabel(params: projectileParams))
                    .accessibilityValue(sceneAccessibilityValue)
                    .accessibilityIgnoresInvertColors()

                // HUD overlay (top). Spacer is non-hit-testing so it doesn't
                // swallow taps belonging to the bottom overlay or the scene.
                VStack(spacing: 0) {
                    PlayHUDView(
                        scenario: scenario,
                        // CLOSE on IDLE+OUTCOME; hidden in ACTION (no escape mid-flight).
                        onClose: phase == .action ? nil : onClose
                    )
                    .opacity(phase == .action ? 0.5 : 1.0)
                    Spacer()
                        .allowsHitTesting(false)
                }
                .animation(.easeOut(duration: 0.25), value: phase)

                // Chrome dock — input (.idle) or outcome (.outcome). Hidden in
                // .action so the shot flies across the full canvas.
                if phase != .action {
                    if useSideDock {
                        sideDock(width: AdaptiveMetrics.sideDockWidth(for: geometry.size.width),
                                 topReserve: metrics.topReserve)
                    } else {
                        bottomDock()
                    }
                }
            }
            .onAppear {
                propagateLayout(ctx: ctx, metrics: metrics, phase: phase)
            }
            .onChange(of: phase) { _, newPhase in
                propagateLayout(ctx: ctx, metrics: metrics, phase: newPhase)
            }
            .onChange(of: geometry.size) { _, _ in
                propagateLayout(ctx: ctx, metrics: metrics, phase: phase)
            }
        }
        .statusBarHidden(true)
        .onChange(of: thetaValue) { _, newValue in
            // Only drive the indicator from input when the player owns θ.
            if scenario.input.mode == .numpadDual || scenario.input.mode == .numpadSingleTheta {
                scene.updateAngleIndicator(degrees: Double(newValue))
            }
            updateDribbleForInputState()
        }
        .onChange(of: velocityValue) { _, _ in
            updateDribbleForInputState()
        }
        .onChange(of: distanceValue) { _, _ in
            updateDribbleForInputState()
        }
        // Mid-session toggles (Settings or iOS) retune the running scene.
        .onChange(of: accessibility.reduceMotionActive) { _, on in
            scene.setReduceMotion(on)
        }
        .onAppear {
            scene.setReduceMotion(accessibility.reduceMotionActive)
            // Single-V/single-D modes: show the given θ as a static cue on the court.
            if (scenario.input.mode == .numpadSingleV || scenario.input.mode == .numpadSingleD),
               let givenTheta = givenVariable("theta") {
                scene.updateAngleIndicator(degrees: givenTheta)
            }
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
                        swishHapticCount += 1   // .success haptic — sharp, rewarding double-tick
                    case .miss(let category):
                        // AIRBALL gets its own sound; everything else gets the sacred sustained tone.
                        if category == "AIRBALL" {
                            audio.play(.airball)
                        } else {
                            audio.play(.missTone)
                        }
                        phase = .outcome(.miss(category: category))
                        missHapticCount += 1    // .error haptic — long buzz, the body knows
                    case .inFlight:
                        break  // shouldn't happen — callback only fires on resolve
                    }
                }
            }
            // Diagnostic auto-fire for screenshot verification.
            if ProcessInfo.processInfo.environment["ARCLAB_AUTOSHOOT"] == "1",
               autoshootReady {
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
        // v3 §3.2–§3.5 — milestone celebration queue. Multiple can stack on a
        // single mastered shot (level-type → chapter-mastery → tier-up); the
        // cover fires them one at a time, each tap advances to the next.
        // Once the queue empties, pop back to the level-type picker.
        .fullScreenCover(item: Binding(
            get: { pendingCelebrations.first },
            set: { _ in /* dismissal goes through onTap below */ }
        )) { celebration in
            CelebrationView(celebration: celebration) {
                pendingCelebrations.removeFirst()
                if pendingCelebrations.isEmpty {
                    // After celebrations end, ask the router for a fresh
                    // seed so the player keeps grinding instead of bouncing
                    // back to the picker. Falls back to onClose if no
                    // router callback is wired (diagnostic launches).
                    if let onRequestNext {
                        onRequestNext()
                    } else {
                        onClose?()
                    }
                }
            }
        }
        // iOS-native escape: swipe-down or edge-swipe-right dismisses PlayView,
        // matching the CLOSE chip's gating (action phase locks both).
        .swipeBackToDismiss(
            isEnabled: phase != .action && onClose != nil
        ) {
            onClose?()
        }
        // Haptic texture: medium thud on SHOOT, .success on swish, .error on miss.
        // Keeps the play loop physically grounded — every key beat has a body cue.
        .gameHaptic(.impact(weight: .medium), trigger: shootHapticCount)
        .gameHaptic(.success, trigger: swishHapticCount)
        .gameHaptic(.error, trigger: missHapticCount)
    }

    private func handleShoot() {
        // v3: source unsupplied variables from situation.variables for single-unknown modes.
        let theta: Double
        let v: Double
        switch scenario.input.mode {
        case .numpadSingleTheta:
            guard let t = Double(thetaValue),
                  let givenV = givenVariable("v") else { return }
            theta = t
            v = givenV
        case .numpadSingleV:
            guard let parsedV = Double(velocityValue),
                  let givenTheta = givenVariable("theta") else { return }
            theta = givenTheta
            v = parsedV
        case .numpadSingleD:
            // Level Type C: player supplies the predicted distance. Both
            // θ and v are given by the scenario; we still need to fire a
            // shot in the sim so the player sees where the ball lands.
            // Scoring against the player's distance happens at outcome time
            // (see Day 5 — adaptive scoring). For now, just simulate the
            // given (θ, v) and let the existing outcome categorize.
            guard let givenTheta = givenVariable("theta"),
                  let givenV = givenVariable("v") else { return }
            theta = givenTheta
            v = givenV
        default:
            // NUMPAD_DUAL legacy path: both fields driven by the player.
            guard let t = Double(thetaValue), let parsedV = Double(velocityValue) else { return }
            theta = t
            v = parsedV
        }
        phase = .action
        shootHapticCount += 1   // heavy impact on launch — feels like a release
        scene.startSimulation(answer: ProjectileAnswer(thetaDegrees: theta, velocity: v))
    }

    /// Reads a given variable's value from `scenario.situation.variables`
    /// for the case the player isn't supplying it (single-unknown level types).
    private func givenVariable(_ symbol: String) -> Double? {
        scenario.situation.variables.first(where: { $0.symbol == symbol })?.value
    }

    /// Hold the ball once the player starts typing (free-throw shooters
    /// don't keep bouncing during the math). Resume only on full clear.
    private func updateDribbleForInputState() {
        guard case .idle = phase else { return }
        // For single-unknown modes, only the relevant field matters.
        let anyInputActive: Bool
        switch scenario.input.mode {
        case .numpadSingleTheta:
            anyInputActive = !thetaValue.isEmpty
        case .numpadSingleV:
            anyInputActive = !velocityValue.isEmpty
        case .numpadSingleD:
            anyInputActive = !distanceValue.isEmpty
        default:
            anyInputActive = !thetaValue.isEmpty || !velocityValue.isEmpty
        }
        if anyInputActive {
            scene.pauseIdleDribble()
        } else {
            scene.resumeIdleDribble()
        }
    }

    /// Push current UI reserves to the scene so the world transform frames
    /// inside the unoccluded band. In iPad landscape the dock occludes a
    /// right-side column (rightReserve); elsewhere it occludes a bottom band.
    /// In .action the dock is hidden, so the court reclaims the full canvas.
    private func propagateLayout(ctx: LayoutContext, metrics: PlayLayoutMetrics, phase: Phase) {
        let desiredBottom: CGFloat
        switch phase {
        case .idle:    desiredBottom = metrics.bottomReserveIdle
        case .action:  desiredBottom = metrics.bottomReserveAction
        case .outcome: desiredBottom = metrics.bottomReserveOutcome
        }
        let am = AdaptiveMetrics.compute(
            ctx: ctx,
            topReserve: metrics.topReserve,
            desiredBottomDockHeight: desiredBottom
        )
        // .action hides the dock → full-bleed flight (no side/bottom reserve
        // beyond the safe area).
        let right: CGFloat = phase == .action ? 0 : am.rightReserve
        let bottom: CGFloat = phase == .action ? metrics.bottomReserveAction : am.bottomReserve
        scene.applyUIReserve(
            top: am.topReserve,
            bottom: bottom,
            safeTop: am.topReserve,        // top reserve already includes safe-area
            safeBottom: bottom,
            right: right
        )
    }

    /// The input dock (.idle) or outcome composition (.outcome). Phase-aware;
    /// returns nothing in .action (caller hides the dock entirely then).
    @ViewBuilder
    private func dockContent() -> some View {
        if case .idle = phase {
            switch scenario.input.mode {
            case .numpadSingleTheta:
                PlayInputSingleFieldView(
                    scenario: scenario, value: $thetaValue,
                    onShoot: handleShoot, isNumpadVisible: $isNumpadVisible
                )
            case .numpadSingleV:
                PlayInputSingleFieldView(
                    scenario: scenario, value: $velocityValue,
                    onShoot: handleShoot, isNumpadVisible: $isNumpadVisible
                )
            case .numpadSingleD:
                PlayInputSingleFieldView(
                    scenario: scenario, value: $distanceValue,
                    onShoot: handleShoot, isNumpadVisible: $isNumpadVisible
                )
            default:
                PlayInputView(
                    scenario: scenario,
                    thetaValue: $thetaValue, velocityValue: $velocityValue,
                    activeField: $activeField,
                    onShoot: handleShoot, isNumpadVisible: $isNumpadVisible
                )
            }
        } else if case let .outcome(resolution) = phase {
            outcomeView(resolution: resolution)
        }
    }

    /// Legacy bottom-pinned dock (iPhone + iPad portrait). Unchanged heights.
    private func bottomDock() -> some View {
        let height: CGFloat = { if case .outcome = phase { return 480 } else { return 330 } }()
        return VStack(spacing: 0) {
            Spacer().allowsHitTesting(false)
            dockContent()
                .frame(height: height)
                .background(Color.arclabBlack)
                .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.25), value: phase)
    }

    /// iPad landscape: dock as a trailing column spanning below the HUD to the
    /// bottom edge. The court frames into the band left of it (rightReserve).
    /// The top `topReserve` strip is left clear so the HUD (incl. the trailing
    /// level chip + variable strip) reads across the full width.
    private func sideDock(width: CGFloat, topReserve: CGFloat) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0).allowsHitTesting(false)   // court shows through (left)
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: topReserve)             // keep HUD visible above
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    Spacer(minLength: 0).allowsHitTesting(false)
                    dockContent()
                    Spacer(minLength: 0).allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.arclabBlack)
            }
            .frame(width: width)
            .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.25), value: phase)
    }

    @ViewBuilder
    private func outcomeView(resolution: Phase.Resolution) -> some View {
        switch resolution {
        case .success(let flavor):
            let isFirstTry = attemptCounter == 1 && flavor == "SWISH"
            let earnedXP = computeEarnedXP(flavor: flavor)
            SwishView(
                // v3 audit polish: stats show the actual shot's θ and v,
                // sourcing from either user input or the scenario-given
                // variable depending on which one the player solved for.
                scenario: scenario,
                flavor: flavor,
                theta: Double(thetaValue) ?? givenVariable("theta") ?? 0,
                velocity: Double(velocityValue) ?? givenVariable("v") ?? 0,
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
                persistMissOutcome(category: category)
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

            // v3: record the attempt and queue two celebration kinds —
            // level-type promotion + chapter mastery (if this write cleared
            // the last level type in the chapter). Tier-up + completion
            // celebrations were cut after audit; XP/IQ progression still
            // shows in HomeView and ProfileView.
            let preChapterMastered = chapterIsMastered(in: p)
            let didMaster = recordV3Attempt(
                profile: &p,
                outcome: outcomeFromFlavor(flavor),
                isFirstTry: isFirstTry,
                now: now
            )
            let postChapterMastered = chapterIsMastered(in: p)

            var queue: [Celebration] = []
            if didMaster, let lt = scenario.meta.levelType {
                queue.append(.levelType(lt))
            }
            if !preChapterMastered, postChapterMastered, let chapter = currentChapter() {
                queue.append(.chapterMastery(chapter: chapter))
            }
            if !queue.isEmpty {
                Task { @MainActor in
                    pendingCelebrations.append(contentsOf: queue)
                }
            }
        }
    }

    /// v3: record a miss into the level-type mastery model. Miss → 0.0 score.
    private func persistMissOutcome(category: String) {
        // Misses still update the rolling window for mastery (per locked spec:
        // miss doesn't reset, the window just shifts). Don't dedupe via
        // outcomeWritten — each miss attempt is its own record.
        let now = Date()
        profile.mutate { p in
            recordV3Attempt(
                profile: &p,
                outcome: .miss,
                isFirstTry: attemptCounter == 1,
                now: now
            )
        }
    }

    /// Shared mastery-write helper. No-op for legacy scenarios with no v3 metadata.
    /// Returns true iff this attempt promoted the level type to MASTERED.
    @discardableResult
    private func recordV3Attempt(
        profile p: inout PlayerProfile,
        outcome: AttemptOutcome,
        isFirstTry: Bool,
        now: Date
    ) -> Bool {
        guard let chapterId = scenario.meta.chapterId,
              let levelType = scenario.meta.levelType else { return false }
        let bucket = scenario.meta.difficultyBucket ?? .easy
        let timeMs = Int(now.timeIntervalSince(scenarioOpenedAt) * 1000)
        let attempt = AttemptRecord(
            situationId: scenario.scenarioId.rawValue,
            levelTypeId: levelType.rawValue,
            outcome: outcome,
            isFirstTry: isFirstTry,
            hintsUsed: 0,                       // v1 — hint tracking deferred
            timeToAnswerMs: max(0, timeMs),
            difficultyBucket: bucket,
            wasReview: false,                   // wired in Day 12 review scheduler
            wasInterleaved: false,              // wired in Day 11 picker integration
            timestamp: now
        )
        return MasteryService.recordAttempt(
            attempt,
            chapterId: chapterId,
            levelType: levelType,
            in: &p,
            now: now
        )
    }

    /// Find the Chapter object owning this scenario, for celebration queueing.
    private func currentChapter() -> Chapter? {
        guard let chapterId = scenario.meta.chapterId else { return nil }
        return BasketballCurriculum.chapters.first { $0.id == chapterId }
    }

    /// True iff every released level type of the current scenario's chapter
    /// is .mastered. Broader basketball level types stay available to
    /// diagnostics until they become player-facing.
    private func chapterIsMastered(in profile: PlayerProfile) -> Bool {
        guard let chapter = currentChapter() else { return false }
        let levelTypes = chapter.releasedPracticeLevelTypes.isEmpty
            ? LevelTypeID.earthChapterTypes
            : chapter.releasedPracticeLevelTypes
        return levelTypes.allSatisfy { lt in
            let key = MasteryService.key(chapterId: chapter.id, levelType: lt)
            return profile.levelTypeMasteries[key]?.status == .mastered
        }
    }

    /// Is the input ready to autoshoot? Mode-aware: only requires the
    /// fields the player would actually fill for the current input mode.
    private var autoshootReady: Bool {
        switch scenario.input.mode {
        case .numpadSingleTheta: return !thetaValue.isEmpty
        case .numpadSingleV:     return !velocityValue.isEmpty
        case .numpadSingleD:     return !distanceValue.isEmpty
        default:                 return !thetaValue.isEmpty && !velocityValue.isEmpty
        }
    }

    /// v1 outcome flavor → v3 AttemptOutcome.
    private func outcomeFromFlavor(_ flavor: String) -> AttemptOutcome {
        switch flavor {
        case "SWISH":    return .swish
        case "GLASS":    return .glass
        case "RIM_DROP": return .rimDrop
        default:         return .swish
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
        // Router-backed launches ask the container to advance or close the
        // push. Standalone legacy v2 scenarios with no router still replay.
        if onRequestNext != nil || scenario.meta.levelType != nil {
            // Ask the router to advance or close the level-type push.
            // Falls back to onClose (then to handleReplay) if no router is
            // wired (diagnostic launches).
            if let onRequestNext {
                onRequestNext()
            } else if let onClose {
                onClose()
            } else {
                handleReplay()
            }
        } else {
            handleReplay()
        }
    }

    private func handleReplay() {
        thetaValue = ""
        velocityValue = ""
        distanceValue = ""
        attemptCounter = 1
        outcomeWritten = false
        scenarioOpenedAt = Date()
        scene.resetForNewShot()
        phase = .idle
    }

    private func handleTryAgain() {
        thetaValue = ""
        velocityValue = ""
        distanceValue = ""
        attemptCounter += 1
        outcomeWritten = false
        scenarioOpenedAt = Date()
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
