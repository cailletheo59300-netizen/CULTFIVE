import SwiftUI
import CultFiveCore

/// Choix de la partie dans un domaine : partie classée (adaptative, compte pour le niveau) ou entraînement libre
/// (nombre de questions, chrono, difficulté au choix, sans effet sur le niveau). Sous-thèmes : tout mélanger, un ou plusieurs.
/// Le parent lance la partie dans le `onDismiss` de la feuille (pas de présentation pendant une fermeture).
struct PlaySetupSheet: View {
    let domainId: String
    var preselected: [String] = []
    let onStart: (PlayConfig) -> Void
    var onStats: (() -> Void)? = nil

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var ranked = true
    @State private var count = 10
    @State private var timed = false
    @State private var level: PlayLevel = .adaptive
    @State private var selected: Set<String> = []
    @State private var available: [String: Int] = [:]
    @State private var skill: SkillSummary?

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
                    if themes.count > 1 { themePicker }
                    if !ranked { freeOptions }
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
            if let stats = try? await app.service.domainStats(domainId) {
                available = Dictionary(uniqueKeysWithValues: stats.subdomains.map { ($0.id, $0.available) })
            }
            skill = (try? await app.service.skills())?.first { $0.domainId == domainId }
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
        if rating.placed { return "Cote CULT \(rating.formatted) · \(rating.rank.name)" }
        return "Placement \(rating.placementGames)/\(CoteCULT.placementGames) · ta cote se dévoile après 5 parties classées"
    }

    private var kindPicker: some View {
        VStack(spacing: 10) {
            kindCard(ranked: true, title: "Partie classée", symbol: "chart.line.uptrend.xyaxis",
                     detail: "10 questions à la limite de ton niveau : environ une sur deux est un vrai défi. Ta cote CULT et tes graines évoluent.")
            kindCard(ranked: false, title: "Entraînement libre", symbol: "slider.horizontal.3",
                     detail: "Nombre de questions, chrono et difficulté au choix. Sans effet sur ta cote.")
        }
    }

    private func kindCard(ranked value: Bool, title: String, symbol: String, detail: String) -> some View {
        let on = ranked == value
        return Button {
            Haptics.selection()
            withAnimation(Motion.standard) { ranked = value }
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
        let config = PlayConfig(mode: .training, domain: domainId, subdomains: Array(selected).sorted(),
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
