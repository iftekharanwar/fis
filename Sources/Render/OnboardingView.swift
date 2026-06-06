import SwiftUI

/// First-launch onboarding shown once per fresh install.
struct OnboardingView: View {
    @Environment(PlayerProfileStore.self) private var profile

    let onBegin: () -> Void

    @State private var page: OnboardingPage
    @State private var appeared: Bool = false

    init(onBegin: @escaping () -> Void) {
        self.onBegin = onBegin
        self._page = State(initialValue: Self.initialPageFromEnvironment())
    }

    private var isLastPage: Bool {
        page == OnboardingPage.allCases.last
    }

    private static func initialPageFromEnvironment() -> OnboardingPage {
        guard let raw = ProcessInfo.processInfo.environment["ARCLAB_ONBOARDING_PAGE"]?.lowercased() else {
            return .feed
        }
        return OnboardingPage.allCases.first { $0.diagnosticName == raw } ?? .feed
    }

    var body: some View {
        ZStack {
            Color.arclabBlack.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(OnboardingPage.allCases) { item in
                    pageContent(item)
                        .tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeOut(duration: 0.25), value: page)
            .ignoresSafeArea()

            OnboardingBottomBlur()

            AdaptiveContentContainer(maxWidth: 640) {
                VStack(spacing: 0) {
                    header

                    titleBlock(for: page)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.lg)

                    Spacer(minLength: 0)

                    footer
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.easeOut(duration: 0.4), value: appeared)
        }
        .statusBarHidden(false)
        .onAppear { appeared = true }
    }

    private var header: some View {
        HStack {
            Button(action: previousPage) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.arclabWhite)
                    .frame(width: Sizing.minTapTarget, height: Sizing.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(page == .feed)
            .opacity(page == .feed ? 0 : 1)
            .accessibilityLabel("Previous onboarding screen.")

            Spacer()

            if !isLastPage {
                Button(action: handleBegin) {
                    Text("SKIP")
                        .font(.sfMono(size: 12, weight: .medium))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)
                        .frame(minWidth: 52, minHeight: Sizing.minTapTarget, alignment: .trailing)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Skip onboarding.")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .frame(height: 60)
    }

    private func titleBlock(for item: OnboardingPage) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(item.eyebrow)
                .font(.sfMono(size: 11, weight: .medium))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.3)
                .lineLimit(1)

            Text(item.title)
                .font(.anton(size: 40))
                .foregroundColor(.arclabWhite)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.copy)
                .font(.barlowCondensed(size: 18, italic: true))
                .foregroundColor(.arclabWhite.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xs)
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
        .shadow(color: Color.arclabBlack.opacity(0.82), radius: 16, x: 0, y: 7)
        .accessibilityElement(children: .combine)
    }

    private func pageContent(_ item: OnboardingPage) -> some View {
        ZStack {
            OnboardingBackdropImage(imageName: item.imageName)

            OnboardingReadabilityScrim()
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            pageDots

            AccentButton(label: isLastPage ? "Start" : "Next", action: nextAction)
                .accessibilityLabel(isLastPage ? "Start PHISIOS." : "Next onboarding screen.")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xl)
    }

    private var pageDots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(OnboardingPage.allCases) { item in
                Capsule()
                    .fill(item == page ? Color.arclabRimOrange : Color.arclabBorderGrey)
                    .frame(width: item == page ? 28 : 8, height: 4)
                    .animation(.easeOut(duration: 0.2), value: page)
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    private func nextAction() {
        if isLastPage {
            handleBegin()
        } else {
            nextPage()
        }
    }

    private func nextPage() {
        guard let idx = OnboardingPage.allCases.firstIndex(of: page),
              idx + 1 < OnboardingPage.allCases.count else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            page = OnboardingPage.allCases[idx + 1]
        }
    }

    private func previousPage() {
        guard let idx = OnboardingPage.allCases.firstIndex(of: page),
              idx > 0 else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            page = OnboardingPage.allCases[idx - 1]
        }
    }

    private func handleBegin() {
        onBegin()
        profile.mutate { $0.hasSeenOnboarding = true }
    }
}

private enum OnboardingPage: Int, CaseIterable, Identifiable, Hashable {
    case feed
    case sports
    case chapters
    case profile

    var id: Int { rawValue }

    var eyebrow: String {
        switch self {
        case .feed:     return "01 · FEED"
        case .sports:   return "02 · SPORTS"
        case .chapters: return "03 · CHAPTERS"
        case .profile:  return "04 · PROFILE"
        }
    }

    var title: String {
        switch self {
        case .feed:     return "DAILY PLAY."
        case .sports:   return "PICK YOUR GAME."
        case .chapters: return "MOVE THROUGH THE READ."
        case .profile:  return "BUILD YOUR SPORTS IQ."
        }
    }

    var copy: String {
        switch self {
        case .feed:
            return "Call the moment. Then learn why."
        case .sports:
            return "Same physics. Different reads."
        case .chapters:
            return "Each chapter adds one layer."
        case .profile:
            return "Your reads sharpen as you play."
        }
    }

    var imageName: String {
        switch self {
        case .feed:     return "onboarding-feed"
        case .sports:   return "onboarding-sports"
        case .chapters: return "onboarding-chapters"
        case .profile:  return "onboarding-profile"
        }
    }

    var diagnosticName: String {
        switch self {
        case .feed:     return "feed"
        case .sports:   return "sports"
        case .chapters: return "chapters"
        case .profile:  return "profile"
        }
    }
}

private struct OnboardingBackdropImage: View {
    let imageName: String

    var body: some View {
        GeometryReader { proxy in
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(0.80)
                .offset(y: proxy.size.height * 0.24)
        }
        .background(Color.arclabBlack)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct OnboardingReadabilityScrim: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.arclabBlack.opacity(0.96),
                    Color.arclabBlack.opacity(0.86),
                    Color.arclabBlack.opacity(0.48),
                    Color.arclabBlack.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 340)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    Color.arclabBlack.opacity(0),
                    Color.arclabBlack.opacity(0.52),
                    Color.arclabBlack.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct OnboardingBottomBlur: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.arclabBlack.opacity(0.10),
                            Color.arclabBlack.opacity(0.58),
                            Color.arclabBlack.opacity(0.90)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.00),
                            .init(color: .white.opacity(0.78), location: 0.34),
                            .init(color: .white, location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 230)
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingView(onBegin: {})
        .environment(PlayerProfileStore())
}
