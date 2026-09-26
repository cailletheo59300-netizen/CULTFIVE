import SwiftUI
import CultFiveCore

/// Profil : un portrait, pas un tableau de bord. Léon, le pseudo, puis « Ce que tu sais » comme un sommaire.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @State private var skills: [SkillSummary] = []
    @State private var achievements: [AchievementRef] = []
    @State private var history: [DailyHistoryEntry] = []
    @State private var showSettings = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    portrait
                    if app.isAnonymous { AccountNudge() }
                    numbers
                    knowledge
                    calendar
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
        skills = await s ?? []
        achievements = await a ?? []
        history = await h ?? []
    }

    // MARK: Blocs

    private var portrait: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Spacer()
                Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Partager mon profil")
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Réglages")
                    .padding(.leading, Space.m)
            }
            .font(.title3)
            .foregroundStyle(Color.ink)
            .padding(.top, Space.m)

            HStack(alignment: .bottom, spacing: Space.m) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(app.profile?.handle ?? "…").font(.cfDisplay).lineLimit(1).minimumScaleFactor(0.6)
                    if let profile = app.profile {
                        let level = XPLevel(totalXP: profile.xpTotal)
                        Text("Niveau \(level.level) · \(profile.xpTotal) XP").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                        ProgressView(value: level.progress)
                            .tint(Color.ink)
                            .frame(maxWidth: 180)
                            .accessibilityLabel("Progression vers le niveau \(level.level + 1)")
                    }
                }
                Spacer()
                Leon(color: favoriteColor, pose: .rest).frame(width: 110)
            }
        }
    }

    /// La couleur de Léon suit ton domaine le plus fort.
    private var favoriteColor: Color {
        guard let best = skills.filter({ $0.answered >= 5 }).max(by: { $0.level < $1.level }) else { return .chloro }
        return DomainPalette.color(best.domainId)
    }

    private var numbers: some View {
        HStack(alignment: .top, spacing: 0) {
            number("\(app.profile?.streak ?? 0)", "série", symbol: "flame.fill")
            number("\(app.profile?.questionsAnswered ?? 0)", "réponses")
            number("\(app.profile?.errorsCorrected ?? 0)", "erreurs corrigées")
            number("\(app.profile?.seeds ?? 0)", Brand.currencyPlural, symbol: "leaf.fill")
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func number(_ value: String, _ label: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                if let symbol { Image(systemName: symbol).font(.caption) }
                Text(value).font(.system(.title3, design: .serif).weight(.bold)).monospacedDigit()
            }
            Text(label).font(.cfFootnote).foregroundStyle(Color.inkSoft).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var knowledge: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Ce que tu sais").font(.cfHeadline)
            let played = skills.filter { $0.answered > 0 }.sorted { $0.level > $1.level }
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
                            Text("\(skill.level)").font(.system(.title3, design: .serif).weight(.bold)).monospacedDigit()
                                .foregroundStyle(Color.ink)
                        }
                        SkillBar(level: skill.level, reliability: skill.reliability, color: DomainPalette.color(skill.domainId))
                        Text("\(skill.answered) réponses · fiabilité \(Reliability(skill.reliability).label)")
                            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    .padding(.vertical, Space.s)
                }
                .buttonStyle(.row)
            }
        }
    }

    /// Les 5 dernières semaines du 5 du jour : un trait par jour joué.
    private var calendar: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Tes rendez-vous").labelCaps()
            let byDate = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
            let days = (0..<35).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let entry = byDate[isoDate(day)]
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fill(for: entry))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if let score = entry?.score, entry?.status == "finished" {
                                Text("\(score)").font(.system(.caption2, design: .serif).weight(.bold))
                                    .foregroundStyle(score >= 4 ? Color.inkFixed : Color.paper)
                            }
                        }
                        .accessibilityLabel(entry?.score.map { "\(isoDate(day)) : \($0) sur 5" } ?? "\(isoDate(day)) : non joué")
                }
            }
        }
    }

    private func fill(for entry: DailyHistoryEntry?) -> Color {
        guard let entry, entry.status == "finished", let score = entry.score else { return .hairline }
        return score >= 4 ? .chloro : Color.ink.opacity(0.35 + Double(score) * 0.12)
    }

    private func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private var trophies: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Trophées").labelCaps()
            let unlocked = achievements.filter { $0.unlockedAt != nil }
            Text("\(unlocked.count) sur \(achievements.count)").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            ForEach(achievements) { achievement in
                HStack(spacing: Space.m) {
                    Image(systemName: achievement.unlockedAt != nil ? "seal.fill" : "seal")
                        .foregroundStyle(achievement.unlockedAt != nil ? Color.ink : Color.hairline)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.name).font(.system(.body).weight(.semibold))
                            .foregroundStyle(achievement.unlockedAt != nil ? Color.ink : Color.inkSoft)
                        Text(achievement.description).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
                .accessibilityValue(achievement.unlockedAt != nil ? "débloqué" : "à débloquer")
            }
        }
    }
}
