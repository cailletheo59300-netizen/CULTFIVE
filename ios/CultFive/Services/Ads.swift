import Foundation
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform
import CultFiveCore

/// Pubs Google AdMob.
/// - Pubs récompensées, toujours au choix du joueur : la récompense est donnée par le serveur, après la confirmation
///   de Google (vérification côté serveur), jamais par l'app.
/// - Pub entre les parties : au plus 1 toutes les 3 parties finies et 3 par jour, jamais les 3 premiers jours, jamais
///   juste après une pub récompensée. Appelée seulement depuis l'écran de fin d'une partie Jouer (donc jamais pendant
///   le 5 du jour, l'onboarding ou une question).
/// - Consentement : message RGPD de Google (UMP), puis demande Apple de suivi (ATT), avant tout chargement de pub.
/// Les builds de test (Xcode, TestFlight) affichent les pubs de test de Google : cliquer ses propres vraies pubs
/// peut faire suspendre le compte AdMob.
@MainActor
@Observable
final class AdsController {
    private static let rewardedUnits: [AdKind: String] = [
        .doubleSeeds: "ca-app-pub-1190519561086839/7044735086",
        .boostChest: "ca-app-pub-1190519561086839/4275015795",
        .freeChest: "ca-app-pub-1190519561086839/9555262634",
        // Pochette gratuite : même bloc que le coffre offert, en attendant un bloc à part dans AdMob.
        .freePack: "ca-app-pub-1190519561086839/9555262634",
        .streakRescue: "ca-app-pub-1190519561086839/8242180963",
        .correction: "ca-app-pub-1190519561086839/6929099296",
    ]
    private static let interstitialUnit = "ca-app-pub-1190519561086839/9335770786"
    private static let testRewardedUnit = "ca-app-pub-3940256099942544/1712485313"
    private static let testInterstitialUnit = "ca-app-pub-3940256099942544/4411468910"

    /// Pubs de test de Google (Xcode et TestFlight).
    let testAds: Bool
    private let enabled: Bool
    private(set) var started = false
    private var starting = false
    /// Joueur majeur (tranche d'âge 18+ indiquée) : pubs jusqu'à « public adulte » (MA). Sinon (13-17 ou âge non
    /// indiqué) : « adolescents » (T) au plus, non personnalisées (sous l'âge du consentement numérique), sans demande
    /// de suivi Apple. Les catégories sensibles restent bloquées dans AdMob pour tous.
    var adultAudience = false
    /// Une pub récompensée a été vue depuis la dernière partie finie : pas de pub entre les parties juste après.
    private var rewardedSinceLastGame = false
    /// Pourquoi la dernière pub récompensée n'a pas pu s'afficher (journal d'usage), `nil` si elle s'est affichée.
    private(set) var lastFailure: String?
    /// Pubs récompensées chargées à l'avance, par bloc : elles s'ouvrent tout de suite à l'appui.
    /// Google les garde valables une heure ; au-delà de 50 min on en recharge une.
    private var ready: [String: (ad: RewardedAd, loadedAt: Date)] = [:]
    /// Chargements en cours, par bloc : un appui pendant le préchargement attend celui-ci au lieu d'en lancer un autre.
    private var inFlight: [String: Task<RewardedAd?, Never>] = [:]
    /// Blocs préchargés : les bonus les plus utilisés (coffre boosté, coffre offert et pochette gratuite, neurones doublés).
    private static let preloadKinds: [AdKind] = [.boostChest, .freeChest, .doubleSeeds]
    private let defaults = UserDefaults.standard

    init(enabled: Bool) {
        self.enabled = enabled
        #if DEBUG
        testAds = true
        #else
        testAds = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    // MARK: Démarrage et consentement

    /// Consentement RGPD puis suivi Apple, puis démarrage du SDK. Une seule fois ; sans effet si le joueur refuse
    /// (les pubs restent possibles, non personnalisées, si le consentement le permet).
    func start() async {
        guard enabled, !started, !starting else { return }
        starting = true
        defer { starting = false }
        let consent = UMPConsentInformation.sharedInstance
        let parameters = UMPRequestParameters()
        // Mineurs (ou âge non indiqué) : sous l'âge du consentement numérique, pubs non personnalisées.
        parameters.tagForUnderAgeOfConsent = !adultAudience
        do {
            try await consent.requestConsentInfoUpdate(with: parameters)
            // Le voile « Chargement… » est une fenêtre au-dessus de tout : il cacherait le message de Google.
            LoadingOverlay.hide()
            if let root = Self.topViewController {
                try await UMPConsentForm.loadAndPresentIfRequired(from: root)
            }
            consentError = nil
        } catch {
            // Réseau ou formulaire indisponible : on réessaiera à la prochaine pub ou au prochain lancement.
            let error = error as NSError
            consentError = "form \(error.domain) \(error.code)"
        }
        // Demande de suivi Apple seulement aux majeurs : aux autres, aucune pub personnalisée n'est montrée.
        if adultAudience, ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        guard consent.canRequestAds else { return }
        MobileAds.shared.start(completionHandler: nil)
        started = true
    }

    // MARK: Préchargement

    private func rewardedUnit(for kind: AdKind) -> String {
        testAds ? Self.testRewardedUnit : (Self.rewardedUnits[kind] ?? Self.testRewardedUnit)
    }

    /// Charge à l'avance les pubs des bonus les plus utilisés (sans Pass+ seulement, l'appelant le vérifie).
    func preload() {
        guard enabled, started else { return }
        for kind in Self.preloadKinds { _ = loadTask(rewardedUnit(for: kind)) }
    }

    /// Chargement d'une pub du bloc, partagé : un seul à la fois par bloc. Le résultat va dans `ready`.
    private func loadTask(_ unit: String) -> Task<RewardedAd?, Never>? {
        if let fresh = ready[unit], Date().timeIntervalSince(fresh.loadedAt) < 50 * 60 { return nil }
        if let running = inFlight[unit] { return running }
        applyAudience()
        let task = Task<RewardedAd?, Never> { [weak self] in
            let ad: RewardedAd?
            do {
                ad = try await RewardedAd.load(with: unit, request: Request())
            } catch {
                let error = error as NSError
                self?.lastFailure = "load \(error.domain) \(error.code)"
                ad = nil
            }
            self?.inFlight[unit] = nil
            if let ad { self?.ready[unit] = (ad, Date()) }
            return ad
        }
        inFlight[unit] = task
        return task
    }

    /// Une pub prête du bloc (préchargée, ou chargée maintenant), retirée de la réserve.
    private func takeAd(_ unit: String) async -> RewardedAd? {
        if let fresh = ready[unit], Date().timeIntervalSince(fresh.loadedAt) < 50 * 60 {
            ready[unit] = nil
            return fresh.ad
        }
        ready[unit] = nil
        _ = await loadTask(unit)?.value
        return ready.removeValue(forKey: unit)?.ad
    }

    /// Le joueur peut revoir ses choix de confidentialité des pubs (Europe : message RGPD de Google).
    var privacyOptionsAvailable: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    /// Rouvre le message de Google pour changer ses choix, sans réinstaller l'app. Les pubs repartent ensuite
    /// si le nouveau choix le permet.
    func presentPrivacyOptions() async {
        guard let root = Self.topViewController else { return }
        try? await UMPConsentForm.presentPrivacyOptionsForm(from: root)
        if !started, UMPConsentInformation.sharedInstance.canRequestAds {
            MobileAds.shared.start(completionHandler: nil)
            started = true
        }
    }

    /// Dernier échec d'affichage du message de confidentialité (journal d'usage `ad_fail`).
    private var consentError: String?

    /// Consentement encore demandé mais jamais donné (message fermé ou qui n'a pas pu s'afficher) : on le réaffiche.
    /// Accepter comme refuser débloque les pubs (personnalisées ou non) ; on démarre alors le SDK.
    private func askConsentAgain() async {
        let consent = UMPConsentInformation.sharedInstance
        guard enabled, !started, consent.consentStatus == .required else { return }
        LoadingOverlay.hide()
        do {
            guard let root = Self.topViewController else { return }
            let form = try await UMPConsentForm.load()
            try await form.present(from: root)
            consentError = nil
        } catch {
            let error = error as NSError
            consentError = "form \(error.domain) \(error.code)"
        }
        if consent.canRequestAds {
            MobileAds.shared.start(completionHandler: nil)
            started = true
        }
    }

    // MARK: Pubs récompensées

    /// Montre une pub récompensée. Renvoie `true` si elle a été vue jusqu'au bout. Google confirme ensuite la vue à notre
    /// serveur avec l'identifiant du joueur et « type:référence », ce qui permet au serveur de donner la bonne récompense.
    func showRewarded(_ kind: AdKind, userId: UUID, ref: String?) async throws -> Bool {
        lastFailure = nil
        if !started { await start() }
        // Message de confidentialité jamais terminé (D-090) : on le présente de nouveau, au moment où le joueur
        // demande une pub, plutôt que de répondre « Aucune pub disponible ».
        if !started { await askConsentAgain() }
        guard started else {
            lastFailure = "not_started consent \(UMPConsentInformation.sharedInstance.consentStatus.rawValue)"
                + (consentError.map { " \($0)" } ?? "")
            throw Self.unavailable
        }
        let unit = rewardedUnit(for: kind)
        guard let ad = await takeAd(unit) else {
            if lastFailure == nil { lastFailure = "load none" }
            throw Self.unavailable
        }
        lastFailure = nil
        let options = ServerSideVerificationOptions()
        options.userIdentifier = userId.uuidString.lowercased()
        options.customRewardText = "\(kind.rawValue):\(ref ?? "")"
        ad.serverSideVerificationOptions = options
        let waiter = PresentationWaiter()
        ad.fullScreenContentDelegate = waiter
        var earned = false
        // Le voile « Chargement de la pub… » s'efface quand la pub prend l'écran.
        LoadingOverlay.hide()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter.continuation = continuation
            ad.present(from: Self.topViewController) { earned = true }
        }
        // Le délégué est une référence faible du SDK : on garde la pub et l'attente en vie jusqu'à la fermeture.
        withExtendedLifetime((ad, waiter)) {}
        if earned { rewardedSinceLastGame = true }
        // La suivante se charge déjà, pour le prochain bonus.
        if Self.preloadKinds.contains(kind) { _ = loadTask(unit) }
        return earned
    }

    // MARK: Pub entre les parties

    private static let gamesKey = "ads.gamesSinceInterstitial"
    private static let dayKey = "ads.interstitialDay"
    private static let countKey = "ads.interstitialCount"

    /// Pub entre les parties chargée d'avance (pendant le bilan) : elle s'affiche sans faire attendre.
    private var interstitialReady: (ad: InterstitialAd, loadedAt: Date)?
    private var interstitialLoading = false
    /// Dernier échec de chargement de la pub entre les parties (« load <domaine> <code> »).
    private var interstitialLoadError: String?
    /// Pourquoi la pub entre les parties, due, ne s'est pas affichée (journal d'usage `ad_fail`) ; nil si rien à signaler.
    private(set) var interstitialFailure: String?

    /// La pub entre les parties sera due au prochain passage : on la charge pendant que le joueur lit son bilan.
    func preloadInterstitialIfSoon() {
        guard enabled, started, !interstitialLoading, defaults.integer(forKey: Self.gamesKey) >= 3 else { return }
        if let ready = interstitialReady, Date().timeIntervalSince(ready.loadedAt) < 50 * 60 { return }
        interstitialLoading = true
        let unit = testAds ? Self.testInterstitialUnit : Self.interstitialUnit
        applyAudience()
        Task { [weak self] in
            do {
                let ad = try await InterstitialAd.load(with: unit, request: Request())
                self?.interstitialReady = (ad, Date())
                self?.interstitialLoadError = nil
            } catch {
                let error = error as NSError
                self?.interstitialLoadError = "load \(error.domain) \(error.code)"
            }
            self?.interstitialLoading = false
        }
    }

    /// Une partie Jouer vient de finir.
    func noteGameFinished() {
        defaults.set(defaults.integer(forKey: Self.gamesKey) + 1, forKey: Self.gamesKey)
        rewardedSinceLastGame = false
    }

    /// Montre la pub entre les parties si elle est due. `allowed` : autorisation du serveur (pas les 3 premiers jours).
    /// Renvoie `true` si une pub a été montrée.
    func showInterstitialIfDue(allowed: Bool) async -> Bool {
        interstitialFailure = nil
        guard enabled, allowed, !rewardedSinceLastGame else { return false }
        let today = Self.dayString(Date())
        let shownToday = defaults.string(forKey: Self.dayKey) == today ? defaults.integer(forKey: Self.countKey) : 0
        guard defaults.integer(forKey: Self.gamesKey) >= 3, shownToday < 3 else { return false }
        // Due mais impossible : on note pourquoi.
        guard started else {
            interstitialFailure = "not_started consent \(UMPConsentInformation.sharedInstance.consentStatus.rawValue)"
            return false
        }
        // Jamais d'attente entre deux parties : sans pub prête, on n'en montre pas cette fois (elle se charge pour la suivante).
        guard let ready = interstitialReady, Date().timeIntervalSince(ready.loadedAt) < 50 * 60 else {
            interstitialFailure = interstitialReady != nil ? "expired"
                : interstitialLoading ? "loading" : (interstitialLoadError ?? "not_loaded")
            interstitialReady = nil
            preloadInterstitialIfSoon()
            return false
        }
        interstitialReady = nil
        let ad = ready.ad
        let waiter = PresentationWaiter()
        ad.fullScreenContentDelegate = waiter
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter.continuation = continuation
            ad.present(from: Self.topViewController)
        }
        withExtendedLifetime((ad, waiter)) {}
        if let error = waiter.failure as NSError? {
            interstitialFailure = "present \(error.domain) \(error.code)"
            return false
        }
        defaults.set(0, forKey: Self.gamesKey)
        defaults.set(today, forKey: Self.dayKey)
        defaults.set(shownToday + 1, forKey: Self.countKey)
        return true
    }

    // MARK: Outils

    /// Classification maximale des pubs, appliquée avant chaque chargement.
    private func applyAudience() {
        let configuration = MobileAds.shared.requestConfiguration
        configuration.maxAdContentRating = adultAudience ? .matureAudience : .teen
        configuration.tagForUnderAgeOfConsent = NSNumber(value: !adultAudience)
    }

    private static var unavailable: BackendError { .server(status: 400, code: "ad_unavailable", message: "") }

    private static func dayString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// Écran au premier plan (y compris une feuille ou un plein écran SwiftUI), d'où présenter la pub.
    static var topViewController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        // Fenêtres normales seulement : jamais le voile « Chargement… », posé au-dessus de tout.
        let windows = scene?.windows.filter { $0.windowLevel == .normal } ?? []
        var controller = windows.first { $0.isKeyWindow }?.rootViewController ?? windows.first?.rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}

/// Attend la fermeture d'une pub plein écran (ou son échec d'affichage).
private final class PresentationWaiter: NSObject, FullScreenContentDelegate {
    var continuation: CheckedContinuation<Void, Never>?
    /// La pub n'a pas pu s'afficher.
    private(set) var failure: Error?

    private func finish() {
        continuation?.resume()
        continuation = nil
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { finish() }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        failure = error
        finish()
    }
}
