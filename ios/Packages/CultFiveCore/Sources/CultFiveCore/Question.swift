import Foundation

public enum QuestionType: String, Codable, Sendable, CaseIterable {
    case mcq
    case trueFalse = "true_false"
    case numeric
    case ordering
    case pairs
    case mapPick = "map_pick"
    // Nouveaux types (serveur 0038) : marge annoncée avant de répondre, ou jeu de lettres, de mots ou d'images.
    case counter
    case timeline
    case gauge
    case proportion
    case letters
    case wordOrder = "word_order"
    case imageChoice = "image_choice"
    /// Type inconnu de cette version de l'app (ajouté plus tard côté serveur) : affiché comme indisponible, jamais un plantage.
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = QuestionType(rawValue: raw) ?? .unknown
    }

    /// Types où l'on vise un nombre avec une marge annoncée (correction « Pile ! / Juste, dans la marge / Presque… / Raté »).
    public var hasMargin: Bool {
        switch self {
        case .counter, .timeline, .gauge, .proportion: return true
        default: return false
        }
    }
}

/// Élément affichable d'une question (option, élément à classer, membre d'une paire, point sur la carte).
public struct Choice: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let text: String?
    public let lat: Double?
    public let lon: Double?
    /// Choix d'images : code pays (drapeau) ou adresse de l'image (tableau).
    public let flag: String?
    public let image: String?

    public init(id: String, text: String? = nil, lat: Double? = nil, lon: Double? = nil, flag: String? = nil, image: String? = nil) {
        self.id = id
        self.text = text
        self.lat = lat
        self.lon = lon
        self.flag = flag
        self.image = image
    }
}

/// Élément à l'échelle (jeu des proportions) : la référence a une taille connue, l'autre est à étirer.
public struct ScaleItem: Codable, Hashable, Sendable {
    public let label: String
    public let size: Double?
    public let icon: String?

    public init(label: String, size: Double? = nil, icon: String? = nil) {
        self.label = label
        self.size = size
        self.icon = icon
    }
}

/// Silhouette d'un pays : contours normalisés dans [0, 1] (x vers la droite, y vers le bas).
public struct CountryShape: Codable, Hashable, Sendable {
    public let paths: [[[Double]]]

    public init(paths: [[[Double]]]) {
        self.paths = paths
    }
}

public struct MapRegion: Codable, Hashable, Sendable {
    public let lat: Double
    public let lon: Double
    public let span: Double
}

/// Partie publique d'une question : ce que le joueur voit avant de répondre.
public struct QuestionPayload: Codable, Hashable, Sendable {
    public var options: [Choice]?
    public var items: [Choice]?
    public var left: [Choice]?
    public var right: [Choice]?
    public var region: MapRegion?
    public var unit: String?
    public var decimals: Int?
    public var allowNegative: Bool?
    public var keepOrder: Bool?
    /// Silhouette à reconnaître (QCM « Quel pays a cette forme ? »).
    public var shape: CountryShape?
    // Nouveaux types : bornes et marge annoncée (compteur, frise, jauge), échelle (proportions), tuiles (lettres, mots), images.
    public var min: Double?
    public var max: Double?
    public var start: Double?
    public var tolerance: Double?
    public var relTolerance: Double?
    public var reference: ScaleItem?
    public var item: ScaleItem?
    public var dimension: String?
    public var tiles: [Choice]?
    public var kind: String?

    enum CodingKeys: String, CodingKey {
        case options, items, left, right, region, unit, decimals, shape
        case min, max, start, tolerance, reference, item, dimension, tiles, kind
        case allowNegative = "allow_negative"
        case keepOrder = "keep_order"
        case relTolerance = "rel_tolerance"
    }

    public init(options: [Choice]? = nil, items: [Choice]? = nil, left: [Choice]? = nil, right: [Choice]? = nil,
                region: MapRegion? = nil, unit: String? = nil, decimals: Int? = nil, allowNegative: Bool? = nil,
                shape: CountryShape? = nil) {
        self.options = options
        self.items = items
        self.left = left
        self.right = right
        self.region = region
        self.unit = unit
        self.decimals = decimals
        self.allowNegative = allowNegative
        self.shape = shape
    }
}

/// Bonne réponse, telle que stockée côté serveur.
public struct CorrectAnswer: Codable, Hashable, Sendable {
    public var optionId: String?
    public var value: JSONValue?
    public var tolerance: Double?
    public var order: [String]?
    public var pairs: [String: String]?
    // Nouveaux types.
    public var relTolerance: Double?
    public var word: String?
    public var display: String?
    public var words: [String]?
    public var sentence: String?
    /// Choix d'images : nom de chaque option (pays, tableau), révélé après la réponse.
    public var labels: [String: String]?

    enum CodingKeys: String, CodingKey {
        case optionId = "option_id"
        case value, tolerance, order, pairs, word, display, words, sentence, labels
        case relTolerance = "rel_tolerance"
    }

    public init(optionId: String? = nil, value: JSONValue? = nil, tolerance: Double? = nil,
                order: [String]? = nil, pairs: [String: String]? = nil) {
        self.optionId = optionId
        self.value = value
        self.tolerance = tolerance
        self.order = order
        self.pairs = pairs
    }
}

/// Ce qui est révélé après la réponse : bonne réponse, explication, « À retenir ».
public struct Reveal: Codable, Hashable, Sendable {
    public let answer: CorrectAnswer
    public let explanation: String
    public let takeaway: String?
    public let source: String?
    public let factAsOf: String?

    enum CodingKeys: String, CodingKey {
        case answer, explanation, takeaway, source
        case factAsOf = "fact_as_of"
    }

    public init(answer: CorrectAnswer, explanation: String, takeaway: String? = nil, source: String? = nil, factAsOf: String? = nil) {
        self.answer = answer
        self.explanation = explanation
        self.takeaway = takeaway
        self.source = source
        self.factAsOf = factAsOf
    }
}

public struct Question: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let type: QuestionType
    public let domainId: String
    public let subdomainId: String
    public let prompt: String
    public let payload: QuestionPayload
    public let conceptId: String?
    public let position: Int?
    public let hasHint: Bool?
    public let hasContext: Bool?
    /// Présent dans les packs Jouer et la revue du Daily ; absent pendant le Daily.
    public let reveal: Reveal?
    /// Packs Jouer : difficulté absolue (0–100) et chances de réussite estimées pour ce joueur (0–1).
    public var difficulty: Double?
    public var expected: Double?

    enum CodingKeys: String, CodingKey {
        case id, type, prompt, payload, position, answer, explanation, difficulty, expected
        case domainId = "domain_id"
        case subdomainId = "subdomain_id"
        case conceptId = "concept_id"
        case hasHint = "has_hint"
        case hasContext = "has_context"
    }

    public init(id: UUID, type: QuestionType, domainId: String, subdomainId: String, prompt: String,
                payload: QuestionPayload, conceptId: String? = nil, position: Int? = nil,
                hasHint: Bool? = nil, hasContext: Bool? = nil, reveal: Reveal? = nil,
                difficulty: Double? = nil, expected: Double? = nil) {
        self.id = id
        self.type = type
        self.domainId = domainId
        self.subdomainId = subdomainId
        self.prompt = prompt
        self.payload = payload
        self.conceptId = conceptId
        self.position = position
        self.hasHint = hasHint
        self.hasContext = hasContext
        self.reveal = reveal
        self.difficulty = difficulty
        self.expected = expected
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        type = try c.decode(QuestionType.self, forKey: .type)
        domainId = try c.decode(String.self, forKey: .domainId)
        subdomainId = try c.decode(String.self, forKey: .subdomainId)
        prompt = try c.decode(String.self, forKey: .prompt)
        payload = try c.decodeIfPresent(QuestionPayload.self, forKey: .payload) ?? QuestionPayload()
        conceptId = try c.decodeIfPresent(String.self, forKey: .conceptId)
        position = try c.decodeIfPresent(Int.self, forKey: .position)
        hasHint = try c.decodeIfPresent(Bool.self, forKey: .hasHint)
        hasContext = try c.decodeIfPresent(Bool.self, forKey: .hasContext)
        difficulty = try c.decodeIfPresent(Double.self, forKey: .difficulty)
        expected = try c.decodeIfPresent(Double.self, forKey: .expected)
        // La révélation est « à plat » dans le même objet JSON.
        if c.contains(.answer), c.contains(.explanation) {
            reveal = try Reveal(from: decoder)
        } else {
            reveal = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(domainId, forKey: .domainId)
        try c.encode(subdomainId, forKey: .subdomainId)
        try c.encode(prompt, forKey: .prompt)
        try c.encode(payload, forKey: .payload)
        try c.encodeIfPresent(conceptId, forKey: .conceptId)
        try c.encodeIfPresent(position, forKey: .position)
        try c.encodeIfPresent(hasHint, forKey: .hasHint)
        try c.encodeIfPresent(hasContext, forKey: .hasContext)
        try c.encodeIfPresent(difficulty, forKey: .difficulty)
        try c.encodeIfPresent(expected, forKey: .expected)
        try reveal?.encode(to: encoder)
    }
}

/// Réponse donnée par le joueur. Encodée au format attendu par le serveur.
public enum GivenAnswer: Hashable, Sendable {
    case option(String)
    case bool(Bool)
    case number(Decimal)
    case order([String])
    case pairs([String: String])
    /// Lettres mélangées : le mot formé.
    case text(String)
    /// Mots dans l'ordre : le texte de chaque tuile, dans l'ordre choisi.
    case words([String])

    public var json: JSONValue {
        switch self {
        case .option(let id): return .object(["option_id": .string(id)])
        case .bool(let value): return .object(["value": .bool(value)])
        case .number(let value): return .object(["value": .number(NSDecimalNumber(decimal: value).doubleValue)])
        case .order(let ids): return .object(["order": .array(ids.map(JSONValue.string))])
        case .pairs(let map): return .object(["pairs": .object(map.mapValues(JSONValue.string))])
        case .text(let text): return .object(["text": .string(text)])
        case .words(let words): return .object(["words": .array(words.map(JSONValue.string))])
        }
    }
}

extension GivenAnswer: Codable {
    public init(from decoder: Decoder) throws {
        let json = try JSONValue(from: decoder)
        if let id = json["option_id"]?.stringValue {
            self = .option(id)
        } else if let value = json["value"]?.boolValue {
            self = .bool(value)
        } else if let value = json["value"]?.doubleValue {
            self = .number(Decimal(value))
        } else if case .array(let items)? = json["order"] {
            self = .order(items.compactMap(\.stringValue))
        } else if case .object(let map)? = json["pairs"] {
            self = .pairs(map.compactMapValues(\.stringValue))
        } else if let text = json["text"]?.stringValue {
            self = .text(text)
        } else if case .array(let items)? = json["words"] {
            self = .words(items.compactMap(\.stringValue))
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Réponse inconnue"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        try json.encode(to: encoder)
    }
}
