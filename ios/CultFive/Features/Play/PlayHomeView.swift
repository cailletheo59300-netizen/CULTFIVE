import SwiftUI
import CultFiveCore

/// Jouer : exploration. Quatre modes en cartes colorées, puis les domaines en tuiles vives avec leur niveau.
struct PlayHomeView: View {
    @Environment(AppModel.self) private var app
    @State private var skills: [SkillSummary] = []
    @State private var playConfig: PlayConfig?
    @State private var path: [String] = []
    @State private var setup: PlaySetupRequest?
    /// Choix fait dans la feuille : lancé à sa fermeture.
    @State private var pendingConfig: PlayConfig?
    @State private var pendingStats: String?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Jouer").font(.cfDisplay)
                        if let global = CoteCULT.global(skills), global.placed {
                            Text("Ta cote CULT : **\(global.formatted)** · \(global.rank.name)")
                                .font(.cfCallout).foregroundStyle(Color.inkSoft)
                        } else {
                            Text("Autant que tu veux. La difficulté s'ajuste à toi.")
                                .font(.cfCallout).foregroundStyle(Color.inkSoft)
                        }
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
        .sheet(item: $setup, onDismiss: {
            if let config = pendingConfig { pendingConfig = nil; playConfig = config }
            if let domain = pendingStats { pendingStats = nil; path.append(domain) }
        }) { request in
            PlaySetupSheet(domainId: request.domainId, preselected: request.preselected,
                           onStart: { pendingConfig = $0 }, onStats: { pendingStats = request.domainId })
        }
        .task {
            await load()
            #if DEBUG
            if Demo.screen == .domain { path = ["geography"] }
            #endif
        }
    }

    private func load() async {
        if let fresh = try? await app.service.skills() { skills = fresh }
    }

    private var modes: some View {
        let errors = app.profile?.activeErrors ?? 0
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ModeCard(title: "Partie rapide", detail: "10 questions, tous domaines", symbol: "bolt.fill",
                     colors: [Color(hex: 0x7B5CFF), Color(hex: 0x4B2FE0)]) {
                playConfig = PlayConfig(mode: .quick)
            }
            ModeCard(title: "Mix surprise", detail: "On compose pour toi", symbol: "dice.fill",
                     colors: [Color(hex: 0xFF6FA5), Color(hex: 0xE8457E)]) {
                playConfig = PlayConfig(mode: .surprise)
            }
            ModeCard(title: "Défi", detail: "Un cran au-dessus", symbol: "flame.fill",
                     colors: [Color(hex: 0xFF9A3D), Color(hex: 0xF76707)]) {
                playConfig = PlayConfig(mode: .challenge)
            }
            ModeCard(title: "Mes erreurs", detail: errors > 0 ? "\(errors) à corriger" : "Rien à revoir", symbol: "arrow.uturn.backward",
                     colors: [Color(hex: 0x2BD69A), Color(hex: 0x0CA678)], badge: errors > 0 ? "\(errors)" : nil,
                     isEnabled: errors > 0) {
                playConfig = PlayConfig(mode: .errors)
            }
        }
    }

    private var domainsIndex: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Par domaine").font(.cfHeadline)
                Text("Partie classée ou entraînement libre, à toi de choisir.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(orderedDomains) { domain in
                    Button { setup = PlaySetupRequest(domainId: domain.id) } label: {
                        DomainTile(domain: domain, skill: skills.first { $0.domainId == domain.id })
                    }
                    .buttonStyle(.row)
                    .contextMenu {
                        Button("Voir mes stats", systemImage: "chart.bar") { path.append(domain.id) }
                    }
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

/// Mode de jeu : carte en dégradé, pictogramme dans une bulle, titre gras.
private struct ModeCard: View {
    let title: String
    let detail: String
    let symbol: String
    let colors: [Color]
    var badge: String? = nil
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.22), in: Circle())
                    Spacer()
                    if let badge {
                        Text(badge).font(.system(.footnote, design: .rounded).weight(.black))
                            .foregroundStyle(colors.last ?? .brand)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(.white, in: Capsule())
                    }
                }
                Spacer(minLength: Space.s)
                Text(title).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                Text(detail).font(.cfFootnote).foregroundStyle(.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .shadow(color: (colors.last ?? .brand).opacity(isEnabled ? 0.3 : 0), radius: 10, y: 6)
        }
        .buttonStyle(.row)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .combine)
    }
}

/// Domaine : tuile blanche, pictogramme sur pastille colorée, cote CULT (ou placement en cours) et jauge.
private struct DomainTile: View {
    let domain: DomainInfo
    let skill: SkillSummary?

    var body: some View {
        let color = DomainPalette.color(domain.id)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: DomainPalette.symbol(domain.id))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(DomainPalette.onColor(domain.id))
                    .frame(width: 40, height: 40)
                    .background(color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                Spacer()
                if let skill, skill.rating.placed {
                    Text(skill.rating.formatted)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .accessibilityLabel("Cote \(skill.rating.formatted), \(skill.rating.rank.name)")
                }
            }
            Text(domain.name)
                .font(.system(.callout, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
            if let skill, skill.rating.placed {
                HStack(spacing: 6) {
                    Text(skill.rating.rank.name).font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkSoft)
                    SkillBar(level: skill.level, reliability: skill.reliability, color: color)
                }
            } else if let skill, skill.answered > 0 {
                PlacementDots(done: skill.rating.placementGames, color: color, compact: true)
            } else {
                Text("à découvrir").font(.cfFootnote).foregroundStyle(Color.inkSoft).frame(height: 10)
            }
        }
        .popCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
