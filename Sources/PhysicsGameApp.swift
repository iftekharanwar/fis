import SwiftUI

@main
struct PhysicsGameApp: App {

    @State private var playerProfile = PlayerProfileStore.shared

    @State private var motion = MotionController()

    @State private var spotter = SpotterService()

    @State private var subscription = SubscriptionService()

    @State private var audio = AudioService.shared

    @State private var accessibility = AccessibilitySettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(playerProfile)
                .environment(motion)
                .environment(spotter)
                .environment(subscription)
                .environment(audio)
                .environment(accessibility)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}
