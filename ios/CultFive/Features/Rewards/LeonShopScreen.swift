import SwiftUI
import CultFiveCore

/// Boutique de Léon (graines uniquement) : cabine d'essayage en haut, vitrine du jour (une promo), puis couleurs,
/// motifs et objets. Toucher un article l'essaie sur Léon ; l'achat se confirme, puis l'article est porté aussitôt.
/// Les objets des coffres et des fruits ne sont jamais vendus.
struct LeonShopScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.leonOutfit) private var outfit
    @State private var shop: ShopOverview?
    @State private var trying: LeonItem?
    @State private var confirm: LeonItem?
    @State private var busy = false
    @State private var message: String?

    private var items: [LeonItem] { (app.progression?.items ?? []).filter { $0.rarity == "shop" } }
    private var seeds: Int { app.profile?.seeds ?? app.progression?.seeds ?? 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                fittingRoom
                if let shop, !shop.featured.isEmpty { featured(shop) }
                section("Couleurs", slot: "skin", columns: 4)
                section("Motifs", slot: "pattern", columns: 4)
                ForEach([("hat", "Chapeaux"), ("eyes", "Yeux"), ("neck", "Cou"), ("back", "Dos"), ("effect", "Effets")], id: \.0) { slot in
                    section(slot.1, slot: slot.0, columns: 3)
                }
                Text("Ici, tout se paie en \(Brand.currencyPlural), jamais en argent réel. Les objets des coffres et de l'arbre ne sont pas à vendre : ils se gagnent.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .scrollIndicators(.hidden)
        .clearsTabBar()
        .background(Color.paper)
        .navigationTitle("Boutique de Léon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.paper, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { SeedsAmount(amount: seeds).font(.cfNumber) }
        }
        .task {
            shop = try? await app.service.shop()
            await app.refreshProgression()
        }
        .confirmationDialog(confirm.map { "Acheter « \($0.name) » ?" } ?? "", isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                            titleVisibility: .visible) {
            if let item = confirm {
                Button("Acheter pour \(price(item)) \(Brand.currencyPlural)") { Task { await buy(item) } }
            }
        } message: {
            Text("Léon le portera tout de suite. Tu peux changer quand tu veux.")
        }
    }

    // MARK: Cabine d'essayage

    private var fittingRoom: some View {
        VStack(spacing: Space.s) {
            Leon(color: .brand, pose: trying == nil ? .rest : .proud, curl: 0.6,
                 outfit: trying.map { outfit.trying($0.id, slot: $0.slot) } ?? outfit)
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .padding(.top, Space.m)
                .animation(Motion.bounce, value: trying?.id)
            if let item = trying {
                Text(item.name).font(.cfTitle3)
                if item.owned {
                    Button(outfit.item(in: item.slot) == item.id ? "Déjà porté" : "Porter") { Task { await wear(item) } }
                        .buttonStyle(.ink)
                        .disabled(busy || outfit.item(in: item.slot) == item.id)
                } else {
                    Button { confirm = item } label: {
                        HStack(spacing: 6) {
                            Text("Acheter")
                            SeedsAmount(amount: price(item), color: .white)
                        }
                    }
                    .buttonStyle(.ink)
                    .disabled(busy || seeds < price(item))
                    if seeds < price(item) {
                        Text("Il te manque \(price(item) - seeds) \(Brand.currencyPlural).")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                }
                Button("Retirer l'essai") { withAnimation(Motion.standard) { trying = nil } }
                    .buttonStyle(TextLinkStyle(color: .inkSoft))
            } else {
                Text("Touche un article pour l'essayer sur Léon.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            if let message { Text(message).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.correct) }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Space.m)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    // MARK: Vitrine du jour

    private func featured(_ shop: ShopOverview) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Vitrine du jour").font(.cfHeadline)
                Spacer()
                if let reset = shop.resetsAt {
                    Text("Nouvelle vitrine \(reset, style: .relative)").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            HStack(spacing: 10) {
                ForEach(shop.featured) { feature in
                    if let item = items.first(where: { $0.id == feature.id }) {
                        tile(item, promo: feature.price < feature.original ? feature.original : nil)
                    }
                }
            }
        }
    }

    // MARK: Rayons

    @ViewBuilder
    private func section(_ title: String, slot: String, columns: Int) -> some View {
        let list = items.filter { $0.slot == slot }
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(title).font(.cfHeadline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                    ForEach(list) { item in tile(item, compact: columns > 3) }
                }
            }
        }
    }

    private func tile(_ item: LeonItem, promo original: Int? = nil, compact: Bool = false) -> some View {
        let selected = trying?.id == item.id
        return Button {
            Haptics.selection()
            withAnimation(Motion.standard) { trying = item }
        } label: {
            VStack(spacing: 4) {
                Leon(color: .brand, pose: .rest, curl: 0.4, animated: false, outfit: LeonOutfit(form: outfit.form).trying(item.id, slot: item.slot))
                    .frame(height: compact ? 40 : 54)
                if !compact {
                    Text(item.name).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                if item.owned {
                    Text(outfit.item(in: item.slot) == item.id ? "Porté" : "À toi")
                        .font(.system(.caption2, design: .rounded).weight(.heavy)).foregroundStyle(Color.brand)
                } else {
                    HStack(spacing: 3) {
                        if let original {
                            Text("\(original)").strikethrough().foregroundStyle(Color.inkSoft)
                        }
                        SeedsAmount(amount: price(item), color: original != nil ? .wrong : .inkSoft)
                    }
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                }
            }
            .padding(compact ? 6 : 8)
            .frame(maxWidth: .infinity)
            .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .strokeBorder(selected ? Color.brand : (original != nil ? Color.sun : .clear), lineWidth: 2)
            }
        }
        .buttonStyle(.row)
        .accessibilityLabel(item.name)
        .accessibilityValue(item.owned ? "possédé" : "\(price(item)) \(Brand.currencyPlural)")
    }

    // MARK: Actions

    /// Prix du jour (promo de la vitrine comprise).
    private func price(_ item: LeonItem) -> Int {
        shop?.featured.first { $0.id == item.id }?.price ?? item.price ?? 0
    }

    private func buy(_ item: LeonItem) async {
        busy = true
        defer { busy = false }
        do {
            _ = try await app.service.buy(item.id)
            _ = try? await app.service.equip(slot: item.slot, item: item.id)
            SoundFX.play(.reward)
            Haptics.success()
            await app.refreshProfile()
            shop = try? await app.service.shop()
            withAnimation(Motion.bounce) {
                message = "\(item.name) : à toi !"
                trying = nil
            }
        } catch {
            message = (error as? LocalizedError)?.errorDescription
        }
    }

    private func wear(_ item: LeonItem) async {
        busy = true
        defer { busy = false }
        _ = try? await app.service.equip(slot: item.slot, item: item.id)
        Haptics.selection()
        await app.refreshProgression()
        withAnimation(Motion.standard) { trying = nil }
    }
}

/// Toutes les étapes de l'arbre et les formes de Léon : ce qui est atteint en couleur, le reste en silhouette.
struct TreeStagesSheet: View {
    let tree: TreeState

    private struct Stage: Identifiable {
        let id: Int
        let stage: Int
        let fruits: Int
        let name: String
        let threshold: Int
        let reward: String
        let form: String?
    }

    private var stages: [Stage] {
        let forms = [1: "form_baby", 3: "form_young", 5: "form_adult", 6: "form_sage"]
        let formNames = ["form_baby": "Léon bébé", "form_young": "Léon jeune", "form_adult": "Léon adulte", "form_sage": "Léon sage"]
        var list = (1 ... 6).map { stage in
            Stage(id: stage, stage: stage, fruits: 0, name: TreeState.stageName(stage), threshold: TreeState.stageThresholds[stage - 1],
                  reward: [stage > 1 ? "Coffre en or" : nil, forms[stage].flatMap { formNames[$0] }].compactMap { $0 }.joined(separator: " · "),
                  form: forms[stage])
        }
        let fruitNames = ["Couronne de feuilles", "Monocle", "Cape étoilée", "Léon doré"]
        for fruit in 1 ... 4 {
            list.append(Stage(id: 6 + fruit, stage: 6, fruits: fruit, name: fruit == 1 ? "1er fruit" : "\(fruit)e fruit",
                              threshold: 9000 + TreeState.fruitStep * fruit, reward: fruitNames[fruit - 1], form: nil))
        }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("L'arbre et Léon").font(.cfDisplay).padding(.top, Space.l)
                Text("Chaque étape donne un coffre en or. Léon change de forme avec l'arbre, puis l'arbre porte des fruits rares.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(stages) { stage in
                    let reached = tree.points >= stage.threshold
                    HStack(spacing: Space.m) {
                        ZStack(alignment: .bottomLeading) {
                            LeonTreeView(stage: stage.stage, fruits: stage.fruits).frame(width: 76, height: 76)
                            if let form = stage.form {
                                Leon(color: .brand, pose: .rest, curl: 0.4, animated: false, outfit: LeonOutfit(form: form))
                                    .frame(width: 36)
                            }
                        }
                        .saturation(reached ? 1 : 0)
                        .opacity(reached ? 1 : 0.35)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.name).font(.cfTitle3).foregroundStyle(reached ? Color.ink : Color.inkSoft)
                            Text(stage.threshold == 0 ? "Au départ" : "\(stage.threshold) \(Brand.currencyPlural)")
                                .font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft).monospacedDigit()
                            if !stage.reward.isEmpty {
                                Text(stage.reward).font(.cfFootnote).foregroundStyle(reached ? Color.correct : Color.inkSoft)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: reached ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundStyle(reached ? Color.correct : Color.hairline)
                            .font(.title3)
                    }
                    .padding(10)
                    .background(stage.stage == tree.stage && stage.fruits == tree.fruits ? Color.brand.opacity(0.08) : Color.paperRaised,
                                in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(reached ? "atteint" : "à venir")
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .background(Color.paper)
        .presentationDragIndicator(.visible)
    }
}
