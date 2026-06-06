import SwiftUI

/// First-launch onboarding shown once per fresh install.
struct OnboardingView: View {
    @Environment(PlayerProfileStore.self) private var profile

    let onBegin: () -> Void

    @State private var page: OnboardingPage = .feed
    @State private var appeared: Bool = false

    private var isLastPage: Bool {
        page == OnboardingPage.allCases.last
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

            AdaptiveContentContainer(maxWidth: 640) {
                VStack(spacing: 0) {
                    header

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
            Text("PHISIOS")
                .font(.sfMono(size: 13, weight: .medium))
                .foregroundColor(.arclabWhite)
                .tracking(3.0)
                .lineLimit(1)

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

    private func pageContent(_ item: OnboardingPage) -> some View {
        ZStack {
            OnboardingBackdropImage(imageName: item.imageName)

            OnboardingReadabilityScrim()

            AdaptiveContentContainer(maxWidth: 640) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: Spacing.xs) {
                        Text(item.eyebrow)
                            .font(.sfMono(size: 11, weight: .medium))
                            .foregroundColor(.arclabMidGrey)
                            .tracking(2.3)
                            .lineLimit(1)

                        Text(item.title)
                            .font(.anton(size: 46))
                            .foregroundColor(.arclabWhite)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(item.copy)
                            .font(.barlowCondensed(size: 18, italic: true))
                            .foregroundColor(.arclabMidGrey)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Spacing.xs)
                    }
                    .frame(maxWidth: 460)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, 132)
                    .shadow(color: Color.arclabBlack.opacity(0.75), radius: 14, x: 0, y: 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            pageDots

            HStack(spacing: Spacing.sm) {
                Button(action: previousPage) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(page == .feed ? .arclabBorderGrey : .arclabWhite)
                        .frame(width: Sizing.pillButtonHeight, height: Sizing.pillButtonHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: Sizing.pillRadius)
                                .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(page == .feed)
                .accessibilityLabel("Previous onboarding screen.")

                AccentButton(label: isLastPage ? "Start" : "Next", action: nextAction)
                    .accessibilityLabel(isLastPage ? "Start PHISIOS." : "Next onboarding screen.")
            }
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
}

private struct OnboardingBackdropImage: View {
    let imageName: String

    var body: some View {
        GeometryReader { proxy in
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
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
                    Color.arclabBlack.opacity(0.68),
                    Color.arclabBlack.opacity(0.28),
                    Color.arclabBlack.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)

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

#Preview {
    OnboardingView(onBegin: {})
        .environment(PlayerProfileStore())
}
