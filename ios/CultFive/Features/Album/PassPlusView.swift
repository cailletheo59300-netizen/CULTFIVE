import SwiftUI
import CultFiveCore

/// Écran du Pass+ (D-118) : une image plutôt que du texte. Au centre, le cadeau du palier 30, entouré des plus beaux
/// cadeaux de la piste ; trois lignes courtes ; le bouton d'achat ; puis les 30 cadeaux, chacun s'ouvre en grand.
/// Paiement unique pour la saison en cours (achat consommable, racheté à chaque saison) : rien ne se renouvelle tout seul.
struct PassPlusView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var store = AlbumStore.shared
    @State private var preview: PassPreviewItem?
    private var shop: ShopStore { app.shop }
    private var active: Bool { store.passPlusActive }

    /// Piste Pass+ du serveur, sinon l'aperçu de la saison 1.
    private var rewards: [PassPreviewItem] {
        if let paid = store.season.passPlus?.rewards, !paid.isEmpty {
            return paid.map { PassPreviewItem(tier: $0.tier, paid: true, taken: $0.claimed, icon: $0.icon, name: $0.label) }
        }
        return PassReward.paid.enumerated().map { PassPreviewItem(tier: $0.offset + 1, paid: true, taken: false, icon: $0.element.icon, name: $0.element.name) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                header
                PassPlusCollage()
                highlights
                buyArea
                gifts
                legal
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.m)
            .containerRelativeFrame(.horizontal)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .background(Rectangle().fill(PassPlusFill()).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("Fermer")
            .padding(Space.m)
        }
        .sheet(item: $preview) { PassRewardPreview(item: $0) }
        .task {
            await shop.loadProducts()
            await store.refresh()
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 2) {
            Text("PASS+")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE680), Color.sun, Color(hex: 0xF2A900)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.sun.opacity(0.45), radius: 12)
            Text(seasonLine)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, Space.s)
    }

    private var seasonLine: String {
        guard let season = store.season.season else { return "Pour toute une saison" }
        return "\(season.name) · jusqu'au \(Self.day(season.endsOn))"
    }

    /// « 28 mars » à partir de « 2027-03-28 ».
    static func day(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: iso) else { return iso }
        let output = DateFormatter()
        output.locale = Locale(identifier: "fr_FR")
        output.dateFormat = "d MMMM"
        return output.string(from: date)
    }

    // MARK: - Trois lignes

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            line("gift.fill", "\(rewards.count) cadeaux exclusifs pour ton album")
            line("nosign", store.season.season.map { "Zéro pub jusqu'au \(Self.day($0.endsOn))" } ?? "Zéro pub toute la saison")
            line("bolt.fill", "Déjà avancé ? Tes paliers atteints, tout de suite")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.m)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.inkFixed)
                .frame(width: 30, height: 30)
                .background(Color.sun, in: Circle())
            Text(text)
                .font(.system(.callout, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Achat

    @ViewBuilder private var buyArea: some View {
        VStack(spacing: Space.s) {
            if active {
                Label("Ton Pass+ est actif", systemImage: "checkmark.seal.fill")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(Color.sun)
                    .frame(maxWidth: .infinity, minHeight: 58)
            } else if app.passPlusForSale {
                BuyButton(title: "Activer le Pass+", price: shop.price(.passPlus), busy: shop.purchasing == .passPlus,
                          enabled: !shop.busy) {
                    Task {
                        if await shop.purchase(.passPlus) {
                            Haptics.success()
                            app.show("Pass+ activé !")
                        }
                    }
                }
                Text("Paiement unique pour la saison")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("Le Pass+ n'est pas encore en vente pour cette saison.")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 58)
            }
            if let error = shop.errorMessage {
                Text(error).font(.cfFootnote).foregroundStyle(Color.sun).multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Les cadeaux

    private var gifts: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Les \(rewards.count) cadeaux")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.white)
            Text("Touche un cadeau pour le voir en grand.")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(rewards) { item in
                    Button {
                        Haptics.selection()
                        preview = item
                    } label: {
                        VStack(spacing: 4) {
                            AlbumImage(kind: .pass, name: item.icon).frame(width: 58, height: 58)
                            Text(item.name)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, minHeight: 28, alignment: .top)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            Text("\(item.tier)")
                                .font(.system(size: 10, weight: .black, design: .rounded)).monospacedDigit()
                                .foregroundStyle(Color.inkFixed)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.sun, in: Circle())
                                .padding(5)
                        }
                    }
                    .buttonStyle(.row)
                    .accessibilityLabel("Palier \(item.tier) : \(item.name)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legal: some View {
        VStack(spacing: 6) {
            Button("Restaurer mes achats") { Task { await shop.restore() } }
                .buttonStyle(.textLink)
                .tint(Color.sun)
                .disabled(shop.busy)
            Text("Paiement unique pour la saison en cours, sans abonnement : rien ne se renouvelle tout seul. Le Pass+ est lié à ton compte \(Brand.name).")
                .font(.cfFootnote).foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.m) {
                Link("Conditions", destination: Brand.termsURL)
                Link("Confidentialité", destination: Brand.privacyURL)
            }
            .font(.cfFootnote.weight(.bold))
            .tint(Color.sun)
        }
        .frame(maxWidth: .infinity)
    }
}

/// L'image du Pass+ : le cadeau du palier 30 au centre, dans un halo doré, et les plus beaux cadeaux autour, qui
/// flottent. Un macaron « zéro pub » rappelle le bonus de la saison.
struct PassPlusCollage: View {
    private static let orbit = ["cadre_vitrail", "dos_domaines", "coffret", "finition_holo",
                                "jeton", "couv_or", "titre_chasseur", "socle_neon"]
    private static let height: CGFloat = 320

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                halo
                ForEach(0..<Self.orbit.count, id: \.self) { index in
                    orbitIcon(index, size: proxy.size)
                }
                centerpiece
                noAdsBadge.offset(y: Self.height * 0.3)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: Self.height)
        .accessibilityElement()
        .accessibilityLabel("Les cadeaux du Pass+ et zéro pub toute la saison")
    }

    private var halo: some View {
        Circle()
            .fill(RadialGradient(colors: [Color.sun.opacity(0.55), Color.sun.opacity(0.12), .clear],
                                 center: .center, startRadius: 6, endRadius: Self.height * 0.55))
            .frame(width: Self.height * 1.1, height: Self.height * 1.1)
    }

    private func orbitIcon(_ index: Int, size: CGSize) -> some View {
        let angle = Double(index) / Double(Self.orbit.count) * 2 * .pi - .pi / 2
        let x = cos(angle) * (size.width / 2 - 40)
        let y = sin(angle) * (size.height / 2 - 36)
        let period = 1.8 + Double(index % 3) * 0.35
        return AlbumImage(kind: .pass, name: Self.orbit[index])
            .frame(width: 66, height: 66)
            .floating(5, period: period)
            .offset(x: x, y: y)
    }

    private var centerpiece: some View {
        AlbumImage(kind: .pass, name: "final_payant")
            .frame(width: Self.height * 0.52, height: Self.height * 0.52)
            .shadow(color: Color.sun.opacity(0.5), radius: 18)
            .floating(7, period: 2.6)
    }

    private var noAdsBadge: some View {
        HStack(spacing: 4) {
            Image("shop_noads").resizable().scaledToFit().frame(width: 26, height: 26)
            Text("ZÉRO PUB").font(.system(size: 12, weight: .black, design: .rounded)).tracking(0.5)
        }
        .foregroundStyle(Color.inkFixed)
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .background(Color.sun, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }
}
