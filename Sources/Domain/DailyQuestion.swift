import Foundation

/// One Daily Question — a bite-size, counterintuitive physics prompt tied to a
/// sport. Shown once a day on the Daily card: the user guesses, then the answer
/// reveals with a one-line "why" and a fun fact. Pure value type; the content
/// lives in `DailyQuestionCatalog`.
struct DailyQuestion: Identifiable, Equatable, Sendable {
    let id: String
    /// 1…N authoring order, also the rotation slot.
    let day: Int
    let sport: Sport
    /// Short principle tag, e.g. "Magnus effect". Shown as the eyebrow.
    let principle: String
    let prompt: String
    /// 2–3 answer choices, in display order.
    let options: [String]
    /// Index into `options` of the correct choice.
    let answerIndex: Int
    /// One-line explanation shown on reveal.
    let why: String
    /// One-line "huh, cool" shown on reveal.
    let funFact: String
    /// Asset name in the catalog (Resources/Illustrations/daily/), or nil for a
    /// clean type-only card. Lets us ship before any image is generated.
    let imageName: String?

    func isCorrect(_ pick: Int) -> Bool { pick == answerIndex }
}

extension DailyQuestion {
    /// The option order actually shown to the user — a deterministic per-question
    /// shuffle so the correct answer isn't always in the same slot (the authored
    /// answers were nearly all "B"). Seeded by `day`, so it's stable across app
    /// launches: re-opening an already-answered question shows the same order and
    /// the saved pick still maps to the right option.
    var displayOrder: [Int] {
        var order = Array(options.indices)
        var rng = DQSeededRNG(seed: UInt64(day) &* 2_654_435_761 &+ 1)
        order.shuffle(using: &rng)
        return order
    }

    /// `options` in the shuffled display order.
    var displayOptions: [String] { displayOrder.map { options[$0] } }

    /// Index of the correct answer within `displayOptions`.
    var displayAnswerIndex: Int { displayOrder.firstIndex(of: answerIndex) ?? 0 }

    /// Whether the tapped display position is the correct one.
    func isDisplayPickCorrect(_ position: Int) -> Bool { position == displayAnswerIndex }
}

/// Tiny deterministic RNG so each question's option shuffle is stable across runs.
private struct DQSeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
