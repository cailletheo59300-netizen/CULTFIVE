import SwiftUI
import CultFiveCore

/// Défis sous le 5 du jour (aperçu TestFlight) : Jour, Semaine, Saison. Chaque défi dit ce qu'il rapporte :
/// des neurones et des points de saison qui font monter le pass. Les défis du jour et de la semaine sont les vrais
/// (serveur) ; les missions de saison sont simulées et se valident à la main dans l'aperçu.
struct SeasonChallengesCard: View {
    let overview: QuestsOverview?
    let store: AlbumStore
    var onOpenPass: () -> Void

    private enum Tab: String, CaseIterable { case day = "Jour", week = "Semaine", season = "Saison" }

    @State private var tab: Tab = .day

    private var accent: Color {
        switch tab {
        case .day: return Color(hex: 0xF76707)
        case .week: return .brand
        case .season: return Color(hex: 0xF0588F)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            picker
            switch tab {
            case .day: period(overview?.day, points: AlbumStore.dayPoints, bonus: AlbumStore.dayBonus)
            case .week: period(overview?.week, points: AlbumStore.weekPoints, bonus: AlbumStore.weekBonus)
            case .season: missions
            }
        }
        .popCard()
        .animation(Motion.standard, value: tab)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Défis").font(.cfHeadline).foregroundStyle(Color.ink)
                HStack(spacing: 4) {
                    Text("Gagne des")
                    NeuroneIcon().frame(width: 16, height: 16)
                    Text("neurones et des points de saison")
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
            Spacer(minLength: Space.s)
            Button(action: onOpenPass) {
                VStack(spacing: 0) {
                    Text("Pass").font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                    Text("\(store.tier)/\(AlbumStore.tiers)").font(.system(.subheadline, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(Color.sun)
                }
                .frame(width: 58, height: 46)
                .background(Color.popGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.row)
            .accessibilityLabel("Pass de saison, palier \(store.tier) sur \(AlbumStore.tiers)")
        }
    }

    private var picker: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { value in
                Button {
                    Haptics.selection()
                    tab = value
                } label: {
                    Text(value.rawValue)
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundStyle(tab == value ? Color.white : Color.inkSoft)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(tab == value ? accent : Color.clear, in: Capsule())
                }
                .buttonStyle(.row)
                .accessibilityAddTraits(tab == value ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.hairline.opacity(0.6), in: Capsule())
    }

    // MARK: - Jour et semaine (vrais défis)

    @ViewBuilder
    private func period(_ period: QuestsOverview.Period?, points: Int, bonus: Int) -> some View {
        if let period {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(period.quests) { quest in
                    ChallengeRow(label: quest.label, progress: quest.progress, target: quest.target, done: quest.done,
                                 neurones: quest.seeds, points: points, accent: accent)
                }
                BonusBar(bonus: bonus, count: period.doneCount, total: period.quests.count, accent: accent,
                         extra: bonusExtra(period.bonus))
                HStack(spacing: 4) {
                    Image(systemName: "clock").accessibilityHidden(true)
                    Text("Nouveaux défis \(remaining(period.endsAt))")
                }
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        } else {
            HStack(spacing: Space.s) {
                ProgressView()
                Text("Chargement des défis…").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        }
    }

    private func bonusExtra(_ bonus: QuestsOverview.Bonus) -> String? {
        if let chest = bonus.chest { return "\(ChestName.title(chest)) en plus" }
        if bonus.seeds > 0 { return "+\(bonus.seeds) neurones en plus" }
        return nil
    }

    // MARK: - Saison (missions simulées)

    private var missions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("12 missions pour toute la saison, sans date limite. Aperçu : touche une mission pour la valider.")
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            ForEach(AlbumStore.missions.indices, id: \.self) { i in
                let done = store.missionsDone.contains(i)
                Button {
                    guard !done else { return }
                    Haptics.success()
                    withAnimation(Motion.standard) { store.completeMission(i) }
                } label: {
                    ChallengeRow(label: AlbumStore.missions[i], progress: done ? 1 : 0, target: 1, done: done,
                                 neurones: 0, points: AlbumStore.missionPoints, accent: accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// « dans 5 h », « dans 3 jours ».
    private func remaining(_ end: Date) -> String {
        let seconds = max(0, end.timeIntervalSinceNow)
        if seconds >= 2 * 86_400 { return "dans \(Int(seconds / 86_400)) jours" }
        if seconds >= 3_600 { return "dans \(Int(seconds / 3_600)) h" }
        return "dans \(max(1, Int(seconds / 60))) min"
    }
}

/// Un défi : coche, libellé, jauge, et ce qu'il rapporte (neurones, points de saison).
private struct ChallengeRow: View {
    let label: String
    let progress: Int
    let target: Int
    let done: Bool
    let neurones: Int
    let points: Int
    let accent: Color

    var body: some View {
        let ratio = CGFloat(min(progress, target)) / CGFloat(max(target, 1))
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(done ? Color.correct : accent.opacity(0.45))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(done ? Color.inkSoft : Color.ink)
                        .strikethrough(done, color: .inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    if target > 1 {
                        Text("\(progress)/\(target)")
                            .font(.system(.caption, design: .rounded).weight(.heavy)).monospacedDigit()
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline.opacity(0.7))
                        Capsule().fill(done ? Color.correct : accent)
                            .frame(width: max(6, proxy.size.width * ratio))
                    }
                }
                .frame(height: 6)
            }
            VStack(alignment: .trailing, spacing: 3) {
                if neurones > 0 {
                    HStack(spacing: 2) {
                        NeuroneIcon().frame(width: 16, height: 16)
                        Text("+\(neurones)").monospacedDigit()
                    }
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color(hex: 0xD6336C))
                }
                Text("+\(points) pts")
                    .font(.system(.caption2, design: .rounded).weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.brand, in: Capsule())
            }
            .fixedSize()
            .opacity(done ? 0.5 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(progress) sur \(target)\(done ? ", rempli" : ""), \(neurones) neurones, \(points) points de saison")
    }
}
