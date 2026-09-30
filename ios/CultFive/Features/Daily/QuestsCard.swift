import SwiftUI
import CultFiveCore

/// Défis du jour et de la semaine : trois lignes avec leur jauge et leur récompense ; les trois remplis donnent un coffre
/// (bois le jour, argent la semaine).
struct QuestsCard: View {
    let overview: QuestsOverview
    @State private var weekly = false

    private var period: QuestsOverview.Period { weekly ? overview.week : overview.day }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Défis").font(.cfHeadline)
                Spacer()
                picker
            }
            ForEach(period.quests) { quest in
                QuestRow(quest: quest)
            }
            bonusRow
            HStack(spacing: 4) {
                Image(systemName: "clock").accessibilityHidden(true)
                Text("Nouveaux défis \(remaining)")
            }
            .font(.cfFootnote).foregroundStyle(Color.inkSoft)
        }
        .popCard()
        .animation(Motion.standard, value: weekly)
    }

    private var picker: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { value in
                Button {
                    Haptics.selection()
                    weekly = value
                } label: {
                    Text(value ? "Semaine" : "Jour")
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundStyle(weekly == value ? Color.white : Color.inkSoft)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(weekly == value ? Color.brand : Color.clear, in: Capsule())
                }
                .buttonStyle(.row)
                .accessibilityAddTraits(weekly == value ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.hairline.opacity(0.6), in: Capsule())
    }

    private var bonusRow: some View {
        HStack(spacing: 10) {
            if let chest = period.bonus.chest.flatMap(ChestTier.init(rawValue:)) {
                ChestView(tier: chest, open: period.bonus.done).frame(width: 40)
                    .opacity(period.bonus.done ? 0.7 : 1)
            } else {
                Image(systemName: period.bonus.done ? "gift.fill" : "gift")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(period.bonus.done ? Color.white : Color(hex: 0xFFB020))
                    .frame(width: 34, height: 34)
                    .background(period.bonus.done ? Color(hex: 0xFFB020) : Color(hex: 0xFFB020).opacity(0.14), in: Circle())
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(weekly ? "Les trois de la semaine" : "Les trois du jour")
                    .font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                Text(period.bonus.done ? "Coffre gagné !" : "\(period.doneCount)/\(period.quests.count) défis remplis")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            if let chest = period.bonus.chest {
                Text(ChestName.title(chest))
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(period.bonus.done ? Color.inkSoft : Color(hex: 0xB7791F))
                    .opacity(period.bonus.done ? 0.6 : 1)
            } else {
                RewardPill(xp: period.bonus.xp, seeds: period.bonus.seeds, done: period.bonus.done)
            }
        }
        .padding(10)
        .background(Color(hex: 0xFFB020).opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// « dans 5 h », « dans 3 jours ».
    private var remaining: String {
        let seconds = max(0, period.endsAt.timeIntervalSinceNow)
        if seconds >= 2 * 86_400 { return "dans \(Int(seconds / 86_400)) jours" }
        if seconds >= 3_600 { return "dans \(Int(seconds / 3_600)) h" }
        return "dans \(max(1, Int(seconds / 60))) min"
    }
}

private struct QuestRow: View {
    let quest: QuestsOverview.Quest

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: quest.done ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(quest.done ? Color.correct : Color.hairline)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(quest.label)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(quest.done ? Color.inkSoft : Color.ink)
                        .strikethrough(quest.done, color: .inkSoft)
                    Spacer(minLength: 4)
                    Text("\(quest.progress)/\(quest.target)")
                        .font(.system(.footnote, design: .rounded).weight(.heavy)).monospacedDigit()
                        .foregroundStyle(Color.inkSoft)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline.opacity(0.7))
                        Capsule().fill(quest.done ? Color.correct : Color.brand)
                            .frame(width: max(8, proxy.size.width * CGFloat(quest.progress) / CGFloat(max(quest.target, 1))))
                    }
                }
                .frame(height: 8)
            }
            RewardPill(xp: quest.xp, seeds: quest.seeds, done: quest.done)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quest.label), \(quest.progress) sur \(quest.target)\(quest.done ? ", rempli" : "")")
    }
}

/// « +2 🌱 » (et l'XP en petit) ; grisé une fois gagné.
private struct RewardPill: View {
    let xp: Int
    let seeds: Int
    var done = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            SeedsAmount(amount: seeds, signed: true, color: done ? .inkSoft : Color(hex: 0x37B24D))
                .font(.system(.footnote, design: .rounded).weight(.heavy))
            if xp > 0 {
                Text("+\(xp) XP").font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
            }
        }
        .opacity(done ? 0.6 : 1)
    }
}

/// Bandeau de célébration quand un objectif vient d'être rempli.
struct QuestRewardBanner: View {
    let rewards: [QuestsOverview.Reward]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rewards.enumerated()), id: \.offset) { _, reward in
                CelebrationCard(kind: .quest, title: reward.label,
                                detail: reward.chest.map { "\(ChestName.title($0)) gagné !" }
                                    ?? "+\(reward.seeds) graines\(reward.xp > 0 ? " · +\(reward.xp) XP" : "")")
            }
        }
    }
}
