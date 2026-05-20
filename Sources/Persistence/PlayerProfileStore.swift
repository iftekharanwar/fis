import Foundation
import Observation

enum PersistenceError: Error, Equatable {
    case profileTooOld(found: Int, current: Int)
    case profileFromFuture(found: Int, current: Int)
    case decodeFailed(reason: String)
    case writeFailed(reason: String)
}

/// Owns `PlayerProfile` on disk: synchronous in-memory mutations, debounced background writes.
@MainActor
@Observable
final class PlayerProfileStore {

    static let shared = PlayerProfileStore()

    private(set) var profile: PlayerProfile

    private let fileURL: URL
    private let writeQueue: DispatchQueue
    private var pendingWriteTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval

    /// Tests pass a custom `fileURL` and `debounceInterval: 0` for synchronous-feeling writes.
    init(
        fileURL: URL = PlayerProfileStore.defaultFileURL(),
        debounceInterval: TimeInterval = 0.5
    ) {
        self.fileURL = fileURL
        self.writeQueue = DispatchQueue(label: "com.iftekharanwar.physicsgame.profile.write", qos: .utility)
        self.debounceInterval = debounceInterval
        self.profile = Self.loadOrRecover(from: fileURL)
    }

    /// Synchronous from the caller's perspective; disk write happens later on the background queue.
    func mutate(_ block: (inout PlayerProfile) -> Void) {
        var copy = profile
        block(&copy)
        profile = copy
        scheduleWrite()
    }

    func flushPendingWritesForTest() async {
        await pendingWriteTask?.value
        let snapshot = profile
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writeQueue.async {
                Self.atomicWrite(snapshot, to: self.fileURL)
                cont.resume()
            }
        }
    }

    nonisolated static func defaultFileURL() -> URL {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Application Support always exists on iOS; tmp fallback is defensive only.
            return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PlayerProfile.v1.json")
        }
        let dir = appSupport.appendingPathComponent("PhysicsGame", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("PlayerProfile.v1.json")
    }

    nonisolated private static func loadOrRecover(from url: URL) -> PlayerProfile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return PlayerProfile.newProfile()
        }
        do {
            let data = try Data(contentsOf: url)
            return try migrate(data)
        } catch {
            // On corruption or migration failure, rename the bad file aside and start fresh.
            print("[PlayerProfileStore] load failed at \(url.path): \(error)")
            renameAsBad(url: url)
            return PlayerProfile.newProfile()
        }
    }

    nonisolated static func migrate(_ data: Data) throws -> PlayerProfile {
        // Peek at version before full decode so we can route migrations.
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let version = (raw["profileSchemaVersion"] as? Int) ?? 0
        switch version {
        case PlayerProfile.currentSchemaVersion:
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(PlayerProfile.self, from: data)
            } catch {
                throw PersistenceError.decodeFailed(reason: String(describing: error))
            }
        case 1:
            // Legacy users have already played; default hasSeenOnboarding to true.
            var migrated = raw
            migrated["hasSeenOnboarding"] = true
            migrated["profileSchemaVersion"] = PlayerProfile.currentSchemaVersion
            let migratedData = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(PlayerProfile.self, from: migratedData)
            } catch {
                throw PersistenceError.decodeFailed(reason: "v1→v2 migration: \(error)")
            }
        case 0:
            throw PersistenceError.profileTooOld(found: version, current: PlayerProfile.currentSchemaVersion)
        case let v where v > PlayerProfile.currentSchemaVersion:
            throw PersistenceError.profileFromFuture(found: v, current: PlayerProfile.currentSchemaVersion)
        default:
            throw PersistenceError.profileTooOld(found: version, current: PlayerProfile.currentSchemaVersion)
        }
    }

    nonisolated private static func renameAsBad(url: URL) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let badURL = url.appendingPathExtension("bad-\(timestamp)")
        try? FileManager.default.moveItem(at: url, to: badURL)
    }

    private func scheduleWrite() {
        pendingWriteTask?.cancel()
        let snapshot = profile
        let interval = debounceInterval
        let queue = writeQueue
        let url = fileURL
        pendingWriteTask = Task { [weak self] in
            // Debounce — coalesce rapid mutations into one disk write.
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled, self != nil else { return }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                queue.async {
                    Self.atomicWrite(snapshot, to: url)
                    cont.resume()
                }
            }
        }
    }

    /// Encode → temp file → APFS-atomic `replaceItemAt`. No torn writes.
    nonisolated static func atomicWrite(_ profile: PlayerProfile, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)
            let tempURL = url.appendingPathExtension("tmp")
            try data.write(to: tempURL, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: url)
            }
        } catch {
            // Silent failure preferred over crashing on transient disk errors; in-memory profile stays authoritative.
            print("[PlayerProfileStore] atomicWrite failed: \(error)")
        }
    }
}
