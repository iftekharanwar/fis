import SwiftUI

/// Post-splash router. v3 flow:
///   Home → Sport → ChapterListView → sport chapter screen
///        → lesson reader → practice row → call verdict
///        → optional sliders/math deep-dive
///   Home → (DAILY card) → DailyQuestionView
///   Home → (PROFILE pill) → ProfileView (sheet)
///   Home → (gear chip) → SettingsView (sheet)
///
/// First-launch users see OnboardingView before Home. SportPicker is
/// auto-skipped when only one sport is unlocked (current v3 ship state).
struct PostSplashRouterView: View {
    @Environment(PlayerProfileStore.self) private var profile

    @State private var navigationPath = NavigationPath()
    /// Daily-card path → CallPlayView (call mechanic, single shot).
    @State private var presentedScenario: ScenarioDefinition?
    /// Tracked alongside `presentedScenario` so CallPlayView's reveal beat
    /// can pull phenomenon + explainer from the originating chapter.
    @State private var presentedChapter: Chapter?
    /// Archery push: ArcheryScenario goes through its own play surface
    /// (ArcheryCallPlayView, call mechanic — totally separate from the
    /// basketball numpad PlayView).
    @State private var pushedArcheryScenario: ArcheryScenario?
    @State private var pushedArcheryChapter: Chapter?
    /// Soccer push: SoccerScenario goes through SoccerCallPlayView — the
    /// Magnus-driven free-kick surface (plan view, SF Symbol figures, no
    /// numpad). One scenario at a time; no auto-advance queue yet.
    @State private var pushedSoccerScenario: SoccerScenario?
    @State private var pushedSoccerChapter: Chapter?
    @State private var presentedProfile: Bool = false
    /// Settings — presented from the Home gear chip (top-right).
    @State private var presentedSettings: Bool = false
    /// Daily Question — presented full-screen from the Home DAILY card.
    @State private var presentedDaily: Bool = false
    /// F1 ships lesson-first: the playable corner isn't built yet, so a
    /// scenario tap on an F1 chapter raises this honest "coming soon" alert.
    @State private var f1ScenarioComingSoon: Bool = false

    var body: some View {
        if profile.profile.hasSeenOnboarding {
            homeStack
        } else {
            OnboardingView(onBegin: {})
                .transition(.opacity)
        }
    }

    private var homeStack: some View {
        NavigationStack(path: $navigationPath) {
            HomeView(
                onOpenSport: { sport in navigationPath.append(V2Route.chapterList(sport)) },
                onOpenProfile: { presentedProfile = true },
                onOpenDaily: { presentedDaily = true },
                onOpenSettings: { presentedSettings = true }
            )
            .navigationDestination(for: V2Route.self) { route in
                destination(for: route)
                    // Hide the nav bar entirely (incl. the default chevron),
                    // but DON'T use .navigationBarBackButtonHidden(true) —
                    // that kills the native left-edge back-swipe gesture too.
                    // Hiding the bar via .toolbar leaves the interactive
                    // pop-gesture recognizer alive on iOS.
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        // Daily-card path: CallPlayView (call mechanic, one-shot).
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
        // Archery push: ArcheryCallPlayView (call mechanic — Parham's v2.2
        // surface). One scenario at a time, no auto-advance queue yet.
        .fullScreenCover(item: $pushedArcheryScenario) { scenario in
            ArcheryCallPlayView(
                scenario: scenario,
                chapter: pushedArcheryChapter,
                onClose: {
                    pushedArcheryScenario = nil
                    pushedArcheryChapter = nil
                }
            )
        }
        // Soccer push: SoccerCallPlayView (Magnus free-kick surface).
        .fullScreenCover(item: $pushedSoccerScenario) { scenario in
            SoccerCallPlayView(
                scenario: scenario,
                chapter: pushedSoccerChapter,
                onClose: {
                    pushedSoccerScenario = nil
                    pushedSoccerChapter = nil
                }
            )
        }
        .sheet(isPresented: $presentedProfile) {
            ProfileView()
        }
        .sheet(isPresented: $presentedSettings) {
            SettingsView()
        }
        // Daily Question — one small physics question a day, full-screen.
        // A brand-new player gets Day 1 (illustrated); regulars get the
        // date-based daily.
        .fullScreenCover(isPresented: $presentedDaily) {
            DailyQuestionView(
                onClose: { presentedDaily = false },
                question: DailyQuestionPicker.current(for: profile.profile)
            )
        }
        // F1 lesson-first: scenario taps on F1 chapters land here until the
        // playable corner ships.
        .alert("Coming soon", isPresented: $f1ScenarioComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The corner is coming soon — the lesson is ready now.")
        }
    }

    // MARK: - Route dispatch

    @ViewBuilder
    private func destination(for route: V2Route) -> some View {
        switch route {
        case .sportPicker:
            SportPickerView(onSelect: { sport in
                navigationPath.append(V2Route.chapterList(sport))
            })

        case .chapterList(let sport):
            ChapterListView(
                sport: sport,
                chapters: chapters(for: sport),
                onSelectChapter: { chapter in
                    navigationPath.append(V2Route.chapter(chapter.id))
                }
            )

        case .chapter(let chapterId):
            if let chapter = chapter(withId: chapterId) {
                switch chapter.sport {
                case .basketball:
                    ChapterView(
                        chapter: chapter,
                        onOpenScenario: { scenarioId in
                            presentScenario(id: scenarioId, in: chapter)
                        }
                    )
                case .archery:
                    // Archery uses Parham's v2.2 ChapterView (lesson row +
                    // scenario rows). Scenario taps present ArcheryCallPlayView.
                    ChapterView(
                        chapter: chapter,
                        onOpenScenario: { scenarioId in
                            startArcheryPush(chapter: chapter, scenarioId: scenarioId)
                        }
                    )
                case .soccer:
                    // Soccer reuses the same chapter shell as archery — lesson
                    // row + scenario rows. Scenario taps present
                    // SoccerCallPlayView (Magnus free-kick surface).
                    ChapterView(
                        chapter: chapter,
                        onOpenScenario: { scenarioId in
                            startSoccerPush(chapter: chapter, scenarioId: scenarioId)
                        }
                    )
                case .formula1:
                    // F1 ships lesson-first: the chapter + lesson read now;
                    // the playable corner (F1CallPlayView) lands next pass.
                    // Until then a scenario tap surfaces an honest "coming soon".
                    ChapterView(
                        chapter: chapter,
                        onOpenScenario: { _ in f1ScenarioComingSoon = true }
                    )
                case .pool:
                    // Locked sports shouldn't reach here, but render an
                    // honest "coming soon" if they do (vs cryptic crash).
                    placeholder("\(chapter.sport.displayName) is coming soon.")
                }
            } else {
                placeholder("Chapter not found.")
            }

        }
    }

    // MARK: - Actions

    private func presentScenario(id: String, in chapter: Chapter?) {
        guard let scenario = try? ScenarioLoader.load(ScenarioID(id)) else { return }
        presentedChapter = chapter
        presentedScenario = scenario
    }

    /// Archery scenario tap → look up in catalog → present in
    /// ArcheryCallPlayView. Single scenario per push (no auto-advance yet
    /// — Parham hasn't authored that progression).
    private func startArcheryPush(chapter: Chapter, scenarioId: String) {
        guard let scenario = ArcheryScenarioCatalog.scenario(for: scenarioId) else {
            print("[arclab/router] archery scenario not in catalog: \(scenarioId)")
            return
        }
        pushedArcheryChapter = chapter
        pushedArcheryScenario = scenario
    }

    /// Soccer scenario tap → look up in catalog → present in
    /// SoccerCallPlayView. Single scenario per push; each scenario carries
    /// its own Magnus mechanic so the player doesn't bounce through a
    /// level-type picker first.
    private func startSoccerPush(chapter: Chapter, scenarioId: String) {
        guard let scenario = SoccerScenarioCatalog.scenario(for: scenarioId) else {
            print("[arclab/router] soccer scenario not in catalog: \(scenarioId)")
            return
        }
        pushedSoccerChapter = chapter
        pushedSoccerScenario = scenario
    }

    // MARK: - Curriculum lookup

    private func chapters(for sport: Sport) -> [Chapter] {
        sport.chapters  // each Sport returns its own curriculum
    }

    /// Search every sport's curriculum for a chapter id. Used by the route
    /// dispatcher when a deep-link push only carries the chapter id, not
    /// the sport. Both basketball (JSON-backed) and archery (catalog-backed)
    /// chapters live in the same id space.
    private func chapter(withId id: String) -> Chapter? {
        for sport in Sport.allCases where sport.isUnlocked {
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

/// Navigation routes for v2.1.
enum V2Route: Hashable {
    case sportPicker
    case chapterList(Sport)              // shows all chapters for a sport
    case chapter(String)                 // chapterId
}
