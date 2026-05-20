import Foundation

/// Centralized UserDefaults keys for scalar app preferences.
enum PersistenceKeys {
    /// True until the app has launched once at all (distinct from first START tap).
    static let firstLaunchEver = "arclab.firstLaunchEver"

    /// v1.1 — Coach Mode (ghost-arc preview, ×0.5 score multiplier). Off by default.
    static let coachModeEnabled = "arclab.v11.coachMode"

    /// v1.1 — Pre-fill last attempt's input values on TRY AGAIN. Off by default.
    static let prefillLastAttempt = "arclab.v11.prefillLastAttempt"

    /// nil = follow system; true/false = explicit override.
    static let hapticsEnabled = "arclab.hapticsEnabled"

    /// nil = follow system; true/false = explicit override.
    static let reduceMotionOverride = "arclab.reduceMotionOverride"
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
