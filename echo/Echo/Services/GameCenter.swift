import Foundation
import GameKit
import EchoCore

/// Classements Game Center (gratuits, gérés par Apple, sans serveur).
/// Deux classements à créer dans App Store Connect avec ces identifiants exacts (voir `echo/README.md`) :
/// - meilleur score en mode classique (classement permanent, « meilleur score ») ;
/// - défi du jour (classement récurrent, remis à zéro chaque jour à 00:00 UTC).
@MainActor
@Observable
final class GameCenter {
    static let classicLeaderboard = "app.brainlix.echo.classic"
    static let dailyLeaderboard = "app.brainlix.echo.daily"

    private(set) var authenticated = false

    /// Connexion silencieuse au lancement. Si le joueur n'est pas connecté à Game Center, iOS propose l'écran de
    /// connexion une fois ; en cas de refus, le jeu marche normalement, sans classement.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, _ in
            Task { @MainActor in
                if let controller, let root = AdsController.topViewController {
                    root.present(controller, animated: true)
                }
                self?.authenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    func submit(score: Int, mode: GameMode) {
        guard authenticated, score > 0 else { return }
        let board = mode == .classic ? Self.classicLeaderboard : Self.dailyLeaderboard
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board])
        }
    }

    /// Ouvre les classements de Game Center.
    func showLeaderboards() {
        if !authenticated {
            authenticate()
            return
        }
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }
}
