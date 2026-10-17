import SwiftUI
import CultFiveCore

// Vitrine du profil (D-067) : jusqu'à 3 cartes posées sur un socle gagné dans le pass. Les amis la voient sur le profil.

/// Socles du pass, dans l'ordre du choix. `nil` : présentoir simple (pour tous).
enum SocleStyle: String, CaseIterable, Identifiable {
    case marbre, or, neon, glace

    var id: String { rawValue }

    var name: String {
        switch self {
        case .marbre: return "Marbre"
        case .or: return "Or"
        case .neon: return "Néon"
        case .glace: return "Glace"
        }
    }

    /// Où le gagner, pour un socle pas encore possédé.
    var origin: String {
        switch self {
        case .marbre: return "Pass, palier 15"
        case .or: return "Pass+, palier 11"
        case .neon: return "Pass+, palier 19"
        case .glace: return "Pass d'hiver"
        }
    }

    var icon: String { "socle_\(rawValue)" }
}

/// Couleurs d'un socle dessiné : dessus, flanc, liseré.
private struct SoclePalette {
    let top: [Color]
    let side: [Color]
    let rim: Color
    var glow: Color?

    init(_ socle: SocleStyle?) {
        switch socle {
        case .marbre:
            top = [Color(hex: 0xFFFFFF), Color(hex: 0xE4E3EA)]
            side = [Color(hex: 0xE2E1E8), Color(hex: 0xB9B7C4)]
            rim = .white
        case .or:
            top = [Color(hex: 0xFFE68A), Color(hex: 0xE8B53A)]
            side = [Color(hex: 0xE0A72C), Color(hex: 0x9E6B0C)]
            rim = Color(hex: 0xFFF3C4)
        case .neon:
            top = [Color(hex: 0x3A3170), Color(hex: 0x1C1838)]
            side = [Color(hex: 0x241E48), Color(hex: 0x100D22)]
            rim = Color(hex: 0xB49BFF)
            glow = Color(hex: 0x8B6BFF)
        case .glace:
            top = [Color(hex: 0xF4FCFF), Color(hex: 0xC9EBFA)]
            side = [Color(hex: 0xBFE6F7), Color(hex: 0x7FC3E3)]
            rim = .white
        case nil:
            top = [Color(hex: 0xEDEBF5), Color(hex: 0xD9D6E6)]
            side = [Color(hex: 0xCFCBDD), Color(hex: 0xA9A5BC)]
            rim = Color.white.opacity(0.7)
        }
    }
}

/// Le socle dessiné : un disque large vu de trois quarts (dessus clair, flanc plus sombre, liseré).
struct SocleBase: View {
    let socle: SocleStyle?

    var body: some View {
        let palette = SoclePalette(socle)
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let topH = h * 0.62
            ZStack(alignment: .top) {
                // Flanc : la moitié basse d'une ellipse décalée, sous le dessus.
                Ellipse()
                    .fill(LinearGradient(colors: palette.side, startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: topH)
                    .offset(y: h - topH)
                Rectangle()
                    .fill(LinearGradient(colors: palette.side, startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h - topH)
                    .offset(y: topH / 2)
                Ellipse()
                    .fill(LinearGradient(colors: palette.top, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: w, height: topH)
                Ellipse()
                    .strokeBorder(palette.rim, lineWidth: max(1.5, w * 0.006))
                    .frame(width: w, height: topH)
                // Reflet sur le dessus.
                Ellipse()
                    .fill(Color.white.opacity(socle == .neon ? 0.08 : 0.35))
                    .frame(width: w * 0.55, height: topH * 0.3)
                    .offset(x: -w * 0.12, y: topH * 0.14)
                    .blur(radius: 4)
            }
            .shadow(color: palette.glow?.opacity(0.75) ?? .black.opacity(0.18), radius: palette.glow == nil ? 10 : 16, y: 6)
        }
        .accessibilityHidden(true)
    }
}

/// Vitrine : les cartes debout sur le socle, la première au centre et plus grande.
/// `onSlot` (modification) : chaque emplacement devient touchable, les vides montrent un « + ».
struct ShowcaseStage: View {
    let socle: SocleStyle?
    /// Trois emplacements : centre, gauche, droite.
    let slots: [ShowcaseSlot?]
    var onSlot: ((Int) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let center = w * 0.3
            let side = w * 0.24
            ZStack(alignment: .bottom) {
                SocleBase(socle: socle)
                    .frame(width: w * 0.94, height: w * 0.17)
                HStack(alignment: .bottom, spacing: w * 0.035) {
                    slot(1, width: side).rotationEffect(.degrees(-4), anchor: .bottom)
                    slot(0, width: center)
                    slot(2, width: side).rotationEffect(.degrees(4), anchor: .bottom)
                }
                .padding(.bottom, w * 0.085)
            }
            .frame(width: w, height: proxy.size.height, alignment: .bottom)
        }
        .aspectRatio(1.55, contentMode: .fit)
    }

    @ViewBuilder
    private func slot(_ index: Int, width: CGFloat) -> some View {
        let content = slots.indices.contains(index) ? slots[index] : nil
        Group {
            if let content {
                AlbumCardView(card: content.card, state: content.state)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
            } else if onSlot != nil {
                RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
                    .strokeBorder(Color.inkSoft.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .background(Color.paperRaised.opacity(0.6), in: RoundedRectangle(cornerRadius: width * 0.06, style: .continuous))
                    .overlay(Image(systemName: "plus").font(.system(size: width * 0.2, weight: .bold)).foregroundStyle(Color.inkSoft))
                    .aspectRatio(albumCardRatio, contentMode: .fit)
                    .accessibilityLabel("Emplacement vide")
            } else {
                Color.clear.aspectRatio(albumCardRatio, contentMode: .fit)
            }
        }
        .frame(width: width)
        .contentShape(Rectangle())
        .onTapGesture { onSlot?(index) }
        .accessibilityAddTraits(onSlot != nil ? .isButton : [])
    }
}

/// Une carte exposée, prête à dessiner.
struct ShowcaseSlot {
    let card: AlbumCard
    let state: OwnedCard

    /// Depuis le serveur (vitrine d'un ami ou la sienne). nil si la carte manque au catalogue de l'app.
    init?(_ item: Showcase.Card) {
        guard let card = AlbumCatalog.shared.byServerId[item.card] else { return nil }
        self.card = card
        state = OwnedCard(shiny: item.shiny, prestige: item.prestige, masterpiece: item.masterpiece,
                          frame: item.frame, finish: item.finish, title: item.title)
    }

    init(card: AlbumCard, state: OwnedCard) {
        self.card = card
        self.state = state.shown
    }

    static func slots(of showcase: Showcase) -> [ShowcaseSlot?] {
        var slots = showcase.cards.prefix(3).map { ShowcaseSlot($0) }
        while slots.count < 3 { slots.append(nil) }
        return slots
    }
}

extension Showcase {
    var socleStyle: SocleStyle? { socle.flatMap(SocleStyle.init(rawValue:)) }
    var isEmpty: Bool { cards.isEmpty }
}

/// Bloc « Ma vitrine » du profil : la vitrine, ou une invitation à la remplir.
struct ProfileShowcaseBlock: View {
    let showcase: Showcase
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(spacing: Space.s) {
                ShowcaseStage(socle: showcase.socleStyle, slots: ShowcaseSlot.slots(of: showcase))
                if showcase.isEmpty {
                    Text("Expose tes 3 plus belles cartes : tes amis les verront sur ton profil.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                }
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.row)
        .accessibilityLabel("Ma vitrine")
        .accessibilityHint("Choisir les cartes et le socle")
    }
}

/// Modifier sa vitrine : le socle, puis les cartes (toucher un emplacement).
struct ShowcaseEditor: View {
    let initial: Showcase
    var onSaved: (Showcase) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var socle: SocleStyle?
    @State private var slots: [ShowcaseSlot?] = [nil, nil, nil]
    @State private var picking: Int?
    @State private var busy = false
    @State private var error: String?

    private var store: AlbumStore { AlbumStore.shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    ShowcaseStage(socle: socle, slots: slots) { picking = $0 }
                        .padding(.top, Space.s)
                    Text("Touche un emplacement pour y poser une carte. Celle du centre est la plus grande.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    Text("Socle").font(.cfHeadline)
                    socles
                    if let error {
                        Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
                    }
                }
                .padding(Space.gutter)
            }
            .background(Color.paper)
            .navigationTitle("Ma vitrine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }.disabled(busy)
                }
            }
            .sheet(item: Binding(get: { picking.map { PickTarget(index: $0) } }, set: { picking = $0?.index })) { target in
                ShowcaseCardPicker(current: slots[target.index]?.card,
                                   placed: Set(slots.compactMap { $0?.card.id })) { card in
                    slots[target.index] = card.flatMap { c in store.state(c).map { ShowcaseSlot(card: c, state: $0) } }
                    picking = nil
                }
            }
        }
        .onAppear {
            socle = initial.socleStyle
            slots = ShowcaseSlot.slots(of: initial)
        }
        .task { if !store.loaded { await store.refresh() } }
    }

    private struct PickTarget: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private var socles: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                socleChoice(nil, owned: true)
                ForEach(SocleStyle.allCases) { style in
                    socleChoice(style, owned: store.has("socle.\(style.rawValue)"))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func socleChoice(_ style: SocleStyle?, owned: Bool) -> some View {
        let selected = socle == style
        return Button {
            Haptics.selection()
            socle = style
        } label: {
            VStack(spacing: 4) {
                Group {
                    if let style {
                        AlbumImage(kind: .pass, name: style.icon)
                    } else {
                        SocleBase(socle: nil).frame(width: 52, height: 18).frame(maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 8)
                    }
                }
                .frame(width: 60, height: 60)
                .saturation(owned ? 1 : 0).opacity(owned ? 1 : 0.4)
                Text(style?.name ?? "Simple").font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                Text(owned ? (selected ? "Choisi" : " ") : (style?.origin ?? ""))
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(selected ? Color.brand : Color.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 92, height: 112)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Color.brand : .clear, lineWidth: 2))
        }
        .buttonStyle(.row)
        .disabled(!owned)
        .accessibilityLabel("Socle \(style?.name ?? "simple")")
        .accessibilityValue(owned ? (selected ? "choisi" : "") : "à gagner : \(style?.origin ?? "")")
    }

    private func save() {
        busy = true
        error = nil
        let cards = slots.compactMap { $0?.card.serverId }
        Task {
            do {
                let saved = try await app.service.setShowcase(socle: socle?.rawValue, cards: cards)
                Haptics.success()
                onSaved(saved)
                dismiss()
            } catch {
                self.error = error.userMessage("Impossible d'enregistrer ta vitrine. Réessaie.")
            }
            busy = false
        }
    }
}

/// Choix d'une carte possédée pour un emplacement (les plus rares d'abord).
private struct ShowcaseCardPicker: View {
    let current: AlbumCard?
    /// Cartes déjà posées ailleurs dans la vitrine.
    let placed: Set<String>
    var onPick: (AlbumCard?) -> Void

    @Environment(\.dismiss) private var dismiss
    private var store: AlbumStore { AlbumStore.shared }

    private var cards: [AlbumCard] {
        AlbumCatalog.shared.cards.filter { store.isOwned($0) }
            .sorted { $0.rarity != $1.rarity ? $0.rarity > $1.rarity : $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if cards.isEmpty {
                    Text("Tu n'as pas encore de carte. Ouvre des pochettes dans l'Album pour en gagner.")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                        .padding(Space.xl)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                        ForEach(cards) { card in
                            let elsewhere = placed.contains(card.id) && card.id != current?.id
                            Button { onPick(card) } label: {
                                VStack(spacing: 4) {
                                    AlbumCardView(card: card, state: store.state(card), outlined: true)
                                        .overlay(alignment: .topTrailing) {
                                            if card.id == current?.id {
                                                Image(systemName: "checkmark.circle.fill").font(.title3)
                                                    .foregroundStyle(Color.white, Color.brand).padding(4)
                                            }
                                        }
                                    Text(card.name).font(.system(.caption2, design: .rounded).weight(.bold))
                                        .foregroundStyle(Color.ink).lineLimit(1)
                                }
                                .opacity(elsewhere ? 0.35 : 1)
                            }
                            .buttonStyle(.row)
                            .disabled(elsewhere)
                        }
                    }
                    .padding(Space.gutter)
                }
            }
            .background(Color.paper)
            .navigationTitle("Choisir une carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                if current != nil {
                    ToolbarItem(placement: .destructiveAction) { Button("Retirer") { onPick(nil) } }
                }
            }
        }
    }
}
