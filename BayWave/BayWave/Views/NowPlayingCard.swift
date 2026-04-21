import SwiftUI

struct NowPlayingCard: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        let station = app.player.currentStation
        let song = app.recognizer.currentSong
        let status = app.recognizer.status
        let tint = station.map { Theme.genreTint($0.genre) } ?? Theme.amber

        HStack(alignment: .center, spacing: 16) {
            artwork(tint: tint, song: song)
                .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 4) {
                primaryText(station: station, song: song)
                secondaryText(station: station, song: song, status: status)

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button {
                        app.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.mutedText)
                    }
                    .buttonStyle(.plain)
                    .disabled(station == nil)

                    Button {
                        app.togglePlayPause()
                    } label: {
                        Image(systemName: app.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(station == nil)

                    Button {
                        app.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.mutedText)
                    }
                    .buttonStyle(.plain)
                    .disabled(station == nil)

                    if let dest = openDestination(song: song) {
                        Button {
                            openURL(dest.url)
                        } label: {
                            Label(dest.label, systemImage: dest.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(tint.opacity(0.15)))
                                .foregroundStyle(tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(height: 96)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let dest = openDestination(song: song) { openURL(dest.url) }
        }
    }

    // MARK: - Text

    @ViewBuilder
    private func primaryText(station: Station?, song: RecognizedSong?) -> some View {
        if let song {
            Text(song.title)
                .font(Theme.display)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        } else if let station {
            Text(station.name)
                .font(Theme.display)
                .lineLimit(2)
        } else {
            Text("BayWave")
                .font(Theme.display)
        }
    }

    @ViewBuilder
    private func secondaryText(station: Station?, song: RecognizedSong?, status: LookupStatus) -> some View {
        if let song {
            Text(song.artist)
                .font(Theme.body)
                .foregroundStyle(Theme.mutedText)
                .lineLimit(1)
        } else if station != nil {
            HStack(spacing: 6) {
                if status == .checking {
                    ProgressView().controlSize(.mini).tint(Theme.mutedText)
                }
                Text(statusLine(status: status))
                    .font(Theme.body)
                    .foregroundStyle(Theme.mutedText)
            }
        } else {
            Text("Pick a station")
                .font(Theme.body)
                .foregroundStyle(Theme.mutedText)
        }
    }

    private func statusLine(status: LookupStatus) -> String {
        switch status {
        case .idle: return "Paused"
        case .listening: return "Listening for a song…"
        case .checking: return "Checking Shazam…"
        case .matched: return "Listening for a song…"
        case .noMatch: return "Couldn't recognize — keep listening"
        }
    }

    // MARK: - Artwork

    @ViewBuilder
    private func artwork(tint: Color, song: RecognizedSong?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.25), tint.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                )

            if let url = song?.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Image(systemName: "music.note")
                            .font(.system(size: 30))
                            .foregroundStyle(tint)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 30))
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, options: .repeating, isActive: app.isPlaying)
            }
        }
    }

    // MARK: - Open destinations

    private struct Destination {
        let url: URL
        let label: String
        let icon: String
    }

    private func openDestination(song: RecognizedSong?) -> Destination? {
        guard let song else { return nil }
        if let am = song.appleMusicURL {
            return Destination(url: am, label: "Open in Music", icon: "music.note")
        }
        if let sz = song.shazamURL {
            return Destination(url: sz, label: "Open in Shazam", icon: "waveform.badge.magnifyingglass")
        }
        return nil
    }
}
