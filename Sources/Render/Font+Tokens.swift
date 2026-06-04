import SwiftUI
import UIKit

/// Typography tokens per `CONCEPT.md` and `SCREENS.md` Conventions.
///
/// Three families:
/// - **Anton** — display verb. Always uppercase (it's a display face designed
///   for it). Custom font, bundled.
/// - **Barlow Condensed** — subhead and prose. Sentence case always. Custom
///   font, bundled.
/// - **SF Mono** — every technical readout (variables, units, ranks, level
///   codes, stat strips, attempt counters). System-bundled (free, no bundle
///   hit). Uppercase only for codes/tags/nav of ≤3 words.
///
/// **Dynamic Type** — every family scales with the user's accessibility text
/// size. Anton and Barlow scale via `Font.custom(..., relativeTo:)`. SF Mono
/// scales via `UIFontMetrics`: a fixed `Font.system(size:)` does *not* respond
/// to Dynamic Type, so we build the monospaced `UIFont` and let
/// `UIFontMetrics` scale it relative to a text style. Poster headlines (Anton
/// verbs) clamp via the caller using `.dynamicTypeSize(...)` to protect
/// layout — see SCREENS.md Conventions for the clamping policy.
///
/// **Legibility floor** — base sizes are clamped to a minimum before scaling
/// (`12` for SF Mono, `16` for Barlow prose) so no call site can render text
/// below the readable floor, even if it passes a smaller literal. To change
/// the floor, edit `TypeScale` here — never re-introduce sub-floor sizes at
/// call sites.
///
/// **Font fallback** — if the bundled .ttf files aren't present in
/// `Resources/Fonts/` at runtime, `Font.custom` silently falls back to the
/// system font. The app still runs; the typography just doesn't match the
/// spec. Diagnostic test in `FontRegistrationTests` catches this in CI.
extension Font {

    // MARK: - Anton (display verb)

    /// Anton at any size. Pair with `.foregroundColor(.arclabWhite)` and
    /// caller-supplied `.dynamicTypeSize(...)` clamping for poster headlines.
    static func anton(size: CGFloat, relativeTo: Font.TextStyle = .largeTitle) -> Font {
        Font.custom("Anton-Regular", size: size, relativeTo: relativeTo)
    }

    /// Anton scaled by a `LayoutContext.typeScale` so poster verbs grow on a
    /// regular-width canvas (iPad) and stay phone-sized on compact (scale 1.0).
    static func anton(size: CGFloat, scale: CGFloat, relativeTo: Font.TextStyle = .largeTitle) -> Font {
        anton(size: size * scale, relativeTo: relativeTo)
    }

    // MARK: - Barlow Condensed (prose, italic flavor)

    static func barlowCondensed(size: CGFloat, italic: Bool = false, relativeTo: Font.TextStyle = .body) -> Font {
        let name = italic ? "BarlowCondensed-Italic" : "BarlowCondensed-Regular"
        return Font.custom(name, size: max(size, TypeScale.minProse) * TypeScale.bodyBoost, relativeTo: relativeTo)
    }

    /// Barlow Condensed scaled by a `LayoutContext.typeScale` for subheads/prose
    /// that should grow on a regular-width canvas. Scale 1.0 = unchanged.
    static func barlowCondensed(size: CGFloat, scale: CGFloat, italic: Bool = false, relativeTo: Font.TextStyle = .body) -> Font {
        barlowCondensed(size: size * scale, italic: italic, relativeTo: relativeTo)
    }

    // MARK: - SF Mono (system, technical readouts)

    /// SF Mono at any size, Dynamic Type-aware. System-bundled — no .ttf
    /// required. The uppercase rule (≤3 words) is enforced by the caller, not
    /// the font. We build a concrete monospaced `UIFont` and scale it through
    /// `UIFontMetrics`, because a plain `Font.system(size:)` is frozen and
    /// ignores the user's accessibility text-size setting.
    static func sfMono(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        let base = UIFont.monospacedSystemFont(ofSize: max(size, TypeScale.minMono) * TypeScale.bodyBoost, weight: weight.uiKitWeight)
        let scaled = UIFontMetrics(forTextStyle: textStyle.uiKitTextStyle).scaledFont(for: base)
        return Font(scaled)
    }
}

// MARK: - Legibility floor

private enum TypeScale {
    /// Smallest SF Mono base size before Dynamic Type scaling.
    static let minMono: CGFloat = 12
    /// Smallest Barlow prose base size before Dynamic Type scaling.
    static let minProse: CGFloat = 16
    /// Global readability boost applied to body prose (Barlow Condensed) and
    /// technical readouts (SF Mono) — but NOT display titles (Anton). Bakes the
    /// user-preferred "110%" into the default so non-title text reads
    /// comfortably at the standard Dynamic Type size; Dynamic Type still scales
    /// further on top of this.
    static let bodyBoost: CGFloat = 1.10
}

// MARK: - SwiftUI → UIKit bridges (for UIFontMetrics scaling)

private extension Font.Weight {
    /// The UIKit weight matching this SwiftUI weight, so we can build a
    /// concrete `UIFont` for `UIFontMetrics` to scale.
    var uiKitWeight: UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}

private extension Font.TextStyle {
    /// The UIKit text style whose Dynamic Type scaling curve this readout
    /// should follow.
    var uiKitTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}
