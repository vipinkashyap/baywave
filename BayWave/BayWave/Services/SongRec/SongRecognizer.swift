import Foundation
import Combine
import AVFoundation

enum LookupStatus: Equatable {
    case idle, listening, checking, matched, noMatch
}

@MainActor
final class SongRecognizer: ObservableObject {
    @Published private(set) var currentSong: RecognizedSong?
    @Published private(set) var isListening: Bool = false
    @Published private(set) var status: LookupStatus = .idle

    private var engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private let processor: AudioProcessor
    private var resampler: AVAudioConverter?
    private var scratchBuffer: AVAudioPCMBuffer?

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        processor = AudioProcessor()
        processor.onLookupReady = { [weak self] sig in
            Task { [weak self] in await self?.performLookup(sig) }
        }
    }

    func start() {
        guard !isListening else { return }
        #if os(iOS)
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default,
                           options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? s.setActive(true)
        #endif

        engine = AVAudioEngine()
        let input = engine.inputNode
        #if os(iOS)
        try? input.setVoiceProcessingEnabled(false)
        #endif

        let inFormat = input.outputFormat(forBus: 0)
        NSLog("[SongRec] input format: sr=%.0f ch=%u", inFormat.sampleRate, inFormat.channelCount)
        guard inFormat.sampleRate > 0 else {
            NSLog("[SongRec] inputNode has invalid format; aborting start")
            return
        }

        // Pre-create the resampler and output buffer so the audio thread can
        // reuse them on every tap invocation — no per-buffer allocations.
        let capturedTarget = targetFormat
        resampler = AVAudioConverter(from: inFormat, to: capturedTarget)
        let bufferCapacity = AVAudioFrameCount(
            Double(4096) * 16000.0 / inFormat.sampleRate
        ) + 64
        scratchBuffer = AVAudioPCMBuffer(pcmFormat: capturedTarget, frameCapacity: bufferCapacity)

        let capturedResampler = resampler
        let capturedScratch = scratchBuffer
        let capturedProcessor = processor

        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { buffer, _ in
            guard let resampler = capturedResampler, let out = capturedScratch else { return }
            out.frameLength = 0
            var error: NSError?
            var supplied = false
            _ = resampler.convert(to: out, error: &error) { _, outStatus in
                if supplied { outStatus.pointee = .endOfStream; return nil }
                supplied = true
                outStatus.pointee = .haveData
                return buffer
            }
            if error != nil { return }
            guard let ch = out.floatChannelData?[0] else { return }
            let n = Int(out.frameLength)
            let floats = Array(UnsafeBufferPointer(start: ch, count: n))
            capturedProcessor.submit(floats: floats)
        }

        engine.prepare()
        do {
            try engine.start()
            isListening = true
            status = .listening
            processor.reset()
            NSLog("[SongRec] engine started")
        } catch {
            NSLog("[SongRec] engine failed: %@", error.localizedDescription)
        }
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        status = .idle
        NSLog("[SongRec] engine stopped")
    }

    func clear() {
        currentSong = nil
        status = isListening ? .listening : .idle
    }

    private func performLookup(_ sig: DecodedSignature) async {
        let peakCount = sig.bandPeaks.reduce(0) { $0 + $1.count }
        NSLog("[SongRec] lookup: samples=%u peaks=%d", sig.numberSamples, peakCount)
        guard peakCount > 0 else {
            processor.markLookupDone()
            return
        }
        status = .checking
        defer { processor.markLookupDone() }

        do {
            if let song = try await ShazamClient.recognize(signature: sig) {
                NSLog("[SongRec] MATCH: %@ — %@", song.title, song.artist)
                if currentSong != song { currentSong = song }
                status = .matched
            } else {
                NSLog("[SongRec] no match")
                if currentSong == nil { status = .noMatch } else { status = .matched }
            }
        } catch {
            NSLog("[SongRec] lookup error: %@", error.localizedDescription)
            if currentSong == nil { status = .noMatch }
        }
    }
}

/// Owns the signature generator + buffering. All mutable state is accessed only
/// on `queue`, so this class is safe to call from any thread.
final class AudioProcessor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.baywave.songrec", qos: .userInitiated)
    private let generator = SignatureGenerator()
    private var pendingI16: [Int16] = []
    private var samplesSinceLastLookup = 0
    private var lookupInFlight = false

    private let lookupEveryNSamples = 12 * 16000
    private let maxBufferedSamples = 20 * 16000

    var onLookupReady: ((DecodedSignature) -> Void)?

    func reset() {
        queue.async {
            self.generator.reset()
            self.pendingI16.removeAll()
            self.samplesSinceLastLookup = 0
            self.lookupInFlight = false
        }
    }

    func markLookupDone() {
        queue.async { self.lookupInFlight = false }
    }

    func submit(floats: [Float]) {
        queue.async { [floats] in
            self.pendingI16.reserveCapacity(self.pendingI16.count + floats.count)
            for f in floats {
                let c = max(-1.0, min(1.0, f))
                self.pendingI16.append(Int16(c * 32767))
            }

            var idx = 0
            while idx + 128 <= self.pendingI16.count {
                let chunk = Array(self.pendingI16[idx..<idx+128])
                self.generator.feed(chunk128: chunk)
                idx += 128
                self.samplesSinceLastLookup += 128
            }
            if idx > 0 { self.pendingI16.removeFirst(idx) }
            if self.pendingI16.count > self.maxBufferedSamples {
                self.pendingI16.removeFirst(self.pendingI16.count - self.maxBufferedSamples)
            }

            if self.samplesSinceLastLookup >= self.lookupEveryNSamples, !self.lookupInFlight {
                self.samplesSinceLastLookup = 0
                self.lookupInFlight = true
                let snapshot = self.generator.signature
                self.onLookupReady?(snapshot)
            }
        }
    }
}
