import SwiftUI
import CultFiveCore

// Collection simulée de l'album (aperçu TestFlight) : tout reste sur le téléphone, rien ne part au serveur.
// Règles : D-046 (neurones, pochettes, fabrication), D-048 (états, doublons, habillage), D-049 (pass).

/// Ce que le joueur possède d'une carte.
struct OwnedCard: Codable, Equatable {
    var copies = 1
    var shiny = false
    var prestige = false
    /// Maîtrisée au quiz (3 étoiles) : jamais achetable. Simulé ici avec « Tout débloquer ».
    var masterpiece = false
    var frame: String?
    var finish: String?
    var title: String?
}

/// Habillage qu'on possède une fois et qu'on pose sur n'importe quelle carte.
enum Cosmetic {
    struct Item: Identifiable, Hashable {
        let id: String
        let name: String
        /// Icône 3D du pass (dossier AlbumData/pass).
        let icon: String
    }

    static let frames = [
        Item(id: "citrouille", name: "Citrouille", icon: "cadre_citrouille"),
        Item(id: "vitrail", name: "Vitrail", icon: "cadre_vitrail"),
        Item(id: "nuit", name: "Nuit étoilée", icon: "cadre_nuit"),
        Item(id: "toile", name: "Toile d'araignée", icon: "cadre_toile"),
        Item(id: "marbre", name: "Marbre", icon: "cadre_marbre"),
    ]
    static let finishes = [
        Item(id: "givre", name: "Givre", icon: "finition_givre"),
        Item(id: "or", name: "Poussière d'or", icon: "finition_or"),
        Item(id: "holo", name: "Holographique", icon: "finition_holo"),
    ]
    static let titles = [
        Item(id: "curieux", name: "Curieux", icon: "titre_curieux"),
        Item(id: "erudit", name: "Érudit", icon: "titre_erudit"),
        Item(id: "grand_curieux", name: "Grand curieux", icon: "titre_grand_curieux"),
        Item(id: "chasseur", name: "Chasseur de légendes", icon: "titre_chasseur"),
        Item(id: "musee", name: "Pièce de musée", icon: "titre_musee"),
    ]
    static let backs = [
        Item(id: "classique", name: "Classique", icon: "classique"),
        Item(id: "soleil", name: "Soleil", icon: "dos_soleil"),
        Item(id: "nuit", name: "Nuit étoilée", icon: "dos_nuit"),
        Item(id: "domaines", name: "Les 12 domaines", icon: "dos_domaines"),
        Item(id: "or", name: "Feuille d'or", icon: "dos_or"),
        Item(id: "citrouille", name: "Citrouille", icon: "citrouille"),
    ]
    static let covers = [
        Item(id: "classique", name: "Brainlix", icon: "marque"),
        Item(id: "automne", name: "Automne", icon: "couv_automne"),
        Item(id: "grimoire", name: "Grimoire", icon: "couv_grimoire"),
        Item(id: "or", name: "Feuille d'or", icon: "couv_or"),
    ]
}

/// Une carte sortie d'une pochette ou d'un coffret, et ce qu'elle a donné.
struct Pull: Identifiable, Hashable {
    enum Outcome: Hashable { case new, shiny, neurones(Int), nothing }
    let id = UUID()
    let card: AlbumCard
    let outcome: Outcome
}

@Observable
final class AlbumStore {
    static let packPrice = 150
    static let goldPackPrice = 900
    static let odds: [(CardRarity, Double)] = [(.legend, 1.5), (.epic, 6.5), (.rare, 22)]
    /// La 40e pochette sans légendaire en donne une (jamais affiché au joueur, D-046).
    static let pity = 40
    static let tierPoints = 150
    static let tiers = 30
    /// Points de saison : défi du jour, de la semaine, mission de saison, et bonus des trois (D-049).
    static let dayPoints = 15, dayBonus = 15, weekPoints = 40, weekBonus = 60, missionPoints = 75
    static let missions = ["Finis une page de l'album", "Ouvre 5 pochettes Histoire", "Fabrique une carte dans l'album", "Obtiens une carte brillante",
                           "Gagne 3 duels", "Fais 7 jours de suite", "Réussis un 5 du jour parfait", "Maîtrise 3 cartes (3 étoiles)",
                           "Complète 10 cartes Nature", "Joue dans 8 domaines différents", "Mets 3 cartes en vitrine", "Trouve une légendaire"]

    /// La même collection simulée pour toute l'app (album, Comptoir, pass, défis de l'écran du 5).
    static let shared = AlbumStore()

    private struct Saved: Codable {
        var owned: [String: OwnedCard]
        var neurones: Int
        var tickets: Int
        var tokens: Int
        var goldPacks: Int
        var goldBought: Bool
        var coffrets: Int
        var pity: Int
        var unlocked: Set<String>
        var back: String
        var cover: String
        var points: Int
        var passPlus: Bool
        var claimedFree: Set<Int>
        var claimedPaid: Set<Int>
        var packsOpened: Int
        var coffretsOpened: Int
        var credited: Set<String>?
        var missionsDone: Set<Int>?
    }

    private(set) var owned: [String: OwnedCard] = [:]
    var neurones = 1_450
    var tickets = 5
    /// Jetons Prestige à poser.
    var tokens = 1
    /// Pochettes dorées à ouvrir (pass, palier 30).
    var goldPacks = 0
    /// Pochette dorée du Comptoir déjà achetée cette semaine.
    var goldBought = false
    /// Coffrets de catégorie à choisir (Pass+).
    var coffrets = 0
    private var pity = 26
    /// Habillage débloqué : « cadre.vitrail », « dos.soleil », « titre.curieux »…
    var unlocked: Set<String> = ["dos.classique", "couv.classique"]
    var back = "classique"
    var cover = "classique"
    var points = 1_240
    var passPlus = false
    var claimedFree: Set<Int> = []
    var claimedPaid: Set<Int> = []
    var packsOpened = 0
    var coffretsOpened = 0
    /// Défis du serveur déjà comptés dans le pass (« jour:2026-10-12:1 »), pour ne les compter qu'une fois.
    private var credited: Set<String> = []
    /// Missions de saison remplies (simulées).
    var missionsDone: Set<Int> = []

    private let catalog = AlbumCatalog.shared
    private static let key = "album.preview.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            owned = saved.owned; neurones = saved.neurones; tickets = saved.tickets; tokens = saved.tokens
            goldPacks = saved.goldPacks; goldBought = saved.goldBought; coffrets = saved.coffrets; pity = saved.pity
            unlocked = saved.unlocked; back = saved.back; cover = saved.cover; points = saved.points; passPlus = saved.passPlus
            claimedFree = saved.claimedFree; claimedPaid = saved.claimedPaid; packsOpened = saved.packsOpened
            coffretsOpened = saved.coffretsOpened
            credited = saved.credited ?? []
            missionsDone = saved.missionsDone ?? []
        } else {
            seed()
        }
    }

    /// Collection de départ : environ un tiers des communes, quelques rares et épiques, aucune légendaire.
    private func seed() {
        var generator = SeededGenerator(seed: 7)
        owned = [:]
        for card in catalog.cards {
            let chance: Double
            switch card.rarity {
            case .common: chance = 0.35
            case .rare: chance = 0.18
            case .epic: chance = 0.06
            case .legend: chance = 0
            }
            if Double.random(in: 0..<1, using: &generator) < chance {
                owned[card.id] = OwnedCard(shiny: Double.random(in: 0..<1, using: &generator) < 0.12)
            }
        }
    }

    func save() {
        let saved = Saved(owned: owned, neurones: neurones, tickets: tickets, tokens: tokens, goldPacks: goldPacks, goldBought: goldBought,
                          coffrets: coffrets, pity: pity, unlocked: unlocked, back: back, cover: cover, points: points, passPlus: passPlus,
                          claimedFree: claimedFree, claimedPaid: claimedPaid, packsOpened: packsOpened,
                          coffretsOpened: coffretsOpened, credited: credited, missionsDone: missionsDone)
        if let data = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    // MARK: - Lecture

    func state(_ card: AlbumCard) -> OwnedCard? { owned[card.id] }
    func isOwned(_ card: AlbumCard) -> Bool { owned[card.id] != nil }
    func ownedCount(_ cards: [AlbumCard]) -> Int { cards.filter { owned[$0.id] != nil }.count }
    var totalOwned: Int { owned.count }
    func has(_ unlock: String) -> Bool { unlocked.contains(unlock) }

    // MARK: - Pochettes

    /// Ouvre une pochette de 5 cartes : au moins une rare, légendaire garantie au 40e essai, dorée = une légendaire.
    func openPack(_ series: PackSeries, gold: Bool = false) -> [Pull] {
        var rarities = (0..<5).map { _ in rollRarity() }
        if !rarities.contains(where: { $0 > .common }) { rarities[4] = .rare }
        if gold && !rarities.contains(.legend) { rarities.sort(); rarities[4] = .legend }
        pity += 1
        if rarities.contains(.legend) { pity = 0 } else if pity >= Self.pity { rarities.sort(); rarities[4] = .legend; pity = 0 }
        rarities.sort()
        var picked: Set<String> = []
        let pulls = rarities.map { rarity -> Pull in
            var pool = series.cards.filter { $0.rarity == rarity && !picked.contains($0.id) }
            if pool.isEmpty { pool = catalog.cards.filter { $0.rarity == rarity && !picked.contains($0.id) } }
            let card = pool.randomElement() ?? series.cards[0]
            picked.insert(card.id)
            return receive(card, fromCoffret: false)
        }
        packsOpened += 1
        save()
        return pulls
    }

    private func rollRarity() -> CardRarity {
        var roll = Double.random(in: 0..<100)
        for (rarity, odds) in Self.odds {
            if roll < odds { return rarity }
            roll -= odds
        }
        return .common
    }

    /// Une carte reçue : nouvelle ; sinon le premier doublon la rend brillante ; ensuite des neurones (pochette) ou rien (coffret).
    @discardableResult
    func receive(_ card: AlbumCard, fromCoffret: Bool) -> Pull {
        guard var state = owned[card.id] else {
            owned[card.id] = OwnedCard(shiny: fromCoffret)
            return Pull(card: card, outcome: .new)
        }
        state.copies += 1
        defer { owned[card.id] = state }
        if !state.shiny {
            state.shiny = true
            return Pull(card: card, outcome: .shiny)
        }
        if fromCoffret { return Pull(card: card, outcome: .nothing) }
        neurones += card.rarity.duplicateNeurones
        return Pull(card: card, outcome: .neurones(card.rarity.duplicateNeurones))
    }

    /// Ce que donnerait une carte de coffret (affiché avant l'achat).
    func coffretOutcome(_ card: AlbumCard) -> Pull.Outcome {
        guard let state = owned[card.id] else { return .new }
        return state.shiny ? .nothing : .shiny
    }

    /// Coffret de catégorie (Pass+) : les 3 cartes affichées avant, au plus une épique, pas de légendaire.
    func coffretCards(_ series: PackSeries) -> [AlbumCard] {
        // Graine stable (le hash de Swift change à chaque lancement) : le coffret montré reste le même.
        let base = series.id.unicodeScalars.reduce(UInt64(17)) { $0 &* 31 &+ UInt64($1.value) }
        var generator = SeededGenerator(seed: base &+ UInt64(coffretsOpened))
        let commons = series.cards.filter { $0.rarity == .common }.shuffled(using: &generator)
        let rares = series.cards.filter { $0.rarity == .rare }.shuffled(using: &generator)
        let epics = series.cards.filter { $0.rarity == .epic }.shuffled(using: &generator)
        return Array((epics.prefix(1) + rares.prefix(1) + commons.prefix(1)).prefix(3))
    }

    func openCoffret(_ series: PackSeries) -> [Pull] {
        guard coffrets > 0 else { return [] }
        let pulls = coffretCards(series).map { receive($0, fromCoffret: true) }
        coffrets -= 1
        coffretsOpened += 1
        save()
        return pulls
    }

    // MARK: - Achats en neurones (aucun argent réel ici)

    func buyPack(_ series: PackSeries, useTicket: Bool) -> [Pull]? {
        if useTicket {
            guard tickets > 0 else { return nil }
            tickets -= 1
        } else {
            guard neurones >= Self.packPrice else { return nil }
            neurones -= Self.packPrice
        }
        return openPack(series)
    }

    func buyGoldPack() -> [Pull]? {
        guard !goldBought, neurones >= Self.goldPackPrice, let series = catalog.series.first else { return nil }
        neurones -= Self.goldPackPrice
        goldBought = true
        return openPack(series, gold: true)
    }

    func openOwnedGoldPack() -> [Pull]? {
        guard goldPacks > 0, let series = catalog.series.first else { return nil }
        goldPacks -= 1
        return openPack(series, gold: true)
    }

    /// Fabriquer une carte manquante, depuis sa case vide.
    func craft(_ card: AlbumCard) -> Bool {
        guard owned[card.id] == nil, neurones >= card.rarity.craftCost else { return false }
        neurones -= card.rarity.craftCost
        owned[card.id] = OwnedCard()
        save()
        return true
    }

    // MARK: - États et habillage

    /// Pose un jeton Prestige : définitif.
    func applyPrestige(_ card: AlbumCard) -> Bool {
        guard tokens > 0, var state = owned[card.id], !state.prestige else { return false }
        tokens -= 1
        state.prestige = true
        owned[card.id] = state
        save()
        return true
    }

    func update(_ card: AlbumCard, _ change: (inout OwnedCard) -> Void) {
        guard var state = owned[card.id] else { return }
        change(&state)
        owned[card.id] = state
        save()
    }

    // MARK: - Pass de saison

    var tier: Int { min(points / Self.tierPoints, Self.tiers) }

    /// Compte dans le pass les vrais défis remplis (jour et semaine), une seule fois chacun, avec leurs neurones.
    func credit(_ overview: QuestsOverview) {
        var changed = false
        func take(_ key: String, points value: Int, neurones gain: Int) {
            guard !credited.contains(key) else { return }
            credited.insert(key)
            points = min(points + value, Self.tierPoints * Self.tiers)
            neurones += gain
            changed = true
        }
        for quest in overview.day.quests where quest.done {
            take("jour:\(overview.day.periodStart):\(quest.slot)", points: Self.dayPoints, neurones: quest.seeds)
        }
        if overview.day.bonus.done { take("jour:\(overview.day.periodStart):bonus", points: Self.dayBonus, neurones: overview.day.bonus.seeds) }
        for quest in overview.week.quests where quest.done {
            take("semaine:\(overview.week.periodStart):\(quest.slot)", points: Self.weekPoints, neurones: quest.seeds)
        }
        if overview.week.bonus.done { take("semaine:\(overview.week.periodStart):bonus", points: Self.weekBonus, neurones: overview.week.bonus.seeds) }
        if changed { save() }
    }

    /// Mission de saison remplie (aperçu : validée à la main).
    func completeMission(_ index: Int) {
        guard !missionsDone.contains(index) else { return }
        missionsDone.insert(index)
        addPoints(Self.missionPoints)
    }

    func addPoints(_ value: Int) {
        points = min(points + value, Self.tierPoints * Self.tiers)
        save()
    }

    func claim(_ reward: PassReward, tier: Int, paid: Bool) {
        guard tier <= self.tier, paid ? (passPlus && !claimedPaid.contains(tier)) : !claimedFree.contains(tier) else { return }
        if paid { claimedPaid.insert(tier) } else { claimedFree.insert(tier) }
        apply(reward)
        save()
    }

    private func apply(_ reward: PassReward) {
        switch reward.kind {
        case .chest(let value): neurones += value
        case .ticket: tickets += 1
        case .token: tokens += 1
        case .coffret: coffrets += 1
        case .unlock(let ids): unlocked.formUnion(ids)
        case .finalFree: unlocked.insert("dos.nuit"); goldPacks += 1
        case .finalPaid: unlocked.formUnion(["dos.or", "cadre.anime"])
        }
    }

    // MARK: - Outils de test

    /// Tout l'habillage, des jetons et des neurones pour essayer (bouton réservé à l'aperçu).
    func unlockEverything() {
        for item in Cosmetic.frames { unlocked.insert("cadre.\(item.id)") }
        for item in Cosmetic.finishes { unlocked.insert("finition.\(item.id)") }
        for item in Cosmetic.titles { unlocked.insert("titre.\(item.id)") }
        for item in Cosmetic.backs { unlocked.insert("dos.\(item.id)") }
        for item in Cosmetic.covers { unlocked.insert("couv.\(item.id)") }
        tokens += 10
        neurones += 5_000
        tickets += 10
        goldPacks += 1
        coffrets += 1
        save()
    }

    /// Marque quelques cartes comme maîtrisées (Chef-d'œuvre), pour voir l'effet.
    func simulateMastery() {
        for (id, state) in owned.prefix(12) where !state.masterpiece {
            var next = state
            next.masterpiece = true
            owned[id] = next
        }
        save()
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        neurones = 1_450; tickets = 5; tokens = 1; goldPacks = 0; goldBought = false; coffrets = 0; pity = 26
        unlocked = ["dos.classique", "couv.classique"]; back = "classique"; cover = "classique"
        points = 1_240; passPlus = false; claimedFree = []; claimedPaid = []; packsOpened = 0; coffretsOpened = 0
        credited = []; missionsDone = []
        seed()
        save()
    }
}

/// Générateur reproductible (collection de départ, coffrets).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
