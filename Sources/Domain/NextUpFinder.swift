import Foundation

/// What the user should encounter next on the home surface.
///
/// `scenarioId == nil` means the chapter has no playable scenarios yet
/// (authoring placeholder) — the UI should surface the chapter itself
/// rather than jumping straight into a play beat.
struct NextUp: Equatable, Sendable {
    let chapter: Chapter
    let scenarioId: String?
}

/// Computes the "next thing to do" given the curriculum and the player's
/// completed scenarios. Walks chapters in order; returns the first released
/// practice item the user hasn't completed. If every released item is done,
/// surfaces the next placeholder chapter so the user has somewhere to land.
enum NextUpFinder {
    static func compute(
        chapters: [Chapter],
        completed: [ScenarioID: ScenarioRecord]
    ) -> NextUp? {
        guard !chapters.isEmpty else { return nil }

        for chapter in chapters {
            for scenarioId in chapter.progressScenarioIDs
            where completed[ScenarioID(scenarioId)] == nil {
                return NextUp(chapter: chapter, scenarioId: scenarioId)
            }
        }

        // Every authored scenario is done. Prefer the first placeholder
        // chapter so the user sees "next up — coming soon" rather than
        // bouncing back to a chapter they've already cleared.
        if let placeholder = chapters.first(where: { !$0.hasPlayablePractice }) {
            return NextUp(chapter: placeholder, scenarioId: nil)
        }

        return chapters.last.map { NextUp(chapter: $0, scenarioId: nil) }
    }
}
