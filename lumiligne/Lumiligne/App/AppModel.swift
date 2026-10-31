import Foundation
import SwiftUI
import LumiCore

/// Le cerveau de l'app : profil du joueur (gardé sur le téléphone), grille en cours, pubs, achats, Game Center.
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
    /// Grille affichée (route `.game`).
    private(set) var session: GameSession?
    /// Grille en préparation (génération).
    private(set) var preparing = false

    let ads = AdsController()
    let store = StoreController()
    let gameCenter = GameCenter()
    let sound = SoundPlayer()
    let haptics = Haptics()

    private static let profileKey = "lumiligne.profile"
    private static let pacingKey = "lumiligne.adPacing"

    init() {
        let decoder = JSONDecoder()
        let defaults = UserDefaults.standard
        profile = defaults.data(forKey: Self.profileKey).flatMap { try? decoder.decode(Profile.self, from: $0) } ?? Profile()
        adPacing = defaults.data(forKey: Self.pacingKey).flatMap { try? decoder.decode(AdPacing.self, from: $0) } ?? AdPacing()
        sound.enabled = profile.soundOn
        haptics.enabled = profile.hapticsOn
        store.start(app: self)
        gameCenter.authenticate()
        // Joueur qui revient : le consentement aux pubs a déjà été demandé, on démarre les pubs tout de suite.
        if profile.gridsSolved > 0 { Task { await ads.start() } }
    }

    // MARK: Profil

    var today: String { DayKey.today() }
    var palette: Palette { Palette(Catalog.theme(profile.theme)) }

    /// Modifie le profil et l'enregistre aussitôt.
    func update(_ change: (inout Profile) -> Void) {
        change(&profile)
        sound.enabled = profile.soundOn
        haptics.enabled = profile.hapticsOn
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(profile) { UserDefaults.standard.set(data, forKey: Self.profileKey) }
        if let data = try? encoder.encode(adPacing) { UserDefaults.standard.set(data, forKey: Self.pacingKey) }
    }

    // MARK: Grilles

    func playNextLevel() { play(.level(profile.nextLevel)) }
    func playDaily() { play(.daily(today)) }
    func playBonus() { play(.bonus(today)) }

    /// Prépare la grille (en arrière-plan : quelques millisecondes à une seconde) puis l'affiche.
    func play(_ kind: PuzzleKind) {
        guard !preparing else { return }
        preparing = true
        Task {
            let grid = await Task.detached(priority: .userInitiated) { Puzzles.grid(kind) }.value
            let saved = profile.saved(kind.key)
            adPacing.gridStarted()
            save()
            session = GameSession(app: self, kind: kind, grid: grid, saved: saved)
            route = .game
            preparing = false
        }
    }

    /// Garde la grille commencée (reprise au prochain lancement).
    func keep(_ grid: SavedGrid) {
        update { $0.save(grid) }
    }

    /// Grille finie (une seule fois par grille) : récompense, série, Game Center, pubs.
    func finish(_ kind: PuzzleKind, seconds: Int, hintsUsed: Int) -> Reward {
        var reward = Reward()
        update { profile in
            profile.forget(kind.key)
            switch kind {
            case .level(let number):
                reward = profile.completeLevel(number)
            case .daily(let day):
                reward = profile.completeDaily(day: day, time: Economy.dailyTime(seconds: seconds, hintsUsed: hintsUsed))
            case .bonus(let day):
                reward = profile.completeBonus(day: day)
            }
        }
        switch kind {
        case .level: if reward.firstTime { gameCenter.submitLevel(profile.levelsDone) }
        case .daily: gameCenter.submitDaily(seconds: Economy.dailyTime(seconds: seconds, hintsUsed: hintsUsed))
        case .bonus: break
        }
        adPacing.gridFinished()
        save()
        // Première grille finie : c'est le moment de demander le consentement aux pubs (pas au tout premier lancement).
        Task {
            await ads.start()
            ads.preload()
        }
        return reward
    }

    /// Quitte l'écran de victoire : pub entre les grilles si elle est due, puis `next`.
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

    // MARK: Indices et pubs récompensées

    /// Utilise un indice. Renvoie `false` s'il n'en reste pas.
    func spendHint() -> Bool {
        var spent = false
        update { spent = $0.useHint() }
        return spent
    }

    /// Un indice contre une pub. Renvoie vrai s'il a été gagné.
    func earnHint() async -> Bool {
        let day = today
        guard profile.canEarnAdHint(today: day), await watchRewarded(.hint) else { return false }
        update { $0.earnAdHint(today: day) }
        haptics.success()
        return true
    }

    /// Débloque la grille bonus du jour contre une pub. Renvoie vrai si elle est débloquée.
    func unlockBonus() async -> Bool {
        let day = today
        guard profile.canUnlockBonus(today: day), await watchRewarded(.bonus) else { return false }
        update { $0.unlockBonus(today: day) }
        return true
    }

    private func watchRewarded(_ placement: AdsController.Placement) async -> Bool {
        let earned = await ads.showRewarded(placement)
        if earned {
            adPacing.rewardedWatched()
            save()
        }
        return earned
    }

    // MARK: Thèmes et achats

    func select(_ theme: ThemeSkin) {
        update { $0.select(theme) }
        haptics.tap()
    }

    /// Achats non consommables actifs (lus auprès d'Apple au lancement, après un achat ou « Restaurer »).
    func applyEntitlements(_ products: Set<StoreProduct>) {
        guard !products.isEmpty else { return }
        update { profile in
            for product in StoreProduct.allCases where products.contains(product) {
                if product.removesAds { profile.noAds = true }
                for theme in product.themes where !profile.ownedThemes.contains(theme) { profile.ownedThemes.append(theme) }
            }
        }
    }

    /// Achat remboursé par Apple : on retire ce qu'il donnait.
    func revoke(_ product: StoreProduct) {
        update { profile in
            if product.removesAds { profile.noAds = false }
            profile.ownedThemes.removeAll { product.themes.contains($0) }
            if !profile.owns(Catalog.theme(profile.theme)) { profile.theme = Catalog.defaultTheme }
        }
    }

    /// Indices payés : crédités une seule fois par transaction.
    func credit(_ product: StoreProduct, transaction: UInt64) {
        guard product.hints > 0, !profile.creditedTransactions.contains(transaction) else { return }
        update { profile in
            profile.hints += product.hints
            profile.creditedTransactions.append(transaction)
        }
    }
}
