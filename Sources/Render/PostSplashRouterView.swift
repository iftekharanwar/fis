import SwiftUI

/// Post-splash router. v3 flow:
///   Home → (CONTINUE) → ChapterListView → LevelTypePickerView
///        → [LessonView | PlayView via NextSituationPicker]
///        → SwishView / MissedView / MasteryGateTakeoverView
///   Home → (TODAY hero card) → CallPlayView (call mechanic)
///   Home → (PROFILE row) → ProfileView (sheet)
///
/// First-launch users see V3OnboardingView before Home. SportPicker is
/// auto-skipped when only one sport is unlocked (current v3 ship state).
struct PostSplashRouterView: View {
    @Environment(PlayerProfileStore.self) private var profile

    @State private var navigationPath = NavigationPath()
    /// Daily-card path → CallPlayView (call mechanic, single shot).
    @State private var presentedScenario: ScenarioDefinition?
    /// Tracked alongside `presentedScenario` so CallPlayView's reveal beat
    /// can pull phenomenon + explainer from the originating chapter.
    @State private var presentedChapter: Chapter?
    /// v3 mastery push → PlayView (numpad mechanic, multi-shot loop with
    /// MasteryService writes and CelebrationView queue). Separate from the
    /// daily-card path because the two surfaces are intentionally different.
    @State private var pushedScenario: ScenarioDefinition?
    /// The chapter + level type the player is currently grinding on. Lets
    /// PlayView's "NEXT SHOT" handler re-invoke NextSituationPicker for a
    /// fresh seed in the same level type without popping back to the picker.
    @State private var pushedChapter: Chapter?
    @State private var pushedLevelType: LevelTypeID?
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
                onTapTodayCard: handleTapTodayCard,
                onOpenSport: { sport in navigationPath.append(V2Route.chapterList(sport)) },
                onOpenProfile: { presentedProfile = true }
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
        // v3 mastery push: PlayView (numpad mechanic). On close, if the
        // player is still inside a level-type push (didn't bail to the
        // picker), auto-advance to the next seed via NextSituationPicker.
        // That makes "NEXT SHOT" inside PlayView feel like a continuous
        // session instead of a pop-back-to-picker bounce.
        .fullScreenCover(item: $pushedScenario) { scenario in
            PlayView(
                scenario: scenario,
                onClose: handlePlayViewBail,        // user-initiated bail → picker
                onRequestNext: handlePlayViewNext   // NEXT SHOT → fresh seed in same push
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
                    LevelTypePickerView(
                        chapter: chapter,
                        onSelectLevelType: { lt in
                            startLevelTypePush(chapter: chapter, levelType: lt)
                        },
                        onOpenFamousMoments: {
                            // v3.1 — Famous Moments replay flow. v3 ship: no-op
                            // until the dedicated FamousMomentsView lands.
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
                case .pool:
                    // Locked sports shouldn't reach here, but render an
                    // honest "coming soon" if they do (vs cryptic crash).
                    placeholder("\(chapter.sport.displayName) is coming soon.")
                }
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

    /// When only one sport is unlocked (v3 ship state), skip past the
    /// SportPicker straight to that sport's ChapterListView — saves the
    /// user a redundant tap on a list-of-one. Re-introduces the picker as
    /// soon as a second sport unlocks.
    private func handleContinueTap() {
        let unlockedSports = Sport.allCases.filter(\.isUnlocked)
        if unlockedSports.count == 1, let only = unlockedSports.first {
            navigationPath.append(V2Route.chapterList(only))
        } else {
            navigationPath.append(V2Route.sportPicker)
        }
    }

    private func handleDailyScenarioTap() {
        // v3 §HomeView — daily card now picks player-relevant scenario via
        // DailyScenarioPicker (review-due → active level type → opener),
        // deterministic per-day so the tap delivers exactly what the hero
        // card promised. Server-picked daily + push notify still TBD for
        // a later milestone; the picker is the client-side stand-in.
        let pick = DailyScenarioPicker.pick(
            for: profile.profile,
            chapters: BasketballCurriculum.chapters
        )
        let chapter = BasketballCurriculum.chapters.first(where: { $0.id == pick.chapterId })
        presentScenario(id: pick.scenarioId, in: chapter)
    }

    /// v2.3 Home CONTINUE hero tap. `scenarioId` is non-nil when the chapter
    /// has an authored next-up scenario — present it directly via the call
    /// surface. Nil means "preview": push the chapter view so the player can
    /// see what's coming.
    private func handleTapTodayCard(chapter: Chapter, scenarioId: String?) {
        if let scenarioId {
            presentScenario(id: scenarioId, in: chapter)
        } else {
            navigationPath.append(V2Route.chapter(chapter.id))
        }
    }

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

    /// User explicitly bailed (CLOSE chip or swipe back). Pop to picker.
    private func handlePlayViewBail() {
        pushedScenario = nil
        pushedChapter = nil
        pushedLevelType = nil
    }

    /// User tapped NEXT SHOT after a v3 outcome (or finished celebrations).
    /// Advance to a fresh seed in the same level type — or, if the player
    /// just mastered the current type, promote them to the next unlocked
    /// type so progression FEELS like progression. Pop to picker only when
    /// no further levels exist in the chapter (the celebration screens
    /// already handled the "chapter mastered" beat).
    private func handlePlayViewNext() {
        guard let chapter = pushedChapter, let lt = pushedLevelType else {
            handlePlayViewBail()
            return
        }
        // Did this push just clear mastery on the active level type?
        let key = MasteryService.key(chapterId: chapter.id, levelType: lt)
        let activeStatus = profile.profile.levelTypeMasteries[key]?.status
        let nextLevelType: LevelTypeID? = (activeStatus == .mastered)
            ? nextUnlockedLevelType(after: lt, in: chapter)
            : lt
        pushedScenario = nil
        guard let target = nextLevelType else {
            // Chapter is fully mastered — drop to picker so the player can
            // pick another chapter (or see the chapter-mastery celebration
            // queued from PlayView's outcome write).
            handlePlayViewBail()
            return
        }
        // Re-pick on the next runloop tick so the fullScreenCover finishes
        // its dismiss animation before we present the next seed. SwiftUI
        // rejects simultaneous present-and-dismiss on the same binding.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            startLevelTypePush(chapter: chapter, levelType: target)
        }
    }

    /// Next earth-chapter level type after `current` in A→B→C→D order whose
    /// prerequisites are satisfied. Returns nil if `current` was the last.
    private func nextUnlockedLevelType(after current: LevelTypeID, in chapter: Chapter) -> LevelTypeID? {
        let order = LevelTypeID.earthChapterTypes
        guard let idx = order.firstIndex(of: current), idx + 1 < order.count else { return nil }
        return order[idx + 1]
    }

    /// v3 §3.2 — start a mastery push on a level type. Picks a situation
    /// via NextSituationPicker and presents it in PlayView (the numpad
    /// mechanic, NOT CallPlayView's one-shot call surface). PlayView's
    /// onClose re-invokes this same function so NEXT SHOT serves a fresh
    /// seed without bouncing the player back to the picker.
    private func startLevelTypePush(chapter: Chapter, levelType: LevelTypeID) {
        let seedPool: [LevelTypeID: [String]] = Dictionary(
            uniqueKeysWithValues: LevelTypeID.earthChapterTypes.map { lt in
                (lt, chapter.seeds(for: lt))
            }
        )
        var rng = SystemRandomNumberGenerator()
        guard let pick = NextSituationPicker.nextPick(
            chapterId: chapter.id,
            activeLevelType: levelType,
            seedPool: seedPool,
            masteries: profile.profile.levelTypeMasteries,
            rng: &rng
        ) else { return }
        guard let scenario = try? ScenarioLoader.load(ScenarioID(pick.situationId)) else { return }
        // Remember the active push so handlePlayViewClose can auto-advance.
        pushedChapter = chapter
        pushedLevelType = levelType
        pushedScenario = scenario
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
    case lesson(String, chapterId: String)  // lessonId
}
