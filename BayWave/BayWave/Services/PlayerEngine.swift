import Foundation
import Combine
import AVFoundation

@MainActor
final class PlayerEngine: ObservableObject {
    @Published private(set) var currentStation: Station?
    @Published private(set) var isPlaying: Bool = false

    let player: AVPlayer
    private var rateObservation: NSKeyValueObservation?

    init() {
        player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = true
        configureAudioSession()
        rateObservation = player.observe(\.rate, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in self?.isPlaying = p.rate > 0 }
        }
    }

    func play(_ station: Station) {
        NSLog("[Player] play %@", station.name)
        currentStation = station
        let item = AVPlayerItem(url: station.streamURL)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func togglePlayPause() {
        if player.rate > 0 { player.pause() } else { player.play() }
    }

    private func configureAudioSession() {
        #if os(iOS)
        // playAndRecord is set by ShazamService when mic starts. Default to playback.
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [])
        try? s.setActive(true)
        #endif
    }
}
