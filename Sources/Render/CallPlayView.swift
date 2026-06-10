import SwiftUI
import SpriteKit

/// v2.1 call-first play surface. Renders the v1 SpriteKit court via
/// PlaySceneNode, but drives the 5-beat call mechanic from CONCEPT_v2.1 §4:
///
///   STANCE   →  RELEASE  →  FROZEN at apex  →  FINISH  →  VERDICT (+ correctness)
///
/// No numpad: the user is *calling* yes/no on the scenario's canonical truth
/// shot, not computing it. Compute mode (the slider dock + formula
/// walkthrough) is a separate beat that chains after the verdict if the
/// user wants to go deeper.
struct CallPlayView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(AudioService.self) private var audio
    @Environment(AccessibilitySettings.self) private var accessibility
    @Environment(\.horizontalSizeClass) private var hSizeClass

    let scenario: ScenarioDefinition
    /// Curriculum chapter the scenario belongs to. Drives the reveal beat:
    /// the chapter's lesson title becomes the physics phenomenon shown on
    /// the verdict screen, and the lesson's one-liner becomes the explainer.
    /// Optional so diagnostic / standalone launches still compile.
    let chapter: Chapter?
    var onClose: (() -> Void)? = nil

    /// Kept from init so VoiceOver scene narration can compute reads at the
    /// view layer (the scene itself is invisible to the accessibility tree).
    private let projectileParams: Projectile2DParams

    /// @State so the scene isn't recreated on every SwiftUI re-render.
    @State private var scene: PlaySceneNode

    /// 5-beat phase.
    @State private var phase: Phase = .stance

    /// The user's call (YES = true) — set when they tap YES/NO at apex.
    @State private var userCall: Bool? = nil

    /// Truth-vs-call resolution. The scene's escaping closure can't reliably
    /// read `@State` values captured at view init, so it stores the raw
    /// resolution here, and `.onChange(of: pendingResolution)` reads the
    /// live `userCall` to compute `wasCorrect` and transition into verdict.
    @State private var pendingResolution: Phase.Resolution? = nil

    /// Guards the one profile write for the call beat.
    @State private var outcomeWritten: Bool = false

    /// The shot fired on the CALL beat. Picked once per view instance —
    /// either the canonical (scores) or a verified perturbed miss — so the
    /// YES/NO call is a genuine read instead of always-YES.
    @State private var callShot: ProjectileAnswer? = nil

    /// Compute mode — user-chosen θ (degrees) and v (m/s). Initialized
    /// near plausible values on first entry; persist across attempts so a
    /// user tweaking up/down doesn't have to restart from zero.
    @State private var computeTheta: Double = 50.0
    @State private var computeVelocity: Double = 7.0

    /// Medium impact on RELEASE — the physical "ball leaving the hand" beat.
    @State private var releaseHapticCount: Int = 0

    /// Moves VoiceOver to the CALL IT prompt when the frozen dock swaps in —
    /// without it the phase change is silent and focus dies with the old dock.
    @AccessibilityFocusState private var callPromptFocused: Bool

    /// Max attempts in compute mode before returning to chapter.
    private let computeMaxAttempts = 5

    enum Phase: Sendable, Equatable {
        /// Shooter at the line, "CALL IT." prompt, tap to release.
        case stance
        /// Ball arcing toward apex; no UI on the play surface.
        case release
        /// Ball frozen at apex; CALL IT (YES / NO) overlay visible.
        case frozen
        /// Ball completing its arc to the outcome.
        case finish
        /// Outcome resolved; reveal the call's correctness.
        case verdict(Resolution, wasCorrect: Bool)
        /// User chose to try the math — slider dock visible, picking θ/v.
        case compute(attempt: Int)
        /// User's shot animating with their chosen values.
        case computeAction(attempt: Int)
        /// User's shot outcome — swish/miss + retry-or-done options.
        case computeVerdict(Resolution, attempt: Int)
        /// Post-compute formula walkthrough. `step` is 0-indexed into the
        /// derivation cards (5 total).
        case formulaWalkthrough(step: Int)
        /// Free bonus attempt — canonical values, user watches the swish
        /// play out after seeing the derivation.
        case bonusAttempt
        /// Terminal beat after the deep-dive (or when attempts run out):
        /// "Play again" restarts the scenario, "Done" exits.
        case replayPrompt

        enum Resolution: Sendable, Equatable {
            case success(flavor: String)
            case miss(category: String)
        }
    }

    init(scenario: ScenarioDefinition, chapter: Chapter? = nil, onClose: (() -> Void)? = nil) {
        self.scenario = scenario
        self.chapter = chapter
        self.onClose = onClose
        guard case .projectile2D(_, let params) = scenario.simulation else {
            fatalError("CallPlayView currently supports only PROJECTILE_2D scenarios")
        }
        self.projectileParams = params
        let initialSize = CGSize(width: 393, height: 340)
        _scene = State(initialValue: PlaySceneNode(projectileParams: params, size: initialSize))
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
            let useSideDock = ctx.isRegular && ctx.isWide
            let dockWidth = AdaptiveMetrics.sideDockWidth(for: geometry.size.width)
            let callTopReserve = metrics.topReserve - 40   // CallHUD is shorter

            ZStack(alignment: .top) {
                // Z0 — full-bleed court canvas.
                Color.arclabBlack.ignoresSafeArea()
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    // SKScene content never reaches the accessibility tree —
                    // narrate it: static geometry in the label, the live
                    // phase read in the value (the YES/NO call evidence).
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(SceneNarration.basketballLabel(params: projectileParams))
                    .accessibilityValue(sceneAccessibilityValue)
                    .accessibilityIgnoresInvertColors()

                // HUD (top) — quiet v2.1 chrome: close affordance only,
                // no variable strip (call beat must be intuitive, not data-leaked).
                VStack(spacing: 0) {
                    CallHUD(onClose: shouldShowClose ? onClose : nil)
                        .opacity(hudOpacity)
                    Spacer().allowsHitTesting(false)
                }
                .animation(.easeOut(duration: 0.2), value: phase)

                // Phase-dependent dock — bottom band (iPhone + iPad portrait)
                // or right-side column (iPad landscape). Hidden during the
                // full-screen flight phases so the arc owns the canvas.
                if phaseShowsDock {
                    if useSideDock {
                        sideDock(width: dockWidth, topReserve: callTopReserve)
                    } else {
                        VStack(spacing: 0) {
                            Spacer().allowsHitTesting(false)
                            bottomOverlay
                        }
                        .animation(.easeOut(duration: 0.2), value: phase)
                    }
                }

                // Reveal overlay — slides up over the verdict ~0.9s after it
                // lands. In landscape it rides within the right column.
                if case .verdict(let resolution, let wasCorrect) = phase {
                    let reveal = RevealOverlay(
                        wasCorrect: wasCorrect,
                        actualWentIn: actualWentIn(resolution),
                        phenomenon: revealPhenomenon,
                        explainer: revealExplainer,
                        onTryCompute: handleTryCompute,
                        onShowMath: handleShowMath
                    )
                    if useSideDock {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0).allowsHitTesting(false)
                            reveal
                                .frame(width: dockWidth)
                                .padding(.top, callTopReserve)
                        }
                        .transition(.opacity)
                    } else {
                        reveal.transition(.opacity)
                    }
                }
            }
            .onAppear { propagateLayout(ctx: ctx, metrics: metrics) }
            .onChange(of: phase) { _, _ in propagateLayout(ctx: ctx, metrics: metrics) }
            .onChange(of: geometry.size) { _, _ in propagateLayout(ctx: ctx, metrics: metrics) }
        }
        .statusBarHidden(true)
        // iOS-native escape: mirror the CLOSE chip's gating so swipe-down /
        // edge-swipe-right dismiss the same phases the chip allows.
        .swipeBackToDismiss(
            isEnabled: shouldShowClose && onClose != nil
        ) {
            onClose?()
        }
        .gameHaptic(.impact(weight: .medium), trigger: releaseHapticCount)
        .onAppear {
            scene.setReduceMotion(accessibility.reduceMotionActive)
            configureScene()
            startAutoplayIfRequested()
        }
        // Mid-session toggles (Settings or iOS) retune the running scene.
        .onChange(of: accessibility.reduceMotionActive) { _, on in
            scene.setReduceMotion(on)
        }
        .onChange(of: pendingResolution) { _, new in
            // Finalize the verdict here so live SwiftUI state (userCall,
            // current phase) is read fresh, not from a stale closure capture.
            guard let resolution = new else { return }
            if case .computeAction(let attempt) = phase {
                // Compute mode finished — user's own shot resolved.
                phase = .computeVerdict(resolution, attempt: attempt)
            } else if case .bonusAttempt = phase {
                // Canonical shot played out after the walkthrough. Dwell on
                // the swish for a beat, then offer a replay instead of
                // silently closing.
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeOut(duration: 0.25)) { phase = .replayPrompt }
                }
            } else {
                // Call beat finished — derive correctness vs truth.
                let truthIsSwish: Bool
                switch resolution {
                case .success: truthIsSwish = true
                case .miss:    truthIsSwish = false
                }
                let wasCorrect = (userCall == truthIsSwish)
                recordCallOutcome(correct: wasCorrect)
                phase = .verdict(resolution, wasCorrect: wasCorrect)
            }
            pendingResolution = nil
        }
        .onDisappear { audio.stopLoop(.dribbleLoop) }
    }

    /// Diagnostic — ARCLAB_AUTOPLAY=1 walks the 5-beat loop end-to-end so
    /// we can capture video without click injection. Uses fixed delays
    /// because the SwiftUI Task captures `self` at .onAppear and `@State`
    /// reads inside the closure return stale values, so we can't poll
    /// `phase` to coordinate.
    private func startAutoplayIfRequested() {
        guard ProcessInfo.processInfo.environment["ARCLAB_AUTOPLAY"] == "1" else { return }
        Task {
            try? await Task.sleep(for: .seconds(2))
            handleRelease()
            try? await Task.sleep(for: .seconds(3.5))
            handleCall(yes: true)

            // AUTOPLAY=2 — drive into compute mode for capture.
            if ProcessInfo.processInfo.environment["ARCLAB_AUTOPLAY_COMPUTE"] == "1" {
                try? await Task.sleep(for: .seconds(3.0))
                handleTryCompute()

                // AUTOPLAY=3 — fire compute shoot + drive into walkthrough.
                if ProcessInfo.processInfo.environment["ARCLAB_AUTOPLAY_WALKTHROUGH"] == "1" {
                    try? await Task.sleep(for: .seconds(1.0))
                    handleComputeShoot()
                    try? await Task.sleep(for: .seconds(4.0))
                    handleShowMath()
                }
            }
        }
    }

    /// True for phases that show a dock (stance/frozen/compute/verdict/…).
    /// The full-screen flight phases hide it so the arc owns the canvas.
    private var phaseShowsDock: Bool {
        switch phase {
        case .release, .finish, .computeAction, .bonusAttempt: return false
        default: return true
        }
    }

    private func propagateLayout(ctx: LayoutContext, metrics: PlayLayoutMetrics) {
        // Stance + frozen reserve roughly equal the v1 IDLE bottom; verdict
        // matches v1 OUTCOME; release/finish are full-screen.
        let desiredBottom: CGFloat
        switch phase {
        case .stance, .frozen, .compute:                          desiredBottom = metrics.bottomReserveIdle
        case .release, .finish, .computeAction, .bonusAttempt:    desiredBottom = metrics.bottomReserveAction
        case .verdict, .computeVerdict, .formulaWalkthrough,
             .replayPrompt:                                       desiredBottom = metrics.bottomReserveOutcome
        }
        // v2.1 uses CallHUD (60pt) instead of v1's PlayHUDView (140pt) so
        // the top reserve is smaller — more vertical room for the court arc.
        let topReserve = metrics.topReserve - 40  // 100 - 40 = 60pt
        let am = AdaptiveMetrics.compute(ctx: ctx, topReserve: topReserve, desiredBottomDockHeight: desiredBottom)
        // Flight phases hide the dock → full-bleed canvas (no side/bottom band).
        let right: CGFloat = phaseShowsDock ? am.rightReserve : 0
        let bottom: CGFloat = phaseShowsDock ? am.bottomReserve : metrics.bottomReserveAction
        scene.applyUIReserve(
            top: am.topReserve,
            bottom: bottom,
            safeTop: am.topReserve,
            safeBottom: bottom,
            right: right
        )
    }

    /// iPad landscape: phase dock as a trailing column below the HUD. The
    /// court frames into the band left of it (rightReserve).
    private func sideDock(width: CGFloat, topReserve: CGFloat) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0).allowsHitTesting(false)   // court shows through (left)
            VStack(spacing: 0) {
                Color.clear.frame(height: topReserve).allowsHitTesting(false)
                VStack(spacing: 0) {
                    Spacer(minLength: 0).allowsHitTesting(false)
                    bottomOverlay
                    Spacer(minLength: 0).allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.arclabBlack)
            }
            .frame(width: width)
        }
        .animation(.easeOut(duration: 0.2), value: phase)
    }

    // MARK: - Phase-dependent UI

    @ViewBuilder
    private var bottomOverlay: some View {
        switch phase {
        case .stance:
            stanceDock
        case .release, .finish, .computeAction, .bonusAttempt:
            EmptyView()
        case .frozen:
            callDock
        case .verdict(let resolution, let wasCorrect):
            verdictOverlay(resolution: resolution, wasCorrect: wasCorrect)
                .frame(height: 480)
                .background(Color.arclabBlack)
                .transition(.opacity)
        case .compute(let attempt):
            computeDock(attempt: attempt)
                .transition(.opacity)
        case .computeVerdict(let resolution, let attempt):
            computeVerdictView(resolution: resolution, attempt: attempt)
                .frame(height: 360)
                .background(Color.arclabBlack)
                .transition(.opacity)
        case .formulaWalkthrough(let step):
            walkthroughDock(step: step)
                .frame(height: 400)
                .background(Color.arclabBlack)
                .transition(.opacity)
        case .replayPrompt:
            replayDock
                .frame(height: 320)
                .background(Color.arclabBlack)
                .transition(.opacity)
        }
    }

    /// Terminal dock after the deep-dive — replay the scenario or exit.
    private var replayDock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            Text("THAT'S THE SHOT.")
                .font(.anton(size: 52))
                .foregroundColor(.arclabWhite)
                .padding(.horizontal, Spacing.md)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer().frame(height: Spacing.sm)

            Text("Run it again, or head back.")
                .font(.barlowCondensed(size: 16, italic: true))
                .foregroundColor(.arclabMidGrey)
                .padding(.horizontal, Spacing.md)

            Spacer()

            VStack(spacing: Spacing.xs) {
                PrimaryButton(label: "Play again", action: handleReplay)
                SecondaryButton(label: "Done", action: handleClose)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The live scene description VoiceOver reads off the court canvas.
    private var sceneAccessibilityValue: String {
        switch phase {
        case .stance:
            return "Shooter at the line, dribbling. No shot in the air."
        case .release, .finish:
            return "Ball in flight."
        case .frozen:
            return frozenSceneRead
        case .verdict:
            return "Shot resolved."
        case .compute, .computeAction:
            return "Your shot: \(Int(computeTheta.rounded())) degrees at "
                + String(format: "%.1f", computeVelocity) + " meters per second."
        case .computeVerdict:
            return "Your shot resolved."
        case .formulaWalkthrough, .bonusAttempt, .replayPrompt:
            return "Reviewing the physics."
        }
    }

    /// The apex read for the frozen beat — same evidence a sighted player
    /// judges, bucketed by SceneNarration so the answer never leaks.
    private var frozenSceneRead: String {
        guard let shot = callShot else {
            return "The ball is frozen at the top of its arc."
        }
        return SceneNarration.basketballFrozenRead(params: projectileParams, shot: shot)
    }

    private var stanceDock: some View {
        // A real Button (not a bare tap gesture) so VoiceOver, Switch Control
        // and Voice Control all get an actionable, labeled target — this is
        // the first beat of every scenario.
        Button(action: handleRelease) {
            VStack(spacing: Spacing.sm) {
                Text("CALL IT.")
                    .font(.anton(size: 32))
                    .foregroundColor(.arclabWhite)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)
                    .fixedSize(horizontal: false, vertical: true)

                Text("TAP TO RELEASE")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .padding(.bottom, Spacing.lg)
            .background(Color.arclabBlack)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Release the shot. The ball flies and freezes mid-flight; then you call whether it goes in.")
        .transition(.opacity)
    }

    private var callDock: some View {
        VStack(spacing: Spacing.sm) {
            Text("CALL IT")
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
                // The dock swaps in silently mid-flight — move VoiceOver here
                // so the focus speech delivers the prompt AND the apex read,
                // two swipes from YES/NO.
                .accessibilityLabel("Call it. \(frozenSceneRead) Will it go in? Yes and No buttons below.")
                .accessibilityFocused($callPromptFocused)

            HStack(spacing: Spacing.md) {
                PrimaryButton(label: "Yes", action: { handleCall(yes: true) })
                SecondaryButton(label: "No", action: { handleCall(yes: false) })
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .padding(.bottom, Spacing.lg)
        .background(Color.arclabBlack)
        .transition(.opacity)
        .onAppear { callPromptFocused = true }
    }

    // MARK: - Compute mode (easy)

    /// Compute dock — slider entry for θ and v, then SHOOT. The post-compute
    /// formula-walkthrough beat lives separately; we don't embed two modes
    /// inside this dock.
    private func computeDock(attempt: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("YOUR SHOT")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                Text("ATTEMPT \(attempt) OF \(computeMaxAttempts)")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }

            ParameterSliderRow(
                label: "ANGLE", spokenName: "Launch angle",
                unit: "°", spokenUnit: "degrees",
                value: $computeTheta, range: 15...80, format: "%.0f", step: 1
            )
            ParameterSliderRow(
                label: "SPEED", spokenName: "Launch speed",
                unit: "m/s", spokenUnit: "meters per second",
                value: $computeVelocity, range: 3...15, format: "%.1f", step: 0.5
            )

            PrimaryButton(label: "Shoot", action: handleComputeShoot)
                .padding(.top, Spacing.xs)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.arclabBlack)
    }

    /// Compute outcome view — clean call-first-styled verdict for the
    /// user's *own* shot, with retry/next CTAs.
    private func computeVerdictView(resolution: Phase.Resolution, attempt: Int) -> some View {
        let madeIt: Bool
        switch resolution {
        case .success: madeIt = true
        case .miss:    madeIt = false
        }
        let canRetry = !madeIt && attempt < computeMaxAttempts

        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            Text(madeIt ? "GOT IT." : "MISSED.")
                .font(.anton(size: 64))
                .foregroundColor(.arclabWhite)
                .padding(.horizontal, Spacing.md)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Spacer().frame(height: Spacing.sm)

            Text(madeIt
                 ? "Your numbers landed the shot. There's a formula for it too."
                 : "Close call by feel. There's a formula that nails it every time.")
                .font(.barlowCondensed(size: 16, italic: true))
                .foregroundColor(.arclabMidGrey)
                .padding(.horizontal, Spacing.md)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Show the math unlocks once they've made it or tried 3+ times;
            // retry (orange) is offered while attempts remain.
            VStack(spacing: Spacing.xs) {
                if madeIt || attempt >= 3 {
                    PrimaryButton(label: "Show the math", action: handleShowMath)
                }
                HStack(spacing: Spacing.md) {
                    if canRetry {
                        AccentOutlineButton(label: "Retry", action: handleComputeRetry)
                    } else {
                        // Out of attempts (or made it) — offer a clean restart
                        // instead of leaving "Done" as the only way out.
                        SecondaryButton(label: "Play again", action: handleReplay)
                    }
                    SecondaryButton(label: "Done", action: handleClose)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((madeIt ? Color.arclabBlack : Color.arclabMissTint).ignoresSafeArea())
        .announceOnAppear {
            madeIt
                ? "Got it. Your numbers landed the shot."
                : "Missed, attempt \(attempt) of \(computeMaxAttempts). Buttons below to retry or see the math."
        }
    }

    // MARK: - Formula walkthrough

    /// Single-card derivation walkthrough, advanced by tapping NEXT. Cards
    /// are generated from the scenario's authored solution + ghost arc
    /// (CallWalkthrough), so the math always matches the simulated shot.
    /// After the last step, transitions to the `.bonusAttempt` phase where
    /// the canonical shot plays out.
    private var walkthroughCards: [CallWalkthrough.Card] {
        CallWalkthrough(scenario: scenario).cards
    }

    private func walkthroughDock(step: Int) -> some View {
        let cards = walkthroughCards
        let card = cards[min(step, cards.count - 1)]
        let isLast = step >= cards.count - 1

        return VStack(alignment: .leading, spacing: 0) {
            // Step indicator
            HStack {
                Text("STEP \(step + 1) OF \(cards.count)")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                Text("THE PHYSICS")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

            Spacer().frame(height: Spacing.md)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(card.headline)
                    .font(.anton(size: 32))
                    .foregroundColor(.arclabWhite)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                if !card.math.isEmpty {
                    Text(card.math)
                        .font(.sfMono(size: 15))
                        .foregroundColor(.arclabWhite)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !card.body.isEmpty {
                    Text(card.body)
                        .font(.barlowCondensed(size: 15))
                        .foregroundColor(.arclabMidGrey)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            PrimaryButton(label: isLast ? "Watch it land" : "Next", action: handleNextStep)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func verdictOverlay(resolution: Phase.Resolution, wasCorrect: Bool) -> some View {
        switch resolution {
        case .success(let flavor):
            CallVerdictView(wasCorrect: wasCorrect, ballWentIn: true)
                .onAppear { playOutcomeSound(success: flavor) }
        case .miss(let category):
            CallVerdictView(wasCorrect: wasCorrect, ballWentIn: false)
                .onAppear { playOutcomeSound(miss: category) }
        }
    }

    // MARK: - Scene wiring

    private func configureScene() {
        if callShot == nil {
            var rng = SystemRandomNumberGenerator()
            callShot = CallShotPicker.pick(for: scenario, using: &rng).answer
        }
        scene.audio = audio
        scene.onReachedApex = { [weak scene] in
            Task { @MainActor in
                _ = scene  // keep reference alive
                self.phase = .frozen
            }
        }
        scene.onOutcomeResolved = { outcome, _ in
            Task { @MainActor in
                scene.freezeForOutcome()
                let resolution: Phase.Resolution
                switch outcome {
                case .success(let flavor):
                    resolution = .success(flavor: flavor)
                case .miss(let category):
                    resolution = .miss(category: category)
                case .inFlight:
                    return
                }
                // Hand off to SwiftUI; `.onChange(of: pendingResolution)` in
                // the body reads the live `userCall` and finalizes the verdict.
                // Reading `userCall` directly here gets a stale snapshot
                // captured at .onAppear, since SwiftUI struct closures freeze
                // their `self` reference.
                pendingResolution = resolution
            }
        }
        audio.startLoop(.dribbleLoop)
    }

    // MARK: - Actions

    private func handleRelease() {
        phase = .release
        releaseHapticCount += 1   // medium impact — the player launched the ball
        scene.startSimulation(
            answer: callShot ?? ProjectileAnswer(thetaDegrees: canonicalTheta, velocity: canonicalVelocity),
            pauseAtApex: true
        )
    }

    private func handleCall(yes: Bool) {
        userCall = yes
        phase = .finish
        scene.resumeAfterApex()
    }

    /// Restart the playable compute challenge with fresh attempts. Surfaced
    /// after the deep-dive and on the attempts-spent verdict so the user is
    /// never dead-ended into closing.
    ///
    /// The user already made their YES/NO call this session, so a replay does
    /// NOT re-ask the call (that would be the same prediction twice) — it
    /// drops straight back into the slider challenge. A genuine fresh replay
    /// of the level (re-entering from the picker) is a new view instance and
    /// still opens on the call beat.
    private func handleReplay() {
        pendingResolution = nil
        // Fresh slider values for a clean run at the challenge.
        computeTheta = 50.0
        computeVelocity = 7.0
        scene.resetForNewShot()
        withAnimation(.easeOut(duration: 0.25)) { phase = .compute(attempt: 1) }
    }

    /// User tapped TRY IT on the reveal — open the compute slider dock.
    /// First attempt — reset the scene so the ball is back at the shooter's
    /// hand. Slider values are kept (the user might want to fine-tune from
    /// their last try, or start fresh on first entry).
    private func handleTryCompute() {
        scene.resetForNewShot()
        phase = .compute(attempt: 1)
    }

    /// User tapped SHOOT inside the compute dock — fire their chosen θ/v
    /// through the scene with no apex pause (the user picked the values;
    /// they want to see the result, not freeze midflight).
    private func handleComputeShoot() {
        let currentAttempt: Int
        if case .compute(let attempt) = phase { currentAttempt = attempt }
        else { currentAttempt = 1 }

        phase = .computeAction(attempt: currentAttempt)
        scene.startSimulation(
            answer: ProjectileAnswer(thetaDegrees: computeTheta, velocity: computeVelocity),
            pauseAtApex: false
        )
    }

    /// User tapped RETRY on a missed compute attempt — bump attempt counter
    /// (or end if exhausted), reset scene, back to the slider dock.
    private func handleComputeRetry() {
        let nextAttempt: Int
        if case .computeVerdict(_, let attempt) = phase { nextAttempt = attempt + 1 }
        else { nextAttempt = 1 }

        guard nextAttempt <= computeMaxAttempts else {
            handleClose()
            return
        }
        scene.resetForNewShot()
        phase = .compute(attempt: nextAttempt)
    }

    private func handleClose() {
        onClose?()
    }

    /// User tapped SHOW THE MATH on the compute verdict — open the
    /// step-by-step formula walkthrough at card 0.
    private func handleShowMath() {
        phase = .formulaWalkthrough(step: 0)
    }

    /// User tapped NEXT inside the walkthrough. Advances the step or, on the
    /// final card, transitions to the canonical-shot bonus attempt.
    private func handleNextStep() {
        guard case .formulaWalkthrough(let step) = phase else { return }
        let next = step + 1
        if next >= walkthroughCards.count {
            // Fire the canonical shot; bonusAttempt phase suppresses the
            // dock so user watches the swish play out clean.
            scene.resetForNewShot()
            phase = .bonusAttempt
            scene.startSimulation(
                answer: ProjectileAnswer(thetaDegrees: canonicalTheta, velocity: canonicalVelocity),
                pauseAtApex: false
            )
        } else {
            phase = .formulaWalkthrough(step: next)
        }
    }

    // MARK: - Truth lookup

    private var canonicalTheta: Double {
        scenario.outcome.ghostArc?.answer["theta"] ?? 52
    }

    private var canonicalVelocity: Double {
        scenario.outcome.ghostArc?.answer["v"] ?? 7.5
    }

    // MARK: - Reveal beat content

    private func actualWentIn(_ resolution: Phase.Resolution) -> Bool {
        if case .success = resolution { return true }
        return false
    }

    /// Physics phenomenon shown on the reveal card. Falls back to a generic
    /// "Projectile motion." headline if the scenario isn't yet in a chapter
    /// context (diagnostic launches, legacy navigation, etc.).
    private var revealPhenomenon: String {
        chapter?.lesson.title ?? "Projectile motion."
    }

    /// 2–3 sentence reveal copy. Pulls the chapter lesson's one-liner when
    /// available; falls back to a generic projectile-motion summary.
    private var revealExplainer: String {
        if let oneLiner = chapter?.lesson.oneLiner, !oneLiner.isEmpty {
            return oneLiner
        }
        return "Once the ball leaves your hand, only gravity acts on it. The arc is fully determined by release angle and speed — the rest is geometry."
    }

    // MARK: - Audio

    private func playOutcomeSound(success flavor: String) {
        switch flavor {
        case "SWISH": audio.play(.swish); scene.playNetFlex()
        case "GLASS": audio.play(.glass)
        case "RIM_DROP": audio.play(.rimDrop)
        default: audio.play(.swish)
        }
    }

    private func playOutcomeSound(miss category: String) {
        if category == "AIRBALL" {
            audio.play(.airball)
        } else {
            audio.play(.missTone)
        }
    }

    // MARK: - HUD visibility

    private var shouldShowClose: Bool {
        switch phase {
        // CLOSE hidden only during the *call-truth* mid-flight beats —
        // letting the user bail mid-prediction would break the mechanic.
        // bonusAttempt keeps CLOSE active as a safety net (no other escape
        // path exists if the simulation ever fails to resolve).
        case .release, .finish, .frozen, .computeAction: return false
        case .stance, .verdict, .compute, .computeVerdict, .formulaWalkthrough, .bonusAttempt, .replayPrompt: return true
        }
    }

    private var hudOpacity: Double {
        switch phase {
        case .release, .finish, .frozen, .computeAction: return 0.5
        case .stance, .verdict, .compute, .computeVerdict, .formulaWalkthrough, .bonusAttempt, .replayPrompt: return 1.0
        }
    }

    // MARK: - Scoring

    /// Match archery/soccer: the scenario completes on the call beat, and XP
    /// is based on whether the prediction was correct. The optional slider
    /// deep-dive after the verdict is practice, not a second progression loop.
    private func recordCallOutcome(correct: Bool) {
        guard !outcomeWritten else { return }
        outcomeWritten = true

        let id = scenario.scenarioId
        let base = correct ? 20 : 5
        let now = Date()
        profile.mutate { p in
            p.recordPlayToday(now: now)
            let already = p.completedScenarios[id]?.firstCompletedAt != nil
            var record = p.completedScenarios[id] ?? ScenarioRecord.newRecord(now: now)
            if record.firstCompletedAt == nil { record.firstCompletedAt = now }
            record.lastPlayedAt = now
            record.bestScore = max(record.bestScore, base)
            p.completedScenarios[id] = record
            p.totalXP += already ? max(1, base / 10) : base
            p.recomputeRank()
        }
    }
}
