import SwiftUI
import SpriteKit
import EchoCore

/// Écran de partie : la scène SpriteKit, et par-dessus le score, les conseils, la pause et la fin de partie.
struct GameView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    let session: GameSession

    var body: some View {
        ZStack {
            app.theme.background.ignoresSafeArea()
            SpriteView(scene: session.scene, preferredFramesPerSecond: 120, options: [.allowsTransparency, .ignoresSiblingOrder])
                .ignoresSafeArea()
            hud
            if session.paused { PauseOverlay(session: session) }
            if session.isOver { GameOverOverlay(session: session) }
            if session.busy { LoadingVeil() }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: scenePhase) { _, phase in
            // L'app passe en arrière-plan en pleine manche : pause automatique.
            if phase != .active, session.phase == .playing { session.paused = true }
        }
    }

    /// Multiplicateur (×2 à ×5), de plus en plus chaud.
    private struct MultiplierBadge: View {
        let value: Int

        private var color: Color {
            switch value {
            case ..<3: Theme.accent
            case 3: Theme.gold
            case 4: .orange
            default: Theme.ghost
            }
        }

        var body: some View {
            Text("×\(value)")
                .font(Theme.title(20 + CGFloat(value) * 2))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.9), radius: 8 + CGFloat(value) * 2)
                .opacity(value > 1 ? 1 : 0)
                .scaleEffect(value > 1 ? 1 : 0.4)
                .animation(.spring(duration: 0.3, bounce: 0.5), value: value)
                .frame(height: 30)
        }
    }

    private var hud: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Button {
                    app.haptics.tap()
                    session.paused = true
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.card))
                }
                .opacity(session.isOver ? 0 : 1)
                Spacer()
                VStack(spacing: 2) {
                    Text(session.mode == .daily ? "DÉFI DU JOUR · MANCHE \(session.round)" : "MANCHE \(session.round)")
                        .font(Theme.body(13, .bold))
                        .foregroundStyle(Theme.secondary)
                        .tracking(1.5)
                    Text("\(session.score)")
                        .font(Theme.title(40))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: session.score)
                    MultiplierBadge(value: session.multiplier)
                }
                .allowsHitTesting(false)
                Spacer()
                Spacer().frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ZStack {
                if let toast = session.toast {
                    Text(toast.text)
                        .font(Theme.title(26))
                        .foregroundStyle(toast.color)
                        .shadow(color: toast.color.opacity(0.8), radius: 10)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .frame(height: 40)
            .animation(.spring(duration: 0.25), value: session.toast)
            .allowsHitTesting(false)

            Spacer()

            if let hint = session.hint {
                Text(hint)
                    .font(Theme.body(17))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(.bottom, 60)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(!session.isOver)
        .animation(.easeInOut(duration: 0.2), value: session.hint)
    }
}

// MARK: Pause

private struct PauseOverlay: View {
    @Environment(AppModel.self) private var app
    let session: GameSession

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Pause").font(Theme.title(36)).foregroundStyle(Theme.text)
                Text("Score : \(session.score)").font(Theme.body(17)).foregroundStyle(Theme.secondary)
                Button("Reprendre") {
                    app.haptics.tap()
                    session.paused = false
                }
                .buttonStyle(GlowButtonStyle())
                .padding(.top, 10)
                Button("Abandonner") {
                    session.quit()
                    Task { await app.leaveGame { app.goHome() } }
                }
                .buttonStyle(GlowButtonStyle(color: Theme.ghost, filled: false))
            }
            .padding(28)
        }
    }
}

// MARK: Fin de partie

private struct GameOverOverlay: View {
    @Environment(AppModel.self) private var app
    let session: GameSession
    @State private var appeared = false
    /// « Toucher l'écran pour rejouer » n'est actif qu'après un court instant : le doigt encore posé au moment de la
    /// mort ne relance pas une partie par erreur.
    @State private var tapToReplay = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.62 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard tapToReplay, session.mode == .classic, !session.busy else { return }
                    replayClassic()
                }
            VStack(spacing: 16) {
                header
                stats
                buttons
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: "#0E1330").opacity(0.96)))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
            .padding(20)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)

            if session.mode == .classic {
                VStack {
                    Spacer()
                    Text("Touche l'écran pour rejouer")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.secondary)
                        .opacity(tapToReplay ? 1 : 0)
                        .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Laisse l'explosion se voir un court instant avant d'afficher le bilan.
            withAnimation(.spring(duration: 0.35).delay(0.35)) { appeared = true }
            Task {
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeIn(duration: 0.3)) { tapToReplay = true }
            }
        }
    }

    private func replayClassic() {
        session.finalize()
        Task { await app.leaveGame { app.startClassic() } }
    }

    private var header: some View {
        VStack(spacing: 6) {
            if session.beatsRecord {
                Text("NOUVEAU RECORD !")
                    .font(Theme.body(15, .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Theme.gold)
            } else {
                Text(session.mode == .daily ? "DÉFI DU JOUR" : "PARTIE TERMINÉE")
                    .font(Theme.body(15, .heavy))
                    .tracking(1.5)
                    .foregroundStyle(Theme.secondary)
            }
            Text("\(session.score)")
                .font(Theme.title(64))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
            if session.mode == .classic {
                Text("Record : \(max(app.profile.bestScore, session.score))")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.secondary)
            } else if let best = app.profile.dailyBest {
                Text("Meilleur score du jour : \(max(best, session.score))")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.secondary)
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("\(session.result.roundsCleared)", "manches")
            stat("×\(session.result.bestMultiplier)", "multi max")
            stat("+\(session.coinsEarned)", "pièces", color: Theme.gold)
        }
        .overlay(alignment: .bottom) {
            if let reward = session.summary?.streakReward, reward > 0 {
                Text("Série de \(app.profile.streak) jour\(app.profile.streak > 1 ? "s" : "") : +\(reward) pièces")
                    .font(Theme.body(14, .bold))
                    .foregroundStyle(Theme.gold)
                    .offset(y: 26)
            }
        }
        .padding(.bottom, (session.summary?.streakReward ?? 0) > 0 ? 22 : 0)
    }

    private func stat(_ value: String, _ label: String, color: Color = Theme.text) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.title(24)).monospacedDigit().foregroundStyle(color)
            Text(label).font(Theme.body(13)).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 10) {
            if session.canContinue {
                Button {
                    Task { await session.continueWithAd() }
                } label: {
                    Label("Continuer", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(GlowButtonStyle(color: Theme.gold))
                Text("Le fantôme qui t'a touché disparaît.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.secondary)
            }
            if !session.doubled {
                Button {
                    Task { await session.doubleCoinsWithAd() }
                } label: {
                    Label("Pièces ×2", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(GlowButtonStyle(color: Theme.gold, filled: !session.canContinue))
            }
            HStack(spacing: 10) {
                Button("Accueil") {
                    session.finalize()
                    Task { await app.leaveGame { app.goHome() } }
                }
                .buttonStyle(GlowButtonStyle(color: Theme.text, filled: false))
                replayButton
            }
        }
        .disabled(session.busy || !appeared)
    }

    @ViewBuilder
    private var replayButton: some View {
        if session.mode == .classic {
            Button("Rejouer") { replayClassic() }
                .buttonStyle(GlowButtonStyle())
        } else if app.profile.dailyAttemptsLeft(day: app.today) > 0 {
            Button("Réessayer") {
                session.finalize()
                Task { await app.leaveGame { app.startDaily() } }
            }
            .buttonStyle(GlowButtonStyle())
        } else if app.profile.canEarnDailyAttempt(day: app.today) {
            Button {
                session.finalize()
                Task {
                    session.busy = true
                    let earned = await app.earnDailyAttempt()
                    session.busy = false
                    if earned { app.startDaily() }
                }
            } label: {
                Label("Réessayer", systemImage: "play.rectangle.fill")
            }
            .buttonStyle(GlowButtonStyle())
        } else {
            Button("Jouer") {
                session.finalize()
                Task { await app.leaveGame { app.startClassic() } }
            }
            .buttonStyle(GlowButtonStyle())
        }
    }
}

/// Voile pendant le chargement d'une pub.
struct LoadingVeil: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            ProgressView().tint(.white).scaleEffect(1.4)
        }
    }
}
