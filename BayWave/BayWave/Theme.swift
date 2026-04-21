import SwiftUI

enum Theme {
    static let navy = Color(red: 0x0A/255, green: 0x16/255, blue: 0x28/255)
    static let navyDeep = Color(red: 0x05/255, green: 0x0B/255, blue: 0x17/255)
    static let amber = Color(red: 0xE8/255, green: 0xA3/255, blue: 0x3D/255)
    static let amberSoft = Color(red: 0xE8/255, green: 0xA3/255, blue: 0x3D/255).opacity(0.18)
    static let text = Color.white.opacity(0.92)
    static let mutedText = Color.white.opacity(0.55)
    static let faintLine = Color.white.opacity(0.06)

    static let displayLarge = Font.system(size: 32, weight: .semibold, design: .serif)
    static let display = Font.system(size: 22, weight: .semibold, design: .serif)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
    static let pill = Font.system(size: 10, weight: .semibold, design: .rounded)

    // Map a station's genre string to a distinctive tint.
    static func genreTint(_ genre: String) -> Color {
        switch genre.lowercased() {
        case "jazz", "classical": return Color(red: 0.75, green: 0.55, blue: 0.95)
        case "indie", "college", "community": return Color(red: 0.55, green: 0.85, blue: 0.72)
        case "public", "news": return Color(red: 0.55, green: 0.75, blue: 0.95)
        case "rock", "metal": return Color(red: 0.95, green: 0.55, blue: 0.45)
        case "electronic", "ambient", "hiphop", "dance": return Color(red: 0.62, green: 0.70, blue: 1.0)
        case "specialty", "americana", "folk", "country", "reggae", "world": return Color(red: 0.95, green: 0.75, blue: 0.48)
        case "pop", "adult contemporary": return Color(red: 0.95, green: 0.65, blue: 0.80)
        default: return amber
        }
    }
}
