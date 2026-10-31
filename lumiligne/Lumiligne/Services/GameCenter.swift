import Foundation
import GameKit
import LumiCore

/// Classements Game Center (gratuits, gérés par Apple, sans serveur).
/// Deux classements à créer dans App Store Connect avec ces identifiants exacts (voir `lumiligne/README.md`) :
/// - niveau atteint (classement permanent, plus haut niveau fini) ;
/// - grille du jour (classement récurrent remis à zéro chaque jour à 00:00 UTC, en secondes : le plus petit gagne).
@MainActor
@Observable
final class GameCenter {
    static let levelLeaderboard = "app.brainlix.lumiligne.level"
    static let dailyLeaderboard = "app.brainlix.lumiligne.daily"

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

    func submitLevel(_ level: Int) {
        submit(level, to: Self.levelLeaderboard)
    }

    /// Temps de la grille du jour, en secondes (pénalités d'indices comprises).
    func submitDaily(seconds: Int) {
        submit(seconds, to: Self.dailyLeaderboard)
    }

    private func submit(_ score: Int, to board: String) {
        guard authenticated, score > 0 else { return }
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
