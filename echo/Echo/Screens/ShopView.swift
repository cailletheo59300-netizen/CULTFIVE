import SwiftUI
import EchoCore

/// Boutique : traînées et décors (en pièces ou en euros), offres (Sans pub, Pack de départ, pièces).
/// Tout s'achète directement, sans hasard.
struct ShopView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = Tab.capture ?? .trails

    enum Tab: String, CaseIterable, Identifiable {
        case trails = "Traînées"
        case decors = "Décors"
        case offers = "Offres"
        var id: String { rawValue }

        /// Onglet demandé par le mode capture (`-capture offers|trails|decors`).
        static var capture: Tab? {
            switch AppModel.capture {
            case "offers": .offers
            case "trails": .trails
            case "decors": .decors
            default: nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                app.theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Rayon", selection: $tab) {
                            ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch tab {
                        case .trails: grid(Catalog.trails)
                        case .decors: grid(Catalog.decors)
                        case .offers: OffersList()
                        }

                        if let message = app.store.message {
                            Text(message)
                                .font(Theme.body(14))
                                .foregroundStyle(Theme.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                }
                if app.store.busy { LoadingVeil() }
            }
            .navigationTitle("Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Chip(icon: "circle.hexagongrid.fill", text: "\(app.profile.coins)")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.font(Theme.body(17, .bold))
                }
            }
        }
        .task { await app.store.loadProducts() }
    }

    private func grid(_ skins: [Skin]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(skins) { SkinCard(skin: $0) }
        }
    }
}

/// Une apparence : aperçu, nom, et bouton (équipée, équiper, prix).
private struct SkinCard: View {
    @Environment(AppModel.self) private var app
    let skin: Skin

    private var owned: Bool { app.profile.owns(skin) }
    private var equipped: Bool {
        skin.kind == .trail ? app.profile.equippedTrail == skin.id : app.profile.equippedDecor == skin.id
    }

    var body: some View {
        VStack(spacing: 10) {
            SkinPreview(skin: skin, theme: app.theme)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(skin.name)
                .font(Theme.body(16, .bold))
                .foregroundStyle(Theme.text)
            action
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(equipped ? Theme.accent : Theme.stroke, lineWidth: equipped ? 2 : 1))
    }

    @ViewBuilder
    private var action: some View {
        if equipped {
            label("Équipée", icon: "checkmark", color: Theme.accent, filled: false)
        } else if owned {
            Button { app.equip(skin) } label: { label("Équiper", icon: nil, color: Theme.accent, filled: true) }
        } else {
            switch skin.price {
            case .free:
                EmptyView()
            case .coins(let price):
                Button {
                    if !app.buyWithCoins(skin) { app.haptics.error() }
                } label: {
                    label("\(price)", icon: "circle.hexagongrid.fill", color: Theme.gold, filled: app.profile.coins >= price)
                }
                .opacity(app.profile.coins >= price ? 1 : 0.55)
            case .store(let product):
                Button {
                    Task {
                        if await app.store.purchase(product) {
                            app.haptics.success()
                            app.equip(skin)
                        }
                    }
                } label: {
                    label(app.store.price(product) ?? "…", icon: nil, color: Theme.ghost, filled: true)
                }
            }
        }
    }

    private func label(_ text: String, icon: String?, color: Color, filled: Bool) -> some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon) }
            Text(text).monospacedDigit()
        }
        .font(Theme.body(15, .bold))
        .foregroundStyle(filled ? Color.black : color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Capsule().fill(filled ? color : color.opacity(0.12)))
    }
}

/// Aperçu dessiné d'une apparence : une traînée en vague sur le fond du décor.
struct SkinPreview: View {
    let skin: Skin
    let theme: GameTheme

    var body: some View {
        let preview = skin.kind == .trail ? GameTheme(trail: skin, decor: theme.decor) : GameTheme(trail: theme.trail, decor: skin)
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                canvas.fill(Path(CGRect(origin: .zero, size: size)),
                            with: .linearGradient(Gradient(colors: [preview.backgroundTop, preview.backgroundBottom]),
                                                  startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                let count = 18
                for i in 0..<count {
                    let k = Double(i + 1) / Double(count)
                    let x = size.width * (0.1 + 0.75 * k)
                    let y = size.height * (0.5 + 0.28 * sin(k * 5 + t * 2))
                    let r = 2 + 7 * k
                    let color = Color(uiColor: preview.trailColor(at: 1 - k, time: t))
                    canvas.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color.opacity(k)))
                }
                let head = CGPoint(x: size.width * 0.85, y: size.height * (0.5 + 0.28 * sin(5 + t * 2)))
                canvas.fill(Path(ellipseIn: CGRect(x: head.x - 9, y: head.y - 9, width: 18, height: 18)), with: .color(.white))
                if skin.kind == .decor {
                    let ghost = CGPoint(x: size.width * 0.3, y: size.height * 0.3)
                    canvas.fill(Path(ellipseIn: CGRect(x: ghost.x - 8, y: ghost.y - 8, width: 16, height: 16)),
                                with: .color(Color(uiColor: preview.ghostColor)))
                    let orb = CGPoint(x: size.width * 0.45, y: size.height * 0.78)
                    canvas.fill(Path(ellipseIn: CGRect(x: orb.x - 10, y: orb.y - 10, width: 20, height: 20)),
                                with: .color(Color(uiColor: preview.orbColor)))
                }
            }
        }
    }
}

/// Offres en euros.
private struct OffersList: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 12) {
            if !app.profile.noAds {
                offer(.starter, title: "Pack de départ", detail: "Sans pub + Feu, Galaxie et Synthwave", icon: "gift.fill",
                      highlight: true)
                offer(.noAds, title: "Sans pub", detail: "Plus aucune pub entre les parties. Pour toujours.",
                      icon: "nosign")
            } else {
                Label("Sans pub : activé. Merci !", systemImage: "checkmark.seal.fill")
                    .font(Theme.body(16, .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            }
            offer(.coinsSmall, title: "\(StoreProduct.coinsSmall.coins) pièces", detail: "Petit coup de pouce",
                  icon: "circle.hexagongrid.fill")
            offer(.coinsMedium, title: "\(StoreProduct.coinsMedium.coins) pièces", detail: "Le plus choisi",
                  icon: "circle.hexagongrid.fill")
            offer(.coinsLarge, title: "\(StoreProduct.coinsLarge.coins) pièces", detail: "Toute la boutique ou presque",
                  icon: "circle.hexagongrid.fill")
            Button("Restaurer les achats") {
                Task { await app.store.restore() }
            }
            .font(Theme.body(15))
            .foregroundStyle(Theme.secondary)
            .padding(.top, 6)
        }
    }

    private func offer(_ product: StoreProduct, title: String, detail: String, icon: String, highlight: Bool = false) -> some View {
        Button {
            Task {
                if await app.store.purchase(product) { app.haptics.success() }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(highlight ? Theme.ghost : Theme.gold)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Theme.body(17, .bold)).foregroundStyle(Theme.text)
                    Text(detail).font(Theme.body(13, .medium)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                Text(app.store.price(product) ?? "…")
                    .font(Theme.body(16, .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(highlight ? Theme.ghost : Theme.gold))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(highlight ? Theme.ghost.opacity(0.12) : Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(highlight ? Theme.ghost.opacity(0.6) : Theme.stroke, lineWidth: highlight ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}
