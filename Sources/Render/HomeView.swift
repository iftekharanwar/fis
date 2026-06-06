import SwiftUI

/// v2.3 Home — landing surface after splash.
///
/// Direction: "Continue + Sports". A scrolling surface that fills the screen
/// and surfaces what matters:
/// 1. System header — ARCLAB identity (left) + a progress pill (rank + streak)
///    that opens the profile (right). Identity/momentum is visible up front,
///    not hidden behind a bare PROFILE chip.
/// 2. CONTINUE hero — the user's next unplayed scenario as a full poster card
///    (chapter background image + scrim when available; a typographic surface
///    otherwise). The single strongest element on the page.
/// 3. SPORTS — the five physics domains listed directly. Sports ARE the app's
///    content, so they live on home instead of behind a picker. Each row shows
///    its icon, physics domain, and whether it's playable or coming soon.
///
/// iPad adaptation: the content stays a single scrolling column but caps to
/// a readable max-width and centers on regular-width canvases via
/// `AdaptiveContentContainer`. iPhone is pass-through.
struct HomeView: View {
    @Environment(PlayerProfileStore.self) private var profile

    /// Tap a sport row → that sport's chapter list.
    let onOpenSport: (Sport) -> Void
    let onOpenProfile: () -> Void
    /// Tap the DAILY card → push the Daily Question. Optional so existing
    /// call sites and previews stay valid.
    var onOpenDaily: () -> Void = {}

    /// Drives the one-shot entrance animation (fade + rise) when Home appears.
    @State private var appeared = false

    var body: some View {
        AdaptiveContentContainer(maxWidth: 700) {
            VStack(spacing: 0) {
                header

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        heroCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(.easeOut(duration: 0.45), value: appeared)
                        sportsSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(.easeOut(duration: 0.45).delay(0.1), value: appeared)
                    }
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xxl)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arclabBlack.ignoresSafeArea())
        .onAppear { appeared = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Spacer()
            progressPill
        }
        .frame(minHeight: 44)
    }

    private var progressPill: some View {
        let streak = profile.profile.currentStreak
        return Button(action: onOpenProfile) {
            HStack(spacing: Spacing.xs) {
                Text(profile.profile.rankRung.description)
                    .font(.sfMono(size: 12, weight: .medium))
                    .foregroundColor(.arclabWhite)
                    .tracking(1.5)
                if streak > 0 {
                    Text("·")
                        .font(.sfMono(size: 12))
                        .foregroundColor(.arclabMidGrey)
                    Text("\(streak)D")
                        .font(.sfMono(size: 12, weight: .medium))
                        .foregroundColor(.arclabRimOrange)
                        .tracking(1.5)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 44)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.cornerRadius)
                    .stroke(Color.arclabBorderGrey, lineWidth: Sizing.borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Profile. \(profile.profile.rankRung.description), \(streak) day streak. View your Sports IQ, streak, and badges.")
    }

    // MARK: - Daily hero (the home feed card)

    /// The hero slot now serves the Daily Question — one card, not a new section
    /// stacked on top. Keeps the premium poster look; the copy + CTA switch
    /// between "answer" and the answered "back tomorrow" state.
    private var heroCard: some View {
        let answered = profile.profile.hasAnsweredDailyToday()
        let sportName = DailyQuestionPicker.current(for: profile.profile)?.sport.displayName ?? "TODAY"
        return Button(action: onOpenDaily) {
            ZStack(alignment: .bottomLeading) {
                posterBackground

                // Bottom scrim so the copy stays legible over the backdrop.
                LinearGradient(
                    colors: [Color.arclabBlack.opacity(0), Color.arclabBlack.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(answered ? Color.arclabMidGrey : Color.arclabRimOrange)
                            .frame(width: 4, height: 4)
                        Text(answered ? "DAILY · DONE" : "DAILY · \(sportName)")
                            .font(.sfMono(size: 11))
                            .foregroundColor(.arclabMidGrey)
                            .tracking(2.0)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Text(answered ? "BACK TOMORROW." : "TODAY'S QUESTION.")
                        .font(.anton(size: 40))
                        .foregroundColor(.arclabWhite)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(answered
                         ? "You've called it. Tap to re-read the why and the fun fact."
                         : "One quick call on the physics — 20 seconds.")
                        .font(.barlowCondensed(size: 16, italic: true))
                        .foregroundColor(.arclabWhite.opacity(0.82))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Spacer()
                        Text(answered ? "SEE IT AGAIN  →" : "ANSWER  →")
                            .font(.sfMono(size: 13, weight: .medium))
                            .foregroundColor(answered ? .arclabMidGrey : .arclabRimOrange)
                            .tracking(2.0)
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.md)
            }
            .frame(height: 264)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Sizing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.cardRadius)
                    .stroke(answered ? Color.arclabBorderGrey : Color.arclabRimOrange,
                            lineWidth: Sizing.borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(haptic: .impact(weight: .medium)))
        .accessibilityLabel(answered
            ? "Daily question, answered. Tap to review."
            : "Daily question. Tap to answer.")
    }

    /// Code-drawn hero backdrop — a dark diagonal gradient lifted by a soft amber
    /// glow and a faint trajectory arc, so the card reads as a premium poster
    /// without a photo. The copy sits on the dark bottom-left, clear of both.
    private var posterBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color.arclabSceneBg, Color.arclabCardBlack],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.arclabRimOrange.opacity(0.18), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 300
            )
            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width, h = geo.size.height
                    path.move(to: CGPoint(x: -20, y: h * 0.86))
                    path.addQuadCurve(
                        to: CGPoint(x: w + 20, y: h * 0.5),
                        control: CGPoint(x: w * 0.45, y: h * 0.12)
                    )
                }
                .stroke(Color.arclabWhite.opacity(0.12), lineWidth: 1.5)
            }
        }
    }

    // MARK: - SPORTS

    private var sportsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPORTS")
                .font(.sfMono(size: 12))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)

            VStack(spacing: Spacing.xs) {
                ForEach(Sport.allCases) { sport in
                    sportRow(sport)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sportRow(_ sport: Sport) -> some View {
        let available = !sport.chapters.isEmpty
        let tint: Color = available ? .arclabWhite : .arclabMidGrey
        return Button(action: { if available { onOpenSport(sport) } }) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.md) {
                    Image(systemName: sport.sfSymbolName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(tint)
                        .frame(width: 32, alignment: .center)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sport.displayName)
                            .font(.anton(size: 28))
                            .foregroundColor(tint)
                        Text(sport.physicsDomainSubhead)
                            .font(.sfMono(size: 11))
                            .foregroundColor(.arclabMidGrey)
                            .tracking(1.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer()

                    Text(available ? "→" : "SOON")
                        .font(.sfMono(size: available ? 17 : 11, weight: .medium))
                        .foregroundColor(available ? .arclabRimOrange : .arclabMidGrey)
                        .tracking(available ? 0 : 2.0)
                }

                if available {
                    progressBar(sport)
                }
            }
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.pillRadius, style: .continuous)
                    .stroke(available ? Color.arclabBorderGrey : Color.arclabBorderGrey.opacity(0.5),
                            lineWidth: Sizing.borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!available)
        .accessibilityLabel(sportAccessibilityLabel(sport, available: available))
    }

    /// A thin per-chapter progress track — one segment per chapter, filled amber
    /// once any scenario in that chapter is completed. Mirrors the lesson
    /// progress hairline so the language stays consistent.
    private func progressBar(_ sport: Sport) -> some View {
        let total = max(sport.chapters.count, 1)
        let earned = chaptersEarned(sport)
        return HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < earned ? Color.arclabRimOrange : Color.arclabBorderGrey)
                    .frame(height: 3)
            }
        }
    }

    /// Chapters in this sport with at least one completed released practice item.
    private func chaptersEarned(_ sport: Sport) -> Int {
        sport.chapters.filter { chapter in
            chapter.progressScenarioIDs.contains { profile.profile.completedScenarios[ScenarioID($0)] != nil }
        }.count
    }

    private func sportAccessibilityLabel(_ sport: Sport, available: Bool) -> String {
        guard available else {
            return "\(sport.displayName). \(sport.physicsDomainSubhead). Coming soon."
        }
        return "\(sport.displayName). \(sport.physicsDomainSubhead). \(chaptersEarned(sport)) of \(sport.chapters.count) chapters started. Tap to open."
    }
}

#Preview {
    HomeView(
        onOpenSport: { _ in },
        onOpenProfile: {}
    )
}
