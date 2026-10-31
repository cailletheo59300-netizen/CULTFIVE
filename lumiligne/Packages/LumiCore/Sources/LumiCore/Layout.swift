import Foundation

/// Une grille carrée découpée en zones de couleur, et les règles de Lumiligne :
/// 1. une gemme par zone ;
/// 2. les gemmes de deux zones qui se suivent (1 et 2, 2 et 3…) sont sur la même ligne ou la même colonne ;
/// 3. deux gemmes ne se touchent jamais, même en diagonale.
/// Il y a autant de zones que de lignes : une grille 6 × 6 a 6 zones, numérotées 0 à 5 dans le code (1 à 6 à l'écran).
/// Les cases sont numérotées ligne par ligne : case = ligne × taille + colonne.
public struct Layout: Equatable, Sendable {
    public let size: Int
    /// Zone de chaque case.
    public let zones: [Int]
    /// Cases de chaque zone, dans l'ordre de lecture.
    public let cellsOfZone: [[Int]]
    /// Cases exclues par une gemme posée sur chaque case (même zone, cases qui touchent, zones voisines non alignées).
    public let blocked: [[Int]]

    public init(size: Int, zones: [Int]) {
        precondition(zones.count == size * size)
        self.size = size
        self.zones = zones
        var cells = Array(repeating: [Int](), count: size)
        for (cell, zone) in zones.enumerated() { cells[zone].append(cell) }
        cellsOfZone = cells
        var blocked = Array(repeating: [Int](), count: size * size)
        for cell in 0..<(size * size) {
            for other in 0..<(size * size) where other != cell && Self.blocks(cell, other, size: size, zones: zones) {
                blocked[cell].append(other)
            }
        }
        self.blocked = blocked
    }

    public var cellCount: Int { size * size }

    public func row(_ cell: Int) -> Int { cell / size }
    public func column(_ cell: Int) -> Int { cell % size }

    /// Deux cases différentes qui se touchent (côté ou coin).
    public func touch(_ a: Int, _ b: Int) -> Bool { Self.touch(a, b, size: size) }

    /// Même ligne ou même colonne.
    public func aligned(_ a: Int, _ b: Int) -> Bool { row(a) == row(b) || column(a) == column(b) }

    /// Voisins par un côté.
    public func sideNeighbors(_ cell: Int) -> [Int] { Self.sideNeighbors(cell, size: size) }

    /// Case où l'on écrit le numéro de la zone (la première dans l'ordre de lecture).
    public func labelCell(of zone: Int) -> Int { cellsOfZone[zone][0] }

    /// Pourquoi deux gemmes ne peuvent pas être là en même temps (`nil` si elles le peuvent).
    public func conflict(_ a: Int, _ b: Int) -> Conflict? {
        guard a != b else { return nil }
        let za = zones[a], zb = zones[b]
        if za == zb { return .sameZone }
        if touch(a, b) { return .touching }
        if abs(za - zb) == 1, !aligned(a, b) { return .notAligned }
        return nil
    }

    static func touch(_ a: Int, _ b: Int, size: Int) -> Bool {
        a != b && abs(a / size - b / size) <= 1 && abs(a % size - b % size) <= 1
    }

    static func sideNeighbors(_ cell: Int, size: Int) -> [Int] {
        let r = cell / size, c = cell % size
        var result: [Int] = []
        if r > 0 { result.append(cell - size) }
        if r < size - 1 { result.append(cell + size) }
        if c > 0 { result.append(cell - 1) }
        if c < size - 1 { result.append(cell + 1) }
        return result
    }

    static func blocks(_ a: Int, _ b: Int, size: Int, zones: [Int]) -> Bool {
        let za = zones[a], zb = zones[b]
        if za == zb || touch(a, b, size: size) { return true }
        let aligned = a / size == b / size || a % size == b % size
        return abs(za - zb) == 1 && !aligned
    }
}

/// Règle enfreinte par deux gemmes.
public enum Conflict: Equatable, Sendable {
    /// Deux gemmes dans la même zone.
    case sameZone
    /// Deux gemmes qui se touchent.
    case touching
    /// Deux zones qui se suivent, mais gemmes ni sur la même ligne ni sur la même colonne.
    case notAligned
}

/// Niveau de difficulté d'une grille, mesuré par le solveur (voir `Solver.rate`).
public enum Difficulty: Int, Codable, CaseIterable, Sendable {
    case easy, medium, hard

    public var name: String {
        switch self {
        case .easy: "Facile"
        case .medium: "Moyen"
        case .hard: "Difficile"
        }
    }

    /// Bornes de score par taille : facile jusqu'à la 1re, moyen jusqu'à la 2e, difficile au-delà.
    /// Réglées pour qu'environ 1 grille sur 4 soit facile, 1 sur 2 moyenne, 1 sur 4 difficile.
    static func bounds(size: Int) -> (easy: Int, medium: Int) {
        switch size {
        case ...5: (1, 3)
        case 6: (2, 4)
        case 7: (3, 5)
        case 8: (3, 6)
        default: (4, 7)
        }
    }

    public static func of(score: Int, size: Int) -> Difficulty {
        let b = bounds(size: size)
        return score <= b.easy ? .easy : (score <= b.medium ? .medium : .hard)
    }
}

/// Une grille prête à jouer : découpage, solution (unique) et difficulté mesurée.
public struct Grid: Equatable, Sendable {
    public let layout: Layout
    /// Case de la gemme de chaque zone.
    public let solution: [Int]
    /// Score de difficulté (somme des déductions difficiles nécessaires).
    public let score: Int
    public var size: Int { layout.size }
    public var difficulty: Difficulty { Difficulty.of(score: score, size: size) }

    public init(layout: Layout, solution: [Int], score: Int) {
        self.layout = layout
        self.solution = solution
        self.score = score
    }
}
