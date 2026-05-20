import Foundation

/// Five-method contract every physics domain implements; the render layer only sees Snapshot.
protocol SimulationModule {
    associatedtype Params: Codable & Sendable
    associatedtype State
    associatedtype Snapshot: Sendable
    associatedtype Answer: Sendable
    associatedtype Outcome: Sendable

    static var moduleId: String { get }              // "PROJECTILE_2D"
    static var moduleVersion: SemVer { get }

    func initState(params: Params, answer: Answer) -> State

    /// Fixed-timestep, pure: same input → same output.
    func step(state: State, dt: Double) -> State

    func snapshot(state: State) -> Snapshot

    /// Called after every step; non-resolved means keep stepping.
    func evaluate(history: [Snapshot], params: Params) -> Outcome

    func reset()
}

/// Lets the driver loop decide when to stop stepping.
protocol SimulationOutcome: Sendable {
    var isResolved: Bool { get }
}

extension SimulationModule where Outcome: SimulationOutcome {
    /// Shared by CI smoke tests and ghost-arc precomputation; capped to prevent runaway runs.
    func headlessRun(
        params: Params,
        answer: Answer,
        fixedDt: Double,
        maxRuntime: Double = 10.0
    ) -> [Snapshot] {
        var state = initState(params: params, answer: answer)
        var history: [Snapshot] = [snapshot(state: state)]
        var elapsed: Double = 0
        while !evaluate(history: history, params: params).isResolved, elapsed < maxRuntime {
            state = step(state: state, dt: fixedDt)
            history.append(snapshot(state: state))
            elapsed += fixedDt
        }
        return history
    }
}
