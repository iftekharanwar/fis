import XCTest
import AVFoundation
@testable import PhysicsGame

/// Smoke tests for the audio bundle. Verifies every `SoundID` and `LoopID`
/// has its `.wav` reachable from `Bundle.main` and decodes through
/// `AVAudioFile`. Catches silent-no-op asset misnames / missing files at
/// CI time instead of player-runtime.
final class AudioBundleTests: XCTestCase {

    func testEverySoundIDResolvesToBundle() throws {
        for sound in SoundID.allCases {
            let url = locate(filename: sound.filename, subdirectory: sound.bundleSubdirectory)
            XCTAssertNotNil(url, "missing audio asset: \(sound.filename)")
            if let url {
                XCTAssertNoThrow(try AVAudioFile(forReading: url), "failed to decode \(sound.filename)")
            }
        }
    }

    func testEveryLoopIDResolvesToBundle() throws {
        for loop in LoopID.allCases {
            let url = locate(filename: loop.filename, subdirectory: loop.bundleSubdirectory)
            XCTAssertNotNil(url, "missing audio loop: \(loop.filename)")
            if let url {
                XCTAssertNoThrow(try AVAudioFile(forReading: url), "failed to decode \(loop.filename)")
            }
        }
    }

    /// Mirrors `AudioService.bundleURL(filename:subdirectory:)` resolution.
    /// Tries subdirectory first, falls back to bundle root (Xcode flattens
    /// folder references at copy time).
    private func locate(filename: String, subdirectory: String) -> URL? {
        let stem = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let testBundle = Bundle(for: AudioBundleTests.self)
        if let url = testBundle.url(forResource: stem, withExtension: ext, subdirectory: subdirectory) {
            return url
        }
        if let url = testBundle.url(forResource: stem, withExtension: ext) {
            return url
        }
        // Tests bundle doesn't include app's Resources; fall back to main bundle
        // when run as an in-app test target.
        if let url = Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: subdirectory) {
            return url
        }
        return Bundle.main.url(forResource: stem, withExtension: ext)
    }
}
