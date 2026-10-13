import Foundation

// Album de cartes et pass de saison (serveur 0042–0045). Les règles vivent sur le serveur ; l'app affiche et demande.

/// Vue d'ensemble de l'album : soldes, habillage possédé, cartes avec leurs états (`album_overview`).
public struct AlbumOverview: Codable, Hashable, Sendable {
    public struct Card: Codable, Hashable, Sendable {
        public let id: String
        public let copies: Int
        public let shiny: Bool
        public let prestige: Bool
        /// Chef-d'œuvre : les 3 étoiles de maîtrise (ou imposé en mode admin).
        public let masterpiece: Bool
        public let stars: Int
        /// États obtenus que le joueur a choisi de ne pas afficher : shiny · prestige · masterpiece.
        public let hidden: [String]
        public let frame: String?
        public let finish: String?
        public let title: String?

        public init(id: String, copies: Int = 1, shiny: Bool = false, prestige: Bool = false, masterpiece: Bool = false, stars: Int = 0,
                    hidden: [String] = [], frame: String? = nil, finish: String? = nil, title: String? = nil) {
            self.id = id
            self.copies = copies
            self.shiny = shiny
            self.prestige = prestige
            self.masterpiece = masterpiece
            self.stars = stars
            self.hidden = hidden
            self.frame = frame
            self.finish = finish
            self.title = title
        }
    }

    public let admin: Bool
    /// Le joueur peut passer en mode admin (administrateur du jeu).
    public let canAdmin: Bool
    public let neurones: Int
    public let tickets: Int
    public let tokens: Int
    public let goldPacks: Int
    /// La pochette dorée du Comptoir peut encore être achetée cette semaine.
    public let goldAvailable: Bool
    public let forcedRarity: String?
    public let back: String
    public let cover: String
    /// Habillage possédé : « cadre.vitrail », « dos.soleil »…
    public let cosmetics: [String]
    public let cards: [Card]

    public init(admin: Bool = false, canAdmin: Bool = false, neurones: Int = 0, tickets: Int = 0, tokens: Int = 0, goldPacks: Int = 0,
                goldAvailable: Bool = true, forcedRarity: String? = nil, back: String = "classique", cover: String = "classique",
                cosmetics: [String] = [], cards: [Card] = []) {
        self.admin = admin
        self.canAdmin = canAdmin
        self.neurones = neurones
        self.tickets = tickets
        self.tokens = tokens
        self.goldPacks = goldPacks
        self.goldAvailable = goldAvailable
        self.forcedRarity = forcedRarity
        self.back = back
        self.cover = cover
        self.cosmetics = cosmetics
        self.cards = cards
    }

    enum CodingKeys: String, CodingKey {
        case admin, neurones, tickets, tokens, back, cover, cosmetics, cards
        case canAdmin = "can_admin"
        case goldPacks = "gold_packs"
        case goldAvailable = "gold_available"
        case forcedRarity = "forced_rarity"
    }
}

/// Une carte reçue (pochette, coffre, fin de partie) et ce qu'elle a donné.
public struct AlbumPull: Codable, Hashable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        /// Nouvelle carte.
        case new
        /// Premier doublon : la carte devient brillante.
        case shiny
        /// Doublon d'une brillante : des neurones.
        case neurones
    }

    public let card: String
    public let rarity: String
    public let outcome: Outcome
    public let neurones: Int?

    public init(card: String, rarity: String, outcome: Outcome, neurones: Int? = nil) {
        self.card = card
        self.rarity = rarity
        self.outcome = outcome
        self.neurones = neurones
    }
}

/// Une pochette ouverte (`album_open_pack`).
public struct AlbumOpening: Codable, Hashable, Sendable {
    public let id: UUID
    public let series: String
    public let gold: Bool
    public let pulls: [AlbumPull]
    /// Solde de neurones après l'ouverture.
    public let balance: Int?

    public init(id: UUID, series: String, gold: Bool, pulls: [AlbumPull], balance: Int?) {
        self.id = id
        self.series = series
        self.gold = gold
        self.pulls = pulls
        self.balance = balance
    }
}

/// Façon de payer une pochette.
public enum AlbumPayment: String, Sendable {
    case neurones, ticket
    /// Pochette dorée du Comptoir (une par semaine).
    case gold
    /// Pochette dorée gagnée dans le pass.
    case goldPass = "gold_pass"
}

/// Outils du mode admin.
public enum AlbumAdminTool: String, Sendable {
    case ownAll = "own_all"
    case ownAllShiny = "own_all_shiny"
    case empty
    /// Rareté imposée à la prochaine pochette (argument : common · rare · epic · legend).
    case force
}

/// Pass de saison, piste gratuite (`season_overview`).
public struct SeasonOverview: Codable, Hashable, Sendable {
    public struct Season: Codable, Hashable, Sendable {
        public let id: Int
        public let name: String
        public let startsOn: String
        public let endsOn: String

        enum CodingKeys: String, CodingKey {
            case id, name
            case startsOn = "starts_on"
            case endsOn = "ends_on"
        }
    }

    public struct Reward: Codable, Hashable, Sendable {
        public let tier: Int
        /// chest · ticket · token · cosmetic · final
        public let kind: String
        public let label: String
        /// Icône 3D du pass (dossier AlbumData/pass).
        public let icon: String
        public let claimed: Bool

        public init(tier: Int, kind: String, label: String, icon: String, claimed: Bool) {
            self.tier = tier
            self.kind = kind
            self.label = label
            self.icon = icon
            self.claimed = claimed
        }
    }

    public struct Extra: Codable, Hashable, Sendable {
        public let earned: Int
        public let claimed: Int
    }

    public struct Rules: Codable, Hashable, Sendable {
        public let day: Int
        public let dayBonus: Int
        public let week: Int
        public let weekBonus: Int
        public let mission: Int

        public init(day: Int = 15, dayBonus: Int = 15, week: Int = 40, weekBonus: Int = 60, mission: Int = 75) {
            self.day = day
            self.dayBonus = dayBonus
            self.week = week
            self.weekBonus = weekBonus
            self.mission = mission
        }

        enum CodingKeys: String, CodingKey {
            case day, week, mission
            case dayBonus = "day_bonus"
            case weekBonus = "week_bonus"
        }
    }

    public struct Mission: Codable, Hashable, Sendable {
        public let slot: Int
        public let label: String
        public let progress: Int
        public let target: Int
        public let done: Bool
    }

    /// nil : aucune saison en cours.
    public let season: Season?
    public let points: Int
    public let tier: Int
    public let tierPoints: Int
    public let tiers: Int
    public let rewards: [Reward]
    public let extraChests: Extra?
    public let pointsRules: Rules
    public let missions: [Mission]

    public init(season: Season? = nil, points: Int = 0, tier: Int = 0, tierPoints: Int = 150, tiers: Int = 30, rewards: [Reward] = [],
                extraChests: Extra? = nil, pointsRules: Rules = Rules(), missions: [Mission] = []) {
        self.season = season
        self.points = points
        self.tier = tier
        self.tierPoints = tierPoints
        self.tiers = tiers
        self.rewards = rewards
        self.extraChests = extraChests
        self.pointsRules = pointsRules
        self.missions = missions
    }

    enum CodingKeys: String, CodingKey {
        case season, points, tier, tiers, rewards, missions
        case tierPoints = "tier_points"
        case extraChests = "extra_chests"
        case pointsRules = "points_rules"
    }

    // Sans saison en cours, le serveur ne renvoie que `season: null`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        season = try c.decodeIfPresent(Season.self, forKey: .season)
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        tier = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 0
        tierPoints = try c.decodeIfPresent(Int.self, forKey: .tierPoints) ?? 150
        tiers = try c.decodeIfPresent(Int.self, forKey: .tiers) ?? 30
        rewards = try c.decodeIfPresent([Reward].self, forKey: .rewards) ?? []
        extraChests = try c.decodeIfPresent(Extra.self, forKey: .extraChests)
        pointsRules = try c.decodeIfPresent(Rules.self, forKey: .pointsRules) ?? Rules()
        missions = try c.decodeIfPresent([Mission].self, forKey: .missions) ?? []
    }
}
