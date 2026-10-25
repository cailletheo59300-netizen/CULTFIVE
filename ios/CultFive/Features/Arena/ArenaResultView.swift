import SwiftUI
import CultFiveCore

/// Bilan d'un duel classé : victoire, défaite ou égalité (points, coffres, classement de la semaine), ou « Ton duel
/// est en jeu » quand personne ne l'a encore joué (jamais « en attente de joueurs »).
struct ArenaResultView: View {
    let result: ArenaDuelResult
    let me: String
    let onNext: () -> Void
    let onClose: () -> Void

    @State private var shown = false

    private var duel: ArenaDuel { result.duel }

    private var title: String {
        switch duel.winner {
        case "me": return "Victoire"
        case "opponent": return "Défaite"
        case "draw": return "Égalité"
        default: return duel.opponent == nil ? "Ton duel est en jeu" : "Ton adversaire joue"
        }
    }

    var body: some View {
        ZStack {
            ArenaPalette.night.ignoresSafeArea()
            if duel.winner == "me" { Confetti().ignoresSafeArea().allowsHitTesting(false) }
            ScrollView {
                VStack(spacing: Space.l) {
                    Text(title)
                        .font(.system(size: duel.isFinished ? 46 : 32, weight: .black, design: .rounded))
                        .foregroundStyle(duel.winner == "me" ? Color.sun : .white)
                        .multilineTextAlignment(.center)
                        .scaleEffect(shown ? 1 : 0.6)
                        .opacity(shown ? 1 : 0)
                        .padding(.top, Space.xl)
                    faceOff
                    if duel.isFinished {
                        pointsCard
                        bonuses
                    } else {
                        waitingCard
                    }
                    answersCard
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button(action: onNext) { Text(duel.isFinished ? "Duel suivant" : "Lancer un autre duel") }
                        .buttonStyle(.sun)
                    Button("Retour à l'Arène", action: onClose)
                        .buttonStyle(TextLinkStyle(color: .white))
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.s)
                .background(ArenaPalette.nightTop.opacity(0.001))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { shown = true }
            if duel.winner == "me" { Haptics.success() }
        }
    }

    // MARK: Face à face

    private var faceOff: some View {
        HStack(spacing: 0) {
            side(handle: me, me: true, score: duel.me.score, champion: false)
            VStack(spacing: 2) {
                Text(scoreLine)
                    .font(.system(size: 44, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white)
                Text("bonnes réponses").font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(minWidth: 110)
            if let opponent = duel.opponent {
                side(handle: opponent.handle, me: false, score: opponent.score, champion: opponent.champion)
            } else {
                VStack(spacing: 6) {
                    Circle().strokeBorder(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                        .overlay(Text("?").font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.8)))
                        .frame(width: 64, height: 64)
                    Text("à venir").font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var scoreLine: String {
        let theirs = duel.opponent?.score.map(String.init) ?? "?"
        return "\(duel.me.score) – \(theirs)"
    }

    private func side(handle: String, me: Bool, score: Int?, champion: Bool) -> some View {
        let won = (duel.winner == "me") == me && duel.winner != nil && duel.winner != "draw"
        return VStack(spacing: 6) {
            ArenaAvatar(handle: handle, size: 64, ring: won ? Color.sun : .white.opacity(0.6), me: me)
                .overlay(alignment: .top) { if champion { ArenaCrown(size: 26).offset(y: -20) } }
            Text(me ? "Toi" : handle).font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Points

    private var pointsCard: some View {
        let points = duel.result?.points ?? 0
        let streak = duel.result?.streak ?? 0
        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(points > 0 ? "+\(points)" : "0")
                    .font(.system(size: 52, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(points > 0 ? Color.sun : .white)
                Text(points > 1 ? "points" : "point").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white)
            }
            Text(pointsDetail(points: points, streak: streak))
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            if let week = result.week {
                Divider().overlay(Color.white.opacity(0.15))
                HStack {
                    Text("Ta semaine").font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text("\(week.points) pts").font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(.white)
                    if week.eligible {
                        Text(ArenaClock.ordinal(week.rank))
                            .font(.system(.subheadline, design: .rounded).weight(.black))
                            .foregroundStyle(Color.inkFixed)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Color.sun, in: Capsule())
                    }
                }
                if !week.eligible {
                    Text("Encore \(max(5 - week.duels, 1)) duel\(5 - week.duels > 1 ? "s" : "") cette semaine pour entrer au classement des récompenses")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.sun)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func pointsDetail(points: Int, streak: Int) -> String {
        switch duel.result?.outcome ?? "" {
        case "win" where streak >= 3: return "Victoire (+3) et série de \(streak) victoires (+1)"
        case "win": return streak > 1 ? "Victoire · \(streak) victoires de suite" : "Victoire"
        case "draw": return "Égalité : même score et même temps"
        default: return "Défaite : tu ne perds aucun point. À la prochaine !"
        }
    }

    // MARK: Coffres

    @ViewBuilder private var bonuses: some View {
        let bonus = duel.result?.bonus ?? []
        VStack(spacing: 10) {
            ForEach(bonus, id: \.self) { kind in
                HStack(spacing: 14) {
                    ChestView(tier: kind == "arena_chest" ? .gold : .silver).frame(width: 58, height: 58)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind == "arena_chest" ? "Coffre d'Arène gagné !" : "Coffre d'argent gagné !")
                            .font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(.white)
                        Text(bonusDetail(kind)).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.sun.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.sun.opacity(0.6), lineWidth: 1.5))
            }
            // Jauge du coffre d'Arène (toutes les 10 victoires).
            if !bonus.contains("arena_chest") {
                HStack(spacing: 12) {
                    ChestView(tier: .gold).frame(width: 40, height: 40).opacity(0.9)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Coffre d'Arène").font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(.white)
                            Spacer()
                            Text("\(result.chestProgress)/\(result.chestEvery) victoires")
                                .font(.system(.caption, design: .rounded).weight(.black)).monospacedDigit().foregroundStyle(.white.opacity(0.8))
                        }
                        ProgressBarLine(value: Double(result.chestProgress) / Double(max(result.chestEvery, 1)))
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func bonusDetail(_ kind: String) -> String {
        switch kind {
        case "daily_chest": return "1er duel gagné aujourd'hui"
        case "streak_chest": return "5 victoires de suite"
        default: return "10 victoires : carte rare ou mieux à l'intérieur"
        }
    }

    // MARK: En jeu

    private var waitingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            step(1, duel.opponent == nil ? "Ton duel est ouvert à toute l'Arène" : "\(duel.opponent?.handle ?? "Ton adversaire") a pris ton duel")
            step(2, duel.opponent == nil ? "Le premier joueur qui lance un duel classé tombe sur toi"
                                         : "Il répond aux mêmes questions en ce moment")
            step(3, "Tu reçois le résultat et tes points dès qu'il a fini")
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill").foregroundStyle(Color.sun)
                Text("On te prévient par notification").font(.system(.footnote, design: .rounded).weight(.bold)).foregroundStyle(.white)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundStyle(Color.inkFixed)
                .frame(width: 26, height: 26)
                .background(Color.sun, in: Circle())
            Text(text).font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Réponses

    private var answersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Question par question").labelCaps(.white.opacity(0.6))
            answerRow("Toi", marks: result.myAnswers, me: true)
            if let theirs = result.theirAnswers, let opponent = duel.opponent {
                answerRow(opponent.handle, marks: theirs, me: false)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func answerRow(_ name: String, marks: [Duel.Mark], me: Bool) -> some View {
        HStack(spacing: 10) {
            Text(name).font(.system(.footnote, design: .rounded).weight(.black)).foregroundStyle(.white)
                .lineLimit(1).frame(width: 80, alignment: .leading)
            HStack(spacing: 5) {
                ForEach(1...duel.total, id: \.self) { position in
                    let mark = marks.first { $0.position == position }
                    ZStack {
                        Circle().fill(mark.map { ($0.isCorrect ?? false) ? Color.correct : Color.wrong } ?? Color.white.opacity(0.15))
                        if let mark {
                            Image(systemName: (mark.isCorrect ?? false) ? "checkmark" : "xmark")
                                .font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) : \(marks.filter { $0.isCorrect == true }.count) bonnes réponses")
    }
}

/// Barre de progression arrondie, jaune sur fond translucide.
struct ProgressBarLine: View {
    let value: Double
    var fill: Color = .sun
    var track: Color = .white.opacity(0.18)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill).frame(width: max(proxy.size.width * min(max(value, 0), 1), value > 0 ? 8 : 0))
            }
        }
        .frame(height: 8)
    }
}
