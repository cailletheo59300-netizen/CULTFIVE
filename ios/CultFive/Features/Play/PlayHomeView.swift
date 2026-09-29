import SwiftUI
import CultFiveCore

/// Jouer : compact et coloré. Une grande carte « Partie rapide », « Mes erreurs » quand il y en a, puis les domaines
/// en grille de 3 cases pleines (couleur du domaine, pictogramme, cote ou placement) : presque tout tient sur un écran.
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
                VStack(alignment: .leading, spacing: Space.l) {
                    header
                    modes
                    domainsIndex
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
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

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Jouer").font(.cfDisplay)
            Spacer()
            if let global = CoteCULT.global(skills), global.placed {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(global.formatted).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(Color.brand)
                    Text(global.rank.name).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Ton Elo : \(global.formatted), \(global.rank.name)")
            }
        }
        .padding(.top, Space.l)
    }

    private var modes: some View {
        let errors = app.profile?.activeErrors ?? 0
        return VStack(spacing: 10) {
            QuickPlayCard { playConfig = PlayConfig(mode: .quick) }
            // Plus dur ? L'entraînement libre d'un domaine, en difficulté Expert. Plus de modes « Défi » ni « Surprise ».
            if errors > 0 {
                ModePill(title: "Revoir mes erreurs", symbol: "arrow.uturn.backward", tint: Color(hex: 0x0CA678),
                         badge: "\(errors)") {
                    playConfig = PlayConfig(mode: .errors)
                }
            }
        }
    }

    private var domainsIndex: some View {
        let interests = Set(app.profile?.interests ?? [])
        return VStack(alignment: .leading, spacing: 10) {
            Text("Par domaine").font(.cfHeadline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(orderedDomains) { domain in
                    Button { setup = PlaySetupRequest(domainId: domain.id) } label: {
                        DomainTile(domain: domain, skill: skills.first { $0.domainId == domain.id },
                                   favorite: interests.contains(domain.id))
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

/// Partie rapide : grande carte violette, le geste principal de l'écran.
private struct QuickPlayCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.sun)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Partie rapide").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white)
                    Text("10 questions · tous domaines").font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(.body, design: .rounded).weight(.black))
                    .foregroundStyle(Color(hex: 0x3A1FB8))
                    .frame(width: 44, height: 44)
                    .background(Color.sun, in: Circle())
            }
            .padding(14)
            .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .shadow(color: Color(hex: 0x3A1FB8).opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.row)
        .accessibilityElement(children: .combine)
        .accessibilityHint("10 questions de tous les domaines")
    }
}

/// Mode secondaire : pastille teintée, pictogramme + titre, compteur éventuel.
private struct ModePill: View {
    let title: String
    let symbol: String
    let tint: Color
    var badge: String? = nil
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(.subheadline, design: .rounded).weight(.heavy))
                Text(title).font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .lineLimit(1).minimumScaleFactor(0.75)
                if let badge {
                    Text(badge).font(.system(.caption2, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(tint, in: Capsule())
                }
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(tint.opacity(0.13), in: Capsule())
        }
        .buttonStyle(.row)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement(children: .combine)
    }
}

/// Domaine : case pleine de la couleur du domaine, gros pictogramme, nom, cote (ou placement) en bas.
private struct DomainTile: View {
    let domain: DomainInfo
    let skill: SkillSummary?
    var favorite = false

    var body: some View {
        let color = DomainPalette.color(domain.id)
        let on = DomainPalette.onColor(domain.id)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: DomainPalette.symbol(domain.id))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(on)
                Spacer(minLength: 0)
                if favorite {
                    Image(systemName: "star.fill").font(.caption2.weight(.bold)).foregroundStyle(on.opacity(0.8))
                        .accessibilityLabel("Favori")
                }
            }
            Spacer(minLength: 6)
            Text(domain.name)
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(on)
                .lineLimit(1).minimumScaleFactor(0.7)
            status(on: on)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                color
                Image(systemName: DomainPalette.symbol(domain.id))
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(on.opacity(0.1))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 14, y: 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
        .shadow(color: color.opacity(0.28), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func status(on: Color) -> some View {
        if let skill, skill.rating.placed {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(skill.rating.formatted).font(.system(.callout, design: .rounded).weight(.black)).monospacedDigit()
                Text(skill.rating.rank.name).font(.system(.caption2, design: .rounded).weight(.bold)).opacity(0.8)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundStyle(on)
            .accessibilityLabel("Elo \(skill.rating.formatted), \(skill.rating.rank.name)")
        } else if let skill, skill.answered > 0 {
            HStack(spacing: 3) {
                ForEach(0 ..< CoteCULT.placementGames, id: \.self) { i in
                    Circle().fill(on.opacity(i < skill.rating.placementGames ? 1 : 0.3)).frame(width: 6, height: 6)
                }
                Text("\(skill.rating.placementGames)/\(CoteCULT.placementGames)")
                    .font(.system(.caption2, design: .rounded).weight(.heavy)).monospacedDigit()
                    .foregroundStyle(on.opacity(0.85))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Placement \(skill.rating.placementGames) sur \(CoteCULT.placementGames)")
        } else {
            Text("à découvrir").font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(on.opacity(0.8))
        }
    }
}
