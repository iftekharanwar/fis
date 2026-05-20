import Foundation
import AVFoundation
import os

/// App-wide audio service backed by AVAudioEngine.
@MainActor
@Observable
final class AudioService {

    static let shared = AudioService()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let log = Logger(subsystem: "com.iftekharanwar.physicsgame", category: "audio")

    // One player per voice; simultaneous plays of the same sound will interrupt each other.
    private var oneShotPlayers: [SoundID: AVAudioPlayerNode] = [:]
    private var oneShotBuffers: [SoundID: AVAudioPCMBuffer] = [:]

    private var loopPlayers: [LoopID: AVAudioPlayerNode] = [:]
    private var loopBuffers: [LoopID: AVAudioPCMBuffer] = [:]
    private var loopsRunning: Set<LoopID> = []

    var masterEnabled: Bool = true

    private init() {
        configureSession()
        attachMixer()
        preloadOneShots()
        preloadLoops()
        startEngine()
        logBundleStatus()
    }

    private func logBundleStatus() {
        let loadedOneShots = oneShotBuffers.keys
        let allOneShots = Set(SoundID.allCases)
        let missingOneShots = allOneShots.subtracting(loadedOneShots).sorted { $0.filename < $1.filename }

        let loadedLoops = loopBuffers.keys
        let allLoops = Set(LoopID.allCases)
        let missingLoops = allLoops.subtracting(loadedLoops).sorted { $0.filename < $1.filename }

        log.info("audio bundle status: \(loadedOneShots.count, privacy: .public)/\(allOneShots.count, privacy: .public) one-shots loaded, \(loadedLoops.count, privacy: .public)/\(allLoops.count, privacy: .public) loops loaded")
        if !missingOneShots.isEmpty {
            let names = missingOneShots.map(\.filename).joined(separator: ", ")
            log.info("audio missing — one-shots: \(names, privacy: .public)")
        }
        if !missingLoops.isEmpty {
            let names = missingLoops.map(\.filename).joined(separator: ", ")
            log.info("audio missing — loops: \(names, privacy: .public)")
        }
    }

    private func configureSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .ambient honors silent switch and mixes with other audio.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            log.error("AVAudioSession config failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func attachMixer() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
    }

    private func preloadOneShots() {
        for sound in SoundID.allCases {
            guard let url = bundleURL(filename: sound.filename, subdirectory: sound.bundleSubdirectory) else {
                log.info("audio asset missing — \(sound.filename, privacy: .public)")
                continue
            }
            guard let buffer = loadBuffer(url: url) else { continue }
            oneShotBuffers[sound] = buffer

            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: buffer.format)
            oneShotPlayers[sound] = player
        }
    }

    private func preloadLoops() {
        for loop in LoopID.allCases {
            guard let url = bundleURL(filename: loop.filename, subdirectory: loop.bundleSubdirectory) else {
                log.info("audio loop missing — \(loop.filename, privacy: .public)")
                continue
            }
            guard let buffer = loadBuffer(url: url) else { continue }
            loopBuffers[loop] = buffer

            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: buffer.format)
            loopPlayers[loop] = player
        }
    }

    private func startEngine() {
        engine.prepare()
        do {
            try engine.start()
        } catch {
            log.error("AVAudioEngine failed to start: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func bundleURL(filename: String, subdirectory: String) -> URL? {
        // Try subdirectory first (folder reference); fall back to flat lookup (group import).
        let stem = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        if let url = Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: subdirectory) {
            return url
        }
        return Bundle.main.url(forResource: stem, withExtension: ext)
    }

    private func loadBuffer(url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                log.error("failed to allocate PCM buffer for \(url.lastPathComponent, privacy: .public)")
                return nil
            }
            try file.read(into: buffer)
            return buffer
        } catch {
            log.error("failed to load \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func play(_ sound: SoundID) {
        guard masterEnabled else { return }
        guard let player = oneShotPlayers[sound],
              let buffer = oneShotBuffers[sound] else { return }
        // Stop in-flight play to avoid queueing overlapping copies on rapid taps.
        if player.isPlaying { player.stop() }
        player.volume = sound.gain
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        if !engine.isRunning { try? engine.start() }
        player.play()
    }

    /// Idempotent — no-op if loop is already running.
    func startLoop(_ loop: LoopID) {
        guard masterEnabled else { return }
        guard !loopsRunning.contains(loop) else { return }
        guard let player = loopPlayers[loop],
              let buffer = loopBuffers[loop] else { return }
        player.volume = loop.gain
        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        if !engine.isRunning { try? engine.start() }
        player.play()
        loopsRunning.insert(loop)
    }

    func stopLoop(_ loop: LoopID) {
        guard loopsRunning.contains(loop) else { return }
        loopPlayers[loop]?.stop()
        loopsRunning.remove(loop)
    }

    /// Explicit stop on background avoids a click on resume.
    func stopAll() {
        for player in oneShotPlayers.values where player.isPlaying { player.stop() }
        for loop in loopsRunning {
            loopPlayers[loop]?.stop()
        }
        loopsRunning.removeAll()
    }
}
