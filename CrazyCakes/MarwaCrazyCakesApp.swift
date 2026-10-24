import SwiftUI

@main
struct MarwaCrazyCakesApp: App {
    @StateObject private var store = ContentStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootContainer(store: store)
                .task {
                    await store.bootstrap()
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task { await store.checkForUpdates() }
                }
        }
    }
}

/// Splash + error + app gate, mirroring the boot flow in App.tsx.
struct RootContainer: View {
    @ObservedObject var store: ContentStore
    @State private var splashElapsed = false

    var body: some View {
        Group {
            if let message = store.errorMessage {
                BootstrapErrorView(message: message) {
                    Task { await store.retry() }
                }
            } else if !store.ready || !splashElapsed {
                SplashView(loading: !store.ready)
            } else {
                AppRoot(store: store)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                splashElapsed = true
            }
        }
    }
}
