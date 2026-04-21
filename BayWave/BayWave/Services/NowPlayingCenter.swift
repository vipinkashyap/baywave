import Foundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

@MainActor
enum NowPlayingCenter {
    private static var lastArtworkURL: URL?

    static func update(station: Station?, label: String?, artworkURL: URL?, isPlaying: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = station?.name ?? "BayWave"
        info[MPMediaItemPropertyArtist] = label ?? (station?.city ?? "")
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if artworkURL == nil { info[MPMediaItemPropertyArtwork] = nil }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        if artworkURL != lastArtworkURL {
            lastArtworkURL = artworkURL
            if let url = artworkURL {
                Task.detached { await fetchAndSetArtwork(from: url) }
            }
        }
    }

    private static func fetchAndSetArtwork(from url: URL) async {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        await MainActor.run {
            #if canImport(UIKit)
            guard let image = UIImage(data: data) else { return }
            #elseif canImport(AppKit)
            guard let image = NSImage(data: data) else { return }
            #endif
            let art = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = art
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    static func installRemoteCommands(play: @escaping () -> Void, pause: @escaping () -> Void) {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false

        center.playCommand.addTarget { _ in play(); return .success }
        center.pauseCommand.addTarget { _ in pause(); return .success }
        center.togglePlayPauseCommand.addTarget { _ in play(); return .success }
    }
}
