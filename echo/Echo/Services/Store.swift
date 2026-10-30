import Foundation
import StoreKit
import EchoCore

/// Achats intégrés (StoreKit 2), sans serveur : Apple signe chaque achat et StoreKit vérifie la signature sur le
/// téléphone. Les achats définitifs (Sans pub, apparences) sont relus auprès d'Apple à chaque lancement ; les packs de
/// pièces sont crédités une seule fois (identifiant de transaction gardé dans le profil).
@MainActor
@Observable
final class StoreController {
    private(set) var products: [StoreProduct: Product] = [:]
    /// Achat en cours (un seul à la fois).
    private(set) var purchasing: StoreProduct?
    var message: String?

    private weak var app: AppModel?
    private var updates: Task<Void, Never>?

    var busy: Bool { purchasing != nil }

    func start(app: AppModel) {
        guard self.app == nil else { return }
        self.app = app
        // Achats faits ailleurs (autre appareil, achat approuvé par un parent, remboursement).
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await loadProducts()
            for await result in Transaction.unfinished {
                await handle(result)
            }
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        guard products.count < StoreProduct.allCases.count else { return }
        let found = (try? await Product.products(for: StoreProduct.allCases.map(\.rawValue))) ?? []
        for product in found {
            if let kind = StoreProduct(rawValue: product.id) { products[kind] = product }
        }
    }

    /// Prix affiché par l'App Store (« 3,99 € »), dans la devise du joueur.
    func price(_ kind: StoreProduct) -> String? {
        products[kind]?.displayPrice ?? (AppModel.capture != nil ? Self.referencePrices[kind] : nil)
    }

    /// Prix conseillés (France), affichés seulement en mode capture : le simulateur n'a pas accès à l'App Store.
    private static let referencePrices: [StoreProduct: String] = [
        .noAds: "3,99 €", .starter: "4,99 €", .trailFire: "1,99 €", .trailGalaxy: "1,99 €", .decorSynthwave: "1,99 €",
        .coinsSmall: "0,99 €", .coinsMedium: "2,99 €", .coinsLarge: "9,99 €",
    ]

    /// Achat. Renvoie vrai s'il a abouti.
    @discardableResult
    func purchase(_ kind: StoreProduct) async -> Bool {
        message = nil
        await loadProducts()
        guard let product = products[kind] else {
            message = "Cet achat n'est pas disponible pour l'instant. Réessaie dans un instant."
            return false
        }
        purchasing = kind
        defer { purchasing = nil }
        do {
            switch try await product.purchase() {
            case .success(let result):
                return await handle(result)
            case .pending:
                message = "Achat en attente d'approbation. Il s'activera tout seul ensuite."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            message = "L'achat n'a pas abouti. Aucun paiement n'a été pris."
            return false
        }
    }

    /// « Restaurer les achats » (nouveau téléphone, app réinstallée).
    func restore() async {
        message = nil
        purchasing = .noAds
        defer { purchasing = nil }
        try? await AppStore.sync()
        let found = await refreshEntitlements()
        message = found.isEmpty ? "Aucun achat à restaurer sur ce compte Apple." : "Achats restaurés."
    }

    /// Relit auprès d'Apple les achats définitifs actifs et les applique au profil.
    @discardableResult
    private func refreshEntitlements() async -> Set<StoreProduct> {
        var owned: Set<StoreProduct> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil,
               let product = StoreProduct(rawValue: transaction.productID), !product.isConsumable {
                owned.insert(product)
            }
        }
        app?.applyEntitlements(owned)
        return owned
    }

    /// Une transaction signée par Apple : appliquée, puis terminée.
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        // Signature invalide : on ne donne rien.
        guard case .verified(let transaction) = result, let product = StoreProduct(rawValue: transaction.productID) else {
            return false
        }
        if transaction.revocationDate != nil {
            app?.revoke(product)
        } else if product.isConsumable {
            app?.credit(product, transaction: transaction.id)
        } else {
            app?.applyEntitlements([product])
        }
        await transaction.finish()
        return transaction.revocationDate == nil
    }
}
