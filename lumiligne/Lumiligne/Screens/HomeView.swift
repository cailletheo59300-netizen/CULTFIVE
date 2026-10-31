import SwiftUI
import LumiCore

/// Accueil : grille du jour (et grille bonus), niveau suivant, thèmes, classements, réglages.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showShop = false
    @State private var showSettings = false
    @State private var busy = false

    var body: some View {
        let palette = app.palette
        ZStack {
            palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar(palette)
                Spacer(minLength: 12)
                VStack(spacing: 6) {
                    LogoMark(palette: palette)
                        .frame(width: 150, height: 110)
                    Text("Lumiligne")
                        .font(Fonts.title(46))
                        .foregroundStyle(palette.text)
                    Text("Relie les gemmes. Ne devine jamais.")
                        .font(Fonts.body(16, .medium))
                        .foregroundStyle(palette.secondary)
                }
                Spacer(minLength: 12)
                VStack(spacing: 12) {
                    DailyCard(busy: $busy)
                    levelButton(palette)
                    HStack(spacing: 12) {
                        Button {
                            app.haptics.tap()
                            showShop = true
                        } label: {
                            Label("Thèmes", systemImage: "paintpalette.fill")
                        }
                        .buttonStyle(PillButtonStyle(palette: palette, filled: false))
                        Button {
                            app.haptics.tap()
                            app.gameCenter.showLeaderboards()
                        } label: {
                            Label("Classements", systemImage: "trophy.fill")
                        }
                        .buttonStyle(PillButtonStyle(palette: palette, filled: false))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            if busy { LoadingVeil() }
        }
        .sheet(isPresented: $showShop) { ShopView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private func topBar(_ palette: Palette) -> some View {
        HStack(spacing: 10) {
            Chip(palette: palette, text: "\(app.profile.hints)", icon: "lightbulb.fill")
                .accessibilityLabel("\(app.profile.hints) indices")
            let streak = app.profile.currentStreak(today: app.today)
            if streak > 0 {
                Chip(palette: palette, text: "\(streak)", icon: "flame.fill", iconColor: Color(hex: "#FF7A1A"))
                    .accessibilityLabel("Série de \(streak) jours")
            }
            Spacer()
            Button {
                app.haptics.tap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(palette.card))
                    .overlay(Circle().stroke(palette.stroke, lineWidth: 1))
            }
            .accessibilityLabel("Réglages")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func levelButton(_ palette: Palette) -> some View {
        let level = app.profile.nextLevel
        let started = app.profile.saved(PuzzleKind.level(level).key) != nil
        return Button {
            app.haptics.tap()
            app.playNextLevel()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(started ? "Reprendre" : "Jouer").font(Fonts.body(14, .semibold)).opacity(0.8)
                    Text("Niveau \(level)").font(Fonts.title(24))
                }
                Spacer()
                Text("\(Puzzles.levelSize(level)) × \(Puzzles.levelSize(level))")
                    .font(Fonts.number(15))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(palette.backgroundTop.opacity(0.25)))
                Image(systemName: "play.fill").font(.system(size: 20, weight: .bold))
            }
            .foregroundStyle(palette.backgroundTop)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.text))
        }
        .buttonStyle(.plain)
    }
}

/// Carte de la grille du jour : à faire / finie (temps), série, compte à rebours, grille bonus.
private struct DailyCard: View {
    @Environment(AppModel.self) private var app
    @Binding var busy: Bool

    var body: some View {
        let palette = app.palette
        let day = app.today
        let done = app.profile.dailyDone(today: day)
        let plan = Puzzles.plan(.daily(day))
        VStack(spacing: 12) {
            Button {
                app.haptics.tap()
                app.playDaily()
            } label: {
                HStack(spacing: 14) {
                    CalendarBadge(day: Int(day.suffix(2)) ?? 1, palette: palette)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Grille du jour").font(Fonts.body(18, .bold)).foregroundStyle(palette.text)
                        Text(subtitle(done: done, plan: plan))
                            .font(Fonts.body(14, .medium))
                            .foregroundStyle(palette.secondary)
                    }
                    Spacer()
                    Image(systemName: done ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(done ? palette.success : palette.beam)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if app.profile.bonusAvailable(today: day) {
                bonusButton(palette, title: "Jouer la grille bonus", ad: false)
            } else if app.profile.canUnlockBonus(today: day) {
                bonusButton(palette, title: "Grille bonus", ad: true)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.card))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(palette.beam.opacity(0.55), lineWidth: 1.5))
    }

    private func bonusButton(_ palette: Palette, title: String, ad: Bool) -> some View {
        Button {
            app.haptics.tap()
            if !ad {
                app.playBonus()
                return
            }
            Task {
                busy = true
                let unlocked = await app.unlockBonus()
                busy = false
                if unlocked { app.playBonus() }
            }
        } label: {
            HStack {
                Image(systemName: ad ? "play.rectangle.fill" : "sparkles")
                Text(title)
                Spacer()
                Text("8 × 8 · difficile").font(Fonts.body(13, .medium)).opacity(0.7)
            }
            .font(Fonts.body(15, .bold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.beam.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    private func subtitle(done: Bool, plan: Puzzles.Plan) -> String {
        if done, let time = app.profile.dailyTime {
            return "Finie en \(formatTime(Double(time))) · prochaine dans \(Self.countdown())"
        }
        let started = app.profile.saved(PuzzleKind.daily(app.today).key) != nil
        return "\(started ? "À reprendre" : "La même pour tout le monde") · \(plan.size) × \(plan.size)"
    }

    static func countdown() -> String {
        let seconds = Int(DayKey.secondsUntilNextDay())
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes))" : "\(minutes) min"
    }
}

/// Petit calendrier avec le numéro du jour.
private struct CalendarBadge: View {
    let day: Int
    let palette: Palette

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(palette.beam).frame(height: 11)
            Text("\(day)")
                .font(Fonts.number(20, .heavy))
                .foregroundStyle(Color(hex: "#1F2333"))
                .frame(maxHeight: .infinity)
        }
        .frame(width: 44, height: 46)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(palette.line.opacity(0.4), lineWidth: 1))
    }
}

/// Logo animé : trois gemmes reliées par un rayon qui se dessine, s'efface et recommence.
struct LogoMark: View {
    let palette: Palette

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 4) / 4 // 0…1 toutes les 4 secondes
            let progress = min(1, phase / 0.45)
            let fade = phase > 0.8 ? max(0, 1 - (phase - 0.8) / 0.2) : 1
            Canvas { canvas, size in
                let points = [CGPoint(x: size.width * 0.12, y: size.height * 0.3),
                              CGPoint(x: size.width * 0.62, y: size.height * 0.3),
                              CGPoint(x: size.width * 0.62, y: size.height * 0.82),
                              CGPoint(x: size.width * 0.92, y: size.height * 0.82)]
                var path = Path()
                path.move(to: points[0])
                for point in points.dropFirst() { path.addLine(to: point) }
                let drawn = path.trimmedPath(from: 0, to: progress)
                var glow = canvas
                glow.addFilter(.blur(radius: 6))
                glow.stroke(drawn, with: .color(palette.beam.opacity(0.8 * fade)), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                canvas.stroke(drawn, with: .color(palette.beam.opacity(fade)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                let colors = [palette.zone(0), palette.zone(1), palette.zone(2), palette.zone(3)]
                for (index, point) in points.enumerated() {
                    let r: CGFloat = 15
                    var gem = Path()
                    gem.move(to: CGPoint(x: point.x, y: point.y - r))
                    gem.addLine(to: CGPoint(x: point.x + r, y: point.y))
                    gem.addLine(to: CGPoint(x: point.x, y: point.y + r))
                    gem.addLine(to: CGPoint(x: point.x - r, y: point.y))
                    gem.closeSubpath()
                    canvas.fill(gem, with: .color(colors[index]))
                    canvas.stroke(gem, with: .color(palette.line), lineWidth: 2.5)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
