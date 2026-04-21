import Foundation

struct Station: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let callLetters: String
    let frequency: String?
    let genre: String
    let streamURL: URL
    let description: String
    let city: String
    let region: String
}

struct StationsFile: Codable {
    let version: Int
    let stations: [Station]
}
