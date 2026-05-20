import SwiftUI

/// Routes to Onboarding or SportPicker based on `hasSeenOnboarding`.
struct PostSplashRouterView: View {
    @Environment(PlayerProfileStore.self) private var profile

    @State private var navigationPath = NavigationPath()

    var body: some View {
        if profile.profile.hasSeenOnboarding {
            sportPickerStack
        } else {
            OnboardingView(onBegin: handleOnboardingBegin)
                .transition(.opacity)
        }
    }

    private var sportPickerStack: some View {
        NavigationStack(path: $navigationPath) {
            SportPickerView(onSelect: { sport in
                navigationPath.append(SportRoute.levelSelect(sport: sport))
            })
            .navigationDestination(for: SportRoute.self) { route in
                switch route {
                case .levelSelect(let sport):
                    LevelSelectView(sport: sport)
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private func handleOnboardingBegin() {
        // OnboardingView already mutated hasSeenOnboarding; @Observable re-evaluates body.
    }
}

enum SportRoute: Hashable {
    case levelSelect(sport: Sport)
}
