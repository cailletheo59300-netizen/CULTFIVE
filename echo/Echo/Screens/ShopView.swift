import SwiftUI
import SpriteKit
import EchoCore

/// Boutique : traînées et décors (en pièces ou en euros), offres (Sans pub, Pack de départ, pièces).
/// Tout s'achète directement, sans hasard. Chaque apparence montre son aperçu animé réel (mêmes effets qu'en partie).
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
                app.theme.menuBackground.ignoresSafeArea()
                ScrollViewReader { scroll in
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
                    .onAppear {
                        // Captures : les traînées payantes (Feu, Galaxie) doivent être visibles.
                        if tab == .trails, AppModel.capture != nil { scroll.scrollTo("trail.galaxy", anchor: .bottom) }
                    }
                }
                if app.store.busy { LoadingVeil() }
            }
            .navigationTitle("Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Chip(text: "\(app.profile.coins)") { CoinIcon(size: 20) }
                        .fixedSize()
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
            ForEach(skins) { SkinCard(skin: $0).id($0.id) }
        }
    }
}

/// Une apparence : aperçu animé, nom, et bouton (équipée, équiper, prix).
private struct SkinCard: View {
    @Environment(AppModel.self) private var app
    let skin: Skin

    private var owned: Bool { app.profile.owns(skin) }
    private var equipped: Bool {
        skin.kind == .trail ? app.profile.equippedTrail == skin.id : app.profile.equippedDecor == skin.id
    }
    private var premium: Bool { if case .store = skin.price { true } else { false } }

    var body: some View {
        VStack(spacing: 10) {
            SkinPreview(skin: skin)
                .frame(height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if premium {
                        Text("PREMIUM")
                            .font(Theme.body(10, .heavy))
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(LinearGradient(colors: [Theme.gold, Theme.ghost], startPoint: .leading, endPoint: .trailing)))
                            .padding(6)
                    }
                }
            Text(skin.name)
                .font(Theme.body(16, .bold))
                .foregroundStyle(Theme.text)
            action
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(equipped ? Theme.accent : (premium ? Theme.ghost.opacity(0.6) : Theme.stroke), lineWidth: equipped || premium ? 2 : 1))
    }

    @ViewBuilder
    private var action: some View {
        if equipped {
            label("Équipée", systemIcon: "checkmark", color: Theme.accent, filled: false)
        } else if owned {
            Button { app.equip(skin) } label: { label("Équiper", color: Theme.accent, filled: true) }
        } else {
            switch skin.price {
            case .free:
                EmptyView()
            case .coins(let price):
                Button {
                    if !app.buyWithCoins(skin) { app.haptics.error() }
                } label: {
                    label("\(price)", coin: true, color: Theme.gold, filled: app.profile.coins >= price)
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
                    label(app.store.price(product) ?? "…", color: Theme.ghost, filled: true)
                }
            }
        }
    }

    private func label(_ text: String, systemIcon: String? = nil, coin: Bool = false, color: Color, filled: Bool) -> some View {
        HStack(spacing: 5) {
            if let systemIcon { Image(systemName: systemIcon) }
            if coin { CoinIcon(size: 17) }
            Text(text).monospacedDigit()
        }
        .font(Theme.body(15, .bold))
        .foregroundStyle(filled ? Color.black : color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Capsule().fill(filled ? color : color.opacity(0.12)))
    }
}

/// Aperçu animé réel d'une apparence (scène SpriteKit : vrai décor, vraie traînée).
/// Une traînée s'affiche sur le décor équipé ; un décor avec la traînée équipée.
struct SkinPreview: View {
    @Environment(AppModel.self) private var app
    let skin: Skin
    @State private var scene: PreviewScene?

    private var theme: GameTheme {
        skin.kind == .trail ? GameTheme(trail: skin, decor: app.theme.decor) : GameTheme(trail: app.theme.trail, decor: skin)
    }

    var body: some View {
        ZStack {
            theme.background
            if let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 30, options: [.allowsTransparency])
            }
        }
        .onAppear {
            if scene == nil { scene = PreviewScene(theme: theme) }
        }
    }
}

/// Offres en euros : Pack de départ (mis en avant), Sans pub, pièces.
private struct OffersList: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 14) {
            if !app.profile.noAds {
                StarterCard()
                noAdsCard
            } else {
                HStack(spacing: 12) {
                    NoAdsIcon(size: 36)
                    Text("Sans pub : activé. Merci !")
                        .font(Theme.body(16, .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            }

            Text("PIÈCES")
                .font(Theme.body(14, .heavy))
                .tracking(1.5)
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            HStack(spacing: 10) {
                coinCard(.coinsSmall, level: 1, bonus: nil)
                coinCard(.coinsMedium, level: 2, bonus: "+10 %")
                coinCard(.coinsLarge, level: 3, bonus: "+32 %")
            }

            Button("Restaurer les achats") {
                Task { await app.store.restore() }
            }
            .font(Theme.body(15))
            .foregroundStyle(Theme.secondary)
            .padding(.top, 6)
        }
    }

    private var noAdsCard: some View {
        Button {
            Task { if await app.store.purchase(.noAds) { app.haptics.success() } }
        } label: {
            HStack(spacing: 14) {
                NoAdsIcon(size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sans pub").font(Theme.body(18, .bold)).foregroundStyle(Theme.text)
                    Text("Plus aucune pub entre les parties. Pour toujours.")
                        .font(Theme.body(13, .medium))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                priceTag(app.store.price(.noAds), color: Theme.ghost)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func coinCard(_ product: StoreProduct, level: Int, bonus: String?) -> some View {
        Button {
            Task { if await app.store.purchase(product) { app.haptics.success() } }
        } label: {
            VStack(spacing: 8) {
                CoinStack(level: level, size: 22)
                    .frame(height: 56)
                Text(product.coins.formatted())
                    .font(Theme.title(20))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("pièces").font(Theme.body(12, .medium)).foregroundStyle(Theme.secondary)
                priceTag(app.store.price(product), color: Theme.gold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(bonus != nil ? Theme.gold.opacity(0.6) : Theme.stroke, lineWidth: bonus != nil ? 1.5 : 1))
            .overlay(alignment: .top) {
                if let bonus {
                    Text(bonus)
                        .font(Theme.body(12, .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.gold))
                        .offset(y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func priceTag(_ price: String?, color: Color) -> some View {
        Text(price ?? "…")
            .font(Theme.body(15, .bold))
            .foregroundStyle(.black)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(color))
    }
}

/// Carte du Pack de départ : bordure animée, aperçus réels des 3 apparences premium, prix barré.
private struct StarterCard: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Button {
            Task { if await app.store.purchase(.starter) { app.haptics.success() } }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    GiftIcon(size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pack de départ").font(Theme.title(22)).foregroundStyle(Theme.text)
                        Text("Sans pub + 3 apparences premium").font(Theme.body(13, .medium)).foregroundStyle(Theme.secondary)
                    }
                    Spacer(minLength: 0)
                    Text("−50 %")
                        .font(Theme.body(14, .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.gold))
                }
                HStack(spacing: 8) {
                    preview("trail.fire")
                    preview("trail.galaxy")
                    preview("decor.synthwave")
                }
                HStack {
                    Label("Plus aucune pub entre les parties", systemImage: "checkmark.circle.fill")
                        .font(Theme.body(13, .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text(app.store.price(.starter) ?? "…")
                        .font(Theme.body(18, .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Theme.ghost))
                        .shadow(color: Theme.ghost.opacity(0.6), radius: 10)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#3A0E3C"), Color(hex: "#1A0B2E")], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(AnimatedBorder(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private func preview(_ id: String) -> some View {
        VStack(spacing: 4) {
            if let skin = Catalog.skin(id) {
                SkinPreview(skin: skin)
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(skin.name).font(Theme.body(12, .bold)).foregroundStyle(Theme.text)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Bordure lumineuse qui tourne autour d'une carte mise en avant.
private struct AnimatedBorder: View {
    let cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4 * 360
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(AngularGradient(colors: [Theme.ghost, Theme.gold, Theme.accent, Theme.ghost],
                                              center: .center, angle: .degrees(angle)), lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }
}
