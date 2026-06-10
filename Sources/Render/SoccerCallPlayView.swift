import SwiftUI
import SpriteKit

/// Soccer call-first play surface — mirrors the archery loop, but the
/// ball now flies under a real SpriteKit physics integration:
///
///   STANCE → RELEASE → VERDICT (+ reveal)
///       ↓                ↓
///       │             See why →
///       │                ↓
///       │           COMPUTE  (3 Magnus sliders + live preview)
///       │                ↓
///       │             SHOOT
///       │                ↓
///       │        COMPUTE ACTION  (animate with chosen params)
///       │                ↓
///       │        COMPUTE VERDICT (retry up to 5)
///       │                ↓
///       └─────────────► CLOSE
///
/// SpriteKit owns the scene graph (shooter, wall, keeper, goal, ball,
/// trail). Outcome is emitted from the physics resolution and bridged
/// back to SwiftUI via `pendingOutcome`.
struct SoccerCallPlayView: View {
    @Environment(PlayerProfileStore.self) private var profile

    let scenario: SoccerScenario
    let chapter: Chapter?
    var onClose: (() -> Void)? = nil

    @State private var scene: SoccerSceneNode
    @State private var phase: Phase = .stance
    @State private var userCall: Bool? = nil
    @State private var pendingOutcome: SoccerOutcome? = nil
    /// Guards the XP/completion write so one call beat only records once.
    /// Reset on replay so a fresh play-through is credited again.
    @State private var didRecordOutcome: Bool = false
    @State private var keeperOffset: Double
    /// Defender wall's lateral centre. Rolled at the same time as the
    /// keeper but on the OPPOSITE side of the goal — the two together
    /// always leave a real but defended corner for the player to find.
    @State private var wallOffsetCentre: Double

    // Compute-mode slider state — seeded from the scenario so the first
    // preview matches the strike the player just watched.
    @State private var computeSpin: Double
    @State private var computeVelocity: Double
    @State private var computeAimOffset: Double

    private let computeMaxAttempts = 5
    /// SPIN slider is signed: −12 m = full left curve, +12 m = full
    /// right curve, 0 = knuckler. The slider's sign IS the effect
    /// direction. Range widened so the player can curl the ball around
    /// the wall into either far corner — opens up the whole goal mouth.
    private let spinRange: ClosedRange<Double> = -12...12
    private let velocityRange: ClosedRange<Double> = 18...35
    private let aimRange: ClosedRange<Double> = -1...1

    enum Phase: Equatable {
        case stance
        case release
        case verdict(SoccerOutcome, wasCorrect: Bool)
        case compute(attempt: Int)
        case computeAction(attempt: Int)
        case computeVerdict(scored: Bool, attempt: Int)
    }

    init(scenario: SoccerScenario, chapter: Chapter? = nil, onClose: (() -> Void)? = nil) {
        self.scenario = scenario
        self.chapter = chapter
        self.onClose = onClose
        // SPIN seeded NEUTRAL (0) so the player can curl left or right
        // freely from the start — the scenario no longer biases which
        // way the ball wants to swerve. AIM stays seeded at scenario
        // so the player still gets a sensible starting line.
        _computeSpin = State(initialValue: 0)
        _computeVelocity = State(initialValue: scenario.ballVelocity)
        _computeAimOffset = State(initialValue: scenario.aimOffset)
        // Roll the keeper somewhere inside the goal mouth, then place
        // the wall on the OPPOSITE side of the goal so the two cover
        // different zones. Magnitudes are randomized so each load
        // produces a fresh layout while always staying inside the
        // posts (never out of play).
        let keeper = Double.random(in: -0.55...0.55)
        let wallMagnitude = Double.random(in: 0.15...0.35)
        let wall = (keeper >= 0 ? -1.0 : 1.0) * wallMagnitude
        _keeperOffset = State(initialValue: keeper)
        _wallOffsetCentre = State(initialValue: wall)
        // The SpriteKit scene is created once and reused across phases.
        // The size doesn't matter here — SpriteView resizes it on layout.
        let initial = CGSize(width: 393, height: 600)
        _scene = State(initialValue: SoccerSceneNode(
            scenario: scenario,
            size: initial,
            keeperOffset: keeper,
            wallOffsetCentre: wall
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            // CallHUD (60) + safe area + info-strip allowance. Tightened
            // versus the previous pass to gift more vertical pitch to
            // the world — figures are smaller now, the goal can sit
            // higher without touching the RANGE/WALL/SPIN line.
            let topReserve: CGFloat = 60 + geometry.safeAreaInsets.top
                + (showsInfoStrip ? 80 : 24)
            let bottomReserve: CGFloat = bottomDockReserve
                + geometry.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                Color.arclabBlack.ignoresSafeArea()

                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    // SKScene content never reaches the accessibility tree —
                    // narrate it. Soccer's call happens at stance, so the
                    // stance read carries the full evidence (aim/spin/curve).
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(SceneNarration.soccerLabel(scenario, keeperOffset: keeperOffset))
                    .accessibilityValue(sceneAccessibilityValue)
                    .accessibilityIgnoresInvertColors()

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
                    RevealOverlay(
                        wasCorrect: wasCorrect,
                        actualWentIn: outcome.didScore,
                        phenomenon: revealPhenomenon,
                        explainer: revealExplainer,
                        onTryCompute: handleTryCompute,
                        outcomeLabelOverride: outcome.didScore ? "IT WENT IN" : "IT MISSED"
                    )
                    .transition(.opacity)
                }
            }
            .onAppear {
                configureScene()
                scene.applyReserves(top: topReserve, bottom: bottomReserve)
            }
            .onChange(of: phase) { _, _ in
                scene.applyReserves(top: topReserve, bottom: bottomReserve)
            }
            .onChange(of: geometry.size) { _, _ in
                scene.applyReserves(top: topReserve, bottom: bottomReserve)
            }
        }
        .statusBarHidden(true)
        .onChange(of: pendingOutcome) { _, new in
            guard let outcome = new else { return }
            handleResolvedOutcome(outcome)
            pendingOutcome = nil
        }
        .onChange(of: computeSpin) { _, _ in updateAimIndicator() }
        .onChange(of: computeVelocity) { _, _ in updateAimIndicator() }
        .onChange(of: computeAimOffset) { _, _ in updateAimIndicator() }
    }

    // MARK: - Aim indicator (compute phase only)

    /// Pushes the current slider values to the scene's aim indicator —
    /// a short curved arrow at the shooter that scales with POWER and
    /// bends with signed SPIN. Visible only while the player is tuning;
    /// hidden as soon as the shot is fired or the dock changes.
    private func updateAimIndicator() {
        if case .compute = phase {
            scene.setGhost(
                power: computeVelocity,
                aim: computeAimOffset,
                signedSpin: computeSpin
            )
        } else {
            scene.setGhost(power: nil, aim: 0, signedSpin: 0)
        }
    }

    // MARK: - Scene wiring

    private func configureScene() {
        scene.onOutcomeResolved = { outcome in
            Task { @MainActor in
                pendingOutcome = outcome
            }
        }
    }

    // MARK: - Top info strip

    private var showsInfoStrip: Bool {
        switch phase {
        case .stance, .compute: return true
        default:                return false
        }
    }

    private var infoStrip: some View {
        HStack(spacing: Spacing.lg) {
            stat(label: "RANGE", value: "\(Int(scenario.goalDistance)) m")
            stat(label: "WALL", value: "\(Int(scenario.wallDistance)) m")
            stat(label: "SPIN", value: scenario.mechanicLabel)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xxs)
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

    // MARK: - Bottom reservations

    /// Bottom-area reservation per phase — keeps the shooter clearly
    /// above whichever dock is currently up. Trimmed from the previous
    /// pass: figures are smaller now, so they need less head room above
    /// the dock, and the pitch grows taller as a result.
    private var bottomDockReserve: CGFloat {
        switch phase {
        case .stance:                       return 280
        case .compute:                      return 360
        case .release, .computeAction:      return 80
        case .verdict:                      return 480
        case .computeVerdict:               return 360
        }
    }

    // MARK: - Bottom overlay

    @ViewBuilder
    private var bottomOverlay: some View {
        switch phase {
        case .stance:
            stanceDock
        case .release, .computeAction:
            EmptyView()
        case .verdict(let outcome, let wasCorrect):
            SoccerCallVerdictView(wasCorrect: wasCorrect, outcome: outcome)
                .frame(height: 480)
                .background(Color.arclabBlack)
                .transition(.opacity)
        case .compute(let attempt):
            computeDock(attempt: attempt)
                .transition(.opacity)
        case .computeVerdict(let scored, let attempt):
            computeVerdictView(scored: scored, attempt: attempt)
                .frame(height: 340)
                .transition(.opacity)
        }
    }

    /// The live scene description VoiceOver reads off the pitch canvas.
    private var sceneAccessibilityValue: String {
        switch phase {
        case .stance:
            return SceneNarration.soccerStanceRead(scenario)
        case .release:
            return "Ball in flight."
        case .verdict:
            return "Strike resolved."
        case .compute, .computeAction:
            return "Your strike is set on the sliders below."
        case .computeVerdict:
            return "Your strike resolved."
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
                // Soccer's call happens here at stance — fold the kick read
                // into the prompt so the evidence is one element away from
                // the YES/NO buttons.
                .accessibilityLabel("\(scenario.stancePrompt) \(SceneNarration.soccerStanceRead(scenario)) Yes and No buttons below.")

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

    // MARK: - Compute dock (Magnus sliders)

    private func computeDock(attempt: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("TUNE THE SHOT")
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
                label: "POWER", spokenName: "Shot power",
                unit: "m/s", spokenUnit: "meters per second",
                value: $computeVelocity, range: velocityRange, format: "%.0f", step: 1,
                tint: .arclabRimOrange
            )

            ParameterSliderRow(
                label: "DIRECTION", spokenName: "Aim direction",
                unit: directionUnit, spokenUnit: spokenDirection,
                value: $computeAimOffset, range: aimRange, format: "%+.2f", step: 0.05,
                tint: .arclabRimOrange
            )

            ParameterSliderRow(
                label: "SPIN", spokenName: "Spin",
                unit: spinUnit, spokenUnit: spokenSpin,
                value: $computeSpin, range: spinRange, format: "%+.1f", step: 0.1,
                tint: .arclabRimOrange
            )

            PrimaryButton(label: "Shoot", action: handleComputeShoot)
                .padding(.top, Spacing.xxs)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.arclabBlack)
    }

    /// Tiny hint sitting next to the DIRECTION read-out — negative aims
    /// left of centre, positive aims right.
    private var directionUnit: String {
        if computeAimOffset < -0.05 { return "←" }
        if computeAimOffset >  0.05 { return "→" }
        return "·"
    }

    /// SPIN unit hints which way the curve is pulling.
    private var spinUnit: String {
        if computeSpin < -0.05 { return "m ←" }
        if computeSpin >  0.05 { return "m →" }
        return "m ·"
    }

    /// Spoken equivalents of the arrow hints — VoiceOver can't read "←".
    private var spokenDirection: String {
        if computeAimOffset < -0.05 { return "toward the left post" }
        if computeAimOffset >  0.05 { return "toward the right post" }
        return "center"
    }

    private var spokenSpin: String {
        if computeSpin < -0.05 { return "meters of curve, bending left" }
        if computeSpin >  0.05 { return "meters of curve, bending right" }
        return "meters of curve, straight"
    }

    // MARK: - Compute verdict view

    private func computeVerdictView(scored: Bool, attempt: Int) -> some View {
        let canRetry = !scored && attempt < computeMaxAttempts
        let verb = scored ? "GOAL." : "MISSED."
        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            Text(verb)
                .font(.anton(size: 64))
                .foregroundColor(.arclabWhite)
                .padding(.horizontal, Spacing.md)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer().frame(height: Spacing.sm)

            Text(computeVerdictSubhead(scored: scored))
                .font(.barlowCondensed(size: 16, italic: true))
                .foregroundColor(.arclabMidGrey)
                .padding(.horizontal, Spacing.md)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack(spacing: Spacing.md) {
                if canRetry {
                    AccentOutlineButton(label: "Retry", action: handleComputeRetry)
                } else {
                    // Out of attempts (or scored) — offer a clean restart
                    // instead of leaving "Done" as the only way out.
                    SecondaryButton(label: "Play again", action: handleReplay)
                }
                SecondaryButton(label: "Done", action: handleClose)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((scored ? Color.arclabBlack : Color.arclabMissTint).ignoresSafeArea())
        .announceOnAppear { "\(verb) \(computeVerdictSubhead(scored: scored))" }
    }

    /// Coaching line based on the resolved scene outcome — points the
    /// player at which slider to nudge for the next attempt.
    private func computeVerdictSubhead(scored: Bool) -> String {
        if scored {
            return "Tucked it past the keeper. The spin and the aim agreed."
        }
        if let outcome = pendingOutcome ?? lastResolvedOutcome {
            switch outcome {
            case .goal:          return ""
            case .savedByKeeper:
                let keeperSide = keeperOffset > 0 ? "right" : "left"
                return "Right at the keeper — they shaded \(keeperSide). Find the other corner."
            case .wideOfPost:    return "Past the post. Less curve, or pull the DIRECTION back."
            case .overTheBar:    return "Sailed over. Less POWER or more SPIN to bring it down."
            }
        }
        return "The keeper got a hand to it. Try a different line."
    }

    // MARK: - Actions

    private func handleCall(yes: Bool) {
        userCall = yes
        scene.resetForNewShot()
        phase = .release
        let signedSpin = scenario.curveDirection.signedHorizontal * scenario.curveAmount
        scene.startSimulation(
            power: scenario.ballVelocity,
            aim: scenario.aimOffset,
            signedSpin: signedSpin
        )
    }

    @State private var lastResolvedOutcome: SoccerOutcome? = nil

    /// Routes physics resolution to the right verdict phase. Call beat
    /// → `.verdict`, compute beat → `.computeVerdict`.
    private func handleResolvedOutcome(_ outcome: SoccerOutcome) {
        lastResolvedOutcome = outcome
        switch phase {
        case .release:
            let wasCorrect = (userCall == outcome.didScore)
            recordCallOutcome(correct: wasCorrect)
            withAnimation(.easeOut(duration: 0.25)) {
                phase = .verdict(outcome, wasCorrect: wasCorrect)
            }
        case .computeAction(let attempt):
            withAnimation(.easeOut(duration: 0.25)) {
                phase = .computeVerdict(scored: outcome.didScore, attempt: attempt)
            }
        default:
            break
        }
    }

    private func handleTryCompute() {
        scene.resetForNewShot()
        withAnimation(.easeOut(duration: 0.25)) {
            phase = .compute(attempt: 1)
        }
        // Prime the aim indicator off the seeded slider values.
        updateAimIndicator()
    }

    private func handleComputeShoot() {
        let attempt: Int
        if case .compute(let a) = phase { attempt = a } else { attempt = 1 }
        // Hide the aim indicator before the ball flies.
        scene.setGhost(power: nil, aim: 0, signedSpin: 0)
        scene.resetForNewShot()
        phase = .computeAction(attempt: attempt)
        scene.startSimulation(
            power: computeVelocity,
            aim: computeAimOffset,
            signedSpin: computeSpin
        )
    }

    private func handleComputeRetry() {
        let next: Int
        if case .computeVerdict(_, let a) = phase { next = a + 1 } else { next = 1 }
        guard next <= computeMaxAttempts else { handleClose(); return }
        scene.resetForNewShot()
        withAnimation(.easeOut(duration: 0.25)) {
            phase = .compute(attempt: next)
        }
        updateAimIndicator()
    }

    private func handleClose() {
        onClose?()
    }

    /// Restart the playable compute challenge with fresh attempts. Surfaced
    /// on the attempts-spent verdict so the user is never dead-ended into
    /// closing.
    ///
    /// The user already made their YES/NO call this session, so a replay does
    /// NOT re-ask the call — it drops straight back into the slider challenge.
    /// A genuine fresh replay of the level (re-entering from the picker) is a
    /// new view instance and still opens on the call beat.
    private func handleReplay() {
        pendingOutcome = nil
        lastResolvedOutcome = nil
        // Fresh slider values for a clean run at the challenge.
        computeSpin = 0
        computeVelocity = scenario.ballVelocity
        computeAimOffset = scenario.aimOffset
        scene.resetForNewShot()
        withAnimation(.easeOut(duration: 0.25)) { phase = .compute(attempt: 1) }
        updateAimIndicator()
    }

    /// Record the call beat into the profile: streak, XP, and a completion
    /// entry — so soccer actually moves the player's Sports IQ and shows up
    /// in their profile (previously only the streak was recorded). A correct
    /// call is worth more; repeats of an already-completed scenario earn a
    /// small fraction so the loop can't be farmed.
    private func recordCallOutcome(correct: Bool) {
        guard !didRecordOutcome else { return }
        didRecordOutcome = true
        let id = ScenarioID(scenario.id)
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

    // MARK: - HUD visibility

    private var shouldShowClose: Bool {
        switch phase {
        case .release, .computeAction: return false
        default:                       return true
        }
    }

    private var hudOpacity: Double {
        switch phase {
        case .release, .computeAction: return 0.5
        default:                       return 1.0
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
}

#Preview {
    SoccerCallPlayView(
        scenario: SoccerScenarioCatalog.scenarios["soc-curve-001"]!,
        chapter: SoccerCurriculum.chapters[0],
        onClose: {}
    )
    .environment(PlayerProfileStore())
}
