import SwiftUI
import Charts
import CultFiveCore

/// Un domaine : la couleur prend de la place, les statistiques mènent à des actions (« Capitales faible → S'entraîner »).
struct DomainView: View {
    let domainId: String

    @Environment(AppModel.self) private var app
    @State private var stats: DomainStats?
    @State private var playConfig: PlayConfig?
    @State private var loadError: String?

    private var color: Color { DomainPalette.color(domainId) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: Space.xl) {
                    Button("S'entraîner sur tout le domaine") {
                        playConfig = PlayConfig(mode: .training, domain: domainId)
                    }
                    .buttonStyle(.domain(domainId))

                    subdomains
                    if let stats, stats.answered > 0 {
                        evolution(stats)
                        figures(stats)
                        difficulty(stats)
                        recentErrors(stats)
                    } else if stats != nil {
                        Text("Réponds à quelques questions pour voir apparaître tes statistiques.")
                            .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.l)
                .padding(.bottom, Space.xxl)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(color, for: .navigationBar)
        .toolbarColorScheme(domainId == "music" ? .light : .dark, for: .navigationBar)
        .fullScreenCover(item: $playConfig, onDismiss: { Task { await load() } }) { config in
            PlaySessionView(config: config)
        }
        .task { await load() }
    }

    private func load() async {
        do {
            stats = try await app.service.domainStats(domainId)
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(app.domainName(domainId))
                .font(.cfDisplay)
                .foregroundStyle(DomainPalette.onColor(domainId))
            if let stats {
                HStack(alignment: .lastTextBaseline, spacing: Space.s) {
                    Text("\(stats.level)").numeral(size: 64).foregroundStyle(DomainPalette.onColor(domainId))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("niveau").font(.cfFootnote)
                        Text("fiabilité \(Reliability(stats.reliability).label)").font(.cfFootnote)
                    }
                    .foregroundStyle(DomainPalette.onColor(domainId).opacity(0.8))
                }
            } else if let loadError {
                Text(loadError).font(.cfCallout).foregroundStyle(DomainPalette.onColor(domainId).opacity(0.8))
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.m)
        .padding(.bottom, Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                color
                Image(systemName: DomainPalette.symbol(domainId))
                    .font(.system(size: 130, weight: .black))
                    .foregroundStyle(DomainPalette.onColor(domainId).opacity(0.14))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 24, y: 10)
            }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: Radius.l, bottomTrailingRadius: Radius.l, style: .continuous))
            .ignoresSafeArea(edges: .top)
        }
    }

    private var subdomains: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Sous-domaines").labelCaps()
            VStack(spacing: 10) {
                let rows: [DomainStats.Subdomain] = stats?.subdomains ?? app.subdomains(of: domainId).map {
                    DomainStats.Subdomain(id: $0.id, name: $0.name, level: 0, reliability: 0, answered: 0, correct: 0, available: 1)
                }
                let weakest = rows.filter { $0.answered >= 3 }.min { $0.level < $1.level }?.id
                ForEach(rows) { sub in
                    Button {
                        playConfig = PlayConfig(mode: .training, domain: domainId, subdomain: sub.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(sub.name).font(.cfTitle3).foregroundStyle(Color.ink)
                                if sub.id == weakest {
                                    Text("à renforcer").labelCaps(color)
                                }
                                Spacer()
                                if sub.answered > 0 {
                                    Text("\(sub.level)").font(.cfNumber).foregroundStyle(Color.ink)
                                }
                                Image(systemName: "play.fill").font(.caption).foregroundStyle(color)
                                    .accessibilityLabel("S'entraîner")
                            }
                            if sub.answered > 0 {
                                SkillBar(level: sub.level, reliability: sub.reliability, color: color)
                            }
                        }
                        .popCard(padding: 14)
                    }
                    .buttonStyle(.row)
                    .disabled(sub.available == 0)
                    .opacity(sub.available == 0 ? 0.4 : 1)
                }
            }
        }
    }

    private func evolution(_ stats: DomainStats) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Évolution").labelCaps()
            if stats.history.count >= 2 {
                Chart(stats.history, id: \.day) { point in
                    LineMark(x: .value("Jour", DateText.date(point.day) ?? Date()), y: .value("Niveau", point.level))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(color)
                    PointMark(x: .value("Jour", DateText.date(point.day) ?? Date()), y: .value("Niveau", point.level))
                        .foregroundStyle(color)
                        .symbolSize(18)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: 150)
                .accessibilityLabel("Évolution du niveau sur les derniers jours")
            } else {
                Text("La courbe apparaîtra après quelques jours de jeu.").font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
    }

    private func figures(_ stats: DomainStats) -> some View {
        HStack(alignment: .top, spacing: 0) {
            figure("\(stats.answered)", "questions")
            figure("\(Int((Double(stats.correct) / Double(max(stats.answered, 1)) * 100).rounded())) %", "de réussite")
            figure(stats.avgMs.map { DurationFormat.seconds(milliseconds: $0) } ?? "—", "par question")
            figure("\(stats.conceptsMastered)", "notions sûres")
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.cfFootnote).foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func difficulty(_ stats: DomainStats) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Selon la difficulté").labelCaps()
            ForEach(["easy", "medium", "hard"], id: \.self) { band in
                if let row = stats.byDifficulty.first(where: { $0.band == band }) {
                    let rate = Double(row.correct) / Double(max(row.answered, 1))
                    HStack {
                        Text(band == "easy" ? "Faciles" : band == "medium" ? "Moyennes" : "Difficiles")
                            .font(.cfCallout).frame(width: 90, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.hairline)
                                Rectangle().fill(color).frame(width: proxy.size.width * rate)
                            }
                        }
                        .frame(height: 6)
                        Text("\(Int((rate * 100).rounded())) %").font(.cfNumber).frame(width: 52, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func recentErrors(_ stats: DomainStats) -> some View {
        if !stats.recentErrors.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Erreurs récentes").labelCaps()
                ForEach(stats.recentErrors) { error in
                    HStack {
                        Text(error.label).font(.cfCallout)
                        Spacer()
                        Text(error.state == "to_review" ? "à revoir" : "ratée").font(.cfFootnote).foregroundStyle(Color.wrong)
                    }
                    .popCard(padding: 12, radius: Radius.s)
                }
                Button("Corriger mes erreurs") { playConfig = PlayConfig(mode: .errors) }
                    .buttonStyle(.textLink)
            }
        }
    }
}
