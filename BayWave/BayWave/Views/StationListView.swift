import SwiftUI

struct StationListView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        VStack(spacing: 0) {
            RegionTabs(regions: app.regions, selected: $app.selectedRegion)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(app.stations(in: app.selectedRegion)) { station in
                        StationRow(
                            station: station,
                            isActive: app.player.currentStation?.id == station.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { app.play(station) }
                    }
                    Spacer(minLength: 24)
                }
            }
        }
    }
}

private struct RegionTabs: View {
    let regions: [String]
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(regions, id: \.self) { region in
                let active = region == selected
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selected = region
                    }
                } label: {
                    Text(region)
                        .font(.system(size: 13, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? Theme.navyDeep : Theme.mutedText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(active ? Theme.amber : Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

private struct StationRow: View {
    let station: Station
    let isActive: Bool

    var body: some View {
        let tint = Theme.genreTint(station.genre)

        HStack(spacing: 14) {
            Rectangle()
                .fill(isActive ? tint : Color.clear)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if !station.description.isEmpty {
                    Text(station.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mutedText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            GenrePill(genre: station.genre, tint: tint)

            if isActive {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(tint)
                    .padding(.trailing, 14)
            } else {
                Color.clear.frame(width: 0).padding(.trailing, 14)
            }
        }
        .padding(.vertical, 11)
        .background(isActive ? tint.opacity(0.08) : Color.clear)
    }
}

private struct GenrePill: View {
    let genre: String
    let tint: Color

    var body: some View {
        Text(genre.capitalized)
            .font(Theme.pill)
            .tracking(0.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}
