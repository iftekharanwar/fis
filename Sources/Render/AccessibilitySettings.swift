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

    private let defaults: UserDefaults

    /// Tests pass an isolated `UserDefaults` suite and an explicit system flag.
    init(
        defaults: UserDefaults = .standard,
        systemIncreaseContrast: Bool = UIAccessibility.isDarkerSystemColorsEnabled
    ) {
        self.defaults = defaults
        self.highLegibilityEnabled = defaults.bool(forKey: PersistenceKeys.highLegibilityEnabled)
        self.systemIncreaseContrast = systemIncreaseContrast
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemContrastDidChange),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
    }

    /// UIAccessibility status notifications post on the main thread.
    @objc private func systemContrastDidChange() {
        systemIncreaseContrast = UIAccessibility.isDarkerSystemColorsEnabled
    }
}
