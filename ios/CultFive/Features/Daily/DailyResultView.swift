import SwiftUI
import CultFiveCore

/// Résultat du 5 du jour : le moment de satisfaction. Fond violet, score géant en jaune soleil, Léon qui réagit,
/// confettis sur un sans-faute. Peu de chiffres, bien choisis, en cartes translucides.
struct DailyResultView: View {
    let result: DailyResult
    var onReview: () -> Void
    var onShare: () -> Void
    var onClose: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var shownScore = 0
    /// Domaines dont la cote est dévoilée (placement terminé).
    @State private var placed: Set<String> = []
    /// Le rappel quotidien est proposé une seule fois, après le premier 5 du jour (jamais pendant l'onboarding).
    @AppStorage("reminderOfferAnswered") private var reminderAsked = false

    private let white = Color.white

    /// Le profil n'est rafraîchi qu'à la fermeture : il porte encore l'XP d'avant ce Daily.
    private var levelUp: Int? {
        guard let before = app.profile?.xpTotal, result.xp > 0 else { return nil }
        let old = XPLevel(totalXP: before).level, new = XPLevel(totalXP: before + result.xp).level
        return new > old ? new : nil
    }

    var body: some View {
        ZStack {
            Color.popGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    header
                    scoreBlock
                    Text(ResultCopy.headline(score: result.score, status: result.status))
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(white)
                        .fixedSize(horizontal: false, vertical: true)
                        .stagger(appeared, index: 1, reduceMotion: reduceMotion)
                    figures.stagger(appeared, index: 2, reduceMotion: reduceMotion)
                    rewards.stagger(appeared, index: 3, reduceMotion: reduceMotion)
                    knowledge.stagger(appeared, index: 4, reduceMotion: reduceMotion)
                    celebrations.stagger(appeared, index: 5, reduceMotion: reduceMotion)
                    if !reminderAsked {
                        ReminderOfferCard { reminderAsked = true }
                            .stagger(appeared, index: 6, reduceMotion: reduceMotion)
                    }
                    actions.padding(.top, Space.s)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
            if result.score == 5 || !result.achievements.isEmpty || levelUp != nil {
                Confetti().ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if let skills = try? await app.service.skills() {
                placed = Set(skills.filter { $0.rating.placed }.map(\.domainId))
            }
        }
        .onAppear {
            withAnimation(Motion.adaptive(Motion.moment, reduceMotion: reduceMotion)) { appeared = true }
            countUp()
            result.score >= 4 ? Haptics.success() : Haptics.soft()
        }
    }

    /// Le score monte de 0 à sa valeur, un cran à la fois.
    private func countUp() {
        guard !reduceMotion, result.score > 0 else { shownScore = result.score; return }
        for step in 1...result.score {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + 0.14 * Double(step)) {
                withAnimation(Motion.bounce) { shownScore = step }
                Haptics.selection()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(Brand.dailyName) · \(DateText.long(result.date))").labelCaps(white.opacity(0.7))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(.footnote, design: .rounded).weight(.heavy)).foregroundStyle(white)
                    .frame(width: 34, height: 34)
                    .background(white.opacity(0.18), in: Circle())
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Fermer")
        }
        .padding(.top, Space.s)
    }

    private var leonPose: Leon.Pose {
        switch result.score {
        case 4...: return .proud
        case 2...3: return .wave
        default: return .sad
        }
    }

    private var scoreBlock: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(shownScore)")
                        .numeral(size: 140)
                        .foregroundStyle(Color.sun)
                        .contentTransition(.numericText(value: Double(shownScore)))
                        .shadow(color: .black.opacity(0.2), radius: 0, x: 0, y: 5)
                    Text("/5")
                        .numeral(size: 48)
                        .foregroundStyle(white.opacity(0.5))
                }
                TallyMark(results: result.answers.map(\.isCorrect), onInk: true)
                    .frame(width: 80)
                    .opacity(appeared ? 1 : 0)
            }
            Spacer()
            Leon(color: Color(hex: 0xFFD23F), pose: leonPose, curl: min(1, 0.2 + Double(result.streak) * 0.08),
                 rainbow: result.score == 5)
                .frame(width: 130)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score : \(result.score) sur 5")
    }

    private var figures: some View {
        HStack(alignment: .top, spacing: 10) {
            figure(value: result.percentile?.top.map { "Top \($0) %" } ?? "—",
                   label: result.percentile?.source == .estimate ? "estimation" : "des joueurs du jour", symbol: "chart.bar.fill")
            figure(value: DurationFormat.clock(milliseconds: result.totalMs), label: "temps", symbol: "stopwatch.fill")
            figure(value: "\(result.streak)", label: result.streak > 1 ? "jours de série" : "jour de série", symbol: "flame.fill")
        }
    }

    private func figure(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).font(.callout).foregroundStyle(Color.sun)
            Text(value).font(.system(.title3, design: .rounded).weight(.heavy)).monospacedDigit().foregroundStyle(white)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.cfFootnote).foregroundStyle(white.opacity(0.65)).lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(white.opacity(0.13), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var rewards: some View {
        HStack(spacing: Space.s) {
            Text("+\(result.xp) XP").monospacedDigit()
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(white.opacity(0.16), in: Capsule())
            SeedsAmount(amount: result.seeds, signed: true, color: white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(white.opacity(0.16), in: Capsule())
            Spacer()
        }
        .font(.system(.callout, design: .rounded).weight(.heavy))
        .foregroundStyle(white)
    }

    /// Évolution de la cote CULT : seulement les mouvements notables (≥ 5 points).
    @ViewBuilder private var knowledge: some View {
        let moves = result.answers
            .compactMap { answer -> (String, Int, Int)? in
                guard let before = answer.domainBefore, let after = answer.domainAfter else { return nil }
                return (answer.domainId, CoteCULT.cote(level: before), CoteCULT.cote(level: after))
            }
            .filter { abs($0.2 - $0.1) >= 5 }
            .prefix(3)
        if !moves.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ce que ça change").labelCaps(white.opacity(0.6))
                ForEach(Array(moves.enumerated()), id: \.offset) { _, move in
                    HStack {
                        DomainTag(domainId: move.0, name: app.domainName(move.0))
                        Spacer()
                        Text(CoteCULT.format(move.2)).foregroundStyle(placed.contains(move.0) ? white : white.opacity(0.6))
                        if !placed.contains(move.0) {
                            Text("prov.").font(.cfFootnote.weight(.bold)).foregroundStyle(white.opacity(0.6))
                        }
                        Text(CoteCULT.formatDelta(move.2 - move.1))
                            .foregroundStyle(move.2 >= move.1 ? Color.sun : white.opacity(0.6))
                    }
                    .font(.system(.callout, design: .rounded).weight(.heavy).monospacedDigit())
                }
            }
            .padding(14)
            .background(white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
    }

    @ViewBuilder private var celebrations: some View {
        VStack(spacing: 10) {
            if let levelUp {
                CelebrationCard(kind: .levelUp, title: "Niveau \(levelUp)", detail: "Ton XP grimpe, continue comme ça.", onColor: true)
            }
            ForEach(result.achievements) { achievement in
                CelebrationCard(kind: .trophy, title: achievement.name, detail: achievement.description, onColor: true)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Space.s) {
            Button(action: onShare) { Label("Partager mon résultat", systemImage: "square.and.arrow.up") }
                .buttonStyle(.sun)
            HStack(spacing: Space.l) {
                Button("Revoir mes réponses", action: onReview).buttonStyle(TextLinkStyle(color: white))
                Button("Continuer", action: onClose).buttonStyle(TextLinkStyle(color: white.opacity(0.75)))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

enum ResultCopy {
    static func headline(score: Int, status: String) -> String {
        if status == "expired" { return "Temps écoulé. Les réponses données comptent." }
        switch score {
        case 5: return "Sans faute. Rien à redire."
        case 4: return "Très solide. Une seule t'a échappé."
        case 3: return "Plus de la moitié. Honnête."
        case 2: return "Deux sur cinq. Tu en sais plus qu'hier."
        case 1: return "Une bonne réponse, et cinq choses apprises."
        default: return "Zéro, mais cinq choses apprises. Demain, revanche."
        }
    }
}

enum DateText {
    private static let input: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let output: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter
    }()

    /// « samedi 26 septembre »
    static func long(_ isoDate: String) -> String {
        guard let date = input.date(from: isoDate) else { return isoDate }
        return output.string(from: date)
    }

    static func date(_ isoDate: String) -> Date? { input.date(from: isoDate) }

    private static let shortOutput: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()

    /// « 21 sept. »
    static func short(_ isoDate: String) -> String {
        guard let date = input.date(from: isoDate) else { return isoDate }
        return shortOutput.string(from: date)
    }
}

private extension View {
    /// Apparition échelonnée des blocs du résultat.
    func stagger(_ visible: Bool, index: Int, reduceMotion: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 12)
            .animation(reduceMotion ? .easeIn(duration: 0.15) : Motion.moment.delay(0.08 * Double(index)), value: visible)
    }
}

/// « Un rappel demain pour ton 5 du jour ? » : l'heure, puis Oui (demande l'autorisation de l'iPhone) ou Non merci.
/// Proposé une fois, après le premier 5 du jour ; modifiable ensuite dans Réglages.
private struct ReminderOfferCard: View {
    var onAnswered: () -> Void

    @Environment(AppModel.self) private var app
    @State private var time = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date()) ?? Date()
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Un rappel demain ?").font(.system(.title3, design: .rounded).weight(.heavy)).foregroundStyle(.white)
            Text("Une notification quand ton prochain \(Brand.dailyName) est prêt, jamais plus de deux par jour, et aucune si tu l'as déjà fait.")
                .font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Vers").font(.cfCallout.weight(.bold)).foregroundStyle(.white)
                DatePicker("Heure du rappel", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
                Spacer()
            }
            HStack(spacing: Space.s) {
                Button("Oui, me le rappeler") { Task { await answer(true) } }
                    .buttonStyle(InkButtonStyle(fill: Color.sun, text: Color(hex: 0x1E1340)))
                Button("Non merci") { Task { await answer(false) } }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(minHeight: 44)
            }
            .disabled(busy)
        }
        .padding(Space.m)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .onAppear {
            if let saved = app.profile?.notifDailyTime {
                let parts = saved.split(separator: ":").compactMap { Int($0) }
                if parts.count >= 2, let date = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) {
                    time = date
                }
            }
        }
    }

    private func answer(_ yes: Bool) async {
        busy = true
        defer { busy = false }
        Haptics.selection()
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var fields: [String: JSONValue] = ["notif_daily": .bool(yes), "notif_reminder": .bool(yes)]
        if yes {
            fields["notif_daily_time"] = .string(String(format: "%02d:%02d", parts.hour ?? 8, parts.minute ?? 30))
            let granted = await NotificationScheduler.requestAuthorization()
            app.track("notif_permission", ["granted": granted ? "yes" : "no", "from": "daily_result"])
        }
        app.track("reminder_optin", ["answer": yes ? "yes" : "no"])
        if let profile = try? await app.service.updateProfile(fields) {
            app.profile = profile
            await NotificationScheduler.refresh(profile: profile, dailyDone: true)
        }
        withAnimation(Motion.standard) { onAnswered() }
    }
}
