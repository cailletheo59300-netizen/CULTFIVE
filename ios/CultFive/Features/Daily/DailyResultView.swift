import SwiftUI
import CultFiveCore

/// Résultat du 5 du jour : le moment de satisfaction. Plein encre, score géant en chlorophylle, peu de chiffres, bien choisis.
struct DailyResultView: View {
    let result: DailyResult
    var onReview: () -> Void
    var onShare: () -> Void
    var onClose: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let paper = Color.paperFixed

    var body: some View {
        ZStack {
            Color.inkFixed.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    header
                    scoreBlock
                    Text(ResultCopy.headline(score: result.score, status: result.status))
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(paper)
                        .fixedSize(horizontal: false, vertical: true)
                        .stagger(appeared, index: 1, reduceMotion: reduceMotion)
                    Rectangle().fill(paper.opacity(0.15)).frame(height: 1)
                    figures.stagger(appeared, index: 2, reduceMotion: reduceMotion)
                    rewards.stagger(appeared, index: 3, reduceMotion: reduceMotion)
                    knowledge.stagger(appeared, index: 4, reduceMotion: reduceMotion)
                    if !result.achievements.isEmpty {
                        achievements.stagger(appeared, index: 5, reduceMotion: reduceMotion)
                    }
                    actions.padding(.top, Space.m)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(Motion.adaptive(Motion.moment, reduceMotion: reduceMotion)) { appeared = true }
            result.score >= 4 ? Haptics.success() : Haptics.soft()
        }
    }

    private var header: some View {
        HStack {
            Text("\(Brand.dailyName) · \(DateText.long(result.date))").labelCaps(paper.opacity(0.6))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(paper.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Fermer")
        }
        .padding(.top, Space.s)
    }

    private var scoreBlock: some View {
        HStack(alignment: .bottom) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(result.score)")
                    .numeral(size: 150)
                    .foregroundStyle(Color.chloro)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.8, anchor: .bottomLeading)
                Text("/5")
                    .numeral(size: 52, weight: .semibold)
                    .foregroundStyle(paper.opacity(0.45))
            }
            Spacer()
            TallyMark(results: result.answers.map(\.isCorrect), onInk: true)
                .frame(width: 92)
                .padding(.bottom, 24)
                .opacity(appeared ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score : \(result.score) sur 5")
    }

    private var figures: some View {
        HStack(alignment: .top, spacing: 0) {
            figure(value: result.percentile?.top.map { "TOP \($0) %" } ?? "—",
                   label: result.percentile?.source == .estimate ? "estimation" : "des joueurs du jour")
            figure(value: DurationFormat.clock(milliseconds: result.totalMs), label: "temps")
            figure(value: "\(result.streak)", label: result.streak > 1 ? "jours de série" : "jour de série", symbol: "flame.fill")
        }
    }

    private func figure(value: String, label: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.callout).foregroundStyle(Color.chloro) }
                Text(value).font(.system(.title2, design: .serif).weight(.bold)).monospacedDigit().foregroundStyle(paper)
                    .minimumScaleFactor(0.7).lineLimit(1)
            }
            Text(label).font(.cfFootnote).foregroundStyle(paper.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var rewards: some View {
        HStack(spacing: Space.m) {
            Text("+\(result.xp) XP").monospacedDigit()
            SeedsAmount(amount: result.seeds, signed: true, color: paper)
            Spacer()
        }
        .font(.system(.callout).weight(.semibold))
        .foregroundStyle(paper.opacity(0.8))
    }

    /// Évolution des connaissances : seulement les mouvements notables.
    @ViewBuilder private var knowledge: some View {
        let moves = result.answers
            .compactMap { answer -> (String, Double, Double)? in
                guard let before = answer.domainBefore, let after = answer.domainAfter else { return nil }
                return (answer.domainId, before, after)
            }
            .filter { abs($0.2 - $0.1) >= 0.5 }
            .prefix(3)
        if !moves.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Ce que ça change").labelCaps(paper.opacity(0.5))
                ForEach(Array(moves.enumerated()), id: \.offset) { _, move in
                    HStack {
                        Circle().fill(DomainPalette.color(move.0)).frame(width: 8, height: 8)
                        Text(app.domainName(move.0)).foregroundStyle(paper)
                        Spacer()
                        Text("\(Int(move.1.rounded())) → \(Int(move.2.rounded()))").monospacedDigit()
                            .foregroundStyle(move.2 >= move.1 ? Color.chloro : paper.opacity(0.6))
                    }
                    .font(.cfCallout)
                }
            }
        }
    }

    private var achievements: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(result.achievements) { achievement in
                HStack(spacing: Space.m) {
                    Leon(color: .chloro, pose: .proud).frame(width: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trophée débloqué").labelCaps(Color.chloro)
                        Text(achievement.name).font(.cfTitle3).foregroundStyle(paper)
                        Text(achievement.description).font(.cfFootnote).foregroundStyle(paper.opacity(0.6))
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Button("Partager mon résultat", action: onShare).buttonStyle(.chloro)
            HStack(spacing: Space.l) {
                Button("Revoir mes réponses", action: onReview).buttonStyle(TextLinkStyle(color: paper))
                Button("Continuer", action: onClose).buttonStyle(TextLinkStyle(color: paper.opacity(0.7)))
            }
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
