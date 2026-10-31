import Foundation

/// Ce que le joueur a mis sur une case.
public enum Mark: Int, Codable, Sendable {
    case empty = 0, cross = 1, gem = 2
}

/// La partie en cours : la grille et les marques du joueur. Un appui fait défiler vide → croix → gemme → vide.
public struct Board: Equatable, Sendable {
    public let grid: Grid
    public private(set) var marks: [Mark]
    private var history: [[Mark]] = []
    private static let historyLimit = 300

    public init(grid: Grid, marks: [Mark]? = nil) {
        self.grid = grid
        if let marks, marks.count == grid.layout.cellCount {
            self.marks = marks
        } else {
            self.marks = Array(repeating: .empty, count: grid.layout.cellCount)
        }
    }

    public var layout: Layout { grid.layout }
    public var size: Int { grid.size }

    // MARK: Actions

    /// Appui sur une case. Renvoie la nouvelle marque.
    @discardableResult
    public mutating func tap(_ cell: Int) -> Mark {
        remember()
        let next: Mark = switch marks[cell] {
        case .empty: .cross
        case .cross: .gem
        case .gem: .empty
        }
        marks[cell] = next
        return next
    }

    /// Début d'un glissé du doigt (une seule étape d'annulation pour tout le glissé).
    public mutating func beginStroke() { remember() }

    /// Croix posée en glissant le doigt (seulement sur une case vide). Renvoie vrai si la case a changé.
    @discardableResult
    public mutating func strokeCross(_ cell: Int) -> Bool {
        guard marks[cell] == .empty else { return false }
        marks[cell] = .cross
        return true
    }

    public mutating func set(_ cell: Int, _ mark: Mark) {
        remember()
        marks[cell] = mark
    }

    public var canUndo: Bool { !history.isEmpty }

    public mutating func undo() {
        guard let previous = history.popLast() else { return }
        marks = previous
    }

    /// Efface tout (annulable).
    public mutating func clear() {
        guard marks.contains(where: { $0 != .empty }) else { return }
        remember()
        marks = Array(repeating: .empty, count: marks.count)
    }

    private mutating func remember() {
        history.append(marks)
        if history.count > Self.historyLimit { history.removeFirst() }
    }

    // MARK: État

    /// Cases où il y a une gemme.
    public var gemCells: [Int] { marks.indices.filter { marks[$0] == .gem } }

    /// Gemme de chaque zone (la première trouvée s'il y en a plusieurs).
    public var gems: [Int?] {
        var result = [Int?](repeating: nil, count: size)
        for cell in gemCells where result[layout.zones[cell]] == nil { result[layout.zones[cell]] = cell }
        return result
    }

    /// Règle enfreinte par la gemme de cette case, et avec quelle autre gemme.
    public func conflict(at cell: Int) -> (conflict: Conflict, other: Int)? {
        guard marks[cell] == .gem else { return nil }
        for other in gemCells {
            if let conflict = layout.conflict(cell, other) { return (conflict, other) }
        }
        return nil
    }

    /// Gemmes qui enfreignent une règle.
    public var conflicts: [Bool] {
        var result = Array(repeating: false, count: marks.count)
        let cells = gemCells
        for a in cells {
            for b in cells where a < b && layout.conflict(a, b) != nil {
                result[a] = true
                result[b] = true
            }
        }
        return result
    }

    /// Croix automatiques : cases vides exclues par une gemme posée (option « Croix automatiques »).
    public var autoCrosses: [Bool] {
        var result = Array(repeating: false, count: marks.count)
        for gem in gemCells {
            for cell in layout.blocked[gem] where marks[cell] == .empty { result[cell] = true }
        }
        return result
    }

    /// Rayon allumé entre la zone `k` et la zone `k + 1` (les deux gemmes posées, alignées, sans erreur).
    public var links: [Bool] {
        let gems = gems
        let bad = conflicts
        return (0..<max(0, size - 1)).map { k in
            guard let a = gems[k], let b = gems[k + 1], !bad[a], !bad[b] else { return false }
            return layout.aligned(a, b)
        }
    }

    /// Zone résolue : elle a une gemme, sans erreur.
    public var resolvedZones: [Bool] {
        let gems = gems
        let bad = conflicts
        return (0..<size).map { zone in
            guard let gem = gems[zone] else { return false }
            return !bad[gem]
        }
    }

    /// Toutes les gemmes posées, sans erreur (la solution est unique : c'est donc la bonne).
    public var isSolved: Bool {
        gemCells.count == size && gems.enumerated().allSatisfy { $0.element == grid.solution[$0.offset] }
    }

    // MARK: Indices

    /// Le prochain indice : d'abord une erreur à corriger, sinon une déduction expliquée.
    public func hint(autoCrosses useAutoCrosses: Bool) -> Hint? {
        if isSolved { return nil }
        let gemCells = gemCells
        // 1. Une règle enfreinte (gratuit : on montre l'erreur).
        for cell in gemCells {
            if let found = conflict(at: cell) {
                return Hint(kind: .conflict(found.conflict, zones: [layout.zones[cell], layout.zones[found.other]]),
                            cells: [cell, found.other])
            }
        }
        // 2. Une gemme qui n'est pas à sa place.
        for cell in gemCells where grid.solution[layout.zones[cell]] != cell {
            return Hint(kind: .wrongGem(zone: layout.zones[cell]), cells: [cell])
        }
        // 3. Une croix sur la case d'une gemme.
        for cell in grid.solution where marks[cell] == .cross {
            return Hint(kind: .wrongCross(zone: layout.zones[cell]), cells: [cell])
        }
        // 4. Une déduction à partir de ce que le joueur a posé.
        var knowledge = Knowledge(layout: layout)
        let automatic = useAutoCrosses ? autoCrosses : Array(repeating: false, count: marks.count)
        for cell in marks.indices where marks[cell] == .cross || automatic[cell] { knowledge.possible[cell] = false }
        for cell in gemCells { knowledge.gems[layout.zones[cell]] = cell }
        if let deduction = Solver.next(layout, knowledge) {
            let cells = deduction.place.map { [$0] } ?? deduction.cross
            return Hint(kind: .deduction(deduction), cells: cells)
        }
        // Filet de sécurité : on donne une gemme.
        let zone = (0..<size).first { gems[$0] == nil } ?? 0
        return Hint(kind: .deduction(Deduction(reason: .onlyCell(zone: zone), place: grid.solution[zone], cross: [])),
                    cells: [grid.solution[zone]])
    }

    /// Applique un indice sur la grille (annulable).
    public mutating func apply(_ hint: Hint) {
        switch hint.kind {
        case .conflict:
            break
        case .wrongGem, .wrongCross:
            set(hint.cells[0], .empty)
        case .deduction(let deduction):
            remember()
            if let cell = deduction.place {
                let zone = layout.zones[cell]
                for other in layout.cellsOfZone[zone] where marks[other] == .gem { marks[other] = .empty }
                marks[cell] = .gem
            }
            for cell in deduction.cross where marks[cell] == .empty { marks[cell] = .cross }
        }
    }
}

/// Un indice : ce qu'il montre, sur quelles cases, et son explication.
public struct Hint: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case conflict(Conflict, zones: [Int])
        case wrongGem(zone: Int)
        case wrongCross(zone: Int)
        case deduction(Deduction)
    }

    public let kind: Kind
    /// Cases à montrer.
    public let cells: [Int]

    /// Un indice qui montre seulement une erreur visible ne coûte rien.
    public var isFree: Bool {
        if case .conflict = kind { return true }
        return false
    }

    /// Explication en français (numéros de zone à partir de 1).
    public var message: String {
        switch kind {
        case .conflict(let conflict, let zones):
            return Self.explain(conflict, zones[0] + 1, zones[1] + 1)
        case .wrongGem(let zone):
            return "La gemme \(zone + 1) n'est pas à sa place : on la retire."
        case .wrongCross(let zone):
            return "Cette croix est en trop : la gemme \(zone + 1) va ici. On l'efface."
        case .deduction(let deduction):
            switch deduction.reason {
            case .onlyCell(let zone):
                return "Zone \(zone + 1) : il ne reste qu'une case possible. La gemme \(zone + 1) va ici."
            case .blockedByGem(let zone):
                return "La gemme \(zone + 1) exclut ces cases : elles la touchent, sont dans sa zone, ou ne sont pas alignées avec elle."
            case .sharedByZone(let zone):
                return "Où que tu mettes la gemme \(zone + 1), ces cases seront exclues. Barre-les."
            case .wouldEmptyZone(let zone):
                return "Une gemme ici ne laisserait plus aucune place à la zone \(zone + 1)."
            case .deadEnd:
                return "Une gemme ici mène à une impasse quelques coups plus loin."
            }
        }
    }

    public static func explain(_ conflict: Conflict, _ a: Int, _ b: Int) -> String {
        switch conflict {
        case .sameZone: "Il y a deux gemmes dans la zone \(a)."
        case .touching: "Les gemmes \(a) et \(b) se touchent."
        case .notAligned: "Les gemmes \(min(a, b)) et \(max(a, b)) doivent être sur la même ligne ou la même colonne."
        }
    }
}
