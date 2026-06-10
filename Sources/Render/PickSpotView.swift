import SwiftUI
import SpriteKit

/// PROTOTYPE — Level C "pick the spot" beat, reachable only via the
/// ARCLAB_LAUNCH_TO=pickspot diagnostic.
///
/// The shot is fully given (θ and v render as locked GIVEN rows — values
/// vary per round so the visible hoop isn't a cheat-sheet). The player
/// slides a floor marker to call where the ball crosses hoop height on
/// the descent, commits, and watches the given shot fly. Hit = within
/// the rim's inner radius of the true crossing.
struct PickSpotView: View {
    @Environment(AudioService.self) private var audio

    let scenario: ScenarioDefinition
    var onClose: (() -> Void)? = nil

    @State private var scene: PlaySceneNode
    @State private var phase: Phase = .pick(attempt: 1)
    @State private var round: PickSpotChallenge?
    @State private var markerD: Double
    @State private var pickHapticCount: Int = 0

    private let markerRange: ClosedRange<Double>
    private let params: Projectile2DParams

    enum Phase: Equatable {
        case pick(attempt: Int)
        case flight(attempt: Int)
        case verdict(attempt: Int, hit: Bool, offBy: Double)
    }

    init(scenario: ScenarioDefinition, onClose: (() -> Void)? = nil) {
        self.scenario = scenario
        self.onClose = onClose
        guard case .projectile2D(_, let p) = scenario.simulation else {
            fatalError("PickSpotView currently supports only PROJECTILE_2D scenarios")
        }
        params = p
        // Marker range from the scenario's authored d input field when
        // present, clamped to the visible world so the marker stays on court.
        let field = scenario.input.fields.first(where: { $0.name == "d" })
        let lo = max(field?.min ?? 0.5, 0.5)
        let hi = min(field?.max ?? (p.world.xMax - 0.5), p.world.xMax - 0.5)
        markerRange = lo...max(hi, lo + 1)
        _markerD = State(initialValue: (lo + hi) / 2)
        _scene = State(initialValue: PlaySceneNode(projectileParams: p, size: CGSize(width: 393, height: 340)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.arclabBlack.ignoresSafeArea()
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()
                .allowsHitTesting(false)

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
                    handlePick()
                }
            }
        }
        .onChange(of: markerD) { _, new in
            scene.setSpotMarker(distanceMeters: new)
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
        case .verdict(let attempt, let hit, let offBy):
            verdictDock(attempt: attempt, hit: hit, offBy: offBy)
                .background(Color.arclabBlack)
        }
    }

    private func pickDock(attempt: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("CALL THE SPOT")
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

            givenLine(label: "ANGLE", value: String(format: "%.0f", round?.answer.thetaDegrees ?? 0), unit: "°")
            givenLine(label: "SPEED", value: String(format: "%.2f", round?.answer.velocity ?? 0), unit: "m/s")

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .lastTextBaseline) {
                    Text("DISTANCE")
                        .font(.sfMono(size: 10))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)
                    Spacer()
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.2f", markerD))
                            .font(.sfMono(size: 18, weight: .medium))
                            .foregroundColor(.arclabWhite)
                        Text("m")
                            .font(.sfMono(size: 11))
                            .foregroundColor(.arclabMidGrey)
                    }
                }
                Slider(value: $markerD, in: markerRange, step: 0.05)
                    .tint(.arclabWhite)
            }

            PrimaryButton(label: "Call it", action: handlePick)
                .padding(.top, Spacing.xs)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    private func verdictDock(attempt: Int, hit: Bool, offBy: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Spacing.lg)

            Text(hit ? "CALLED IT." : "OFF THE SPOT.")
                .font(.anton(size: 56))
                .foregroundColor(.arclabWhite)
                .padding(.horizontal, Spacing.md)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer().frame(height: Spacing.sm)

            Text(hit
                 ? String(format: "Within the rim. It crossed at %.2f m.", round?.crossingD ?? 0)
                 : String(format: "It crossed at %.2f m — your call was off by %.2f m.", round?.crossingD ?? 0, offBy))
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

    private func givenLine(label: String, value: String, unit: String) -> some View {
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
    }

    /// World numbers that aren't the unknown: hoop height, release height,
    /// gravity. No distance — distance is the question.
    private var environmentGivens: [SituationDefinition.VariableSpec] {
        scenario.situation.variables.filter {
            $0.symbol != "theta" && $0.symbol != "v" && $0.symbol != "d"
        }
    }

    // MARK: - Flow

    private func configure() {
        scene.audio = audio
        // Prototype-fixed reserves: CallHUD up top, pick dock below.
        scene.applyUIReserve(top: 60, bottom: 430, safeTop: 60, safeBottom: 430)
        scene.onOutcomeResolved = { _, _ in
            Task { @MainActor in
                scene.freezeForOutcome()
                resolveVerdict()
            }
        }
        startRound(attempt: 1)
    }

    private func startRound(attempt: Int) {
        var rng = SystemRandomNumberGenerator()
        round = PickSpotChallenge.round(for: scenario, attempt: attempt, using: &rng)
        scene.resetForNewShot()
        scene.setSpotMarker(distanceMeters: markerD)
        withAnimation(.easeOut(duration: 0.25)) { phase = .pick(attempt: attempt) }
    }

    private func handlePick() {
        guard case .pick(let attempt) = phase, let round else { return }
        pickHapticCount += 1
        phase = .flight(attempt: attempt)
        scene.startSimulation(answer: round.answer, pauseAtApex: false)
    }

    private func resolveVerdict() {
        guard case .flight(let attempt) = phase, let round else { return }
        let hit = PickSpotChallenge.isHit(markerD: markerD, crossingD: round.crossingD, params: params)
        let offBy = abs(markerD - round.crossingD)
        withAnimation(.easeOut(duration: 0.25)) {
            phase = .verdict(attempt: attempt, hit: hit, offBy: offBy)
        }
    }
}
