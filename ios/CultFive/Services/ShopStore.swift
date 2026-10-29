import Foundation
import StoreKit
import CultFiveCore

/// Produits de la boutique (identifiants App Store Connect, D-118).
enum ShopProduct: String, CaseIterable {
    /// Pass+ : consommable, 3,99 €, racheté à chaque saison (cadeaux de la piste Pass+ et plus de pub pendant la saison).
    case passPlus = "app.brainlix.pass"
    /// Sans pub pour toujours : non consommable, 7,99 €.
    case noAds = "app.brainlix.noads"
    /// Packs d'objets (consommables, D-119) : 1, 3 ou 8 de chaque objet et 1 h, 6 h ou 24 h sans pub.
    case packEssai = "app.brainlix.pack.essai"
    case packJoueur = "app.brainlix.pack.joueur"
    case packBig = "app.brainlix.pack.big"
    /// Offre de bienvenue (consommable, 7 premiers jours, une fois) : 7 jours sans pub, 2 de chaque objet, l'avatar
    /// Hypatie et le contour Bienvenue.
    case welcome = "app.brainlix.bienvenue"
    /// Look (non consommables, D-120) : avatars premium (0,99 € l'un, 2,49 € les 4), contours et titres (0,99 €),
    /// Pack Prestige (4,99 €, contenus exclusifs).
    case avatarJoan = "app.brainlix.avatar.joan"
    case avatarHugo = "app.brainlix.avatar.hugo"
    case avatarGalileo = "app.brainlix.avatar.galileo"
    case avatarDarwin = "app.brainlix.avatar.darwin"
    case avatars = "app.brainlix.avatars"
    case ringNeon = "app.brainlix.ring.neon"
    case ringGold = "app.brainlix.ring.gold"
    case ringRainbow = "app.brainlix.ring.rainbow"
    case titleErudit = "app.brainlix.title.erudit"
    case titleEncyclo = "app.brainlix.title.encyclo"
    case titleGenie = "app.brainlix.title.genie"
    case prestige = "app.brainlix.prestige"

    static func avatar(_ animal: AnimalAvatar) -> ShopProduct? { ShopProduct(rawValue: "app.brainlix.avatar.\(animal.rawValue)") }
    static func ring(_ ring: AvatarRing) -> ShopProduct? { ShopProduct(rawValue: "app.brainlix.ring.\(ring.rawValue)") }
    static func title(_ title: PlayerTitle) -> ShopProduct? { ShopProduct(rawValue: "app.brainlix.title.\(title.rawValue)") }
}

/// Achats intégrés (StoreKit 2) : Pass+ et boutique.
/// L'app n'active rien elle-même : chaque achat signé par Apple est envoyé au serveur (`iap-verify`), qui le vérifie et
/// l'enregistre sur le compte Brainlix. La transaction n'est terminée (`finish`) qu'une fois le serveur d'accord : en cas
/// d'échec réseau, elle revient au prochain lancement (`Transaction.unfinished`).
@MainActor
@Observable
final class ShopStore {
    private(set) var products: [ShopProduct: Product] = [:]
    /// Achat en cours (un seul à la fois).
    private(set) var purchasing: ShopProduct?
    /// Achats de test (TestFlight, examen d'Apple) : le Pass+ s'achète même hors période de vente.
    private(set) var sandbox = false
    var errorMessage: String?

    private weak var app: AppModel?
    private var updates: Task<Void, Never>?

    var busy: Bool { purchasing != nil }

    /// Au lancement (une fois connecté) : produits, environnement, achats en attente ou faits ailleurs.
    func start(app: AppModel) {
        guard self.app == nil else { return }
        self.app = app
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await loadProducts()
            if case .verified(let transaction)? = try? await AppTransaction.shared {
                sandbox = transaction.environment != .production
            }
            for await result in Transaction.unfinished {
                await handle(result)
            }
        }
    }

    func loadProducts() async {
        guard products.count < ShopProduct.allCases.count else { return }
        let found = (try? await Product.products(for: ShopProduct.allCases.map(\.rawValue))) ?? []
        for product in found {
            if let kind = ShopProduct(rawValue: product.id) { products[kind] = product }
        }
    }

    /// Prix affiché par l'App Store (« 3,99 € »).
    func price(_ kind: ShopProduct) -> String? { products[kind]?.displayPrice }

    /// Achat. Renvoie vrai si le produit est actif à la fin.
    func purchase(_ kind: ShopProduct) async -> Bool {
        errorMessage = nil
        await loadProducts()
        guard let product = products[kind] else {
            errorMessage = "Cet achat n'est pas disponible pour l'instant. Réessaie dans un instant."
            return false
        }
        guard let user = app?.profile?.id else {
            errorMessage = BackendError.notAuthenticated.errorDescription
            return false
        }
        purchasing = kind
        defer { purchasing = nil }
        do {
            // L'identifiant du joueur voyage avec l'achat : le serveur ne l'accepte que pour ce compte.
            switch try await product.purchase(options: [.appAccountToken(user)]) {
            case .success(let result):
                let ok = await handle(result)
                if ok { app?.track(kind == .passPlus ? "pass_buy" : "shop_buy", ["product": kind.rawValue]) }
                return ok
            case .pending:
                errorMessage = "Achat en attente d'approbation. Il s'activera tout seul ensuite."
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

    /// « Restaurer mes achats » : les achats pas encore validés (réseau coupé) et « Sans pub pour toujours » sont renvoyés
    /// au serveur, puis l'état est relu. Tout est lié au compte Brainlix : sur un autre iPhone, il suffit de se connecter.
    func restore() async {
        errorMessage = nil
        purchasing = .noAds
        defer { purchasing = nil }
        try? await AppStore.sync()
        for await result in Transaction.unfinished {
            await handle(result)
        }
        for await result in Transaction.currentEntitlements {
            await handle(result)
        }
        await app?.refreshPassPlus()
        if app?.noAds != true {
            errorMessage = "Aucun achat sur ce compte. Tes achats sont liés à ton compte \(Brand.name) : connecte-toi au compte avec lequel tu les as faits."
        }
    }

    /// Une transaction de l'App Store : envoyée au serveur, puis terminée s'il l'a acceptée (ou refusée pour de bon).
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result, ShopProduct(rawValue: transaction.productID) != nil, let app else { return false }
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
            errorMessage = error.userMessage("Le serveur ne répond pas. Ton achat sera validé au prochain lancement.")
            return false
        }
    }

    private static let final: Set<String> = ["wrong_account", "transaction_other_user", "revoked", "wrong_product", "wrong_app",
                                             "pass_not_on_sale"]
}
