import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        let _ = NSLog("[Boot] RootView body (stations=%d, playing=%@)", app.stations.stations.count, app.isPlaying ? "yes" : "no")
        ZStack {
            LinearGradient(
                colors: [Theme.navy, Theme.navyDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                AppHeader()
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                NowPlayingCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 14)

                StationListView()
            }
        }
        .foregroundStyle(Theme.text)
    }
}

private struct AppHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: 22)
            Text("BayWave")
                .font(.system(size: 16, weight: .semibold, design: .serif))
            Spacer()
        }
    }
}
