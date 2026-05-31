import SwiftUI

/// Post-splash router.
///
/// v2.2 flow:
///   Home → [TODAY → Scenario]
///        → [ALL SPORTS → SportPicker → ChapterList(sport) → Chapter → Lesson | Scenario]
///        → Verdict / Reveal → Home
///
/// TODAY is currently driven by NextUpFinder (the user's next unplayed
/// scenario). The card surface is named TODAY so the home stays stable
/// once daily-pick video content is wired in.
///
/// Scenario presentation dispatches by id prefix: `bb-*` opens the
/// basketball `CallPlayView`, `arc-*` opens `ArcheryCallPlayView`. The
/// two play surfaces share the reveal beat (`RevealOverlay`) but each
/// owns its own scene + verdict view because archery and basketball have
/// different success geometry and different sport-coded copy.
struct PostSplashRouterView: View {
    @Environment(PlayerProfileStore.self) private var profile

    @State private var navigationPath = NavigationPath()
    @State private var presentedPlay: PresentedPlay?
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
                onTapTodayCard: handleTapTodayCard,
                onOpenSport: { sport in navigationPath.append(V2Route.chapterList(sport)) },
                onOpenProfile: { presentedProfile = true }
            )
            .navigationDestination(for: V2Route.self) { route in
                destination(for: route)
                    .navigationBarBackButtonHidden(true)
            }
        }
        .fullScreenCover(item: $presentedPlay) { play in
            playView(for: play)
        }
        .sheet(isPresented: $presentedProfile) {
            ProfileView()
        }
    }

    // MARK: - Play presentation

    @ViewBuilder
    private func playView(for play: PresentedPlay) -> some View {
        switch play {
        case .basketball(let scenario, let chapter):
            CallPlayView(
                scenario: scenario,
                chapter: chapter,
                onClose: { presentedPlay = nil }
            )
        case .archery(let scenario, let chapter):
            ArcheryCallPlayView(
                scenario: scenario,
                chapter: chapter,
                onClose: { presentedPlay = nil }
            )
        }
    }

    // MARK: - Route dispatch

    @ViewBuilder
    private func destination(for route: V2Route) -> some View {
        switch route {
        case .sportPicker:
            SportPickerView(onSelect: { sport in
                guard sport.isUnlocked else { return }
                navigationPath.append(V2Route.chapterList(sport))
            })

        case .chapterList(let sport):
            ChapterListView(
                sport: sport,
                onOpenChapter: { chapter in
                    navigationPath.append(V2Route.chapter(chapter.id))
                }
            )

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

    /// User tapped the TODAY card. Same routing logic as before:
    ///  - scenario exists AND its lesson has been read → present the
    ///    scenario directly (engaged path)
    ///  - otherwise → push the chapter view so the user lands on the
    ///    lesson + scenario list.
    private func handleTapTodayCard(chapter: Chapter, scenarioId: String?) {
        let lessonRead = profile.profile.completedLessons.contains(chapter.lesson.id)
        if let scenarioId, lessonRead {
            presentScenario(id: scenarioId, in: chapter)
        } else {
            navigationPath.append(V2Route.chapter(chapter.id))
        }
    }

    /// Dispatches the scenario to the right play surface by id prefix.
    /// Unknown / unloadable ids fail silently — better than a crash on a
    /// stale curriculum entry.
    private func presentScenario(id: String, in chapter: Chapter?) {
        if id.hasPrefix("arc-") {
            guard let arc = ArcheryScenarioCatalog.scenario(for: id) else { return }
            presentedPlay = .archery(arc, chapter)
        } else {
            guard let scenario = try? ScenarioLoader.load(ScenarioID(id)) else { return }
            presentedPlay = .basketball(scenario, chapter)
        }
    }

    // MARK: - Curriculum lookup

    private func chapter(withId id: String) -> Chapter? {
        for sport in Sport.allCases {
            if let match = sport.chapters.first(where: { $0.id == id }) {
                return match
            }
        }
        return nil
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

/// Discriminated union covering both play surfaces. Identifiable so it
/// can drive `.fullScreenCover(item:)` without a separate Bool flag.
enum PresentedPlay: Identifiable {
    case basketball(ScenarioDefinition, Chapter?)
    case archery(ArcheryScenario, Chapter?)

    var id: String {
        switch self {
        case .basketball(let s, _): return s.scenarioId.rawValue
        case .archery(let s, _):    return s.id
        }
    }
}

/// Navigation routes for v2.2.
enum V2Route: Hashable {
    case sportPicker
    case chapterList(Sport)
    case chapter(String)                       // chapterId
    case lesson(String, chapterId: String)     // lessonId
}
