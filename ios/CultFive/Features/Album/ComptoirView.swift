import SwiftUI
import CultFiveCore

/// Le Comptoir de Léon : pochettes par thème payées en neurones ou en tickets, la pochette dorée et l'offre du jour.
/// Tout passe par le serveur (album_open_pack, album_craft). Aucun argent réel ici.
struct ComptoirView: View {
    let store: AlbumStore
    var onOpen: (PackOpening) -> Void

    @Environment(AppModel.self) private var app
    @State private var selected = "encyclo"
    @State private var coffret: AlbumOverview.Coffret?
    /// Feuille des 3 façons d'ouvrir une pochette (touche sur la grande pochette du panneau).
    @State private var choice: PackSeries?
    /// Pochette touchée sur le rayon : elle passe au centre du rayon et le panneau d'achat se centre à l'écran.
    @State private var focusPanel = 0

    private let catalog = AlbumCatalog.shared
    private var series: PackSeries { catalog.series.first { $0.id == selected } ?? catalog.series[0] }

    var body: some View {
        ScrollViewReader { page in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    LeonSays(text: "Bienvenue au Comptoir ! Choisis une pochette : tu paies en neurones ou avec un ticket.", pose: .wave, size: 76)
                    wallet
                    if !store.coffrets.isEmpty {
                        section("Coffrets à ouvrir", detail: "Pass+ · tu choisis le domaine")
                        coffretRow
                    }
                    section("Pochettes", detail: "5 cartes, au moins 1 rare")
                    shelf
                    packPanel.id("achat")
                    section("Pochette dorée", detail: "1 légendaire garantie")
                    gold
                    if let offer = dailyOffer {
                        section("Offre du jour", detail: "une carte qui te manque")
                        offerCard(offer)
                    }
                    Text("Chances pour chaque carte : commune 70 %, rare 22 %, épique 6,5 %, légendaire 1,5 %. Au moins une rare par pochette.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.m)
            }
            .onChange(of: focusPanel) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { page.scrollTo("achat", anchor: .center) }
            }
        }
        .task { await app.refreshAdStatus() }
        .clearsTabBar()
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Comptoir de Léon")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $coffret) { item in
            CoffretPicker(store: store, coffret: item) { opening in
                coffret = nil
                // La feuille se ferme d'abord, puis l'ouverture plein écran.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onOpen(opening) }
            }
        }
        .sheet(item: $choice) { item in
            packSheet(item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Coffrets de catégorie (Pass+)

    private var coffretRow: some View {
        ShopButton(title: store.coffrets.count > 1 ? "Ouvrir un coffret (\(store.coffrets.count))" : "Ouvrir mon coffret",
                   price: nil, icon: "coffret", fill: .brand, text: .white, enabled: !store.busy) {
            coffret = store.coffrets.first
        }
    }

    private func section(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.cfHeadline).foregroundStyle(Color.ink).fixedSize()
            Spacer(minLength: Space.s)
            Text(detail).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.trailing).lineLimit(2).minimumScaleFactor(0.85)
        }
        .padding(.bottom, -Space.s)
    }

    // MARK: - Porte-monnaie

    private var wallet: some View {
        HStack(spacing: Space.s) {
            WalletTile(icon: "neurone", value: store.neurones, label: "Neurones",
                       tint: Color(hex: 0xF0588F), fill: [Color(hex: 0xFFF0F6), Color(hex: 0xFFE0EC)])
            WalletTile(icon: "ticket_pochette", value: store.tickets,
                       label: store.admin ? "Tickets" : "\(store.tickets > 1 ? "Tickets" : "Ticket") · \(AlbumStore.ticketMax) max",
                       tint: .brand, fill: [Color(hex: 0xF3EFFF), Color(hex: 0xE6DEFF)])
        }
    }

    // MARK: - Rayon des pochettes

    private var shelf: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(catalog.series) { item in
                        shelfItem(item).id(item.id)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, -Space.gutter)
            .onAppear { reader.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { reader.scrollTo(selected, anchor: .center) }
            }
        }
    }

    private func shelfItem(_ item: PackSeries) -> some View {
        let isOn = selected == item.id
        return Button {
            Haptics.selection()
            withAnimation(Motion.bounce) { selected = item.id }
            focusPanel += 1
        } label: {
            VStack(spacing: 8) {
                AlbumImage(kind: .packs, name: item.id)
                    .frame(width: 84, height: 126)
                    .shadow(color: item.tone.opacity(isOn ? 0.55 : 0.18), radius: isOn ? 14 : 6, y: isOn ? 8 : 4)
                    .offset(y: isOn ? -6 : 0)
                    .scaleEffect(isOn ? 1.06 : 1)
                Text(item.label)
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(isOn ? Color.ink : Color.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: 90)
                Text("\(store.ownedCount(item.cards))/\(item.cards.count)")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isOn ? .white : item.tone)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(isOn ? item.tone : item.tone.opacity(0.12), in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Série \(item.label), \(store.ownedCount(item.cards)) cartes sur \(item.cards.count)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Fiche de la pochette choisie

    private var packPanel: some View {
        let owned = store.ownedCount(series.cards)
        let total = series.cards.count
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .center, spacing: Space.m) {
                Button { choice = series } label: {
                    AlbumImage(kind: .packs, name: series.id)
                        .frame(width: 92, height: 138)
                        .shadow(color: series.tone.opacity(0.45), radius: 12, y: 6)
                }
                .buttonStyle(.row)
                .accessibilityLabel("Ouvrir la pochette \(series.label)")
                VStack(alignment: .leading, spacing: 6) {
                    Text(series.id == "encyclo" ? "Encyclopédie" : series.label)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(series.id == "encyclo" ? "Tous les thèmes mélangés" : "Seulement des cartes de ce thème")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.inkSoft)
                        .lineLimit(2)
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(series.tone.opacity(0.15))
                                Capsule().fill(series.tone).frame(width: proxy.size.width * CGFloat(owned) / CGFloat(max(total, 1)))
                            }
                        }
                        .frame(height: 7)
                        Text("\(owned) sur \(total) cartes dans ton album")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(series.tone)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            packButtons(series, then: onOpen)
        }
        .popCard()
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(series.tone.opacity(0.35), lineWidth: 2))
    }

    // MARK: - Les 3 façons d'ouvrir une pochette

    /// Neurones, ticket, ou pochette gratuite du jour (une pub, ou rien à regarder avec le Pass+).
    private func packButtons(_ series: PackSeries, then: @escaping (PackOpening) -> Void) -> some View {
        let missing = AlbumStore.packPrice - store.neurones
        return VStack(alignment: .leading, spacing: Space.m) {
            ShopButton(title: "Ouvrir la pochette", price: "\(AlbumStore.packPrice)", icon: "neurone",
                       fill: .brand, text: .white, enabled: store.neurones >= AlbumStore.packPrice && !store.busy) {
                Task { if let pulls = await store.buyPack(series, useTicket: false) { then(PackOpening(series: series, pulls: pulls)) } }
            }
            // 5 tickets au plus : au-delà, chaque ticket gagné devient 30 neurones (serveur 0057).
            ShopButton(title: "Utiliser un ticket", price: store.admin ? "∞" : "\(store.tickets)/\(AlbumStore.ticketMax)",
                       icon: "ticket_pochette", fill: .sun, text: .inkFixed, enabled: store.tickets > 0 && !store.busy) {
                Task { if let pulls = await store.buyPack(series, useTicket: true) { then(PackOpening(series: series, pulls: pulls)) } }
            }
            if let free = app.adStatus?.freePack {
                // Une pochette gratuite par jour contre une pub (vérifiée par le serveur, 0053).
                ShopButton(title: "Pochette gratuite", price: free == 0 ? "Demain" : app.noAds ? "Pass+" : "1 pub", icon: "ticket_pochette",
                           fill: Color(hex: 0x37B24D), text: .white, enabled: free > 0 && !store.busy) {
                    Task {
                        do {
                            guard try await app.watchAd(.freePack) != nil else { return }
                            if let pulls = await store.buyPack(series, useTicket: true) { then(PackOpening(series: series, pulls: pulls)) }
                        } catch {
                            app.show(error, "Pub indisponible pour l'instant.")
                        }
                    }
                }
            }
            if missing > 0 {
                Label("Il te manque \(missing) neurones pour l'ouvrir.", systemImage: "info.circle")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
    }

    /// Feuille d'une pochette touchée sur le rayon : la pochette, ce qu'il te manque, et les 3 façons de l'ouvrir.
    private func packSheet(_ series: PackSeries) -> some View {
        ScrollView {
            VStack(spacing: Space.m) {
                AlbumImage(kind: .packs, name: series.id)
                    .frame(width: 110, height: 165)
                    .shadow(color: series.tone.opacity(0.45), radius: 14, y: 8)
                    .padding(.top, Space.l)
                Text(series.id == "encyclo" ? "Encyclopédie" : series.label)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                Text("\(store.ownedCount(series.cards)) sur \(series.cards.count) cartes dans ton album · 5 cartes, au moins 1 rare")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .multilineTextAlignment(.center)
                packButtons(series) { opening in
                    choice = nil
                    // La feuille se ferme d'abord, puis l'ouverture plein écran.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onOpen(opening) }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .background(Color.paper.ignoresSafeArea())
    }

    // MARK: - Pochette dorée

    private var gold: some View {
        let legends = catalog.cards.filter { $0.rarity == .legend }.count
        let missing = AlbumStore.goldPackPrice - store.neurones
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                AlbumImage(kind: .packs, name: "gold")
                    .frame(width: 80, height: 120)
                    .shadow(color: Color(hex: 0xB8862A).opacity(0.5), radius: 12, y: 6)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Une légendaire garantie")
                        .font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
                    Text("Tirée parmi les \(legends) légendaires de l'album. Une par semaine.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            if store.goldPacks > 0 {
                ShopButton(title: "Ouvrir celle du pass", price: store.admin ? "∞" : "\(store.goldPacks)", icon: "doree", fill: .sun, text: .inkFixed, enabled: !store.busy) {
                    Task { if let pulls = await store.openOwnedGoldPack() { onOpen(PackOpening(series: catalog.series[0], pulls: pulls, gold: true)) } }
                }
            }
            ShopButton(title: store.goldBought ? "De retour lundi" : "Ouvrir la pochette dorée", price: "\(AlbumStore.goldPackPrice)", icon: "neurone",
                       fill: Color(hex: 0xC8902E), text: .white, enabled: !store.goldBought && missing <= 0 && !store.busy) {
                Task { if let pulls = await store.buyGoldPack() { onOpen(PackOpening(series: catalog.series[0], pulls: pulls, gold: true)) } }
            }
            if !store.goldBought && missing > 0 {
                Label("Il te manque \(missing) neurones.", systemImage: "info.circle")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
        .popCard(fill: Color(light: 0xFFF8E6, dark: 0x2A2214))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(CardRarity.legend.border, lineWidth: 2))
    }

    // MARK: - Offre du jour

    /// Une carte manquante (hors légendaire), la même toute la journée.
    private var dailyOffer: AlbumCard? {
        let missing = catalog.cards.filter { !store.isOwned($0) && $0.rarity != .legend }
        guard !missing.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return missing[day % missing.count]
    }

    private func offerCard(_ card: AlbumCard) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                AlbumCardView(card: card, state: nil, outlined: true)
                    .frame(width: 88)
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.name)
                        .font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
                        .lineLimit(2)
                    Text(AlbumCatalog.shared.page(card.pageKey)?.title ?? "")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft).lineLimit(2)
                    Text(card.rarity.label)
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(card.rarity.color, in: Capsule())
                }
            }
            ShopButton(title: "Prendre cette carte", price: "\(card.rarity.craftCost)", icon: "neurone",
                       fill: .brand, text: .white, enabled: store.neurones >= card.rarity.craftCost && !store.busy) {
                Task { if await store.craft(card) { Haptics.success() } }
            }
        }
        .popCard()
    }
}

/// Tuile du porte-monnaie : grosse icône 3D, gros chiffre, petit libellé.
private struct WalletTile: View {
    let icon: String
    let value: Int
    let label: String
    let tint: Color
    let fill: [Color]

    var body: some View {
        HStack(spacing: 10) {
            AlbumImage(kind: .pass, name: icon)
                .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 0) {
                Text(value >= AlbumStore.unlimited ? "∞" : value.formatted(.number.locale(Locale(identifier: "fr_FR"))))
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(Color.inkFixed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .fixedSize()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: fill, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(tint.opacity(0.25), lineWidth: 1.5))
        .shadow(color: tint.opacity(0.15), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }
}

/// Bouton d'achat pleine largeur, toujours sur une ligne : l'action à gauche, le prix (ou le reste) dans une pastille à droite.
struct ShopButton: View {
    let title: String
    let price: String?
    let icon: String
    let fill: Color
    let text: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            HStack(spacing: Space.s) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(0)
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    AlbumImage(kind: .pass, name: icon).frame(width: 24, height: 24)
                    if let price {
                        Text(price)
                            .font(.system(.subheadline, design: .rounded).weight(.black))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 6)
                .padding(.trailing, price == nil ? 6 : 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.25), in: Capsule())
                .fixedSize()
                .layoutPriority(1)
            }
            .foregroundStyle(text)
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(fill, in: Capsule())
            .shadow(color: fill.opacity(enabled ? 0.35 : 0), radius: 10, y: 5)
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(ShopPress())
        .disabled(!enabled)
    }
}

private struct ShopPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Coffret de catégorie : le joueur choisit un domaine et voit les 3 cartes (et ce qu'elles donneront) avant d'ouvrir.
struct CoffretPicker: View {
    let store: AlbumStore
    let coffret: AlbumOverview.Coffret
    var onOpen: (PackOpening) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var domain: String?

    private let catalog = AlbumCatalog.shared

    /// Domaines proposés, dans l'ordre de l'album.
    private var domains: [AlbumDomain] { catalog.domains.filter { coffret.offers[$0.id] != nil } }

    private func cards(_ domain: String) -> [AlbumCard] {
        (coffret.offers[domain] ?? []).compactMap { catalog.byServerId[$0] }
    }

    /// Ce que la carte donnera, d'après l'album actuel.
    private func outcome(_ card: AlbumCard) -> Pull.Outcome {
        guard let state = store.state(card) else { return .new }
        return state.shiny ? .nothing : .shiny
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    Text("Choisis un domaine : le coffret donne ses 3 cartes. Au plus une épique, jamais de légendaire.")
                        .font(.cfBody).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Space.s)], spacing: Space.s) {
                        ForEach(domains) { item in
                            Button {
                                Haptics.selection()
                                withAnimation(Motion.standard) { domain = item.id }
                            } label: {
                                Text(item.label)
                                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                    .foregroundStyle(domain == item.id ? DomainPalette.onColor(item.id) : Color.ink)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(domain == item.id ? DomainPalette.color(item.id) : Color.paperRaised,
                                                in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                                        .strokeBorder(DomainPalette.color(item.id).opacity(0.5), lineWidth: 1.5))
                            }
                            .buttonStyle(.row)
                        }
                    }
                    if let domain {
                        HStack(alignment: .top, spacing: Space.s) {
                            ForEach(cards(domain)) { card in
                                VStack(spacing: 6) {
                                    AlbumCardView(card: card, state: store.state(card))
                                        .aspectRatio(0.7, contentMode: .fit)
                                    OutcomeTag(outcome: outcome(card), compact: true)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        Button {
                            Task {
                                guard let pulls = await store.openCoffret(coffret, domain: domain) else { return }
                                let series = catalog.series.first { $0.id == domain } ?? catalog.series[0]
                                onOpen(PackOpening(series: series, pulls: pulls, coffret: true))
                            }
                        } label: {
                            Text("Ouvrir le coffret \(catalog.domains.first { $0.id == domain }?.label ?? "")")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ink)
                        .disabled(store.busy)
                    }
                    if let error = store.errorMessage {
                        Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.m)
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Coffret de catégorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Plus tard") { dismiss() } }
            }
        }
    }
}
