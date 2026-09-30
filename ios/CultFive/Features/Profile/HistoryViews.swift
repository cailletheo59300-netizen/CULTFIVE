import SwiftUI
import CultFiveCore

/// « Mes semaines » : une carte par semaine (lundi → dimanche). La semaine en cours est ouverte, les autres se déplient.
struct WeeksRecapSection: View {
    let weeks: [WeekRecap]
    @Environment(AppModel.self) private var app
    @State private var open: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Mes semaines").font(.cfHeadline)
            if weeks.allSatisfy(\.isEmpty) {
                Text("Ton récap se remplira au fil de tes parties.").font(.cfCallout).foregroundStyle(Color.inkSoft)
            }
            ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                if !week.isEmpty || index == 0 {
                    card(week, current: index == 0)
                }
            }
        }
    }

    private func card(_ week: WeekRecap, current: Bool) -> some View {
        let expanded = current || open.contains(week.id)
        return Button {
            guard !current else { return }
            Haptics.selection()
            withAnimation(Motion.standard) {
                if open.contains(week.id) { open.remove(week.id) } else { open.insert(week.id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(current ? "Cette semaine" : "Semaine du \(DateText.short(week.weekStart))")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(Color.ink)
                    Spacer()
                    if !expanded {
                        Text(summary(week)).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    }
                    if !current {
                        Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Color.inkSoft)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }
                if expanded {
                    HStack(alignment: .top, spacing: 0) {
                        stat("\(week.games)", "parties")
                        stat("\(week.answers)", "réponses")
                        stat(week.rate.map { "\($0) %" } ?? "—", "réussite")
                        stat(week.dailyAvg.map { String(format: "%.1f", $0).replacingOccurrences(of: ".", with: ",") } ?? "—",
                             "/5 au Daily (\(week.dailies))")
                    }
                    if !week.coteMoves.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(week.coteMoves.prefix(4), id: \.domainId) { move in
                                HStack(spacing: 4) {
                                    Image(systemName: DomainPalette.symbol(move.domainId)).font(.caption2.weight(.bold))
                                    Text(app.domainName(move.domainId)).font(.system(.caption, design: .rounded).weight(.bold))
                                    Text(CoteCULT.formatDelta(move.delta)).font(.system(.caption, design: .rounded).weight(.heavy))
                                        .foregroundStyle(move.delta > 0 ? Color.correct : Color.wrong)
                                }
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(DomainPalette.color(move.domainId).opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        Label("\(week.questsDone) défi\(week.questsDone > 1 ? "s" : "")", systemImage: "target")
                        Label("\(week.errorsCorrected) erreur\(week.errorsCorrected > 1 ? "s" : "") corrigée\(week.errorsCorrected > 1 ? "s" : "")",
                              systemImage: "checkmark.seal")
                    }
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            .popCard(padding: 14)
        }
        .buttonStyle(.row)
        .accessibilityElement(children: .combine)
    }

    private func summary(_ week: WeekRecap) -> String {
        [week.games > 0 ? "\(week.games) partie\(week.games > 1 ? "s" : "")" : nil, week.rate.map { "\($0) %" }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.cfFootnote).foregroundStyle(Color.inkSoft).lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Historique du 5 du jour : score, % de bonnes réponses, classement parmi les joueurs du jour.
struct DailyHistoryList: View {
    let entries: [DailyHistoryEntry]

    private var finished: [DailyHistoryEntry] { entries.filter { $0.status != "in_progress" } }

    var body: some View {
        List {
            if !finished.isEmpty {
                Section {
                    HStack(spacing: 0) {
                        figure("\(finished.count)", "5 du jour joués")
                        figure("\(averageRate) %", "de réussite")
                        figure(finished.compactMap(\.top).min().map { "Top \($0) %" } ?? "—", "meilleur classement")
                    }
                    .listRowBackground(Color.paperRaised)
                }
            }
            Section {
                ForEach(entries, id: \.date) { entry in
                    row(entry)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle("Historique du 5 du jour")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var averageRate: Int {
        let rates = finished.compactMap(\.rate)
        return rates.isEmpty ? 0 : Int((Double(rates.reduce(0, +)) / Double(rates.count)).rounded())
    }

    private func row(_ entry: DailyHistoryEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(DateText.long(entry.date).capitalized(with: Locale(identifier: "fr_FR")))
                    .font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                if let top = entry.top {
                    Text("Top \(top) % des joueurs\(entry.percentile?.source == .estimate ? " (estimation)" : "")")
                        .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                } else if entry.status == "in_progress" {
                    Text("En cours").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                } else if entry.status == "expired" {
                    Text("Temps écoulé").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            Spacer()
            if let score = entry.score, entry.status != "in_progress" {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(score)/5").font(.system(.headline, design: .rounded).weight(.black)).monospacedDigit()
                        .foregroundStyle(score >= 4 ? Color.correct : score >= 2 ? Color.ink : Color.wrong)
                    Text("\(entry.rate ?? score * 20) %").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
                }
            }
        }
        .listRowBackground(Color.paperRaised)
        .accessibilityElement(children: .combine)
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
            Text(label).font(.cfFootnote).foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Feuille « Historique du 5 du jour » : charge un historique plus long que le calendrier du profil.
struct DailyHistoryDetail: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [DailyHistoryEntry]?

    var body: some View {
        Group {
            if let entries {
                DailyHistoryList(entries: entries)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.paper)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer") { dismiss() }
            }
        }
        .task { entries = (try? await app.service.dailyHistory(days: 120)) ?? [] }
    }
}
