import SwiftUI
import CultFiveCore

/// Une récompense de palier du pass (D-049). Les deux pistes viennent du serveur (season_overview).
struct PassReward: Identifiable {
    let id = UUID()
    /// Icône 3D (dossier AlbumData/pass).
    let icon: String
    let name: String
    var star = false

    init(_ icon: String, _ name: String, star: Bool = false) {
        self.icon = icon
        self.name = name
        self.star = star
    }

    /// Récompense d'une piste, telle que le serveur la décrit.
    init(_ reward: SeasonOverview.Reward) {
        self.init(reward.icon, reward.label, star: ["final", "token", "perk", "coffret"].contains(reward.kind))
    }

    /// Piste Pass+ de la saison 1, en aperçu quand le serveur n'en renvoie pas encore.
    static let paid: [PassReward] = [
        .init("sans_pub", "Plus de pub toute la saison", star: true), .init("dos_domaines", "Dos « Les 12 domaines »"),
        .init("autoc_fondateur", "Autocollant « Fondateur »"), .init("titre_grand_curieux", "Titre « Grand curieux »"),
        .init("cadre_vitrail", "Cadre Vitrail"), .init("jeton", "Jeton Prestige n° 1", star: true),
        .init("coffret", "Coffret de catégorie n° 1", star: true), .init("finition_givre", "Finition Givre"),
        .init("titrej_savant", "Titre « Savant »"), .init("cadre_nuit", "Cadre Nuit étoilée"), .init("socle_or", "Socle Or"),
        .init("autoc_chauve", "Autocollant « Chauve-souris »"), .init("couv_grimoire", "Couverture « Grimoire »"),
        .init("titre_chasseur", "Titre « Chasseur de légendes »"), .init("jeton", "Jeton Prestige n° 2", star: true),
        .init("finition_or", "Finition Poussière d'or"), .init("cadre_toile", "Cadre « Toile d'araignée »"),
        .init("coffret", "Coffret de catégorie n° 2", star: true), .init("socle_neon", "Socle Néon"),
        .init("titrej_legende", "Titre « Légende vivante »"), .init("cadre_marbre", "Cadre Marbre"),
        .init("marque", "Marque-page d'album"), .init("flamme", "Autocollant animé « Flamme »"),
        .init("finition_holo", "Finition Holographique"), .init("jeton", "Jeton Prestige n° 3", star: true),
        .init("coffret", "Coffret de catégorie n° 3", star: true), .init("titre_musee", "Titre « Pièce de musée »"),
        .init("couv_or", "Couverture « Feuille d'or »"), .init("vitrine", "Vitrine lumineuse"),
        .init("final_payant", "Dos Feuille d'or + cadre animé", star: true),
    ]
}

/// Pass de saison : 30 paliers de 150 points. Piste gratuite pour tous, piste Pass+ pour qui l'a acheté (avec plus de pub).
/// Les points viennent des objectifs du jour et de la semaine qui existent déjà, plus 12 missions de saison.
struct SeasonPassView: View {
    let store: AlbumStore
    var onOpen: (PackOpening) -> Void

    @Environment(AppModel.self) private var app
    @State private var claimed: PassReward?

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    hero
                    tracksCompare
                    catchUp
                    extraChests
                    ChallengesLink()
                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack {
                            Text("Les 30 paliers").font(.cfHeadline).foregroundStyle(Color.ink)
                            Spacer()
                            if store.tier > 0 {
                                Button {
                                    withAnimation(Motion.standard) { reader.scrollTo(store.tier, anchor: .center) }
                                } label: {
                                    Label("Mon palier", systemImage: "arrow.down.circle.fill")
                                        .font(.system(.caption, design: .rounded).weight(.heavy))
                                        .foregroundStyle(Color.brand)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.brand.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        PassTrack(store: store) { reward in
                            withAnimation(Motion.standard) { claimed = reward }
                            Task {
                                try? await Task.sleep(for: .seconds(1.6))
                                withAnimation(Motion.standard) { if claimed?.id == reward.id { claimed = nil } }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.m)
            }
        }
        .refreshable { await store.refresh() }
        .task { await store.refresh() }
        .clearsTabBar()
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Pass de saison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { TourButton(id: .pass) }
        }
        .guidedTour(.pass)
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
        let inTier = store.points % max(store.tierPoints, 1)
        let finished = store.tier >= store.tiers
        let progress = finished ? 1 : CGFloat(inTier) / CGFloat(max(store.tierPoints, 1))
        return HStack(spacing: Space.m) {
            ZStack {
                Circle().stroke(.white.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.sun, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text("\(store.tier)").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("/ \(store.tiers)").font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(.white.opacity(0.7))
                }
                .monospacedDigit()
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(seasonLine)
                    .font(.system(.caption2, design: .rounded).weight(.black)).tracking(2)
                    .foregroundStyle(.white.opacity(0.75))
                Text("Palier \(store.tier)")
                    .font(.system(.title2, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                Text(finished ? "Tout le pass est débloqué." : "\(inTier)/\(store.tierPoints) points vers le palier \(store.tier + 1)")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.sun)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.25), radius: 16, y: 8)
    }

    /// « SAISON 1 · ENCORE 12 JOURS », d'après les dates du serveur.
    private var seasonLine: String {
        guard let season = store.season.season else { return "PAS DE SAISON EN COURS" }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let end = formatter.date(from: season.endsOn) else { return season.name.uppercased() }
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: end).day ?? 0)
        return "\(season.name.uppercased()) · ENCORE \(days) JOUR\(days > 1 ? "S" : "")"
    }

    /// Après le palier 30 : un coffre en bois tous les 150 points (10 au plus).
    @ViewBuilder private var extraChests: some View {
        if let extra = store.season.extraChests, extra.earned > extra.claimed {
            let count = extra.earned - extra.claimed
            ShopButton(title: "Récupérer \(count) coffre\(count > 1 ? "s" : "") en bois", price: nil, icon: "chest_wood",
                       fill: .sun, text: .inkFixed, enabled: !store.busy) {
                Task { if await store.claimExtra() > 0 { Haptics.success() } }
            }
        }
    }

    /// Ce que donne chaque piste, côte à côte.
    private var tracksCompare: some View {
        HStack(alignment: .top, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 8) {
                TrackBadge(paid: false)
                perk("11 coffres")
                perk("8 tickets de pochette")
                perk("1 jeton Prestige")
                perk("Pochette dorée au 30")
                Spacer(minLength: 0)
                Text("Pour tout le monde")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.inkSoft)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 8) {
                TrackBadge(paid: true)
                perk("Plus de pub", onDark: true)
                perk("3 jetons Prestige", onDark: true)
                perk("3 coffrets de catégorie", onDark: true)
                perk("Cadres, finitions, dos", onDark: true)
                Spacer(minLength: 0)
                passPlusAction
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PassPlusFill(), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(CardRarity.legend.border, lineWidth: 2))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Bas de la colonne Pass+ : actif, à activer, ou bientôt.
    @ViewBuilder private var passPlusAction: some View {
        if store.passPlusActive {
            Label("Actif", systemImage: "checkmark.seal.fill")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.sun)
        } else if app.passPlusForSale {
            Button {
                Haptics.selection()
                app.openPassPlus(from: "pass")
            } label: {
                Text(app.passPlus.price.map { "Activer · \($0)" } ?? "Activer")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Color.inkFixed)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.sun, in: Capsule())
            }
            .buttonStyle(.row)
        } else {
            Text("Bientôt")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.sun)
        }
    }

    /// Pass+ acheté en cours de saison : les paliers déjà atteints, d'un coup.
    @ViewBuilder private var catchUp: some View {
        let ready = store.season.passPlus?.rewards.filter { !$0.claimed && $0.tier <= store.tier }.count ?? 0
        if store.passPlusActive && ready > 1 {
            ShopButton(title: "Récupérer \(ready) paliers Pass+", price: nil, icon: "final_payant",
                       fill: .sun, text: .inkFixed, enabled: !store.busy) {
                Task {
                    let claimed = await store.claimAllPaid()
                    guard !claimed.isEmpty else { return }
                    Haptics.success()
                    app.show("\(claimed.count) récompenses Pass+ récupérées")
                }
            }
        }
    }

    private func perk(_ text: String, onDark: Bool = false) -> some View {
        HStack(spacing: 7) {
            // Puce simple aux couleurs de la piste (plus d'icône 3D ici).
            Circle()
                .fill(onDark ? Color.sun : Color.brand)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(onDark ? Color.white : Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Fond de la piste Pass+ : violet profond.
struct PassPlusFill: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        LinearGradient(colors: [Color(hex: 0x5B3CF0), Color(hex: 0x2A1490)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Étiquette d'une piste : « Gratuit » ou « Pass+ » avec sa couronne.
struct TrackBadge: View {
    let paid: Bool

    var body: some View {
        HStack(spacing: 4) {
            if paid { Image(systemName: "crown.fill") }
            Text(paid ? "PASS+" : "GRATUIT")
        }
        .font(.system(.caption, design: .rounded).weight(.black))
        .tracking(1)
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(paid ? Color.inkFixed : Color.brand)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(paid ? AnyShapeStyle(CardRarity.legend.border) : AnyShapeStyle(Color.brand.opacity(0.12)), in: Capsule())
    }
}

// MARK: - Lien vers les défis

/// Les défis sont sur l'écran du 5 : ce bouton y mène.
private struct ChallengesLink: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Gagner des points").font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
                Text("Tes défis du jour, de la semaine et de la saison font monter le pass.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.selection()
                app.pendingChallenges = true
                app.tab = .daily
            } label: {
                HStack(spacing: 4) {
                    Text("Voir les défis")
                    Image(systemName: "chevron.right")
                }
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.brand, in: Capsule())
                .shadow(color: Color.brand.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.row)
        }
        .popCard()
    }
}

// MARK: - Les paliers, à la verticale

/// Une ligne par palier : à gauche la case Gratuit (blanche), au centre le numéro sur une barre verticale remplie
/// jusqu'au palier atteint, à droite la case Pass+ (violette, liseré doré, cadenas tant qu'il n'est pas activé).
private struct PassTrack: View {
    let store: AlbumStore
    var onClaim: (PassReward) -> Void

    @Environment(AppModel.self) private var app

    /// Piste Pass+ du serveur, ou l'aperçu de la saison 2.
    private var paidRewards: [SeasonOverview.Reward]? {
        guard let rewards = store.season.passPlus?.rewards, !rewards.isEmpty else { return nil }
        return rewards
    }

    private let node: CGFloat = 36
    private let rowGap: CGFloat = 10

    var body: some View {
        VStack(spacing: rowGap) {
            HStack(spacing: Space.s) {
                TrackBadge(paid: false).frame(maxWidth: .infinity)
                Color.clear.frame(width: node, height: 1)
                TrackBadge(paid: true).frame(maxWidth: .infinity)
            }
            ForEach(1...max(store.tiers, 1), id: \.self) { tier in
                row(tier).id(tier)
            }
        }
    }

    private func row(_ tier: Int) -> some View {
        let reached = tier <= store.tier
        return HStack(spacing: Space.s) {
            if let reward = store.season.rewards.first(where: { $0.tier == tier }) {
                cell(PassReward(reward), tier: tier, paid: false, taken: reward.claimed)
            } else {
                Color.clear.frame(maxWidth: .infinity, minHeight: 66)
            }
            ZStack {
                // Morceau de barre verticale qui relie les paliers.
                Rectangle()
                    .fill(reached ? Color.sun : Color.hairline)
                    .frame(width: 6)
                    .padding(.vertical, -rowGap / 2 - 1)
                Text("\(tier)")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(reached ? Color.inkFixed : Color.inkSoft)
                    .frame(width: node, height: node)
                    .background(reached ? Color.sun : Color.paperRaised, in: Circle())
                    .overlay(Circle().strokeBorder(reached ? Color.white : Color.hairline, lineWidth: 2))
                    .shadow(color: reached ? Color.sun.opacity(0.5) : .clear, radius: 6)
            }
            .frame(width: node)
            if let paid = paidRewards {
                if let reward = paid.first(where: { $0.tier == tier }) {
                    cell(PassReward(reward), tier: tier, paid: true, taken: reward.claimed)
                } else {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 66)
                }
            } else if tier <= PassReward.paid.count {
                cell(PassReward.paid[tier - 1], tier: tier, paid: true, taken: false)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func cell(_ reward: PassReward, tier: Int, paid: Bool, taken: Bool) -> some View {
        let reached = tier <= store.tier
        // Piste Pass+ verrouillée tant que le Pass+ n'est pas actif : la toucher ouvre l'écran du Pass+.
        let locked = paid && (!store.passPlusActive || paidRewards == nil)
        let ready = reached && !taken && !locked && !store.busy
        return Button {
            if locked && app.passPlusForSale {
                Haptics.selection()
                app.openPassPlus(from: "pass_tier")
                return
            }
            guard ready else { Haptics.error(); return }
            Task {
                if await store.claim(tier: tier, track: paid ? .paid : .free) {
                    Haptics.success()
                    onClaim(reward)
                }
            }
        } label: {
            HStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    AlbumImage(kind: .pass, name: reward.icon)
                        .frame(width: 48, height: 48)
                        .opacity(reached ? 1 : 0.55)
                    if taken {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.correct)
                            .background(Circle().fill(.white))
                    } else if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.inkFixed)
                            .padding(4)
                            .background(Color.sun, in: Circle())
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(reward.name)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(paid ? Color.white : Color.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    if ready {
                        Text("Récupérer")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color.inkFixed)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.sun, in: Capsule())
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(maxWidth: .infinity, minHeight: 66, maxHeight: .infinity, alignment: .leading)
            .background {
                if paid {
                    RoundedRectangle(cornerRadius: Radius.s, style: .continuous).fill(PassPlusFill())
                } else {
                    RoundedRectangle(cornerRadius: Radius.s, style: .continuous).fill(Color.paperRaised)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .strokeBorder(ready ? AnyShapeStyle(Color.sun)
                                        : (paid ? AnyShapeStyle(CardRarity.legend.border) : AnyShapeStyle(Color.hairline)),
                                  lineWidth: ready ? 3 : 1.5)
            )
            .shadow(color: ready ? Color.sun.opacity(0.6) : Color(hex: 0x3A1FB8).opacity(0.07), radius: ready ? 10 : 6, y: 3)
            .saturation(reached || paid ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(paid ? "Pass+" : "Gratuit"), palier \(tier) : \(reward.name)\(taken ? ", récupéré" : ready ? ", à récupérer" : "")")
    }
}

/// Bonus d'un groupe de défis : une barre à la couleur du groupe qui se remplit à chaque défi, verte une fois gagnée.
/// Le bonus est en points de saison ; `extra` dit ce qu'il donne en plus (un coffre).
struct BonusBar: View {
    let bonus: Int
    let count: Int
    let total: Int
    let accent: Color
    var extra: String? = nil

    private var won: Bool { count >= total }

    var body: some View {
        let color = won ? Color.correct : accent
        let progress = CGFloat(min(count, total)) / CGFloat(max(total, 1))
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: Space.s) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(won ? "Bonus gagné" : "Bonus · fais les \(total) défis")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(won ? Color.correct : Color.ink)
                    if let extra {
                        Text(extra)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text("+\(bonus) pts")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(color, in: Capsule())
                    .fixedSize()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        .animation(Motion.standard, value: count)
        .accessibilityElement(children: .combine)
    }
}
