import SwiftUI

/// Interactive pop gesture for screens presented as `.fullScreenCover`.
///
/// iOS only ships the interactive pop on `NavigationStack` pushes (left-edge
/// swipe) and the swipe-down on `.sheet`. Full-screen covers get neither, so
/// the user has no edge-gesture habit available — they have to find the
/// explicit CLOSE chip every time.
///
/// This modifier rebuilds that habit. Content tracks the finger live —
/// translates horizontally for the edge-swipe-right and vertically for the
/// swipe-down — and on release either commits (dismiss) or springs back to
/// origin. The threshold is "30% of travel distance or a flick" to match
/// UIKit's interactive-presentation heuristic.
///
/// Critical layout note: this modifier MUST NOT wrap content in a
/// GeometryReader at the root, because that collapses cover content that
/// depends on intrinsic full-bleed expansion (SpriteView, ZStack with
/// .ignoresSafeArea backgrounds). Instead it reads the content's own resolved
/// size via a *background* GeometryReader (which matches the content's size
/// without constraining it) — correct in any orientation / Split View, unlike
/// the deprecated `UIScreen.main.bounds`. Content gets a plain `.offset` that
/// respects its own layout.
///
/// Gate dismissal with `isEnabled`: e.g. set `false` during a mid-flight
/// action phase so the user can't accidentally swipe away in-progress work.
struct SwipeBackToDismiss: ViewModifier {
    let isEnabled: Bool
    let onDismiss: () -> Void

    /// Live translation tracked from .onChanged so the content follows the
    /// finger. Reset to .zero on release or when isEnabled flips false.
    @State private var dragOffset: CGSize = .zero

    /// Which axis the user committed to on first non-trivial drag. Locks the
    /// gesture to one axis so a slight diagonal doesn't bleed both ways.
    @State private var axis: DragAxis? = nil

    /// The content's own resolved size, read via a background GeometryReader.
    /// Used as the commit-threshold reference so the gesture works correctly in
    /// landscape and Split View (where `UIScreen.main.bounds` lies).
    @State private var contentSize: CGSize = .zero

    private enum DragAxis { case horizontal, vertical }

    /// 30% of screen size in either axis is the commit threshold — matches
    /// UIKit's interactive-pop habit. A meaningful flick (predicted travel
    /// 500pt+ past current position) commits regardless of where you stop.
    private let commitFraction: CGFloat = 0.30
    private let flickPredictedExtra: CGFloat = 500

    func body(content: Content) -> some View {
        content
            // Live translation: only show non-zero offset along the locked axis.
            // Both clamps to >= 0 so the pop is right-only / dismiss is down-only.
            .offset(x: max(0, dragOffset.width),
                    y: max(0, dragOffset.height))
            .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.85),
                       value: dragOffset)
            // Read the content's resolved size without constraining it.
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contentSize = proxy.size }
                        .onChange(of: proxy.size) { _, newValue in contentSize = newValue }
                }
            )
            .simultaneousGesture(dragGesture, including: isEnabled ? .all : .subviews)
            .onChange(of: isEnabled) { _, newValue in
                if !newValue {
                    // Reset any in-progress drag if gesture gets disabled
                    // mid-swipe (e.g. action phase started).
                    dragOffset = .zero
                    axis = nil
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                // First non-trivial change locks the axis. From there only
                // one axis can grow — keeps the diagonal-swipe case sane.
                if axis == nil {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    // Edge-swipe-right only originates near the leading edge
                    // (first 40pt). Anywhere else, only swipe-down counts.
                    let nearLeadingEdge = value.startLocation.x < 40
                    if dx > dy, nearLeadingEdge, value.translation.width > 0 {
                        axis = .horizontal
                    } else if dy > dx, value.translation.height > 0 {
                        axis = .vertical
                    } else {
                        return  // ambiguous / wrong direction — ignore
                    }
                }
                switch axis {
                case .horizontal:
                    dragOffset = CGSize(width: max(0, value.translation.width),
                                        height: 0)
                case .vertical:
                    dragOffset = CGSize(width: 0,
                                        height: max(0, value.translation.height))
                case .none:
                    break
                }
            }
            .onEnded { value in
                defer { axis = nil; dragOffset = .zero }
                guard let lockedAxis = axis else { return }

                // Threshold reference = the content's own size (correct in any
                // orientation / Split View). Fall back to screen bounds only if
                // the background reader hasn't reported yet.
                let screen = contentSize == .zero ? UIScreen.main.bounds.size : contentSize
                let traveled: CGFloat
                let dimension: CGFloat
                let predictedExtra: CGFloat
                switch lockedAxis {
                case .horizontal:
                    traveled = value.translation.width
                    dimension = screen.width
                    predictedExtra = value.predictedEndTranslation.width - value.translation.width
                case .vertical:
                    traveled = value.translation.height
                    dimension = screen.height
                    predictedExtra = value.predictedEndTranslation.height - value.translation.height
                }

                let crossedThreshold = traveled > dimension * commitFraction
                let flicked = predictedExtra > flickPredictedExtra
                if crossedThreshold || flicked {
                    onDismiss()
                }
                // axis + dragOffset reset via defer — animates the spring-back.
            }
    }
}

extension View {
    /// Apply interactive pop gestures to a `.fullScreenCover` content view.
    /// `isEnabled` defaults to true; pass false to suppress during phases
    /// where dismissal would discard in-progress work.
    ///
    /// Behavior:
    /// - **Edge-swipe-right** (started within 40pt of leading edge): content
    ///   tracks the finger horizontally. Commits past 30% of screen width
    ///   or a strong flick; springs back otherwise.
    /// - **Swipe-down** (any start point): content tracks vertically. Same
    ///   30%-or-flick threshold against screen height.
    /// - **Diagonal drags** lock to whichever axis dominates on first
    ///   meaningful change, so a slightly diagonal swipe still feels clean.
    func swipeBackToDismiss(
        isEnabled: Bool = true,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(SwipeBackToDismiss(isEnabled: isEnabled, onDismiss: onDismiss))
    }
}
