import SwiftUI
import CultFiveCore

/// « Ton parcours » : les six rangs d'Elo, du Curieux à l'Encyclopédie, avec leur emblème et leurs traits du 5 du jour.
/// Rangs atteints : traits pleins. Rang en cours : ses traits se remplissent avec la jauge, le prochain clignote.
/// Rangs à venir : traits « manqués » (courts et pâles, comme une erreur au 5 du jour) et emblème grisé.
struct RankPathView: View {
    /// Elo global (nil : aucune partie classée).
    let global: CoteCULT?

    private var placed: Bool { global?.placed == true }
    private var current: CoteCULT.Rank? { placed ? global?.rank : nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header
                VStack(spacing: 0) {
                    ForEach(CoteCULT.Rank.allCases.reversed(), id: \.self) { rank in
                        row(rank)
                        if rank != .curious { connector(reached: reached(rank)) }
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xl)
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .clearsTabBar()
        .background(Color.paper)
        .navigationTitle("Ton parcours")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // MARK: En-tête : le rang actuel en grand

    private var header: some View {
        VStack(spacing: Space.s) {
            RankEmblem(rank: current ?? .curious)
                .frame(width: 132, height: 132)
                .opacity(placed ? 1 : 0.5)
                .accessibilityHidden(true)
            if let global, placed {
                Text(global.rank.name).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("Elo \(global.formatted)").font(.cfHeadline).foregroundStyle(Color.sun).monospacedDigit()
                if let next = global.toNextRank, let rank = global.rank.next {
                    ProgressView(value: next.progress).tint(.sun).frame(maxWidth: 220)
                    Text("Encore \(CoteCULT.format(next.missing)) points pour devenir \(rank.name)")
                        .font(.cfFootnote).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                } else {
                    Text("Rang maximal : bravo !").font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                }
            } else {
                Text("Elo provisoire").font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("Ton rang apparaît après 5 parties classées dans un domaine.")
                    .font(.cfFootnote).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Space.l)
        .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
        .padding(.top, Space.s)
    }

    // MARK: Échelle

    private func reached(_ rank: CoteCULT.Rank) -> Bool {
        guard let current else { return false }
        return rank <= current
    }

    private func row(_ rank: CoteCULT.Rank) -> some View {
        let isCurrent = rank == current
        let done = reached(rank)
        let state: RankTally.Progress = isCurrent ? .current(progress(rank)) : (done ? .reached : .locked)
        return HStack(spacing: Space.m) {
            RankEmblem(rank: rank)
                .frame(width: 64, height: 64)
                .saturation(done ? 1 : 0)
                .opacity(done ? 1 : 0.45)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(rank.name).font(.cfHeadline).foregroundStyle(done ? Color.ink : Color.inkSoft)
                    if isCurrent {
                        Text("TU ES ICI")
                            .font(.system(size: 10, weight: .black, design: .rounded)).tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.brand, in: Capsule())
                    }
                }
                Text(rank == .curious ? "Moins de \(CoteCULT.format(CoteCULT.Rank.amateur.floor))" : "Dès \(CoteCULT.format(rank.floor))")
                    .font(.cfFootnote).monospacedDigit().foregroundStyle(Color.inkSoft)
                if isCurrent, let global, let next = global.toNextRank {
                    Text("Encore \(CoteCULT.format(next.missing)) pts").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.brand)
                }
            }
            Spacer(minLength: 0)
            RankTally(marks: Self.marks(rank), state: state)
                .frame(width: 56, height: 50)
        }
        .padding(12)
        .background(isCurrent ? Color.paperRaised : Color.clear, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(Color.brand, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility(rank, done: done, isCurrent: isCurrent))
    }

    /// Trait vertical entre deux rangs : violet une fois atteint.
    private func connector(reached: Bool) -> some View {
        HStack {
            Capsule()
                .fill(reached ? Color.brand : Color.hairline)
                .frame(width: 4, height: 18)
                .padding(.leading, 12 + 30)
            Spacer()
        }
        .accessibilityHidden(true)
    }

    /// Avancée dans le rang en cours (0–1), vers le suivant.
    private func progress(_ rank: CoteCULT.Rank) -> Double {
        guard let global, rank == global.rank else { return 0 }
        return global.toNextRank?.progress ?? 1
    }

    /// Traits de l'emblème : 1 (Curieux) … 4 (Érudit, Expert), 5 barré (Encyclopédie).
    static func marks(_ rank: CoteCULT.Rank) -> Int {
        switch rank {
        case .curious: return 1
        case .amateur: return 2
        case .enlightened: return 3
        case .scholar, .expert: return 4
        case .encyclopedia: return 5
        }
    }

    private func accessibility(_ rank: CoteCULT.Rank, done: Bool, isCurrent: Bool) -> String {
        let floor = rank == .curious ? "moins de \(CoteCULT.format(CoteCULT.Rank.amateur.floor))" : "dès \(CoteCULT.format(rank.floor))"
        let state = isCurrent ? "ton rang actuel" : (done ? "atteint" : "pas encore atteint")
        return "\(rank.name), \(floor), \(state)"
    }
}

/// Les traits du 5 du jour d'un rang. Atteint : pleins. En cours : remplis selon la jauge, le suivant clignote.
/// À venir : « manqués », plus courts et pâles (forme et couleur, jamais la couleur seule).
private struct RankTally: View {
    enum Progress: Equatable { case reached, current(Double), locked }

    let marks: Int
    let state: Progress

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var isCurrent: Bool {
        if case .current = state { return true }
        return false
    }

    /// Traits pleins.
    private var filled: Int {
        switch state {
        case .reached: return marks
        case .locked: return 0
        case .current(let p): return min(marks, Int((Double(marks) * p).rounded(.down)))
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width * 0.1, 3)
            ZStack {
                ForEach(0 ..< marks, id: \.self) { i in
                    let on = i < filled
                    let blinking = isCurrent && i == filled
                    TallyStrokeShape(index: i)
                        .trim(from: on || blinking ? 0 : 0.3, to: on || blinking ? 1 : 0.7)
                        .stroke(color(i, on: on, blinking: blinking), style: StrokeStyle(lineWidth: width, lineCap: .round))
                        .opacity(blinking ? (pulse ? 1 : 0.3) : 1)
                }
            }
        }
        .onAppear {
            guard case .current = state, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }

    private func color(_ i: Int, on: Bool, blinking: Bool) -> Color {
        if on || blinking { return i == 4 ? Color.sun : Color.brand }
        return Color.inkSoft.opacity(0.35)
    }
}
