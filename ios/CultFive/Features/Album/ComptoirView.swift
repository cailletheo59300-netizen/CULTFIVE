import SwiftUI

/// Le Comptoir de Léon (aperçu TestFlight) : pochettes par thème payées en neurones ou en tickets, la pochette dorée,
/// l'offre du jour et les coffrets de catégorie du Pass+ (cartes connues avant de choisir). Aucun argent réel ici.
struct ComptoirView: View {
    let store: AlbumStore
    var onOpen: (PackOpening) -> Void

    @State private var selected = "encyclo"
    @State private var coffretSeries = "history"

    private let catalog = AlbumCatalog.shared
    private var series: PackSeries { catalog.series.first { $0.id == selected } ?? catalog.series[0] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                LeonSays(text: "Bienvenue au Comptoir ! Les pochettes se paient en neurones, et tes tickets marchent aussi.", pose: .wave, size: 80)
                balances
                packs
                gold
                if let offer = dailyOffer { offerCard(offer) }
                coffrets
                Text("Chances pour chaque carte : commune 70 %, rare 22 %, épique 6,5 %, légendaire 1,5 %. Au moins une rare par pochette.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.m)
        }
        .clearsTabBar()
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Comptoir de Léon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var balances: some View {
        HStack(spacing: Space.m) {
            NeuronesAmount(amount: store.neurones)
            Label("\(store.tickets) ticket\(store.tickets > 1 ? "s" : "")", systemImage: "ticket.fill")
                .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
            if store.goldPacks > 0 {
                Label("\(store.goldPacks) dorée", systemImage: "star.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color(hex: 0xB8862A))
            }
        }
        .popCard(padding: 12)
    }

    // MARK: - Pochettes par thème

    private var packs: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Pochettes · 5 cartes").font(.cfHeadline).foregroundStyle(Color.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(catalog.series) { item in
                        Button {
                            Haptics.selection()
                            withAnimation(Motion.standard) { selected = item.id }
                        } label: {
                            VStack(spacing: 6) {
                                AlbumImage(kind: .packs, name: item.id)
                                    .frame(width: 96, height: 144)
                                    .scaleEffect(selected == item.id ? 1.06 : 0.94)
                                    .shadow(color: item.tone.opacity(selected == item.id ? 0.5 : 0.15), radius: 10, y: 6)
                                Text(item.label).font(.system(.caption, design: .rounded).weight(.heavy))
                                    .foregroundStyle(selected == item.id ? Color.ink : Color.inkSoft)
                                Text("\(store.ownedCount(item.cards))/\(item.cards.count)")
                                    .font(.system(.caption2, design: .rounded).weight(.bold)).monospacedDigit()
                                    .foregroundStyle(Color.inkSoft)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Série \(item.label)")
                        .accessibilityAddTraits(selected == item.id ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
            .padding(.horizontal, -Space.gutter)
            VStack(alignment: .leading, spacing: Space.s) {
                Text(series.id == "encyclo" ? "Tous les thèmes mélangés : idéal pour remplir l'album au hasard."
                                            : "Seulement des cartes \(series.label) : \(series.cards.count) cartes, tu en as \(store.ownedCount(series.cards)).")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                HStack(spacing: Space.s) {
                    Button {
                        if let pulls = store.buyPack(series, useTicket: false) { onOpen(PackOpening(series: series, pulls: pulls)) }
                    } label: {
                        HStack(spacing: 4) { Text("Ouvrir"); Image(systemName: "brain.fill"); Text("\(AlbumStore.packPrice)") }
                    }
                    .buttonStyle(.ink)
                    .disabled(store.neurones < AlbumStore.packPrice)
                    Button {
                        if let pulls = store.buyPack(series, useTicket: true) { onOpen(PackOpening(series: series, pulls: pulls)) }
                    } label: {
                        HStack(spacing: 4) { Image(systemName: "ticket.fill"); Text("Ticket") }
                    }
                    .buttonStyle(.sun)
                    .disabled(store.tickets == 0)
                }
            }
            .popCard()
        }
    }

    // MARK: - Pochette dorée

    private var gold: some View {
        let legends = catalog.cards.filter { $0.rarity == .legend }.count
        return HStack(spacing: Space.m) {
            AlbumImage(kind: .packs, name: "gold")
                .frame(width: 84, height: 126)
                .shadow(color: Color(hex: 0xB8862A).opacity(0.4), radius: 10, y: 6)
            VStack(alignment: .leading, spacing: 6) {
                Text("Pochette dorée").font(.cfTitle3).foregroundStyle(Color.ink)
                Text("Une légendaire garantie, tirée parmi les \(legends) de l'album. Une par semaine.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                if store.goldPacks > 0 {
                    Button("Ouvrir celle du pass") {
                        if let pulls = store.openOwnedGoldPack() { onOpen(PackOpening(series: catalog.series[0], pulls: pulls, gold: true)) }
                    }
                    .buttonStyle(.sun)
                } else {
                    Button {
                        if let pulls = store.buyGoldPack() { onOpen(PackOpening(series: catalog.series[0], pulls: pulls, gold: true)) }
                    } label: {
                        HStack(spacing: 4) {
                            Text(store.goldBought ? "De retour lundi" : "Ouvrir")
                            if !store.goldBought { Image(systemName: "brain.fill"); Text("\(AlbumStore.goldPackPrice)") }
                        }
                    }
                    .buttonStyle(.sun)
                    .disabled(store.goldBought || store.neurones < AlbumStore.goldPackPrice)
                }
            }
        }
        .popCard()
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
        HStack(spacing: Space.m) {
            AlbumCardView(card: card, state: nil)
                .frame(width: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text("Offre du jour").labelCaps(Color(hex: 0xF0588F))
                Text(card.name).font(.cfTitle3).foregroundStyle(Color.ink)
                Text("Une carte qui te manque, connue à l'avance. \(card.rarity.label).")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                Button {
                    if store.craft(card) { Haptics.success() }
                } label: {
                    HStack(spacing: 4) { Text("Prendre"); Image(systemName: "brain.fill"); Text("\(card.rarity.craftCost)") }
                }
                .buttonStyle(.ink)
                .disabled(store.neurones < card.rarity.craftCost)
            }
        }
        .popCard()
    }

    // MARK: - Coffrets de catégorie (Pass+)

    private var coffrets: some View {
        let theme = catalog.series.first { $0.id == coffretSeries } ?? catalog.series[1]
        let cards = store.coffretCards(theme)
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Coffrets de catégorie").font(.cfHeadline).foregroundStyle(Color.ink)
                Spacer()
                Text("\(store.coffrets) à choisir").font(.cfNumber).foregroundStyle(Color.brand)
            }
            Text("Gagnés dans le Pass+. Tu choisis un thème et tu vois les 3 cartes avant de le prendre : pas de hasard.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            Picker("Thème", selection: $coffretSeries) {
                ForEach(catalog.series.dropFirst()) { Text($0.label).tag($0.id) }
            }
            .pickerStyle(.menu)
            .tint(Color.brand)
            HStack(alignment: .top, spacing: Space.s) {
                ForEach(cards) { card in
                    VStack(spacing: 4) {
                        AlbumCardView(card: card, state: nil)
                        OutcomeTag(outcome: store.coffretOutcome(card), compact: true)
                    }
                }
            }
            Button("Prendre ce coffret") {
                let pulls = store.openCoffret(theme)
                if !pulls.isEmpty { onOpen(PackOpening(series: theme, pulls: pulls, coffret: true)) }
            }
            .buttonStyle(.ink)
            .disabled(store.coffrets == 0)
        }
        .popCard()
    }
}
