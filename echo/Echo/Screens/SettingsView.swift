import SwiftUI
import EchoCore

/// Réglages, dans le style du jeu : doigt (avec zone d'essai), son et vibrations, aide, achats, infos.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false

    /// Pages du site (même site que Brainlix, rubrique Écho).
    private static let site = URL(string: "https://brainlix.site/echo")!

    var body: some View {
        NavigationStack {
            ZStack {
                app.theme.menuBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        controlCard
                        card("Son et vibrations", icon: "speaker.wave.2.fill") {
                            GameToggle(title: "Son", icon: "music.note", isOn: binding(\.soundOn))
                            Divider().overlay(Theme.stroke)
                            GameToggle(title: "Vibrations", icon: "iphone.radiowaves.left.and.right", isOn: binding(\.hapticsOn))
                        }
                        card("Aide", icon: "questionmark.circle.fill") {
                            row("Comment jouer", icon: "book.fill") { showRules = true }
                            Divider().overlay(Theme.stroke)
                            row(app.profile.tutorialDone ? "Revoir les conseils du début" : "Conseils du début : activés",
                                icon: "lightbulb.fill") {
                                app.update { $0.tutorialDone = false }
                            }
                        }
                        card("Achats", icon: "bag.fill") {
                            row("Restaurer les achats", icon: "arrow.clockwise") {
                                Task { await app.store.restore() }
                            }
                            if let message = app.store.message {
                                Text(message).font(Theme.body(13, .medium)).foregroundStyle(Theme.secondary)
                            }
                            if app.ads.privacyOptionsAvailable {
                                Divider().overlay(Theme.stroke)
                                row("Confidentialité des pubs", icon: "hand.raised.fill") {
                                    Task { await app.ads.presentPrivacyOptions() }
                                }
                            }
                        }
                        card("Infos", icon: "info.circle.fill") {
                            link("Aide et contact", "support")
                            Divider().overlay(Theme.stroke)
                            link("Confidentialité", "confidentialite")
                            Divider().overlay(Theme.stroke)
                            link("Conditions d'utilisation", "conditions")
                        }
                        Text("Écho \(Self.version)" + (app.ads.testAds ? " · pubs de test" : ""))
                            .font(Theme.body(13, .medium))
                            .foregroundStyle(Theme.secondary)
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(Theme.body(17, .bold))
                }
            }
            .sheet(isPresented: $showRules) { RulesView() }
        }
    }

    // MARK: Doigt

    private var controlCard: some View {
        card("Contrôle du doigt", icon: "hand.draw.fill") {
            HStack {
                Text("Précis").font(Theme.body(14, .bold)).foregroundStyle(Theme.secondary)
                Slider(value: binding(\.controlSetting), in: 0...1)
                    .tint(Theme.accent)
                Text("Rapide").font(Theme.body(14, .bold)).foregroundStyle(Theme.secondary)
            }
            Text("Doigt lent : le point suit exactement. Doigt rapide : il va plus loin. Essaie ci-dessous.")
                .font(Theme.body(13, .medium))
                .foregroundStyle(Theme.secondary)
            ControlTestPad(setting: app.profile.controlSetting, theme: app.theme)
                .frame(height: 190)
        }
    }

    // MARK: Éléments

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(Theme.body(14, .heavy))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Theme.accent)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }

    private func row(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            app.haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Theme.gold).frame(width: 26)
                Text(title).font(Theme.body(17)).foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func link(_ title: String, _ page: String) -> some View {
        Link(destination: Self.site.appendingPathComponent(page)) {
            HStack(spacing: 12) {
                Text(title).font(Theme.body(17)).foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.secondary)
            }
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

/// Interrupteur aux couleurs du jeu.
private struct GameToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Theme.gold).frame(width: 26)
                Text(title).font(Theme.body(17)).foregroundStyle(Theme.text)
            }
        }
        .tint(Theme.accent)
    }
}

/// Zone d'essai : on y déplace un point exactement comme en partie (même accélération), avec sa traînée.
private struct ControlTestPad: View {
    let setting: Double
    let theme: GameTheme
    @State private var dot = CGPoint(x: 0.5, y: 0.5)
    @State private var trail: [CGPoint] = []
    @State private var last: (point: CGPoint, time: Date)?

    /// Échelle approximative de l'arène en partie (points d'écran par unité d'arène), pour que la vitesse du doigt
    /// soit mesurée comme en jeu.
    private static let arenaScale = 0.36

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Canvas { canvas, _ in
                for (i, p) in trail.enumerated() {
                    let k = Double(i + 1) / Double(max(trail.count, 1))
                    let r = 3 + 7 * k
                    let color = Color(uiColor: theme.trailColor(at: 1 - k, time: 0))
                    canvas.fill(Path(ellipseIn: CGRect(x: p.x * size.width - r, y: p.y * size.height - r, width: 2 * r, height: 2 * r)),
                                with: .color(color.opacity(0.8 * k)))
                }
                let c = CGPoint(x: dot.x * size.width, y: dot.y * size.height)
                canvas.fill(Path(ellipseIn: CGRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22)), with: .color(.white))
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
            .overlay {
                if trail.isEmpty {
                    Text("Glisse ton doigt ici")
                        .font(Theme.body(14, .medium))
                        .foregroundStyle(Theme.secondary)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in move(to: value.location, size: size) }
                    .onEnded { _ in last = nil }
            )
        }
    }

    private func move(to location: CGPoint, size: CGSize) {
        let now = Date()
        defer { last = (location, now) }
        guard let last, size.width > 0, size.height > 0 else { return }
        let dx = location.x - last.point.x
        let dy = location.y - last.point.y
        let interval = min(0.1, max(1.0 / 240, now.timeIntervalSince(last.time)))
        let speed = (dx * dx + dy * dy).squareRoot() / Self.arenaScale / interval
        let gain = Tuning.standard.pointerGain(speed: speed, setting: setting)
        dot.x = min(1, max(0, dot.x + dx * gain / size.width))
        dot.y = min(1, max(0, dot.y + dy * gain / size.height))
        trail.append(dot)
        if trail.count > 18 { trail.removeFirst() }
    }
}

/// Règles du jeu en quelques cartes.
struct RulesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private let rules: [(String, String)] = [
        ("hand.draw.fill", "Glisse ton doigt n'importe où sur l'écran : le point suit ton geste."),
        ("circle.circle.fill", "Attrape les orbes dorés, l'un après l'autre. Le cercle discret montre le suivant."),
        ("figure.walk.motion", "À la manche suivante, ton fantôme rejoue exactement ta manche précédente. Puis 2 fantômes, puis 3…"),
        ("xmark.octagon.fill", "Touche un fantôme et c'est fini. Ils s'allument un court instant après le départ."),
        ("sparkles", "Les échos s'effacent : un fantôme vit 3 manches. Pendant sa dernière, il pâlit et devient inoffensif : fonce dessus pour l'absorber (bonus et multiplicateur)."),
        ("flame.fill", "Frôle les fantômes sans les toucher : ton multiplicateur monte jusqu'à ×5. Une manche sans frôlement le remet à ×1."),
        ("bolt.fill", "Plus tu vas loin, plus les fantômes sont rapides et plus il y a d'orbes."),
        ("calendar", "Défi du jour : les mêmes orbes pour tout le monde. 1 essai par jour (+2 avec une pub). Joue chaque jour pour ta série."),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                app.theme.menuBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(rules, id: \.1) { icon, text in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: icon)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 30)
                                Text(text)
                                    .font(Theme.body(16, .medium))
                                    .foregroundStyle(Theme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Comment jouer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(Theme.body(17, .bold))
                }
            }
        }
    }
}
