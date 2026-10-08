import SwiftUI
import CultFiveCore

/// Profil : un portrait, pas un tableau de bord. Léon aux couleurs de ton meilleur domaine, le radar de culture,
/// puis « Ce que tu sais » en cartes.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @State private var skills: [SkillSummary] = []
    @State private var trophyOverview: TrophiesOverview?
    @State private var showTree = false
    @State private var history: [DailyHistoryEntry] = []
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showShare = false
    @State private var showEloHelp = false
    @State private var showRankPath = false
    @State private var showTrophies = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    portrait
                    if app.isAnonymous { AccountNudge() }
                    treeCard
                    Button { showRankPath = true } label: { coteCard }
                        .buttonStyle(.row)
                        .accessibilityHint("Ouvre ton parcours : les rangs et ce qu'il te reste à gagner")
                    ProfileSectionTitle(title: "Tes chiffres")
                    ProfileStatsGrid(profile: app.profile, skills: skills, history: history)
                    ProfileSectionTitle(title: "Tes domaines", action: "Comment marche l'Elo ?") { showEloHelp = true }
                    ProfileDomainsList(skills: skills)
                    ProfileSectionTitle(title: "Ton mois", action: "Historique") { showHistory = true }
                    ProfileMonthCalendar(history: history)
                    if let trophyOverview {
                        ProfileSectionTitle(title: "Trophées", action: "Tout voir") { showTrophies = true }
                        ProfileTrophyShelf(trophies: trophyOverview)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.l)
            }
            .scrollIndicators(.hidden)
            .clearsTabBar()
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { DomainView(domainId: $0) }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(isPresented: $showTree) { LeonTreeScreen() }
            .navigationDestination(isPresented: $showRankPath) { RankPathView(global: CoteCULT.overall(skills)) }
            .refreshable { await load() }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { DailyHistoryDetail() }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showShare) {
            if let profile = app.profile {
                ShareSheetView(content: .profile(profile, skills: skills))
            }
        }
        .sheet(isPresented: $showEloHelp) { EloExplainerSheet() }
        .sheet(isPresented: $showTrophies) {
            if let trophyOverview {
                NavigationStack {
                    ScrollView { TrophiesShowcase(trophies: trophyOverview).padding(Space.gutter) }
                        .background(Color.paper)
                        .navigationTitle("Trophées")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
            }
        }
        .task { await load() }
    }

    private func load() async {
        await app.refreshProfile()
        let service = app.service
        async let s = try? service.skills()
        async let a = try? service.trophies()
        async let h = try? service.dailyHistory(days: 35)
        skills = await s ?? []
        trophyOverview = await a ?? trophyOverview
        history = await h ?? []
    }

    // MARK: Blocs

    private var portrait: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Spacer()
                Button { showShare = true } label: { roundIcon("square.and.arrow.up") }
                    .accessibilityLabel("Partager mon profil")
                Button { showSettings = true } label: { roundIcon("gearshape.fill") }
                    .accessibilityLabel("Réglages")
            }
            .padding(.top, Space.s)

            HStack(alignment: .bottom, spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(app.profile?.handle ?? "…").font(.cfDisplay).lineLimit(1).minimumScaleFactor(0.6)
                    if let profile = app.profile {
                        let level = XPLevel(totalXP: profile.xpTotal)
                        Text("Niveau \(level.level) · \(profile.xpTotal) XP").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        SkillBar(level: Int(level.progress * 100), reliability: 1, color: .brand)
                            .frame(maxWidth: 180)
                            .accessibilityLabel("Progression vers le niveau \(level.level + 1)")
                    }
                }
                Spacer()
                Button { showTree = true } label: {
                    Leon(color: favoriteColor, pose: .rest, curl: min(1, 0.2 + Double(app.profile?.streak ?? 0) * 0.08))
                        .frame(width: 120)
                }
                .buttonStyle(.row)
                .accessibilityHint("Ouvre l'arbre de Léon et sa tenue")
            }
        }
    }

    private func roundIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(.body, design: .rounded).weight(.bold))
            .foregroundStyle(Color.ink)
            .frame(width: 42, height: 42)
            .background(Color.paperRaised, in: Circle())
    }

    /// La couleur de Léon suit ton domaine le plus fort.
    private var favoriteColor: Color {
        guard let best = skills.filter({ $0.answered >= 5 }).max(by: { $0.level < $1.level }) else { return .brand }
        return DomainPalette.color(best.domainId)
    }

    /// Cote CULT globale : moyenne des domaines pondérée par les réponses, rang et progression vers le rang suivant.
    private var coteCard: some View {
        // Même règle que l'écran Jouer : l'Elo se voit dès la 1re partie, « provisoire » tant qu'aucun domaine n'est confirmé.
        let global = CoteCULT.overall(skills)
        let confirmed = skills.filter { $0.rating.placed }.count
        let played = skills.filter { $0.answered > 0 }.count
        return HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Elo").labelCaps(.white.opacity(0.8))
                if let global {
                    Text(global.formatted).numeral(size: 52).foregroundStyle(global.placed ? Color.white : .white.opacity(0.75))
                    if global.placed {
                        Text(global.rank.name).font(.cfHeadline).foregroundStyle(Color.sun)
                        if let next = global.toNextRank, let rank = global.rank.next {
                            ProgressView(value: next.progress).tint(.sun)
                                .frame(maxWidth: 200)
                                .accessibilityLabel("\(next.missing) points avant \(rank.name)")
                            Text("\(next.missing) pts avant \(rank.name)").font(.cfFootnote).foregroundStyle(.white.opacity(0.8))
                        }
                    } else {
                        Text("Elo provisoire").font(.cfHeadline).foregroundStyle(Color.sun)
                        Text("Il se confirme après 5 parties classées dans un domaine.")
                            .font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("1 000").numeral(size: 52).foregroundStyle(.white.opacity(0.75))
                    Text("Tout le monde part de 1 000. Joue une partie classée pour voir ton Elo bouger.")
                        .font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if played > 0 {
                    Text("Elo confirmé dans \(confirmed) domaine\(confirmed > 1 ? "s" : "") sur \(played) joué\(played > 1 ? "s" : "")")
                        .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            // L'emblème du rang ; estompé tant que l'Elo est provisoire.
            VStack(spacing: 4) {
                RankEmblem(rank: global?.placed == true ? global?.rank ?? .curious : .curious)
                    .frame(width: 96, height: 96)
                    .opacity(global?.placed == true ? 1 : 0.45)
                    .accessibilityHidden(true)
                HStack(spacing: 2) {
                    Text("Parcours")
                    Image(systemName: "chevron.right")
                }
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.sun)
            }
        }
        .padding(Space.m)
        .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Entrée vers l'arbre de Léon : l'arbre en miniature, l'étape, la jauge.
    @ViewBuilder private var treeCard: some View {
        if let tree = app.progression?.tree {
            Button { showTree = true } label: {
                HStack(spacing: Space.m) {
                    LeonTreeView(stage: tree.stage, fruits: tree.fruits).frame(width: 70, height: 70)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("L'arbre de Léon").labelCaps()
                        Text(tree.stageName).font(.cfTitle3).foregroundStyle(Color.ink)
                        if let label = tree.nextLabel {
                            ProgressView(value: tree.progress).tint(.correct).frame(maxWidth: 180)
                            Text("Nourris-le pour atteindre : \(label.lowercased())").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        } else {
                            Text("Complet, avec tous ses fruits").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.callout.weight(.heavy)).foregroundStyle(Color.inkSoft.opacity(0.6))
                }
                .popCard(padding: 14)
            }
            .buttonStyle(.row)
            .accessibilityHint("Nourrir l'arbre et habiller Léon")
        }
    }
}
