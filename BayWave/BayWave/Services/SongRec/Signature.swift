import Foundation

enum FrequencyBand: Int {
    case b250_520 = 0
    case b520_1450 = 1
    case b1450_3500 = 2
    case b3500_5500 = 3
}

struct FrequencyPeak {
    let fftPassNumber: UInt32
    let peakMagnitude: UInt16
    let correctedPeakFrequencyBin: UInt16
}

struct DecodedSignature {
    var sampleRateHz: UInt32 = 16000
    var numberSamples: UInt32 = 0
    var bandPeaks: [[FrequencyPeak]] = Array(repeating: [], count: 4)
}

/// Writes a Shazam-format signature blob. Port of signature_format.rs `encode_to_binary`.
enum SignatureEncoder {
    static let dataURIPrefix = "data:audio/vnd.shazam.sig;base64,"

    static func encodeToBinary(_ sig: DecodedSignature) -> Data {
        var out = Data()

        func writeU32(_ v: UInt32, into d: inout Data) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
        }
        func writeU16(_ v: UInt16, into d: inout Data) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { d.append(contentsOf: $0) }
        }

        // Header (48 bytes). CRC and size patched in at end.
        writeU32(0xcafe2580, into: &out)                 // magic1
        writeU32(0, into: &out)                          // crc32 (patched)
        writeU32(0, into: &out)                          // size_minus_header (patched)
        writeU32(0x94119c00, into: &out)                 // magic2
        writeU32(0, into: &out); writeU32(0, into: &out); writeU32(0, into: &out) // void1
        let srID: UInt32 = {
            switch sig.sampleRateHz {
            case 8000: return 1
            case 11025: return 2
            case 16000: return 3
            case 32000: return 4
            case 44100: return 5
            case 48000: return 6
            default: return 3
            }
        }()
        writeU32(srID << 27, into: &out)                 // shifted_sample_rate_id
        writeU32(0, into: &out); writeU32(0, into: &out) // void2
        let plusDiv = sig.numberSamples + UInt32(Float(sig.sampleRateHz) * 0.24)
        writeU32(plusDiv, into: &out)                    // number_samples_plus_divided_sample_rate
        writeU32((15 << 19) + 0x40000, into: &out)       // fixed_value

        // TLV preamble
        writeU32(0x40000000, into: &out)
        writeU32(0, into: &out)                          // size_minus_header (patched)

        // Per-band peak lists
        for (bandIdx, peaks) in sig.bandPeaks.enumerated() where !peaks.isEmpty {
            var peakBuf = Data()
            var lastPass: UInt32 = 0
            for p in peaks {
                precondition(p.fftPassNumber >= lastPass)
                if p.fftPassNumber - lastPass >= 255 {
                    peakBuf.append(0xff)
                    writeU32(p.fftPassNumber, into: &peakBuf)
                    lastPass = p.fftPassNumber
                }
                peakBuf.append(UInt8(p.fftPassNumber - lastPass))
                writeU16(p.peakMagnitude, into: &peakBuf)
                writeU16(p.correctedPeakFrequencyBin, into: &peakBuf)
                lastPass = p.fftPassNumber
            }
            writeU32(0x60030040 + UInt32(bandIdx), into: &out)
            writeU32(UInt32(peakBuf.count), into: &out)
            out.append(peakBuf)
            let pad = (4 - peakBuf.count % 4) % 4
            for _ in 0..<pad { out.append(0) }
        }

        let totalSize = UInt32(out.count)
        let sizeMinusHeader = totalSize - 48

        // Patch sizes
        patchU32(&out, at: 8, value: sizeMinusHeader)
        patchU32(&out, at: 48 + 4, value: sizeMinusHeader)

        // Patch CRC32 over everything after the first 8 bytes (magic1 + crc32 field).
        let crc = CRC32.compute(out.suffix(from: 8))
        patchU32(&out, at: 4, value: crc)

        return out
    }

    static func encodeToURI(_ sig: DecodedSignature) -> String {
        let data = encodeToBinary(sig)
        return dataURIPrefix + data.base64EncodedString()
    }

    private static func patchU32(_ data: inout Data, at offset: Int, value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { bytes in
            for i in 0..<4 {
                data[offset + i] = bytes[i]
            }
        }
    }
}

/// IEEE 802.3 CRC-32, same polynomial zlib / Ethernet uses.
enum CRC32 {
    private static let table: [UInt32] = {
        var t = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            t[i] = c
        }
        return t
    }()

    static func compute<S: Sequence>(_ bytes: S) -> UInt32 where S.Element == UInt8 {
        var crc: UInt32 = 0xFFFFFFFF
        for b in bytes {
            crc = table[Int((crc ^ UInt32(b)) & 0xff)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
