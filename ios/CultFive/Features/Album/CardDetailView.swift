import SwiftUI
import CoreMotion

/// Fiche d'une carte : la carte en grand qui s'incline (doigt ou téléphone), ses quatre états, son habillage et le dos.
/// Case vide : la silhouette et le bouton pour la fabriquer.
struct CardDetailView: View {
    let card: AlbumCard
    let store: AlbumStore

    private enum Tab: String, CaseIterable { case states = "États", dress = "Habillage", back = "Dos" }

    @State private var tab: Tab = .states
    @State private var drag: CGSize = .zero
    @State private var motion = TiltMotion()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: OwnedCard? { store.state(card) }
    private var tilt: CGSize {
        CGSize(width: max(-1, min(1, drag.width + motion.tilt.width)), height: max(-1, min(1, drag.height + motion.tilt.height)))
    }

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
        .onAppear { if !reduceMotion { motion.start() } }
        .onDisappear { motion.stop() }
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
            Button { dismiss() } label: { CloseCircle() }
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
            ShopButton(title: "Fabriquer cette carte", price: "\(cost)", icon: "neurone", fill: .brand, text: .white, enabled: enough) {
                if store.craft(card) { Haptics.success() }
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
        VStack(alignment: .leading, spacing: Space.s) {
            stateRow("Normale", detail: "La carte telle qu'elle sort de la pochette.", done: true, symbol: "rectangle.portrait")
            stateRow("Brillante", detail: state?.shiny == true ? "Reflet irisé : incline la carte." : "Au premier doublon de cette carte.",
                     done: state?.shiny == true, symbol: "sparkles")
            stateRow("Prestige", detail: state?.prestige == true ? "Le dessin occupe toute la carte, pour toujours." : "Pose un jeton Prestige : le dessin occupe toute la carte. Définitif.",
                     done: state?.prestige == true, symbol: "crown.fill", trailing: state?.prestige == true ? nil : AnyView(prestigeButton))
            stateRow("Chef-d'œuvre", detail: state?.masterpiece == true ? "Carte maîtrisée : triple cadre doré." : "Maîtrise cette carte au quiz (3 étoiles). Ne s'achète pas.",
                     done: state?.masterpiece == true, symbol: "star.circle.fill")
            Text(card.phrase)
                .font(.cfReading).foregroundStyle(Color.ink)
                .padding(.top, Space.s)
        }
        .popCard()
    }

    private var prestigeButton: some View {
        Button(store.admin ? "Jeton (∞)" : "Jeton (\(store.tokens))") {
            if store.applyPrestige(card) { Haptics.success() }
        }
        .font(.system(.footnote, design: .rounded).weight(.heavy))
        .buttonStyle(.borderedProminent)
        .tint(Color.brand)
        .disabled(store.tokens == 0)
    }

    private func stateRow(_ title: String, detail: String, done: Bool, symbol: String, trailing: AnyView? = nil) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: done ? "checkmark.circle.fill" : symbol)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(done ? Color.correct : Color.inkSoft.opacity(0.6))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
                Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Habillage

    private var dressPanel: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("L'habillage se gagne une fois (pass, événements) et se pose sur n'importe quelle carte. Il ne change ni la rareté ni le jeu.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            dressRow("Cadre", items: Cosmetic.frames + (store.has("cadre.anime") ? [Cosmetic.Item(id: "anime", name: "Cadre animé", icon: "final_payant")] : []),
                     prefix: "cadre", current: state?.frame) { id in store.update(card) { $0.frame = id } }
            dressRow("Finition", items: Cosmetic.finishes, prefix: "finition", current: state?.finish) { id in store.update(card) { $0.finish = id } }
            dressRow("Titre de carte", items: Cosmetic.titles, prefix: "titre", current: state?.title) { id in store.update(card) { $0.title = id } }
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
                        store.back = item.id
                        store.save()
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

/// Inclinaison du téléphone (gravité), lissée, pour faire bouger les reflets.
@Observable
final class TiltMotion {
    var tilt: CGSize = .zero
    @ObservationIgnored private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let gravity = data?.gravity else { return }
            let target = CGSize(width: max(-1, min(1, gravity.x * 1.6)), height: max(-1, min(1, (gravity.y + 0.6) * 1.6)))
            tilt = CGSize(width: tilt.width * 0.8 + target.width * 0.2, height: tilt.height * 0.8 + target.height * 0.2)
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}
