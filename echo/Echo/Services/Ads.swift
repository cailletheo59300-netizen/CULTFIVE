import Foundation
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Blocs d'annonces AdMob d'Écho (app « Echo » dans AdMob). Ce ne sont pas des secrets. Xcode et TestFlight
/// affichent quand même les pubs de test de Google (voir `testAds`).
enum AdConfig {
    /// Pub récompensée « Continuer ».
    static let rewardedContinue = "ca-app-pub-1190519561086839/7704746453"
    /// Pub récompensée « Pièces ×2 ».
    static let rewardedDouble = "ca-app-pub-1190519561086839/1000184419"
    /// Pub récompensée « Un essai de plus » au défi du jour.
    static let rewardedDaily = "ca-app-pub-1190519561086839/3518536549"
    /// Pub entre les parties.
    static let interstitial = "ca-app-pub-1190519561086839/3110895329"

    static let testRewarded = "ca-app-pub-3940256099942544/1712485313"
    static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"
}

/// Pubs Google AdMob (même fonctionnement que Brainlix, en plus simple : pas de serveur).
/// - Pubs récompensées, toujours au choix du joueur : Continuer, Pièces ×2, Un essai de plus au défi.
/// - Pub entre les parties : quand le joueur quitte l'écran de fin, selon `AdPacing` (jamais pendant une manche).
/// - Consentement : message RGPD de Google (UMP), puis demande Apple de suivi (ATT), après la première partie.
/// Xcode et TestFlight affichent toujours les pubs de test de Google : cliquer ses propres vraies pubs peut faire
/// suspendre le compte AdMob.
@MainActor
@Observable
final class AdsController {
    enum Placement {
        case continueRun, doubleCoins, extraDaily
    }

    private(set) var started = false
    private var starting = false
    let testAds: Bool

    private var rewardedReady: [String: (ad: RewardedAd, loadedAt: Date)] = [:]
    private var rewardedLoading: [String: Task<RewardedAd?, Never>] = [:]
    private var interstitialReady: (ad: InterstitialAd, loadedAt: Date)?
    private var interstitialLoading = false

    init() {
        #if DEBUG
        testAds = true
        #else
        testAds = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" || AdConfig.interstitial.isEmpty
        #endif
    }

    // MARK: Démarrage et consentement

    /// Consentement RGPD puis suivi Apple, puis démarrage du SDK. Une seule fois.
    func start() async {
        guard !started, !starting else { return }
        starting = true
        defer { starting = false }
        let consent = UMPConsentInformation.sharedInstance
        do {
            try await consent.requestConsentInfoUpdate(with: UMPRequestParameters())
            if let root = Self.topViewController {
                try await UMPConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // Réseau ou message indisponible : on réessaiera à la prochaine pub ou au prochain lancement.
        }
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        guard consent.canRequestAds else { return }
        let configuration = MobileAds.shared.requestConfiguration
        // Pubs adaptées à un jeu tout public (voir la classification de l'app dans App Store Connect).
        configuration.maxAdContentRating = .parentalGuidance
        MobileAds.shared.start(completionHandler: nil)
        started = true
        preload()
    }

    /// Le joueur peut revoir ses choix de confidentialité (Europe).
    var privacyOptionsAvailable: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    func presentPrivacyOptions() async {
        guard let root = Self.topViewController else { return }
        try? await UMPConsentForm.presentPrivacyOptionsForm(from: root)
    }

    // MARK: Pubs récompensées

    private func unit(_ placement: Placement) -> String {
        let real: String = switch placement {
        case .continueRun: AdConfig.rewardedContinue
        case .doubleCoins: AdConfig.rewardedDouble
        case .extraDaily: AdConfig.rewardedDaily
        }
        return testAds || real.isEmpty ? AdConfig.testRewarded : real
    }

    /// Charge à l'avance les pubs : elles s'ouvrent tout de suite quand le joueur les demande.
    func preload() {
        guard started else { return }
        for placement in [Placement.continueRun, .doubleCoins] { _ = loadRewarded(unit(placement)) }
        loadInterstitial()
    }

    private func loadRewarded(_ unit: String) -> Task<RewardedAd?, Never>? {
        if let ready = rewardedReady[unit], Date().timeIntervalSince(ready.loadedAt) < 50 * 60 { return nil }
        if let running = rewardedLoading[unit] { return running }
        let task = Task<RewardedAd?, Never> { [weak self] in
            let ad = try? await RewardedAd.load(with: unit, request: Request())
            self?.rewardedLoading[unit] = nil
            if let ad { self?.rewardedReady[unit] = (ad, Date()) }
            return ad
        }
        rewardedLoading[unit] = task
        return task
    }

    /// Montre une pub récompensée. Renvoie vrai si elle a été vue jusqu'au bout.
    func showRewarded(_ placement: Placement) async -> Bool {
        if !started { await start() }
        guard started else { return false }
        let unit = unit(placement)
        if rewardedReady[unit] == nil { _ = await loadRewarded(unit)?.value }
        guard let ready = rewardedReady.removeValue(forKey: unit),
              Date().timeIntervalSince(ready.loadedAt) < 55 * 60 else { return false }
        let waiter = PresentationWaiter()
        ready.ad.fullScreenContentDelegate = waiter
        var earned = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter.continuation = continuation
            ready.ad.present(from: Self.topViewController) { earned = true }
        }
        withExtendedLifetime((ready.ad, waiter)) {}
        _ = loadRewarded(unit)
        return earned
    }

    // MARK: Pub entre les parties

    private func loadInterstitial() {
        guard started, !interstitialLoading else { return }
        if let ready = interstitialReady, Date().timeIntervalSince(ready.loadedAt) < 50 * 60 { return }
        interstitialLoading = true
        let unit = testAds || AdConfig.interstitial.isEmpty ? AdConfig.testInterstitial : AdConfig.interstitial
        Task { [weak self] in
            if let ad = try? await InterstitialAd.load(with: unit, request: Request()) {
                self?.interstitialReady = (ad, Date())
            }
            self?.interstitialLoading = false
        }
    }

    /// Montre la pub entre les parties si elle est prête (jamais d'attente). Renvoie vrai si elle a été montrée.
    func showInterstitial() async -> Bool {
        guard started, let ready = interstitialReady, Date().timeIntervalSince(ready.loadedAt) < 55 * 60 else {
            loadInterstitial()
            return false
        }
        interstitialReady = nil
        let waiter = PresentationWaiter()
        ready.ad.fullScreenContentDelegate = waiter
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter.continuation = continuation
            ready.ad.present(from: Self.topViewController)
        }
        withExtendedLifetime((ready.ad, waiter)) {}
        loadInterstitial()
        return waiter.failure == nil
    }

    /// Écran au premier plan, d'où présenter une pub ou un message.
    static var topViewController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
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
