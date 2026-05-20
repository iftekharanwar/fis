import Foundation

/// String-keyed lookup of simulation modules. Write-once at launch, read-only thereafter.
@MainActor
enum SimulationRegistry {

    private static var modules: [String: any AnySimulationModule] = [:]

    static func registerDefaults() {
        register(Projectile2DModule())
    }

    /// Idempotent — re-registering overwrites (useful in tests).
    static func register<M: AnySimulationModule>(_ module: M) {
        modules[type(of: module).staticModuleId] = module
    }

    static func module(for moduleId: String) -> (any AnySimulationModule)? {
        modules[moduleId]
    }

    static func reset() {
        modules.removeAll()
    }
}

/// Type-erased SimulationModule for storage in the registry.
protocol AnySimulationModule: Sendable {
    static var staticModuleId: String { get }
    static var staticModuleVersion: SemVer { get }
}
