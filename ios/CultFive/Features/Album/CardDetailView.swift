import SwiftUI

/// Fiche d'une carte : la carte en grand qui s'incline (doigt ou téléphone), ses quatre états, son habillage et le dos.
/// Case vide : la silhouette et le bouton pour la fabriquer.
struct CardDetailView: View {
    let card: AlbumCard
    let store: AlbumStore

    private enum Tab: String, CaseIterable { case states = "États", dress = "Habillage", back = "Dos" }

    @State private var tab: Tab = .states
    @State private var drag: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: OwnedCard? { store.state(card) }
    /// La carte reste droite : elle ne s'incline que sous le doigt, et revient en place quand on la lâche.
    private var tilt: CGSize { drag }

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                header
                cardStage
                if state != nil {
                    Picker("Rubrique", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch tab {
                    case .states: statesPanel
                    case .dress: dressPanel
                    case .back: backPanel
                    }
                } else {
                    craftPanel
                }
            }
            .padding(Space.gutter)
        }
        .background(Color.paper.ignoresSafeArea())
        // La fiche est en plein écran : elle montre elle-même les refus du serveur.
        .alert("Album", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AlbumCatalog.shared.page(card.pageKey)?.title ?? "").labelCaps(DomainPalette.color(card.domain))
                Text(card.name).font(.cfHeadline).foregroundStyle(Color.ink)
                HStack(spacing: 6) {
                    Circle().fill(card.rarity.color).frame(width: 8, height: 8)
                    Text("\(card.rarity.label) · carte \(card.n)").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    if let state, state.copies > 1 {
                        Text("· \(state.copies) exemplaires").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                }
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(.body, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ink)
                    .frame(width: 40, height: 40)
                    .background(Color.paperRaised, in: Circle())
                    .shadow(color: Color(hex: 0x3A1FB8).opacity(0.12), radius: 6, y: 3)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
        }
    }

    private var cardStage: some View {
        Group {
            if state != nil {
                AlbumCardView(card: card, state: state, tilt: tilt)
                    .rotation3DEffect(.degrees(Double(tilt.width) * 14), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(Double(-tilt.height) * 10), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .shadow(color: card.rarity.color.opacity(card.rarity >= .epic ? 0.55 : 0.2), radius: 24, y: 12)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                drag = CGSize(width: max(-1, min(1, value.translation.width / 140)),
                                              height: max(-1, min(1, value.translation.height / 180)))
                            }
                            .onEnded { _ in withAnimation(Motion.moment) { drag = .zero } }
                    )
            } else {
                EmptySlot(card: card)
            }
        }
        .frame(maxWidth: 280)
        .padding(.vertical, Space.s)
    }

    // MARK: - Fabriquer

    private var craftPanel: some View {
        let cost = card.rarity.craftCost
        let enough = store.neurones >= cost
        return VStack(spacing: Space.m) {
            Text("Cette case est vide. Tu peux attendre de la trouver dans une pochette, ou la fabriquer tout de suite avec tes neurones.")
                .font(.cfCallout).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
            ShopButton(title: "Fabriquer cette carte", price: "\(cost)", icon: "neurone", fill: .brand, text: .white, enabled: enough && !store.busy) {
                Task { if await store.craft(card) { Haptics.success() } }
            }
            if !enough {
                Text("Il te manque \(cost - store.neurones) neurones.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            HStack(spacing: 4) {
                Text("Tu as")
                NeuronesAmount(amount: store.neurones, color: .inkSoft)
            }
            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
        }
        .popCard()
    }

    // MARK: - États

    private var statesPanel: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Une carte peut avoir plusieurs états en même temps. Ce que tu as gagné reste à toi : tu peux juste choisir de l'afficher ou non.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            if store.admin {
                Label("Mode admin : pose ou retire chaque état librement.", systemImage: "crown.fill")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.inkFixed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.sun, in: Capsule())
            }
            StateRow(card: card, preview: OwnedCard(), title: "Normale",
                     what: "La carte telle qu'elle sort de la pochette.",
                     how: nil, owned: true) { EmptyView() }
            Hairline()
            StateRow(card: card, preview: OwnedCard(shiny: true), title: "Brillante",
                     what: "Un reflet irisé passe sur la carte quand tu la bouges.",
                     how: "Tu l'obtiens au premier doublon de cette carte.",
                     owned: state?.shiny == true) { control(.shiny) }
            Hairline()
            StateRow(card: card, preview: OwnedCard(prestige: true), title: "Prestige",
                     what: "Le dessin prend toute la carte, sur un fond holographique.",
                     how: "Il faut un jeton Prestige : tu en gagnes 1 dans le pass, et parfois dans un coffre Savant. Le jeton est utilisé pour toujours.",
                     owned: state?.prestige == true) { control(.prestige) }
            Hairline()
            StateRow(card: card, preview: OwnedCard(masterpiece: true), title: "Chef-d'œuvre",
                     what: "Un triple cadre doré et une plaque gravée.",
                     how: "Il s'obtient en maîtrisant la carte au quiz (3 étoiles). Il ne s'achète pas.",
                     owned: state?.masterpiece == true) { control(.masterpiece) }
            Text(card.phrase)
                .font(.cfReading).foregroundStyle(Color.ink)
                .padding(.top, Space.s)
        }
        .popCard()
    }

    /// Ce qu'on peut faire d'un état : l'afficher ou non s'il est obtenu ; le poser librement en admin ;
    /// utiliser un jeton pour le Prestige.
    @ViewBuilder private func control(_ kind: CardStateKind) -> some View {
        if let state {
            if store.admin {
                Toggle("Activé", isOn: Binding(get: { state.has(kind) && !state.isHidden(kind) },
                                               set: { on in withAnimation(Motion.standard) { store.adminSet(card, kind, on) } }))
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .tint(Color.brand)
            } else if state.has(kind) {
                Toggle("Afficher", isOn: Binding(get: { !state.isHidden(kind) },
                                                 set: { on in withAnimation(Motion.standard) { store.setHidden(card, kind, !on) } }))
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .tint(Color.brand)
            } else if kind == .prestige {
                Button {
                    Task { if await store.applyPrestige(card) { Haptics.success() } }
                } label: {
                    HStack(spacing: 6) {
                        AlbumImage(kind: .pass, name: "jeton").frame(width: 22, height: 22)
                        Text(store.tokens > 0 ? "Utiliser un jeton (il t'en reste \(store.tokens))" : "Aucun jeton pour l'instant")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(store.tokens > 0 ? Color.white : Color.inkSoft)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(store.tokens > 0 ? Color.brand : Color.hairline, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(store.tokens == 0 || store.busy)
            }
        }
    }

    // MARK: - Habillage

    private var dressPanel: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("L'habillage se gagne une fois (pass, événements) et se pose sur n'importe quelle carte. Il ne change ni la rareté ni le jeu.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            dressRow("Cadre", items: Cosmetic.frames + (store.has("cadre.anime") ? [Cosmetic.Item(id: "anime", name: "Cadre animé", icon: "final_payant")] : []),
                     prefix: "cadre", current: state?.frame) { id in store.dress(card) { $0.frame = id } }
            dressRow("Finition", items: Cosmetic.finishes, prefix: "finition", current: state?.finish) { id in store.dress(card) { $0.finish = id } }
            dressRow("Titre de carte", items: Cosmetic.titles, prefix: "titre", current: state?.title) { id in store.dress(card) { $0.title = id } }
        }
        .popCard()
    }

    private func dressRow(_ title: String, items: [Cosmetic.Item], prefix: String, current: String?,
                          apply: @escaping (String?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).labelCaps()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    choice(name: "Aucun", icon: nil, selected: current == nil, locked: false) { apply(nil) }
                    ForEach(items) { item in
                        let locked = !store.has("\(prefix).\(item.id)") && item.id != "anime"
                        choice(name: item.name, icon: item.icon, selected: current == item.id, locked: locked) { apply(item.id) }
                    }
                }
            }
        }
    }

    private func choice(name: String, icon: String?, selected: Bool, locked: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !locked else { Haptics.error(); return }
            Haptics.selection()
            withAnimation(Motion.standard) { action() }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let icon {
                            AlbumImage(kind: .pass, name: icon)
                        } else {
                            Image(systemName: "nosign").font(.title2).foregroundStyle(Color.inkSoft)
                        }
                    }
                    .frame(width: 54, height: 54)
                    .opacity(locked ? 0.35 : 1)
                    if locked {
                        Image(systemName: "lock.fill").font(.caption2.weight(.bold)).foregroundStyle(Color.inkSoft)
                    }
                }
                Text(name).font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(locked ? Color.inkSoft : Color.ink)
                    .lineLimit(2).multilineTextAlignment(.center)
                    .frame(width: 72)
            }
            .padding(6)
            .background(selected ? Color.brand.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.s, style: .continuous).strokeBorder(selected ? Color.brand : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(name), à débloquer dans le pass" : name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Dos

    private var backPanel: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Le dos s'applique à toutes tes cartes (ouvertures de pochettes, vitrine).")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(Cosmetic.backs) { item in
                    let locked = !store.has("dos.\(item.id)")
                    Button {
                        guard !locked else { Haptics.error(); return }
                        Haptics.selection()
                        store.setBack(item.id)
                    } label: {
                        VStack(spacing: 4) {
                            AlbumCardBack(kind: item.id)
                                .opacity(locked ? 0.4 : 1)
                                .overlay {
                                    if locked { Image(systemName: "lock.fill").foregroundStyle(.white).font(.title3.weight(.bold)) }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(store.back == item.id ? Color.brand : .clear, lineWidth: 3)
                                )
                            Text(item.name).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .popCard()
    }
}

/// Une ligne de la partie « États » : la mini-carte dans cet état, ce que c'est, comment l'obtenir, et son statut.
private struct StateRow<Control: View>: View {
    let card: AlbumCard
    let preview: OwnedCard
    let title: String
    let what: String
    let how: String?
    let owned: Bool
    @ViewBuilder var control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .top, spacing: Space.m) {
                AlbumCardView(card: card, state: preview, dressed: false)
                    .frame(width: 64)
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.ink)
                        Spacer(minLength: 4)
                        Text(owned ? "Obtenu" : "Pas encore")
                            .font(.system(.caption2, design: .rounded).weight(.black))
                            .foregroundStyle(owned ? Color.white : Color.inkSoft)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(owned ? Color.correct : Color.hairline, in: Capsule())
                            .fixedSize()
                    }
                    Text(what)
                        .font(.cfFootnote).foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let how {
                        Text(how)
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            control
        }
        .accessibilityElement(children: .contain)
    }
}
