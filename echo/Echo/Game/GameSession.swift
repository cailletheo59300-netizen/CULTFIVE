import Foundation
import SwiftUI
import EchoCore

/// Une partie affichée : le moteur, la scène SpriteKit, et ce que l'interface (HUD, fin de partie) doit montrer.
@MainActor
@Observable
final class GameSession: Identifiable {
    let id = UUID()
    let mode: GameMode
    /// Jour du défi (défi du jour seulement) : compté pour ce jour-là, même si la partie finit après minuit.
    let day: String?
    @ObservationIgnored let engine: GameEngine
    @ObservationIgnored let scene: GameScene
    @ObservationIgnored private weak var app: AppModel?

    // Affiché par le HUD
    private(set) var round = 1
    private(set) var score = 0
    private(set) var phase: GamePhase = .ready
    private(set) var multiplier = 1
    private(set) var toast: Toast?
    var paused = false {
        didSet { scene.running = !paused }
    }

    // Fin de partie
    /// Partie comptée (pièces, record, classement) : une seule fois.
    private(set) var summary: GameSummary?
    /// Le joueur a doublé ses pièces avec une pub.
    private(set) var doubled = false
    /// Une pub est en cours de chargement.
    var busy = false
    /// Record battu (calculé à la mort, avant que la partie soit comptée).
    private(set) var beatsRecord = false

    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let color: Color
    }

    init(app: AppModel, mode: GameMode, day: String?, seed: UInt64) {
        self.app = app
        self.mode = mode
        self.day = day
        let engine = GameEngine(seed: seed, mode: mode)
        self.engine = engine
        scene = GameScene(engine: engine, theme: app.theme, controlSetting: app.profile.controlSetting)
        scene.onFrame = { [weak self] events in self?.frame(events) }
    }

    var isOver: Bool { engine.isDead }
    var canContinue: Bool { engine.canContinue && summary == nil }
    var result: GameResult { engine.result }
    var coinsEarned: Int { (summary?.coins ?? Economy.coins(for: result)) * (doubled ? 2 : 1) }

    /// Conseil affiché en bas de l'écran.
    var hint: String? {
        guard let app else { return nil }
        let tutorial = !app.profile.tutorialDone
        switch phase {
        case .ready:
            if round == 1 { return tutorial ? "Glisse ton doigt n'importe où :\nle point suit ton geste." : "Glisse pour commencer" }
            if round == 2 && tutorial { return "Ton fantôme rejoue ta manche 1.\nNe le touche pas !" }
            return "Manche \(round) · Glisse pour commencer"
        case .playing:
            if tutorial && round == 1 && engine.tick < 240 { return "Attrape les orbes, l'un après l'autre." }
            if tutorial && round == 2 && engine.tick < 120 { return "Les fantômes s'allument après un court instant." }
            if tutorial && round == 3 && engine.tick < 150 { return "Frôle un fantôme sans le toucher :\nton multiplicateur monte !" }
            if tutorial && round == 5 && engine.tick < 150 { return "Un fantôme qui pâlit vit sa dernière manche." }
            return nil
        case .transition, .dead:
            return nil
        }
    }

    // MARK: Boucle

    private func frame(_ events: [GameEvent]) {
        if round != engine.round { round = engine.round }
        if score != engine.score { score = engine.score }
        if phase != engine.phase { phase = engine.phase }
        if multiplier != engine.multiplier { multiplier = engine.multiplier }
        guard !events.isEmpty, let app else { return }
        for event in events {
            switch event {
            case .roundStarted:
                break
            case .orbCollected(let index):
                app.sound.play(.orb(index))
                app.haptics.light()
            case .roundCleared(_, let bonus):
                app.sound.play(.roundClear)
                app.haptics.success()
                show("+\(bonus)", Theme.gold)
            case .nearMiss(_, let multiplier):
                app.sound.play(.nearMiss)
                app.haptics.medium()
                show("Frôlé ! ×\(multiplier)", Theme.accent)
            case .multiplierLost:
                show("Multiplicateur perdu", Theme.secondary)
            case .died:
                app.sound.play(.death)
                app.haptics.error()
                beatsRecord = mode == .classic && engine.score > app.profile.bestScore
                // Pas de « Continuer » possible : la partie est comptée tout de suite.
                if !engine.canContinue { finalize() }
            }
        }
    }

    private func show(_ text: String, _ color: Color) {
        let toast = Toast(text: text, color: color)
        self.toast = toast
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.9))
            if self?.toast?.id == toast.id { self?.toast = nil }
        }
    }

    // MARK: Actions de fin de partie

    /// Compte la partie (une seule fois).
    func finalize() {
        guard summary == nil, let app else { return }
        summary = app.finish(engine.result, day: day)
    }

    /// « Continuer » : pub, puis la manche recommence sans le fantôme fautif.
    func continueWithAd() async {
        guard canContinue, let app else { return }
        busy = true
        let earned = await app.watchRewarded(.continueRun)
        busy = false
        guard earned, engine.continueAfterDeath() else { return }
        phase = engine.phase
        scene.restartAfterContinue()
    }

    /// « Pièces ×2 » : pub, puis les pièces de la partie sont données une deuxième fois.
    func doubleCoinsWithAd() async {
        guard !doubled, let app else { return }
        finalize()
        busy = true
        let earned = await app.watchRewarded(.doubleCoins)
        busy = false
        guard earned, let summary else { return }
        doubled = true
        app.addCoins(summary.coins)
    }

    /// Abandon depuis la pause : la partie est comptée avec le score atteint.
    func quit() {
        paused = false
        finalize()
    }
}
