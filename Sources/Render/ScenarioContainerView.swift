import SwiftUI

/// Owns INTRO+PLAY phases within a single fullScreenCover.
struct ScenarioContainerView: View {
    @Environment(\.dismiss) private var dismiss

    let scenario: ScenarioDefinition

    @State private var phase: Phase = .intro

    enum Phase: Sendable, Equatable {
        case intro
        case play
    }

    var body: some View {
        ZStack {
            switch phase {
            case .intro:
                IntroView(
                    scenario: scenario,
                    presentationSource: .modalFromLevelSelect,
                    onStart: handleIntroStart
                )
                .transition(.opacity)
            case .play:
                PlayView(scenario: scenario, onClose: handleClose)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: phase)
    }

    private func handleIntroStart() {
        phase = .play
    }

    private func handleClose() {
        dismiss()
    }
}
