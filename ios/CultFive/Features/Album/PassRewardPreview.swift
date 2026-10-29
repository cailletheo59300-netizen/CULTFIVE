import SwiftUI
import CultFiveCore

/// Une récompense du pass touchée : de quel palier et de quelle piste, et si elle est déjà prise.
struct PassPreviewItem: Identifiable, Hashable {
    let tier: Int
    let paid: Bool
    let taken: Bool
    let icon: String
    let name: String
    var id: String { "\(paid ? "paid" : "free")-\(tier)" }
}

/// Aperçu en grand d'une récompense du pass (D-118) : on la voit toujours, même verrouillée. Un cadre, une finition ou
/// un titre se montre posé sur une vraie carte, un dos de carte en grand ; on fait pivoter du doigt. En bas : récupérer,
/// le palier à atteindre, ou « Activer le Pass+ ».
struct PassRewardPreview: View {
    let item: PassPreviewItem
    var onClaim: (PassReward) -> Void = { _ in }

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var tilt: CGSize = .zero
    private let store = AlbumStore.shared

    var body: some View {
        VStack(spacing: Space.m) {
            HStack {
                TrackBadge(paid: item.paid)
                Text("Palier \(item.tier)")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                        .frame(width: 34, height: 34).background(.white.opacity(0.18), in: Circle())
                }
                .accessibilityLabel("Fermer")
            }
            Spacer(minLength: 0)
            visual
                .rotation3DEffect(.degrees(tilt.width * 18), axis: (x: 0, y: 1, z: 0))
                .rotation3DEffect(.degrees(-tilt.height * 14), axis: (x: 1, y: 0, z: 0))
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        tilt = CGSize(width: max(-1, min(1, value.translation.width / 140)),
                                      height: max(-1, min(1, value.translation.height / 180)))
                    }
                    .onEnded { _ in withAnimation(Motion.bounce) { tilt = .zero } })
                .frame(maxHeight: 380)
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Text(item.name)
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if let detail = Self.detail(item.icon) {
                    Text(detail)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            action
        }
        .padding(Space.l)
        .background {
            Group {
                if item.paid { Rectangle().fill(PassPlusFill()) } else { Rectangle().fill(Color.popGradient) }
            }
            .ignoresSafeArea()
        }
        .presentationDetents([.large])
    }

    // MARK: - Aperçu

    /// Carte d'exemple pour poser un habillage : une légendaire de l'album.
    private static var sample: AlbumCard? {
        AlbumCatalog.shared.cards.first { $0.rarity == .legend } ?? AlbumCatalog.shared.cards.first
    }

    @ViewBuilder private var visual: some View {
        let icon = item.icon
        if let state = Self.dressing(icon), let card = Self.sample {
            AlbumCardView(card: card, state: state, tilt: tilt)
                .frame(maxWidth: 250)
                .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
        } else if icon.hasPrefix("dos_") {
            AlbumCardBack(kind: String(icon.dropFirst(4)))
                .frame(maxWidth: 250)
                .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
        } else {
            ZStack {
                Circle().fill(RadialGradient(colors: [Color.sun.opacity(0.45), .clear], center: .center, startRadius: 10, endRadius: 170))
                AlbumImage(kind: .pass, name: icon)
                    .frame(width: 230, height: 230)
                    .floating(8)
            }
        }
    }

    /// Habillage posé sur la carte d'exemple : cadre, finition, titre de carte (le cadre animé pour le palier 30).
    private static func dressing(_ icon: String) -> OwnedCard? {
        var state = OwnedCard()
        if icon == "final_payant" { state.frame = "anime"; return state }
        if icon.hasPrefix("cadre_") { state.frame = String(icon.dropFirst(6)); return state }
        if icon.hasPrefix("finition_") { state.finish = String(icon.dropFirst(9)); return state }
        if icon.hasPrefix("titre_") { state.title = String(icon.dropFirst(6)); return state }
        return nil
    }

    /// Une phrase pour dire à quoi sert la récompense.
    static func detail(_ icon: String) -> String? {
        let rules: [(String, String)] = [
            ("final_payant", "Le dos Feuille d'or et un cadre animé, le plus beau de la saison."),
            ("final_gratuit", "Une pochette dorée : une carte légendaire garantie."),
            ("sans_pub", "Plus aucune pub pendant toute la saison."),
            ("cadre_", "Un cadre à poser sur n'importe quelle carte de ton album."),
            ("finition_", "Une finition qui fait briller tes cartes quand tu bouges le téléphone."),
            ("titre_", "Un ruban de titre sous tes cartes préférées."),
            ("titrej_", "Un titre de joueur pour ton profil."),
            ("dos_", "Le dos de toutes les cartes de ton album."),
            ("couv_", "La couverture de ton album."),
            ("socle_", "Un socle pour la vitrine de ton profil."),
            ("autoc_", "Un autocollant pour décorer ton album."),
            ("flamme", "Un autocollant animé pour décorer ton album."),
            ("jeton", "Rends une carte Prestige : son dessin occupe toute la carte, sur fond holographique."),
            ("coffret", "Tu choisis un domaine et tu vois les 3 cartes avant d'ouvrir."),
            ("chest_", "Un coffre à ouvrir : neurones, tickets, parfois une carte."),
            ("ticket_pochette", "Un ticket pour ouvrir une pochette de cartes."),
            ("doree", "Une pochette dorée : une carte légendaire garantie."),
            ("vitrine", "Une vitrine lumineuse pour tes plus belles cartes."),
            ("marque", "Un marque-page pour ton album."),
        ]
        return rules.first { icon.hasPrefix($0.0) }?.1
    }

    // MARK: - Action

    private var reached: Bool { item.tier <= store.tier }
    private var locked: Bool { item.paid && !store.passPlusActive }

    @ViewBuilder private var action: some View {
        if item.taken {
            Label("Déjà à toi", systemImage: "checkmark.seal.fill")
                .font(.system(.headline, design: .rounded).weight(.black))
                .foregroundStyle(Color.sun)
                .frame(minHeight: 58)
        } else if locked {
            VStack(spacing: 6) {
                if app.passPlusForSale {
                    BuyButton(title: "Activer le Pass+", price: app.shop.price(.passPlus),
                              busy: app.shop.purchasing == .passPlus, enabled: !app.shop.busy) {
                        Task {
                            if await app.shop.purchase(.passPlus) {
                                Haptics.success()
                                app.show("Pass+ activé !")
                            }
                        }
                    }
                    Text("Les 30 cadeaux, et tu récupères d'un coup les paliers déjà atteints.")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                } else {
                    Text("Le Pass+ n'est pas en vente en ce moment.")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(minHeight: 58)
                }
                if let error = app.shop.errorMessage {
                    Text(error).font(.cfFootnote).foregroundStyle(Color.sun).multilineTextAlignment(.center)
                }
            }
        } else if !reached {
            let missing = max(0, item.tier * store.tierPoints - store.points)
            VStack(spacing: 2) {
                Label("Palier \(item.tier)", systemImage: "lock.fill")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Text("Encore \(missing) points : fais tes défis du jour et de la semaine.")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .frame(minHeight: 58)
        } else {
            BuyButton(title: "Récupérer", busy: store.busy, enabled: !store.busy) {
                Task {
                    if await store.claim(tier: item.tier, track: item.paid ? .paid : .free) {
                        Haptics.success()
                        onClaim(PassReward(item.icon, item.name))
                        dismiss()
                    }
                }
            }
        }
    }
}
