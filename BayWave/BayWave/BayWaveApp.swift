import SwiftUI

@main
struct BayWaveApp: App {
    @StateObject private var app: AppModel = {
        NSLog("[Boot] BayWaveApp constructing AppModel…")
        let m = AppModel()
        NSLog("[Boot] AppModel constructed")
        return m
    }()

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra {
            RootView()
                .environmentObject(app)
                .frame(width: 340, height: 480)
        } label: {
            Image(systemName: app.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
        }
        .menuBarExtraStyle(.window)

        Window("BayWave", id: "main") {
            RootView()
                .environmentObject(app)
                .frame(minWidth: 360, minHeight: 520)
        }
        #else
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
        }
        #endif
    }
}
