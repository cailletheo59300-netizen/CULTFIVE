import SwiftUI
import EchoCore

/// Accueil : jouer, défi du jour, boutique, classements, réglages.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showShop = false
    @State private var showSettings = false
    @State private var busy = false

    var body: some View {
        ZStack {
            app.theme.background.ignoresSafeArea()
            EchoBackdrop(theme: app.theme)
                .ignoresSafeArea()
                .opacity(0.55)

            VStack(spacing: 0) {
                topBar
                Spacer()
                title
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        app.haptics.tap()
                        app.startClassic()
                    } label: {
                        Label("JOUER", systemImage: "play.fill")
                            .font(Theme.title(24))
                    }
                    .buttonStyle(GlowButtonStyle())

                    DailyCard(busy: $busy)

                    HStack(spacing: 12) {
                        Button {
                            app.haptics.tap()
                            showShop = true
                        } label: {
                            Label("Boutique", systemImage: "sparkles")
                        }
                        .buttonStyle(GlowButtonStyle(color: Theme.gold, filled: false))
                        Button {
                            app.haptics.tap()
                            app.gameCenter.showLeaderboards()
                        } label: {
                            Label("Classements", systemImage: "trophy.fill")
                        }
                        .buttonStyle(GlowButtonStyle(color: Theme.accent, filled: false))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            if busy { LoadingVeil() }
        }
        .sheet(isPresented: $showShop) { ShopView() }
        .onAppear { if AppModel.capture != nil { showShop = true } }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Chip(icon: "circle.hexagongrid.fill", text: "\(app.profile.coins)")
            let streak = app.profile.currentStreak(today: app.today)
            if streak > 0 {
                Chip(icon: "flame.fill", text: "\(streak)", color: .orange)
            }
            Spacer()
            Button {
                app.haptics.tap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.card))
            }
            .accessibilityLabel("Réglages")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var title: some View {
        VStack(spacing: 10) {
            Text("ÉCHO")
                .font(Theme.title(76))
                .tracking(8)
                .foregroundStyle(Theme.text)
                .shadow(color: Theme.accent.opacity(0.8), radius: 18)
                .shadow(color: Theme.ghost.opacity(0.5), radius: 30, x: 6, y: 6)
            Text("Ne touche pas ton passé.")
                .font(Theme.body(18, .medium))
                .foregroundStyle(Theme.secondary)
            if app.profile.bestScore > 0 {
                Text("Record : \(app.profile.bestScore) · manche \(app.profile.bestRound + 1)")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 6)
            }
        }
    }
}

/// Carte du défi du jour : essais restants, meilleur score du jour, temps avant le prochain défi.
private struct DailyCard: View {
    @Environment(AppModel.self) private var app
    @Binding var busy: Bool

    var body: some View {
        let day = app.today
        let left = app.profile.dailyAttemptsLeft(day: day)
        let best = app.profile.dailyDay == day ? app.profile.dailyBest : nil
        Button {
            app.haptics.tap()
            if left > 0 {
                app.startDaily()
            } else if app.profile.canEarnDailyAttempt(day: day) {
                Task {
                    busy = true
                    let earned = await app.earnDailyAttempt()
                    busy = false
                    if earned { app.startDaily() }
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.ghost)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Défi du jour")
                        .font(Theme.body(18, .bold))
                        .foregroundStyle(Theme.text)
                    Text(subtitle(left: left, best: best, day: day))
                        .font(Theme.body(14, .medium))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                if left > 0 {
                    Text(left > 1 ? "\(left) essais" : "1 essai")
                        .font(Theme.body(14, .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.ghost))
                } else if app.profile.canEarnDailyAttempt(day: day) {
                    Label("+1", systemImage: "play.rectangle.fill")
                        .font(Theme.body(14, .bold))
                        .foregroundStyle(Theme.ghost)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.ghost)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.ghost.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.ghost.opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func subtitle(left: Int, best: Int?, day: String) -> String {
        if let best { return "Ton meilleur score aujourd'hui : \(best)" }
        if left > 0 { return "Les mêmes orbes pour tout le monde" }
        return "Nouveau défi dans \(Self.countdown())"
    }

    static func countdown() -> String {
        let seconds = Int(DayKey.secondsUntilNextDay())
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes))" : "\(minutes) min"
    }
}

/// Fond animé de l'accueil : quelques fantômes qui se poursuivent.
struct EchoBackdrop: View {
    let theme: GameTheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let colors: [Color] = [Color(uiColor: theme.playerColor), Color(uiColor: theme.ghostColor),
                                       Color(uiColor: theme.ghostColor), Color(uiColor: theme.orbColor)]
                for (index, color) in colors.enumerated() {
                    let speed = 0.25 + Double(index) * 0.07
                    for step in 0..<14 {
                        let time = t * speed - Double(step) * 0.035
                        let x = size.width * (0.5 + 0.38 * sin(time * 1.3 + Double(index) * 1.7))
                        let y = size.height * (0.5 + 0.36 * sin(time * 0.9 + Double(index) * 2.3))
                        let k = 1 - Double(step) / 14
                        let r = 4 + 8 * k
                        canvas.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                                    with: .color(color.opacity(0.7 * k)))
                    }
                }
            }
            .blur(radius: 2)
        }
        .allowsHitTesting(false)
    }
}
