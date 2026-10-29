import SwiftUI
import CultFiveCore

// Boutique (D-118) : un seul endroit pour tout ce qui est payant, rangé par rubriques, peu de prix différents.
// En tête : « Sans pub pour toujours » (7,99 €), puis le Pass+ de la saison. Ailleurs dans l'app, au plus un rappel
// discret par jour (après une pub) et un petit bouton sur l'accueil.

/// Bouton d'achat principal : grand, jaune soleil, le prix dedans.
struct BuyButton: View {
    let title: String
    var price: String?
    var busy = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            HStack(spacing: Space.s) {
                if busy { ProgressView().controlSize(.small).tint(Color.inkFixed) }
                Text(price.map { "\(title) · \($0)" } ?? title)
                    .font(.system(.title3, design: .rounded).weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.inkFixed)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color.sun, in: Capsule())
            .shadow(color: Color.sun.opacity(0.5), radius: 14, y: 6)
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.row)
        .disabled(busy || !enabled)
    }
}

/// Fait flotter doucement une image (immobile si « Réduire les animations » est activé).
private struct Floating: ViewModifier {
    let amplitude: CGFloat
    let period: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .phaseAnimator(reduceMotion ? [false] : [false, true]) { view, up in
                view.offset(y: up ? -amplitude : amplitude).rotationEffect(.degrees(up ? -2 : 2))
            } animation: { _ in .easeInOut(duration: period) }
    }
}

extension View {
    func floating(_ amplitude: CGFloat = 6, period: Double = 2.2) -> some View {
        modifier(Floating(amplitude: amplitude, period: period))
    }
}

/// Icône 3D de l'app qui flotte doucement.
struct FloatingArt: View {
    let name: String
    var amplitude: CGFloat = 6
    var period: Double = 2.2

    var body: some View {
        Image(name).resizable().scaledToFit()
            .floating(amplitude, period: period)
            .accessibilityHidden(true)
    }
}

/// Rubriques de la boutique : un bouton qui y mène ouvre la boutique directement dessus (D-118).
enum ShopFocus: String, CaseIterable, Identifiable {
    case noAds, packs, look, pass, items
    var id: String { rawValue }

    var title: String {
        switch self {
        case .noAds: return "Sans pub"
        case .packs: return "Packs"
        case .look: return "Look"
        case .pass: return "Pass+"
        case .items: return "Objets"
        }
    }

    var image: String {
        switch self {
        case .noAds: return "shop_noads"
        case .packs: return "item_energy"
        case .look: return "avatar_joan"
        case .pass: return "shop_gift"
        case .items: return "item_bet"
        }
    }
}

/// La Boutique, en plein écran : un grand en-tête, des raccourcis vers chaque rubrique, puis les rubriques.
struct ShopView: View {
    /// Rubrique à montrer en arrivant (« Obtenir » avant une partie → les packs).
    var focus: ShopFocus? = nil

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var store = AlbumStore.shared
    @State private var showPassPlus = false

    private var shop: ShopStore { app.shop }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    header
                    shortcuts(reader)
                    if let until = app.boutique?.welcomeUntil, until > Date() {
                        WelcomeOfferCard(until: until)
                    }
                    NoAdsHero().id(ShopFocus.noAds)
                    PacksSection().id(ShopFocus.packs)
                    LookShopCard().id(ShopFocus.look)
                    passCard.id(ShopFocus.pass)
                    ItemsGuide().id(ShopFocus.items)
                    footer
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
                .containerRelativeFrame(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .background(Color.paper.ignoresSafeArea())
            .task {
                if let focus {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(Motion.standard) { reader.scrollTo(focus, anchor: .top) }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(.black.opacity(0.25), in: Circle())
            }
            .accessibilityLabel("Fermer")
            .padding(.trailing, Space.gutter + 10)
            .padding(.top, Space.s + 10)
        }
        .sheet(isPresented: $showPassPlus) { PassPlusView() }
        .task {
            await shop.loadProducts(force: true)
            await app.refreshBoutique()
            await store.refresh()
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BOUTIQUE")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("Sans pub, objets, look")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.sun)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            FloatingArt(name: "shop_gift", amplitude: 5).frame(width: 96, height: 96)
        }
        .padding(.horizontal, Space.l)
        .padding(.top, 44)
        .padding(.bottom, Space.l)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0xFF7AB6), Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.3), radius: 14, y: 6)
        .padding(.top, Space.s)
    }

    /// Raccourcis : une pastille par rubrique, qui fait défiler jusqu'à elle.
    private func shortcuts(_ reader: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            ForEach(ShopFocus.allCases) { section in
                Button {
                    Haptics.selection()
                    withAnimation(Motion.standard) { reader.scrollTo(section, anchor: .top) }
                } label: {
                    VStack(spacing: 4) {
                        Image(section.image).resizable().scaledToFit().frame(width: 36, height: 36)
                        Text(section.title)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1.5))
                }
                .buttonStyle(.row)
            }
        }
    }

    // MARK: - Pass+

    private var passCard: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ShopSectionTitle(title: "Pass+ de la saison", image: "shop_gift")
            Button {
                Haptics.selection()
                app.track("pass_view", ["from": "shop"])
                showPassPlus = true
            } label: {
                HStack(spacing: Space.m) {
                    AlbumImage(kind: .pass, name: "final_payant").frame(width: 92, height: 92)
                        .floating(4, period: 2.4)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.season.season?.name ?? "Pass+")
                            .font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Label("30 cadeaux pour ton album", systemImage: "gift.fill")
                        Label("Zéro pub toute la saison", systemImage: "nosign")
                        Text(store.passPlusActive ? "Actif ✓" : "Voir les cadeaux ›")
                            .font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.sun)
                    }
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .padding(Space.m)
                .background(PassPlusFill(), in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(CardRarity.legend.border, lineWidth: 2))
                .shadow(color: Color(hex: 0x2A1490).opacity(0.3), radius: 14, y: 6)
            }
            .buttonStyle(.row)
            .accessibilityHint("Ouvre le Pass+")
        }
    }

    // MARK: - Bas de page

    private var footer: some View {
        VStack(spacing: Space.s) {
            if let error = shop.errorMessage {
                Text(error).font(.cfFootnote).foregroundStyle(Color.wrong).multilineTextAlignment(.center)
            }
            Button("Restaurer mes achats") { Task { await shop.restore() } }
                .buttonStyle(.textLink)
                .disabled(shop.busy)
            Text("Achats liés à ton compte \(Brand.name). Aucun abonnement : rien ne se renouvelle tout seul.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
            HStack(spacing: Space.m) {
                Link("Conditions", destination: Brand.termsURL)
                Link("Confidentialité", destination: Brand.privacyURL)
            }
            .font(.cfFootnote.weight(.bold))
            .tint(Color.brand)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s)
    }
}

/// Titre d'une rubrique de la boutique : une icône 3D et un titre en gras, sur une ligne.
struct ShopSectionTitle: View {
    let title: String
    let image: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: Space.s) {
            Image(image).resizable().scaledToFit().frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
    }
}

/// « Sans pub pour toujours » : le panneau PUB barré, deux lignes, le prix.
struct NoAdsHero: View {
    @Environment(AppModel.self) private var app
    private var shop: ShopStore { app.shop }
    private var owned: Bool { app.adStatus?.noAdsForever ?? false }
    /// Heures sans pub en cours (packs, bienvenue) : « 5 h 12 min ».
    private var hoursLeft: String? {
        guard let until = app.adStatus?.noAdsUntil, until > Date() else { return nil }
        return String(WelcomeOfferCard.remaining(until.timeIntervalSinceNow).dropFirst(7))
    }

    var body: some View {
        VStack(spacing: Space.m) {
            FloatingArt(name: "shop_noads")
                .frame(width: 190, height: 190)
                .padding(.top, Space.s)
            VStack(spacing: 6) {
                Text(owned ? "Plus jamais de pub" : "Zéro pub. Pour toujours.")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                Text(owned ? "Merci pour ton soutien ! Tous les bonus se prennent sans vidéo."
                           : "Plus aucune pub entre les parties.\nTous les bonus sans vidéo.")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if owned {
                Label("Acheté", systemImage: "checkmark.seal.fill")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(Color.sun)
                    .frame(minHeight: 44)
            } else {
                BuyButton(title: "Retirer les pubs", price: shop.price(.noAds), busy: shop.purchasing == .noAds,
                          enabled: !shop.busy) {
                    Task {
                        if await shop.purchase(.noAds) {
                            Haptics.success()
                            app.show("Plus jamais de pub. Merci !")
                        }
                    }
                }
                Text(hoursLeft.map { "Paiement unique · sans pub encore \($0)" } ?? "Paiement unique")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8), Color(hex: 0x24127A)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1.5))
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.35), radius: 18, y: 8)
    }
}

/// Petite ligne de l'accueil pour qui voit encore des pubs : « Marre des pubs ? ». Ouvre la Boutique.
struct NoAdsRow: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if app.api != nil, !app.noAds {
            Button {
                Haptics.selection()
                app.openShop(from: "home", focus: .noAds)
            } label: {
                HStack(spacing: Space.m) {
                    Image("shop_noads").resizable().scaledToFit().frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Marre des pubs ?").font(.system(.subheadline, design: .rounded).weight(.black))
                            .foregroundStyle(Color.ink)
                        Text("Retire-les pour toujours").font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.inkSoft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color.inkSoft)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1.5))
            }
            .buttonStyle(.row)
            .accessibilityHint("Ouvre la boutique")
        }
    }
}

/// Bannière de l'accueil quand des cadeaux du pass attendent : bien visible, elle ouvre le pass.
struct GiftsBanner: View {
    let count: Int
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: Space.m) {
                Image("shop_gift").resizable().scaledToFit().frame(width: 44, height: 44)
                    .phaseAnimator(reduceMotion ? [0.0] : [0.0, -8, 8, 0]) { content, angle in
                        content.rotationEffect(.degrees(angle))
                    } animation: { _ in .easeInOut(duration: 0.18).delay(0.6) }
                Text(count > 1 ? "\(count) cadeaux à récupérer" : "1 cadeau à récupérer")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(Color.inkFixed)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .black)).foregroundStyle(Color.inkFixed)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.sun, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .shadow(color: Color.sun.opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(.row)
        .accessibilityHint("Ouvre le pass de saison")
    }
}

/// Rappel après une pub entre les parties (une fois par jour au plus) : « Marre des pubs ? ».
struct NoAdsPrompt: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Space.m) {
            Image("shop_noads").resizable().scaledToFit().frame(width: 120, height: 120)
            Text("Marre des pubs ?").font(.system(.title2, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
            Text("Retire-les pour toujours, en un seul paiement.")
                .font(.cfCallout).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
            BuyButton(title: "Voir l'offre") {
                dismiss()
                app.openShop(from: "after_ad", focus: .noAds)
            }
            Button("Plus tard") { dismiss() }
                .buttonStyle(.textLink)
        }
        .padding(Space.l)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.paper)
    }
}
