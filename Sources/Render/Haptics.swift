import SwiftUI
import UIKit

/// The haptics gate. SwiftUI has no app-level kill switch for
/// `.sensoryFeedback`, so every haptic routes through one of three choke
/// points that consult `AccessibilitySettings.hapticsEnabled`:
///   1. `PressableButtonStyle` (Buttons.swift) — all button-press ticks;
///   2. `View.gameHaptic(...)` below — the event haptics (verdicts,
///      releases, reveals) that used raw `.sensoryFeedback`;
///   3. `Haptics.softTick()` — the lesson readers' UIKit generator taps.
///
/// Review gate: no raw `.sensoryFeedback(` outside Buttons.swift + this file.
@MainActor
enum Haptics {
    /// Lesson-reader page tick (replaces raw `UIImpactFeedbackGenerator`).
    static func softTick() {
        guard AccessibilitySettings.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

extension View {
    /// `.sensoryFeedback` gated by the in-app haptics switch. The Bool is
    /// captured at body time (MainActor); Observation re-evaluates the view
    /// when the toggle flips, refreshing the capture.
    @MainActor
    func gameHaptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        let on = AccessibilitySettings.shared.hapticsEnabled
        return sensoryFeedback(feedback, trigger: trigger) { _, _ in on }
    }

    /// Condition-overload variant for call sites that already gated on
    /// their own predicate (enabled-state forks etc.).
    @MainActor
    func gameHaptic<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T,
        condition: @escaping (T, T) -> Bool
    ) -> some View {
        let on = AccessibilitySettings.shared.hapticsEnabled
        return sensoryFeedback(feedback, trigger: trigger) { old, new in
            on && condition(old, new)
        }
    }

    /// Feedback-providing variant (the closure picks the haptic per event).
    @MainActor
    func gameHaptic<T: Equatable>(
        trigger: T,
        _ feedback: @escaping (T, T) -> SensoryFeedback?
    ) -> some View {
        let on = AccessibilitySettings.shared.hapticsEnabled
        return sensoryFeedback(trigger: trigger) { old, new in
            on ? feedback(old, new) : nil
        }
    }
}
