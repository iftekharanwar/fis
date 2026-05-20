import SwiftUI

/// First-launch onboarding shown once per fresh install.
struct OnboardingView: View {
    @Environment(PlayerProfileStore.self) private var profile

    let onBegin: () -> Void

    @State private var verbVisible: Bool = false

    var body: some View {
        ZStack {
            Color.arclabBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Spacing.xxl)

                Text("ARCLAB")
                    .font(.sfMono(size: 14, weight: .medium))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(3.2)
                    .opacity(verbVisible ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: verbVisible)

                Spacer()

                // Each line as its own Text so the wrap is intentional, not OS-driven.
                VStack(alignment: .leading, spacing: 0) {
                    Text("CATCH")
                        .font(.anton(size: 88))
                        .foregroundColor(.arclabWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("PHYSICS")
                        .font(.anton(size: 88))
                        .foregroundColor(.arclabWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("IN SPORTS.")
                        .font(.anton(size: 88))
                        .foregroundColor(.arclabWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .opacity(verbVisible ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8).delay(0.5), value: verbVisible)

                Spacer().frame(height: Spacing.md)

                Rectangle()
                    .fill(Color.arclabWhite)
                    .frame(width: 24, height: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .opacity(verbVisible ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.4).delay(0.9), value: verbVisible)

                Spacer().frame(height: Spacing.sm)

                Text("Compute the physics. Watch the world respond.")
                    .font(.barlowCondensed(size: 16, italic: true))
                    .foregroundColor(.arclabMidGrey)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .opacity(verbVisible ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.4).delay(1.0), value: verbVisible)

                Spacer()

                Button(action: handleBegin) {
                    Text("BEGIN")
                        .font(.sfMono(size: 16, weight: .medium))
                        .foregroundColor(.arclabWhite)
                        .tracking(3.2)
                        .frame(maxWidth: .infinity)
                        .frame(height: Sizing.pillButtonHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                                .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xxl)
                .opacity(verbVisible ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(1.2), value: verbVisible)
                .sensoryFeedback(.impact(weight: .heavy), trigger: beginTapCount)
                .accessibilityLabel("Begin. Open the sport picker.")
            }
        }
        .statusBarHidden(false)
        .onAppear {
            verbVisible = true
        }
    }

    @State private var beginTapCount: Int = 0

    private func handleBegin() {
        beginTapCount += 1
        profile.mutate { $0.hasSeenOnboarding = true }
        onBegin()
    }
}
