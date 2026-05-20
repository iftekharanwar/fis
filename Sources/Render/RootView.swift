import SwiftUI

/// App root. Set `ARCLAB_LAUNCH_TO=<screen>` in the scheme to jump directly to a screen for screenshots.
struct RootView: View {
    @Environment(PlayerProfileStore.self) private var profile

    var body: some View {
        if let target = ProcessInfo.processInfo.environment["ARCLAB_LAUNCH_TO"] {
            diagnosticLaunch(target: target)
        } else {
            AppOpenView()
        }
    }

    @ViewBuilder
    private func diagnosticLaunch(target: String) -> some View {
        switch target {
        case "onboarding":
            OnboardingView(onBegin: {})
        case "sportpicker":
            SportPickerView(onSelect: { _ in })
        case "levelselect":
            LevelSelectView(sport: .basketball)
        case "intro":
            if let scenario = try? ScenarioLoader.load("bb-freethrow-001") {
                ScenarioContainerView(scenario: scenario)
            } else {
                Color.arclabBlack
            }
        case "play":
            if let scenario = try? ScenarioLoader.load("bb-freethrow-001") {
                PlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "solution":
            if let scenario = try? ScenarioLoader.load("bb-freethrow-001") {
                SolutionView(
                    scenario: scenario,
                    attempt: 3,
                    onClose: {},
                    onTryCanonical: { _, _ in }
                )
            } else {
                Color.arclabBlack
            }
        default:
            AppOpenView()
        }
    }
}

#Preview {
    RootView()
}
