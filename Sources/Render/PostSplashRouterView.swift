import SwiftUI

/// Post-splash router. v2.1 flow:
///   Home → SportPicker → Chapter → [Lesson | Scenario] → Verdict/Reveal → Home
///
/// First-launch users still see Onboarding before Home. Existing v1
/// presentation paths (ScenarioContainerView via fullScreenCover) are reused
/// for the scenario beat — the call-first + reveal beats arrive in steps 3–4
/// of CONCEPT_v2.1 §13.
struct PostSplashRouterView: View {
    @Environment(PlayerProfileStore.self) private var profile

    @State private var navigationPath = NavigationPath()
    @State private var presentedScenario: ScenarioDefinition?
    /// Tracked alongside `presentedScenario` so CallPlayView's reveal beat
    /// can pull phenomenon + explainer from the originating chapter.
    @State private var presentedChapter: Chapter?
    @State private var presentedProfile: Bool = false

    var body: some View {
        if profile.profile.hasSeenOnboarding {
            homeStack
        } else {
            OnboardingView(onBegin: handleOnboardingBegin)
                .transition(.opacity)
        }
    }

    private var homeStack: some View {
        NavigationStack(path: $navigationPath) {
            HomeView(
                onPickDailyScenario: handleDailyScenarioTap,
                onOpenSportPicker: { navigationPath.append(V2Route.sportPicker) },
                onOpenProfile: { presentedProfile = true }
            )
            .navigationDestination(for: V2Route.self) { route in
                destination(for: route)
                    .navigationBarBackButtonHidden(true)
            }
        }
        .fullScreenCover(item: $presentedScenario) { scenario in
            CallPlayView(
                scenario: scenario,
                chapter: presentedChapter,
                onClose: {
                    presentedScenario = nil
                    presentedChapter = nil
                }
            )
        }
        .sheet(isPresented: $presentedProfile) {
            ProfileView()
        }
    }

    // MARK: - Route dispatch

    @ViewBuilder
    private func destination(for route: V2Route) -> some View {
        switch route {
        case .sportPicker:
            SportPickerView(onSelect: { sport in
                // v2.1: sport tap routes to the first chapter of that sport.
                // Multi-sport picker arrives once soccer ships post-launch.
                if let firstChapter = chapters(for: sport).first {
                    navigationPath.append(V2Route.chapter(firstChapter.id))
                }
            })

        case .chapter(let chapterId):
            if let chapter = chapter(withId: chapterId) {
                ChapterView(
                    chapter: chapter,
                    onOpenLesson: { lesson in
                        navigationPath.append(V2Route.lesson(lesson.id, chapterId: chapter.id))
                    },
                    onOpenScenario: { scenarioId in
                        presentScenario(id: scenarioId, in: chapter)
                    }
                )
            } else {
                placeholder("Chapter not found.")
            }

        case .lesson(let lessonId, let chapterId):
            if let chapter = chapter(withId: chapterId),
               chapter.lesson.id == lessonId {
                LessonView(
                    lesson: chapter.lesson,
                    onCompleted: {
                        // Mark lesson as read, then drop back to the chapter
                        // screen so the user picks their first scenario.
                        profile.mutate { $0.completedLessons.insert(lessonId) }
                        navigationPath.removeLast()
                    }
                )
            } else {
                placeholder("Lesson not found.")
            }
        }
    }

    // MARK: - Actions

    private func handleOnboardingBegin() {
        // OnboardingView mutated hasSeenOnboarding; @Observable re-evaluates body.
    }

    private func handleDailyScenarioTap() {
        // Daily Scenario pipeline (server-picked daily card + push notify)
        // isn't wired yet — until it is, route to the canonical free throw
        // and attach its owning chapter so the reveal beat has content.
        let chapter = BasketballCurriculum.chapters.first(where: {
            $0.scenarioIDs.contains("bb-freethrow-001")
        })
        presentScenario(id: "bb-freethrow-001", in: chapter)
    }

    private func presentScenario(id: String, in chapter: Chapter?) {
        guard let scenario = try? ScenarioLoader.load(ScenarioID(id)) else { return }
        presentedChapter = chapter
        presentedScenario = scenario
    }

    // MARK: - Curriculum lookup

    private func chapters(for sport: Sport) -> [Chapter] {
        switch sport {
        case .basketball:
            return BasketballCurriculum.chapters
        default:
            return []
        }
    }

    private func chapter(withId id: String) -> Chapter? {
        BasketballCurriculum.chapters.first { $0.id == id }
    }

    // MARK: - Placeholders

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.barlowCondensed(size: 16, italic: true))
            .foregroundColor(.arclabMidGrey)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.arclabBlack)
    }
}

/// Navigation routes for v2.1.
enum V2Route: Hashable {
    case sportPicker
    case chapter(String)                 // chapterId
    case lesson(String, chapterId: String)  // lessonId
}
