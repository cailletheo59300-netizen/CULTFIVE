import Foundation

/// Place les orbes d'une manche. Ne dépend que de la graine de la partie et du numéro de manche, jamais de ce que fait
/// le joueur : au défi du jour, tout le monde a exactement les mêmes orbes.
public enum OrbPlan {
    public static func orbs(seed: UInt64, round: Int, tuning: Tuning = .standard) -> [Vec2] {
        var random = SeededRandom(seed: SeededRandom.mix(seed, UInt64(round)))
        let margin = tuning.orbMargin
        var orbs: [Vec2] = []
        var previous = tuning.center
        for index in 0..<tuning.orbsPerRound {
            let minimum = index == 0 ? tuning.orbMinFromCenter : tuning.orbMinSpacing
            var candidate = previous
            // Jusqu'à 40 essais pour respecter l'écart ; sinon on garde le plus éloigné trouvé.
            var best = (point: previous, distance: -1.0)
            for _ in 0..<40 {
                candidate = Vec2(random.between(margin, tuning.arena.x - margin),
                                 random.between(margin, tuning.arena.y - margin))
                let distance = candidate.distance(to: previous)
                if distance >= minimum {
                    best = (candidate, distance)
                    break
                }
                if distance > best.distance { best = (candidate, distance) }
            }
            orbs.append(best.point)
            previous = best.point
        }
        return orbs
    }
}
