import SwiftUI
import CultFiveCore

// Rubriques de la boutique (D-118 à D-120) : offre de bienvenue, packs d'objets, look, objets. Des images plutôt que
// du texte, des textes courts sur une ligne, un prix bien visible.

/// Un pack de la boutique : combien de chaque objet, et combien d'heures sans pub.
struct ShopPack: Identifiable {
    let product: ShopProduct
    let title: String
    let counts: [GameItem: Int]
    let hours: Int
    var best = false
    var id: String { product.rawValue }

    static let all: [ShopPack] = [
        ShopPack(product: .packEssai, title: "Pack Essai",
                 counts: [.energy: 1, .shield: 1, .bet: 1, .lifeline: 1, .hourglass: 1], hours: 1),
        ShopPack(product: .packJoueur, title: "Pack Joueur",
                 counts: [.energy: 2, .shield: 2, .bet: 1, .lifeline: 1, .hourglass: 1], hours: 6),
        ShopPack(product: .packBig, title: "Big Pack",
                 counts: [.energy: 3, .shield: 3, .bet: 3, .lifeline: 3, .hourglass: 3], hours: 24, best: true),
    ]
}

/// Macaron « sans pub » : le panneau PUB barré et la durée, en grand.
struct NoAdsBadge: View {
    let text: String
    var dark = false

    var body: some View {
        HStack(spacing: 6) {
            Image("shop_noads").resizable().scaledToFit().frame(width: 30, height: 30)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundStyle(dark ? Color.inkFixed : .white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
        .background(dark ? AnyShapeStyle(Color.sun) : AnyShapeStyle(Color(hex: 0xE03131)), in: Capsule())
        .shadow(color: (dark ? Color.sun : Color(hex: 0xE03131)).opacity(0.4), radius: 6, y: 3)
    }
}

/// Prix d'un achat dans une pastille jaune (sablier pendant l'achat).
struct PricePill: View {
    let product: ShopProduct
    var big = false
    var action: () -> Void

    @Environment(AppModel.self) private var app

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            Group {
                if app.shop.purchasing == product {
                    ProgressView().tint(Color.inkFixed)
                } else {
                    Text(app.shop.price(product) ?? "…")
                        .font(.system(big ? .title3 : .headline, design: .rounded).weight(.black)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(Color.inkFixed)
            .frame(minWidth: big ? 96 : 76, minHeight: big ? 48 : 40)
            .padding(.horizontal, 8)
            .background(Color.sun, in: Capsule())
            .shadow(color: Color.sun.opacity(0.45), radius: 8, y: 3)
        }
        .buttonStyle(.row)
        .disabled(app.shop.busy)
    }
}

/// Offre de bienvenue : les 7 premiers jours, une seule fois, avec le temps qui reste.
struct WelcomeOfferCard: View {
    let until: Date
    @Environment(AppModel.self) private var app
    private var shop: ShopStore { app.shop }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OFFRE DE BIENVENUE")
                        .font(.system(.caption, design: .rounded).weight(.black)).tracking(1)
                        .foregroundStyle(Color.inkFixed.opacity(0.7))
                    Text("Bien démarrer")
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(Color.inkFixed)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Label(Self.remaining(until.timeIntervalSince(context.date)), systemImage: "clock.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.black))
                            .foregroundStyle(Color(hex: 0xC2255C))
                    }
                }
                Spacer(minLength: 0)
                AnimalBadge(animal: .hypatia, size: 84, decor: .ring(.welcome))
            }
            HStack(spacing: 10) {
                NoAdsBadge(text: "7 JOURS", dark: false)
                HStack(spacing: -10) {
                    ForEach(GameItem.allCases) { item in
                        Image(item.image).resizable().scaledToFit().frame(width: 34, height: 34)
                    }
                }
                Text("×2").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(Color.inkFixed)
            }
            Text("7 jours sans pub, 10 objets, et l'avatar exclusif Hypatie avec son contour.")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Color.inkFixed.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            BuyButton(title: "Je prends", price: shop.price(.welcome), busy: shop.purchasing == .welcome, enabled: !shop.busy) {
                Task {
                    if await shop.purchase(.welcome) {
                        Haptics.success()
                        app.show("Bienvenue ! Tout est arrivé.")
                    }
                }
            }
        }
        .padding(Space.l)
        .background(LinearGradient(colors: [Color(hex: 0xFFF3B0), Color.sun], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .shadow(color: Color.sun.opacity(0.45), radius: 16, y: 8)
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

/// Les trois packs d'objets : une grande carte chacun, les objets en grand, le « sans pub » en macaron.
struct PacksSection: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ShopSectionTitle(title: "Packs d'objets", image: "item_energy", subtitle: "Des objets pour tes parties + du sans pub")
            ForEach(ShopPack.all) { pack in
                PackCard(pack: pack)
            }
        }
    }
}

private struct PackCard: View {
    let pack: ShopPack
    @Environment(AppModel.self) private var app

    private var dark: Bool { pack.best }
    private var text: Color { dark ? .white : .ink }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .center, spacing: Space.s) {
                Text(pack.title)
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if pack.best {
                    Text("MEILLEUR PRIX")
                        .font(.system(size: 10, weight: .black, design: .rounded)).tracking(0.5)
                        .foregroundStyle(Color.inkFixed)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.sun, in: Capsule())
                        .fixedSize()
                }
                Spacer(minLength: 4)
                PricePill(product: pack.product) { buy() }
            }
            HStack(spacing: 0) {
                ForEach(GameItem.allCases) { item in
                    VStack(spacing: 2) {
                        Image(item.image).resizable().scaledToFit().frame(width: 50, height: 50)
                        Text("×\(pack.counts[item] ?? 0)")
                            .font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                            .foregroundStyle(dark ? Color.sun : item.tint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            NoAdsBadge(text: "\(pack.hours) H SANS PUB", dark: dark)
        }
        .padding(Space.m)
        .background {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(dark ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0x24127A)], startPoint: .topLeading, endPoint: .bottomTrailing))
                           : AnyShapeStyle(Color.paperRaised))
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
            .strokeBorder(dark ? Color.sun : Color.hairline, lineWidth: dark ? 2.5 : 1.5))
        .shadow(color: (dark ? Color(hex: 0x3A1FB8) : .black).opacity(dark ? 0.35 : 0.06), radius: dark ? 16 : 8, y: 5)
    }

    private func buy() {
        Task {
            if await app.shop.purchase(pack.product) {
                Haptics.success()
                app.show("\(pack.title) : tes objets sont arrivés !")
            }
        }
    }
}

/// Les cinq objets : une carte illustrée chacun, l'effet en gros, combien j'en ai.
struct ItemsGuide: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ShopSectionTitle(title: "Les objets", image: "item_bet", subtitle: "À activer juste avant une partie")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(GameItem.allCases) { item in
                    card(item)
                }
            }
            Text("Tu en gagnes aussi, rarement, dans les coffres.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
        }
    }

    private func card(_ item: GameItem) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Circle().fill(item.tint.opacity(0.14)).frame(width: 84, height: 84)
                Image(item.image).resizable().scaledToFit().frame(width: 76, height: 76)
                Text("×\(app.boostStock[item.rawValue] ?? 0)")
                    .font(.system(size: 13, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(item.tint, in: Capsule())
                    .offset(x: 8, y: -2)
            }
            Text(item.name)
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundStyle(Color.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(item.effect)
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(item.tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(GameItem.survival.contains(item) ? "SURVIE" : "PARTIES CLASSÉES")
                .font(.system(size: 9, weight: .black, design: .rounded)).tracking(0.5)
                .foregroundStyle(Color.inkSoft)
        }
        .padding(.vertical, 12).padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(item.tint.opacity(0.25), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.detail)
    }
}

/// « Ton look » : une vitrine (avatars premium avec leur contour, titres), puis « Mon look » où tout s'essaie.
struct LookShopCard: View {
    @Environment(AppModel.self) private var app
    @State private var showStudio = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ShopSectionTitle(title: "Ton look", image: "avatar_joan", subtitle: "Vu par tous dans les classements")
            Button {
                Haptics.selection()
                showStudio = true
            } label: {
                VStack(spacing: Space.m) {
                    HStack(spacing: 0) {
                        showcase(.joan, .neon, .genie)
                        showcase(.hugo, .gold, .erudit)
                        showcase(.tut, .prestige, .legend)
                    }
                    HStack(spacing: Space.s) {
                        feature("person.crop.circle.fill", "Personnages")
                        feature("circle.circle.fill", "Contours")
                        feature("textformat", "Titres")
                    }
                    Text("Essayer sur mon avatar")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(Color.inkFixed)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.sun, in: Capsule())
                }
                .padding(Space.m)
                .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .shadow(color: Color(hex: 0x3A1FB8).opacity(0.3), radius: 14, y: 6)
            }
            .buttonStyle(.row)
        }
        .sheet(isPresented: $showStudio) { LookStudio() }
    }

    private func showcase(_ animal: AnimalAvatar, _ ring: AvatarRing, _ title: PlayerTitle) -> some View {
        VStack(spacing: 8) {
            AnimalBadge(animal: animal, size: 78, decor: .ring(ring))
                .padding(.top, 6)
            PlayerTitleTag(title: title, compact: true)
        }
        .frame(maxWidth: .infinity)
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(.caption, design: .rounded).weight(.black))
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.14), in: Capsule())
    }
}
