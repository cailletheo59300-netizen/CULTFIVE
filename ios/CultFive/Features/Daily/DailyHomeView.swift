import SwiftUI
import CultFiveCore

/// Accueil = le rendez-vous du jour. Le trait de cinq domine ; le reste est une colonne éditoriale, pas un dashboard.
struct DailyHomeView: View {
    @Environment(AppModel.self) private var app
    @State private var showDaily = false
    @State private var playConfig: PlayConfig?
    @State private var suggestion: SkillSummary?
    @State private var league: LeagueSummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    topLine
                    rendezVous
                    column
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Color.paper)
            .refreshable { await reload() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showDaily) {
            DailySessionView()
        }
        .fullScreenCover(item: $playConfig) { config in
            PlaySessionView(config: config)
        }
        .task { await reload() }
    }

    private func reload() async {
        await app.refreshDaily()
        await app.refreshProfile()
        if let skills = try? await app.service.skills() {
            suggestion = skills.filter { $0.answered >= 5 }.min { $0.level < $1.level }
        }
        league = (try? await app.service.leagues())?.first
    }

    // MARK: Blocs

    private var topLine: some View {
        HStack {
            Text(DateText.long(app.daily?.date ?? isoToday)).labelCaps()
            Spacer()
            if let seeds = app.profile?.seeds {
                SeedsAmount(amount: seeds).font(.cfNumber)
            }
        }
        .padding(.top, Space.m)
    }

    private var rendezVous: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(greeting)
                .font(.cfDisplay)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: Space.l) {
                TallyMark(strokes: strokes)
                    .frame(width: 128)
                    .onTapGesture { showDaily = true }
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(stateTitle).font(.cfHeadline).foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stateDetail).font(.cfCallout).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            switch app.daily?.state {
            case .done:
                Button("Voir mon résultat") { showDaily = true }.buttonStyle(.textLink)
            case .inProgress:
                Button("Reprendre") { showDaily = true }.buttonStyle(.ink)
            default:
                Button("Commencer") { showDaily = true }.buttonStyle(.ink).disabled(app.daily == nil)
            }
        }
    }

    @ViewBuilder private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let profile = app.profile {
                EditorialRow(label: "Série", value: profile.streak > 0 ? "\(profile.streak) jour\(profile.streak > 1 ? "s" : "")" : "à lancer",
                             detail: profile.streakFreezes > 0 ? "\(profile.streakFreezes) joker\(profile.streakFreezes > 1 ? "s" : "") de série en réserve" : "Un joker tous les 7 jours d'affilée",
                             symbol: "flame.fill")
                if profile.activeErrors > 0 {
                    Button { playConfig = PlayConfig(mode: .errors) } label: {
                        EditorialRow(label: "À revoir", value: "\(profile.activeErrors) erreur\(profile.activeErrors > 1 ? "s" : "")",
                                     detail: "Corrige-les pendant qu'elles sont fraîches.", symbol: "arrow.uturn.backward", chevron: true)
                    }
                    .buttonStyle(.row)
                }
            }
            if let suggestion {
                Button { playConfig = PlayConfig(mode: .training, domain: suggestion.domainId) } label: {
                    EditorialRow(label: "Ton terrain à conquérir", value: suggestion.name,
                                 detail: "Niveau \(suggestion.level) · quelques questions pour progresser",
                                 accent: DomainPalette.color(suggestion.domainId), chevron: true)
                }
                .buttonStyle(.row)
            }
            if let league {
                Button { app.tab = .friends } label: {
                    EditorialRow(label: "Ligue", value: league.name, detail: "\(league.members) membre\(league.members > 1 ? "s" : "") · classement de la \(league.period == .week ? "semaine" : "du mois")",
                                 symbol: "person.3", chevron: true)
                }
                .buttonStyle(.row)
            }
        }
    }

    // MARK: Textes

    private var isoToday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let hello = hour >= 18 || hour < 5 ? "Bonsoir" : "Bonjour"
        guard let handle = app.profile?.handle else { return "\(hello)." }
        return "\(hello), \(handle)."
    }

    private var strokes: [TallyStroke] {
        guard let daily = app.daily else { return Array(repeating: .empty, count: 5) }
        switch daily.state {
        case .available: return [.correct, .correct, .correct, .correct, .ready]
        case .inProgress:
            var strokes = daily.answers.map { $0 ? TallyStroke.correct : .wrong }
            if strokes.count < 5 { strokes.append(.current) }
            return strokes
        case .done: return daily.answers.map { $0 ? .correct : .wrong }
        }
    }

    private var stateTitle: String {
        switch app.daily?.state {
        case .available: return "Ton rendez-vous est prêt."
        case .inProgress: return "Tu en es à la question \(app.daily?.nextPosition ?? 1)."
        case .done: return "Terminé aujourd'hui."
        case nil: return "Ton rendez-vous arrive…"
        }
    }

    private var stateDetail: String {
        guard let daily = app.daily else { return "" }
        switch daily.state {
        case .available: return "Cinq questions variées. Environ cinq minutes."
        case .inProgress: return "Tes réponses sont gardées. Reprends où tu t'es arrêté."
        case .done:
            let score = daily.score.map { "\($0)/5" } ?? ""
            return "\(score) · Le prochain dans \(DurationFormat.countdown(seconds: daily.secondsUntilNext))."
        }
    }
}

/// Ligne éditoriale : rubrique en capitales, valeur en serif, précision discrète, filet dessous.
struct EditorialRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    var symbol: String? = nil
    var accent: Color? = nil
    var chevron = false

    var body: some View {
        HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).labelCaps()
                HStack(spacing: 6) {
                    if let symbol { Image(systemName: symbol).font(.callout).foregroundStyle(accent ?? Color.ink) }
                    if symbol == nil, let accent { Circle().fill(accent).frame(width: 9, height: 9) }
                    Text(value).font(.cfTitle3).foregroundStyle(Color.ink)
                }
                if let detail {
                    Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            Spacer()
            if chevron {
                Image(systemName: "arrow.right").font(.callout.weight(.semibold)).foregroundStyle(Color.inkSoft)
            }
        }
        .padding(.vertical, Space.m)
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}
