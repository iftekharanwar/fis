import XCTest
@testable import PhysicsGame

/// Tests for the persistence layer.
///
/// All tests use a per-test temp-directory `fileURL` so they don't touch
/// the real Application Support file. `debounceInterval: 0` makes writes
/// flushable synchronously via `flushPendingWritesForTest()`.
@MainActor
final class PlayerProfileStoreTests: XCTestCase {

    var tempDir: URL!
    var fileURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PlayerProfileStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("PlayerProfile.v1.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - (a) Mutation survives across "app kill"

    func test_mutationPersistsAcrossFreshStoreLoad() async throws {
        // Arrange: fresh store, mutate XP and a scenario record.
        let storeA = PlayerProfileStore(fileURL: fileURL, debounceInterval: 0)
        storeA.mutate { profile in
            profile.totalXP = 420
            profile.recomputeRank()
            profile.completedScenarios[ScenarioID("bb-1-baseline")] = ScenarioRecord(
                bestScore: 95,
                attemptCounter: 3,
                hintTiersUsedThisAttempt: [1, 2],
                scoreCapPenaltyThisAttempt: 35,
                replayAfterSuccessFlag: false,
                watermarkEarnedFlag: true,
                lastAttemptInputs: ["theta": 52.0, "v": 7.45],
                firstCompletedAt: Date(timeIntervalSince1970: 1_700_000_000),
                lastPlayedAt: Date(timeIntervalSince1970: 1_700_000_500)
            )
        }
        await storeA.flushPendingWritesForTest()

        // Act: simulate app kill — instantiate a fresh store from the same file.
        let storeB = PlayerProfileStore(fileURL: fileURL, debounceInterval: 0)

        // Assert: state survived.
        XCTAssertEqual(storeB.profile.totalXP, 420)
        XCTAssertEqual(storeB.profile.rankRung.rank, .rookie)
        XCTAssertEqual(storeB.profile.rankRung.subTier, .III) // 420 XP at v1 thresholds
        let record = try XCTUnwrap(storeB.profile.completedScenarios[ScenarioID("bb-1-baseline")])
        XCTAssertEqual(record.bestScore, 95)
        XCTAssertEqual(record.attemptCounter, 3)
        XCTAssertEqual(record.hintTiersUsedThisAttempt, [1, 2])
        XCTAssertEqual(record.scoreCapPenaltyThisAttempt, 35)
        XCTAssertTrue(record.watermarkEarnedFlag)
        XCTAssertEqual(record.lastAttemptInputs?["theta"], 52.0)
        XCTAssertEqual(record.firstCompletedAt?.timeIntervalSince1970, 1_700_000_000)
    }

    // MARK: - (b) Atomic write doesn't corrupt under simulated mid-write crash

    func test_atomicWrite_oldFileIntactIfTempPresent() async throws {
        // Arrange: write an initial profile, then create an orphan .tmp file
        // (simulating a crashed write that didn't reach replaceItemAt).
        let storeA = PlayerProfileStore(fileURL: fileURL, debounceInterval: 0)
        storeA.mutate { $0.totalXP = 100 }
        await storeA.flushPendingWritesForTest()

        // Orphan .tmp file with garbage content.
        let tempFile = fileURL.appendingPathExtension("tmp")
        try Data("garbage that wouldn't decode".utf8).write(to: tempFile)

        // Act: fresh store load — should read the real file, ignore .tmp.
        let storeB = PlayerProfileStore(fileURL: fileURL, debounceInterval: 0)

        // Assert: real file (totalXP=100) is intact; .tmp is ignored.
        XCTAssertEqual(storeB.profile.totalXP, 100)
        // .tmp file itself remains on disk; next successful write cleans it via replaceItemAt.
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile.path))
    }

    // MARK: - (c) Corruption recovery: rename .bad + fresh default

    func test_corruptedFile_renamedAsBad_freshDefaultLoaded() async throws {
        // Arrange: write garbage where the profile should be.
        try Data("this is not valid JSON".utf8).write(to: fileURL)

        // Act: load.
        let store = PlayerProfileStore(fileURL: fileURL, debounceInterval: 0)

        // Assert: fresh default in memory.
        XCTAssertEqual(store.profile.totalXP, 0)
        XCTAssertTrue(store.profile.firstRun)
        XCTAssertTrue(store.profile.firstEverScenario)

        // Assert: the bad file was renamed (some .bad-* sibling now exists in the dir).
        let dir = fileURL.deletingLastPathComponent()
        let siblings = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let badFiles = siblings.filter { $0.contains(".bad-") }
        XCTAssertEqual(badFiles.count, 1, "Expected exactly one .bad-* renamed file, got: \(siblings)")
    }

    // MARK: - (d) Migration scaffold

    func test_migration_currentVersionDecodes() throws {
        // Encode a current-version profile, decode via migrate().
        let profile = PlayerProfile.newProfile()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        let decoded = try PlayerProfileStore.migrate(data)
        XCTAssertEqual(decoded.profileSchemaVersion, PlayerProfile.currentSchemaVersion)
        XCTAssertEqual(decoded.totalXP, 0)
    }

    func test_migration_versionZeroThrows() throws {
        // v0 = no version field at all (older than MVP shouldn't exist, but defensive).
        let data = Data(#"{"totalXP": 0}"#.utf8)
        XCTAssertThrowsError(try PlayerProfileStore.migrate(data)) { error in
            guard case PersistenceError.profileTooOld = error else {
                return XCTFail("Expected profileTooOld, got \(error)")
            }
        }
    }

    func test_migration_versionFromFutureThrows() throws {
        // v999 = user downgraded from a future app version.
        let data = Data(#"{"profileSchemaVersion": 999, "totalXP": 0}"#.utf8)
        XCTAssertThrowsError(try PlayerProfileStore.migrate(data)) { error in
            guard case PersistenceError.profileFromFuture = error else {
                return XCTFail("Expected profileFromFuture, got \(error)")
            }
        }
    }

    // MARK: - (e) Defaults are sane

    func test_externalTestProfile_decodesCleanly() throws {
        // Diagnostic — proves the exact JSON shape we hand-author for
        // simulator-side default-HOME verification decodes cleanly. If this
        // fails, simulator-side writes will silently get rejected and the
        // app falls back to first-run state, producing very confusing visual
        // verification results.
        //
        // Routed through PlayerProfileStore.migrate so the test exercises the
        // real on-disk decoding path (which handles v1→v2 schema migration
        // automatically). The fixture is intentionally v1 to also serve as a
        // regression test for the migration.
        let json = """
        {
          "completedScenarios" : {},
          "firstEverScenario" : true,
          "firstRun" : false,
          "firstThreeScenariosBriefingHintSeen" : 0,
          "profileSchemaVersion" : 1,
          "rankRung" : {
            "rank" : "ROOKIE",
            "subTier" : "II"
          },
          "totalXP" : 380
        }
        """
        let profile = try PlayerProfileStore.migrate(Data(json.utf8))
        XCTAssertFalse(profile.firstRun)
        XCTAssertEqual(profile.totalXP, 380)
        XCTAssertEqual(profile.rankRung.rank, .rookie)
        // v1→v2 migration must inject hasSeenOnboarding=true for legacy users.
        XCTAssertTrue(profile.hasSeenOnboarding, "v1→v2 migration should mark legacy users as already-onboarded")
        XCTAssertEqual(profile.profileSchemaVersion, PlayerProfile.currentSchemaVersion)
    }

    func test_freshProfile_hasExpectedDefaults() {
        let p = PlayerProfile.newProfile()
        XCTAssertEqual(p.profileSchemaVersion, PlayerProfile.currentSchemaVersion)
        XCTAssertEqual(p.totalXP, 0)
        XCTAssertEqual(p.rankRung, RankRung(rank: .rookie, subTier: .I))
        XCTAssertTrue(p.firstRun)
        XCTAssertTrue(p.firstEverScenario)
        XCTAssertEqual(p.firstThreeScenariosBriefingHintSeen, 0)
        XCTAssertEqual(p.completedScenarios, [:])
        // Fresh-install profile starts un-onboarded; OnboardingView is shown.
        XCTAssertFalse(p.hasSeenOnboarding)
    }
}

/// Tests for the rank progression math. Live in the same target since they
/// don't need a fixture and run instantly.
final class RankRungTests: XCTestCase {

    func test_zeroXP_isRookieI() {
        XCTAssertEqual(RankRung.from(xp: 0), RankRung(rank: .rookie, subTier: .I))
    }

    func test_rankIncreasesMonotonicallyWithXP() {
        var lastSeen = RankRung.from(xp: 0)
        for xp in stride(from: 0, through: 12_000, by: 100) {
            let rung = RankRung.from(xp: xp)
            // Compare by rank index — sub-tier always advances within rank too.
            let lastRankIdx = Rank.allCases.firstIndex(of: lastSeen.rank) ?? 0
            let curRankIdx  = Rank.allCases.firstIndex(of: rung.rank)    ?? 0
            XCTAssertGreaterThanOrEqual(curRankIdx, lastRankIdx, "Rank went backwards at XP=\(xp)")
            lastSeen = rung
        }
    }

    func test_legendIII_isCappedAtTopOfCurve() {
        // Far beyond any reasonable XP → should clamp to LEGEND III, not crash.
        let rung = RankRung.from(xp: 1_000_000)
        XCTAssertEqual(rung.rank, .legend)
        XCTAssertEqual(rung.subTier, .III)
    }

    func test_xpToNext_isNilAtLegendIII() {
        XCTAssertNil(RankRung.xpToNext(currentXP: 1_000_000))
    }

    func test_xpToNext_isPositiveAtIntermediateRung() {
        let xp = 250
        let remaining = RankRung.xpToNext(currentXP: xp)
        XCTAssertNotNil(remaining)
        XCTAssertGreaterThan(remaining ?? 0, 0)
    }
}

/// Regression tests for the Daily Question surfacing logic.
///
/// The card derives its question from the player profile, and *answering
/// mutates that profile* — which makes SwiftUI re-evaluate the view's
/// initializer with fresh state. If the picker isn't stable across that
/// mutation, the question visibly swaps to a different one underneath the
/// revealed answer (the "tapped an answer, saw another question's reveal" bug).
@MainActor
final class DailyQuestionPickerTests: XCTestCase {

    /// A fixed day whose date-rotation pick is *not* the brand-new-player lead
    /// question — so the stability checks are meaningful (a stable picker has
    /// to actively hold the lead rather than coincidentally match the date).
    private let fixedDate = Date(timeIntervalSince1970: 1_000_000_000)

    func test_questionIsStableAcrossAnswering() throws {
        var profile = PlayerProfile.newProfile()
        let before = try XCTUnwrap(
            DailyQuestionPicker.current(for: profile, on: fixedDate),
            "expected a lead question for a fresh profile"
        )

        // Answering sets lastDailyAnsweredDate/Pick/ID on the profile.
        profile.recordDailyAnswer(pick: 0, questionID: before.id, now: fixedDate)

        // The surfaced question must NOT change — this is the swap bug.
        let after = DailyQuestionPicker.current(for: profile, on: fixedDate)
        XCTAssertEqual(after?.id, before.id,
            "Daily question changed after answering — it must stay stable for the day")
    }

    func test_reopenSameDayReturnsTheExactAnsweredQuestion() throws {
        var profile = PlayerProfile.newProfile()
        let lead = try XCTUnwrap(DailyQuestionPicker.current(for: profile, on: fixedDate))
        let rotation = DailyQuestionPicker.todays(on: fixedDate)
        XCTAssertNotEqual(lead.id, rotation?.id,
            "test setup expects the lead and the date-rotation to differ on this day")

        profile.recordDailyAnswer(pick: 1, questionID: lead.id, now: fixedDate)

        let reopened = DailyQuestionPicker.current(for: profile, on: fixedDate)
        XCTAssertEqual(reopened?.id, lead.id,
            "Re-opening the daily must restore the exact question that was answered")
    }

    func test_nextDayResumesTheDateRotation() throws {
        var profile = PlayerProfile.newProfile()
        let lead = try XCTUnwrap(DailyQuestionPicker.current(for: profile, on: fixedDate))
        profile.recordDailyAnswer(pick: 0, questionID: lead.id, now: fixedDate)

        let nextDay = fixedDate.addingTimeInterval(86_400)
        let tomorrow = DailyQuestionPicker.current(for: profile, on: nextDay)
        XCTAssertEqual(tomorrow?.id, DailyQuestionPicker.todays(on: nextDay)?.id,
            "A new day should resume the normal date-based rotation")
    }

    func test_answeredQuestionIDPersistsAcrossReload() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DQPickerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let fileURL = tempDir.appendingPathComponent("PlayerProfile.v1.json")

        let storeA = PlayerProfileStore(fileURL: fileURL, debounceInterval: 0)
        storeA.mutate { $0.recordDailyAnswer(pick: 2, questionID: "dq-03") }
        await storeA.flushPendingWritesForTest()

        // Simulate app kill → fresh load: the new optional field round-trips.
        let storeB = PlayerProfileStore(fileURL: fileURL, debounceInterval: 0)
        XCTAssertEqual(storeB.profile.lastDailyAnsweredQuestionID, "dq-03")
        XCTAssertEqual(storeB.profile.lastDailyAnsweredPick, 2)
    }
}
