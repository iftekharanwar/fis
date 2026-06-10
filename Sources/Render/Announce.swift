import SwiftUI
import Accessibility

/// VoiceOver announcement helper — the single throat for game-beat speech,
/// mirroring `AccessibilitySettings` as the single throat for palette state.
///
/// Every result reveal in the app is an in-place ZStack swap (phase enums,
/// `revealed` flags), not a presentation — so VoiceOver gets no screen-changed
/// event and a blind player would have to re-scrub the screen after every
/// beat. Posting an announcement at each transition closes that gap
/// (WCAG 4.1.3 Status Messages).
///
/// Announcements post from wherever the copy already lives (verdict views,
/// reveal overlays) so spoken strings can never drift from what's on screen.
@MainActor
enum Announce {

    enum Priority {
        /// Interrupts in-progress speech — verdicts, phase beats.
        case high
        /// Waits its turn — reveal cards, XP lines that follow a verdict.
        case queued
    }

    /// Test seam: tests swap this closure to capture (message, priority)
    /// pairs instead of talking to VoiceOver.
    static var poster: (String, Priority) -> Void = { message, priority in
        var text = AttributedString(message)
        text.accessibilitySpeechAnnouncementPriority = (priority == .high) ? .high : .default
        AccessibilityNotification.Announcement(text).post()
    }

    static func post(_ message: String, priority: Priority = .high) {
        poster(message, priority)
    }
}

extension View {
    /// Announce when this view appears — for in-place ZStack swaps that
    /// VoiceOver never sees as screen changes. The message closure is
    /// evaluated at appear time so it can read final (non-animated) state.
    func announceOnAppear(
        priority: Announce.Priority = .high,
        _ message: @escaping () -> String
    ) -> some View {
        onAppear { Announce.post(message(), priority: priority) }
    }
}
