import SwiftUI
import CultFiveCore

/// Profil : un portrait, pas un tableau de bord. Léon aux couleurs de ton meilleur domaine, le radar de culture,
/// puis « Ce que tu sais » en cartes.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @State private var skills: [SkillSummary] = []
    @State private var achievements: [AchievementRef] = []
    @State private var history: [DailyHistoryEntry] = []
    @State private var weeks: [WeekRecap] = []
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    portrait
                    if app.isAnonymous { AccountNudge() }
                    coteCard
                    numbers
                    knowledge
                    calendar
                    WeeksRecapSection(weeks: weeks)
                    trophies
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { DomainView(domainId: $0) }
            .refreshable { await load() }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showHistory) {
            NavigationStack { DailyHistoryDetail() }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showShare) {
            if let profile = app.profile {
                ShareSheetView(content: .profile(profile, skills: skills))
            }
        }
        .task { await load() }
    }

    private func load() async {
        await app.refreshProfile()
        let service = app.service
        async let s = try? service.skills()
        async let a = try? service.achievements()
        async let h = try? service.dailyHistory(days: 35)
        async let w = try? service.weeklyRecap(weeks: 8)
        skills = await s ?? []
        achievements = await a ?? []
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
                Leon(color: favoriteColor, pose: .rest, curl: min(1, 0.2 + Double(app.profile?.streak ?? 0) * 0.08))
                    .frame(width: 120)
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
        let global = CoteCULT.global(skills)
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
                    let answered = global?.answered ?? 0
                    Text("En placement").font(.system(.title2, design: .rounded).weight(.black)).foregroundStyle(Color.white)
                    ProgressView(value: Double(min(answered, CoteCULT.placementAnswers)), total: Double(CoteCULT.placementAnswers))
                        .tint(.sun).frame(maxWidth: 200)
                    Text("\(min(answered, CoteCULT.placementAnswers))/\(CoteCULT.placementAnswers) réponses classées avant de découvrir ton Elo.")
                        .font(.cfFootnote).foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
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
            number("\(app.profile?.seeds ?? 0)", Brand.currencyPlural, symbol: "leaf.fill", tint: Color(hex: 0x37B24D))
        }
    }

    private func number(_ value: String, _ label: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
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
            Text("Ce que tu sais").font(.cfHeadline)
            if skills.contains(where: { $0.answered > 0 }) {
                KnowledgeRadar(axes: skills.map { KnowledgeRadar.Axis(domainId: $0.domainId, level: $0.answered > 0 ? Double($0.level) : 0) },
                               fill: favoriteColor)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                    .popCard()
            }
            // Les cotes placées d'abord, puis par niveau.
            let played = skills.filter { $0.answered > 0 }.sorted {
                ($0.rating.placed ? 1 : 0, $0.level) > ($1.rating.placed ? 1 : 0, $1.level)
            }
            if played.isEmpty {
                Text("Joue quelques parties : ton profil de connaissances se dessinera ici.")
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
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
                                PlacementDots(done: skill.rating.placementGames, color: DomainPalette.color(skill.domainId), compact: true)
                            }
                        }
                        SkillBar(level: skill.level, reliability: skill.reliability, color: DomainPalette.color(skill.domainId))
                        Text(skill.rating.placed ? "\(skill.rating.rank.name) · \(skill.answered) réponses" : "\(skill.answered) réponses · placement en cours")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    .popCard(padding: 14)
                }
                .buttonStyle(.row)
            }
        }
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

    private var trophies: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Trophées").font(.cfHeadline)
            let unlocked = achievements.filter { $0.unlockedAt != nil }
            Text("\(unlocked.count) sur \(achievements.count)").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            ForEach(achievements) { achievement in
                HStack(spacing: Space.m) {
                    Image(systemName: achievement.unlockedAt != nil ? "trophy.fill" : "lock.fill")
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(achievement.unlockedAt != nil ? Color.inkFixed : Color.inkSoft.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .background(achievement.unlockedAt != nil ? Color.sun : Color.hairline, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.name).font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(achievement.unlockedAt != nil ? Color.ink : Color.inkSoft)
                        Text(achievement.description).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    Spacer()
                }
                .popCard(padding: 12)
                .opacity(achievement.unlockedAt != nil ? 1 : 0.7)
                .accessibilityElement(children: .combine)
                .accessibilityValue(achievement.unlockedAt != nil ? "débloqué" : "à débloquer")
            }
        }
    }
}
