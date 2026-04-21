import Foundation

enum RadioBrowserAPI {
    private static let host = "https://de1.api.radio-browser.info"

    struct RBStation: Decodable {
        let stationuuid: String
        let name: String
        let url_resolved: String
        let tags: String?
        let state: String?
    }

    static func bayAreaStations() async throws -> [Station] {
        let url = URL(string: "\(host)/json/stations/search?state=California&tagList=bay-area&hidebroken=true&limit=100")!
        var req = URLRequest(url: url)
        req.setValue("BayWave/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode([RBStation].self, from: data)
        return decoded.compactMap { s -> Station? in
            guard let u = URL(string: s.url_resolved) else { return nil }
            let genre = s.tags?.split(separator: ",").first.map(String.init) ?? "radio"
            return Station(
                id: s.stationuuid,
                name: s.name,
                callLetters: String(s.name.prefix(4)).uppercased(),
                frequency: nil,
                genre: genre,
                streamURL: u,
                description: s.state ?? "",
                city: "",
                region: "Bay Area"
            )
        }
    }
}
