import SwiftUI
import CultFiveCore

/// Jouer : compact et coloré. Une grande carte « Partie rapide », la carte « Survie », « Mes erreurs » quand il y en a, puis les domaines
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
    @State private var survival = SurvivalOverview()
    @State private var showSurvival = false

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
            .clearsTabBar()
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .guidedTour(.play)
            .navigationDestination(for: String.self) { domain in
                DomainView(domainId: domain)
            }
            .refreshable { await load() }
        }
        .fullScreenCover(item: $playConfig, onDismiss: {
            // Coffres gagnés pendant la partie : ils s'ouvrent dès le retour.
            Task {
                await app.refreshProgression()
                app.openNewChests()
            }
        }) { config in
            GameCover(config: config)
        }
        .fullScreenCover(isPresented: $showSurvival, onDismiss: {
            Task {
                await load()
                await app.refreshProgression()
                app.openNewChests()
            }
        }) {
            SurvivalSessionView(overview: survival)
        }
        .sheet(item: $setup, onDismiss: {
            if let config = pendingConfig { pendingConfig = nil; playConfig = config }
            if let domain = pendingStats { pendingStats = nil; path.append(domain) }
        }) { request in
            PlaySetupSheet(domainId: request.domainId, preselected: request.preselected,
                           onStart: { pendingConfig = $0 }, onStats: { pendingStats = request.domainId })
        }
        .onChange(of: app.reselected[.play]) { path = [] }
        .onChange(of: app.pendingDomain, initial: true) { _, domain in
            // Défi « bonnes réponses en … » touché : la feuille du domaine s'ouvre.
            guard let domain else { return }
            app.pendingDomain = nil
            path = []
            setup = PlaySetupRequest(domainId: domain)
        }
        .onChange(of: app.pendingErrors, initial: true) { _, go in
            guard go else { return }
            app.pendingErrors = false
            playConfig = PlayConfig(mode: .errors)
        }
        .task {
            await load()
            #if DEBUG
            if Demo.screen == .domain { path = ["geography"] }
            #endif
        }
    }

    private func load() async {
        let service = app.service
        async let freshSkills = try? service.skills()
        async let freshSurvival = try? service.survivalOverview(domain: nil)
        if let fresh = await freshSkills { skills = fresh }
        if let fresh = await freshSurvival { survival = fresh }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Jouer").font(.cfDisplay)
            TourButton(id: .play)
            Spacer()
            if let global = CoteCULT.overall(skills) {
                // Emblème et Elo centrés l'un sur l'autre.
                if global.placed {
                    RankEmblem(rank: global.rank).frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .trailing, spacing: 0) {
                    Text(global.formatted).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(global.placed ? Color.brand : Color.inkSoft)
                    Text(global.placed ? global.rank.name : "Elo en placement").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(global.placed ? "Ton Elo : \(global.formatted), \(global.rank.name)" : "Ton Elo en placement : \(global.formatted)")
            }
        }
        .padding(.top, Space.l)
    }

    private var modes: some View {
        let errors = app.profile?.activeErrors ?? 0
        return VStack(spacing: 10) {
            QuickPlayCard { playConfig = PlayConfig(mode: .quick) }
            SurvivalCard(record: survival.record) { showSurvival = true }
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
            HStack(alignment: .firstTextBaseline) {
                Text("Par domaine").font(.cfHeadline)
                Spacer()
                Text("Classée ou entraînement").font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkSoft)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
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
                    Text("CLASSÉE · COMPTE POUR L'ELO")
                        .font(.system(size: 10, weight: .black, design: .rounded)).tracking(0.8)
                        .foregroundStyle(Color(hex: 0x1E1340))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.sun, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text("Partie rapide").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white)
                    Text("10 questions de tous les domaines, à ton niveau.")
                        .font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityHint("Partie classée : 10 questions de tous les domaines, compte pour ton Elo")
    }
}

/// Survie : carte orange, record à droite.
private struct SurvivalCard: View {
    let record: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Survie").font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(.white)
                    Text("Jusqu'à la première erreur").font(.cfFootnote).foregroundStyle(.white.opacity(0.88))
                }
                Spacer(minLength: 0)
                if record > 0 {
                    VStack(spacing: 0) {
                        Text("\(record)").font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                        Text("record").font(.system(.caption2, design: .rounded).weight(.heavy))
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(14)
            .background(LinearGradient(colors: [Color(hex: 0xFF8A3D), Color(hex: 0xE8452C)], startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .shadow(color: Color(hex: 0xE8452C).opacity(0.25), radius: 10, y: 5)
        }
        .buttonStyle(.row)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Réponds jusqu'à la première erreur, de plus en plus dur")
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
/// Domaine : case pleine de la couleur du domaine, nom en haut, emblème du rang au centre, rang et Elo en petit
/// dessous, jauge vers le rang suivant. Provisoire : emblème grisé et parties jouées ; jamais joué : « À découvrir ».
private struct DomainTile: View {
    let domain: DomainInfo
    let skill: SkillSummary?
    var favorite = false

    var body: some View {
        let color = DomainPalette.color(domain.id)
        let on = DomainPalette.onColor(domain.id)
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                if favorite {
                    Image(systemName: "star.fill").font(.system(size: 8, weight: .bold)).accessibilityLabel("Favori")
                }
                Text(domain.name).font(.system(.caption, design: .rounded).weight(.black))
                    .lineLimit(2).minimumScaleFactor(0.85).multilineTextAlignment(.center)
            }
            .foregroundStyle(on)
            content(on: on)
        }
        .padding(.horizontal, 6).padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .top)
        .background {
            ZStack(alignment: .bottomTrailing) {
                color
                Image(systemName: DomainPalette.symbol(domain.id))
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(on.opacity(0.1))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 10, y: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .shadow(color: color.opacity(0.28), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func content(on: Color) -> some View {
        if let skill, skill.rating.placed {
            let rating = skill.rating
            RankEmblem(rank: rating.rank).frame(width: 56, height: 56).accessibilityHidden(true)
            VStack(spacing: 0) {
                Text(rating.rank.name).font(.system(.caption, design: .rounded).weight(.black))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(rating.formatted).font(.system(.caption2, design: .rounded).weight(.heavy)).monospacedDigit().opacity(0.88)
            }
            .foregroundStyle(on)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(on.opacity(0.25))
                    Capsule().fill(on).frame(width: geo.size.width * (rating.toNextRank?.progress ?? 1))
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 8).padding(.top, 3)
            .accessibilityHidden(true)
        } else if let skill, skill.answered > 0 {
            RankEmblem(rank: .curious).frame(width: 56, height: 56)
                .saturation(0).opacity(0.5).accessibilityHidden(true)
            VStack(spacing: 0) {
                Text("Placement").font(.system(.caption, design: .rounded).weight(.black))
                Text("\(skill.rating.placementDone)/\(CoteCULT.placementAnswers) réponses")
                    .font(.system(.caption2, design: .rounded).weight(.heavy)).monospacedDigit().opacity(0.88)
            }
            .foregroundStyle(on)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Elo en placement, \(skill.rating.placementDone) réponses sur \(CoteCULT.placementAnswers)")
        } else {
            Spacer(minLength: 4)
            Image(systemName: "play.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(on)
                .frame(width: 34, height: 34)
                .background(on.opacity(0.22), in: Circle())
            Text("À découvrir").font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(on)
                .padding(.top, 4)
            Spacer(minLength: 4)
        }
    }
}
