import SwiftUI

/// Shared top bar — every v2.1 surface uses this. Two slots: a leading
/// affordance (either system word like ARCLAB, or a back chip ← LABEL) and
/// a trailing micro-readout (chapter number, streak, lesson length, rank).
///
/// Locked typography: SF Mono 11pt, tracking 2.0, uppercase only. Leading
/// back chips meet 44pt min tap height. White for the emphasized half of
/// the trailing slot (numbers, current state), mid-grey for the labels.
struct TopBar: View {
    let leading: Leading
    let trailing: Trailing?

    enum Leading {
        /// Static identity word, e.g. "ARCLAB". Not tappable.
        case word(String)
        /// Back chip — "← \(label)" with a tap target. Label is uppercased.
        case back(label: String, action: () -> Void)
    }

    enum Trailing {
        /// Single short readout, e.g. "CHAPTER 1" or "STREAK 0".
        case label(String)
        /// Two-line readout: bold over secondary, e.g. "ROOKIE I / 0 / 200 XP".
        case stacked(primary: String, secondary: String)
    }

    var body: some View {
        HStack(alignment: .center) {
            leadingView
            Spacer()
            trailingView
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .word(let text):
            Text(text.uppercased())
                .font(.sfMono(size: 11))
                .foregroundColor(.arclabMidGrey)
                .tracking(2.0)
        case .back(let label, let action):
            Button(action: action) {
                Text("← \(label.uppercased())")
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to \(label).")
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        if let trailing {
            switch trailing {
            case .label(let text):
                Text(text.uppercased())
                    .font(.sfMono(size: 11))
                    .foregroundColor(.arclabMidGrey)
                    .tracking(2.0)
            case .stacked(let primary, let secondary):
                VStack(alignment: .trailing, spacing: 2) {
                    Text(primary.uppercased())
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabWhite)
                        .tracking(2.0)
                    Text(secondary.uppercased())
                        .font(.sfMono(size: 11))
                        .foregroundColor(.arclabMidGrey)
                        .tracking(2.0)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TopBar(leading: .word("ARCLAB"), trailing: .label("STREAK 0"))
        TopBar(leading: .back(label: "Basketball", action: {}), trailing: .label("CHAPTER 1"))
        TopBar(leading: .back(label: "Back", action: {}), trailing: .label("LESSON · 60s"))
        TopBar(leading: .word("ARCLAB"), trailing: .stacked(primary: "ROOKIE I", secondary: "0 / 200 XP"))
    }
    .padding()
    .background(Color.arclabBlack)
}
