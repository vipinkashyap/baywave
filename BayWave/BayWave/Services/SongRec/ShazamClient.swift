import Foundation

struct RecognizedSong: Equatable {
    let title: String
    let artist: String
    let artworkURL: URL?
    let appleMusicURL: URL?
    let shazamURL: URL?
}

enum ShazamClient {
    static let userAgents = [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
    ]

    static func recognize(signature: DecodedSignature) async throws -> RecognizedSong? {
        let uri = SignatureEncoder.encodeToURI(signature)
        // Shazam's API truncates the 64-bit ms timestamp into 32 bits; match that.
        let timestampMs = UInt32(truncatingIfNeeded: UInt64(Date().timeIntervalSince1970 * 1000))
        let numerator: Double = Double(signature.numberSamples) * 1000.0
        let samplesMs = UInt32(numerator / Double(signature.sampleRateHz))

        let body: [String: Any] = [
            "geolocation": ["altitude": 300, "latitude": 45, "longitude": 2],
            "signature": ["samplems": samplesMs, "timestamp": timestampMs, "uri": uri],
            "timestamp": timestampMs,
            "timezone": "Europe/Paris"
        ]

        let uuid1 = UUID().uuidString.uppercased()
        let uuid2 = UUID().uuidString.lowercased()
        let urlString = "https://amp.shazam.com/discovery/v5/en-US/US/web/-/tag/\(uuid1)/\(uuid2)?sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true&video=v3"
        guard let url = URL(string: urlString) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("en_US", forHTTPHeaderField: "Content-Language")
        req.setValue(userAgents.randomElement()!, forHTTPHeaderField: "User-Agent")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse {
            NSLog("[ShazamClient] status=%d bytes=%d", http.statusCode, data.count)
            if http.statusCode == 429 { return nil } // rate-limited
            if http.statusCode >= 400 { return nil }
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return parse(json: json)
    }

    private static func parse(json: [String: Any]?) -> RecognizedSong? {
        guard let track = json?["track"] as? [String: Any] else { return nil }
        let title = track["title"] as? String ?? ""
        let artist = track["subtitle"] as? String ?? ""

        var artworkURL: URL?
        if let images = track["images"] as? [String: Any],
           let cover = images["coverart"] as? String ?? images["coverarthq"] as? String {
            artworkURL = URL(string: cover)
        }

        var shazamURL: URL?
        if let share = track["share"] as? [String: Any], let href = share["href"] as? String {
            shazamURL = URL(string: href)
        }

        var appleMusicURL: URL?
        if let hub = track["hub"] as? [String: Any], let actions = hub["actions"] as? [[String: Any]] {
            for action in actions {
                if let type = action["type"] as? String, type == "applemusicopen",
                   let uri = action["uri"] as? String {
                    appleMusicURL = URL(string: uri)
                    break
                }
            }
        }

        guard !title.isEmpty else { return nil }
        return RecognizedSong(title: title, artist: artist, artworkURL: artworkURL,
                              appleMusicURL: appleMusicURL, shazamURL: shazamURL)
    }
}
