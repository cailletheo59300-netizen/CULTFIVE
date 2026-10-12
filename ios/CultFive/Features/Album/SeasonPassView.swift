import SwiftUI

/// Une récompense de palier du pass (D-049).
struct PassReward: Identifiable {
    enum Kind { case chest(Int), ticket, token, coffret, unlock([String]), finalFree, finalPaid }

    let id = UUID()
    /// Icône 3D (dossier AlbumData/pass).
    let icon: String
    let name: String
    let kind: Kind
    var star = false

    /// Le type se déduit de l'icône : coffres en neurones, tickets, jetons, coffrets, sinon un habillage à débloquer.
    init(_ icon: String, _ name: String, star: Bool = false) {
        self.icon = icon
        self.name = name
        self.star = star
        switch icon {
        case "chest_wood": kind = .chest(30)
        case "chest_silver": kind = .chest(60)
        case "chest_gold": kind = .chest(120)
        case "chest_savant": kind = .chest(250)
        case "ticket_pochette": kind = .ticket
        case "jeton": kind = .token
        case "coffret": kind = .coffret
        case "final_gratuit": kind = .finalFree
        case "final_payant": kind = .finalPaid
        default:
            // « cadre_vitrail » → « cadre.vitrail », « titre_grand_curieux » → « titre.grand_curieux ».
            if let cut = icon.firstIndex(of: "_") {
                kind = .unlock([String(icon[..<cut]) + "." + String(icon[icon.index(after: cut)...])])
            } else {
                kind = .unlock(["deco.\(icon)"])
            }
        }
    }

    static let free: [PassReward] = [
        .init("chest_wood", "Coffre en bois"), .init("autoc_s1", "Autocollant « Saison 1 »"), .init("ticket_pochette", "Ticket de pochette"),
        .init("chest_wood", "Coffre en bois"), .init("titre_curieux", "Titre « Curieux »"),
        .init("ticket_pochette", "Ticket de pochette"), .init("chest_silver", "Coffre en argent"), .init("cadre_citrouille", "Cadre Citrouille"),
        .init("ticket_pochette", "Ticket de pochette"), .init("dos_soleil", "Dos Soleil", star: true),
        .init("chest_silver", "Coffre en argent"), .init("titrej_explorateur", "Titre « Explorateur »"), .init("ticket_pochette", "Ticket de pochette"),
        .init("chest_silver", "Coffre en argent"), .init("socle_marbre", "Socle Marbre"),
        .init("ticket_pochette", "Ticket de pochette"), .init("chest_silver", "Coffre en argent"), .init("autoc_halloween", "Autocollant « Halloween »"),
        .init("ticket_pochette", "Ticket de pochette"), .init("jeton", "Jeton Prestige", star: true),
        .init("chest_gold", "Coffre en or"), .init("titre_erudit", "Titre « Érudit »"), .init("ticket_pochette", "Ticket de pochette"),
        .init("chest_gold", "Coffre en or"), .init("titrej_batisseur", "Titre « Bâtisseur »"),
        .init("ticket_pochette", "Ticket de pochette"), .init("chest_gold", "Coffre en or"), .init("couv_automne", "Couverture « Automne »"),
        .init("chest_savant", "Coffre Savant", star: true), .init("final_gratuit", "Dos Nuit étoilée + pochette dorée", star: true),
    ]

    static let paid: [PassReward] = [
        .init("dos_domaines", "Dos « Les 12 domaines »"), .init("autoc_fondateur", "Autocollant « Fondateur »"), .init("titre_grand_curieux", "Titre « Grand curieux »"),
        .init("cadre_vitrail", "Cadre Vitrail"), .init("jeton", "Jeton Prestige n° 1", star: true),
        .init("onglets", "Onglets d'album colorés"), .init("coffret", "Coffret de catégorie n° 1", star: true), .init("finition_givre", "Finition Givre"),
        .init("titrej_savant", "Titre « Savant »"), .init("cadre_nuit", "Cadre Nuit étoilée"),
        .init("socle_or", "Socle Or"), .init("autoc_chauve", "Autocollant « Chauve-souris »"), .init("couv_grimoire", "Couverture « Grimoire »"),
        .init("titre_chasseur", "Titre « Chasseur de légendes »"), .init("jeton", "Jeton Prestige n° 2", star: true),
        .init("finition_or", "Finition Poussière d'or"), .init("cadre_toile", "Cadre « Toile d'araignée »"), .init("coffret", "Coffret de catégorie n° 2", star: true),
        .init("socle_neon", "Socle Néon"), .init("titrej_legende", "Titre « Légende vivante »"),
        .init("cadre_marbre", "Cadre Marbre"), .init("marque", "Marque-page d'album"), .init("flamme", "Autocollant animé « Flamme »"),
        .init("finition_holo", "Finition Holographique"), .init("jeton", "Jeton Prestige n° 3", star: true),
        .init("coffret", "Coffret de catégorie n° 3", star: true), .init("titre_musee", "Titre « Pièce de musée »"), .init("couv_or", "Couverture « Feuille d'or »"),
        .init("vitrine", "Vitrine lumineuse"), .init("final_payant", "Dos Feuille d'or + cadre animé", star: true),
    ]
}

/// Pass de saison (aperçu TestFlight) : 30 paliers de 150 points sur deux mois, piste gratuite et piste Pass+.
/// Les points viennent des objectifs du jour et de la semaine qui existent déjà, plus 12 missions de saison.
struct SeasonPassView: View {
    let store: AlbumStore
    var onOpen: (PackOpening) -> Void

    @State private var doneDaily: Set<Int> = []
    @State private var doneWeekly: Set<Int> = []
    @State private var doneMissions: Set<Int> = []
    @State private var claimed: PassReward?

    private let daily = ["Fais le 5 du jour", "Joue 2 parties classées", "Réponds à 20 questions"]
    private let weekly = ["Joue 8 parties classées", "Joue dans 4 domaines différents", "Fais un sans-faute au 5 du jour"]
    private let missions = ["Finis une page de l'album", "Ouvre 5 pochettes Histoire", "Fabrique une carte dans l'album", "Obtiens une carte brillante",
                            "Gagne 3 duels", "Fais 7 jours de suite", "Réussis un 5 du jour parfait", "Maîtrise 3 cartes (3 étoiles)",
                            "Complète 10 cartes Nature", "Joue dans 8 domaines différents", "Mets 3 cartes en vitrine", "Trouve une légendaire"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                hero
                if !store.passPlus { passPlusOffer }
                track
                objectives
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.m)
        }
        .clearsTabBar()
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Pass de saison")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let claimed {
                Toast(text: "\(claimed.name) récupéré")
                    .padding(.top, Space.s)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - En-tête

    private var hero: some View {
        let inTier = store.points % AlbumStore.tierPoints
        let finished = store.tier >= AlbumStore.tiers
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("SAISON 1 · 61 JOURS").font(.system(.caption, design: .rounded).weight(.black)).tracking(2).foregroundStyle(.white.opacity(0.8))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Palier").font(.cfTitle3).foregroundStyle(.white)
                Text("\(store.tier)").numeral(size: 44).foregroundStyle(Color.sun)
                Text("/ \(AlbumStore.tiers)").font(.cfTitle3).foregroundStyle(.white.opacity(0.7))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(Color.sun)
                        .frame(width: proxy.size.width * (finished ? 1 : CGFloat(inTier) / CGFloat(AlbumStore.tierPoints)))
                }
            }
            .frame(height: 10)
            Text(finished ? "Bravo, tout le pass est débloqué." : "\(inTier) / \(AlbumStore.tierPoints) points vers le palier \(store.tier + 1)")
                .font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.25), radius: 16, y: 8)
    }

    private var passPlusOffer: some View {
        HStack(spacing: Space.m) {
            AlbumImage(kind: .pass, name: "final_payant").frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text("Pass+").font(.cfTitle3).foregroundStyle(Color.ink)
                Text("La deuxième piste : apparence et contenus connus à l'avance. Jamais de neurones ni de pochettes.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                Button("Activer (simulation)") {
                    Haptics.success()
                    withAnimation(Motion.standard) { store.passPlus = true }
                    store.save()
                }
                .buttonStyle(.sun)
            }
        }
        .popCard()
    }

    // MARK: - Les paliers

    private var track: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Paliers").font(.cfHeadline).foregroundStyle(Color.ink)
                Spacer()
                Text("Gratuit · Pass+").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(1...AlbumStore.tiers, id: \.self) { tier in
                            column(tier)
                                .id(tier)
                        }
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, -Space.gutter)
                .onAppear { reader.scrollTo(max(1, store.tier), anchor: .center) }
            }
        }
    }

    private func column(_ tier: Int) -> some View {
        let reached = tier <= store.tier
        return VStack(spacing: 8) {
            rewardCell(PassReward.free[tier - 1], tier: tier, paid: false)
            Text("\(tier)")
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundStyle(reached ? Color.inkFixed : Color.inkSoft)
                .frame(width: 34, height: 34)
                .background(reached ? Color.sun : Color.hairline, in: Circle())
            rewardCell(PassReward.paid[tier - 1], tier: tier, paid: true)
        }
    }

    private func rewardCell(_ reward: PassReward, tier: Int, paid: Bool) -> some View {
        let reached = tier <= store.tier
        let taken = paid ? store.claimedPaid.contains(tier) : store.claimedFree.contains(tier)
        let locked = paid && !store.passPlus
        let ready = reached && !taken && !locked
        return Button {
            guard ready else { Haptics.error(); return }
            Haptics.success()
            store.claim(reward, tier: tier, paid: paid)
            withAnimation(Motion.standard) { claimed = reward }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(Motion.standard) { if claimed?.id == reward.id { claimed = nil } }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    AlbumImage(kind: .pass, name: reward.icon)
                        .frame(width: 64, height: 64)
                        .opacity(reached && !locked ? 1 : 0.45)
                        .saturation(reached && !locked ? 1 : 0.4)
                    if taken {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.correct).font(.title3)
                    } else if locked {
                        Image(systemName: "lock.fill").foregroundStyle(Color.inkSoft).font(.footnote.weight(.bold))
                    }
                }
                Text(reward.name)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(3).multilineTextAlignment(.center)
                    .frame(width: 84, height: 40, alignment: .top)
            }
            .padding(8)
            .background(paid ? Color(hex: 0xFFF6DA) : Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .strokeBorder(ready ? Color.sun : (reward.star ? Color.brand.opacity(0.35) : .clear), lineWidth: ready ? 3 : 1.5)
            )
            .shadow(color: ready ? Color.sun.opacity(0.6) : Color(hex: 0x3A1FB8).opacity(0.06), radius: ready ? 10 : 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(paid ? "Pass+" : "Gratuit"), palier \(tier) : \(reward.name)\(taken ? ", récupéré" : ready ? ", à récupérer" : "")")
    }

    // MARK: - Points de saison

    private var objectives: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Gagner des points").font(.cfHeadline).foregroundStyle(Color.ink)
            Text("Tes objectifs habituels rapportent aussi des points de saison. Touche un objectif pour le valider (aperçu).")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            objectiveGroup("Objectifs du jour", items: daily, points: 15, bonus: 15, done: $doneDaily)
            objectiveGroup("Objectifs de la semaine", items: weekly, points: 40, bonus: 60, done: $doneWeekly)
            objectiveGroup("Missions de saison · en plus", items: missions, points: 75, bonus: nil, done: $doneMissions)
        }
    }

    private func objectiveGroup(_ title: String, items: [String], points: Int, bonus: Int?, done: Binding<Set<Int>>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).labelCaps()
            ForEach(items.indices, id: \.self) { i in
                let isDone = done.wrappedValue.contains(i)
                Button {
                    guard !isDone else { return }
                    Haptics.selection()
                    done.wrappedValue.insert(i)
                    var gained = points
                    if let bonus, done.wrappedValue.count == items.count { gained += bonus }
                    withAnimation(Motion.standard) { store.addPoints(gained) }
                } label: {
                    HStack(spacing: Space.s) {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isDone ? Color.correct : Color.inkSoft)
                        Text(items[i]).font(.cfCallout).foregroundStyle(Color.ink).strikethrough(isDone, color: .inkSoft)
                        Spacer()
                        Text("+\(points)").font(.cfNumber).foregroundStyle(Color.brand)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if let bonus {
                HStack {
                    Text("Bonus : tous les objectifs").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    Spacer()
                    Text("+\(bonus)").font(.cfNumber).foregroundStyle(done.wrappedValue.count == items.count ? Color.correct : Color.inkSoft)
                }
            }
        }
        .popCard()
    }
}
