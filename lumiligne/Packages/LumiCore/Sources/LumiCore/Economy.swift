import Foundation

/// Les indices sont la seule monnaie du jeu. Tous les chiffres sont ici.
public enum Economy {
    /// Indices offerts au premier lancement.
    public static let startingHints = 3
    /// Indices gagnés en finissant la grille du jour (la première fois de la journée).
    public static let dailyReward = 1
    /// Bonus de série : tous les 7 jours d'affilée.
    public static let streakBonus = 3
    public static let streakBonusEvery = 7
    /// Un indice offert tous les N niveaux finis.
    public static let levelRewardEvery = 5
    /// Indice gagné avec une pub récompensée, et combien de fois par jour au plus.
    public static let adHint = 1
    public static let maxAdHintsPerDay = 5
    /// Grille bonus finie.
    public static let bonusReward = 1
    /// Secondes ajoutées au temps de la grille du jour par indice utilisé (classement plus juste).
    public static let hintPenaltySeconds = 30

    /// Indices gagnés en finissant la grille du jour avec cette série.
    public static func dailyReward(streak: Int) -> Int {
        dailyReward + (streak > 0 && streak % streakBonusEvery == 0 ? streakBonus : 0)
    }

    /// Indices gagnés en finissant ce niveau pour la première fois.
    public static func levelReward(_ number: Int) -> Int {
        number % levelRewardEvery == 0 ? 1 : 0
    }

    /// Temps envoyé au classement du jour : temps réel + pénalité par indice.
    public static func dailyTime(seconds: Int, hintsUsed: Int) -> Int {
        max(1, seconds) + hintsUsed * hintPenaltySeconds
    }
}

/// Quand montrer une pub entre les grilles. Règles (toutes doivent être vraies) :
/// - le joueur n'a pas acheté « Sans pub » ;
/// - le premier jour après l'installation est sans pub entre les grilles ;
/// - au moins `gridsBetween` grilles finies depuis la dernière pub ;
/// - au moins `minInterval` secondes depuis la dernière pub ;
/// - pas de pub récompensée regardée pendant la grille qui vient de finir.
/// La pub passe quand le joueur quitte l'écran de victoire, jamais pendant une grille.
public struct AdPacing: Codable, Equatable, Sendable {
    public static let gridsBetween = 3
    public static let minInterval: TimeInterval = 120
    public static let freePeriod: TimeInterval = 24 * 3600

    public var gridsSinceInterstitial = 0
    public var lastInterstitial: Date?
    public var rewardedThisGrid = false

    public init() {}

    public mutating func gridStarted() {
        rewardedThisGrid = false
    }

    public mutating func gridFinished() {
        gridsSinceInterstitial += 1
    }

    public mutating func rewardedWatched() {
        rewardedThisGrid = true
    }

    public func interstitialDue(now: Date, firstLaunch: Date, noAds: Bool) -> Bool {
        guard !noAds, !rewardedThisGrid else { return false }
        guard now.timeIntervalSince(firstLaunch) >= Self.freePeriod else { return false }
        guard gridsSinceInterstitial >= Self.gridsBetween else { return false }
        if let last = lastInterstitial, now.timeIntervalSince(last) < Self.minInterval { return false }
        return true
    }

    public mutating func interstitialShown(now: Date) {
        gridsSinceInterstitial = 0
        lastInterstitial = now
    }
}
