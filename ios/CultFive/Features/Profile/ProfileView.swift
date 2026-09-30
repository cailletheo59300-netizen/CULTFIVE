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
    @State private var weeks: [WeekRecap] = []
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showShare = false
    @State private var showEloHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    portrait
                    if app.isAnonymous { AccountNudge() }
                    treeCard
                    coteCard
                    numbers
                    knowledge
                    calendar
                    WeeksRecapSection(weeks: weeks)
                    trophies
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
        .task { await load() }
    }

    private func load() async {
        await app.refreshProfile()
        let service = app.service
        async let s = try? service.skills()
        async let a = try? service.trophies()
        async let h = try? service.dailyHistory(days: 35)
        async let w = try? service.weeklyRecap(weeks: 8)
        skills = await s ?? []
        trophyOverview = await a ?? trophyOverview
        history = await h ?? []
        weeks = await w ?? []
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
        // Seuls les domaines placés comptent : une cote encore cachée ne s'affiche nulle part.
        let placedSkills = skills.filter { $0.rating.placed }
        let global = CoteCULT.global(placedSkills).map { CoteCULT(cote: $0.cote, answered: $0.answered, placed: true) }
        return HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Elo").labelCaps(.white.opacity(0.8))
                if let global, global.placed {
                    Text(global.formatted).numeral(size: 52).foregroundStyle(Color.white)
                    Text(global.rank.name).font(.cfHeadline).foregroundStyle(Color.sun)
                    if let next = global.toNextRank, let rank = global.rank.next {
                        ProgressView(value: next.progress).tint(.sun)
                            .frame(maxWidth: 200)
                            .accessibilityLabel("\(next.missing) points avant \(rank.name)")
                        Text("\(next.missing) pts avant \(rank.name)").font(.cfFootnote).foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    Text("En placement").font(.system(.title2, design: .rounded).weight(.black)).foregroundStyle(Color.white)
                    if let closest = skills.filter({ !$0.rating.placed && $0.answered > 0 }).max(by: { $0.answered < $1.answered }) {
                        PlacementSquares(done: closest.rating.placementGames, color: .sun, empty: .white.opacity(0.25), size: 12)
                        Text("\(closest.name) : \(closest.rating.placementGames)/\(CoteCULT.placementGames) parties classées. Ton rang se dévoile à la 5e.")
                            .font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Joue 5 parties classées dans un domaine pour découvrir ton rang.")
                            .font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !skills.isEmpty {
                    Text("Domaines placés : \(placedSkills.count) sur \(skills.count)")
                        .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                ForEach(CoteCULT.Rank.allCases.reversed(), id: \.self) { rank in
                    let current = global?.placed == true && global?.rank == rank
                    Text(rank.name)
                        .font(.system(.caption2, design: .rounded).weight(current ? .black : .semibold))
                        .foregroundStyle(current ? Color.sun : .white.opacity(0.55))
                }
            }
            .accessibilityHidden(true)
        }
        .padding(Space.m)
        .background(Color.popGradient, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var numbers: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            number("\(app.profile?.streak ?? 0)", "jours de série", symbol: "flame.fill", tint: Color(hex: 0xF76707))
            number("\(app.profile?.questionsAnswered ?? 0)", "réponses", symbol: "checkmark.circle.fill", tint: .brand)
            number("\(app.profile?.errorsCorrected ?? 0)", "erreurs corrigées", symbol: "checkmark.seal.fill", tint: .correct)
            number("\(app.profile?.seeds ?? 0)", Brand.currencyPlural, symbol: nil, tint: Color(hex: 0xE8A33D))
        }
    }

    /// `symbol` nil : la graine de Brainlix.
    private func number(_ value: String, _ label: String, symbol: String?, tint: Color) -> some View {
        HStack(spacing: 10) {
            Group {
                if let symbol {
                    Image(systemName: symbol).font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(tint)
                } else {
                    SeedIcon().frame(width: 15, height: 19)
                }
            }
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(label).font(.cfFootnote).foregroundStyle(Color.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .popCard(padding: 12)
        .accessibilityElement(children: .combine)
    }

    private var knowledge: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Ce que tu sais").font(.cfHeadline)
                Spacer()
                Button { showEloHelp = true } label: {
                    Label("Comment marche l'Elo", systemImage: "questionmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(Color.brand)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Comment marche l'Elo")
            }
            if skills.contains(where: { $0.answered > 0 }) {
                KnowledgeRadar(axes: skills.map { KnowledgeRadar.Axis(domainId: $0.domainId, level: $0.answered > 0 ? Double($0.level) : 0) },
                               fill: favoriteColor)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                    .popCard()
            }
            // Les cotes placées d'abord (par niveau), puis les placements les plus avancés, puis les domaines à découvrir.
            let played = skills.sorted {
                ($0.rating.placed ? 1 : 0, $0.rating.placed ? Double($0.level) : Double($0.answered))
                    > ($1.rating.placed ? 1 : 0, $1.rating.placed ? Double($1.level) : Double($1.answered))
            }
            ForEach(played) { skill in
                NavigationLink(value: skill.domainId) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(skill.name).font(.cfTitle3).foregroundStyle(Color.ink)
                            Spacer()
                            if skill.rating.placed {
                                Text(skill.rating.formatted).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                                    .foregroundStyle(Color.ink)
                            } else {
                                PlacementSquares(done: skill.rating.placementGames, color: DomainPalette.color(skill.domainId), size: 12)
                            }
                        }
                        if skill.rating.placed {
                            SkillBar(level: skill.level, reliability: skill.reliability, color: DomainPalette.color(skill.domainId))
                        }
                        HStack(alignment: .center) {
                            Text(placementLine(skill))
                                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            Spacer(minLength: Space.s)
                            if let mastery = trophyOverview?.mastery.first(where: { $0.domainId == skill.domainId }) {
                                MasteryMedals(mastery: mastery)
                            }
                        }
                    }
                    .popCard(padding: 14)
                }
                .buttonStyle(.row)
            }
        }
    }

    private func placementLine(_ skill: SkillSummary) -> String {
        if skill.rating.placed { return "\(skill.rating.rank.name) · \(skill.answered) réponses" }
        let done = skill.rating.placementGames
        let left = CoteCULT.placementGames - done
        if skill.answered == 0 { return "Pas encore joué · 5 parties classées pour ton rang" }
        return "\(done)/\(CoteCULT.placementGames) parties · encore \(left) pour découvrir ton rang"
    }

    /// Les 5 dernières semaines du 5 du jour : un trait par jour joué.
    private var calendar: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Tes rendez-vous").font(.cfHeadline)
            let byDate = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
            let days = (0..<35).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let entry = byDate[isoDate(day)]
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(fill(for: entry))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if let score = entry?.score, entry?.status == "finished" {
                                Text("\(score)").font(.system(.caption2, design: .rounded).weight(.bold))
                                    .foregroundStyle(score >= 4 ? Color.inkFixed : .white)
                            }
                        }
                        .accessibilityLabel(entry?.score.map { "\(isoDate(day)) : \($0) sur 5" } ?? "\(isoDate(day)) : non joué")
                }
            }
            let finished = history.filter { $0.status != "in_progress" && $0.score != nil }
            if !finished.isEmpty {
                let rate = Int((Double(finished.compactMap(\.score).reduce(0, +)) / Double(finished.count * 5) * 100).rounded())
                Button { showHistory = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(finished.count) rendez-vous · \(rate) % de bonnes réponses")
                                .font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                            if let best = finished.compactMap(\.top).min() {
                                Text("Meilleur jour : top \(best) % des joueurs").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                            }
                        }
                        Spacer()
                        Text("Historique").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.brand)
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.brand)
                    }
                    .popCard(padding: 12, radius: Radius.s)
                }
                .buttonStyle(.row)
            }
        }
    }

    private func fill(for entry: DailyHistoryEntry?) -> Color {
        guard let entry, entry.status == "finished", let score = entry.score else { return .hairline }
        return score >= 4 ? .sun : Color.brand.opacity(0.35 + Double(score) * 0.12)
    }

    private func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Trophées : maîtrise par domaine et exploits (vitrine).
    @ViewBuilder private var trophies: some View {
        if let trophyOverview {
            TrophiesShowcase(trophies: trophyOverview)
        }
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
