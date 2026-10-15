import SwiftUI

/// Filtres de l'album : possédées, manquantes, brillantes, et une rareté. Actifs, ils remplacent le classeur
/// par une grille des cartes qui correspondent (du domaine choisi, ou de tout l'album).
struct AlbumFilter: Equatable {
    enum Show: String, CaseIterable {
        case all = "Toutes", owned = "Possédées", missing = "Manquantes", shiny = "Brillantes"
    }

    var show: Show = .all
    var rarity: CardRarity?
    var allDomains = false

    var isActive: Bool { show != .all || rarity != nil }

    @MainActor
    func matches(_ card: AlbumCard, store: AlbumStore) -> Bool {
        if let rarity, card.rarity != rarity { return false }
        switch show {
        case .all: return true
        case .owned: return store.isOwned(card)
        case .missing: return !store.isOwned(card)
        case .shiny: return store.state(card)?.shiny == true
        }
    }
}

/// Rangée de pastilles des filtres (défile de côté), avec « Effacer » quand un filtre est posé.
struct AlbumFilterBar: View {
    @Binding var filter: AlbumFilter
    let tone: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AlbumFilter.Show.allCases, id: \.self) { show in
                    chip(show.rawValue, on: filter.show == show, color: tone) {
                        filter.show = show
                    }
                }
                Rectangle().fill(Color.hairline).frame(width: 1, height: 22).padding(.horizontal, 2)
                ForEach(CardRarity.allCases, id: \.self) { rarity in
                    chip(rarity.label, on: filter.rarity == rarity, color: rarity.color, border: rarity.border) {
                        filter.rarity = filter.rarity == rarity ? nil : rarity
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 2)
        }
        .padding(.horizontal, -Space.gutter)
    }

    private func chip(_ title: String, on: Bool, color: Color, border: Color? = nil, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(Motion.standard) { action() }
        } label: {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(on ? Color.white : Color.ink)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(on ? color : Color.paperRaised, in: Capsule())
                .overlay(Capsule().strokeBorder(on ? Color.clear : (border ?? Color.hairline), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Grille des cartes filtrées : même rendu que le classeur, sans les feuillets.
struct FilteredCards: View {
    let filter: AlbumFilter
    let domain: String
    let store: AlbumStore
    var onSelect: (AlbumCard) -> Void

    var body: some View {
        let catalog = AlbumCatalog.shared
        let pool = filter.allDomains ? catalog.cards : catalog.pages(of: domain).flatMap(\.cards)
        let cards = pool.filter { filter.matches($0, store: store) }
        VStack(alignment: .leading, spacing: Space.m) {
            Text(summary(cards.count))
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ink)
            if cards.isEmpty {
                Text(empty)
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .multilineTextAlignment(.center)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                    ForEach(cards) { card in
                        Button {
                            Haptics.selection()
                            onSelect(card)
                        } label: {
                            Pocket {
                                if store.isOwned(card) {
                                    AlbumCardView(card: card, state: store.state(card), outlined: true)
                                } else {
                                    EmptySlot(card: card)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(Space.m)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
            .strokeBorder(filter.allDomains ? Color.hairline : DomainPalette.color(domain).opacity(0.5), lineWidth: 2))
    }

    private func summary(_ count: Int) -> String {
        let what = [filter.show == .all ? nil : filter.show.rawValue.lowercased(), filter.rarity.map { $0.label.lowercased() }]
            .compactMap { $0 }.joined(separator: ", ")
        let scope = filter.allDomains ? "dans tout l'album" : "dans ce domaine"
        return "\(count) carte\(count > 1 ? "s" : "") \(what.isEmpty ? "" : "(\(what)) ")\(scope)"
    }

    private var empty: String {
        switch filter.show {
        case .missing: return "Aucune carte qui manque ici. Bravo !"
        case .shiny: return "Pas encore de carte brillante ici. Un doublon rend la carte brillante."
        default: return "Aucune carte ici pour l'instant."
        }
    }
}

/// Onglets des pages d'un domaine, au-dessus du feuillet : la page en cours est soulignée.
struct PageTabs: View {
    let pages: [AlbumPage]
    let current: String
    let tone: Color
    let store: AlbumStore
    var onSelect: (AlbumPage) -> Void

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(pages) { page in
                        let on = page.key == current
                        Button {
                            guard !on else { return }
                            Haptics.selection()
                            onSelect(page)
                        } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(page.title)
                                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                                        .lineLimit(1)
                                        .fixedSize()
                                    Text("\(store.ownedCount(page.cards))/\(page.cards.count)")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .monospacedDigit()
                                        .opacity(0.7)
                                }
                                .foregroundStyle(on ? tone : Color.inkSoft)
                                Capsule()
                                    .fill(on ? tone : Color.clear)
                                    .frame(height: 3)
                            }
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                        }
                        .buttonStyle(.plain)
                        .id(page.key)
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityLabel("\(page.title), \(store.ownedCount(page.cards)) cartes sur \(page.cards.count)")
                    }
                }
            }
            .onAppear { reader.scrollTo(current, anchor: .center) }
            .onChange(of: current) { _, value in
                withAnimation(Motion.standard) { reader.scrollTo(value, anchor: .center) }
            }
        }
    }
}

/// Légende de l'album : ce que veulent dire les cases, les couleurs et les états des cartes.
struct AlbumLegendSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var sample: AlbumCard? {
        AlbumCatalog.shared.cards.first { $0.rarity == .rare } ?? AlbumCatalog.shared.cards.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    section("Les cases") {
                        if let card = sample {
                            row(text: "Carte qui te manque : grisée, avec son numéro. Touche-la pour la fabriquer avec tes neurones (le prix est en bas).") {
                                EmptySlot(card: card)
                            }
                            row(text: "Carte que tu as : en couleur. Touche-la pour la voir en grand et l'habiller.") {
                                AlbumCardView(card: card, state: OwnedCard(), outlined: true)
                            }
                        }
                    }
                    section("La couleur du contour : la rareté") {
                        ForEach(CardRarity.allCases, id: \.self) { rarity in
                            HStack(spacing: Space.s) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(rarity.border, lineWidth: 3)
                                    .frame(width: 22, height: 30)
                                Text(rarity.label).font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
                                Spacer(minLength: Space.s)
                                Text(chance(rarity)).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            }
                        }
                    }
                    section("Les états d'une carte") {
                        if let card = sample {
                            row(text: "Brillante : un reflet irisé quand tu bouges la carte. Tu l'obtiens au premier doublon.") {
                                AlbumCardView(card: card, state: OwnedCard(shiny: true), outlined: true)
                            }
                            row(text: "Prestige : le dessin prend toute la carte. Il faut un jeton Prestige (pass, coffres Savant).") {
                                AlbumCardView(card: card, state: OwnedCard(prestige: true), outlined: true)
                            }
                            row(text: "Chef-d'œuvre : triple cadre doré. Il s'obtient en maîtrisant la carte au quiz (3 étoiles).") {
                                AlbumCardView(card: card, state: OwnedCard(masterpiece: true), outlined: true)
                            }
                        }
                        Text("Une carte peut avoir plusieurs états à la fois. Tu choisis ceux que tu affiches dans sa fiche.")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    section("Avoir des cartes") {
                        Text("Pochettes au Comptoir (neurones ou tickets, 5 tickets au plus), coffres, pass de saison, ou fabrication case par case.")
                            .font(.cfBody).foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.m)
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Comprendre l'album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func chance(_ rarity: CardRarity) -> String {
        switch rarity {
        case .common: return "70 % des cartes"
        case .rare: return "22 %"
        case .epic: return "6,5 %"
        case .legend: return "1,5 %"
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(title).font(.cfHeadline).foregroundStyle(Color.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard()
    }

    private func row<Card: View>(text: String, @ViewBuilder card: () -> Card) -> some View {
        HStack(alignment: .center, spacing: Space.m) {
            card().frame(width: 64)
            Text(text)
                .font(.cfCallout).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
