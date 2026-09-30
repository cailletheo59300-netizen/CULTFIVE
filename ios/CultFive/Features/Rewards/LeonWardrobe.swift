import SwiftUI
import CultFiveCore

/// La tenue de Léon, au même endroit : ce qu'on possède, ce qui se gagne (coffres, fruits, arbre) et ce qui s'achète
/// en graines. Léon en grand sert de cabine d'essayage ; toucher une case l'essaie, un seul bouton suit (Porter,
/// Acheter, ou d'où vient l'objet). Une ligne par emplacement, 4 cases visibles et « + N » pour déplier.
/// Les cases spéciales sont teintées selon leur origine : or pour les coffres, vert pour les fruits, violet pour l'arbre.
struct LeonWardrobe: View {
    @Environment(AppModel.self) private var app
    @Environment(\.leonOutfit) private var outfit
    @State private var shop: ShopOverview?
    @State private var trying: LeonItem?
    @State private var confirm: LeonItem?
    @State private var expanded: Set<String> = []
    @State private var busy = false
    @State private var message: String?

    private var items: [LeonItem] { app.progression?.items ?? [] }
    private var seeds: Int { app.profile?.seeds ?? app.progression?.seeds ?? 0 }

    static let slots: [(id: String, name: String)] = [
        ("form", "Forme"), ("skin", "Couleur"), ("pattern", "Motif"), ("hat", "Tête"), ("eyes", "Yeux"),
        ("neck", "Cou"), ("back", "Dos"), ("effect", "Effet"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            fittingRoom
            if let shop, !shop.featured.isEmpty { featured(shop) }
            ForEach(Self.slots, id: \.id) { slot in row(slot.id, name: slot.name) }
            legend
        }
        .task { shop = try? await app.service.shop() }
        .confirmationDialog(confirm.map { "Acheter « \($0.name) » ?" } ?? "",
                            isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }), titleVisibility: .visible) {
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
            ZStack(alignment: .topTrailing) {
                Leon(color: .brand, pose: trying == nil ? .rest : .proud, curl: 0.6,
                     outfit: trying.map { outfit.trying($0.id, slot: $0.slot) } ?? outfit)
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .animation(Motion.bounce, value: trying?.id)
                Button { Task { await randomOutfit() } } label: {
                    Image(systemName: "dice.fill")
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.brand)
                        .frame(width: 40, height: 40)
                        .background(Color.brand.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Tenue au hasard parmi tes objets")
                .disabled(busy)
            }
            .padding([.top, .horizontal], Space.m)
            if let item = trying {
                Text(item.name).font(.cfTitle3)
                action(item)
                Button("Retirer l'essai") { withAnimation(Motion.standard) { trying = nil } }
                    .buttonStyle(TextLinkStyle(color: .inkSoft))
            } else {
                Text("Touche une case pour l'essayer sur Léon.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            if let message { Text(message).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.correct) }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Space.m)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
    }

    @ViewBuilder
    private func action(_ item: LeonItem) -> some View {
        if item.owned {
            let worn = outfit.item(in: item.slot) == item.id
            Button(worn ? "Déjà porté" : "Porter") { Task { await wear(item) } }
                .buttonStyle(.ink)
                .disabled(busy || worn)
        } else if item.rarity == "shop" {
            Button { confirm = item } label: {
                HStack(spacing: 6) {
                    Text("Acheter")
                    SeedsAmount(amount: price(item), color: .white)
                }
            }
            .buttonStyle(.ink)
            .disabled(busy || seeds < price(item))
            if seeds < price(item) {
                Text("Il te manque \(price(item) - seeds) \(Brand.currencyPlural).").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        } else {
            Label(origin(item), systemImage: "lock.fill")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(tint(item) ?? Color.inkSoft)
                .padding(.horizontal, 16).frame(minHeight: 44)
                .background((tint(item) ?? Color.hairline).opacity(0.15), in: Capsule())
        }
    }

    // MARK: Vitrine du jour

    private func featured(_ shop: ShopOverview) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Vitrine du jour").labelCaps()
                Spacer()
                if let reset = shop.resetsAt {
                    Text("change \(reset, style: .relative)").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            HStack(spacing: 8) {
                ForEach(shop.featured) { feature in
                    if let item = items.first(where: { $0.id == feature.id }) {
                        tile(item, promo: feature.price < feature.original ? feature.original : nil)
                    }
                }
            }
        }
    }

    // MARK: Lignes par emplacement

    /// Possédés (le porté d'abord), puis ce qui se gagne, puis la boutique par prix.
    private func sorted(_ slot: String) -> [LeonItem] {
        items.filter { $0.slot == slot }.sorted { a, b in
            func rank(_ i: LeonItem) -> Int {
                if outfit.item(in: i.slot) == i.id { return 0 }
                if i.owned { return 1 }
                return i.rarity == "shop" ? 3 : 2
            }
            if rank(a) != rank(b) { return rank(a) < rank(b) }
            return (a.price ?? 0, a.unlockStage ?? 0) < (b.price ?? 0, b.unlockStage ?? 0)
        }
    }

    @ViewBuilder
    private func row(_ slot: String, name: String) -> some View {
        let list = sorted(slot)
        if !list.isEmpty {
            let open = expanded.contains(slot)
            let visible = open ? list : Array(list.prefix(4))
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name).font(.cfTitle3)
                    Text("\(list.filter(\.owned).count)/\(list.count)").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                    Spacer()
                    if list.count > 4 {
                        Button(open ? "Réduire" : "Tout voir") { toggle(slot) }
                            .font(.system(.footnote, design: .rounded).weight(.heavy)).foregroundStyle(Color.brand)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(visible) { item in tile(item) }
                    if !open && list.count > 4 {
                        Button { toggle(slot) } label: {
                            Text("+\(list.count - 4)")
                                .font(.system(.headline, design: .rounded).weight(.black))
                                .foregroundStyle(Color.brand)
                                .frame(maxWidth: .infinity, minHeight: 74)
                                .background(Color.brand.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                        }
                        .buttonStyle(.row)
                        .accessibilityLabel("Voir les \(list.count - 4) autres")
                    }
                }
            }
        }
    }

    private func toggle(_ slot: String) {
        Haptics.selection()
        withAnimation(Motion.standard) {
            if expanded.contains(slot) { expanded.remove(slot) } else { expanded.insert(slot) }
        }
    }

    private func tile(_ item: LeonItem, promo original: Int? = nil) -> some View {
        let selected = trying?.id == item.id
        let worn = outfit.item(in: item.slot) == item.id
        let tint = tint(item)
        return Button {
            Haptics.selection()
            withAnimation(Motion.standard) { trying = item }
        } label: {
            VStack(spacing: 2) {
                Leon(color: .brand, pose: .rest, curl: 0.4, animated: false,
                     outfit: LeonOutfit(form: item.slot == "form" ? nil : outfit.form).trying(item.id, slot: item.slot))
                    .frame(height: 40)
                    .opacity(item.owned || item.rarity == "shop" ? 1 : 0.55)
                Group {
                    if worn {
                        Text("Porté").foregroundStyle(Color.brand)
                    } else if item.owned {
                        Text("À toi").foregroundStyle(Color.inkSoft)
                    } else if item.rarity == "shop" {
                        HStack(spacing: 2) {
                            if let original { Text("\(original)").strikethrough().foregroundStyle(Color.inkSoft) }
                            Text("\(price(item))").foregroundStyle(original != nil ? Color.wrong : Color.ink).monospacedDigit()
                        }
                    } else {
                        Image(systemName: "lock.fill").foregroundStyle(tint ?? Color.inkSoft)
                    }
                }
                .font(.system(.caption2, design: .rounded).weight(.heavy))
                .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.vertical, 6).padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background((tint ?? Color.paperRaised).opacity(tint == nil ? 1 : 0.16),
                        in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .strokeBorder(selected ? Color.brand : worn ? Color.brand.opacity(0.5) : (tint ?? .clear).opacity(0.6),
                                  lineWidth: selected ? 2.5 : 1.5)
            }
        }
        .buttonStyle(.row)
        .accessibilityLabel(item.name)
        .accessibilityValue(worn ? "porté" : item.owned ? "possédé" : item.rarity == "shop" ? "\(price(item)) \(Brand.currencyPlural)" : origin(item))
    }

    private var legend: some View {
        HStack(spacing: Space.m) {
            legendDot(Color(hex: 0xF59F00), "Coffres")
            legendDot(Color(hex: 0x2F9E44), "Fruits de l'arbre")
            legendDot(Color.brand, "Arbre")
        }
        .font(.cfFootnote)
        .foregroundStyle(Color.inkSoft)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.35)).frame(width: 12, height: 12)
            Text(text)
        }
    }

    /// Teinte selon l'origine des objets spéciaux ; nil pour la boutique.
    private func tint(_ item: LeonItem) -> Color? {
        switch item.rarity {
        case "chest": return Color(hex: 0xF59F00)
        case "fruit": return Color(hex: 0x2F9E44)
        case "tree": return .brand
        default: return nil
        }
    }

    private func origin(_ item: LeonItem) -> String {
        switch item.rarity {
        case "fruit": return "Fruit de l'arbre de Léon"
        case "tree": return "Arbre : \(TreeState.stageName(item.unlockStage ?? 1).lowercased())"
        default: return "À gagner dans les coffres"
        }
    }

    // MARK: Actions

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

    /// Tenue au hasard parmi ce qu'on possède (la forme ne change pas).
    private func randomOutfit() async {
        busy = true
        defer { busy = false }
        Haptics.selection()
        for slot in ["skin", "pattern", "hat", "eyes", "neck", "back", "effect"] {
            let owned = items.filter { $0.slot == slot && $0.owned }
            let pick = Bool.random() || slot == "skin" ? owned.randomElement()?.id : nil
            _ = try? await app.service.equip(slot: slot, item: pick)
        }
        await app.refreshProgression()
        withAnimation(Motion.standard) { trying = nil }
    }
}
