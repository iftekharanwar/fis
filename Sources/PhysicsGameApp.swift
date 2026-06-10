import SwiftUI

@main
struct PhysicsGameApp: App {

    @State private var playerProfile = PlayerProfileStore.shared

    @State private var spotter = SpotterService()

    @State private var subscription = SubscriptionService()

    @State private var audio = AudioService.shared

    @State private var accessibility = AccessibilitySettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerProfile)
                .environment(spotter)
                .environment(subscription)
                .environment(audio)
                .environment(accessibility)
                // Support the full accessibility range (AX1–AX5). Reading
                // surfaces scroll; play/outcome surfaces cap themselves where
                // fixed-frame layout demands it.
                .dynamicTypeSize(...DynamicTypeSize.accessibility5)
        }
    }
}
