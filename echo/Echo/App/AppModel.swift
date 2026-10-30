import Foundation
import SwiftUI
import EchoCore

/// Le cerveau de l'app : profil du joueur (gardé sur le téléphone), partie en cours, pubs, achats, Game Center.
@MainActor
@Observable
final class AppModel {
    enum Route: Equatable {
        case home
        case game
    }

    private(set) var profile: Profile
    private(set) var adPacing: AdPacing
    var route: Route = .home
    /// Partie affichée (route `.game`).
    private(set) var session: GameSession?

    let ads = AdsController()
    let store = StoreController()
    let gameCenter = GameCenter()
    let sound = SoundPlayer()
    let haptics = Haptics()

    private var defaults: UserDefaults { .standard }
    private static let profileKey = "echo.profile"
    private static let pacingKey = "echo.adPacing"

    /// Captures d'écran (workflow « Écho Captures », builds Debug seulement) : `-capture offers|trails|decors` ouvre la
    /// boutique sur cet onglet, avec un profil d'exemple, sans Game Center ni pubs. Toujours `nil` en Release.
    static let capture: String? = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-capture"), index + 1 < arguments.count { return arguments[index + 1] }
        #endif
        return nil
    }()

    init() {
        if Self.capture != nil {
            var demo = Profile()
            demo.coins = 1250
            demo.ownedSkins.formUnion(["trail.mint", "trail.coral", "decor.ocean"])
            demo.equippedTrail = "trail.coral"
            demo.gamesPlayed = 12
            demo.tutorialDone = true
            profile = demo
            adPacing = AdPacing()
            store.start(app: self)
            return
        }
        let decoder = JSONDecoder()
        profile = UserDefaults.standard.data(forKey: Self.profileKey).flatMap { try? decoder.decode(Profile.self, from: $0) } ?? Profile()
        adPacing = UserDefaults.standard.data(forKey: Self.pacingKey).flatMap { try? decoder.decode(AdPacing.self, from: $0) } ?? AdPacing()
        sound.enabled = profile.soundOn
        haptics.enabled = profile.hapticsOn
        store.start(app: self)
        gameCenter.authenticate()
        // Joueur qui revient : le consentement aux pubs a déjà été demandé, on démarre les pubs tout de suite.
        if profile.gamesPlayed > 0 { Task { await ads.start() } }
    }

    // MARK: Profil

    var today: String { DayKey.today() }
    var theme: GameTheme { GameTheme(profile: profile) }

    /// Modifie le profil et l'enregistre aussitôt.
    func update(_ change: (inout Profile) -> Void) {
        change(&profile)
        sound.enabled = profile.soundOn
        haptics.enabled = profile.hapticsOn
        save()
    }

    private func save() {
        guard Self.capture == nil else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(profile) { defaults.set(data, forKey: Self.profileKey) }
        if let data = try? encoder.encode(adPacing) { defaults.set(data, forKey: Self.pacingKey) }
    }

    // MARK: Parties

    func startClassic() {
        start(mode: .classic, day: nil, seed: UInt64.random(in: .min ... .max))
    }

    /// Lance le défi du jour s'il reste un essai. Renvoie `false` sinon.
    @discardableResult
    func startDaily() -> Bool {
        let day = today
        var started = false
        update { started = $0.startDailyAttempt(day: day) }
        guard started else { return false }
        start(mode: .daily, day: day, seed: DayKey.dailySeed(day))
        return true
    }

    private func start(mode: GameMode, day: String?, seed: UInt64) {
        adPacing.gameStarted()
        save()
        session = GameSession(app: self, mode: mode, day: day, seed: seed)
        route = .game
    }

    /// Fin de partie (une seule fois par partie) : pièces, record, série du défi, Game Center, pubs.
    func finish(_ result: GameResult, day: String?) -> GameSummary {
        let coins = Economy.coins(for: result)
        var record = false
        var streakReward = 0
        update { profile in
            record = profile.recordGame(result, coinsEarned: coins)
            if let day { streakReward = profile.recordDaily(score: result.score, day: day) }
            if result.roundsCleared >= 2 { profile.tutorialDone = true }
        }
        adPacing.gameFinished()
        save()
        gameCenter.submit(score: result.score, mode: result.mode)
        // Première partie finie : c'est le moment de demander le consentement aux pubs (pas au tout premier lancement).
        Task {
            await ads.start()
            ads.preload()
        }
        return GameSummary(coins: coins, newRecord: record, streakReward: streakReward)
    }

    func addCoins(_ amount: Int) {
        update { $0.coins += amount }
    }

    /// Quitte l'écran de fin : pub entre les parties si elle est due, puis `next` (Accueil ou nouvelle partie).
    func leaveGame(then next: @escaping () -> Void) async {
        let now = Date()
        if adPacing.interstitialDue(now: now, firstLaunch: profile.firstLaunch, noAds: profile.noAds),
           await ads.showInterstitial() {
            adPacing.interstitialShown(now: now)
            save()
        }
        next()
    }

    func goHome() {
        session = nil
        route = .home
    }

    /// Pub récompensée. Renvoie vrai si elle a été vue jusqu'au bout.
    func watchRewarded(_ placement: AdsController.Placement) async -> Bool {
        let earned = await ads.showRewarded(placement)
        if earned {
            adPacing.rewardedWatched()
            save()
        }
        return earned
    }

    /// Un essai de plus au défi du jour contre une pub. Renvoie vrai s'il a été gagné.
    func earnDailyAttempt() async -> Bool {
        let day = today
        guard profile.canEarnDailyAttempt(day: day), await watchRewarded(.extraDaily) else { return false }
        update { $0.earnDailyAttempt(day: day) }
        return true
    }

    // MARK: Boutique

    func buyWithCoins(_ skin: Skin) -> Bool {
        var bought = false
        update { bought = $0.buy(skin) }
        if bought { haptics.success() }
        return bought
    }

    func equip(_ skin: Skin) {
        update { $0.equip(skin) }
        haptics.tap()
    }

    /// Achats non consommables actifs (lus auprès d'Apple au lancement, après un achat ou « Restaurer »).
    func applyEntitlements(_ products: Set<StoreProduct>) {
        guard !products.isEmpty else { return }
        update { profile in
            for product in products {
                if product.removesAds { profile.noAds = true }
                profile.ownedSkins.formUnion(product.skins)
            }
        }
    }

    /// Achat remboursé par Apple : on retire ce qu'il donnait.
    func revoke(_ product: StoreProduct) {
        update { profile in
            if product.removesAds { profile.noAds = false }
            for skin in product.skins {
                profile.ownedSkins.remove(skin)
                if profile.equippedTrail == skin { profile.equippedTrail = Catalog.defaultTrail }
                if profile.equippedDecor == skin { profile.equippedDecor = Catalog.defaultDecor }
            }
        }
    }

    /// Pack de pièces payé : crédité une seule fois par transaction.
    func credit(_ product: StoreProduct, transaction: UInt64) {
        guard product.coins > 0, !profile.creditedTransactions.contains(transaction) else { return }
        update { profile in
            profile.coins += product.coins
            profile.creditedTransactions.insert(transaction)
        }
    }
}

/// Ce que l'écran de fin affiche une fois la partie comptée.
struct GameSummary: Equatable {
    var coins: Int
    var newRecord: Bool
    var streakReward: Int
}
