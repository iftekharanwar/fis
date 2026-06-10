import SwiftUI
import SpriteKit

/// PROTOTYPE — Level C "find your range" beat, reachable only via the
/// ARCLAB_LAUNCH_TO=pickspot diagnostic.
///
/// The shot is fully given (θ and v render as locked GIVEN rows — values
/// vary per round so repetition can't be eyeballed). The slider moves the
/// SHOOTER along the baseline; commit fires the given shot from where the
/// player chose to stand, and the rim decides. After a miss, a chevron
/// drops on the spot that would have worked, so the error reads as a
/// distance on the floor.
struct PickSpotView: View {
    @Environment(AudioService.self) private var audio

    let scenario: ScenarioDefinition
    var onClose: (() -> Void)? = nil

    @State private var scene: PlaySceneNode
    @State private var phase: Phase = .pick(attempt: 1)
    @State private var round: PickSpotChallenge?
    /// Player-chosen shooter-to-hoop distance in meters.
    @State private var rangeD: Double
    @State private var pickHapticCount: Int = 0

    private let rangeBounds: ClosedRange<Double>
    private let params: Projectile2DParams

    enum Phase: Equatable {
        case pick(attempt: Int)
        case flight(attempt: Int)
        case verdict(attempt: Int, madeIt: Bool)
    }

    init(scenario: ScenarioDefinition, onClose: (() -> Void)? = nil) {
        self.scenario = scenario
        self.onClose = onClose
        guard case .projectile2D(_, let p) = scenario.simulation else {
            fatalError("PickSpotView currently supports only PROJECTILE_2D scenarios")
        }
        params = p
        // Same playable band the round dealer guarantees answers within.
        rangeBounds = PickSpotChallenge.playableRange(params: p)
        let mid = (rangeBounds.lowerBound + rangeBounds.upperBound) / 2
        _rangeD = State(initialValue: (mid * 20).rounded() / 20)
        _scene = State(initialValue: PlaySceneNode(projectileParams: p, size: CGSize(width: 393, height: 340)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.arclabBlack.ignoresSafeArea()
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Basketball court. You stand where you choose; the given shot fires from there.")
                .accessibilityValue(sceneRead)

            VStack(spacing: 0) {
                CallHUD(onClose: onClose)
                Spacer().allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer().allowsHitTesting(false)
                bottomDock
            }
        }
        .statusBarHidden(true)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: pickHapticCount)
        .onAppear {
            configure()
            // Diagnostic — ARCLAB_AUTOPLAY=1 commits the pick after a beat
            // so the flight + verdict can be captured without taps.
            if ProcessInfo.processInfo.environment["ARCLAB_AUTOPLAY"] == "1" {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    handleShoot()
                }
            }
        }
        .onChange(of: rangeD) { _, _ in
            moveShooter()
        }
    }

    // MARK: - Dock

    @ViewBuilder
    private var bottomDock: some View {
        switch phase {
        case .pick(let attempt):
            pickDock(attempt: attempt)
                .background(Color.arclabBlack)
        case .flight:
            EmptyView()
        case .verdict(let attempt, let madeIt):
            verdictDock(attempt: attempt, madeIt: madeIt)
                .background(Color.arclabBlack)
        }
    }

    private func pickDock(attempt: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("FIND YOUR RANGE")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                Spacer()
                Text("ROUND \(attempt)")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            }

            VariableStrip(variables: environmentGivens)

            givenLine(label: "ANGLE", value: String(format: "%.0f", round?.answer.thetaDegrees ?? 0), unit: "°", spokenName: "Launch angle", spokenUnit: "degrees")
            givenLine(label: "SPEED", value: String(format: "%.2f", round?.answer.velocity ?? 0), unit: "m/s", spokenName: "Launch speed", spokenUnit: "meters per second")

            ParameterSliderRow(
                label: "RANGE", spokenName: "Distance from the hoop",
                unit: "m", spokenUnit: "meters",
                value: $rangeD, range: rangeBounds, format: "%.2f", step: 0.05
            )

            PrimaryButton(label: "Shoot from here", action: handleShoot)
                .padding(.top, Spacing.xs)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private func verdictDock(attempt: Int, madeIt: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            Text(madeIt ? "IN RANGE." : "OUT OF RANGE.")
                .font(.anton(size: 56))
                .foregroundColor(.arclabWhite)
                .padding(.horizontal, Spacing.md)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer().frame(height: Spacing.sm)

            Text(verdictBody(madeIt: madeIt))
                .font(.barlowCondensed(size: 16, italic: true))
                .foregroundColor(.arclabMidGrey)
                .padding(.horizontal, Spacing.md)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: Spacing.xs) {
                PrimaryButton(label: "Next round", action: { startRound(attempt: attempt + 1) })
                SecondaryButton(label: "Done", action: { onClose?() })
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 320)
    }

    private func verdictBody(madeIt: Bool) -> String {
        guard let round else { return "" }
        if madeIt {
            return String(format: "That spot is yours. This shot lives at %.2f m.", round.crossingD)
        }
        let offBy = rangeD - round.crossingD
        let direction = offBy > 0 ? "deep" : "close"
        return String(format: "This shot lives at %.2f m — you stood %.2f m too %@.",
                      round.crossingD, abs(offBy), direction)
    }

    private func givenLine(label: String, value: String, unit: String, spokenName: String = "", spokenUnit: String = "") -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(label)
                .font(.sfMono(size: 10))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
            Text("GIVEN")
                .font(.sfMono(size: 9))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
                .padding(.horizontal, Spacing.xxs)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.arclabBorderGrey, lineWidth: 1)
                )
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.sfMono(size: 18, weight: .medium))
                    .foregroundColor(.arclabWhite)
                Text(unit)
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(spokenName.isEmpty ? label : spokenName), given, \(value) \(spokenUnit.isEmpty ? unit : spokenUnit).")
    }

    /// World numbers that aren't the unknown: hoop height, release height,
    /// gravity. No distance — distance is the question.
    private var environmentGivens: [SituationDefinition.VariableSpec] {
        scenario.situation.variables.filter {
            $0.symbol != "theta" && $0.symbol != "v" && $0.symbol != "d"
        }
    }

    /// Scene description for VoiceOver, per phase.
    private var sceneRead: String {
        switch phase {
        case .pick:
            return "Standing \(String(format: "%.2f", rangeD)) meters from the hoop. The shot is given."
        case .flight:
            return "Ball in flight."
        case .verdict(_, let madeIt):
            return madeIt
                ? "It went in. That spot is yours."
                : "It missed. The spot that works is marked on the floor at "
                    + String(format: "%.2f", round?.crossingD ?? 0) + " meters."
        }
    }

    // MARK: - Flow

    private func configure() {
        scene.audio = audio
        // Prototype-fixed reserves: CallHUD up top, pick dock below.
        scene.applyUIReserve(top: 60, bottom: 430, safeTop: 60, safeBottom: 430)
        scene.onOutcomeResolved = { outcome, _ in
            Task { @MainActor in
                scene.freezeForOutcome()
                resolveVerdict(outcome: outcome)
            }
        }
        startRound(attempt: 1)
    }

    private func startRound(attempt: Int) {
        var rng = SystemRandomNumberGenerator()
        round = PickSpotChallenge.round(for: scenario, attempt: attempt, using: &rng)
        scene.resetForNewShot()
        scene.setSpotMarker(distanceMeters: nil)
        moveShooter()
        withAnimation(.easeOut(duration: 0.25)) { phase = .pick(attempt: attempt) }
    }

    /// Stand the shooter `rangeD` meters from the hoop.
    private func moveShooter() {
        let desiredX = params.target.center[0] - rangeD
        scene.setReleaseOffset(desiredX - params.releasePosition[0])
    }

    private func handleShoot() {
        guard case .pick(let attempt) = phase, let round else { return }
        pickHapticCount += 1
        phase = .flight(attempt: attempt)
        scene.startSimulation(answer: round.answer, pauseAtApex: false)
    }

    private func resolveVerdict(outcome: ProjectileOutcome) {
        guard case .flight(let attempt) = phase, let round else { return }
        let madeIt: Bool
        switch outcome {
        case .success: madeIt = true
        case .miss, .inFlight: madeIt = false
        }
        if !madeIt {
            // Drop the chevron on the spot that would have worked, so the
            // error reads as a distance on the floor.
            let correctX = params.target.center[0] - round.crossingD
            scene.setSpotMarker(distanceMeters: correctX - params.releasePosition[0])
        }
        withAnimation(.easeOut(duration: 0.25)) {
            phase = .verdict(attempt: attempt, madeIt: madeIt)
        }
    }
}
