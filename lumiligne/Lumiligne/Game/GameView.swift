import SwiftUI
import LumiCore

/// Écran de jeu : chaîne des zones, grille, explication, commandes (Annuler, Effacer, Indice), carte de victoire.
struct GameView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    let session: GameSession

    @State private var showRules = false
    @State private var askHintAd = false
    @State private var showShop = false
    @State private var busy = false
    @State private var showWin = false

    var body: some View {
        let palette = app.palette
        ZStack {
            palette.background.ignoresSafeArea()
            VStack(spacing: 14) {
                topBar(palette)
                ChainStrip(board: session.board, palette: palette)
                    .padding(.horizontal, 16)
                BoardView(session: session, palette: palette, showSymbols: app.profile.showSymbols)
                    .padding(.horizontal, 12)
                messageLine(palette)
                Spacer(minLength: 0)
                if !session.solved { controls(palette) }
            }
            .padding(.vertical, 10)

            if showWin {
                Color.black.opacity(0.18).ignoresSafeArea().transition(.opacity)
                WinCard(session: session, busy: $busy)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if busy { LoadingVeil() }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showWin)
        .onChange(of: session.solved) { _, solved in
            guard solved else { return }
            Task {
                try? await Task.sleep(for: .seconds(Double(session.board.size) * 0.12 + 0.9))
                showWin = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.resume() } else { session.pause() }
        }
        .onAppear {
            if !app.profile.tutorialDone { showRules = true }
        }
        .sheet(isPresented: $showRules, onDismiss: { app.update { $0.tutorialDone = true } }) { RulesView() }
        .sheet(isPresented: $showShop) { ShopView(startOnOffers: true) }
        .confirmationDialog("Plus d'indice", isPresented: $askHintAd, titleVisibility: .visible) {
            if app.profile.canEarnAdHint(today: app.today) {
                Button("Regarder une pub : +1 indice") {
                    Task {
                        busy = true
                        let earned = await app.earnHint()
                        busy = false
                        if earned { session.hint() }
                    }
                }
            }
            Button("Voir les packs d'indices") { showShop = true }
            Button("Plus tard", role: .cancel) {}
        } message: {
            Text("Tu n'as plus d'indice.")
        }
    }

    // MARK: Barre du haut

    private func topBar(_ palette: Palette) -> some View {
        HStack(spacing: 12) {
            Button {
                app.haptics.tap()
                session.pause()
                app.goHome()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.text)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(palette.card))
                    .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
            }
            .accessibilityLabel("Accueil")
            VStack(alignment: .leading, spacing: 1) {
                Text(session.kind.title).font(Fonts.title(22)).foregroundStyle(palette.text)
                Text("\(session.board.size) × \(session.board.size) · \(session.board.grid.difficulty.name)")
                    .font(Fonts.body(13, .medium)).foregroundStyle(palette.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(formatTime(session.solved ? Double(session.finalSeconds) : session.elapsed(at: context.date)))
                    .font(Fonts.number(18))
                    .foregroundStyle(palette.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(palette.card))
            .overlay(Capsule().stroke(palette.stroke, lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }

    // MARK: Message

    private func messageLine(_ palette: Palette) -> some View {
        Text(session.message ?? (session.solved ? "" : "Une gemme par couleur. Les numéros qui se suivent sont alignés. Les gemmes ne se touchent pas."))
            .font(Fonts.body(15, session.message == nil ? .regular : .semibold))
            .foregroundStyle(session.messageIsError ? palette.error : (session.message == nil ? palette.secondary : palette.text))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 20)
            .animation(.easeOut(duration: 0.2), value: session.message)
    }

    // MARK: Commandes

    private func controls(_ palette: Palette) -> some View {
        HStack(spacing: 10) {
            ControlButton(palette: palette, title: "Annuler", icon: "arrow.uturn.backward") { session.undo() }
                .disabled(!session.board.canUndo)
                .opacity(session.board.canUndo ? 1 : 0.45)
            ControlButton(palette: palette, title: "Effacer", icon: "eraser") { session.clear() }
            ControlButton(palette: palette, title: "Indice", icon: "lightbulb.fill", badge: "\(app.profile.hints)", accent: true) {
                if session.hint() == .needHints { askHintAd = true }
            }
        }
        .padding(.horizontal, 16)
    }
}

/// Bouton de commande sous la grille.
private struct ControlButton: View {
    let palette: Palette
    let title: String
    let icon: String
    var badge: String?
    var accent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(title).font(Fonts.body(13, .semibold))
            }
            .foregroundStyle(accent ? Color.black.opacity(0.85) : palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(accent ? palette.beam : palette.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(accent ? .clear : palette.stroke, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(Fonts.number(13, .heavy))
                        .foregroundStyle(palette.backgroundTop)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(palette.text))
                        .offset(x: 4, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// La chaîne des zones : 1 — 2 — 3 … Chaque pastille s'allume quand sa zone a sa gemme, chaque trait quand le rayon
/// relie deux gemmes.
struct ChainStrip: View {
    let board: Board
    let palette: Palette

    var body: some View {
        let resolved = board.resolvedZones
        let links = board.links
        let n = board.size
        HStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { zone in
                if zone > 0 {
                    Capsule()
                        .fill(links[zone - 1] ? palette.beam : palette.text.opacity(0.15))
                        .frame(height: 4)
                        .shadow(color: links[zone - 1] ? palette.beam : .clear, radius: 4)
                        .animation(.easeOut(duration: 0.3), value: links[zone - 1])
                }
                Text("\(zone + 1)")
                    .font(Fonts.number(n > 7 ? 12 : 14, .heavy))
                    .foregroundStyle(Color.black.opacity(palette.dark ? 0.85 : 0.75))
                    .frame(width: n > 7 ? 26 : 30, height: n > 7 ? 26 : 30)
                    .background(Circle().fill(palette.zone(zone)))
                    .overlay(Circle().stroke(resolved[zone] ? palette.beam : palette.line.opacity(0.6), lineWidth: resolved[zone] ? 3 : 1.5))
                    .shadow(color: resolved[zone] ? palette.beam.opacity(0.7) : .clear, radius: 6)
                    .scaleEffect(resolved[zone] ? 1.08 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: resolved[zone])
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(links.filter { $0 }.count) liens sur \(max(0, n - 1))")
    }
}

/// Carte de victoire : temps, récompense, série, et la suite (niveau suivant, grille bonus, accueil).
private struct WinCard: View {
    @Environment(AppModel.self) private var app
    let session: GameSession
    @Binding var busy: Bool

    var body: some View {
        let palette = app.palette
        VStack {
            Spacer()
            VStack(spacing: 14) {
                Text(title).font(Fonts.title(30)).foregroundStyle(palette.text)
                HStack(spacing: 10) {
                    Chip(palette: palette, text: formatTime(Double(session.finalSeconds)), icon: "clock.fill")
                    if case .daily = session.kind, let reward = session.reward, reward.streak > 0 {
                        Chip(palette: palette, text: "\(reward.streak) j", icon: "flame.fill", iconColor: Color(hex: "#FF7A1A"))
                    }
                    if let reward = session.reward, reward.hints > 0 {
                        Chip(palette: palette, text: "+\(reward.hints)", icon: "lightbulb.fill")
                    }
                }
                if case .daily = session.kind, session.hintsUsed > 0 {
                    Text("Classement : +\(Economy.hintPenaltySeconds) s par indice utilisé")
                        .font(Fonts.body(13, .medium)).foregroundStyle(palette.secondary)
                }
                if let theme = session.reward?.unlockedTheme {
                    Label("Nouveau thème débloqué : \(Catalog.theme(theme).name)", systemImage: "paintpalette.fill")
                        .font(Fonts.body(15, .bold)).foregroundStyle(palette.text)
                }
                buttons(palette)
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(palette.dark ? Color(hex: palette.skin.surface) : .white))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(palette.beam.opacity(0.7), lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 6)
            .padding(16)
        }
    }

    private var title: String {
        switch session.kind {
        case .level: "Bravo !"
        case .daily: "Grille du jour réussie !"
        case .bonus: "Grille bonus réussie !"
        }
    }

    @ViewBuilder
    private func buttons(_ palette: Palette) -> some View {
        switch session.kind {
        case .level:
            Button("Niveau \(app.profile.nextLevel)") { leave { app.playNextLevel() } }
                .buttonStyle(PillButtonStyle(palette: palette, tint: palette.beam))
        case .daily:
            if app.profile.canUnlockBonus(today: app.today) {
                Button {
                    Task {
                        busy = true
                        let unlocked = await app.unlockBonus()
                        busy = false
                        if unlocked { app.playBonus() }
                    }
                } label: {
                    Label("Grille bonus", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(PillButtonStyle(palette: palette, tint: palette.beam))
            }
            Button("Niveau \(app.profile.nextLevel)") { leave { app.playNextLevel() } }
                .buttonStyle(PillButtonStyle(palette: palette, filled: false))
        case .bonus:
            Button("Niveau \(app.profile.nextLevel)") { leave { app.playNextLevel() } }
                .buttonStyle(PillButtonStyle(palette: palette, tint: palette.beam))
        }
        Button("Accueil") { leave { app.goHome() } }
            .font(Fonts.body(16, .semibold))
            .foregroundStyle(palette.secondary)
            .padding(.top, 2)
    }

    private func leave(_ next: @escaping () -> Void) {
        app.haptics.tap()
        Task {
            busy = true
            await app.leaveGame(then: next)
            busy = false
        }
    }
}
