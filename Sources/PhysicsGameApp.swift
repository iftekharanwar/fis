import SwiftUI

/// App entry. Mounts the global services at the SwiftUI environment level so
/// every downstream view can read them via `@Environment(ServiceType.self)`.
///
/// **Pattern for adding a new global service** (per SCREENS.md *Global services*):
/// 1. Make it an `@Observable final class`, `@MainActor` if it touches UI state.
/// 2. Hold a `@State` instance on `PhysicsGameApp` so its lifetime is the app's.
/// 3. Add `.environment(service)` to the `WindowGroup`'s root view.
/// 4. Read it in downstream views via `@Environment(ServiceType.self) private var service`.
///
/// We intentionally use `.environment(_:)` (the iOS 17+ `@Observable`-native
/// API) instead of the older `.environmentObject(_:)`. `@Observable` types
/// don't conform to `ObservableObject`, so the legacy modifier doesn't apply.
@main
struct PhysicsGameApp: App {

    /// Global player-profile state. App-lifetime. Synchronous load on init.
    @State private var playerProfile = PlayerProfileStore.shared

    /// Ambient-motion gate per SCREENS.md Global services.
    @State private var motion = MotionController()

    /// SPOTTER calculator state — persistent expression buffer across opens.
    @State private var spotter = SpotterService()

    /// Subscription gate — MVP stub returns .premium for everyone.
    @State private var subscription = SubscriptionService()

    /// Audio engine — preloads SFX at init. Per ASSETS.md §4 / §5.1.
    @State private var audio = AudioService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerProfile)
                .environment(motion)
                .environment(spotter)
                .environment(subscription)
                .environment(audio)
        }
    }
}
