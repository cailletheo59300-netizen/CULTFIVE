import SwiftUI

/// Une ouverture à montrer en plein écran (pochette, pochette dorée, coffret).
struct PackOpening: Identifiable {
    let id = UUID()
    let series: PackSeries
    let pulls: [Pull]
    var gold = false
    var coffret = false
}

/// Onglet Album : le classeur. Couverture Brainlix, intercalaires de couleur par domaine,
/// feuillets de 9 pochettes qui tournent en 3D, cases vides à fabriquer. La collection vient du serveur.
struct AlbumView: View {
    @Environment(AppModel.self) private var app
    @State private var store = AlbumStore.shared
    @State private var path: [AlbumRoute] = []
    @State private var domain = AlbumCatalog.shared.domains.first?.id ?? "history"
    @State private var selected: AlbumCard?
    @State private var opening: PackOpening?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    AlbumCover(store: store)
                    shortcuts
                    VStack(spacing: Space.s) {
                        VStack(spacing: 0) {
                            DomainDividers(domain: $domain, store: store)
                            Binder(domain: domain, store: store) { selected = $0 }
                                .id(domain)
                        }
                        RarityLegend()
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.s)
            }
            .refreshable { await store.refresh() }
            .clearsTabBar()
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NeuronesAmount(amount: store.neurones, size: 24)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if store.canAdmin { adminMenu }
                }
            }
            .navigationDestination(for: AlbumRoute.self) { route in
                switch route {
                case .comptoir: ComptoirView(store: store) { opening = $0 }
                case .pass: SeasonPassView(store: store) { opening = $0 }
                }
            }
        }
        .environment(store)
        .task { await store.refresh() }
        .alert("Album", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: app.pendingPass, initial: true) { _, go in
            // Lien « Pass » de la carte Défis (écran du 5) : on ouvre directement le pass.
            guard go else { return }
            app.pendingPass = false
            path = [.pass]
        }
        // Fiche de carte en plein écran : on la ferme avec la croix, pas en glissant.
        .fullScreenCover(item: $selected) { card in
            CardDetailView(card: card, store: store)
        }
        .fullScreenCover(item: $opening) { open in
            PackOpeningView(opening: open, back: store.back) { opening = nil }
        }
    }

    private var shortcuts: some View {
        HStack(spacing: Space.s) {
            NavigationLink(value: AlbumRoute.comptoir) {
                ShortcutTile(title: "Comptoir", detail: store.admin ? "∞ tickets" : store.tickets > 0 ? "\(store.tickets) ticket\(store.tickets > 1 ? "s" : "")" : "Pochettes",
                             icon: "ticket_pochette", tint: Color(hex: 0xF0588F))
            }
            NavigationLink(value: AlbumRoute.pass) {
                ShortcutTile(title: "Pass", detail: "Palier \(store.tier)/\(store.tiers)",
                             icon: "final_gratuit", tint: .brand)
            }
        }
        .buttonStyle(.row)
    }

    /// Menu admin, réservé aux administrateurs (vérifié par le serveur) : un interrupteur, et les outils quand il est activé.
    /// Désactivé, l'album redevient celui d'un joueur normal (sa propre collection).
    private var adminMenu: some View {
        Menu {
            Toggle(isOn: Binding(get: { store.admin }, set: { on in Task { await store.setAdmin(on) } })) {
                Label("Mode admin", systemImage: "crown.fill")
            }
            if store.admin {
                Section("Cartes") {
                    Button { Task { await store.ownAll(shiny: false) } } label: { Label("Toutes les cartes", systemImage: "square.grid.3x3.fill") }
                    Button { Task { await store.ownAll(shiny: true) } } label: { Label("Toutes en brillantes", systemImage: "sparkles") }
                    Button(role: .destructive) { Task { await store.emptyAlbum() } } label: { Label("Vider l'album", systemImage: "trash") }
                }
                Section("Prochaine pochette") {
                    ForEach([CardRarity.legend, .epic, .rare], id: \.self) { rarity in
                        Button {
                            Task { await store.force(rarity) }
                        } label: {
                            if store.forcedRarity == rarity {
                                Label("Avec une \(rarity.label.lowercased())", systemImage: "checkmark")
                            } else {
                                Text("Avec une \(rarity.label.lowercased())")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.admin ? "crown.fill" : "wand.and.stars")
                if store.admin { Text("ADMIN").font(.system(size: 11, weight: .black, design: .rounded)) }
            }
            .font(.system(.body, design: .rounded).weight(.bold))
            .foregroundStyle(store.admin ? Color.inkFixed : Color.brand)
            .padding(.horizontal, store.admin ? 8 : 0)
            .padding(.vertical, store.admin ? 4 : 0)
            .background(store.admin ? Color.sun : Color.clear, in: Capsule())
        }
        .accessibilityLabel(store.admin ? "Menu admin, mode admin activé" : "Menu admin")
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
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ink)
                Text(detail)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(tint)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.inkSoft.opacity(0.6))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(tint.opacity(0.18), lineWidth: 1.5))
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.07), radius: 12, y: 6)
    }
}

// MARK: - Couverture

/// Couverture du classeur : dos à anneaux, emblème Brainlix, compteur et décompte par rareté.
struct AlbumCover: View {
    let store: AlbumStore

    private var colors: [Color] {
        switch store.cover {
        case "automne": return [Color(hex: 0xF08A3C), Color(hex: 0x8C3B12)]
        case "grimoire": return [Color(hex: 0x2F5D50), Color(hex: 0x13241F)]
        case "or": return [Color(hex: 0xE9C25E), Color(hex: 0x8A5A10)]
        default: return [Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8)]
        }
    }

    var body: some View {
        let cards = AlbumCatalog.shared.cards
        let owned = store.totalOwned
        let progress = CGFloat(owned) / CGFloat(max(cards.count, 1))
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                AlbumEmblem()
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text("BRAINLIX · SAISON 1")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.75))
                    Text("Mon album")
                        .font(.system(.title, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(owned)").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(Color.sun)
                        Text("/ \(cards.count) cartes").font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.85))
                    }
                    .monospacedDigit()
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.22))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: 0xFFE680), Color.sun], startPoint: .top, endPoint: .bottom))
                        .frame(width: max(10, proxy.size.width * progress))
                }
            }
            .frame(height: 10)
            HStack(spacing: 6) {
                ForEach(CardRarity.allCases, id: \.self) { rarity in
                    let pool = cards.filter { $0.rarity == rarity }
                    RarityCount(rarity: rarity, owned: store.ownedCount(pool), total: pool.count)
                }
            }
        }
        .padding(Space.m)
        .padding(.leading, 22)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                CoverPattern()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                // Reflet du plastique de la couverture.
                LinearGradient(colors: [.white.opacity(0.22), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                // Le dos du classeur et ses anneaux.
                LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 22)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.l, bottomLeadingRadius: Radius.l))
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { i in
                        if i > 0 { Spacer() }
                        MetalRing()
                    }
                }
                .padding(.vertical, 26)
                .padding(.leading, 6)
                RoundedRectangle(cornerRadius: Radius.l - 6, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .padding(.vertical, 7)
                    .padding(.trailing, 7)
                    .padding(.leading, 28)
            }
        }
        .shadow(color: colors[1].opacity(0.35), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
    }
}

/// Décompte d'une rareté sur la couverture.
private struct RarityCount: View {
    let rarity: CardRarity
    let owned: Int
    let total: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(owned)/\(total)")
                .font(.system(.footnote, design: .rounded).weight(.black))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(rarity.label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(rarity.border, lineWidth: 2))
    }
}

/// Motif discret de la couverture : des traits de cinq.
private struct CoverPattern: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 34
            var row = 0
            var y: CGFloat = 10
            while y < size.height {
                var x: CGFloat = row % 2 == 0 ? 8 : 25
                while x < size.width {
                    var path = Path()
                    for i in 0..<4 {
                        let xx = x + CGFloat(i) * 3.2
                        path.move(to: CGPoint(x: xx, y: y))
                        path.addLine(to: CGPoint(x: xx, y: y + 11))
                    }
                    path.move(to: CGPoint(x: x - 2, y: y + 9))
                    path.addLine(to: CGPoint(x: x + 12, y: y + 2))
                    context.stroke(path, with: .color(.white.opacity(0.07)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    x += step
                }
                y += step * 0.8
                row += 1
            }
        }
        .allowsHitTesting(false)
    }
}

/// Anneau métallique du classeur.
private struct MetalRing: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(hex: 0xF4F3FA), Color(hex: 0x9A97AE), Color(hex: 0xE4E2EE)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 12, height: 22)
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
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

// MARK: - Intercalaires de domaine

/// Les intercalaires du classeur : un onglet de couleur par domaine, qui dépasse ; l'actif est plus haut et relié au feuillet.
private struct DomainDividers: View {
    @Binding var domain: String
    let store: AlbumStore

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(AlbumCatalog.shared.domains) { item in
                        divider(item)
                            .id(item.id)
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
            .padding(.horizontal, -Space.gutter)
            .onAppear { reader.scrollTo(domain, anchor: .center) }
            .onChange(of: domain) { _, value in
                withAnimation(Motion.standard) { reader.scrollTo(value, anchor: .center) }
            }
        }
    }

    private func divider(_ item: AlbumDomain) -> some View {
        let cards = AlbumCatalog.shared.pages(of: item.id).flatMap(\.cards)
        let owned = store.ownedCount(cards)
        let isOn = domain == item.id
        let color = DomainPalette.color(item.id)
        let text = isOn ? DomainPalette.onColor(item.id) : color
        let progress = CGFloat(owned) / CGFloat(max(cards.count, 1))
        return Button {
            guard !isOn else { return }
            Haptics.selection()
            withAnimation(Motion.standard) { domain = item.id }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: DomainPalette.symbol(item.id))
                        .font(.system(size: 13, weight: .bold))
                    Text(item.label)
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .lineLimit(1)
                        .fixedSize()
                }
                HStack(spacing: 5) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(text.opacity(0.22))
                        Capsule().fill(text).frame(width: 46 * progress)
                    }
                    .frame(width: 46, height: 4)
                    Text("\(owned)/\(cards.count)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .foregroundStyle(text)
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, isOn ? 14 : 9)
            .background(isOn ? color : color.opacity(0.13),
                        in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
            .overlay(alignment: .top) {
                if isOn {
                    // Liseré clair du bord de l'intercalaire.
                    UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.label), \(owned) cartes sur \(cards.count)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Classeur

/// Les feuillets d'un domaine, un à la fois, qu'on tourne en 3D (glisser, flèches ou sommaire).
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

    private var tone: Color { DomainPalette.color(domain) }

    var body: some View {
        let sheets = sheets
        VStack(spacing: 0) {
            ZStack {
                ForEach(sheets) { sheet in
                    if sheet.id == index {
                        sheetView(sheet, sheets: sheets)
                            .zIndex(-Double(sheet.id))
                            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.pageTurn(forward: forward))
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 24).onEnded { value in
                    if value.translation.width < -50 { turn(to: index + 1, count: sheets.count) }
                    if value.translation.width > 50 { turn(to: index - 1, count: sheets.count) }
                }
            )
            footer(count: sheets.count)
                .padding(.top, Space.m)
        }
    }

    private func turn(to next: Int, count: Int) {
        guard next >= 0, next < count, next != index else { return }
        forward = next > index
        Haptics.soft()
        // Le sens est posé avant le changement de feuillet : chaque feuillet connaît déjà sa transition.
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.6)) { index = next }
        }
    }

    private func footer(count: Int) -> some View {
        HStack(spacing: Space.s) {
            arrow("chevron.left", enabled: index > 0) { turn(to: index - 1, count: count) }
            Spacer(minLength: 0)
            Text("Feuillet \(index + 1) sur \(count)")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(Color.inkSoft)
                .lineLimit(1)
            Spacer(minLength: 0)
            arrow("chevron.right", enabled: index < count - 1) { turn(to: index + 1, count: count) }
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.body, design: .rounded).weight(.heavy))
                .foregroundStyle(enabled ? Color.white : Color.inkSoft.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(enabled ? tone : Color.hairline, in: Circle())
                .shadow(color: enabled ? tone.opacity(0.35) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "chevron.left" ? "Feuillet précédent" : "Feuillet suivant")
    }

    /// Sommaire du domaine : saute à la première page choisie.
    private func contents(_ sheets: [Sheet], current: Sheet) -> some View {
        Menu {
            ForEach(sheets.filter { $0.part == 1 }) { sheet in
                Button {
                    turn(to: sheet.id, count: sheets.count)
                } label: {
                    Text("\(sheet.page.title) · \(store.ownedCount(sheet.page.cards))/\(sheet.page.cards.count)")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                Text("Pages")
            }
            .font(.system(.caption, design: .rounded).weight(.heavy))
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tone.opacity(0.12), in: Capsule())
        }
        .accessibilityLabel("Sommaire des pages")
    }

    private func header(_ sheet: Sheet, sheets: [Sheet]) -> some View {
        let owned = store.ownedCount(sheet.page.cards)
        let total = sheet.page.cards.count
        return HStack(spacing: Space.s) {
            ZStack {
                Circle().stroke(tone.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(owned) / CGFloat(max(total, 1)))
                    .stroke(tone, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: DomainPalette.symbol(sheet.page.domain))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tone)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(sheet.page.title)
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(sheet.parts > 1 ? "\(owned)/\(total) cartes · partie \(sheet.part)/\(sheet.parts)" : "\(owned)/\(total) cartes")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            contents(sheets, current: sheet)
        }
    }

    private func sheetView(_ sheet: Sheet, sheets: [Sheet]) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            header(sheet, sheets: sheets)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                ForEach(sheet.cards) { card in
                    Button {
                        Haptics.selection()
                        onSelect(card)
                    } label: {
                        Pocket {
                            if store.isOwned(card) {
                                AlbumCardView(card: card, state: store.state(card), outlined: true)
                                    .shadow(color: card.rarity.color.opacity(card.rarity >= .epic ? 0.35 : 0.12), radius: 4, y: 2)
                            } else {
                                EmptySlot(card: card)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                // Pochettes vides en fin de feuillet.
                ForEach(0..<(9 - sheet.cards.count) % 9, id: \.self) { _ in
                    Pocket { Color.clear.aspectRatio(albumCardRatio, contentMode: .fit) }
                }
            }
        }
        .padding(Space.m)
        .padding(.leading, 14)
        .background {
            ZStack(alignment: .leading) {
                UnevenRoundedRectangle(bottomLeadingRadius: Radius.m, bottomTrailingRadius: Radius.m, topTrailingRadius: Radius.m)
                    .fill(Color.paperRaised)
                // Reflet du plastique sur tout le feuillet.
                LinearGradient(stops: [.init(color: .white.opacity(0), location: 0.3), .init(color: .white.opacity(0.35), location: 0.42),
                                       .init(color: .white.opacity(0), location: 0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .allowsHitTesting(false)
                // Bande perforée et anneaux.
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { i in
                        if i > 0 { Spacer() }
                        MetalRing()
                    }
                }
                .padding(.vertical, 54)
                .padding(.leading, 3)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: Radius.m, bottomTrailingRadius: Radius.m, topTrailingRadius: Radius.m))
            .overlay(
                UnevenRoundedRectangle(bottomLeadingRadius: Radius.m, bottomTrailingRadius: Radius.m, topTrailingRadius: Radius.m)
                    .stroke(tone, lineWidth: 3)
            )
            .shadow(color: tone.opacity(0.18), radius: 14, y: 8)
        }
    }
}

/// Une pochette plastique du feuillet : léger creux et reflet.
private struct Pocket<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.ink.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [Color.black.opacity(0.1), Color.white.opacity(0.6)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    )
            )
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
