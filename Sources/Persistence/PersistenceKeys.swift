import Foundation

/// Centralized UserDefaults keys for scalar app preferences.
enum PersistenceKeys {
    /// True until the app has launched once at all (distinct from first START tap).
    static let firstLaunchEver = "arclab.firstLaunchEver"

    /// v1.1 — Coach Mode (ghost-arc preview, ×0.5 score multiplier). Off by default.
    static let coachModeEnabled = "arclab.v11.coachMode"

    /// v1.1 — Pre-fill last attempt's input values on TRY AGAIN. Off by default.
    static let prefillLastAttempt = "arclab.v11.prefillLastAttempt"

    /// Haptics master switch. Default ON; read by AccessibilitySettings.
    /// (iOS's own System Haptics switch sits outside this as the OS mute.)
    static let hapticsEnabled = "arclab.hapticsEnabled"

    /// In-app Reduce Motion override. Default OFF; OR'd with the system
    /// Reduce Motion setting (AccessibilitySettings.reduceMotionActive).
    static let reduceMotionOverride = "arclab.reduceMotionOverride"

    /// Accessibility — high-legibility text palette (brighter secondary grey,
    /// softened white). Off by default; the iOS "Increase Contrast" system
    /// setting activates the same palette without this override.
    static let highLegibilityEnabled = "arclab.highLegibilityEnabled"

    /// In-app Bold Text override (AccessibilitySettings.boldTextActive).
    static let boldTextEnabled = "arclab.boldTextEnabled"

    /// Game sound master switch. Default ON; read by AudioService.
    static let soundEnabled = "arclab.soundEnabled"
}

/// Property wrapper for typed UserDefaults access from non-View code.
@propertyWrapper
struct PersistedValue<Value: Sendable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults

    init(key: String, default defaultValue: Value, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            (store.object(forKey: key) as? Value) ?? defaultValue
        }
        set {
            store.set(newValue, forKey: key)
        }
    }
}

/// Optional variant — nil means "not set / follow system".
@propertyWrapper
struct OptionalPersistedValue<Value: Sendable> {
    let key: String
    private let store: UserDefaults

    init(key: String, store: UserDefaults = .standard) {
        self.key = key
        self.store = store
    }

    var wrappedValue: Value? {
        get { store.object(forKey: key) as? Value }
        set {
            if let newValue {
                store.set(newValue, forKey: key)
            } else {
                store.removeObject(forKey: key)
            }
        }
    }
}
