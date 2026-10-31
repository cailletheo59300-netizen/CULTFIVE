import SwiftUI
import LumiCore

/// Réglages : jeu (croix automatiques, symboles), son et vibrations, aide, achats, infos.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showRules = false

    /// Pages du site (même site que Brainlix, rubrique Lumiligne).
    private static let site = URL(string: "https://brainlix.site/lumiligne")!

    var body: some View {
        let palette = app.palette
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        card(palette, "Jeu", icon: "square.grid.3x3.fill") {
                            toggle(palette, "Croix automatiques", icon: "xmark", detail: "Barre les cases exclues par chaque gemme posée.",
                                   value: binding(\.autoCrosses))
                            Divider().overlay(palette.stroke)
                            toggle(palette, "Symboles dans les zones", icon: "star.fill",
                                   detail: "Un symbole par zone, en plus de la couleur (daltonisme).", value: binding(\.showSymbols))
                        }
                        card(palette, "Son et vibrations", icon: "speaker.wave.2.fill") {
                            toggle(palette, "Son", icon: "music.note", value: binding(\.soundOn))
                            Divider().overlay(palette.stroke)
                            toggle(palette, "Vibrations", icon: "iphone.radiowaves.left.and.right", value: binding(\.hapticsOn))
                        }
                        card(palette, "Aide", icon: "questionmark.circle.fill") {
                            row(palette, "Comment jouer", icon: "book.fill") { showRules = true }
                        }
                        card(palette, "Achats", icon: "bag.fill") {
                            row(palette, "Restaurer les achats", icon: "arrow.clockwise") {
                                Task { await app.store.restore() }
                            }
                            if let message = app.store.message {
                                Text(message).font(Fonts.body(13, .medium)).foregroundStyle(palette.secondary)
                            }
                            if app.ads.privacyOptionsAvailable {
                                Divider().overlay(palette.stroke)
                                row(palette, "Confidentialité des pubs", icon: "hand.raised.fill") {
                                    Task { await app.ads.presentPrivacyOptions() }
                                }
                            }
                        }
                        card(palette, "Infos", icon: "info.circle.fill") {
                            link(palette, "Aide et contact", "support")
                            Divider().overlay(palette.stroke)
                            link(palette, "Confidentialité", "confidentialite")
                            Divider().overlay(palette.stroke)
                            link(palette, "Conditions d'utilisation", "conditions")
                        }
                        Text("Lumiligne \(Self.version)" + (app.ads.testAds ? " · pubs de test" : ""))
                            .font(Fonts.body(13, .medium))
                            .foregroundStyle(palette.secondary)
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(Fonts.body(17, .bold))
                }
            }
            .sheet(isPresented: $showRules) { RulesView() }
        }
    }

    private func card<Content: View>(_ palette: Palette, _ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(Fonts.body(13, .heavy))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(palette.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(palette.stroke, lineWidth: 1))
    }

    private func toggle(_ palette: Palette, _ title: String, icon: String, detail: String? = nil, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).foregroundStyle(palette.beam).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Fonts.body(17)).foregroundStyle(palette.text)
                    if let detail {
                        Text(detail).font(Fonts.body(13, .regular)).foregroundStyle(palette.secondary)
                    }
                }
            }
        }
        .tint(palette.beam)
    }

    private func row(_ palette: Palette, _ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            app.haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(palette.beam).frame(width: 26)
                Text(title).font(Fonts.body(17)).foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(palette.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func link(_ palette: Palette, _ title: String, _ page: String) -> some View {
        Link(destination: Self.site.appendingPathComponent(page)) {
            HStack(spacing: 12) {
                Text(title).font(Fonts.body(17)).foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundStyle(palette.secondary)
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

/// « Comment jouer » : les 3 règles, chacune avec un petit dessin, puis les gestes et la grille du jour.
/// S'ouvre tout seul à la première grille.
struct RulesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let palette = app.palette
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        rule(palette, number: 1, text: "Une gemme par zone de couleur. Chaque zone porte un numéro.",
                             drawing: .onePerZone)
                        rule(palette, number: 2, text: "Les numéros qui se suivent sont alignés : la gemme 1 est sur la même ligne ou la même colonne que la 2, la 2 avec la 3, etc. Le rayon les relie.",
                             drawing: .aligned)
                        rule(palette, number: 3, text: "Deux gemmes ne se touchent jamais, même en diagonale.", drawing: .noTouch)
                        VStack(alignment: .leading, spacing: 10) {
                            tip(palette, "hand.tap.fill", "Un appui : une croix. Deux appuis : une gemme. Trois : la case se vide.")
                            tip(palette, "hand.draw.fill", "Glisse le doigt pour poser des croix sur plusieurs cases.")
                            tip(palette, "lightbulb.fill", "Bloqué ? L'indice explique la prochaine déduction. Jamais besoin de deviner.")
                            tip(palette, "calendar", "Chaque jour, une grille du jour, la même pour tout le monde. Finis-la chaque jour pour ta série.")
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.card))
                        Button("C'est parti") { dismiss() }
                            .buttonStyle(PillButtonStyle(palette: palette, tint: palette.beam))
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Comment jouer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(Fonts.body(17, .bold))
                }
            }
        }
    }

    private func rule(_ palette: Palette, number: Int, text: String, drawing: RuleDrawing.Kind) -> some View {
        HStack(spacing: 14) {
            RuleDrawing(kind: drawing, palette: palette)
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text("Règle \(number)").font(Fonts.body(13, .heavy)).foregroundStyle(palette.secondary)
                Text(text).font(Fonts.body(16, .medium)).foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.card))
    }

    private func tip(_ palette: Palette, _ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(palette.beam).frame(width: 24)
            Text(text).font(Fonts.body(15, .medium)).foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Petit dessin d'une règle sur une grille 3 × 3.
struct RuleDrawing: View {
    enum Kind { case onePerZone, aligned, noTouch }
    let kind: Kind
    let palette: Palette

    var body: some View {
        Canvas { context, size in
            let c = size.width / 3
            // 3 zones : 0 en haut à gauche, 1 à droite, 2 en bas.
            let zones = [0, 1, 1, 0, 0, 1, 2, 2, 2]
            for i in 0..<9 {
                let rect = CGRect(x: CGFloat(i % 3) * c, y: CGFloat(i / 3) * c, width: c, height: c)
                context.fill(Path(rect), with: .color(palette.zone(zones[i])))
                context.stroke(Path(rect), with: .color(palette.line.opacity(0.25)), lineWidth: 1)
            }
            context.stroke(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6), with: .color(palette.line), lineWidth: 2.5)
            let gems: [Int]
            var bad: [Int] = []
            switch kind {
            case .onePerZone, .aligned: gems = [0, 2, 8]
            case .noTouch:
                gems = [4, 5]
                bad = [4, 5]
            }
            if kind == .aligned {
                var beam = Path()
                for (k, cell) in gems.enumerated() {
                    let p = CGPoint(x: (CGFloat(cell % 3) + 0.5) * c, y: (CGFloat(cell / 3) + 0.5) * c)
                    if k == 0 { beam.move(to: p) } else { beam.addLine(to: p) }
                }
                context.stroke(beam, with: .color(palette.beam), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            for cell in gems {
                let r = CGRect(x: CGFloat(cell % 3) * c, y: CGFloat(cell / 3) * c, width: c, height: c).insetBy(dx: c * 0.2, dy: c * 0.2)
                var gem = Path()
                gem.move(to: CGPoint(x: r.midX, y: r.minY))
                gem.addLine(to: CGPoint(x: r.maxX, y: r.midY))
                gem.addLine(to: CGPoint(x: r.midX, y: r.maxY))
                gem.addLine(to: CGPoint(x: r.minX, y: r.midY))
                gem.closeSubpath()
                context.fill(gem, with: .color(.white))
                context.stroke(gem, with: .color(bad.contains(cell) ? palette.error : palette.line), lineWidth: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
