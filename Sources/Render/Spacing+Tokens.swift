import CoreGraphics

/// Spacing scale per `SCREENS.md` Conventions: only these values, no in-betweens.
///
/// Zone-boundary positions (top/middle/bottom layout breakpoints in pt) are
/// distinct from gap-spacing — they're documented per-screen in SCREENS.md and
/// not enumerated here.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 16
    static let md: CGFloat = 24
    static let lg: CGFloat = 32
    static let xl: CGFloat = 48
    static let xxl: CGFloat = 64
}

/// Common element dimensions reused across screens.
enum Sizing {
    /// Canonical pill-button height (START, SHOOT, NEXT LEVEL, REVEAL, etc.).
    static let pillButtonHeight: CGFloat = 56
    /// Standard HIG tap target minimum. Used for small chips.
    static let minTapTarget: CGFloat = 44
    /// LEVEL SELECT row height.
    static let listRowHeight: CGFloat = 88

    /// Corner radius for small chips + buttons (CTAs, pills, chip badges).
    /// 4pt = barely-rounded, brand-coded.
    static let cornerRadius: CGFloat = 4
    /// Pill button radius — for primary CTAs that need to read as
    /// rounded pills. Buttons feel like buttons; cards feel like cards.
    static let pillRadius: CGFloat = 12
    /// Card radius for large containers (hero cards, lesson panels). Slightly
    /// softer than chips so cards read as surfaces, not buttons.
    static let cardRadius: CGFloat = 8
    /// Border width for any bordered container.
    static let borderWidth: CGFloat = 1
}
