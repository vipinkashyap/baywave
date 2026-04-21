import Foundation

/// Shazam-style Hanning multipliers for 2048 samples.
/// Matches songrec: `0.5 * (1 - cos(2π (n+1) / 2049))`, n in 0..<2048.
enum HannWindow {
    static let size = 2048
    static let multipliers: [Float] = (0..<size).map { n in
        Float(0.5 * (1.0 - cos(2.0 * .pi * Double(n + 1) / 2049.0)))
    }
}
