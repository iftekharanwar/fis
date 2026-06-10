import SwiftUI
import UIKit

/// Cold-start splash — "Warm Horizon".
///
/// A warm amber glow rises from below like a light source; the PHISIOS
/// wordmark lifts up into it catching a warm rim, and a thin orange hairline
/// grows beneath. Depth comes from the bottom radial glow over pure black plus
/// a faint film-grain overlay. The reveal is eased (cinematic) but kept brisk,
/// so the minimum dwell is ~1.25s — long enough for the animation to complete
/// and breathe before the cross-fade to Home, without dragging.
struct AppOpenView: View {
    @Environment(AccessibilitySettings.self) private var accessibility

    @State private var loadComplete = false
    @State private var loadFailed = false
    @State private var capReached = false
    /// Drives the staged reveal (wordmark rise, rule grow, glow bloom).
    @State private var revealed = false

    /// Reduce Motion: the splash becomes a pure cross-fade — rise offsets
    /// and the bloom scale pin to their settled values, opacity fades stay.
    private var reduceMotion: Bool { accessibility.reduceMotionActive }

    @State private var capTask: Task<Void, Never>?
    @State private var loadTask: Task<Void, Never>?
    @State private var hangTask: Task<Void, Never>?

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.25), value: loadComplete && capReached)
        .background(Color.arclabBlack.ignoresSafeArea())
        .onAppear(perform: startSplash)
        .onDisappear {
            capTask?.cancel()
            loadTask?.cancel()
            hangTask?.cancel()
        }
    }

    // MARK: - Splash

    private var splash: some View {
        ZStack {
            Color.arclabBlack.ignoresSafeArea()
            warmHorizon
            grain

            VStack(spacing: 0) {
                Text("PHISIOS")
                    .font(.anton(size: 96))
                    .foregroundColor(.arclabWhite)
                    .tracking(2)
                    .dynamicTypeSize(.large ... .accessibility1)
                    // Warm rim — the wordmark "catches" the light it rose into.
                    .shadow(color: Color.arclabRimOrange.opacity(revealed ? 0.35 : 0),
                            radius: 22, x: 0, y: 6)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed || reduceMotion ? 0 : 22)
                    .animation(.timingCurve(0.16, 0.8, 0.24, 1, duration: 0.72), value: revealed)

                // Thin orange hairline that grows in after the wordmark settles.
                LinearGradient(
                    colors: [.clear, .arclabRimOrange, .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: revealed || reduceMotion ? 150 : 0, height: 2)
                .opacity(revealed ? 1 : 0)
                .padding(.top, Spacing.lg)
                .animation(.easeOut(duration: 0.44).delay(0.28), value: revealed)

                Text(loadFailed ? "NO SIGNAL. TAP TO RETRY." : "PHYSICS YOU CAN FEEL")
                    .font(.sfMono(size: 11, weight: loadFailed ? .medium : .regular))
                    .foregroundColor(loadFailed ? .arclabWhite : .arclabMidGrey)
                    .tracking(2.0)
                    .padding(.top, Spacing.lg)
                    .opacity(revealed ? 1 : 0)
                    .animation(.easeOut(duration: 0.34).delay(0.42), value: revealed)
                    .accessibilityLabel(loadFailed ? "Offline. Tap to retry loading." : "Loading.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if loadFailed { retry() } }
        // Only a button while there's actually something to do — the retry.
        .accessibilityAddTraits(loadFailed ? .isButton : [])
        .accessibilityAction { if loadFailed { retry() } }
    }

    /// Warm amber light rising from below the bottom edge. Widened into a soft
    /// ellipse and bloomed in (opacity + slight scale) on reveal.
    private var warmHorizon: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.arclabRimOrange.opacity(0.55), location: 0.0),
                            .init(color: Color.arclabRimOrange.opacity(0.26), location: 0.18),
                            .init(color: Color.arclabRimOrange.opacity(0.08), location: 0.38),
                            .init(color: .clear, location: 0.60),
                        ]),
                        center: UnitPoint(x: 0.5, y: 1.06),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.72
                    )
                )
                .scaleEffect(x: 1.3, y: 1.0, anchor: .bottom)
                .scaleEffect(revealed || reduceMotion ? 1.0 : 0.9, anchor: .bottom)
                .opacity(revealed ? 1 : 0)
                .animation(.easeOut(duration: 0.68), value: revealed)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Faint additive film grain for filmic texture over the near-black ground.
    private var grain: some View {
        Image(uiImage: phisiosGrain)
            .resizable(resizingMode: .tile)
            .opacity(0.035)
            .blendMode(.plusLighter)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    // MARK: - Timing

    private func startSplash() {
        loadComplete = false
        loadFailed = false
        capReached = false
        revealed = false

        // Kick the staged reveal on the next tick so the from-state renders
        // first and the eased animations actually play.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            revealed = true
        }

        // v1 bundles all assets, so "load" is effectively instant.
        loadTask = Task { @MainActor in loadComplete = true }

        // Min dwell so the reveal (~0.75s) completes and breathes before the fade.
        capTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1250))
            guard !Task.isCancelled else { return }
            capReached = true
        }

        // Absolute cap — if anything ever hangs, transition anyway.
        hangTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1950))
            guard !Task.isCancelled else { return }
            if !loadComplete { loadComplete = true }
            if !capReached { capReached = true }
        }
    }

    private func retry() {
        loadFailed = false
        startSplash()
    }
}

/// One-time grayscale noise tile for the splash film grain. Deterministic
/// (seeded LCG) so it's stable across launches and never flickers.
private let phisiosGrain: UIImage = {
    let size = 128
    var px = [UInt8](repeating: 0, count: size * size * 4)
    var s: UInt64 = 0x9E37_79B9_7F4A_7C15
    for i in 0..<(size * size) {
        s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let v = UInt8(truncatingIfNeeded: s >> 40)
        px[i * 4 + 0] = v
        px[i * 4 + 1] = v
        px[i * 4 + 2] = v
        px[i * 4 + 3] = 255
    }
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: &px, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let cg = ctx.makeImage() else {
        return UIImage()
    }
    return UIImage(cgImage: cg)
}()

#Preview("APP OPEN — Warm Horizon") {
    AppOpenView()
}
