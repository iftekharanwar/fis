import Foundation

/// Picks today's Daily Question. Deterministic per calendar day: every player
/// sees the same question on a given day (it's a shared daily, like a crossword),
/// and it rotates at local midnight. Walks the catalog in order, wrapping every
/// `count` days, so the 30 authored questions cycle cleanly.
enum DailyQuestionPicker {

    /// Index into `questions` for the given day. Uses whole days since the Unix
    /// epoch (in the user's calendar) so the rotation is smooth across month and
    /// year boundaries — no reset.
    static func index(for date: Date, count: Int, calendar: Calendar = .current) -> Int {
        guard count > 0 else { return 0 }
        let startOfDay = calendar.startOfDay(for: date)
        let dayNumber = Int(floor(startOfDay.timeIntervalSince1970 / 86_400))
        return ((dayNumber % count) + count) % count   // always 0..<count, even pre-1970
    }

    /// Today's question from the catalog (or a supplied list, for tests).
    static func todays(
        on date: Date = Date(),
        from questions: [DailyQuestion] = DailyQuestionCatalog.all,
        calendar: Calendar = .current
    ) -> DailyQuestion? {
        guard !questions.isEmpty else { return nil }
        return questions[index(for: date, count: questions.count, calendar: calendar)]
    }

    /// The question to surface for this player right now. The result is
    /// **stable across the act of answering** — critically, answering mutates
    /// the profile, and any view deriving its question from the profile must
    /// not see it swap to a different question mid-session.
    ///
    /// Resolution order:
    ///  1. Already answered today → the *exact* question they answered (by id),
    ///     so re-opening (or a state refresh while the card is up) restores the
    ///     right reveal rather than jumping to a different question.
    ///  2. Brand-new player (never answered any daily) → lead with an
    ///     illustrated **basketball** question — a strong first impression and a
    ///     clean demo.
    ///  3. Otherwise → the normal date-based rotation.
    static func current(
        for profile: PlayerProfile,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyQuestion? {
        if profile.hasAnsweredDailyToday(now: date, calendar: calendar) {
            if let id = profile.lastDailyAnsweredQuestionID,
               let answered = DailyQuestionCatalog.question(withID: id) {
                return answered
            }
            // Pre-id profiles (answered before we persisted the id): fall back
            // to the date rotation so they at least see today's question.
            return todays(on: date, calendar: calendar)
        }
        if profile.lastDailyAnsweredDate == nil,
           let lead = DailyQuestionCatalog.all.first(where: { $0.sport == .basketball && $0.imageName != nil }) {
            return lead
        }
        return todays(on: date, calendar: calendar)
    }
}
