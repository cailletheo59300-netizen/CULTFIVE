import SwiftUI

@main
struct LumiligneApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(app.palette.dark ? .dark : .light)
        }
    }
}

/// Accueil ou grille en cours.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            switch app.route {
            case .home:
                HomeView()
                    .transition(.opacity)
            case .game:
                if let session = app.session {
                    GameView(session: session)
                        .id(session.id)
                        .transition(.opacity)
                }
            }
            if app.preparing { LoadingVeil() }
        }
        .animation(.easeInOut(duration: 0.25), value: app.route)
        .animation(.easeInOut(duration: 0.25), value: app.session?.id)
    }
}
