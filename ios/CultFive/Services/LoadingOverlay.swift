import SwiftUI
import UIKit

/// Voile « Chargement… » au-dessus de tout, plein écrans compris, pendant une action qui fait attendre (une pub qui
/// se charge, une récompense que le serveur confirme). Il bloque les appuis : impossible de lancer deux fois la même
/// chose. Il n'apparaît qu'après un court instant, pour ne pas clignoter quand tout va vite.
@MainActor
enum LoadingOverlay {
    private static var window: UIWindow?

    static func show(_ text: String) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        let host = UIHostingController(rootView: LoadingVeil(text: text))
        host.view.backgroundColor = .clear
        let veil = window ?? UIWindow(windowScene: scene)
        veil.windowLevel = .alert + 1
        veil.backgroundColor = .clear
        veil.rootViewController = host
        veil.isHidden = false
        window = veil
    }

    static func hide() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}

private struct LoadingVeil: View {
    let text: String
    @State private var visible = false

    var body: some View {
        ZStack {
            Color.black.opacity(visible ? 0.28 : 0).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().controlSize(.large).tint(.white)
                Text(text)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.94)
        }
        // Un léger délai : si la pub est déjà prête, le voile n'apparaît même pas.
        .task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.easeOut(duration: 0.18)) { visible = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
