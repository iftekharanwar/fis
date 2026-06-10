import SwiftUI
import Observation
import UIKit

/// App-wide accessibility preferences — the single source of truth the color
/// tokens read (see `Color+Tokens.swift`).
///
/// Because every view body resolves tokens through this object, Observation
/// tracking re-renders every visible screen the moment a preference flips —
/// no per-call-site work, the palette swap is global by construction.
///
/// **High Legibility** exists because of player feedback: mid-grey captions
/// sitting next to white text on the black background are hard to read for
/// players with astigmatism (light from bright-on-dark text scatters in the
/// eye and "blooms" — halation). The palette is active when EITHER:
///   - the in-app toggle is on (Settings → Accessibility), or
///   - iOS "Increase Contrast" is enabled (auto-respected, per Apple HIG).
@MainActor
@Observable
final class AccessibilitySettings: NSObject {

    static let shared = AccessibilitySettings()

    /// In-app override — persisted. For players who want the high-legibility
    /// palette without changing system-wide iOS settings.
    var highLegibilityEnabled: Bool {
        didSet { defaults.set(highLegibilityEnabled, forKey: PersistenceKeys.highLegibilityEnabled) }
    }

    /// Mirrors `UIAccessibility.isDarkerSystemColorsEnabled` (iOS Settings →
    /// Accessibility → Display & Text Size → Increase Contrast). Kept fresh
    /// via notification; tests assign it directly to simulate system state.
    var systemIncreaseContrast: Bool

    /// The palette the app actually renders with.
    var highLegibilityActive: Bool { highLegibilityEnabled || systemIncreaseContrast }

    /// In-app Reduce Motion override — persisted. Same contract as High
    /// Legibility: OR'd with the system switch.
    var reduceMotionEnabled: Bool {
        didSet { defaults.set(reduceMotionEnabled, forKey: PersistenceKeys.reduceMotionOverride) }
    }

    /// Mirrors `UIAccessibility.isReduceMotionEnabled`; notification-fresh.
    var systemReduceMotion: Bool

    /// The motion policy the app actually renders with. SwiftUI views read
    /// this live (Observation re-renders them); SpriteKit scenes get it
    /// pushed via `setReduceMotion(_:)` since SKScenes can't observe.
    var reduceMotionActive: Bool { reduceMotionEnabled || systemReduceMotion }

    /// Haptics master switch — persisted, default ON. Threaded through
    /// `PressableButtonStyle` and the `gameHaptic` wrappers (there is no
    /// app-level kill switch for .sensoryFeedback in SwiftUI).
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: PersistenceKeys.hapticsEnabled) }
    }

    /// Mirrors the iOS "Differentiate Without Color" setting. No toggle —
    /// the audit confirmed redundant cues exist everywhere; this is the
    /// hook future color-coded features must consult.
    var systemDifferentiateWithoutColor: Bool

    private let defaults: UserDefaults

    /// Tests pass an isolated `UserDefaults` suite and explicit system flags.
    init(
        defaults: UserDefaults = .standard,
        systemIncreaseContrast: Bool = UIAccessibility.isDarkerSystemColorsEnabled,
        systemReduceMotion: Bool = UIAccessibility.isReduceMotionEnabled,
        systemDifferentiateWithoutColor: Bool = UIAccessibility.shouldDifferentiateWithoutColor
    ) {
        self.defaults = defaults
        self.highLegibilityEnabled = defaults.bool(forKey: PersistenceKeys.highLegibilityEnabled)
        self.reduceMotionEnabled = defaults.bool(forKey: PersistenceKeys.reduceMotionOverride)
        self.hapticsEnabled = (defaults.object(forKey: PersistenceKeys.hapticsEnabled) as? Bool) ?? true
        self.systemIncreaseContrast = systemIncreaseContrast
        self.systemReduceMotion = systemReduceMotion
        self.systemDifferentiateWithoutColor = systemDifferentiateWithoutColor
        super.init()
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(systemContrastDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(systemReduceMotionDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(systemDifferentiateDidChange),
            name: UIAccessibility.differentiateWithoutColorDidChangeNotification,
            object: nil
        )
    }

    /// UIAccessibility status notifications post on the main thread.
    @objc private func systemContrastDidChange() {
        systemIncreaseContrast = UIAccessibility.isDarkerSystemColorsEnabled
    }

    @objc private func systemReduceMotionDidChange() {
        systemReduceMotion = UIAccessibility.isReduceMotionEnabled
    }

    @objc private func systemDifferentiateDidChange() {
        systemDifferentiateWithoutColor = UIAccessibility.shouldDifferentiateWithoutColor
    }
}
