import Foundation

enum ScenarioLoadError: Error, Equatable {
    case notFound(scenarioId: ScenarioID)
    case malformedJSON(scenarioId: ScenarioID, underlying: String)
    /// `path` is a JSON-pointer-like field path that failed validation.
    case validationFailed(scenarioId: ScenarioID, path: String, reason: String)
    case unknownModule(scenarioId: ScenarioID, moduleId: String)
}

/// Loads scenario JSON from the app bundle and decodes it into `ScenarioDefinition`.
enum ScenarioLoader {

    static func load(_ id: ScenarioID, in bundle: Bundle = .main) throws -> ScenarioDefinition {
        guard let url = bundle.url(forResource: id.rawValue, withExtension: "json", subdirectory: "Scenarios")
                ?? bundle.url(forResource: id.rawValue, withExtension: "json")
        else {
            throw ScenarioLoadError.notFound(scenarioId: id)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ScenarioLoadError.malformedJSON(
                scenarioId: id,
                underlying: error.localizedDescription
            )
        }

        return try decode(data, scenarioId: id)
    }

    /// Exposed for tests so they can feed arbitrary Data without writing a file.
    static func decode(_ data: Data, scenarioId: ScenarioID) throws -> ScenarioDefinition {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ScenarioDefinition.self, from: data)
        } catch let DecodingError.typeMismatch(_, context) {
            throw ScenarioLoadError.validationFailed(
                scenarioId: scenarioId,
                path: codingPathString(context.codingPath),
                reason: context.debugDescription
            )
        } catch let DecodingError.valueNotFound(_, context) {
            throw ScenarioLoadError.validationFailed(
                scenarioId: scenarioId,
                path: codingPathString(context.codingPath),
                reason: "Required field missing: \(context.debugDescription)"
            )
        } catch let DecodingError.keyNotFound(key, context) {
            // Build the path including the missing key for clarity.
            let parentPath = codingPathString(context.codingPath)
            let fullPath = parentPath.isEmpty ? "/\(key.stringValue)" : "\(parentPath)/\(key.stringValue)"
            throw ScenarioLoadError.validationFailed(
                scenarioId: scenarioId,
                path: fullPath,
                reason: "Required field missing"
            )
        } catch let DecodingError.dataCorrupted(context) {
            throw ScenarioLoadError.validationFailed(
                scenarioId: scenarioId,
                path: codingPathString(context.codingPath),
                reason: context.debugDescription
            )
        } catch {
            throw ScenarioLoadError.malformedJSON(
                scenarioId: scenarioId,
                underlying: error.localizedDescription
            )
        }
    }

    private static func codingPathString(_ path: [any CodingKey]) -> String {
        guard !path.isEmpty else { return "/" }
        return "/" + path.map { key in
            if let idx = key.intValue { return "\(idx)" }
            return key.stringValue
        }.joined(separator: "/")
    }
}
