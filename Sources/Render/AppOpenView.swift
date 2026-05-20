import SwiftUI

/// Cold-start splash screen.
struct AppOpenView: View {

    @State private var loadComplete = false
    @State private var showProgressSliver = false
    @State private var loadFailed = false
    @State private var capReached = false

    @State private var sliverTask: Task<Void, Never>?
    @State private var capTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if loadComplete && capReached {
                PostSplashRouterView()
                    .transition(.opacity)
            } else {
                splash
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: loadComplete && capReached)
        .background(Color.arclabBlack.ignoresSafeArea())
        .onAppear(perform: startSplashTimers)
        .onDisappear {
            sliverTask?.cancel()
            capTask?.cancel()
            loadTask?.cancel()
        }
    }

    private var splash: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("ARCLAB")
                .font(.anton(size: 96))
                .foregroundColor(.arclabWhite)
                .tracking(2)
                .dynamicTypeSize(.large ... .accessibility1)

            Spacer().frame(height: Spacing.md)

            Rectangle()
                .fill(Color.arclabBorderGrey)
                .frame(width: 1, height: 24)

            Spacer().frame(height: Spacing.sm)

            Text(loadFailed ? "NO SIGNAL. TAP TO RETRY." : "LOADING")
                .font(.sfMono(size: 11, weight: .regular))
                .foregroundColor(.arclabMidGrey)
                .tracking(1.1)
                .accessibilityLabel(loadFailed ? "Offline. Tap to retry loading." : "Loading.")

            Spacer()

            if showProgressSliver && !loadComplete {
                ProgressSliver()
                    .padding(.horizontal, Spacing.xxl)
                    .padding(.bottom, Spacing.xxl)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if loadFailed { retryLoad() } }
    }

    private func startSplashTimers() {
        loadComplete = false
        showProgressSliver = false
        loadFailed = false
        capReached = false

        sliverTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, !loadComplete else { return }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) { showProgressSliver = true }
            }
        }

        // Min 900ms dwell so the brand mark reads; 250ms was too quick.
        capTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            await MainActor.run { capReached = true }
        }

        loadTask = Task {
            await MainActor.run { loadComplete = true }
        }

        // Absolute 1500ms cap — if anything hangs, transition anyway.
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if !loadComplete { loadComplete = true }
                if !capReached { capReached = true }
            }
        }
    }

    private func retryLoad() {
        loadFailed = false
        startSplashTimers()
    }
}

/// 2pt bar that fills left-to-right over 1.5s; signals "still working" on slow splash.
private struct ProgressSliver: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.arclabBorderGrey)
                    .frame(height: 2)
                Rectangle()
                    .fill(Color.arclabWhite)
                    .frame(width: geo.size.width * progress, height: 2)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5)) { progress = 1.0 }
            }
        }
        .frame(height: 2)
    }
}

#Preview("APP OPEN — default") {
    AppOpenView()
}
