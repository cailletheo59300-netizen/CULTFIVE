import Foundation

/// Pièces gagnées en jouant. Repères : une partie moyenne (manche 6 à 8, ~200 points) rapporte ~25 pièces ;
/// une apparence à 500 pièces demande donc ~20 parties, ou un pack de pièces.
public enum Economy {
    /// Pièces d'une partie (doublées par la pub « Pièces ×2 »).
    public static func coins(for result: GameResult) -> Int {
        max(1, result.score / 8)
    }

    /// Cadeau de la série du défi du jour : 20 pièces par jour d'affilée, 140 au plus (7 jours et plus).
    public static func streakReward(streak: Int) -> Int {
        20 * min(max(streak, 1), 7)
    }

    /// Essais en plus au défi du jour, en regardant une pub, par jour.
    public static let maxExtraDailyAttempts = 2
}
