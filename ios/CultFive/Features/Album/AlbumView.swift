import SwiftUI

/// Une ouverture à montrer en plein écran (pochette, pochette dorée, coffret).
struct PackOpening: Identifiable {
    let id = UUID()
    let series: PackSeries
    let pulls: [Pull]
    var gold = false
    var coffret = false
}

/// Onglet Album (aperçu TestFlight) : le classeur. Couverture Brainlix, onglets de couleur par domaine,
/// feuillets de 9 pochettes qui tournent en 3D, cases vides à fabriquer. Collection simulée sur le téléphone.
struct AlbumView: View {
    @State private var store = AlbumStore()
    @State private var domain = AlbumCatalog.shared.domains.first?.id ?? "history"
    @State private var selected: AlbumCard?
    @State private var opening: PackOpening?
    @State private var confirmReset = false

    private let catalog = AlbumCatalog.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    AlbumCover(store: store, cover: store.cover)
                    shortcuts
                    DomainTabs(domain: $domain, store: store)
                    Binder(domain: domain, store: store) { selected = $0 }
                        .id(domain)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.s)
            }
            .clearsTabBar()
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NeuronesAmount(amount: store.neurones)
                }
                ToolbarItem(placement: .topBarTrailing) { testMenu }
            }
            .navigationDestination(for: AlbumRoute.self) { route in
                switch route {
                case .comptoir: ComptoirView(store: store) { opening = $0 }
                case .pass: SeasonPassView(store: store) { opening = $0 }
                }
            }
        }
        .environment(store)
        .sheet(item: $selected) { card in
            CardDetailView(card: card, store: store)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $opening) { open in
            PackOpeningView(opening: open, back: store.back) { opening = nil }
        }
        .confirmationDialog("Repartir de la collection de départ ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Réinitialiser", role: .destructive) { store.reset() }
        }
    }

    private var shortcuts: some View {
        HStack(spacing: Space.s) {
            NavigationLink(value: AlbumRoute.comptoir) {
                ShortcutTile(title: "Comptoir", detail: store.tickets > 0 ? "\(store.tickets) ticket\(store.tickets > 1 ? "s" : "")" : "Pochettes",
                             icon: "ticket_pochette", tint: Color(hex: 0xF0588F))
            }
            NavigationLink(value: AlbumRoute.pass) {
                ShortcutTile(title: "Pass de saison", detail: "Palier \(store.tier) / \(AlbumStore.tiers)",
                             icon: "final_gratuit", tint: .brand)
            }
        }
        .buttonStyle(.row)
    }

    private var testMenu: some View {
        Menu {
            Section("Aperçu TestFlight") {
                Button { store.unlockEverything() } label: { Label("Tout débloquer", systemImage: "sparkles") }
                Button { store.simulateMastery() } label: { Label("Simuler des chefs-d'œuvre", systemImage: "star.fill") }
                Button { store.addPoints(AlbumStore.tierPoints) } label: { Label("+1 palier de pass", systemImage: "arrow.up.circle") }
                Button(role: .destructive) { confirmReset = true } label: { Label("Réinitialiser", systemImage: "arrow.counterclockwise") }
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(Color.brand)
        }
        .accessibilityLabel("Outils de test de l'album")
    }
}

enum AlbumRoute: Hashable { case comptoir, pass }

private struct ShortcutTile: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: Space.s) {
            AlbumImage(kind: .pass, name: icon)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
                Text(detail).font(.cfFootnote).foregroundStyle(tint)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s)
        .frame(maxWidth: .infinity)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.07), radius: 12, y: 6)
    }
}

// MARK: - Couverture

/// Couverture du classeur : emblème Brainlix (trait de cinq entouré des 12 couleurs de domaine), compteur de cartes.
struct AlbumCover: View {
    let store: AlbumStore
    let cover: String

    private var fill: LinearGradient {
        switch cover {
        case "automne": return LinearGradient(colors: [Color(hex: 0xF08A3C), Color(hex: 0x8C3B12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "grimoire": return LinearGradient(colors: [Color(hex: 0x2F5D50), Color(hex: 0x13241F)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "or": return LinearGradient(colors: [Color(hex: 0xF6D98A), Color(hex: 0x9C6412)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        let total = AlbumCatalog.shared.cards.count
        let owned = store.totalOwned
        HStack(spacing: Space.m) {
            AlbumEmblem()
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text("BRAINLIX").font(.system(.caption, design: .rounded).weight(.black)).tracking(3).foregroundStyle(.white.opacity(0.8))
                Text("Mon album").font(.system(.title2, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                Text("\(owned) / \(total) cartes").font(.cfNumber).foregroundStyle(Color.sun)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(Color.sun).frame(width: proxy.size.width * CGFloat(owned) / CGFloat(max(total, 1)))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(Space.m)
        .padding(.leading, Space.s)
        .background(fill, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(alignment: .leading) {
            // Dos du classeur : la tranche et ses anneaux.
            VStack(spacing: 26) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(.white.opacity(0.85)).frame(width: 7, height: 16)
                }
            }
            .padding(.leading, 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1).padding(5)
        )
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.25), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }
}

/// Emblème rond de l'album : trait de cinq sur violet, entouré des couleurs des 12 domaines.
struct AlbumEmblem: View {
    private let domains = ["calc", "french", "geography", "history", "science", "logic", "arts", "sport", "cinema", "music", "tech", "nature"]

    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(domains.indices, id: \.self) { i in
                    let a = -Double.pi / 2 + Double(i) / 12 * 2 * .pi
                    Circle().fill(DomainPalette.color(domains[i]))
                        .frame(width: s * 0.075, height: s * 0.075)
                        .offset(x: CGFloat(cos(a)) * s * 0.45, y: CGFloat(sin(a)) * s * 0.45)
                }
                RoundedRectangle(cornerRadius: s * 0.18, style: .continuous)
                    .fill(Color.popGradient)
                    .overlay(RoundedRectangle(cornerRadius: s * 0.18, style: .continuous).stroke(.white, lineWidth: 2))
                    .frame(width: s * 0.63, height: s * 0.63)
                TallyMark(strokes: [.correct, .correct, .correct, .correct, .ready], onInk: true, lineWidth: s * 0.04)
                    .frame(width: s * 0.34)
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - Onglets de domaine

private struct DomainTabs: View {
    @Binding var domain: String
    let store: AlbumStore

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AlbumCatalog.shared.domains) { item in
                        let cards = AlbumCatalog.shared.pages(of: item.id).flatMap(\.cards)
                        let isOn = domain == item.id
                        Button {
                            Haptics.selection()
                            withAnimation(Motion.standard) { domain = item.id }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: DomainPalette.symbol(item.id))
                                Text(item.label)
                                Text("\(store.ownedCount(cards))/\(cards.count)").monospacedDigit().opacity(0.75)
                            }
                            .font(.system(.footnote, design: .rounded).weight(.heavy))
                            .foregroundStyle(isOn ? DomainPalette.onColor(item.id) : DomainPalette.color(item.id))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(isOn ? DomainPalette.color(item.id) : DomainPalette.color(item.id).opacity(0.12),
                                        in: UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
            .padding(.horizontal, -Space.gutter)
            .onAppear { reader.scrollTo(domain, anchor: .center) }
        }
    }
}

// MARK: - Classeur

/// Les feuillets d'un domaine, un à la fois, qu'on tourne en 3D (glisser ou flèches).
private struct Binder: View {
    let domain: String
    let store: AlbumStore
    var onSelect: (AlbumCard) -> Void

    private struct Sheet: Identifiable {
        let id: Int
        let page: AlbumPage
        let part: Int
        let parts: Int
        let cards: [AlbumCard]
    }

    @State private var index = 0
    @State private var forward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sheets: [Sheet] {
        var result: [Sheet] = []
        for page in AlbumCatalog.shared.pages(of: domain) {
            let parts = page.sheets
            for (i, cards) in parts.enumerated() {
                result.append(Sheet(id: result.count, page: page, part: i + 1, parts: parts.count, cards: cards))
            }
        }
        return result
    }

    var body: some View {
        let sheets = sheets
        VStack(spacing: Space.m) {
            ZStack {
                ForEach(sheets) { sheet in
                    if sheet.id == index {
                        sheetView(sheet)
                            .zIndex(-Double(sheet.id))
                            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.pageTurn(forward: forward))
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 24).onEnded { value in
                    if value.translation.width < -50 { turn(by: 1, count: sheets.count) }
                    if value.translation.width > 50 { turn(by: -1, count: sheets.count) }
                }
            )
            HStack {
                arrow("chevron.left", enabled: index > 0) { turn(by: -1, count: sheets.count) }
                Spacer()
                ProgressPills(current: index + 1, total: sheets.count, color: DomainPalette.color(domain))
                Spacer()
                arrow("chevron.right", enabled: index < sheets.count - 1) { turn(by: 1, count: sheets.count) }
            }
        }
    }

    private func turn(by step: Int, count: Int) {
        let next = index + step
        guard next >= 0, next < count else { return }
        forward = step > 0
        Haptics.soft()
        // Le sens est posé avant le changement de feuillet : chaque feuillet connaît déjà sa transition.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.6)) { index = next }
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.body, design: .rounded).weight(.heavy))
                .foregroundStyle(enabled ? Color.ink : Color.inkSoft.opacity(0.35))
                .frame(width: 44, height: 44)
                .background(Color.paperRaised, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "chevron.left" ? "Feuillet précédent" : "Feuillet suivant")
    }

    private func sheetView(_ sheet: Sheet) -> some View {
        let tone = DomainPalette.color(sheet.page.domain)
        return VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(sheet.page.title).font(.cfTitle3).foregroundStyle(Color.ink)
                if sheet.parts > 1 {
                    Text("\(sheet.part)/\(sheet.parts)").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer()
                Text("\(store.ownedCount(sheet.page.cards))/\(sheet.page.cards.count)")
                    .font(.cfNumber).foregroundStyle(tone)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                ForEach(sheet.cards) { card in
                    Button {
                        Haptics.selection()
                        onSelect(card)
                    } label: {
                        if store.isOwned(card) {
                            AlbumCardView(card: card, state: store.state(card), dressed: true)
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                        } else {
                            EmptySlot(card: card)
                        }
                    }
                    .buttonStyle(.plain)
                }
                // Pochettes vides en fin de feuillet.
                ForEach(0..<(9 - sheet.cards.count) % 9, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.ink.opacity(0.025))
                        .aspectRatio(albumCardRatio, contentMode: .fit)
                }
            }
        }
        .padding(Space.m)
        .padding(.leading, Space.s)
        .background {
            // Feuillet de classeur : plastique transparent, trous des anneaux à gauche.
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .fill(Color.paperRaised)
                .overlay(alignment: .leading) {
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { i in
                            if i > 0 { Spacer() }
                            Circle().fill(Color.paper).frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.hairline, lineWidth: 1))
                        }
                    }
                    .padding(.vertical, 60)
                    .padding(.leading, 6)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(tone.opacity(0.35), lineWidth: 1.5)
                )
                .shadow(color: Color(hex: 0x3A1FB8).opacity(0.1), radius: 12, y: 6)
        }
    }
}

// MARK: - Page qui tourne

private struct PageTurn: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
            .opacity(abs(angle) >= 90 ? 0 : 1)
    }
}

private struct PageShade: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content.overlay(Color.black.opacity(amount).allowsHitTesting(false)).compositingGroup()
    }
}

extension AnyTransition {
    /// Le feuillet tourne autour des anneaux (bord gauche). En avant, l'ancien se soulève et découvre le suivant ;
    /// en arrière, le précédent revient se poser par-dessus.
    static func pageTurn(forward: Bool) -> AnyTransition {
        let turned = AnyTransition.modifier(active: PageTurn(angle: -95), identity: PageTurn(angle: 0))
        let under = AnyTransition.modifier(active: PageShade(amount: 0.12), identity: PageShade(amount: 0))
        return forward ? .asymmetric(insertion: under, removal: turned) : .asymmetric(insertion: turned, removal: under)
    }
}
