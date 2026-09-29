import SwiftUI
import CultFiveCore

@main
@MainActor
struct CultFiveApp: App {
    @State private var model = AppModel.live()
    @Environment(\.scenePhase) private var scenePhase
    /// Clair par défaut, indépendamment du réglage de l'iPhone (voir `AppAppearance`).
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .light

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Color.brand)
                .preferredColorScheme(appearance.colorScheme)
                .onOpenURL { model.handle(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { model.handle(url: url) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, model.phase == .main else { return }
            Task {
                await model.refreshDaily()
                await model.syncPending()
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .top) {
            switch model.phase {
            case .launching:
                LaunchView()
            case .onboarding:
                OnboardingFlow()
                    .transition(.opacity)
            case .main:
                MainTabView()
                    .transition(.opacity)
            case .unavailable(let message):
                UnavailableView(message: message)
            }

            if let toast = model.toast {
                Toast(text: toast).padding(.top, Space.s).zIndex(10)
            }
        }
        .animation(Motion.standard, value: model.phase)
        .task { await model.bootstrap() }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: Space.l) {
            TallyMark(strokes: [.correct, .correct, .correct, .correct, .ready], onInk: true).frame(width: 72)
            Text(Brand.name).font(.system(.title2, design: .rounded).weight(.black)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.popGradient.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chargement")
    }
}

private struct UnavailableView: View {
    @Environment(AppModel.self) private var model
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Spacer()
            Leon(pose: .sad).frame(width: 150)
            Text("Impossible de joindre \(Brand.name).").font(.cfHeadline)
            Text(message).font(.cfBody).foregroundStyle(Color.inkSoft)
            Button("Réessayer") { Task { await model.retryLaunch() } }
                .buttonStyle(.ink)
            Spacer()
        }
        .padding(.horizontal, Space.gutter)
        .background(Color.paper)
    }
}
