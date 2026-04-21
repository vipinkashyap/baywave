import Foundation
import Accelerate

/// Port of songrec's fingerprinting algorithm.
/// Feed chunks of 128 Int16 samples at 16 kHz mono. After ~46 FFT passes (≈0.37s)
/// peaks start accumulating. ~12 seconds is the sweet spot before lookup.
final class SignatureGenerator {
    private var ringInt16 = [Int16](repeating: 0, count: 2048)
    private var ringIndex = 0

    private var reordered = [Float](repeating: 0, count: 2048)

    // 256-slot ring of 1025-bin FFT magnitudes (squared).
    private var fftOutputs: [[Float]] = Array(repeating: [Float](repeating: 0, count: 1025), count: 256)
    private var fftIndex = 0

    // Peak-spread version of the above, same ring size.
    private var spreadOutputs: [[Float]] = Array(repeating: [Float](repeating: 0, count: 1025), count: 256)
    private var spreadIndex = 0

    private var numSpreadDone: UInt32 = 0

    private(set) var signature = DecodedSignature()

    // FFT setup (real FFT of 2048 samples).
    private let log2n = vDSP_Length(11)
    private let fftSetup: FFTSetup

    init() {
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func reset() {
        ringInt16 = [Int16](repeating: 0, count: 2048)
        ringIndex = 0
        for i in 0..<256 {
            fftOutputs[i] = [Float](repeating: 0, count: 1025)
            spreadOutputs[i] = [Float](repeating: 0, count: 1025)
        }
        fftIndex = 0
        spreadIndex = 0
        numSpreadDone = 0
        signature = DecodedSignature()
    }

    /// Feed a chunk of exactly 128 Int16 samples.
    func feed(chunk128 samples: [Int16]) {
        precondition(samples.count == 128)

        // 1. Copy into ring buffer
        for i in 0..<128 {
            ringInt16[(ringIndex + i) & 2047] = samples[i]
        }
        ringIndex = (ringIndex + 128) & 2047

        // 2. Reorder + apply Hann window
        let hann = HannWindow.multipliers
        for i in 0..<2048 {
            reordered[i] = Float(ringInt16[(i + ringIndex) & 2047]) * hann[i]
        }

        // 3. Real FFT → magnitudes squared, normalized
        computeFFTMagnitudes(into: &fftOutputs[fftIndex])
        fftIndex = (fftIndex + 1) & 255

        // 4. Peak spreading
        doPeakSpreading()
        numSpreadDone += 1

        // 5. Peak recognition (after warmup)
        if numSpreadDone >= 46 {
            doPeakRecognition()
        }

        signature.numberSamples += 128
    }

    // MARK: - FFT

    private func computeFFTMagnitudes(into bins: inout [Float]) {
        // Pack 2048 reals into 1024 complex via vDSP_ctoz.
        var realp = [Float](repeating: 0, count: 1024)
        var imagp = [Float](repeating: 0, count: 1024)

        reordered.withUnsafeMutableBufferPointer { rePtr in
            rePtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: 1024) { complexPtr in
                realp.withUnsafeMutableBufferPointer { realpPtr in
                    imagp.withUnsafeMutableBufferPointer { imagpPtr in
                        var split = DSPSplitComplex(realp: realpPtr.baseAddress!, imagp: imagpPtr.baseAddress!)
                        vDSP_ctoz(complexPtr, 2, &split, 1, 1024)
                        vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                    }
                }
            }
        }

        // vDSP packed real FFT: realp[0] = DC, imagp[0] = Nyquist.
        // Bins 1..1023 are (realp[i], imagp[i]). Bin 0 = DC, bin 1024 = Nyquist.
        // vDSP outputs are 2× the mathematical FFT; magnitude-squared → 4×.
        // Rust divides mag² by (1<<17); to match, divide by 4 × (1<<17) = 1<<19.
        let scale: Float = 1.0 / Float(1 << 19)
        let floor: Float = 0.0000000001

        let dc = realp[0]
        bins[0] = max(dc * dc * scale * 0.25, floor) // DC bin has no doubling

        for i in 1..<1024 {
            let re = realp[i], im = imagp[i]
            bins[i] = max((re * re + im * im) * scale, floor)
        }

        let nyq = imagp[0]
        bins[1024] = max(nyq * nyq * scale * 0.25, floor) // Nyquist bin likewise
    }

    // MARK: - Peak spreading

    private func doPeakSpreading() {
        let srcIdx = (fftIndex + 255) & 255
        var spread = fftOutputs[srcIdx] // copy

        // Frequency-domain max over window [p, p+1, p+2]
        for p in 0...1022 {
            spread[p] = max(spread[p], max(spread[p + 1], spread[p + 2]))
        }

        spreadOutputs[spreadIndex] = spread

        // Time-domain spread: push max into FFTs at offsets -1, -3, -6
        let copy = spread
        for offset in [1, 3, 6] {
            let idx = (spreadIndex + 256 - offset) & 255
            for p in 0...1024 {
                spreadOutputs[idx][p] = max(spreadOutputs[idx][p], copy[p])
            }
        }

        spreadIndex = (spreadIndex + 1) & 255
    }

    // MARK: - Peak recognition

    private func doPeakRecognition() {
        let fftM46 = fftOutputs[(fftIndex + 256 - 46) & 255]
        let fftM49 = spreadOutputs[(spreadIndex + 256 - 49) & 255]

        for bin in 10...1014 {
            // Magnitude threshold and vs neighbor at bin-1
            guard fftM46[bin] >= 1.0 / 64.0,
                  fftM46[bin] >= fftM49[bin - 1] else { continue }

            // Freq-domain local max vs a specific neighbor set
            var maxNeighbor: Float = 0
            for off in [-10, -7, -4, -3, 1, 2, 5, 8] {
                let idx = bin + off
                if idx >= 0 && idx <= 1024 {
                    maxNeighbor = max(maxNeighbor, fftM49[idx])
                }
            }
            guard fftM46[bin] > maxNeighbor else { continue }

            // Time-domain local max vs a specific neighbor set of adjacent FFTs
            var maxOther: Float = maxNeighbor
            for off in [-53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249] {
                let otherIdx = (Int(spreadIndex) + off + 256 * 4) & 255
                maxOther = max(maxOther, spreadOutputs[otherIdx][bin - 1])
            }
            guard fftM46[bin] > maxOther else { continue }

            // It's a peak.
            let passNum = numSpreadDone - 46
            let logMag = max(log(fftM46[bin]), 1.0 / 64.0) * 1477.3 + 6144.0
            let logMagBefore = max(log(fftM46[bin - 1]), 1.0 / 64.0) * 1477.3 + 6144.0
            let logMagAfter = max(log(fftM46[bin + 1]), 1.0 / 64.0) * 1477.3 + 6144.0

            let v1 = logMag * 2 - logMagBefore - logMagAfter
            guard v1 > 0 else { continue }
            let v2 = (logMagAfter - logMagBefore) * 32.0 / v1

            let correctedBin = UInt16(Int32(bin) * 64 + Int32(v2))
            let freqHz = Float(correctedBin) * (16000.0 / 2.0 / 1024.0 / 64.0)

            let band: FrequencyBand
            switch Int(freqHz) {
            case 250...519: band = .b250_520
            case 520...1449: band = .b520_1450
            case 1450...3499: band = .b1450_3500
            case 3500...5500: band = .b3500_5500
            default: continue
            }

            signature.bandPeaks[band.rawValue].append(
                FrequencyPeak(
                    fftPassNumber: passNum,
                    peakMagnitude: UInt16(clamping: Int(logMag)),
                    correctedPeakFrequencyBin: correctedBin
                )
            )
        }
    }
}
