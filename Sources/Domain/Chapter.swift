import Foundation

/// A unit of curriculum: one physics insight + its lesson + the scenarios
/// that practice it. Lives inside a sport; ordered by `index`.
///
/// Per CONCEPT_v2.1: chapters are organized by sport, lessons gate first-play,
/// scenarios become free-play after unlock. Each sport gets the number of
/// chapters its physics deserves (basketball is estimated 5–7).
struct Chapter: Identifiable, Hashable, Sendable {
    let id: String          // e.g. "bb-ch1-arc"
    let sport: Sport
    let index: Int          // 1-based display order within sport
    let title: String       // user-visible chapter title
    let subtitle: String    // single-sentence framing
    let lesson: LessonStub
    let scenarioIDs: [String]  // ordered scenarios; v2 convention: index 0 = easy,
                               // 1 = harder, 2 = famous-moment anchor

    /// The one-line poster shown when the user earns MASTERY for this chapter.
    /// Per BASKETBALL_JOURNEY v2 §4 — "Flat shots will look flat to you now,"
    /// "The square is a target. You'll never un-see it," etc. Defaulted to
    /// empty so Parham's Archery v2.2 chapters (which don't define one yet)
    /// still construct.
    var lensReveal: String = ""

    /// v3 §3.7: per-level-type seed pools. Empty dict for chapters that
    /// haven't been migrated to v3 yet — those fall back to `scenarioIDs`
    /// as a Level D-only pool. Ch 1 has all 4 level types populated; Chs 2-5
    /// ship in v3 with Level D only (their lens-specific level types arrive
    /// when the simulation gains spin/fade/bank physics). Defaulted to empty
    /// so non-v3 sports (Archery) still construct.
    var levelTypeSeeds: [LevelTypeID: [String]] = [:]

    /// v2.2 (Parham): optional poster-style background asset shown on
    /// ChapterView. File lives in `Resources/Illustrations/chapters/<name>.png`.
    /// nil falls back to the plain black surface.
    var backgroundImageName: String? = nil

    /// Convenience: the seed pool for a given level type, with sensible
    /// fallback to `scenarioIDs` for Level D when not explicitly populated.
    func seeds(for levelType: LevelTypeID) -> [String] {
        if let pool = levelTypeSeeds[levelType] { return pool }
        if levelType == .findBoth { return scenarioIDs }   // legacy v2 fallback
        return []
    }

    /// v3: true iff this chapter has all 4 Earth level types populated with
    /// seeds. Ch 2-5 currently ship empty `levelTypeSeeds` (locked) per
    /// GAME_v3_LOCKED.md §3.7 — they unlock when the simulator gains the
    /// chapter's physics (spin / fade / bank).
    var isShippableInV3: Bool {
        LevelTypeID.earthChapterTypes.allSatisfy { lt in
            !seeds(for: lt).isEmpty
        }
    }

    /// Basketball's current public chapter flow exposes fixed one-play
    /// practice rows. The broader A/B/C/D seed pools stay authored for
    /// diagnostics and future release work.
    var releasedPracticeLevelTypes: [LevelTypeID] {
        switch sport {
        case .basketball:
            return LevelTypeID.earthChapterTypes.filter { !releasedPracticeSeeds(for: $0).isEmpty }
        case .archery, .soccer, .formula1, .pool:
            return []
        }
    }

    func releasedPracticeSeeds(for levelType: LevelTypeID) -> [String] {
        switch sport {
        case .basketball:
            guard let released = BasketballCurriculum.releasedPracticeSeedsByChapter[id]?[levelType] else { return [] }
            let authored = Set(seeds(for: levelType))
            return released.filter { authored.contains($0) }
        case .archery, .soccer, .formula1:
            return scenarioIDs
        case .pool:
            return []
        }
    }

    /// Scenario IDs that count toward "started/explored" progress today.
    /// Legacy sports use their authored scenario list; basketball uses the
    /// released level-type seed pools instead of the older v2 scenarioIDs.
    var progressScenarioIDs: [String] {
        switch sport {
        case .basketball:
            return releasedPracticeLevelTypes.flatMap { releasedPracticeSeeds(for: $0) }
        case .archery, .soccer, .formula1:
            return scenarioIDs
        case .pool:
            return []
        }
    }

    var hasPlayablePractice: Bool {
        !progressScenarioIDs.isEmpty
    }
}

// LessonStub is a typealias to LessonContent — see LessonContent.swift.
