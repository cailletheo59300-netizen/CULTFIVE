import SwiftUI
import CultFiveCore

// Collection de l'album et pass de saison, lus et modifiés sur le serveur (album_*, season_*, migrations 0042–0045).
// Règles : D-046 (neurones, pochettes, fabrication), D-048 (états, doublons, habillage), D-049 (pass).

/// Ce que le joueur possède d'une carte.
struct OwnedCard: Codable, Equatable {
    var copies = 1
    var shiny = false
    var prestige = false
    /// Maîtrisée au quiz (3 étoiles) : jamais achetable.
    var masterpiece = false
    /// Étoiles de maîtrise au quiz (0 à 3, sur les 60 derniers jours).
    var stars = 0
    var frame: String?
    var finish: String?
    var title: String?
    /// États obtenus mais que le joueur a choisi de ne pas afficher (ils restent gagnés).
    var hidden: Set<CardStateKind>?

    func isHidden(_ kind: CardStateKind) -> Bool { hidden?.contains(kind) ?? false }

    /// Ce qui s'affiche : les états obtenus, moins ceux que le joueur a masqués.
    var shown: OwnedCard {
        var copy = self
        if isHidden(.shiny) { copy.shiny = false }
        if isHidden(.prestige) { copy.prestige = false }
        if isHidden(.masterpiece) { copy.masterpiece = false }
        return copy
    }

    func has(_ kind: CardStateKind) -> Bool {
        switch kind {
        case .shiny: return shiny
        case .prestige: return prestige
        case .masterpiece: return masterpiece
        }
    }
}

/// Les états d'une carte qu'on peut obtenir, masquer ou (en admin) poser librement.
enum CardStateKind: String, Codable, CaseIterable {
    case shiny, prestige, masterpiece
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
        Item(id: "flocons", name: "Flocons", icon: "cadre_flocons"),
        Item(id: "aurore", name: "Aurore", icon: "cadre_aurore"),
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
        Item(id: "polaire", name: "Esprit polaire", icon: "titre_polaire"),
        Item(id: "flocon", name: "Flocon savant", icon: "titre_flocon"),
    ]
    static let backs = [
        Item(id: "classique", name: "Classique", icon: "classique"),
        Item(id: "soleil", name: "Soleil", icon: "dos_soleil"),
        Item(id: "nuit", name: "Nuit étoilée", icon: "dos_nuit"),
        Item(id: "domaines", name: "Les 12 domaines", icon: "dos_domaines"),
        Item(id: "or", name: "Feuille d'or", icon: "dos_or"),
        Item(id: "citrouille", name: "Citrouille", icon: "citrouille"),
        Item(id: "hiver", name: "Nuit d'hiver", icon: "dos_hiver"),
        Item(id: "aurore", name: "Aurore boréale", icon: "dos_aurore"),
    ]
    static let covers = [
        Item(id: "classique", name: "Brainlix", icon: "marque"),
        Item(id: "automne", name: "Automne", icon: "couv_automne"),
        Item(id: "grimoire", name: "Grimoire", icon: "couv_grimoire"),
        Item(id: "or", name: "Feuille d'or", icon: "couv_or"),
        Item(id: "hiver", name: "Hiver", icon: "couv_hiver"),
    ]
}

/// Une carte sortie d'une pochette ou d'un coffret, et ce qu'elle a donné.
struct Pull: Identifiable, Hashable {
    enum Outcome: Hashable { case new, shiny, neurones(Int), nothing }

    /// Carte reçue du serveur (pochette, coffre, fin de partie). nil si la carte manque au catalogue de l'app.
    init?(_ pull: AlbumPull) {
        guard let card = AlbumCatalog.shared.byServerId[pull.card] else { return nil }
        self.card = card
        switch pull.outcome {
        case .new: outcome = .new
        case .shiny: outcome = .shiny
        case .neurones: outcome = .neurones(pull.neurones ?? 0)
        case .nothing: outcome = .nothing
        }
    }

    init(card: AlbumCard, outcome: Outcome) {
        self.card = card
        self.outcome = outcome
    }
    let id = UUID()
    let card: AlbumCard
    let outcome: Outcome
}

@MainActor
@Observable
final class AlbumStore {
    static let packPrice = 150
    static let goldPackPrice = 900
    /// Tickets de pochette : 5 au plus ; au-delà, chaque ticket gagné devient 30 neurones (serveur 0057).
    static let ticketMax = 5
    static let ticketOverflow = 30
    /// Réserves « illimitées » du mode admin (affichées ∞).
    static let unlimited = 999_999

    /// La même collection pour toute l'app (album, Comptoir, pass, défis de l'écran du 5).
    static let shared = AlbumStore()

    private var service: GameService?
    private let catalog = AlbumCatalog.shared

    private(set) var owned: [String: OwnedCard] = [:]
    private(set) var neurones = 0
    private(set) var tickets = 0
    /// Jetons Prestige à poser.
    private(set) var tokens = 0
    /// Pochettes dorées à ouvrir (gagnées dans le pass).
    private(set) var goldPacks = 0
    /// Pochette dorée du Comptoir déjà achetée cette semaine.
    private(set) var goldBought = false
    /// Habillage possédé : « cadre.vitrail », « dos.soleil », « titre.curieux »… (dos et couverture classiques pour tous).
    private(set) var unlocked: Set<String> = AlbumStore.always
    private(set) var back = "classique"
    private(set) var cover = "classique"
    /// Mode admin (administrateurs seulement) : une collection à part, tout illimité.
    private(set) var admin = false
    private(set) var canAdmin = false
    /// Admin : rareté imposée à la prochaine pochette (pour voir chaque animation).
    private(set) var forcedRarity: CardRarity?
    /// Pass de saison (piste gratuite et Pass+).
    private(set) var season = SeasonOverview()
    /// Coffrets de catégorie à ouvrir (Pass+).
    private(set) var coffrets: [AlbumOverview.Coffret] = []
    /// Album lu au moins une fois.
    private(set) var loaded = false
    /// Une action est en cours (ouverture, fabrication…) : les boutons attendent.
    private(set) var busy = false
    /// Dernière erreur à montrer au joueur.
    var errorMessage: String?

    private static let always: Set<String> = ["dos.classique", "couv.classique"]

    /// À appeler une fois au lancement, avec le service de l'app.
    func configure(_ service: GameService, cached: Bool = false) {
        self.service = service
        // Dernier album et dernier pass connus : affichés tout de suite, même sans réseau, puis mis à jour.
        guard cached else { return }
        useCache = true
        if let album: AlbumOverview = cache.load("album") { apply(album) }
        if let pass: SeasonOverview = cache.load("season") { season = pass }
    }

    private let cache = DiskCache()
    private var useCache = false

    /// Déconnexion : on oublie la collection du compte précédent.
    func clear() {
        apply(AlbumOverview())
        loaded = false
        season = SeasonOverview()
        errorMessage = nil
        cache.remove("album")
        cache.remove("season")
    }

    // MARK: - Lecture

    func state(_ card: AlbumCard) -> OwnedCard? { owned[card.id] }
    func isOwned(_ card: AlbumCard) -> Bool { owned[card.id] != nil }
    func ownedCount(_ cards: [AlbumCard]) -> Int { cards.filter { owned[$0.id] != nil }.count }
    var totalOwned: Int { owned.count }
    func has(_ unlock: String) -> Bool { unlocked.contains(unlock) }

    var tier: Int { season.tier }
    var points: Int { season.points }
    var tiers: Int { season.tiers }
    var tierPoints: Int { season.tierPoints }
    var rules: SeasonOverview.Rules { season.pointsRules }

    /// Relit l'album et le pass sur le serveur.
    func refresh() async {
        guard let service else { return }
        async let album = service.albumOverview()
        async let pass = service.seasonOverview()
        do {
            let fresh = try await album
            apply(fresh)
            season = try await pass
            if useCache {
                cache.save(fresh, key: "album")
                cache.save(season, key: "season")
            }
        } catch {
            // Album déjà affiché (cache ou chargement précédent) et réseau coupé : le bandeau « Connexion difficile »
            // suffit, pas d'alerte en plus.
            if loaded, case .offline? = error as? BackendError { return }
            report(error)
        }
    }

    private func apply(_ overview: AlbumOverview) {
        var cards: [String: OwnedCard] = [:]
        for c in overview.cards {
            guard let card = catalog.byServerId[c.id] else { continue }
            let hidden = Set(c.hidden.compactMap(CardStateKind.init(rawValue:)))
            cards[card.id] = OwnedCard(copies: c.copies, shiny: c.shiny, prestige: c.prestige, masterpiece: c.masterpiece, stars: c.stars,
                                       frame: c.frame, finish: c.finish, title: c.title, hidden: hidden.isEmpty ? nil : hidden)
        }
        owned = cards
        neurones = overview.neurones
        tickets = overview.tickets
        tokens = overview.tokens
        goldPacks = overview.goldPacks
        goldBought = !overview.goldAvailable
        unlocked = Self.always.union(overview.cosmetics)
        back = overview.back
        cover = overview.cover
        admin = overview.admin
        canAdmin = overview.canAdmin
        forcedRarity = overview.forcedRarity.flatMap(CardRarity.init(rawValue:))
        coffrets = overview.coffrets
        loaded = true
    }

    private func report(_ error: Error) {
        errorMessage = error.userMessage("Le serveur ne répond pas. Réessaie dans un instant.")
    }

    /// Lance une action serveur, une à la fois ; en cas d'échec, montre l'erreur et relit l'album.
    private func run<T>(_ action: (GameService) async throws -> T) async -> T? {
        guard let service, !busy else { return nil }
        busy = true
        defer { busy = false }
        do {
            return try await action(service)
        } catch {
            report(error)
            await refresh()
            return nil
        }
    }

    // MARK: - Pochettes

    /// Ouvre une pochette payée en neurones ou avec un ticket. Les cartes reçues sont ajoutées à l'album.
    func buyPack(_ series: PackSeries, useTicket: Bool) async -> [Pull]? {
        await open(series, pay: useTicket ? .ticket : .neurones)
    }

    /// Pochette dorée du Comptoir (une par semaine).
    func buyGoldPack() async -> [Pull]? { await open(catalog.series[0], pay: .gold) }

    /// Pochette dorée gagnée dans le pass.
    func openOwnedGoldPack() async -> [Pull]? { await open(catalog.series[0], pay: .goldPass) }

    private func open(_ series: PackSeries, pay: AlbumPayment) async -> [Pull]? {
        let clientId = UUID()
        guard let opening = await run({ try await $0.albumOpenPack(series: series.id, pay: pay, clientId: clientId) }) else { return nil }
        // Les plus rares à la fin, pour le suspense.
        let pulls = opening.pulls.compactMap(Pull.init).sorted { $0.card.rarity < $1.card.rarity }
        await refresh()
        return pulls
    }

    /// Fabriquer une carte manquante (case vide ou offre du jour).
    func craft(_ card: AlbumCard) async -> Bool {
        guard await run({ try await $0.albumCraft(card: card.serverId) }) != nil else { return false }
        await refresh()
        return true
    }

    // MARK: - États et habillage

    /// Pose un jeton Prestige : définitif.
    func applyPrestige(_ card: AlbumCard) async -> Bool {
        guard let left = await run({ try await $0.albumPrestige(card: card.serverId) }) else { return false }
        tokens = left
        change(card) { $0.prestige = true; $0.hidden?.remove(.prestige) }
        return true
    }

    /// Afficher ou masquer un état obtenu (il reste gagné ; le jeton Prestige n'est pas rendu).
    func setHidden(_ card: AlbumCard, _ kind: CardStateKind, _ hide: Bool) {
        change(card) { state in
            var set = state.hidden ?? []
            if hide { set.insert(kind) } else { set.remove(kind) }
            state.hidden = set.isEmpty ? nil : set
        }
        send { try await $0.albumSetHidden(card: card.serverId, state: kind.rawValue, hidden: hide) }
    }

    /// Admin : poser ou retirer un état librement, sans jeton ni condition.
    func adminSet(_ card: AlbumCard, _ kind: CardStateKind, _ on: Bool) {
        guard admin else { return }
        change(card) { state in
            switch kind {
            case .shiny: state.shiny = on
            case .prestige: state.prestige = on
            case .masterpiece: state.masterpiece = on
            }
            state.hidden?.remove(kind)
        }
        send { try await $0.albumAdminState(card: card.serverId, state: kind.rawValue, on: on) }
    }

    /// Habillage d'une carte : cadre, finition, titre.
    func dress(_ card: AlbumCard, _ change: (inout OwnedCard) -> Void) {
        self.change(card, change)
        guard let state = owned[card.id] else { return }
        send { try await $0.albumDress(card: card.serverId, frame: state.frame, finish: state.finish, title: state.title) }
    }

    /// Dos de toutes les cartes.
    func setBack(_ id: String) {
        back = id
        send { try await $0.albumSetLook(back: id, cover: nil) }
    }

    /// Couverture de l'album.
    func setCover(_ id: String) {
        cover = id
        send { try await $0.albumSetLook(back: nil, cover: id) }
    }

    private func change(_ card: AlbumCard, _ change: (inout OwnedCard) -> Void) {
        guard var state = owned[card.id] else { return }
        change(&state)
        owned[card.id] = state
    }

    /// Changement déjà affiché : on l'envoie au serveur ; s'il est refusé, on relit l'album.
    private func send(_ action: @escaping (GameService) async throws -> Void) {
        guard let service else { return }
        Task {
            do {
                try await action(service)
            } catch {
                report(error)
                await refresh()
            }
        }
    }

    // MARK: - Pass de saison

    /// Pass+ actif pour la saison en cours.
    var passPlusActive: Bool { season.passPlus?.active ?? false }

    /// Récupère la récompense d'un palier atteint, sur la piste gratuite ou Pass+.
    func claim(tier: Int, track: SeasonTrack = .free) async -> Bool {
        guard await run({ try await $0.seasonClaim(tier: tier, track: track) }) != nil else { return false }
        await refresh()
        return true
    }

    /// Rattrapage du Pass+ : tous les paliers atteints d'un coup. Renvoie ce qui a été récupéré.
    func claimAllPaid() async -> [SeasonClaimed] {
        guard let claimed = await run({ try await $0.seasonClaimAll(track: .paid) }) else { return [] }
        await refresh()
        return claimed
    }

    /// Ouvre un coffret de catégorie sur le domaine choisi. Les cartes reçues sont ajoutées à l'album.
    func openCoffret(_ coffret: AlbumOverview.Coffret, domain: String) async -> [Pull]? {
        guard let opening = await run({ try await $0.albumOpenCoffret(coffret.id, domain: domain) }) else { return nil }
        let pulls = opening.pulls.compactMap(Pull.init).sorted { $0.card.rarity < $1.card.rarity }
        await refresh()
        return pulls
    }

    /// Après le palier 30 : les coffres en bois gagnés. Renvoie le nombre récupéré.
    func claimExtra() async -> Int {
        guard let count = await run({ try await $0.seasonClaimExtra() }) else { return 0 }
        await refresh()
        return count
    }

    // MARK: - Mode admin

    /// Active ou quitte le mode admin. Chaque mode garde sa propre collection, sur le serveur.
    func setAdmin(_ on: Bool) async {
        guard canAdmin, on != admin, let overview = await run({ try await $0.albumAdmin(on) }) else { return }
        apply(overview)
    }

    /// Les 525 cartes dans l'album (brillantes si demandé).
    func ownAll(shiny: Bool) async { await tool(shiny ? .ownAllShiny : .ownAll) }

    /// Album vide, pour retester les ouvertures depuis zéro.
    func emptyAlbum() async { await tool(.empty) }

    /// Rareté imposée à la prochaine pochette.
    func force(_ rarity: CardRarity) async { await tool(.force, arg: rarity.rawValue) }

    private func tool(_ tool: AlbumAdminTool, arg: String? = nil) async {
        guard admin, let overview = await run({ try await $0.albumAdminTool(tool, arg: arg) }) else { return }
        apply(overview)
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
