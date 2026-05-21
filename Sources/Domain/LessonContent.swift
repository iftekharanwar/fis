import Foundation

/// A lesson is a story — a variable-length sequence of cards. Each card
/// holds one beat: a headline that lands, an optional body line of context,
/// and an optional illustration that gives the beat visual weight. Per the
/// design research, length is content-driven (5–12 cards), not template-fixed.
///
/// Why this shape instead of the previous TERM/PHENOMENON/FORMULA/EXAMPLE
/// quartet: the old shape was textbook-coded. Story-coded cards earn the
/// reader's attention beat-by-beat the way a Wieden+Kennedy poster sequence
/// does, not the way a privacy policy does.
struct LessonContent: Identifiable, Hashable, Sendable {
    let id: String                       // e.g. "bb-l1.1-arc-baseline"
    let title: String                    // user-visible lesson title
    let oneLiner: String                 // shown on the chapter card preview
    let estimatedReadSeconds: Int        // total expected read time

    /// Ordered story beats. Variable length per lesson.
    let cards: [Card]

    /// A single story beat.
    struct Card: Hashable, Sendable {
        /// The headline that lands — Anton, larger, the takeaway.
        let headline: String

        /// Optional body line for context. Barlow Condensed, italic.
        /// Cards can be headline-only when the beat is meant to land hard.
        let body: String?

        /// Optional asset name (in Resources/Illustrations/lessons/).
        /// Cards without illustrations rely on negative space + typography.
        let illustrationName: String?

        /// Optional inline math/formula token, rendered in SF Mono. Used
        /// when the beat IS the equation (the formula-reveal moment).
        let math: String?

        init(
            headline: String,
            body: String? = nil,
            illustration: String? = nil,
            math: String? = nil
        ) {
            self.headline = headline
            self.body = body
            self.illustrationName = illustration
            self.math = math
        }
    }
}

/// Backwards-compat — Chapter.lesson is typed `LessonStub`. Keep the name so
/// nothing breaks; the type now carries the story-card content.
typealias LessonStub = LessonContent
