import Foundation

/// A unit of curriculum: one physics insight + its lesson + the scenarios
/// that practice it. Lives inside a sport; ordered by `index`.
///
/// Per CONCEPT_v2.1: chapters are organized by sport, lessons gate first-play,
/// scenarios become free-play after unlock. Each sport gets the number of
/// chapters its physics deserves (basketball is estimated 5–7).
struct Chapter: Identifiable, Hashable, Sendable {
    let id: String          // e.g. "bb-ch1-projectile"
    let sport: Sport
    let index: Int          // 1-based display order within sport
    let title: String       // user-visible chapter title
    let subtitle: String    // single-sentence framing
    let lesson: LessonStub
    let scenarioIDs: [String]  // ordered scenarios in this chapter; map to JSON ids

    /// Optional poster-style background image asset shown on ChapterView.
    /// File lives in `Resources/Illustrations/chapters/<name>.png`. Each
    /// chapter gets its own visual identity here; nil falls back to the
    /// plain black surface.
    var backgroundImageName: String? = nil
}

// LessonStub is a typealias to LessonContent — see LessonContent.swift.
