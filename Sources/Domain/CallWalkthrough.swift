import Foundation

/// Derivation cards for the call surface's SHOW THE MATH beat, generated
/// from the scenario's authored solution + ghost arc instead of hardcoded
/// copy. The ghost arc is the same answer the CI smoke tests fire through
/// the simulation, so the numbers shown here can never drift from the shot
/// the player actually watches land.
struct CallWalkthrough: Equatable, Sendable {
    struct Card: Equatable, Sendable {
        let headline: String
        let math: String
        let body: String
    }

    let cards: [Card]

    init(scenario: ScenarioDefinition) {
        var built: [Card] = []

        // 1 — the governing equation(s), from the authored solution.
        let equations = scenario.solution?.equations ?? []
        built.append(Card(
            headline: "There's a formula for it.",
            math: equations.isEmpty
                ? "y(t) = h + v · sin(θ) · t − ½ · g · t²"
                : equations.joined(separator: "\n"),
            body: "Gravity pulls the ball down. Nothing else acts on it. Every shot is the same shape — and it has one equation."
        ))

        // 2 — the actual givens from the situation, plus the question asked.
        let givens = scenario.situation.variables
            .map { "\(Self.displaySymbol($0.symbol)) = \(Self.trim($0.value))\(Self.unitSuffix($0.unit))" }
            .joined(separator: "   ")
        built.append(Card(
            headline: "Plug in what you know.",
            math: givens,
            body: scenario.situation.questionRevealed
        ))

        // 3 — the authored worked steps. A leading "Given:" line duplicates
        // the card above, so it gets dropped.
        let steps = (scenario.solution?.workedSteps ?? [])
            .filter { !$0.lowercased().hasPrefix("given") }
        if !steps.isEmpty {
            built.append(Card(
                headline: "Work it through.",
                math: "",
                body: steps.joined(separator: "\n")
            ))
        }

        // 4 — the answer, from the verified ghost arc.
        built.append(Self.answerCard(for: scenario))

        cards = built
    }

    // MARK: - Answer card

    private static func answerCard(for scenario: ScenarioDefinition) -> Card {
        let ghost = scenario.outcome.ghostArc
        let thetaText = ghost?.answer["theta"].map { "θ ≈ \(trim($0))°" }
        let vText = ghost?.answer["v"].map { "v ≈ \(trim($0)) m/s" }
        let dText = targetDistance(of: scenario).map { "d ≈ \(trim($0)) m" }
        let pairText = [thetaText, vText].compactMap { $0 }.joined(separator: ", ")

        // Lead with the unknown the scenario actually asks for.
        let headline: String
        switch scenario.meta.levelType {
        case .findD:     headline = dText ?? pairText
        case .findTheta: headline = thetaText ?? pairText
        case .findV:     headline = vText ?? pairText
        default:         headline = pairText
        }

        return Card(
            headline: headline.isEmpty ? "That's the shot." : headline + ".",
            math: [thetaText, vText].compactMap { $0 }.joined(separator: "   "),
            body: ghost?.description
                ?? "That's the shot. Tap below to watch what the formula calls for."
        )
    }

    /// Horizontal hoop distance from the simulation world params — the
    /// geometry the renderer actually uses, never a defaulted variable lookup.
    static func targetDistance(of scenario: ScenarioDefinition) -> Double? {
        guard case .projectile2D(_, let params) = scenario.simulation,
              let hoopX = params.target.center.first else { return nil }
        return hoopX - (params.releasePosition.first ?? 0)
    }

    // MARK: - Formatting

    private static func displaySymbol(_ symbol: String) -> String {
        symbol == "theta" ? "θ" : symbol
    }

    private static func unitSuffix(_ unit: String) -> String {
        if unit.isEmpty { return "" }
        return unit == "°" ? unit : " " + unit
    }

    /// "48.00" → "48", "8.20" → "8.2", "5.82" → "5.82".
    static func trim(_ value: Double) -> String {
        var s = String(format: "%.2f", value)
        while s.contains("."), s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
