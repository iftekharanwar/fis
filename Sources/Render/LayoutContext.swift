import SwiftUI

/// Resolved adaptive-layout context for a screen. Computed once near the top of
/// a surface from the horizontal size class + the surface's `GeometryReader`
/// size, then read by subviews (directly or via `\.layoutContext`).
///
/// **Keyed off size class + geometry, never device idiom** — so iPad Split View
/// / Stage Manager (which report compact width) and every device size fall out
/// correctly. iPhone never reports regular width, so it always resolves to
/// `.compact` and existing iPhone layouts are unchanged.
struct LayoutContext: Equatable, Sendable {
    enum Form: Sendable { case compact, regular }
    enum Orientation: Sendable { case portrait, landscape }

    let form: Form
    let orientation: Orientation
    let size: CGSize
    let safeArea: EdgeInsets

    /// iPad (or any regular-width canvas).
    var isRegular: Bool { form == .regular }
    /// Landscape (wider than tall). Drives the play surfaces' side-dock layout.
    var isWide: Bool { orientation == .landscape }

    /// Multiplier for display headlines (Anton verbs, hero numbers) so posters
    /// read at the right scale on a large canvas. 1.0 on compact (iPhone) keeps
    /// phone typography byte-for-byte. Precision SF Mono readouts intentionally
    /// do NOT use this (they stay chip-aligned).
    var typeScale: CGFloat {
        switch form {
        case .compact: return 1.0
        case .regular: return isWide ? 1.35 : 1.25
        }
    }

    static func resolve(
        horizontalSizeClass: UserInterfaceSizeClass?,
        size: CGSize,
        safeArea: EdgeInsets
    ) -> LayoutContext {
        LayoutContext(
            form: horizontalSizeClass == .regular ? .regular : .compact,
            orientation: size.width > size.height ? .landscape : .portrait,
            size: size,
            safeArea: safeArea
        )
    }
}

// MARK: - Environment plumbing

private struct LayoutContextKey: EnvironmentKey {
    static let defaultValue = LayoutContext(
        form: .compact,
        orientation: .portrait,
        size: .zero,
        safeArea: EdgeInsets()
    )
}

extension EnvironmentValues {
    /// The current adaptive-layout context. A surface computes it from its
    /// `GeometryReader` and injects it with `.environment(\.layoutContext, ctx)`
    /// so deep subviews (HUD, docks, numpad) read the same value.
    var layoutContext: LayoutContext {
        get { self[LayoutContextKey.self] }
        set { self[LayoutContextKey.self] = newValue }
    }
}
