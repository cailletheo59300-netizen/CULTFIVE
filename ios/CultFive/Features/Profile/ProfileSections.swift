import SwiftUI
import CultFiveCore

/// Bas du profil : tes chiffres, tes domaines, ton mois, tes trophées. Un titre de section, puis une carte simple.
struct ProfileSectionTitle: View {
    let title: String
    var action: String? = nil
    var onAction: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title3, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
            Spacer()
            if let action {
                Button(action, action: onAction)
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.brand)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, Space.s)
    }
}

// MARK: - Tes chiffres

/// Quatre chiffres clés en 2 × 2 : série, questions, erreurs corrigées, meilleur jour.
struct ProfileStatsGrid: View {
    let profile: Profile?
    let skills: [SkillSummary]
    let history: [DailyHistoryEntry]

    var body: some View {
        let streak = profile?.streak ?? 0
        let best = max(profile?.streakBest ?? 0, streak)
        let answered = profile?.questionsAnswered ?? 0
        let corrected = profile?.errorsCorrected ?? 0
        let toReview = profile?.activeErrors ?? 0
        let correct = skills.reduce(0) { $0 + $1.correct }, total = skills.reduce(0) { $0 + $1.answered }
        let rate = total > 0 ? Int((Double(correct) / Double(total) * 100).rounded()) : nil
        let top = history.filter { $0.status != "in_progress" }.compactMap(\.top).min()
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            tile(icon: GameIcon.flame.image, value: "\(streak)", label: streak > 1 ? "jours de série" : "jour de série",
                 detail: "Record : \(best) jour\(best > 1 ? "s" : "")")
            tile(icon: TallyMark(strokes: [.correct, .correct, .correct, .correct, .correct]), value: CoteCULT.format(answered),
                 label: answered > 1 ? "questions répondues" : "question répondue", detail: rate.map { "\($0) % de bonnes" })
            tile(icon: Image(systemName: "checkmark.circle.fill").resizable().scaledToFit().foregroundStyle(Color.correct),
                 value: "\(corrected)", label: corrected > 1 ? "erreurs corrigées" : "erreur corrigée",
                 detail: toReview > 0 ? "\(toReview) à revoir" : "Rien à revoir")
            tile(icon: Image("trophy_cup").resizable().scaledToFit(), value: top.map { "\($0) %" } ?? "—",
                 label: "meilleur jour", detail: top != nil ? "Top des joueurs" : "Joue un 5 du jour")
        }
    }

    private func tile(icon: some View, value: String, label: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                icon.frame(width: 28, height: 28).accessibilityHidden(true)
                Text(value).font(.system(size: 26, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(label).font(.system(.footnote, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.8)
            if let detail {
                Text(detail).font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Color.brand)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard(padding: 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tes domaines

/// Les domaines joués, du plus fort au plus faible : petit emblème, nom, rang, jauge vers le rang suivant, Elo.
/// Puis les domaines en placement. Toucher un domaine ouvre sa page.
struct ProfileDomainsList: View {
    let skills: [SkillSummary]

    var body: some View {
        let placed = skills.filter { $0.rating.placed }.sorted { $0.rating.cote > $1.rating.cote }
        let provisional = skills.filter { !$0.rating.placed && $0.answered > 0 }.sorted { $0.answered > $1.answered }
        VStack(spacing: 0) {
            if placed.isEmpty && provisional.isEmpty {
                Text("Joue une partie classée pour voir ton niveau dans chaque domaine.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
            ForEach(Array((placed + provisional).enumerated()), id: \.element.id) { index, skill in
                if index > 0 { Divider().overlay(Color.hairline) }
                NavigationLink(value: skill.domainId) { row(skill) }
                    .buttonStyle(.row)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .shadow(color: Color.hairline, radius: 0, y: 2)
    }

    private func row(_ skill: SkillSummary) -> some View {
        let color = DomainPalette.color(skill.domainId)
        let rating = skill.rating
        return HStack(spacing: 10) {
            if rating.placed {
                RankEmblem(rank: rating.rank).frame(width: 42, height: 42).accessibilityHidden(true)
            } else {
                Circle().fill(color).frame(width: 10, height: 10).frame(width: 42)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if rating.placed { Circle().fill(color).frame(width: 9, height: 9) }
                    Text(skill.name).font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                        .lineLimit(1)
                }
                Text(rating.placed ? rating.rank.name : "Provisoire · \(rating.placementGames)/\(CoteCULT.placementGames) parties")
                    .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                if rating.placed {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.hairline)
                            Capsule().fill(color).frame(width: geo.size.width * (rating.toNextRank?.progress ?? 1))
                        }
                    }
                    .frame(height: 5)
                }
            }
            Spacer(minLength: 6)
            if rating.placed {
                Text(rating.formatted).font(.system(.callout, design: .rounded).weight(.black)).monospacedDigit()
                    .foregroundStyle(Color.ink)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rating.placed ? "\(skill.name), \(rating.rank.name), Elo \(rating.formatted)"
                                          : "\(skill.name), Elo provisoire, \(rating.placementGames) parties sur 5")
    }
}

// MARK: - Ton mois

/// Le mois en cours : chaque jour joué montre son 5 du jour en traits (pleins = bonnes réponses, 5 barré en vert).
struct ProfileMonthCalendar: View {
    let history: [DailyHistoryEntry]

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale(identifier: "fr_FR")
        return c
    }()

    var body: some View {
        let byDate = Dictionary(history.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let today = Date()
        let days = monthDays(today)
        let lead = leadingBlanks(today)
        let finished = history.filter { $0.status != "in_progress" && $0.score != nil && isThisMonth($0.date, today) }
        let rate = finished.isEmpty ? nil
            : Int((Double(finished.compactMap(\.score).reduce(0, +)) / Double(finished.count * 5) * 100).rounded())
        VStack(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(["L", "M", "M", "J", "V", "S", "D"].indices, id: \.self) { i in
                    Text(["L", "M", "M", "J", "V", "S", "D"][i])
                        .font(.system(.caption2, design: .rounded).weight(.black)).foregroundStyle(Color.inkSoft)
                }
                ForEach(0 ..< lead, id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fit) }
                ForEach(days, id: \.self) { day in
                    cell(day, entry: byDate[iso(day)], isToday: calendar.isDate(day, inSameDayAs: today), future: day > today)
                }
            }
            HStack {
                Text(finished.isEmpty ? "Pas encore de 5 du jour ce mois-ci"
                     : "\(finished.count) rendez-vous\(rate.map { " · \($0) % de bonnes" } ?? "")")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                Spacer()
            }
        }
        .popCard(padding: 12)
    }

    private func cell(_ day: Date, entry: DailyHistoryEntry?, isToday: Bool, future: Bool) -> some View {
        let score = entry?.status == "finished" ? entry?.score : nil
        return RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(future ? Color.clear : Color.paper)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let score {
                    let strokes: [TallyStroke] = (0 ..< 5).map { $0 < score ? .correct : .empty }
                    TallyMark(strokes: strokes).padding(5)
                } else if future {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft.opacity(0.5))
                }
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.brand, lineWidth: 2)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(score.map { "\(DateText.short(iso(day))) : \($0) sur 5" } ?? "\(DateText.short(iso(day))) : pas joué")
    }

    private func monthDays(_ today: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: today),
              let count = calendar.range(of: .day, in: .month, for: today)?.count else { return [] }
        return (0 ..< count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// Cases vides avant le 1er du mois (semaine du lundi au dimanche).
    private func leadingBlanks(_ today: Date) -> Int {
        guard let first = calendar.dateInterval(of: .month, for: today)?.start else { return 0 }
        return (calendar.component(.weekday, from: first) + 5) % 7
    }

    private func isThisMonth(_ date: String, _ today: Date) -> Bool {
        date.hasPrefix(String(iso(today).prefix(7)))
    }

    private func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Trophées

/// Étagère qui défile : médailles de maîtrise gagnées, exploits débloqués, puis ceux à gagner (grisés).
struct ProfileTrophyShelf: View {
    let trophies: TrophiesOverview

    private struct Item: Identifiable {
        let id: String
        let image: String
        let title: String
        let subtitle: String
        let unlocked: Bool
    }

    private var items: [Item] {
        let tierNames = Dictionary(uniqueKeysWithValues: TrophiesOverview.tiers.map { ($0.id, $0.name) })
        let masteries = trophies.mastery.compactMap { m -> Item? in
            guard let tier = m.tier else { return nil }
            return Item(id: "m-\(m.domainId)", image: "medal_\(tier)", title: m.name, subtitle: tierNames[tier] ?? tier, unlocked: true)
        }
        let unlocked = trophies.exploits.filter { $0.unlockedAt != nil }
            .map { Item(id: "e-\($0.id)", image: "trophy_cup", title: $0.name, subtitle: "Exploit", unlocked: true) }
        let locked = trophies.exploits.filter { $0.unlockedAt == nil }.prefix(3)
            .map { Item(id: "e-\($0.id)", image: "trophy_cup", title: $0.name, subtitle: "À gagner", unlocked: false) }
        return masteries + unlocked + locked
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    VStack(spacing: 4) {
                        Image(item.image).resizable().scaledToFit().frame(width: 60, height: 60)
                            .saturation(item.unlocked ? 1 : 0).opacity(item.unlocked ? 1 : 0.4)
                        Text(item.title).font(.system(.caption, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                        Text(item.subtitle).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                    }
                    .frame(width: 96, height: 128, alignment: .top)
                    .padding(.vertical, 10)
                    .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.bottom, 2)
        }
        .scrollIndicators(.hidden)
    }
}
