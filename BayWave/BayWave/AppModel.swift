import Foundation
import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    let stations = StationStore()
    let player = PlayerEngine()
    let recognizer = SongRecognizer()

    @AppStorage("lastStationID") private var lastStationID: String = ""

    @Published var isPlaying: Bool = false
    @Published var selectedRegion: String = ""
    private var cancellables: Set<AnyCancellable> = []

    init() {
        NSLog("[Boot] AppModel.init begin")
        stations.loadBundled()
        NSLog("[Boot] Loaded %d stations", stations.stations.count)
        selectedRegion = stations.stations.first?.region ?? ""

        // Forward nested ObservableObject change signals so SwiftUI views
        // observing AppModel re-render when player/recognizer state changes.
        player.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        recognizer.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        stations.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        player.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] playing in
                guard let self else { return }
                self.isPlaying = playing
                if playing {
                    self.recognizer.start()
                } else {
                    self.recognizer.stop()
                }
                let song = self.recognizer.currentSong
                NowPlayingCenter.update(
                    station: self.player.currentStation,
                    label: song.map { "\($0.title) — \($0.artist)" },
                    artworkURL: song?.artworkURL,
                    isPlaying: playing
                )
            }
            .store(in: &cancellables)

        recognizer.$currentSong
            .receive(on: RunLoop.main)
            .sink { [weak self] song in
                guard let self else { return }
                NowPlayingCenter.update(
                    station: self.player.currentStation,
                    label: song.map { "\($0.title) — \($0.artist)" },
                    artworkURL: song?.artworkURL,
                    isPlaying: self.isPlaying
                )
            }
            .store(in: &cancellables)

        NowPlayingCenter.installRemoteCommands(
            play: { [weak self] in self?.player.togglePlayPause() },
            pause: { [weak self] in self?.player.togglePlayPause() }
        )

        NSLog("[Boot] AppModel.init end")

        Task {
            await stations.refreshFromRadioBrowserIfStale()
            NSLog("[Boot] stations refreshed, count=%d, lastStationID=%@", stations.stations.count, lastStationID)
            if let last = stations.stations.first(where: { $0.id == lastStationID }) {
                play(last)
            }
        }
    }

    func play(_ station: Station) {
        lastStationID = station.id
        selectedRegion = station.region
        recognizer.clear()
        player.play(station)
    }

    func togglePlayPause() {
        player.togglePlayPause()
    }

    var regions: [String] {
        var seen: [String] = []
        for s in stations.stations where !seen.contains(s.region) { seen.append(s.region) }
        return seen
    }

    func stations(in region: String) -> [Station] {
        stations.stations.filter { $0.region == region }
    }

    func playNext() { step(by: +1) }
    func playPrevious() { step(by: -1) }

    private func step(by delta: Int) {
        guard let current = player.currentStation else {
            if let first = stations.stations.first { play(first) }
            return
        }
        let siblings = stations(in: current.region)
        guard !siblings.isEmpty else { return }
        let idx = siblings.firstIndex(of: current) ?? 0
        let next = siblings[((idx + delta) % siblings.count + siblings.count) % siblings.count]
        play(next)
    }
}
