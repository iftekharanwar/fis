import SwiftUI
import SpriteKit

/// v2.2 archery call-first play surface — full loop.
///
///   STANCE → RELEASE → VERDICT (+ reveal)
///     ↓                          ↓
///     │                       See why →
///     │                          ↓
///     │                COMPUTE (slider + live ghost)
///     │                          ↓
///     │                       SHOOT
///     │                          ↓
///     │                COMPUTE ACTION
///     │                          ↓
///     │                COMPUTE VERDICT (retry up to 3)
///     │                          ↓
///     │                    Show the math
///     │                          ↓
///     │           FORMULA WALKTHROUGH (5 cards)
///     │                          ↓
///     │                    Watch it land
///     │                          ↓
///     │                  BONUS ATTEMPT
///     │                          ↓
///     └──────────────────────► CLOSE
///
/// Mechanic mirrors basketball's CallPlayView but archery has a single
/// variable (pin holdover in cm) instead of two (θ + v). Compute dock
/// shows a live dashed-line ghost trajectory that updates as the user
/// drags the slider — they SEE where the arrow will land before firing.
struct ArcheryCallPlayView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(AudioService.self) private var audio

    let scenario: ArcheryScenario
    let chapter: Chapter?
    var onClose: (() -> Void)? = nil

    @State private var scene: ArcherySceneNode
    @State private var phase: Phase = .stance
    @State private var userCall: Bool? = nil
    @State private var pendingOutcome: ArcheryOutcome? = nil

    /// Wobble envelope (radians) at the moment the arrow crossed the
    /// target plane. Drives clean-vs-wobbled judgement for paradox
    /// scenarios. ~0 for Ch1 / non-paradox shots.
    @State private var pendingWobbleAtImpact: Double = 0

    /// Above this envelope, a flight reads as "wobbled." Threshold is
    /// roughly 3° — below that the eye doesn't really pick up the
    /// remaining oscillation.
    private let cleanFlightThresholdRad: Double = 0.052

    /// User-chosen holdover in cm above the bullseye. Default seeds at
    /// 30 cm so the user has somewhere to start (not zero — that's
    /// obviously short; not over-correction either).
    @State private var computeHoldover: Double = 30.0

    /// User-chosen launch velocity (m/s). In real archery this is fixed
    /// by the bow's draw weight, but for the compute-mode learning loop
    /// we let the user crank it so they SEE that v matters as much as θ.
    @State private var computeVelocity: Double = 80.0

    /// Paradox compute: user-chosen arrow spine. Starts at the scenario's
    /// authored value (the "wrong" answer) so the user has to tune toward
    /// the draw weight.
    @State private var computeSpine: Double = 85.0

    private let computeMaxAttempts = 3
    private let velocityRange: ClosedRange<Double> = 50...110
    private let spineRange: ClosedRange<Double> = 30...100

    enum Phase: Equatable {
        case stance
        case release
        case verdict(ArcheryOutcome, wasCorrect: Bool)
        case compute(attempt: Int)
        case computeAction(attempt: Int)
        case computeVerdict(ArcheryOutcome, attempt: Int)
        case formulaWalkthrough(step: Int)
        case bonusAttempt
    }

    init(scenario: ArcheryScenario, chapter: Chapter? = nil, onClose: (() -> Void)? = nil) {
        self.scenario = scenario
        self.chapter = chapter
        self.onClose = onClose
        let initialSize = CGSize(width: 393, height: 340)
        _scene = State(initialValue: ArcherySceneNode(scenario: scenario, size: initialSize))

        // Diagnostic — ARCLAB_ARCHERY_PHASE=compute jumps straight to the
        // slider dock at launch so screenshots don't have to navigate the
        // call beat first.
        if ProcessInfo.processInfo.environment["ARCLAB_ARCHERY_PHASE"] == "compute" {
            _phase = State(initialValue: .compute(attempt: 1))
        }
        // Diagnostic — ARCLAB_ARCHERY_COMPUTE_SPINE=<n> pre-sets the SPINE
        // slider so screenshot scripts can shoot at a specific value.
        if let s = ProcessInfo.processInfo.environment["ARCLAB_ARCHERY_COMPUTE_SPINE"],
           let v = Double(s) {
            _computeSpine = State(initialValue: v)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.arclabBlack.ignoresSafeArea()

                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    CallHUD(onClose: shouldShowClose ? onClose : nil)
                        .opacity(hudOpacity)
                    if showsInfoStrip {
                        infoStrip
                    }
                    Spacer().allowsHitTesting(false)
                }
                .animation(.easeOut(duration: 0.2), value: phase)

                VStack(spacing: 0) {
                    Spacer().allowsHitTesting(false)
                    bottomOverlay
                }
                .animation(.easeOut(duration: 0.2), value: phase)

                if case .verdict(let outcome, let wasCorrect) = phase {
                    let cleanFlight = pendingWobbleAtImpact < cleanFlightThresholdRad
                    RevealOverlay(
                        wasCorrect: wasCorrect,
                        actualWentIn: scenario.usesParadoxMechanic
                            ? cleanFlight
                            : outcome.didHit,
                        phenomenon: revealPhenomenon,
                        explainer: revealExplainer,
                        onContinue: handleClose,
                        onTryCompute: handleTryCompute,
                        outcomeLabelOverride: scenario.usesParadoxMechanic
                            ? (cleanFlight ? "IT FLEW CLEAN" : "IT WOBBLED")
                            : nil
                    )
                    .transition(.opacity)
                }
            }
            .onAppear { propagateReserve(for: geometry) }
            .onChange(of: phase) { _, _ in propagateReserve(for: geometry) }
            .onChange(of: geometry.size) { _, _ in propagateReserve(for: geometry) }
        }
        .statusBarHidden(true)
        .onAppear { configureScene() }
        .onChange(of: pendingOutcome) { _, new in
            guard let outcome = new else { return }
            handleResolvedOutcome(outcome)
            pendingOutcome = nil
        }
        .onChange(of: computeHoldover) { _, _ in updateGhostIfComputing() }
        .onChange(of: computeVelocity) { _, _ in updateGhostIfComputing() }
        .onAppear { startAutoshootIfRequested() }
    }

    // MARK: - Outcome dispatch

    private func handleResolvedOutcome(_ outcome: ArcheryOutcome) {
        switch phase {
        case .computeAction(let attempt):
            phase = .computeVerdict(outcome, attempt: attempt)
        case .bonusAttempt:
            // Dwell on the canonical swish for a beat, then dismiss.
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                handleClose()
            }
        default:
            // Call beat finished — derive correctness against the right
            // truth for this scenario type.
            let truthValue = scenarioTruth(outcome: outcome)
            let wasCorrect = (userCall == truthValue)
            profile.mutate { $0.recordPlayToday() }
            phase = .verdict(outcome, wasCorrect: wasCorrect)
        }
    }

    /// For paradox scenarios, the YES/NO question is "will it fly clean?"
    /// so truth = (wobble at impact < threshold). For pin-gap scenarios
    /// the question is "will it hit?" so truth = geometric bullseye.
    private func scenarioTruth(outcome: ArcheryOutcome) -> Bool {
        if scenario.usesParadoxMechanic {
            return pendingWobbleAtImpact < cleanFlightThresholdRad
        }
        return outcome.didHit
    }

    // MARK: - Top info strip

    private var showsInfoStrip: Bool {
        switch phase {
        case .stance, .compute:                 return true
        default:                                return false
        }
    }

    private var infoStrip: some View {
        HStack(spacing: Spacing.lg) {
            stat(label: "RANGE", value: "\(Int(scenario.targetDistance)) m")
            if scenario.usesParadoxMechanic {
                stat(label: "DRAW", value: "\(Int(scenario.bowDraw)) lb")
                stat(label: "SPINE", value: "\(Int(scenario.arrowSpine))")
            } else {
                stat(label: "PIN", value: "\(Int(scenario.pinSightedFor)) m")
                stat(label: "BOW", value: "\(Int(scenario.arrowVelocity)) m/s")
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
            Text(value)
                .font(.sfMono(size: 14, weight: .medium))
                .foregroundColor(.arclabWhite)
        }
    }

    // MARK: - Bottom overlay

    @ViewBuilder
    private var bottomOverlay: some View {
        switch phase {
        case .stance:
            stanceDock
        case .release, .computeAction, .bonusAttempt:
            EmptyView()
        case .verdict(let outcome, let wasCorrect):
            // For paradox scenarios, the verdict judges "clean vs wobbled,"
            // not "hit vs miss." Both axes are binary so the existing 4-
            // way verb table maps cleanly via the mode parameter.
            ArcheryCallVerdictView(
                wasCorrect: wasCorrect,
                didHit: scenario.usesParadoxMechanic
                    ? (pendingWobbleAtImpact < cleanFlightThresholdRad)
                    : outcome.didHit,
                mode: scenario.usesParadoxMechanic ? .cleanFlight : .hit
            )
                .frame(height: 480)
                .background(Color.arclabBlack)
                .transition(.opacity)
        case .compute(let attempt):
            computeDock(attempt: attempt)
                .transition(.opacity)
        case .computeVerdict(let outcome, let attempt):
            computeVerdictView(outcome: outcome, attempt: attempt)
                .frame(height: 360)
                .transition(.opacity)
        case .formulaWalkthrough(let step):
            walkthroughDock(step: step)
                .frame(height: 400)
                .background(Color.arclabBlack)
                .transition(.opacity)
        }
    }

    private var stanceDock: some View {
        VStack(spacing: Spacing.sm) {
            Text(scenario.stancePrompt)
                .font(.anton(size: 28))
                .foregroundColor(.arclabWhite)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

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
    }

    // MARK: - Compute dock

    @ViewBuilder
    private func computeDock(attempt: Int) -> some View {
        if scenario.usesParadoxMechanic {
            paradoxComputeDock(attempt: attempt)
        } else {
            pinGapComputeDock(attempt: attempt)
        }
    }

    private func pinGapComputeDock(attempt: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("HOLD YOUR PIN")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                Text("ATTEMPT \(attempt) OF \(computeMaxAttempts)")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }

            sliderRow(
                label: "HOLDOVER",
                unit: "cm",
                value: $computeHoldover,
                range: 0...100,
                format: "%.0f"
            )

            sliderRow(
                label: "POWER",
                unit: "m/s",
                value: $computeVelocity,
                range: velocityRange,
                format: "%.0f"
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

    private func paradoxComputeDock(attempt: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("MATCH THE SPINE")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                Text("ATTEMPT \(attempt) OF \(computeMaxAttempts)")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }

            // Fixed reference so the user knows what they're matching to.
            HStack(alignment: .lastTextBaseline) {
                Text("DRAW")
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                Text("\(Int(scenario.bowDraw)) lb")
                    .font(.sfMono(size: 14, weight: .medium))
                    .foregroundColor(.arclabMidGrey)
            }

            sliderRow(
                label: "SPINE",
                unit: "",
                value: $computeSpine,
                range: spineRange,
                format: "%.0f"
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

    private func sliderRow(
        label: String,
        unit: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(.sfMono(size: 10))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: format, value.wrappedValue))
                        .font(.sfMono(size: 18, weight: .medium))
                        .foregroundColor(.arclabWhite)
                    Text(unit)
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                }
            }
            Slider(value: value, in: range)
                .tint(.arclabWhite)
        }
    }

    // MARK: - Compute verdict view

    private func computeVerdictView(outcome: ArcheryOutcome, attempt: Int) -> some View {
        // Paradox: success = clean flight (wobble ≤ threshold). The arrow
        // always hits the bullseye geometrically since the pin is calibrated;
        // only spine matters for the verdict.
        // Pin-gap: success = geometric bullseye hit.
        let success: Bool
        if scenario.usesParadoxMechanic {
            success = pendingWobbleAtImpact < cleanFlightThresholdRad
        } else {
            success = outcome.didHit
        }
        let canRetry = !success && attempt < computeMaxAttempts
        let verb = computeVerdictVerb(success: success)

        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            Text(verb)
                .font(.anton(size: 64))
                .foregroundColor(.arclabWhite)
                .padding(.horizontal, Spacing.md)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer().frame(height: Spacing.sm)

            Text(computeVerdictSubhead(outcome: outcome, success: success))
                .font(.barlowCondensed(size: 16, italic: true))
                .foregroundColor(.arclabMidGrey)
                .padding(.horizontal, Spacing.md)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: Spacing.xs) {
                PrimaryButton(label: "Show the math", action: handleShowMath)
                HStack(spacing: Spacing.md) {
                    if canRetry {
                        SecondaryButton(label: "Retry", action: handleComputeRetry)
                    }
                    SecondaryButton(label: "Done", action: handleClose)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((success ? Color.arclabBlack : Color.arclabMissTint).ignoresSafeArea())
    }

    private func computeVerdictVerb(success: Bool) -> String {
        if scenario.usesParadoxMechanic {
            return success ? "CLEAN." : "WOBBLED."
        }
        return success ? "BULLSEYE." : "MISSED."
    }

    private func computeVerdictSubhead(outcome: ArcheryOutcome, success: Bool) -> String {
        if scenario.usesParadoxMechanic {
            let mismatch = Int(abs(computeSpine - scenario.bowDraw))
            if success {
                if mismatch == 0 {
                    return "Spine matched dead-on. The shaft flexed past the riser and snapped back straight."
                }
                return "Close enough — \(mismatch) off, but the wobble damped before impact."
            } else {
                let tooStiff = computeSpine > scenario.bowDraw
                let arrowDir = tooStiff ? "softer" : "stiffer"
                let sliderDir = tooStiff ? "drop" : "raise"
                return "Off by \(mismatch). The shaft kept oscillating at impact. Try a \(arrowDir) arrow — \(sliderDir) SPINE toward DRAW \(Int(scenario.bowDraw))."
            }
        }
        switch outcome {
        case .hitBullseye:
            return "Your numbers landed the shot. There's a formula behind it too."
        case .missLow(let by):
            let cm = Int((by * 100).rounded())
            return "About \(cm) cm low. Push the pin higher."
        case .missHigh(let by):
            let cm = Int((by * 100).rounded())
            return "About \(cm) cm high. Bring the pin down."
        }
    }

    // MARK: - Formula walkthrough

    private static let walkthroughStepCount = 5

    private func walkthroughDock(step: Int) -> some View {
        let card = walkthroughCard(step: step)
        let isLast = step >= Self.walkthroughStepCount - 1

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("STEP \(step + 1) OF \(Self.walkthroughStepCount)")
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

    private func walkthroughCard(step: Int) -> WalkthroughCard {
        if scenario.usesParadoxMechanic {
            return paradoxWalkthroughCard(step: step)
        }
        return pinGapWalkthroughCard(step: step)
    }

    private func pinGapWalkthroughCard(step: Int) -> WalkthroughCard {
        switch step {
        case 0:
            return WalkthroughCard(
                headline: "There's a formula for it.",
                math: "y(t) = h + v · sin(θ) · t − ½ · g · t²",
                body: "Same as the free throw. Gravity pulls down. Your bow angle θ pushes up. Speed v carries it forward. The path is fully set the instant you release."
            )
        case 1:
            let d = Int(scenario.targetDistance)
            let v = Int(scenario.arrowVelocity)
            return WalkthroughCard(
                headline: "Plug in what you know.",
                math: "v = \(v) m/s   g = 9.8 m/s²   d = \(d) m",
                body: "Your bow's velocity is fixed by the draw. Gravity is constant. The bullseye is \(d) m down the range. Only one variable changes between shots — the bow angle θ."
            )
        case 2:
            let pinD = Int(scenario.pinSightedFor)
            return WalkthroughCard(
                headline: "Find the pin's angle.",
                math: "sin(2θ_pin) = g · d_pin / v²\nθ_pin ≈ 0.9°",
                body: "Your pin holds for \(pinD) m. That means the bow is tilted up just under a degree — invisible to the eye, but enough to hit a \(pinD)-metre bullseye."
            )
        case 3:
            let lift = String(format: "%.2f", liftAtTargetMeters)
            let fall = String(format: "%.2f", fallAtTargetMeters)
            let miss = String(format: "%.2f", missMeters)
            return WalkthroughCard(
                headline: "Now run the arrow.",
                math: "t = d / v ≈ 0.50 s\nlift = v · sin(θ_pin) · t ≈ \(lift) m\nfall = ½ · g · t² ≈ \(fall) m",
                body: "At 40 m, the arrow is in the air half a second. The pin's tilt lifts \(lift) m. Gravity takes \(fall). Net miss: \(miss) m below the bullseye."
            )
        case 4:
            let holdoverM = String(format: "%.2f", missMeters)
            return WalkthroughCard(
                headline: "Close the pin gap.",
                math: "holdover ≈ \(holdoverM) m",
                body: "Hold the pin about a forearm above the bullseye. Same physics. Same arrow. Now the gap is closed."
            )
        default:
            return WalkthroughCard(headline: "", math: "", body: "")
        }
    }

    private func paradoxWalkthroughCard(step: Int) -> WalkthroughCard {
        let draw = Int(scenario.bowDraw)
        let spine = Int(scenario.arrowSpine)
        let mismatch = Int(abs(scenario.spineMismatch))
        let tooStiff = scenario.spineMismatch > 0

        switch step {
        case 0:
            return WalkthroughCard(
                headline: "Arrows aren't sticks. They're springs.",
                math: "",
                body: "When the bowstring releases, it shoves the back of the arrow forward. But the shaft is resting against the side of the bow — the riser is in the way. The arrow doesn't go AROUND the bow. It flexes THROUGH it."
            )
        case 1:
            return WalkthroughCard(
                headline: "Spine = the arrow's stiffness.",
                math: "draw = \(draw) lb   spine = your arrow's flex resistance",
                body: "A 60-lb bow pushes hard. The arrow has to bend just enough to slip past the riser. If it's too stiff, it can't flex. If it's too soft, it bends too much and oscillates the whole way down."
            )
        case 2:
            let direction = tooStiff ? "too STIFF" : "too SOFT"
            return WalkthroughCard(
                headline: "Mismatch = wobble.",
                math: "draw = \(draw)   spine = \(spine)   |mismatch| = \(mismatch)\nthis arrow is \(direction)",
                body: "Match a 60-lb bow with a 60-spine arrow and the flex is just right — bends past the riser, snaps back straight. Mismatch by 25 and the arrow tumbles through the air."
            )
        case 3:
            return WalkthroughCard(
                headline: "How fast does it die?",
                math: "wobble(t) = amplitude · e^(−t/τ)\nτ ≈ 0.55 s",
                body: "The arrow's oscillation damps exponentially. A small mismatch decays before impact — looks clean. A big mismatch still has 30–40% of its wobble at impact, hitting the target at an angle and burying off-line."
            )
        case 4:
            return WalkthroughCard(
                headline: "Match it.",
                math: "spine ≈ draw  →  wobble → 0",
                body: "Drop the spine to about \(draw). The arrow flexes just enough to clear, snaps back straight in flight, and lands clean. Same bow, same string — different arrow."
            )
        default:
            return WalkthroughCard(headline: "", math: "", body: "")
        }
    }

    private struct WalkthroughCard {
        let headline: String
        let math: String
        let body: String
    }

    // MARK: - Physics readouts for the walkthrough

    private var liftAtTargetMeters: Double {
        let theta = scenario.pinLaunchAngleRadians
        let vx = scenario.arrowVelocity * cos(theta)
        let t = scenario.targetDistance / vx
        return scenario.arrowVelocity * sin(theta) * t
    }

    private var fallAtTargetMeters: Double {
        let theta = scenario.pinLaunchAngleRadians
        let vx = scenario.arrowVelocity * cos(theta)
        let t = scenario.targetDistance / vx
        return 0.5 * scenario.gravity * t * t
    }

    private var missMeters: Double {
        scenario.bullseyeHeight - scenario.actualImpactY
    }

    private var canonicalHoldoverCm: Double {
        max(0, missMeters * 100.0)
    }

    // MARK: - Actions

    private func handleCall(yes: Bool) {
        userCall = yes
        phase = .release
        scene.startSimulation()
    }

    private func handleTryCompute() {
        scene.resetForNewShot()
        phase = .compute(attempt: 1)
        if !scenario.usesParadoxMechanic {
            scene.setGhost(holdoverCm: computeHoldover, velocity: computeVelocity)
        }
    }

    private func handleComputeShoot() {
        let attempt: Int
        if case .compute(let a) = phase { attempt = a } else { attempt = 1 }
        phase = .computeAction(attempt: attempt)

        if scenario.usesParadoxMechanic {
            // Spine-driven shot: gravity is solved; user's choice drives wobble.
            scene.startSimulation(spineOverride: computeSpine)
        } else {
            scene.setGhost(holdoverCm: nil, velocity: computeVelocity)
            scene.startSimulation(holdoverCm: computeHoldover, velocity: computeVelocity)
        }
    }

    private func handleComputeRetry() {
        let next: Int
        if case .computeVerdict(_, let a) = phase { next = a + 1 } else { next = 1 }
        guard next <= computeMaxAttempts else { handleClose(); return }
        scene.resetForNewShot()
        phase = .compute(attempt: next)
        if !scenario.usesParadoxMechanic {
            scene.setGhost(holdoverCm: computeHoldover, velocity: computeVelocity)
        }
    }

    private func handleShowMath() {
        scene.resetForNewShot()
        scene.setGhost(holdoverCm: nil, velocity: computeVelocity)
        phase = .formulaWalkthrough(step: 0)
    }

    private func handleNextStep() {
        guard case .formulaWalkthrough(let step) = phase else { return }
        let next = step + 1
        if next >= Self.walkthroughStepCount {
            scene.resetForNewShot()
            phase = .bonusAttempt
            // Canonical shot: for paradox, fire with spine MATCHED to draw
            // so the user sees a clean flight. For pin-gap, use the correct
            // holdover.
            if scenario.usesParadoxMechanic {
                scene.startSimulation(spineOverride: scenario.bowDraw)
            } else {
                scene.startSimulation(
                    holdoverCm: canonicalHoldoverCm,
                    velocity: scenario.arrowVelocity
                )
            }
        } else {
            phase = .formulaWalkthrough(step: next)
        }
    }

    private func updateGhostIfComputing() {
        if case .compute = phase {
            scene.setGhost(holdoverCm: computeHoldover, velocity: computeVelocity)
        }
    }

    /// Diagnostic — ARCLAB_ARCHERY_AUTOSHOOT=1 auto-fires the shot 1.2 s
    /// after mount. Works in both stance phase (call beat) and compute
    /// phase (uses the current SPINE slider value, useful for screenshot
    /// scripts that pre-set ARCLAB_ARCHERY_COMPUTE_SPINE).
    private func startAutoshootIfRequested() {
        guard ProcessInfo.processInfo.environment["ARCLAB_ARCHERY_AUTOSHOOT"] == "1" else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            switch phase {
            case .stance:    handleCall(yes: true)
            case .compute:   handleComputeShoot()
            default:         return
            }
        }
    }

    private func handleClose() {
        onClose?()
    }

    // MARK: - HUD visibility

    private var shouldShowClose: Bool {
        switch phase {
        case .release, .computeAction:                          return false
        case .stance, .verdict, .compute, .computeVerdict,
             .formulaWalkthrough, .bonusAttempt:                return true
        }
    }

    private var hudOpacity: Double {
        switch phase {
        case .release, .computeAction, .bonusAttempt:           return 0.5
        case .stance, .verdict, .compute, .computeVerdict,
             .formulaWalkthrough:                               return 1.0
        }
    }

    // MARK: - Reveal copy

    private var revealPhenomenon: String {
        if let chapter, !chapter.lesson.title.isEmpty {
            return chapter.lesson.title
        }
        return scenario.phenomenon
    }

    private var revealExplainer: String {
        scenario.explainer
    }

    // MARK: - Scene wiring

    private func configureScene() {
        scene.audio = audio
        scene.onOutcomeResolved = { outcome, wobbleAtImpact in
            Task { @MainActor in
                pendingWobbleAtImpact = wobbleAtImpact
                pendingOutcome = outcome
            }
        }
        // If the view was constructed already in .compute phase
        // (diagnostic launch), prime the ghost so the slider preview is
        // visible immediately instead of after first drag.
        if case .compute = phase {
            scene.setGhost(holdoverCm: computeHoldover, velocity: computeVelocity)
        }
    }

    private func propagateReserve(for geometry: GeometryProxy) {
        let safeTop = geometry.safeAreaInsets.top
        let safeBottom = geometry.safeAreaInsets.bottom
        let topReserve: CGFloat = 60 + safeTop
        let bottomReserve: CGFloat
        switch phase {
        case .stance:
            bottomReserve = 220 + safeBottom
        case .compute:
            bottomReserve = 290 + safeBottom    // taller — two sliders
        case .release, .computeAction, .bonusAttempt:
            bottomReserve = safeBottom
        case .verdict:
            bottomReserve = 480 + safeBottom
        case .computeVerdict:
            bottomReserve = 360 + safeBottom
        case .formulaWalkthrough:
            bottomReserve = 400 + safeBottom
        }
        scene.applyUIReserve(
            top: topReserve,
            bottom: bottomReserve,
            safeTop: safeTop,
            safeBottom: safeBottom
        )
        // applyUIReserve rebuilds the scene graph (which clears the ghost).
        // Re-prime the ghost if we're in compute mode so the trajectory
        // preview stays visible across layout changes.
        if case .compute = phase {
            scene.setGhost(holdoverCm: computeHoldover, velocity: computeVelocity)
        }
    }
}
