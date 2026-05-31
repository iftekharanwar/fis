import SwiftUI

/// Reserved UI bands that occlude the full-bleed SpriteKit scene. Pushed into
/// the scene so the world transform frames action inside the unoccluded area.
///
/// `left`/`right` default to 0 so every existing
/// `SceneInsets(top:bottom:safeTop:safeBottom:)` call site keeps the same
/// portrait/bottom-dock geometry. The right band is used by the iPad landscape
/// side-dock layout (scene left / dock right) — see `AdaptiveMetrics`.
struct SceneInsets: Equatable, Sendable {
    var top: CGFloat
    var bottom: CGFloat
    var safeTop: CGFloat
    var safeBottom: CGFloat
    var left: CGFloat = 0
    var right: CGFloat = 0

    static let zero = SceneInsets(top: 0, bottom: 0, safeTop: 0, safeBottom: 0)
}

/// Per-device layout numbers for PLAY. Single source of truth — every PLAY
/// subview reads from the same instance.
struct PlayLayoutMetrics: Equatable, Sendable {
    /// Total reserved at the top (HUD + variable strip + safe-area top).
    let topReserve: CGFloat
    /// Reserved at the bottom during .idle (input dock + safe-area bottom).
    let bottomReserveIdle: CGFloat
    /// Reserved at the bottom during .action (zero — scene takes full screen).
    let bottomReserveAction: CGFloat
    /// Reserved at the bottom during .outcome (outcome composition height).
    let bottomReserveOutcome: CGFloat

    /// Numpad sheet height when revealed.
    let numpadSheetHeight: CGFloat
    /// Each numpad button row height. 4 rows.
    let numpadRowHeight: CGFloat

    /// Each input row (ANGLE / VELOCITY readout) height.
    let inputRowHeight: CGFloat
    /// SHOOT verb hit-area height.
    let shootHeight: CGFloat

    /// Whether to compress the variable strip on small phones.
    let variableStripCondensed: Bool

    /// Reserves match actual SwiftUI overlay heights. Bump these when the
    /// typographic dock redesign (task #94) replaces the legacy input view.
    static func compute(for size: CGSize, safeArea: EdgeInsets) -> PlayLayoutMetrics {
        let h = size.height
        let safeTop = safeArea.top
        let safeBottom = safeArea.bottom

        if h < 700 {
            return PlayLayoutMetrics(
                topReserve: safeTop + 100,
                bottomReserveIdle: safeBottom + 330,
                bottomReserveAction: safeBottom + 0,
                bottomReserveOutcome: safeBottom + 480,
                numpadSheetHeight: 280,
                numpadRowHeight: 56,
                inputRowHeight: 44,
                shootHeight: 56,
                variableStripCondensed: true
            )
        } else if h < 920 {
            return PlayLayoutMetrics(
                topReserve: safeTop + 100,
                bottomReserveIdle: safeBottom + 330,
                bottomReserveAction: safeBottom + 0,
                bottomReserveOutcome: safeBottom + 480,
                numpadSheetHeight: 320,
                numpadRowHeight: 64,
                inputRowHeight: 52,
                shootHeight: 64,
                variableStripCondensed: false
            )
        } else {
            return PlayLayoutMetrics(
                topReserve: safeTop + 100,
                bottomReserveIdle: safeBottom + 330,
                bottomReserveAction: safeBottom + 0,
                bottomReserveOutcome: safeBottom + 480,
                numpadSheetHeight: 360,
                numpadRowHeight: 72,
                inputRowHeight: 56,
                shootHeight: 72,
                variableStripCondensed: false
            )
        }
    }
}

/// Orientation-aware placement of a play surface's chrome dock, layered on top
/// of `PlayLayoutMetrics`. The play surfaces own a per-phase "desired dock
/// height" today (idle 330 / action 0 / outcome 480, etc.); this struct decides
/// whether that dock stays a **bottom band** (iPhone + iPad portrait) or becomes
/// a **right-side column** (iPad landscape), and produces the matching scene
/// reserves to push via `applyUIReserve`.
///
/// Compact always resolves to the bottom-band branch with the exact reserve the
/// caller asked for, so iPhone geometry is unchanged.
struct AdaptiveMetrics: Equatable, Sendable {
    /// True when the dock is a right-side column (scene framed into the left
    /// band). False for the legacy bottom-band layout.
    let usesSideDock: Bool
    /// Reserve bands handed to the SpriteKit scene transform.
    let topReserve: CGFloat
    let bottomReserve: CGFloat
    let rightReserve: CGFloat
    /// Width of the dock content column (side dock width, or full width for a
    /// bottom band).
    let dockWidth: CGFloat
    /// Height available to the dock (its band height for a bottom dock, or the
    /// full surface height for a side column).
    let dockHeight: CGFloat

    /// Side-dock column width: ~38% of the surface, clamped to a usable range so
    /// the numpad/inputs stay comfortable and the court keeps real estate.
    static func sideDockWidth(for width: CGFloat) -> CGFloat {
        min(max(width * 0.38, 360), 480)
    }

    /// Translate a phase's desired bottom-dock height into reserves + placement.
    /// - Parameters:
    ///   - ctx: resolved layout context for the surface.
    ///   - topReserve: the surface's top reserve (HUD + safe area), unchanged.
    ///   - desiredBottomDockHeight: the dock height the surface would use in the
    ///     legacy bottom-band layout for the current phase.
    static func compute(
        ctx: LayoutContext,
        topReserve: CGFloat,
        desiredBottomDockHeight: CGFloat
    ) -> AdaptiveMetrics {
        let safeBottom = ctx.safeArea.bottom

        if ctx.form == .regular && ctx.orientation == .landscape {
            let dockW = sideDockWidth(for: ctx.size.width)
            return AdaptiveMetrics(
                usesSideDock: true,
                topReserve: topReserve,
                bottomReserve: safeBottom,
                rightReserve: dockW,
                dockWidth: dockW,
                dockHeight: ctx.size.height
            )
        }

        // Compact (iPhone) OR iPad portrait → keep the bottom-band geometry.
        return AdaptiveMetrics(
            usesSideDock: false,
            topReserve: topReserve,
            bottomReserve: desiredBottomDockHeight,
            rightReserve: 0,
            dockWidth: ctx.size.width,
            dockHeight: desiredBottomDockHeight
        )
    }
}
