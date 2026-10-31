import Foundation

/// Ce que l'on sait d'une grille à un moment donné : cases encore possibles et gemmes posées.
public struct Knowledge: Equatable, Sendable {
    /// Une gemme peut-elle encore aller sur cette case ?
    public var possible: [Bool]
    /// Gemme posée dans chaque zone.
    public var gems: [Int?]

    public init(layout: Layout) {
        possible = Array(repeating: true, count: layout.cellCount)
        gems = Array(repeating: nil, count: layout.size)
    }

    /// Cases encore possibles d'une zone.
    public func candidates(_ zone: Int, in layout: Layout) -> [Int] {
        layout.cellsOfZone[zone].filter { possible[$0] }
    }

    public var complete: Bool { gems.allSatisfy { $0 != nil } }

    /// Pose une gemme et retire toutes les cases qu'elle exclut.
    mutating func place(_ cell: Int, in layout: Layout) {
        gems[layout.zones[cell]] = cell
        for other in layout.blocked[cell] { possible[other] = false }
    }

    /// Une zone sans gemme n'a plus aucune case possible : impasse.
    func deadEnd(in layout: Layout) -> Bool {
        (0..<layout.size).contains { gems[$0] == nil && candidates($0, in: layout).isEmpty }
    }
}

/// Une déduction : une gemme à poser, ou des cases à barrer, avec sa raison (pour les indices).
public struct Deduction: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        /// La zone n'a plus qu'une case possible.
        case onlyCell(zone: Int)
        /// Cases exclues par la gemme de cette zone (elles la touchent, sont dans sa zone, ou pas alignées).
        case blockedByGem(zone: Int)
        /// Quelle que soit la case choisie dans cette zone, ces cases sont exclues.
        case sharedByZone(zone: Int)
        /// Une gemme sur cette case ne laisserait aucune place à cette zone.
        case wouldEmptyZone(zone: Int)
        /// Une gemme sur cette case mène, quelques déductions plus loin, à une zone sans place.
        case deadEnd
    }

    public let reason: Reason
    /// Gemme à poser.
    public let place: Int?
    /// Cases à barrer.
    public let cross: [Int]

    /// Difficulté de la déduction : 0 (évidente) à 4 (impasse à prévoir).
    public var level: Int {
        switch reason {
        case .onlyCell, .blockedByGem: 0
        case .sharedByZone: 2
        case .wouldEmptyZone: 3
        case .deadEnd: 4
        }
    }

    /// Points de difficulté ajoutés au score de la grille.
    var weight: Int {
        switch level {
        case 2: 1
        case 3: 2
        case 4: 6
        default: 0
        }
    }
}

/// Résolution « comme un joueur » : uniquement par déduction, jamais au hasard. Sert à garantir qu'une grille se
/// résout sans deviner, à mesurer sa difficulté, et à donner des indices qui expliquent le raisonnement.
public enum Solver {
    /// Déduction la plus simple possible à partir de `knowledge` (`nil` si aucune, dans la limite de `maxLevel`).
    public static func next(_ layout: Layout, _ knowledge: Knowledge, maxLevel: Int = 4) -> Deduction? {
        // 0. Cases encore marquées possibles alors qu'une gemme posée les exclut (indices seulement : le solveur
        //    les retire déjà en posant la gemme).
        for zone in 0..<layout.size {
            guard let gem = knowledge.gems[zone] else { continue }
            let cells = layout.blocked[gem].filter { knowledge.possible[$0] && knowledge.gems[layout.zones[$0]] == nil }
            if !cells.isEmpty { return Deduction(reason: .blockedByGem(zone: zone), place: nil, cross: cells) }
        }
        // 1. Une zone qui n'a plus qu'une case.
        for zone in 0..<layout.size where knowledge.gems[zone] == nil {
            let cells = knowledge.candidates(zone, in: layout)
            if cells.count == 1 { return Deduction(reason: .onlyCell(zone: zone), place: cells[0], cross: []) }
        }
        guard maxLevel >= 2 else { return nil }
        // 2. Cases exclues par toutes les possibilités d'une zone.
        for zone in 0..<layout.size where knowledge.gems[zone] == nil {
            let cells = knowledge.candidates(zone, in: layout)
            guard let first = cells.first else { continue }
            var shared = Array(repeating: false, count: layout.cellCount)
            for other in layout.blocked[first] { shared[other] = true }
            for cell in cells.dropFirst() {
                var mask = Array(repeating: false, count: layout.cellCount)
                for other in layout.blocked[cell] { mask[other] = true }
                for i in 0..<layout.cellCount where !mask[i] { shared[i] = false }
            }
            let cross = (0..<layout.cellCount).filter {
                shared[$0] && knowledge.possible[$0] && layout.zones[$0] != zone && knowledge.gems[layout.zones[$0]] == nil
            }
            if !cross.isEmpty { return Deduction(reason: .sharedByZone(zone: zone), place: nil, cross: cross) }
        }
        guard maxLevel >= 3 else { return nil }
        // 3. Une gemme ici ne laisserait aucune place à une autre zone.
        for cell in 0..<layout.cellCount where knowledge.possible[cell] && knowledge.gems[layout.zones[cell]] == nil {
            var mask = Array(repeating: false, count: layout.cellCount)
            for other in layout.blocked[cell] { mask[other] = true }
            for zone in 0..<layout.size where zone != layout.zones[cell] && knowledge.gems[zone] == nil {
                if knowledge.candidates(zone, in: layout).allSatisfy({ mask[$0] }) {
                    return Deduction(reason: .wouldEmptyZone(zone: zone), place: nil, cross: [cell])
                }
            }
        }
        guard maxLevel >= 4 else { return nil }
        // 4. Une gemme ici mène à une impasse (essai suivi des déductions 1 à 3).
        for cell in 0..<layout.cellCount where knowledge.possible[cell] && knowledge.gems[layout.zones[cell]] == nil {
            var trial = knowledge
            trial.place(cell, in: layout)
            if leadsToDeadEnd(layout, trial) {
                return Deduction(reason: .deadEnd, place: nil, cross: [cell])
            }
        }
        return nil
    }

    private static func leadsToDeadEnd(_ layout: Layout, _ start: Knowledge) -> Bool {
        var knowledge = start
        for _ in 0..<(layout.cellCount * 2) {
            if knowledge.deadEnd(in: layout) { return true }
            if knowledge.complete { return false }
            guard let step = next(layout, knowledge, maxLevel: 3) else { return false }
            apply(step, to: &knowledge, in: layout)
        }
        return knowledge.deadEnd(in: layout)
    }

    public static func apply(_ deduction: Deduction, to knowledge: inout Knowledge, in layout: Layout) {
        if let cell = deduction.place { knowledge.place(cell, in: layout) }
        for cell in deduction.cross { knowledge.possible[cell] = false }
    }

    /// Résout la grille par déduction seule. Renvoie la solution trouvée (`nil` si on reste bloqué sans deviner)
    /// et le score de difficulté.
    public static func rate(_ layout: Layout) -> (solution: [Int]?, score: Int) {
        var knowledge = Knowledge(layout: layout)
        var score = 0
        for _ in 0..<(layout.cellCount * 4) {
            if knowledge.complete { return (knowledge.gems.compactMap { $0 }, score) }
            if knowledge.deadEnd(in: layout) { return (nil, score) }
            guard let step = next(layout, knowledge) else { return (nil, score) }
            score += step.weight
            apply(step, to: &knowledge, in: layout)
        }
        return (nil, score)
    }

    /// Toutes les solutions (au plus `limit`), par recherche exhaustive : sert à vérifier qu'il n'y en a qu'une.
    public static func solutions(size: Int, zones: [Int], limit: Int = 2) -> [[Int]] {
        var cells = Array(repeating: [Int](), count: size)
        for (cell, zone) in zones.enumerated() { cells[zone].append(cell) }
        var found: [[Int]] = []
        var gems: [Int] = []
        func search(_ zone: Int) {
            if found.count >= limit { return }
            if zone == size {
                found.append(gems)
                return
            }
            for cell in cells[zone] {
                if let previous = gems.last, previous / size != cell / size, previous % size != cell % size { continue }
                if gems.contains(where: { Layout.touch($0, cell, size: size) }) { continue }
                gems.append(cell)
                search(zone + 1)
                gems.removeLast()
            }
        }
        search(0)
        return found
    }
}
