import SwiftUI
import CultFiveCore

// Rubriques de la boutique pour les objets (D-119) : offre de bienvenue, packs, et à quoi sert chaque objet.

/// Un pack de la boutique : ce qu'il contient, en clair.
struct ShopPack: Identifiable {
    let product: ShopProduct
    let title: String
    /// Ce que contient le pack, en une ligne.
    let contents: String
    let hours: String
    var best = false
    var id: String { product.rawValue }

    static let all: [ShopPack] = [
        ShopPack(product: .packEssai, title: "Pack Essai", contents: "1 de chaque objet", hours: "1 h sans pub"),
        ShopPack(product: .packJoueur, title: "Pack Joueur", contents: "2 Boissons, 2 Boucliers d'Elo, 1 de chaque autre",
                 hours: "6 h sans pub"),
        ShopPack(product: .packBig, title: "Big Pack", contents: "3 de chaque objet", hours: "24 h sans pub", best: true),
    ]
}

/// Les cinq objets en éventail (aperçu d'un pack).
struct ItemsFan: View {
    var size: CGFloat = 40

    var body: some View {
        HStack(spacing: -size * 0.38) {
            ForEach(Array(GameItem.allCases.enumerated()), id: \.offset) { index, item in
                Image(item.image).resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(Double(index - 2) * 8))
                    .offset(y: abs(Double(index - 2)) * 3)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Offre de bienvenue : les 7 premiers jours, une seule fois, avec le temps qui reste.
struct WelcomeOfferCard: View {
    let until: Date
    @Environment(AppModel.self) private var app
    private var shop: ShopStore { app.shop }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OFFRE DE BIENVENUE")
                        .font(.system(.caption, design: .rounded).weight(.black)).tracking(1)
                        .foregroundStyle(Color.inkFixed.opacity(0.7))
                    Text("Bien démarrer")
                        .font(.system(.title2, design: .rounded).weight(.black))
                        .foregroundStyle(Color.inkFixed)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Label(Self.remaining(until.timeIntervalSince(context.date)), systemImage: "clock.fill")
                            .font(.system(.footnote, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color(hex: 0xC2255C))
                    }
                }
                Spacer(minLength: 0)
                FloatingArt(name: "shop_gift").frame(width: 84, height: 84)
            }
            VStack(alignment: .leading, spacing: 6) {
                bullet("nosign", "7 jours sans aucune pub")
                bullet("sparkles", "2 de chaque objet (10 objets)")
                bullet("person.crop.circle.badge.checkmark", "L'avatar exclusif Hypatie + son contour")
            }
            BuyButton(title: "Je prends", price: shop.price(.welcome), busy: shop.purchasing == .welcome, enabled: !shop.busy) {
                Task {
                    if await shop.purchase(.welcome) {
                        Haptics.success()
                        app.show("Bienvenue ! Tes objets sont arrivés.")
                    }
                }
            }
            Text("Une seule fois, pendant ta première semaine.")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.inkFixed.opacity(0.65))
                .frame(maxWidth: .infinity)
        }
        .padding(Space.l)
        .background(LinearGradient(colors: [Color(hex: 0xFFE680), Color.sun], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .shadow(color: Color.sun.opacity(0.45), radius: 16, y: 8)
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(.callout, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.inkFixed)
    }

    /// « Encore 3 j 4 h », « Encore 5 h 12 min ».
    static func remaining(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let days = minutes / 1440, hours = (minutes % 1440) / 60, mins = minutes % 60
        if days > 0 { return "Encore \(days) j \(hours) h" }
        if hours > 0 { return "Encore \(hours) h \(mins) min" }
        return "Encore \(max(mins, 1)) min"
    }
}

/// Les trois packs d'objets, du plus petit au plus gros.
struct PacksSection: View {
    @Environment(AppModel.self) private var app
    private var shop: ShopStore { app.shop }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Packs d'objets")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(Color.ink)
            Text("Des objets à utiliser avant tes parties, et des heures sans pub en cadeau.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            ForEach(ShopPack.all) { pack in
                packRow(pack)
            }
        }
    }

    private func packRow(_ pack: ShopPack) -> some View {
        HStack(spacing: Space.m) {
            ItemsFan(size: pack.best ? 34 : 30)
                .frame(width: 104)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(pack.title).font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                    if pack.best {
                        Text("MEILLEUR PRIX")
                            .font(.system(size: 9, weight: .black, design: .rounded)).tracking(0.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: 0xE03131), in: Capsule())
                    }
                }
                Text(pack.contents).font(.system(.footnote, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("+ \(pack.hours)").font(.system(.footnote, design: .rounded).weight(.bold)).foregroundStyle(Color.brand)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.soft()
                Task {
                    if await shop.purchase(pack.product) {
                        Haptics.success()
                        app.show("\(pack.title) : tes objets sont arrivés !")
                    }
                }
            } label: {
                Group {
                    if shop.purchasing == pack.product {
                        ProgressView().tint(Color.inkFixed)
                    } else {
                        Text(shop.price(pack.product) ?? "…")
                            .font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                    }
                }
                .foregroundStyle(Color.inkFixed)
                .frame(minWidth: 64, minHeight: 40)
                .padding(.horizontal, 6)
                .background(Color.sun, in: Capsule())
            }
            .buttonStyle(.row)
            .disabled(shop.busy)
            .accessibilityLabel("Acheter \(pack.title)")
        }
        .padding(12)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
            .strokeBorder(pack.best ? Color.sun : Color.hairline, lineWidth: pack.best ? 2.5 : 1.5))
    }
}

/// À quoi sert chaque objet, et combien j'en ai.
struct ItemsGuide: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Les objets")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(Color.ink)
            Text("À activer sur l'écran juste avant la partie. Tu en gagnes aussi, rarement, dans les coffres.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(GameItem.allCases) { item in
                HStack(alignment: .top, spacing: Space.m) {
                    Image(item.image).resizable().scaledToFit().frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.name).font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                            Spacer()
                            Text("×\(app.boostStock[item.rawValue] ?? 0)")
                                .font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                                .foregroundStyle(item.tint)
                        }
                        Text(item.detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(GameItem.survival.contains(item) ? "Survie" : "Parties classées")
                            .font(.system(.caption2, design: .rounded).weight(.heavy))
                            .foregroundStyle(item.tint)
                    }
                }
                .padding(10)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            }
        }
    }
}

/// « Ton look » : avatars premium, contours, titres, Pack Prestige. Un aperçu, puis l'atelier où tout s'essaie.
struct LookShopCard: View {
    @Environment(AppModel.self) private var app
    @State private var showStudio = false

    var body: some View {
        Button {
            Haptics.selection()
            showStudio = true
        } label: {
            VStack(alignment: .leading, spacing: Space.m) {
                HStack(spacing: -12) {
                    AnimalBadge(animal: .joan, size: 58, decor: .ring(.neon))
                    AnimalBadge(animal: .hugo, size: 58, decor: .ring(.gold))
                    AnimalBadge(animal: .galileo, size: 58, decor: .ring(.rainbow))
                    AnimalBadge(animal: .tut, size: 58, decor: .ring(.prestige))
                }
                .padding(.top, Space.s)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ton look").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                    Text("Avatars premium, contours et titres : tout le monde les voit dans les classements, les duels et l'Arène.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        PlayerTitleTag(title: .genie)
                        PlayerTitleTag(title: .legend)
                    }
                }
                Text("Essayer sur mon avatar ›")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(Color.brand)
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1.5))
        }
        .buttonStyle(.row)
        .sheet(isPresented: $showStudio) { LookStudio() }
    }
}
