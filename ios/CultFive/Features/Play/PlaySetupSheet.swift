import SwiftUI
import CultFiveCore

/// Choix de la partie dans un domaine : partie classée (adaptative, tous les thèmes du domaine, compte pour l'Elo)
/// ou entraînement libre (thèmes, nombre de questions, chrono et difficulté au choix, sans effet sur l'Elo).
/// Le parent lance la partie dans le `onDismiss` de la feuille (pas de présentation pendant une fermeture).
struct PlaySetupSheet: View {
    let domainId: String
    var preselected: [String] = []
    let onStart: (PlayConfig) -> Void
    var onStats: (() -> Void)? = nil

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var ranked = true
    /// Survie dans ce domaine (D-078) : jusqu'à la première erreur.
    @State private var survival = false
    @State private var count = 10
    @State private var timed = false
    @State private var level: PlayLevel = .adaptive
    @State private var selected: Set<String> = []
    @State private var available: [String: Int] = [:]
    @State private var skill: SkillSummary?
    /// Classement Elo du domaine (D-079).
    @State private var board: DailyLeaderboard?

    private var color: Color { DomainPalette.color(domainId) }
    private var onColor: Color { DomainPalette.onColor(domainId) }

    /// Sous-thèmes jouables : assez de questions pour une vraie partie.
    private var themes: [SubdomainInfo] {
        app.subdomains(of: domainId).filter { (available[$0.id] ?? 0) >= 5 }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    kindPicker
                    if !ranked && !survival {
                        if themes.count > 1 { themePicker }
                        freeOptions
                    }
                    leaderboard
                }
                .padding(Space.gutter)
            }
            .scrollIndicators(.hidden)
            VStack(spacing: 4) {
                Button("C'est parti !") { start() }
                    .buttonStyle(.domain(domainId))
                if let onStats {
                    Button("Voir mes stats") { dismiss(); onStats() }.buttonStyle(TextLinkStyle(color: color))
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.s)
        }
        .background(Color.paper)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            selected = Set(preselected)
            if !preselected.isEmpty { ranked = false; survival = false }
            if let stats = try? await app.service.domainStats(domainId) {
                available = Dictionary(uniqueKeysWithValues: stats.subdomains.map { ($0.id, $0.available) })
            }
            skill = (try? await app.service.skills())?.first { $0.domainId == domainId }
            board = try? await app.service.domainLeaderboard(domain: domainId)
        }
    }

    // MARK: Blocs

    private var header: some View {
        HStack(spacing: Space.m) {
            Image(systemName: DomainPalette.symbol(domainId))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .frame(width: 54, height: 54)
                .background(onColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(app.domainName(domainId)).font(.cfHeadline).foregroundStyle(onColor)
                Text(skill.map(ratingLine) ?? " ")
                    .font(.cfFootnote).foregroundStyle(onColor.opacity(0.8))
            }
            Spacer()
        }
        .padding(Space.gutter)
        .padding(.top, Space.s)
        .background(color)
    }

    private func ratingLine(_ skill: SkillSummary) -> String {
        let rating = skill.rating
        if rating.placed { return "Elo \(rating.formatted) · \(rating.rank.name)" }
        if rating.answered == 0 { return "Elo de départ : 500 · 20 réponses classées de placement" }
        return "Elo \(rating.formatted) · \(rating.provisionalLabel)"
    }

    /// Classement Elo du domaine : podium animé, puis toi et tes voisins. Pas encore placé : ta place viendra.
    @ViewBuilder private var leaderboard: some View {
        if let board, !board.rows.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Classement").font(.cfHeadline).foregroundStyle(Color.ink)
                    Spacer()
                    Text("Elo").font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkSoft)
                }
                LeaderboardBody(entries: board.rows.map { row in
                    RankEntry(id: "\(row.rank)", rank: row.rank, handle: row.handle, score: nil, totalMs: nil, streak: nil,
                              me: row.me, elo: row.elo)
                }, style: .onPaper)
                if board.rank == nil {
                    Text("Termine ton placement (20 réponses classées) pour entrer dans le classement.")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, Space.s)
        }
    }

    private var kindPicker: some View {
        VStack(spacing: 10) {
            kindCard(ranked: true, survival: false, title: "Partie classée", symbol: "chart.line.uptrend.xyaxis",
                     detail: "10 questions sur tous les thèmes du domaine, à la limite de ton niveau. Ton Elo et tes neurones évoluent.")
            kindCard(ranked: false, survival: true, title: "Survie", symbol: "flame.fill",
                     detail: "Jusqu'à la première erreur, 20 s par question, de plus en plus dur. Bats ton record.")
            kindCard(ranked: false, survival: false, title: "Entraînement libre", symbol: "slider.horizontal.3",
                     detail: "Thèmes, nombre de questions, chrono et difficulté au choix. Sans effet sur ton Elo.")
        }
    }

    private func kindCard(ranked value: Bool, survival isSurvival: Bool, title: String, symbol: String,
                          detail: String) -> some View {
        let on = ranked == value && survival == isSurvival
        return Button {
            Haptics.selection()
            withAnimation(Motion.standard) {
                ranked = value
                survival = isSurvival
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(on ? onColor : color)
                    .frame(width: 42, height: 42)
                    .background(on ? onColor.opacity(0.2) : color.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.cfTitle3).foregroundStyle(on ? onColor : Color.ink)
                    Text(detail).font(.cfFootnote).foregroundStyle(on ? onColor.opacity(0.85) : Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold)).foregroundStyle(on ? onColor : Color.hairline)
            }
            .padding(14)
            .background(on ? color : Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .shadow(color: on ? color.opacity(0.3) : .clear, radius: 10, y: 5)
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Thèmes").labelCaps()
                Spacer()
                Text(selected.isEmpty ? "Tout mélanger" : "\(selected.count) choisi\(selected.count > 1 ? "s" : "")")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            FlowLayout(spacing: Space.s) {
                chip("Tout mélanger", on: selected.isEmpty) { selected = [] }
                ForEach(themes, id: \.id) { theme in
                    chip(theme.name, on: selected.contains(theme.id)) {
                        if selected.contains(theme.id) { selected.remove(theme.id) } else { selected.insert(theme.id) }
                    }
                }
            }
        }
    }

    private var freeOptions: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            option("Nombre de questions") {
                ForEach([5, 10, 20, 30], id: \.self) { n in chip("\(n)", on: count == n) { count = n } }
            }
            option("Chrono") {
                chip("Sans", on: !timed) { timed = false }
                chip("20 s par question", on: timed) { timed = true }
            }
            option("Difficulté") {
                ForEach(PlayLevel.allCases, id: \.self) { l in chip(PlayLevelText.name(l), on: level == l) { level = l } }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func option<Chips: View>(_ title: String, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).labelCaps()
            FlowLayout(spacing: Space.s) { chips() }
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(Motion.bounce) { action() }
        } label: {
            Text(title)
                .font(.system(.callout, design: .rounded).weight(.heavy))
                .foregroundStyle(on ? onColor : Color.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 42)
                .background(on ? color : Color.paperRaised, in: Capsule())
                .shadow(color: on ? color.opacity(0.3) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func start() {
        if survival {
            dismiss()
            onStart(PlayConfig(mode: .training, domain: domainId, ranked: false, survival: true))
            return
        }
        let config = PlayConfig(mode: .training, domain: domainId, subdomains: ranked ? [] : Array(selected).sorted(),
                                count: ranked ? 10 : count, ranked: ranked, level: ranked ? .adaptive : level,
                                timer: !ranked && timed ? 20 : nil)
        dismiss()
        onStart(config)
    }
}

/// Demande d'ouverture de la feuille de choix (domaine + sous-thèmes présélectionnés).
struct PlaySetupRequest: Identifiable {
    let id = UUID()
    let domainId: String
    var preselected: [String] = []
}
