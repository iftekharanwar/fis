import SwiftUI

/// Typography tokens per `CONCEPT.md` and `SCREENS.md` Conventions.
///
/// Three families:
/// - **Anton** — display verb. Always uppercase (it's a display face designed
///   for it). Custom font, bundled.
/// - **Barlow Condensed** — subhead and prose. Sentence case always. Custom
///   font, bundled.
/// - **SF Mono** — every technical readout (variables, units, ranks, level
///   codes, stat strips, attempt counters). System-bundled (free, no bundle
///   hit, Dynamic Type-native). Uppercase only for codes/tags/nav of ≤3 words.
///
/// **Dynamic Type** — every helper uses `Font.custom(..., size:, relativeTo:)`
/// so custom fonts scale with the user's accessibility text size. Poster
/// headlines (Anton verbs) clamp via the caller using `.dynamicTypeSize(...)`
/// to protect layout — see SCREENS.md Conventions for the clamping policy.
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
        return Font.custom(name, size: size, relativeTo: relativeTo)
    }

    /// Barlow Condensed scaled by a `LayoutContext.typeScale` for subheads/prose
    /// that should grow on a regular-width canvas. Scale 1.0 = unchanged.
    static func barlowCondensed(size: CGFloat, scale: CGFloat, italic: Bool = false, relativeTo: Font.TextStyle = .body) -> Font {
        barlowCondensed(size: size * scale, italic: italic, relativeTo: relativeTo)
    }

    // MARK: - SF Mono (system, technical readouts)

    /// SF Mono at any size. System-bundled — no .ttf required.
    /// Uppercase rule (≤3 words) enforced by the caller, not the font.
    static func sfMono(size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle = .body) -> Font {
        // SF Mono is exposed via `.monospaced` design on a system font;
        // explicit-size variant uses `Font.system(size:weight:design:)` per
        // Apple's Font docs. Dynamic Type scaling is automatic via relativeTo
        // when used with `Font.system(_:design:)` (preferred for body text)
        // but we use fixed-size here so the readouts stay precision-aligned
        // with the surrounding bordered chip layouts.
        Font.system(size: size, weight: weight, design: .monospaced)
    }
}
