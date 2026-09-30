#if DEBUG
import Foundation
import CultFiveCore

/// Coffres, arbre et tenue de Léon en mode démo : mêmes règles que le serveur (migration 0022), en mémoire.
final class DemoProgression: @unchecked Sendable {
    static let shared = DemoProgression()
    private let lock = NSLock()

    private var chests: [ChestRef] = [
        ChestRef(id: UUID(), tier: .gold, source: "welcome"),
        ChestRef(id: UUID(), tier: .wood, source: "quests_day"),
        ChestRef(id: UUID(), tier: .silver, source: "level", ref: "5"),
    ]
    private var opened: [UUID: ChestContents] = [:]
    private var owned: Set<String> = ["beret"]
    private var outfit: [String: String] = ["hat": "beret"]
    private var tickets = (fifty: 1, hint: 0)
    private var treePoints = 420
    private var stageRewarded = 2
    private var fruitsRewarded = 0
    private var freezes = 1
    private var fedKeys: Set<UUID> = []

    static let catalog: [(id: String, name: String, slot: String, rarity: String)] = chestAndFruit + forms + shopItems.map { ($0.id, $0.name, $0.slot, "shop") }

    static let forms: [(id: String, name: String, slot: String, rarity: String)] = [
        ("form_baby", "Bébé", "form", "tree"), ("form_young", "Jeune", "form", "tree"),
        ("form_adult", "Adulte", "form", "tree"), ("form_sage", "Sage", "form", "tree"),
    ]
    static let formStages = ["form_baby": 1, "form_young": 3, "form_adult": 5, "form_sage": 6]

    static let shopItems: [(id: String, name: String, slot: String, price: Int)] = [
        ("skin_mint", "Menthe", "skin", 200), ("skin_peach", "Pêche", "skin", 200), ("skin_sky", "Ciel", "skin", 200),
        ("skin_coral", "Corail", "skin", 200), ("skin_ocean", "Océan", "skin", 250), ("skin_lavender", "Lavande", "skin", 250),
        ("skin_lemon", "Citron", "skin", 250), ("skin_raspberry", "Framboise", "skin", 300), ("skin_forest", "Forêt", "skin", 300),
        ("skin_cocoa", "Cacao", "skin", 350), ("skin_night", "Nuit", "skin", 400), ("skin_snow", "Neige", "skin", 600),
        ("pattern_stripes", "Rayures", "pattern", 800), ("pattern_dots", "Pois", "pattern", 800),
        ("pattern_stars", "Étoiles", "pattern", 1200), ("pattern_rainbow", "Arc-en-ciel", "pattern", 1500),
        ("cap", "Casquette", "hat", 300), ("beanie", "Bonnet", "hat", 300), ("wizard_hat", "Chapeau de magicien", "hat", 900),
        ("crown", "Couronne", "hat", 1200), ("sunglasses", "Lunettes de soleil", "eyes", 400), ("hero_mask", "Masque de héros", "eyes", 700),
        ("medal", "Médaille", "neck", 500), ("flower_necklace", "Collier de fleurs", "neck", 450), ("backpack", "Sac à dos", "back", 500),
        ("wings", "Ailes", "back", 1200), ("aura_stars", "Aura étoilée", "effect", 1000), ("bubbles", "Bulles", "effect", 600),
    ]

    static let chestAndFruit: [(id: String, name: String, slot: String, rarity: String)] = [
        ("beret", "Béret", "hat", "chest"), ("party_hat", "Chapeau de fête", "hat", "chest"),
        ("headphones", "Casque audio", "hat", "chest"), ("round_glasses", "Lunettes rondes", "eyes", "chest"),
        ("star_glasses", "Lunettes étoiles", "eyes", "chest"), ("red_scarf", "Écharpe rouge", "neck", "chest"),
        ("bow_tie", "Nœud papillon", "neck", "chest"), ("skin_sunset", "Coucher de soleil", "skin", "chest"),
        ("leaf_crown", "Couronne de feuilles", "hat", "fruit"), ("monocle", "Monocle", "eyes", "fruit"),
        ("star_cape", "Cape étoilée", "back", "fruit"), ("skin_gold", "Léon doré", "skin", "fruit"),
    ]

    private static let maxPoints = 19000

    private static func stage(_ points: Int) -> Int {
        TreeState.stageThresholds.lastIndex { points >= $0 }.map { $0 + 1 } ?? 1
    }

    private static func fruits(_ points: Int) -> Int { min(4, max(0, (points - 9000) / TreeState.fruitStep)) }

    private static func tree(_ points: Int) -> TreeState {
        let stage = stage(points)
        let fruits = fruits(points)
        let next: Int? = points >= maxPoints ? nil
            : stage < 6 ? TreeState.stageThresholds[stage] : 9000 + TreeState.fruitStep * (fruits + 1)
        return TreeState(points: points, stage: stage, stageName: TreeState.stageName(stage), fruits: fruits,
                         nextAt: next, max: maxPoints, complete: points >= maxPoints)
    }

    func overview(seeds: Int) -> ProgressionOverview {
        lock.lock(); defer { lock.unlock() }
        return ProgressionOverview(
            xp: 1240, level: 5, seeds: seeds, streakFreezes: freezes, tree: Self.tree(treePoints), chests: chests,
            tickets: HelpTickets(fiftyFifty: tickets.fifty, hint: tickets.hint), outfit: outfit,
            items: Self.catalog.map { item in
                LeonItem(id: item.id, name: item.name, slot: item.slot, rarity: item.rarity,
                         owned: owned.contains(item.id) || (Self.formStages[item.id].map { $0 <= Self.stage(treePoints) } ?? false),
                         equipped: outfit[item.slot] == item.id,
                         price: Self.shopItems.first { $0.id == item.id }?.price, unlockStage: Self.formStages[item.id])
            },
            bestForm: Self.formStages.filter { $0.value <= Self.stage(treePoints) }.max { $0.value < $1.value }?.key)
    }

    /// Ouvre un coffre ; renvoie le contenu et les graines gagnées (à créditer par l'appelant).
    func open(_ id: UUID) throws -> ChestContents {
        lock.lock(); defer { lock.unlock() }
        if let done = opened[id] { return done }
        guard let chest = chests.first(where: { $0.id == id }) else { throw BackendError.server(status: 400, code: "chest_not_found", message: "") }
        var seeds: Int
        var ticketCount: Int
        switch chest.tier {
        case .wood: seeds = Int.random(in: 10...20); ticketCount = 1
        case .silver: seeds = Int.random(in: 30...50); ticketCount = 2
        case .gold: seeds = Int.random(in: 60...80); ticketCount = 0
        }
        var fifty = 0, hint = 0
        for _ in 0 ..< ticketCount { if Bool.random() { fifty += 1 } else { hint += 1 } }
        tickets.fifty += fifty
        tickets.hint += hint
        var joker = false
        let wantJoker = chest.tier == .gold || Double.random(in: 0..<1) < (chest.tier == .silver ? 0.3 : 0.1)
        if wantJoker {
            if freezes < 2 { freezes += 1; joker = true } else { seeds += chest.tier == .wood ? 10 : chest.tier == .silver ? 20 : 40 }
        }
        var item: ChestItem?
        if chest.tier == .gold || (chest.tier == .silver && Double.random(in: 0..<1) < 0.25) {
            if let pick = Self.catalog.filter({ $0.rarity == "chest" && !owned.contains($0.id) }).randomElement() {
                owned.insert(pick.id)
                item = ChestItem(id: pick.id, name: pick.name, slot: pick.slot)
            } else {
                seeds += chest.tier == .silver ? 25 : 40
            }
        }
        let contents = ChestContents(tier: chest.tier, seeds: seeds,
                                     tickets: .init(fiftyFifty: fifty, hint: hint), joker: joker, item: item, balance: nil)
        opened[id] = contents
        chests.removeAll { $0.id == id }
        return contents
    }

    /// Nourrit l'arbre (graines déjà vérifiées par l'appelant) ; renvoie le résultat sans le solde.
    func feed(_ amount: Int, key: UUID) throws -> (fed: Int, chests: Int, items: [ChestItem], tree: TreeState) {
        lock.lock(); defer { lock.unlock() }
        guard treePoints < Self.maxPoints else { throw BackendError.server(status: 400, code: "tree_complete", message: "") }
        guard !fedKeys.contains(key) else { return (0, 0, [], Self.tree(treePoints)) }
        fedKeys.insert(key)
        let fed = min(amount, Self.maxPoints - treePoints)
        treePoints += fed
        var newChests = 0
        let stage = Self.stage(treePoints)
        if stage > stageRewarded {
            for _ in stageRewarded + 1 ... stage { chests.append(ChestRef(id: UUID(), tier: .gold, source: "tree")); newChests += 1 }
            stageRewarded = stage
        }
        var items: [ChestItem] = []
        let fruits = Self.fruits(treePoints)
        let rare = Self.catalog.filter { $0.rarity == "fruit" }
        while fruitsRewarded < fruits {
            let pick = rare[fruitsRewarded]
            owned.insert(pick.id)
            items.append(ChestItem(id: pick.id, name: pick.name, slot: pick.slot))
            fruitsRewarded += 1
        }
        return (fed, newChests, items, Self.tree(treePoints))
    }

    /// Vitrine du jour : 3 articles, le premier à −30 %.
    func shop(seeds: Int) -> ShopOverview {
        lock.lock(); defer { lock.unlock() }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let pool = Self.shopItems.filter { !owned.contains($0.id) }
        let picks = (0 ..< min(3, pool.count)).map { pool[(day * 7 + $0 * 5) % pool.count] }
        return ShopOverview(featured: picks.enumerated().map { i, item in
            .init(id: item.id, price: i == 0 ? Int((Double(item.price) * 0.7 / 10).rounded()) * 10 : item.price, original: item.price)
        }, resetsAt: Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400), balance: seeds)
    }

    /// Achète un article (le prix est vérifié par l'appelant) ; false s'il était déjà possédé.
    func buy(_ item: String) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard Self.shopItems.contains(where: { $0.id == item }) else {
            throw BackendError.server(status: 400, code: "item_not_for_sale", message: "")
        }
        return owned.insert(item).inserted
    }

    func equip(slot: String, item: String?) throws -> [String: String] {
        lock.lock(); defer { lock.unlock() }
        if let item {
            let unlockedForm = Self.formStages[item].map { $0 <= Self.stage(treePoints) } ?? false
            guard owned.contains(item) || unlockedForm, Self.catalog.contains(where: { $0.id == item && $0.slot == slot }) else {
                throw BackendError.server(status: 400, code: "item_not_owned", message: "")
            }
            outfit[slot] = item
        } else {
            outfit[slot] = nil
        }
        return outfit
    }

    /// Utilise un ticket d'aide s'il y en a un.
    func useTicket(_ kind: HelpKind) -> (used: Bool, left: Int) {
        lock.lock(); defer { lock.unlock() }
        switch kind {
        case .fiftyFifty:
            guard tickets.fifty > 0 else { return (false, 0) }
            tickets.fifty -= 1
            return (true, tickets.fifty)
        case .hint, .secondChance:
            guard tickets.hint > 0 else { return (false, 0) }
            tickets.hint -= 1
            return (true, tickets.hint)
        case .context:
            return (false, 0)
        }
    }
}
#endif
