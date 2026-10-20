import SwiftUI
import StoreKit
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
    @Environment(\.requestReview) private var requestReview
    @State private var appeared = false
    @State private var shownScore = 0
    /// Domaines dont la cote est dévoilée (placement terminé).
    @State private var placed: Set<String> = []
    /// Classement du jour : déjà chargé pendant la correction, ou gardé sur le téléphone (D-080).
    @State private var boardLoaded = false
    /// Moments forts (niveau, record de série, trophées), fêtés en plein écran une seule fois.
    @State private var celebrations: [Celebration] = []
    @State private var celebrated = false

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
                    DailyLeaderboardCard(result: result, board: Leaderboards.shared.board(Leaderboards.daily(result.date)),
                                         loaded: boardLoaded)
                        .stagger(appeared, index: 2, reduceMotion: reduceMotion)
                    rewards.stagger(appeared, index: 3, reduceMotion: reduceMotion)
                    if result.seeds > 0 {
                        DoubleSeedsButton(ref: "daily:\(result.runId.uuidString.lowercased())", onInk: true)
                    }
                    knowledge.stagger(appeared, index: 4, reduceMotion: reduceMotion)
                    actions.padding(.top, Space.s)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
            if result.score == 5 {
                Confetti().ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Binding(get: { !celebrations.isEmpty }, set: { if !$0 { celebrations = [] } })) {
            CelebrationSequence(items: celebrations) { celebrations = [] }
        }
        .task {
            if !celebrated {
                celebrated = true
                ReviewPrompt.noteActiveDay()
                let items = await moments()
                // Après l'apparition du score : le résultat d'abord, puis la fête.
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                celebrations = items
                // Bon moment, sans fête en cours : la demande de note d'Apple (une fois, joueur actif 3 jours).
                if items.isEmpty, result.score >= 4, ReviewPrompt.isDue {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    ReviewPrompt.markAsked()
                    requestReview()
                }
            }
            if let skills = try? await app.service.skills() {
                placed = Set(skills.filter { $0.rating.placed }.map(\.domainId))
            }
        }
        .task {
            await Leaderboards.shared.refreshDaily(app.service, date: result.date, maxAge: 30)
            boardLoaded = true
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

    /// Évolution de l'Elo (le serveur renvoie l'Elo dans l'unité « niveau ») : seulement les domaines placés,
    /// et seulement les mouvements notables (≥ 5 points).
    @ViewBuilder private var knowledge: some View {
        let moves = result.answers
            .compactMap { answer -> (String, Int, Int)? in
                guard let before = answer.domainBefore, let after = answer.domainAfter else { return nil }
                return (answer.domainId, CoteCULT.cote(level: before), CoteCULT.cote(level: after))
            }
            .filter { placed.contains($0.0) && abs($0.2 - $0.1) >= 5 }
            .prefix(3)
        if !moves.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ce que ça change").labelCaps(white.opacity(0.6))
                ForEach(Array(moves.enumerated()), id: \.offset) { _, move in
                    HStack {
                        DomainTag(domainId: move.0, name: app.domainName(move.0))
                        Spacer()
                        Text(CoteCULT.format(move.2)).foregroundStyle(white)
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

    /// Les moments forts à fêter en plein écran : niveau, record de série, trophées. Le profil porte encore les
    /// valeurs d'avant ce Daily (XP, meilleure série, jokers).
    private func moments() async -> [Celebration] {
        await app.refreshProgression()
        let chests = app.progression?.chests ?? []
        var items: [Celebration] = []
        if let levelUp {
            let chest = chests.first { $0.source == "level" && $0.ref == "\(levelUp)" } ?? chests.first { $0.source == "level" }
            items.append(.level(levelUp, xp: result.xp, chest: chest?.tier))
        }
        if let profile = app.profile, result.streak >= 3, result.streak > profile.streakBest {
            // Un joker tous les 7 jours d'affilée, 2 au plus.
            let joker = result.streak.isMultiple(of: 7) && profile.streakFreezes < 2
            items.append(.streak(result.streak, joker: joker))
        }
        let trophyChest = chests.first { $0.source == "trophy" }?.tier
        for achievement in result.achievements {
            items.append(.trophy(name: achievement.name, detail: achievement.description, chest: trophyChest))
        }
        return items
    }

    private var actions: some View {
        VStack(spacing: Space.s) {
            // Le 5 du jour fini, on enchaîne : direction l'onglet Jouer (D-089).
            Button {
                app.tab = .play
                onClose()
            } label: {
                Label("Continuer à jouer", systemImage: "play.fill")
            }
            .buttonStyle(.sun)
            Button(action: onShare) { Label("Partager mon résultat", systemImage: "square.and.arrow.up") }
                .buttonStyle(.inverted)
            HStack(spacing: Space.l) {
                Button("Revoir mes réponses", action: onReview).buttonStyle(TextLinkStyle(color: white))
                Button("Fermer", action: onClose).buttonStyle(TextLinkStyle(color: white.opacity(0.75)))
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
