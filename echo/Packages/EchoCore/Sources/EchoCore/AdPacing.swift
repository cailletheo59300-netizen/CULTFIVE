import Foundation

/// Quand montrer une pub entre les parties. Règles (toutes doivent être vraies) :
/// - le joueur n'a pas acheté « Sans pub » ;
/// - le premier jour après l'installation est sans pub entre les parties (on ne fait pas fuir un nouveau joueur) ;
/// - au moins `gamesBetween` parties depuis la dernière pub ;
/// - au moins `minInterval` secondes depuis la dernière pub ;
/// - pas de pub récompensée regardée pendant la partie qui vient de finir.
/// La pub passe au moment où le joueur quitte l'écran de fin (Rejouer ou Accueil), jamais pendant une manche.
public struct AdPacing: Codable, Equatable, Sendable {
    public static let gamesBetween = 3
    public static let minInterval: TimeInterval = 90
    public static let freePeriod: TimeInterval = 24 * 3600

    public var gamesSinceInterstitial = 0
    public var lastInterstitial: Date?
    public var rewardedThisGame = false

    public init() {}

    public mutating func gameStarted() {
        rewardedThisGame = false
    }

    public mutating func gameFinished() {
        gamesSinceInterstitial += 1
    }

    public mutating func rewardedWatched() {
        rewardedThisGame = true
    }

    public func interstitialDue(now: Date, firstLaunch: Date, noAds: Bool) -> Bool {
        guard !noAds, !rewardedThisGame else { return false }
        guard now.timeIntervalSince(firstLaunch) >= Self.freePeriod else { return false }
        guard gamesSinceInterstitial >= Self.gamesBetween else { return false }
        if let last = lastInterstitial, now.timeIntervalSince(last) < Self.minInterval { return false }
        return true
    }

    public mutating func interstitialShown(now: Date) {
        gamesSinceInterstitial = 0
        lastInterstitial = now
    }
}
