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
        case "home":
            HomeView(
                onTapTodayCard: { _, _ in },
                onOpenSport: { _ in },
                onOpenProfile: {}
            )
        case "chapterlist":
            ChapterListView(
                sport: .basketball,
                onOpenChapter: { _ in }
            )
        case "chapter":
            ChapterView(
                chapter: BasketballCurriculum.chapters[0],
                onOpenLesson: { _ in },
                onOpenScenario: { _ in }
            )
        case "archerychapter":
            ChapterView(
                chapter: ArcheryCurriculum.chapters[0],
                onOpenLesson: { _ in },
                onOpenScenario: { _ in }
            )
        case "lesson":
            LessonView(
                lesson: BasketballCurriculum.chapters[0].lesson,
                onCompleted: {}
            )
        case "callplay":
            if let scenario = try? ScenarioLoader.load("bb-freethrow-001") {
                CallPlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "archery":
            if let scenario = ArcheryScenarioCatalog.scenario(for: "arc-pingap-001") {
                ArcheryCallPlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "archery2":
            if let scenario = ArcheryScenarioCatalog.scenario(for: "arc-paradox-001") {
                ArcheryCallPlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "profile":
            ProfileView()
        default:
            AppOpenView()
        }
    }
}

#Preview {
    RootView()
}
