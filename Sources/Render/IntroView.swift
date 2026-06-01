import SwiftUI

/// Scenario INTRO screen.
struct IntroView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(MotionController.self) private var motion
    @Environment(\.dismiss) private var dismiss

    let scenario: ScenarioDefinition
    let presentationSource: PresentationSource
    let onStart: () -> Void

    enum PresentationSource {
        case modalFromLevelSelect
        case pushedFromLevelSelect
    }

    @State private var verbVisible: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            topZone
            Spacer()
            heroZone
            briefingZone
                .padding(.top, Spacing.lg)
            Spacer()
            startButton
                .padding(.bottom, Spacing.xxl)
        }
        .padding(.horizontal, Spacing.md)
        .background(ScenarioBackgroundView(opacity: 0.40))
        .onAppear {
            motion.pause()
            if isFirstRun {
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    verbVisible = true
                }
            } else {
                verbVisible = true
            }
        }
        .onDisappear { motion.resume() }
    }

    private var topZone: some View {
        HStack(alignment: .top) {
            if presentationSource == .modalFromLevelSelect {
                Button(action: { dismiss() }) {
                    Text("✕ CLOSE")
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(1.1)
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Close. Return to home.")
            }
            Spacer()
        }
        .padding(.top, Spacing.xs)
    }

    private var heroZone: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(scenario.meta.subtitle)
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)

            Text(scenario.meta.title)
                .font(.anton(size: 96))
                .foregroundColor(.arclabWhite)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .dynamicTypeSize(.large ... .accessibility2)
                .padding(.top, Spacing.sm)
                .accessibilityLabel(scenario.meta.title)

            Rectangle()
                .fill(Color.arclabWhite)
                .frame(width: 24, height: 1)
                .padding(.top, Spacing.md)

            Text(scenario.voice.intro.subhead)
                .font(.barlowCondensed(size: 16, italic: true))
                .foregroundColor(.arclabMidGrey)
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var briefingZone: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if verbVisible {
                VariableStrip(
                    variables: scenario.situation.variables,
                    staggered: isFirstRun
                )
            }

            Text(scenario.situation.questionRevealed)
                .font(.barlowCondensed(size: 14, italic: true))
                .foregroundColor(.arclabWhite)
                .padding(.top, Spacing.sm)

            if let attemptInfo = replayAttemptInfoLine {
                Text(attemptInfo)
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(1.1)
                    .padding(.top, Spacing.xs)
            }
        }
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text(startButtonLabel)
                .font(.sfMono(size: 16, weight: .medium))
                .foregroundColor(.arclabWhite)
                .tracking(3.2)
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.pillButtonHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                        .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(startButtonLabel). Start the scenario.")
    }

    private var isFirstRun: Bool {
        profile.profile.firstEverScenario
    }

    private var replayAttemptInfoLine: String? {
        guard let record = profile.profile.completedScenarios[scenario.scenarioId],
              record.bestScore > 0 else { return nil }
        return "BEST: +\(record.bestScore)"
    }

    private var startButtonLabel: String {
        if profile.profile.firstRun {
            return "BEGIN"
        }
        if let record = profile.profile.completedScenarios[scenario.scenarioId],
           record.firstCompletedAt != nil {
            return "REPLAY"
        }
        return "START"
    }
}
