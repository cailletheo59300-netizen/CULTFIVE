import Foundation

/// Fabrique les grilles. Aucune grille n'est faite à la main : tout part d'une graine.
/// 1. On tire une chaîne de gemmes qui respecte les règles (chaque gemme alignée avec la précédente, aucune ne touche).
/// 2. On fait grandir une zone autour de chaque gemme jusqu'à remplir la grille.
/// 3. Tant qu'une autre solution existe, on retouche les zones (une case passe dans une zone voisine) pour la casser.
/// 4. Le solveur résout la grille par déduction seule (sinon elle est jetée) et mesure sa difficulté.
/// 5. On recommence jusqu'à obtenir la difficulté demandée.
/// La même graine donne toujours la même grille, sur tous les iPhone.
public enum Generator {
    /// Taille minimale d'une zone (une zone d'une seule case serait trop facile).
    public static let minZoneSize = 2

    public static func grid(size: Int, difficulty: Difficulty, seed: UInt64) -> Grid {
        var random = SeededRandom(seed: seed)
        var best: Grid?
        var attempts = 0
        while true {
            attempts += 1
            guard let found = uniqueLayout(size: size, random: &random) else { continue }
            let layout = Layout(size: size, zones: found.zones)
            let rating = Solver.rate(layout)
            guard let solution = rating.solution, solution == found.chain else { continue }
            let grid = Grid(layout: layout, solution: solution, score: rating.score)
            if grid.difficulty == difficulty { return grid }
            if best == nil || distance(grid, difficulty) < distance(best!, difficulty) { best = grid }
            // Après beaucoup d'essais, on garde la grille la plus proche de la difficulté demandée.
            if attempts >= 200, let best { return best }
        }
    }

    private static func distance(_ grid: Grid, _ difficulty: Difficulty) -> Int {
        abs(grid.difficulty.rawValue - difficulty.rawValue)
    }

    /// Découpage à solution unique (la chaîne tirée au départ), ou `nil` si la retouche échoue.
    static func uniqueLayout(size n: Int, random: inout SeededRandom) -> (zones: [Int], chain: [Int])? {
        guard let chain = randomChain(size: n, random: &random) else { return nil }
        var zones = grow(size: n, chain: chain, random: &random)
        // Une zone d'une seule case : grille jetée.
        guard (0..<n).allSatisfy({ zone in zones.filter { $0 == zone }.count >= minZoneSize }) else { return nil }
        for _ in 0..<120 {
            let found = Solver.solutions(size: n, zones: zones, limit: 2)
            if found.count == 1 { return found[0] == chain ? (zones, chain) : nil }
            guard let other = found.first(where: { $0 != chain }) else { return nil }
            // Cases de l'autre solution qui ne sont pas dans la nôtre : on en déplace une dans une zone voisine.
            var cells = (0..<n).filter { other[$0] != chain[$0] }.map { other[$0] }
            random.shuffle(&cells)
            var moved = false
            search: for cell in cells {
                let old = zones[cell]
                guard zones.filter({ $0 == old }).count > minZoneSize else { continue }
                var targets = Layout.sideNeighbors(cell, size: n).map { zones[$0] }.filter { $0 != old }
                random.shuffle(&targets)
                for target in targets {
                    zones[cell] = target
                    if isConnected(zones, zone: old, size: n) {
                        moved = true
                        break search
                    }
                    zones[cell] = old
                }
            }
            if !moved { return nil }
        }
        return nil
    }

    /// Chaîne de `n` gemmes : chacune alignée avec la précédente, aucune ne touche les autres.
    static func randomChain(size n: Int, random: inout SeededRandom) -> [Int]? {
        for _ in 0..<200 {
            var chain = [random.int(n * n)]
            var ok = true
            for _ in 1..<n {
                let previous = chain[chain.count - 1]
                let options = (0..<(n * n)).filter { cell in
                    (cell / n == previous / n || cell % n == previous % n)
                        && !chain.contains { $0 == cell || Layout.touch($0, cell, size: n) }
                }
                guard !options.isEmpty else {
                    ok = false
                    break
                }
                chain.append(random.pick(options))
            }
            if ok { return chain }
        }
        return nil
    }

    /// Zones qui grandissent au hasard autour de chaque gemme, jusqu'à couvrir toute la grille.
    static func grow(size n: Int, chain: [Int], random: inout SeededRandom) -> [Int] {
        var zones = Array(repeating: -1, count: n * n)
        for (zone, cell) in chain.enumerated() { zones[cell] = zone }
        var left = n * n - n
        while left > 0 {
            let cell = random.int(n * n)
            guard zones[cell] == -1 else { continue }
            let around = Layout.sideNeighbors(cell, size: n).map { zones[$0] }.filter { $0 >= 0 }
            guard !around.isEmpty else { continue }
            zones[cell] = random.pick(around)
            left -= 1
        }
        return zones
    }

    static func isConnected(_ zones: [Int], zone: Int, size n: Int) -> Bool {
        let cells = zones.indices.filter { zones[$0] == zone }
        guard let start = cells.first else { return false }
        var seen = Array(repeating: false, count: zones.count)
        seen[start] = true
        var stack = [start]
        var count = 1
        while let cell = stack.popLast() {
            for next in Layout.sideNeighbors(cell, size: n) where zones[next] == zone && !seen[next] {
                seen[next] = true
                count += 1
                stack.append(next)
            }
        }
        return count == cells.count
    }
}
