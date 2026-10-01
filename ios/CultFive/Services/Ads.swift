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
            if let root = Self.topViewController {
                try await UMPConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // Réseau ou formulaire indisponible : on réessaiera au prochain lancement.
        }
        // Demande de suivi Apple seulement aux majeurs : aux autres, aucune pub personnalisée n'est montrée.
        if adultAudience, ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        guard consent.canRequestAds else { return }
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        started = true
    }

    // MARK: Pubs récompensées

    /// Montre une pub récompensée. Renvoie `true` si elle a été vue jusqu'au bout. Google confirme ensuite la vue à notre
    /// serveur avec l'identifiant du joueur et « type:référence », ce qui permet au serveur de donner la bonne récompense.
    func showRewarded(_ kind: AdKind, userId: UUID, ref: String?) async throws -> Bool {
        if !started { await start() }
        guard started else { throw Self.unavailable }
        let unit = testAds ? Self.testRewardedUnit : (Self.rewardedUnits[kind] ?? Self.testRewardedUnit)
        let ad: GADRewardedAd
        do {
            applyAudience()
            ad = try await GADRewardedAd.load(withAdUnitID: unit, request: GADRequest())
        } catch {
            throw Self.unavailable
        }
        let options = GADServerSideVerificationOptions()
        options.userIdentifier = userId.uuidString.lowercased()
        options.customRewardString = "\(kind.rawValue):\(ref ?? "")"
        ad.serverSideVerificationOptions = options
        let waiter = PresentationWaiter()
        ad.fullScreenContentDelegate = waiter
        var earned = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter.continuation = continuation
            ad.present(fromRootViewController: Self.topViewController) { earned = true }
        }
        // Le délégué est une référence faible du SDK : on garde la pub et l'attente en vie jusqu'à la fermeture.
        withExtendedLifetime((ad, waiter)) {}
        if earned { rewardedSinceLastGame = true }
        return earned
    }

    // MARK: Pub entre les parties

    private static let gamesKey = "ads.gamesSinceInterstitial"
    private static let dayKey = "ads.interstitialDay"
    private static let countKey = "ads.interstitialCount"

    /// Une partie Jouer vient de finir.
    func noteGameFinished() {
        defaults.set(defaults.integer(forKey: Self.gamesKey) + 1, forKey: Self.gamesKey)
        rewardedSinceLastGame = false
    }

    /// Montre la pub entre les parties si elle est due. `allowed` : autorisation du serveur (pas les 3 premiers jours).
    /// Renvoie `true` si une pub a été montrée.
    func showInterstitialIfDue(allowed: Bool) async -> Bool {
        guard enabled, started, allowed, !rewardedSinceLastGame else { return false }
        let today = Self.dayString(Date())
        let shownToday = defaults.string(forKey: Self.dayKey) == today ? defaults.integer(forKey: Self.countKey) : 0
        guard defaults.integer(forKey: Self.gamesKey) >= 3, shownToday < 3 else { return false }
        let unit = testAds ? Self.testInterstitialUnit : Self.interstitialUnit
        applyAudience()
        guard let ad = try? await GADInterstitialAd.load(withAdUnitID: unit, request: GADRequest()) else { return false }
        let waiter = PresentationWaiter()
        ad.fullScreenContentDelegate = waiter
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter.continuation = continuation
            ad.present(fromRootViewController: Self.topViewController)
        }
        withExtendedLifetime((ad, waiter)) {}
        defaults.set(0, forKey: Self.gamesKey)
        defaults.set(today, forKey: Self.dayKey)
        defaults.set(shownToday + 1, forKey: Self.countKey)
        return true
    }

    // MARK: Outils

    /// Classification maximale des pubs, appliquée avant chaque chargement.
    private func applyAudience() {
        let configuration = GADMobileAds.sharedInstance().requestConfiguration
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
        var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}

/// Attend la fermeture d'une pub plein écran (ou son échec d'affichage).
private final class PresentationWaiter: NSObject, GADFullScreenContentDelegate {
    var continuation: CheckedContinuation<Void, Never>?

    private func finish() {
        continuation?.resume()
        continuation = nil
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) { finish() }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) { finish() }
}
