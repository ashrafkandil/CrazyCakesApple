import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: Destination = .home

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(Destination.allCases, selection: $selection) { destination in
                    Label(destination.title, systemImage: destination.symbol)
                        .tag(destination)
                }
                .navigationTitle("Marwa Crazy Cakes")
            } detail: {
                screen(for: selection)
            }
            .tint(Palette.primary)
        } else {
            TabView(selection: $selection) {
                ForEach(Destination.allCases) { destination in
                    screen(for: destination)
                        .tabItem {
                            Label(destination.title, systemImage: destination.symbol)
                        }
                        .tag(destination)
                }
            }
            .tint(Palette.primary)
        }
    }

    @ViewBuilder
    private func screen(for destination: Destination) -> some View {
        switch destination {
        case .home:
            HomeScreen(onNavigate: { selection = $0 })
        case .about:
            AboutScreen(onNavigate: { selection = $0 })
        case .gallery:
            GalleryScreen(onNavigate: { selection = $0 })
        case .reviews:
            ReviewsScreen()
        case .pricing:
            PricingScreen(onNavigate: { selection = $0 })
        case .contact:
            ContactScreen()
        }
    }
}

#Preview {
    ContentView()
}
