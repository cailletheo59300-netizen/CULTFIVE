import SwiftUI
import UIKit

// Album (aperçu TestFlight) : le catalogue des 525 cartes et leurs images, rangés dans l'app (dossier AlbumData,
// généré par scripts/album/export-app.mjs). Aucune donnée ne vient du serveur.

enum CardRarity: String, CaseIterable, Comparable {
    case common, rare, epic, legend

    var label: String {
        switch self {
        case .common: return "Commune"
        case .rare: return "Rare"
        case .epic: return "Épique"
        case .legend: return "Légendaire"
        }
    }

    var color: Color {
        switch self {
        case .common: return Color(hex: 0x9A97AE)
        case .rare: return Color(hex: 0x2F6BFF)
        case .epic: return Color(hex: 0x9B5CFF)
        case .legend: return Color(hex: 0xE9A31B)
        }
    }

    /// Neurones donnés par un doublon d'une carte déjà brillante (D-046).
    var duplicateNeurones: Int {
        switch self {
        case .common: return 5
        case .rare: return 15
        case .epic: return 40
        case .legend: return 100
        }
    }

    /// Prix pour fabriquer la carte dans l'album (D-046).
    var craftCost: Int {
        switch self {
        case .common: return 50
        case .rare: return 150
        case .epic: return 400
        case .legend: return 1_200
        }
    }

    private var rank: Int { CardRarity.allCases.firstIndex(of: self) ?? 0 }
    static func < (a: CardRarity, b: CardRarity) -> Bool { a.rank < b.rank }
}

struct AlbumCard: Identifiable, Hashable {
    /// « <page>_<n> », aussi le nom des images.
    let id: String
    let pageKey: String
    let domain: String
    let n: Int
    let name: String
    let figure: String
    let unit: String
    let phrase: String
    let rarity: CardRarity
}

struct AlbumPage: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let title: String
    let domain: String
    let domainLabel: String
    let tone: Color
    let cards: [AlbumCard]

    /// Feuillets de 9 pochettes (une page de l'album = un ou plusieurs feuillets).
    var sheets: [[AlbumCard]] {
        stride(from: 0, to: cards.count, by: 9).map { Array(cards[$0..<min($0 + 9, cards.count)]) }
    }
}

struct AlbumDomain: Identifiable, Hashable {
    let id: String
    let label: String
}

/// Une série de pochettes : l'Encyclopédie (tout l'album) ou un domaine.
struct PackSeries: Identifiable, Hashable {
    let id: String
    let label: String
    let tone: Color
    let cards: [AlbumCard]
}

final class AlbumCatalog {
    static let shared = AlbumCatalog()

    let pages: [AlbumPage]
    let cards: [AlbumCard]
    let byId: [String: AlbumCard]
    /// Domaines dans l'ordre de l'album, avec leur libellé.
    let domains: [AlbumDomain]
    let series: [PackSeries]

    private init() {
        struct RawCard: Decodable { let n: Int; let name, figure, unit, phrase, rarity: String }
        struct RawPage: Decodable { let key, title, dom, domLabel, tone: String; let cards: [RawCard] }
        struct Raw: Decodable { let pages: [RawPage] }

        var pages: [AlbumPage] = []
        if let url = AlbumCatalog.folder?.appendingPathComponent("cards.json"),
           let data = try? Data(contentsOf: url),
           let raw = try? JSONDecoder().decode(Raw.self, from: data) {
            pages = raw.pages.map { p in
                AlbumPage(key: p.key, title: p.title, domain: p.dom, domainLabel: p.domLabel, tone: Color(hexString: p.tone),
                          cards: p.cards.map { c in
                              AlbumCard(id: "\(p.key)_\(c.n)", pageKey: p.key, domain: p.dom, n: c.n, name: c.name, figure: c.figure,
                                        unit: c.unit, phrase: c.phrase, rarity: CardRarity(rawValue: c.rarity) ?? .common)
                          })
            }
        }
        self.pages = pages
        cards = pages.flatMap(\.cards)
        byId = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        var seen: [String] = []
        var labels: [String: String] = [:]
        for page in pages where labels[page.domain] == nil {
            seen.append(page.domain)
            labels[page.domain] = page.domainLabel
        }
        domains = seen.map { AlbumDomain(id: $0, label: labels[$0] ?? $0) }
        series = [PackSeries(id: "encyclo", label: "Encyclopédie", tone: Color(hex: 0x6A4CFF), cards: cards)]
            + seen.map { dom in
                PackSeries(id: dom, label: labels[dom] ?? dom, tone: DomainPalette.color(dom), cards: pages.filter { $0.domain == dom }.flatMap(\.cards))
            }
    }

    func pages(of domain: String) -> [AlbumPage] { pages.filter { $0.domain == domain } }
    func page(_ key: String) -> AlbumPage? { pages.first { $0.key == key } }

    static let folder: URL? = Bundle.main.url(forResource: "AlbumData", withExtension: nil)
}

/// Images de l'album (WebP), gardées en cache.
enum AlbumImages {
    enum Kind: String { case faces, art, packs, backs, pass }

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 120
        return cache
    }()

    static func image(_ kind: Kind, _ name: String) -> UIImage? {
        let key = "\(kind.rawValue)/\(name)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let url = AlbumCatalog.folder?.appendingPathComponent("\(kind.rawValue)/\(name).webp"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Image de l'album, ou un aplat discret si elle manque.
struct AlbumImage: View {
    let kind: AlbumImages.Kind
    let name: String
    var template = false

    var body: some View {
        if let image = AlbumImages.image(kind, name) {
            Image(uiImage: image)
                .renderingMode(template ? .template : .original)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Color.hairline
        }
    }
}

extension Color {
    /// « #RRGGBB » (couleurs du catalogue de l'album).
    init(hexString: String) {
        self.init(hex: UInt32(hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x6E6B85)
    }
}
