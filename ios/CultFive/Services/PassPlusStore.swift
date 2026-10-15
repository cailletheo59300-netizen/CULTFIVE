import Foundation
import StoreKit
import CultFiveCore

/// Achat du Pass+ (StoreKit 2) : une saison sans pub et la piste payante du pass.
/// L'app n'active rien elle-même : chaque achat signé par Apple est envoyé au serveur (`iap-verify`), qui le vérifie et
/// l'enregistre. La transaction n'est terminée (`finish`) qu'une fois le serveur d'accord : en cas d'échec réseau, elle
/// revient au prochain lancement (`Transaction.unfinished`).
@MainActor
@Observable
final class PassPlusStore {
    /// Produit App Store Connect : consommable, 3,99 €, racheté à chaque saison. Le Pass+ vit sur le serveur (compte Brainlix).
    static let productId = "app.brainlix.pass"

    private(set) var product: Product?
    private(set) var purchasing = false
    /// Achats de test (TestFlight, examen d'Apple) : le Pass+ s'achète même hors période de vente.
    private(set) var sandbox = false
    var errorMessage: String?

    private weak var app: AppModel?
    private var updates: Task<Void, Never>?

    /// Au lancement (une fois connecté) : produit, environnement, achats en attente ou faits ailleurs.
    func start(app: AppModel) {
        guard self.app == nil else { return }
        self.app = app
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await loadProduct()
            if case .verified(let transaction)? = try? await AppTransaction.shared {
                sandbox = transaction.environment != .production
            }
            for await result in Transaction.unfinished {
                await handle(result)
            }
        }
    }

    func loadProduct() async {
        guard product == nil else { return }
        product = try? await Product.products(for: [Self.productId]).first
    }

    /// Prix affiché par l'App Store (« 3,99 € »).
    var price: String? { product?.displayPrice }

    /// Achat. Renvoie vrai si le Pass+ est actif à la fin.
    func purchase() async -> Bool {
        errorMessage = nil
        await loadProduct()
        guard let product else {
            errorMessage = "Le Pass+ n'est pas disponible pour l'instant. Réessaie dans un instant."
            return false
        }
        guard let user = app?.profile?.id else {
            errorMessage = BackendError.notAuthenticated.errorDescription
            return false
        }
        purchasing = true
        defer { purchasing = false }
        do {
            // L'identifiant du joueur voyage avec l'achat : le serveur ne l'accepte que pour ce compte.
            switch try await product.purchase(options: [.appAccountToken(user)]) {
            case .success(let result):
                let ok = await handle(result)
                if ok { app?.track("pass_buy") }
                return ok
            case .pending:
                errorMessage = "Achat en attente d'approbation. Le Pass+ s'activera tout seul ensuite."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "L'achat n'a pas abouti. Aucun paiement n'a été pris."
            return false
        }
    }

    /// « Restaurer mes achats » : un achat pas encore validé (réseau coupé) est renvoyé au serveur, puis le Pass+ est relu.
    /// Le Pass+ est lié au compte Brainlix (consommable) : sur un autre iPhone, il suffit de se connecter au même compte.
    func restore() async {
        errorMessage = nil
        purchasing = true
        defer { purchasing = false }
        try? await AppStore.sync()
        for await result in Transaction.unfinished {
            await handle(result)
        }
        await app?.refreshPassPlus()
        if app?.noAds != true {
            errorMessage = "Aucun Pass+ sur ce compte. Ton Pass+ est lié à ton compte \(Brand.name) : connecte-toi au compte avec lequel tu l'as acheté."
        }
    }

    /// Une transaction de l'App Store : envoyée au serveur, puis terminée s'il l'a acceptée (ou refusée pour de bon).
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result, transaction.productID == Self.productId, let app else { return false }
        do {
            let verification = try await app.service.passPlusVerify(signedTransaction: result.jwsRepresentation)
            await transaction.finish()
            await app.refreshPassPlus()
            return verification.active
        } catch let error as BackendError where Self.final.contains(error.code ?? "") {
            // Refus définitif (autre compte, remboursé, hors vente) : inutile de la renvoyer.
            await transaction.finish()
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Le serveur ne répond pas. Ton achat sera validé au prochain lancement."
            return false
        }
    }

    private static let final: Set<String> = ["wrong_account", "transaction_other_user", "revoked", "wrong_product", "wrong_app",
                                             "pass_not_on_sale"]
}
