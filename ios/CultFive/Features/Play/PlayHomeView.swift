import SwiftUI
import CultFiveCore

/// Jouer : exploration. Des modes en tête, puis le sommaire des domaines — grands titres serif colorés, pas une grille de tuiles.
struct PlayHomeView: View {
    @Environment(AppModel.self) private var app
    @State private var skills: [SkillSummary] = []
    @State private var playConfig: PlayConfig?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("Jouer").font(.cfDisplay)
                        Text("Autant que tu veux. Le niveau s'ajuste à toi.")
                            .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    }
                    .padding(.top, Space.l)

                    modes
                    domainsIndex
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { domain in
                DomainView(domainId: domain)
            }
            .refreshable { await load() }
        }
        .fullScreenCover(item: $playConfig) { config in
            PlaySessionView(config: config)
        }
        .task { await load() }
    }

    private func load() async {
        if let fresh = try? await app.service.skills() { skills = fresh }
    }

    private var modes: some View {
        VStack(alignment: .leading, spacing: 0) {
            ModeRow(title: "Partie rapide", detail: "10 questions, tous domaines.", number: "10") {
                playConfig = PlayConfig(mode: .quick)
            }
            ModeRow(title: "Mix surprise", detail: "Tu ne choisis rien. On compose.", number: "?") {
                playConfig = PlayConfig(mode: .surprise)
            }
            ModeRow(title: "Défi", detail: "Un cran au-dessus de ton niveau.", number: "+") {
                playConfig = PlayConfig(mode: .challenge)
            }
            let errors = app.profile?.activeErrors ?? 0
            ModeRow(title: "Mes erreurs", detail: errors > 0 ? "\(errors) à corriger." : "Rien à revoir pour l'instant.",
                    number: "\(errors)", isEnabled: errors > 0) {
                playConfig = PlayConfig(mode: .errors)
            }
        }
    }

    private var domainsIndex: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Par domaine").labelCaps()
            VStack(alignment: .leading, spacing: 0) {
                ForEach(orderedDomains) { domain in
                    NavigationLink(value: domain.id) {
                        DomainIndexRow(domain: domain, skill: skills.first { $0.domainId == domain.id })
                    }
                    .buttonStyle(.row)
                }
            }
        }
    }

    /// Centres d'intérêt d'abord, puis l'ordre éditorial.
    private var orderedDomains: [DomainInfo] {
        let interests = Set(app.profile?.interests ?? [])
        let domains = app.domains.isEmpty
            ? ["calc", "french", "geography", "history", "science", "logic", "arts", "sport", "cinema", "music", "tech", "nature"]
                .enumerated().map { DomainInfo(id: $0.element, name: DomainPalette.fallbackName($0.element), dailySlot: nil, sort: $0.offset) }
            : app.domains
        return domains.sorted { a, b in
            let ai = interests.contains(a.id), bi = interests.contains(b.id)
            return ai != bi ? ai : a.sort < b.sort
        }
    }
}

private struct ModeRow: View {
    let title: String
    let detail: String
    let number: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Space.m) {
                Text(number)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.cfTitle3).foregroundStyle(Color.ink)
                    Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer()
                Image(systemName: "arrow.right").font(.callout.weight(.semibold)).foregroundStyle(Color.inkSoft)
            }
            .padding(.vertical, Space.m)
            .overlay(alignment: .bottom) { Hairline() }
        }
        .buttonStyle(.row)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct DomainIndexRow: View {
    let domain: DomainInfo
    let skill: SkillSummary?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(domain.name)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(DomainPalette.color(domain.id))
            Spacer()
            if let skill, skill.answered > 0 {
                Text("\(skill.level)")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .accessibilityLabel("Niveau \(skill.level)")
            } else {
                Text("à découvrir").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Hairline() }
    }
}
