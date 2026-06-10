import SwiftUI

/// App root. Set `ARCLAB_LAUNCH_TO=<screen>` in the scheme to jump directly to a screen for screenshots.
struct RootView: View {
    @Environment(PlayerProfileStore.self) private var profile

    var body: some View {
        Group {
            if let target = ProcessInfo.processInfo.environment["ARCLAB_LAUNCH_TO"] {
                diagnosticLaunch(target: target)
            } else {
                AppOpenView()
            }
        }
        .onAppear { applyMasteryDecayOnce() }
    }

    /// v3 §4 — Ebbinghaus decay. Mastered level types untouched for 14+ days
    /// get demoted to .inReview so the next session serves a refresher.
    /// Idempotent + fast — pure profile mutation over a small dict.
    @State private var decayApplied: Bool = false
    private func applyMasteryDecayOnce() {
        guard !decayApplied else { return }
        decayApplied = true
        profile.mutate { p in
            MasteryService.applyDecay(to: &p)
        }
    }

    @ViewBuilder
    private func diagnosticLaunch(target: String) -> some View {
        switch target {
        case "onboarding":
            OnboardingView(onBegin: {})
        case "sportpicker":
            SportPickerView(onSelect: { _ in })
        case "play":
            if let scenario = try? ScenarioLoader.load("bb-1-baseline") {
                PlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "play-a":
            // v3 diagnostic: NUMPAD_SINGLE_THETA — Level Type A (find θ).
            if let scenario = try? ScenarioLoader.load("bb-a-freethrow") {
                PlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "play-a-logo":
            // v3 diagnostic: Level A logo three (deep distance, high arc).
            if let scenario = try? ScenarioLoader.load("bb-a-logo") {
                PlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "play-a-ugly":
            // v3 diagnostic: Level A hard-bucket seed. Use to test Level A mastery promotion.
            if let scenario = try? ScenarioLoader.load("bb-a-ugly-1") {
                PlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "play-b":
            // v3 diagnostic: NUMPAD_SINGLE_V — Level Type B (find v).
            if let scenario = try? ScenarioLoader.load("bb-b-freethrow") {
                PlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "play-c":
            // v3 diagnostic: NUMPAD_SINGLE_D — Level Type C (find d / "pick the spot").
            if let scenario = try? ScenarioLoader.load("bb-c-freethrow") {
                PlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "play-c-floater":
            // v3 diagnostic: Level C high-arc floater.
            if let scenario = try? ScenarioLoader.load("bb-c-high-floater") {
                PlayView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "leveltypes":
            // v3 diagnostic: the new Level Type picker for Ch 1.
            // Wraps the natural router so onSelectLevelType actually fires
            // NextSituationPicker → PlayView (for natural-flow verification).
            DiagnosticLevelTypePickerWrapper(
                chapter: BasketballCurriculum.chapters[0]
            )
        case "pickspot":
            // PROTOTYPE — Level C pick-the-spot beat. ARCLAB_SCENARIO picks
            // the scenario (defaults to the wing throw).
            let spotId = ProcessInfo.processInfo.environment["ARCLAB_SCENARIO"] ?? "bb-c-wing-throw"
            if let scenario = try? ScenarioLoader.load(ScenarioID(spotId)) {
                PickSpotView(scenario: scenario, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "chapter-bb1":
            // Wave verification: Ch 1's chapter screen with its released
            // practice rows (requires the lesson marked read in the profile).
            ChapterView(
                chapter: BasketballCurriculum.chapters[0],
                onOpenScenario: { _ in }
            )
        case "chapterlist":
            // v3 diagnostic: the chapter list for Basketball (showing lock states).
            ChapterListView(
                sport: .basketball,
                chapters: BasketballCurriculum.chapters,
                onSelectChapter: { _ in }
            )
        case "chapterlist-archery":
            // v2.2 diagnostic: chapter list for Archery (Parham's curriculum).
            ChapterListView(
                sport: .archery,
                chapters: ArcheryCurriculum.chapters,
                onSelectChapter: { _ in }
            )
        case "mastery-a":
            // v3 diagnostic: takeover after Level Type A clears.
            CelebrationView(celebration: .levelType(.findTheta), onTap: {})
        case "mastery-d":
            // v3 diagnostic: takeover after Level Type D clears.
            CelebrationView(celebration: .levelType(.findBoth), onTap: {})
        case "celebrate-chapter":
            // v3 diagnostic: chapter MASTERY lens-reveal (Ch 1).
            CelebrationView(
                celebration: .chapterMastery(chapter: BasketballCurriculum.chapters[0]),
                onTap: {}
            )
        case "solution":
            if let scenario = try? ScenarioLoader.load("bb-1-baseline") {
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
                onOpenSport: { _ in },
                onOpenProfile: {}
            )
        case "lesson":
            LessonView(
                lesson: BasketballCurriculum.chapters[0].lesson,
                onCompleted: {}
            )
        case "callverdict-wrong":
            // v3 playtest: verify CallVerdictView voice fix for the worst
            // case (called NO, ball went IN — the "you were wrong" path).
            CallVerdictView(wasCorrect: false, ballWentIn: true)
        case "callverdict-right":
            // The "you called it right and it went in" success path.
            CallVerdictView(wasCorrect: true, ballWentIn: true)
        case "callplay":
            // Optional ARCLAB_SCENARIO picks any bundled scenario so content
            // releases can be eyeballed on the call surface before shipping.
            // The chapter is resolved from the scenario's chapterId so the
            // reveal beat matches what shipping navigation shows.
            let scenarioId = ProcessInfo.processInfo.environment["ARCLAB_SCENARIO"] ?? "bb-1-baseline"
            if let scenario = try? ScenarioLoader.load(ScenarioID(scenarioId)) {
                let chapter = Sport.basketball.chapters.first { $0.id == scenario.meta.chapterId }
                CallPlayView(scenario: scenario, chapter: chapter, onClose: {})
            } else {
                Color.arclabBlack
            }
        case "archeryplay":
            // Archery call surface (Parham's v2.2). Pin-gap scenario.
            if let scenario = ArcheryScenarioCatalog.scenario(for: "arc-pingap-001") {
                ArcheryCallPlayView(
                    scenario: scenario,
                    chapter: ArcheryCurriculum.chapters.first,
                    onClose: {}
                )
            } else {
                Color.arclabBlack
            }
        case "profile":
            ProfileView()
        case "settings":
            SettingsView()
        case "dailyquestion":
            // Daily Question — one bite-size physics question a day.
            DailyQuestionView(onClose: {})
        default:
            AppOpenView()
        }
    }
}

#Preview {
    RootView()
}

/// Legacy v3 playtest harness for the level-type picker. Normal basketball
/// navigation no longer uses this route, but the `leveltypes` diagnostic still
/// exercises NextSituationPicker → PlayView from a single env-var launch.
struct DiagnosticLevelTypePickerWrapper: View {
    @Environment(PlayerProfileStore.self) private var profile

    let chapter: Chapter
    @State private var presentedScenario: ScenarioDefinition?

    var body: some View {
        LevelTypePickerView(
            chapter: chapter,
            onSelectLevelType: { lt in
                startLevelTypePush(levelType: lt)
            },
            onOpenFamousMoments: {}
        )
        .fullScreenCover(item: $presentedScenario) { scenario in
            PlayView(scenario: scenario, onClose: { presentedScenario = nil })
        }
    }

    /// Diagnostic picker path: pick via NextSituationPicker and present PlayView.
    private func startLevelTypePush(levelType: LevelTypeID) {
        let seedPool: [LevelTypeID: [String]] = Dictionary(
            uniqueKeysWithValues: LevelTypeID.earthChapterTypes.map { lt in
                (lt, chapter.releasedPracticeSeeds(for: lt))
            }
        )
        let difficultyBySituation = difficultyMap(for: seedPool)
        var rng = SystemRandomNumberGenerator()
        let attempts = profile.profile.levelTypeMasteries[
            MasteryService.key(chapterId: chapter.id, levelType: levelType)
        ]?.attemptHistory.count ?? 0
        print("[arclab/diag] startLevelTypePush chapterId=\(chapter.id) lt=\(levelType.rawValue) attempts=\(attempts)")
        guard let pick = NextSituationPicker.nextPick(
            chapterId: chapter.id,
            activeLevelType: levelType,
            seedPool: seedPool,
            masteries: profile.profile.levelTypeMasteries,
            difficultyBySituation: difficultyBySituation,
            rng: &rng
        ) else {
            print("[arclab/diag] pick=nil")
            return
        }
        print("[arclab/diag] picked=\(pick.situationId) interleaved=\(pick.isInterleaved)")
        guard let scenario = try? ScenarioLoader.load(ScenarioID(pick.situationId)) else {
            print("[arclab/diag] scenario load failed for \(pick.situationId)")
            return
        }
        presentedScenario = scenario
    }

    private func difficultyMap(for seedPool: [LevelTypeID: [String]]) -> [String: DifficultyBucket] {
        var map: [String: DifficultyBucket] = [:]
        for scenarioId in seedPool.values.flatMap({ $0 }) {
            guard let scenario = try? ScenarioLoader.load(ScenarioID(scenarioId)),
                  let bucket = scenario.meta.difficultyBucket else { continue }
            map[scenarioId] = bucket
        }
        return map
    }
}
