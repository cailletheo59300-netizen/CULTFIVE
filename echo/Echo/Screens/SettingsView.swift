import SwiftUI
import EchoCore

/// Réglages : son, vibrations, sensibilité, tutoriel, confidentialité des pubs, achats, liens légaux.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false

    /// Pages du site (même site que Brainlix, rubrique Écho).
    private static let site = URL(string: "https://brainlix.site/echo")!

    var body: some View {
        NavigationStack {
            Form {
                Section("Jeu") {
                    Toggle("Son", isOn: binding(\.soundOn))
                    Toggle("Vibrations", isOn: binding(\.hapticsOn))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sensibilité du doigt : \(Int((app.profile.sensitivity * 100).rounded())) %")
                        Slider(value: binding(\.sensitivity), in: 0.7...2.0, step: 0.05)
                    }
                    Button("Comment jouer") { showRules = true }
                    Button("Revoir les conseils du début") {
                        app.update { $0.tutorialDone = false }
                    }
                }
                Section("Achats") {
                    Button("Restaurer les achats") {
                        Task { await app.store.restore() }
                    }
                    if let message = app.store.message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if app.ads.privacyOptionsAvailable {
                    Section("Pubs") {
                        Button("Confidentialité des pubs") {
                            Task { await app.ads.presentPrivacyOptions() }
                        }
                    }
                }
                Section("Infos") {
                    Link("Aide et contact", destination: Self.site.appendingPathComponent("support"))
                    Link("Confidentialité", destination: Self.site.appendingPathComponent("confidentialite"))
                    Link("Conditions d'utilisation", destination: Self.site.appendingPathComponent("conditions"))
                    LabeledContent("Version", value: Self.version)
                    if app.ads.testAds {
                        LabeledContent("Pubs", value: "pubs de test")
                    }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.bold()
                }
            }
            .sheet(isPresented: $showRules) { RulesView() }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Profile, Value>) -> Binding<Value> {
        Binding(get: { app.profile[keyPath: keyPath] }, set: { value in app.update { $0[keyPath: keyPath] = value } })
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

/// Règles du jeu en quelques lignes.
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                rule("hand.draw.fill", "Glisse ton doigt n'importe où sur l'écran : le point suit ton geste.")
                rule("circle.circle.fill", "Attrape les 3 orbes dorés, l'un après l'autre. Le cercle discret montre le suivant.")
                rule("figure.walk.motion", "À la manche suivante, ton fantôme rejoue exactement ta manche précédente. Puis 2 fantômes, puis 3…")
                rule("xmark.octagon.fill", "Touche un fantôme et c'est fini. Ils s'allument un court instant après le départ.")
                rule("bolt.fill", "Bonus : finis vite une manche, et frôle les fantômes sans les toucher (+5).")
                rule("lightbulb.fill", "Astuce : des trajets courts et propres te laissent plus de place pour la suite.")
                rule("calendar", "Défi du jour : les mêmes orbes pour tout le monde. 1 essai par jour (+2 avec une pub). Joue chaque jour pour ta série.")
            }
            .navigationTitle("Comment jouer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.bold()
                }
            }
        }
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 4)
    }
}
