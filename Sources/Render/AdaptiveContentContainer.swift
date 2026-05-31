import SwiftUI

/// Constrains a content screen to a readable, centered column on a regular-width
/// canvas (iPad), while passing through unchanged on compact (iPhone).
///
/// Wrap a screen's root content in this so prose/rows don't stretch the full
/// width of a large display. Two-column screens (Home, ChapterList) compose
/// their own `HStack` of two of these (or place a side panel alongside).
///
/// Compact path is a literal pass-through, so iPhone layout is unchanged.
struct AdaptiveContentContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var hSize

    private let maxWidth: CGFloat
    private let content: Content

    /// - Parameter maxWidth: readable column cap on regular width. ~680–760 reads
    ///   well for single-column prose/lists; pass a smaller value for tight forms.
    init(maxWidth: CGFloat = 720, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        if hSize == .regular {
            content
                .frame(maxWidth: maxWidth)        // cap the column
                .frame(maxWidth: .infinity)       // center it in the wide canvas
        } else {
            content                                // iPhone: unchanged
        }
    }
}
