import Foundation
import Combine

@MainActor
final class StationStore: ObservableObject {
    @Published private(set) var stations: [Station] = []
    @Published private(set) var source: Source = .bundle

    enum Source { case bundle, remote }

    func loadBundled() {
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(StationsFile.self, from: data) else {
            return
        }
        stations = file.stations
        source = .bundle
    }

    func refreshFromRadioBrowserIfStale(olderThan seconds: TimeInterval = 60 * 60 * 24 * 30) async {
        let fm = FileManager.default
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let attrs = try? fm.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) > seconds else { return }
        if let remote = try? await RadioBrowserAPI.bayAreaStations(), !remote.isEmpty {
            self.stations = remote
            self.source = .remote
        }
    }
}
