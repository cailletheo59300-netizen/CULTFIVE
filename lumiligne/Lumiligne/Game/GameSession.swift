import Foundation
import SwiftUI
import LumiCore

/// Une grille en cours : marques du joueur, chronomètre, indices, messages, victoire.
/// Les règles sont dans `LumiCore.Board` ; ici, on relie les gestes aux sons, vibrations, animations et sauvegardes.
@MainActor
@Observable
final class GameSession: Identifiable {
    let id = UUID()
    let kind: PuzzleKind
    private(set) var board: Board
    private(set) var hintsUsed: Int

    /// Message sous la grille (explication d'un indice ou d'une erreur).
    private(set) var message: String?
    private(set) var messageIsError = false
    /// Cases montrées par le dernier indice (et un compteur pour relancer l'animation).
    private(set) var highlight: [Int] = []
    private(set) var highlightToken = 0
    /// Zone qui vient d'être résolue (éclat), avec un compteur pour relancer l'animation.
    private(set) var flashZone: Int?
    private(set) var flashToken = 0

    private(set) var solved = false
    private(set) var reward: Reward?
    private(set) var finalSeconds = 0

    private var elapsedBefore: Double
    private var runningSince: Date?
    private weak var app: AppModel?

    init(app: AppModel, kind: PuzzleKind, grid: LumiCore.Grid, saved: SavedGrid?) {
        self.app = app
        self.kind = kind
        let marks = saved?.marks.compactMap { Mark(rawValue: $0) }
        board = Board(grid: grid, marks: marks)
        hintsUsed = saved?.hintsUsed ?? 0
        elapsedBefore = saved?.elapsed ?? 0
        runningSince = Date()
    }

    var palette: Palette { app?.palette ?? Palette(Catalog.theme(Catalog.defaultTheme)) }
    var autoCrosses: Bool { app?.profile.autoCrosses ?? true }
    var hintsLeft: Int { app?.profile.hints ?? 0 }

    // MARK: Chronomètre

    func elapsed(at now: Date = Date()) -> Double {
        elapsedBefore + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    /// L'app passe en arrière-plan : le chronomètre s'arrête et la grille est gardée.
    func pause() {
        guard let since = runningSince else { return }
        elapsedBefore += Date().timeIntervalSince(since)
        runningSince = nil
        persist()
    }

    func resume() {
        guard !solved, runningSince == nil else { return }
        runningSince = Date()
    }

    // MARK: Gestes

    func tap(_ cell: Int) {
        guard !solved else { return }
        let before = snapshot()
        let mark = board.tap(cell)
        switch mark {
        case .cross: app?.sound.play(.cross); app?.haptics.tap()
        case .gem: app?.sound.play(.gem(board.layout.zones[cell])); app?.haptics.gem()
        case .empty: app?.haptics.tap()
        }
        changed(from: before, touched: cell)
    }

    private var stroking = false

    /// Glissé du doigt : croix sur les cases vides traversées (une seule étape d'annulation).
    func stroke(_ cell: Int) {
        guard !solved else { return }
        if !stroking {
            stroking = true
            board.beginStroke()
        }
        if board.strokeCross(cell) {
            app?.sound.play(.cross)
            app?.haptics.tap()
        }
    }

    func endStroke() {
        guard stroking else { return }
        stroking = false
        clearMessage()
        persist()
    }

    func undo() {
        guard !solved, board.canUndo else { return }
        board.undo()
        app?.haptics.tap()
        clearMessage()
        persist()
    }

    func clear() {
        guard !solved else { return }
        board.clear()
        app?.haptics.tap()
        clearMessage()
        persist()
    }

    // MARK: Indices

    enum HintOutcome {
        case shown
        /// Plus d'indice : proposer la pub.
        case needHints
    }

    @discardableResult
    func hint() -> HintOutcome {
        guard !solved, let app, let hint = board.hint(autoCrosses: autoCrosses) else { return .shown }
        if !hint.isFree {
            guard app.spendHint() else { return .needHints }
            hintsUsed += 1
        }
        let before = snapshot()
        board.apply(hint)
        highlight = hint.cells
        highlightToken += 1
        message = hint.message
        messageIsError = hint.isFree
        app.sound.play(.hint)
        app.haptics.gem()
        changed(from: before, touched: nil, keepMessage: true)
        return .shown
    }

    // MARK: Après chaque changement

    private struct Snapshot {
        var resolved: [Bool]
        var links: [Bool]
    }

    private func snapshot() -> Snapshot { Snapshot(resolved: board.resolvedZones, links: board.links) }

    private func changed(from before: Snapshot, touched cell: Int?, keepMessage: Bool = false) {
        let now = snapshot()
        // Nouvelle zone résolue : éclat de la zone.
        if let zone = now.resolved.indices.first(where: { now.resolved[$0] && !before.resolved[$0] }) {
            flashZone = zone
            flashToken += 1
        }
        // Nouveau rayon entre deux gemmes.
        if let link = now.links.indices.last(where: { now.links[$0] && !before.links[$0] }) {
            app?.sound.play(.link(link))
            app?.haptics.link()
        }
        // Règle enfreinte par la gemme posée.
        if let cell, let found = board.conflict(at: cell) {
            let layout = board.layout
            message = Hint.explain(found.conflict, layout.zones[cell] + 1, layout.zones[found.other] + 1)
            messageIsError = true
            app?.sound.play(.error)
            app?.haptics.error()
        } else if !keepMessage {
            clearMessage()
        }
        if board.isSolved {
            win()
        } else {
            persist()
        }
    }

    private func clearMessage() {
        message = nil
        messageIsError = false
        highlight = []
    }

    private func persist() {
        guard !solved else { return }
        app?.keep(SavedGrid(key: kind.key, marks: board.marks.map(\.rawValue), elapsed: elapsed(), hintsUsed: hintsUsed))
    }

    private func win() {
        pause()
        solved = true
        finalSeconds = max(1, Int(elapsed().rounded()))
        highlight = []
        message = nil
        reward = app?.finish(kind, seconds: finalSeconds, hintsUsed: hintsUsed)
        app?.haptics.success()
        // L'arpège part pendant que le rayon parcourt la chaîne (voir BoardView).
        Task {
            try? await Task.sleep(for: .seconds(Double(board.size) * 0.12))
            app?.sound.play(.win)
        }
    }
}

/// « 2:07 ».
func formatTime(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return "\(total / 60):" + String(format: "%02d", total % 60)
}
