import SwiftUI
import CultFiveCore

// MARK: - Modèle

/// Partie de duel : comme le 5 du jour (question servie sans réponse, temps officiel serveur), sur la série du duel.
/// Format 7 questions (D-112) : 25 s par question, chrono tenu par le serveur ; temps écoulé = faux.
@MainActor
@Observable
final class DuelSessionModel {
    enum Stage: Equatable {
        case loading
        case intro(Duel)
        case question
        case finished(Duel)
        case failed(String)
    }

    let duelId: UUID
    private(set) var stage: Stage = .loading
    /// Nombre de questions du duel (5 à 20).
    private(set) var total = 5
    private(set) var question: Question?
    private(set) var phase: AnswerPhase = .answering
    private(set) var results: [Bool] = []
    private(set) var position = 1
    private(set) var isRetrying = false
    /// Chrono par question (nil : sans chrono).
    private(set) var seconds: Int?
    /// Fin du chrono de la question affichée.
    private(set) var deadline: Date?
    private var lastVerdict: DailyVerdict?
    private var pendingGiven: GivenAnswer?
    private var hasPending = false
    private var pendingMs: Int?
    private var stopwatch = Stopwatch()
    private let service: GameService

    init(duelId: UUID, service: GameService) {
        self.duelId = duelId
        self.service = service
    }

    func start() async {
        stage = .loading
        do {
            let duel = try await service.duelResult(duelId)
            total = duel.questionCount
            seconds = duel.seconds
            if duel.myTurn {
                position = duel.me.answered + 1
                results = (duel.myAnswers ?? []).map { $0.isCorrect ?? false }
                stage = .intro(duel)
            } else {
                stage = .finished(duel)
            }
        } catch {
            stage = .failed(message(for: error))
        }
    }

    func play() async { await load(position: position) }

    private func load(position: Int) async {
        self.position = position
        do {
            let response = try await service.duelQuestion(duel: duelId, position: position)
            guard let q = response.question, !response.expired else { await showResult(); return }
            question = q
            phase = .answering
            deadline = nil
            stopwatch.reset()
            stage = .question
        } catch {
            stage = .failed(message(for: error))
        }
    }

    func questionDisplayed() {
        stopwatch.start()
        if let seconds, deadline == nil, phase.isAnswering { deadline = Date().addingTimeInterval(TimeInterval(seconds)) }
    }
    func pause() { stopwatch.pause() }
    func resume() { if stage == .question && phase.isAnswering { stopwatch.start() } }

    func submit(_ given: GivenAnswer) { send(given) }

    /// Temps écoulé : faux.
    func timeUp() { send(nil) }

    private func send(_ given: GivenAnswer?) {
        guard phase.isAnswering else { return }
        stopwatch.pause()
        deadline = nil
        let ms = stopwatch.elapsedMilliseconds
        pendingGiven = given
        pendingMs = ms
        hasPending = true
        phase = .submitting(given)
        Task { await post(given: given, ms: ms) }
    }

    func retry() {
        guard hasPending else { return }
        isRetrying = false
        Task { await post(given: pendingGiven, ms: pendingMs) }
    }

    private func post(given: GivenAnswer?, ms: Int?) async {
        do {
            let verdict = try await service.duelAnswer(duel: duelId, position: position, given: given, clientMs: ms)
            guard let reveal = verdict.reveal else { throw BackendError.decoding("verdict incomplet") }
            let correct = verdict.isCorrect ?? false
            lastVerdict = verdict
            Feedback.answer(correct)
            if results.count < position { results.append(correct) }
            phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
            pendingGiven = nil
            hasPending = false
        } catch {
            isRetrying = true
        }
    }

    /// Passage à la question suivante en cours : un double appui ne doit pas sauter une question.
    private var advancing = false

    func next() async {
        guard !advancing else { return }
        advancing = true
        defer { advancing = false }
        if lastVerdict?.finished == true || position >= total { await showResult() } else { await load(position: position + 1) }
    }

    private func showResult() async {
        stage = .loading
        do { stage = .finished(try await service.duelResult(duelId)) } catch { stage = .failed(message(for: error)) }
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Une erreur est survenue."
    }
}

// MARK: - Écran de partie

struct DuelSessionView: View {
    let duelId: UUID

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: DuelSessionModel?
    /// Duel affiché : celui demandé, puis la revanche éventuelle.
    @State private var currentId: UUID?
    @State private var rematchError: String?
    /// Duel dont la fin est déjà notée pour la pub entre les parties (le bilan réapparaît après une pub).
    @State private var countedDuel: UUID?

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            if let model { content(model) } else { ProgressView() }
        }
        .task(id: currentId ?? duelId) {
            let session = DuelSessionModel(duelId: currentId ?? duelId, service: app.service)
            model = session
            await session.start()
        }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? model?.resume() : model?.pause()
        }
    }

    @ViewBuilder private func content(_ model: DuelSessionModel) -> some View {
        switch model.stage {
        case .loading:
            DelayedSpinner(tint: Color.brand)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Space.l) {
                Spacer()
                Leon(pose: .sad).frame(width: 150)
                Text(message).font(.cfHeadline)
                Button("Fermer") { close() }.buttonStyle(.ink)
                Spacer()
            }
            .padding(Space.gutter)
        case .intro(let duel):
            DuelIntroView(duel: duel, myHandle: app.profile?.handle ?? "Moi", resuming: model.position > 1,
                          onGo: { Task { await model.play() } }, onClose: { close() })
        case .question:
            if let question = model.question {
                QuestionScreen(
                    question: question,
                    domainName: app.domainName(question.domainId),
                    phase: model.phase,
                    continueTitle: model.position >= model.total ? "Voir le résultat" : "Question suivante",
                    onSubmit: { model.submit($0) },
                    onContinue: { Task { await model.next() } },
                    onDisplayed: { model.questionDisplayed() }
                ) {
                    HStack(spacing: Space.m) {
                        if let deadline = model.deadline, let seconds = model.seconds {
                            TimerRing(deadline: deadline, total: TimeInterval(seconds), color: Color.brand)
                        } else {
                            Label("Duel", systemImage: "bolt.fill").font(.cfFootnote.weight(.heavy)).foregroundStyle(Color.brand)
                        }
                        if model.total <= 12 {
                            ProgressPills(current: model.position, total: model.total, color: DomainPalette.color(question.domainId))
                        } else {
                            Text("\(model.position) / \(model.total)").font(.cfNumber).foregroundStyle(Color.inkSoft)
                        }
                        Button { close() } label: { CloseCircle() }
                            .accessibilityLabel("Quitter (tu pourras reprendre)")
                    }
                }
                .id(question.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .task(id: model.deadline) {
                    guard let deadline = model.deadline else { return }
                    try? await Task.sleep(nanoseconds: UInt64(max(0, deadline.timeIntervalSinceNow) * 1_000_000_000))
                    guard !Task.isCancelled, model.deadline == deadline else { return }
                    model.timeUp()
                }
                .overlay(alignment: .bottom) {
                    if model.isRetrying {
                        VStack(spacing: Space.s) {
                            Text("Connexion perdue. Ta réponse est gardée.").font(.cfCallout).foregroundStyle(.white)
                            Button("Renvoyer") { model.retry() }.buttonStyle(.sun)
                        }
                        .padding(Space.m)
                        .background(Color.brandDeep, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                        .padding(Space.gutter)
                    }
                }
            }
        case .finished(let duel):
            DuelResultView(duel: duel, myHandle: app.profile?.handle ?? "Moi", rematchError: rematchError,
                           onRematch: duel.opponent?.id == nil || duel.myTurn || (!duel.isFinished && duel.status != "expired")
                               ? nil : { rematch(duel) },
                           onClose: { close(afterGame: true) })
                .task(id: duel.id) {
                    guard countedDuel != duel.id else { return }
                    countedDuel = duel.id
                    app.noteGameFinished()
                }
        }
    }

    /// `afterGame` : on quitte le bilan, la pub entre les parties peut passer (D-110).
    private func close(afterGame: Bool = false) {
        Task {
            if afterGame { await app.interstitialBetweenGames() }
            dismiss()
            await app.refreshProfile()
        }
    }

    /// Revanche : même adversaire, mêmes réglages ; on enchaîne directement.
    private func rematch(_ duel: Duel) {
        rematchError = nil
        Task {
            do {
                let next = try await app.service.duelRematch(duel.id)
                Haptics.soft()
                model = nil
                currentId = next.id
            } catch {
                rematchError = error.userMessage("Revanche impossible pour l'instant.")
            }
        }
    }
}

/// Face-à-face avant de jouer : les deux pseudos, les règles en une ligne.
private struct DuelIntroView: View {
    let duel: Duel
    let myHandle: String
    let resuming: Bool
    var onGo: () -> Void
    var onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.popGradient.ignoresSafeArea()
            VStack(spacing: Space.l) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(.footnote, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                            .frame(width: 34, height: 34).background(.white.opacity(0.18), in: Circle()).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Fermer")
                }
                Spacer()
                Text("DUEL").font(.cfLabel).tracking(2).foregroundStyle(Color.sun)
                HStack(alignment: .center, spacing: Space.m) {
                    player(myHandle, me: true, avatar: nil)
                    Text("VS").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .scaleEffect(appeared ? 1 : 0.3)
                    player(duel.opponent?.handle ?? "?", me: false, avatar: duel.opponent?.avatar)
                }
                Text("Le meilleur score gagne ; à égalité, le plus rapide.")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Spacer()
                Button(resuming ? "Reprendre" : "Go !", action: onGo).buttonStyle(.sun)
            }
            .padding(Space.gutter)
        }
        .onAppear { withAnimation(Motion.bounce.delay(0.1)) { appeared = true } }
    }

    private func player(_ handle: String, me: Bool, avatar: JSONValue?) -> some View {
        VStack(spacing: 10) {
            if handle == "?" {
                ArenaMystery(size: 104)
            } else {
                ArenaAvatar(handle: handle, size: 104, ring: me ? Color.sun : .white.opacity(0.85), me: me, avatar: avatar)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            }
            Text(handle).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Résultat

struct DuelResultView: View {
    let duel: Duel
    let myHandle: String
    var rematchError: String? = nil
    /// Revanche proposée une fois le duel terminé (même adversaire, mêmes réglages).
    var onRematch: (() -> Void)? = nil
    var onClose: () -> Void

    @State private var appeared = false

    private var title: String {
        switch duel.winner {
        case "me": return "Victoire !"
        case "opponent": return "Perdu, de peu ?"
        case "draw": return "Égalité parfaite"
        default:
            if duel.status == "expired" { return "Duel expiré" }
            return duel.opponent == nil ? "Ta partie est faite" : "En attente de \(duel.opponent?.handle ?? "ton adversaire")"
        }
    }

    var body: some View {
        ZStack {
            Color.popGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Space.l) {
                    HStack {
                        Text("DUEL").font(.cfLabel).tracking(2).foregroundStyle(Color.sun)
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark").font(.system(.footnote, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                                .frame(width: 34, height: 34).background(.white.opacity(0.18), in: Circle()).frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Fermer")
                    }
                    Leon(color: .sun, pose: duel.winner == "me" ? .proud : duel.winner == "opponent" ? .sad : .wave,
                         rainbow: duel.winner == "me" && duel.me.score == duel.questionCount)
                        .frame(width: 140)
                    Text(title).font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    HStack(alignment: .top, spacing: Space.m) {
                        column(myHandle, score: duel.me.score, ms: duel.me.totalMs, marks: duel.myAnswers ?? [],
                               highlight: duel.winner == "me")
                        Text("–").font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 34)
                        if let pending = opponentPending {
                            pendingColumn(duel.opponent?.handle ?? "?", text: pending)
                        } else {
                            column(duel.opponent?.handle ?? "?", score: duel.opponent?.score, ms: duel.opponent?.totalMs,
                                   marks: duel.theirAnswers ?? [], highlight: duel.winner == "opponent")
                        }
                    }
                    if duel.winner == "me" {
                        Label("+20 XP · +5 \(Brand.currencyPlural)", systemImage: "trophy.fill")
                            .font(.system(.callout, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkFixed)
                            .padding(.horizontal, 16).padding(.vertical, 8).background(Color.sun, in: Capsule())
                    }
                    if !duel.isFinished, duel.status != "expired" {
                        VStack(spacing: Space.s) {
                            Text(duel.opponent == nil ? "Envoie le lien : le premier qui l'ouvre devient ton adversaire."
                                                      : "Tu seras prévenu dans l'onglet Arène quand il aura joué.")
                                .font(.cfCallout).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                            ShareLink(item: Brand.duelURL(code: duel.code),
                                      message: Text("Je t'ai défié sur \(Brand.name) : j'ai fait \(duel.me.score)/\(duel.questionCount). À toi !")) {
                                Label("Partager le défi", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.sun)
                        }
                    }
                    if let onRematch {
                        Button(action: onRematch) { Label("Revanche", systemImage: "arrow.triangle.2.circlepath") }
                            .buttonStyle(.sun)
                        Text("Mêmes réglages, nouvelles questions.").font(.cfFootnote).foregroundStyle(.white.opacity(0.75))
                    }
                    if let rematchError {
                        Text(rematchError).font(.cfFootnote).foregroundStyle(.white).multilineTextAlignment(.center)
                    }
                    Button("Continuer", action: onClose).buttonStyle(TextLinkStyle(color: .white))
                }
                .padding(Space.gutter)
            }
            .scrollIndicators(.hidden)
            if duel.winner == "me" { Confetti().ignoresSafeArea() }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(Motion.bounce.delay(0.1)) { appeared = true }
            duel.winner == "me" ? Haptics.success() : Haptics.soft()
        }
    }

    /// L'adversaire n'a pas fini : on n'affiche ni score partiel ni temps, seulement où il en est.
    private var opponentPending: String? {
        guard !duel.isFinished, duel.status != "expired" else { return nil }
        guard let opponent = duel.opponent else { return "Pas encore d'adversaire" }
        if opponent.answered >= duel.questionCount { return nil }
        return opponent.answered == 0 ? "Pas encore joué" : "En train de jouer"
    }

    private func pendingColumn(_ handle: String, text: String) -> some View {
        VStack(spacing: 8) {
            Text(handle).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            Image(systemName: "hourglass").font(.system(size: 40, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                .frame(height: 64)
            Text(text).font(.cfFootnote.weight(.bold)).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.m)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func column(_ handle: String, score: Int?, ms: Int?, marks: [Duel.Mark], highlight: Bool) -> some View {
        VStack(spacing: 8) {
            Text(handle).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(score.map { "\($0)" } ?? "?").numeral(size: 64).foregroundStyle(highlight ? Color.sun : .white)
                .scaleEffect(appeared ? 1 : 0.4)
            TallyMark(results: marks.compactMap(\.isCorrect), onInk: true).frame(width: 56)
            Text(ms.map { DurationFormat.clock(milliseconds: $0) } ?? "—").font(.cfFootnote.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(Space.m)
        .background(.white.opacity(highlight ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Liste (onglet Amis)

/// Duel à ouvrir en plein écran.
struct DuelLaunch: Identifiable {
    let id: UUID
}

struct DuelRow: View {
    let duel: Duel
    /// Afficher l'adversaire (liste générale) ou la date (profil d'un ami).
    var showsDate = false
    var onOpen: () -> Void
    var onDecline: () -> Void = {}
    /// Supprimer un défi que j'ai lancé et que personne n'a commencé (D-114).
    var onCancel: (() -> Void)? = nil

    @State private var confirmDecline = false
    @State private var confirmCancel = false

    /// Mon défi, sans aucune réponse ni de moi ni de l'autre : on peut le supprimer. Dès une réponse, il faut finir.
    private var cancellable: Bool {
        duel.iAmChallenger && ["open", "active"].contains(duel.status) && duel.me.answered == 0
            && (duel.opponent?.answered ?? 0) == 0
    }

    private var status: (String, Color) {
        switch duel.winner {
        case "me": return ("Gagné \(duel.me.score)–\(duel.opponent?.score ?? 0)", .correct)
        case "opponent": return ("Perdu \(duel.me.score)–\(duel.opponent?.score ?? 0)", .wrong)
        case "draw": return ("Égalité", .inkSoft)
        default: break
        }
        if duel.status == "expired" { return ("Expiré", .inkSoft) }
        if cancellable { return ("Pas encore commencé", .brand) }
        if duel.myTurn { return (duel.me.answered > 0 ? "À finir" : "À toi de jouer", .brand) }
        if duel.opponent == nil { return ("Lien en attente", .inkSoft) }
        return ("En attente de \(duel.opponent?.handle ?? "l'adversaire")", .inkSoft)
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                if let opponent = duel.opponent, let handle = opponent.handle {
                    ArenaAvatar(handle: handle, size: 44, ring: duel.myTurn ? Color.brand : nil, avatar: opponent.avatar)
                } else {
                    ArenaMystery(size: 44, onInk: false)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(showsDate ? DuelText.date(duel) : (duel.opponent?.handle.map { "Contre \($0)" } ?? "Défi par lien"))
                        .font(.cfTitle3).foregroundStyle(Color.ink)
                    Text(status.0).font(.cfFootnote.weight(.bold)).foregroundStyle(status.1)
                    Text(DuelText.settings(duel)).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer(minLength: 0)
                if duel.myTurn, !duel.iAmChallenger, duel.me.answered == 0 {
                    // Petite pastille grise, et une confirmation : un doigt qui glisse ne refuse pas le défi.
                    Button("Refuser") { confirmDecline = true }
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.inkSoft)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.paper, in: Capsule())
                        .buttonStyle(.plain)
                } else if cancellable, onCancel != nil {
                    Button("Supprimer") { confirmCancel = true }
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.wrong)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.wrong.opacity(0.1), in: Capsule())
                        .buttonStyle(.plain)
                }
                Image(systemName: "chevron.right").font(.callout.weight(.heavy)).foregroundStyle(Color.inkSoft.opacity(0.6))
            }
            .popCard(padding: 12)
        }
        .buttonStyle(.row)
        .confirmationDialog("Refuser le défi de \(duel.opponent?.handle ?? "ton adversaire") ?",
                            isPresented: $confirmDecline, titleVisibility: .visible) {
            Button("Refuser le défi", role: .destructive, action: onDecline)
        }
        .confirmationDialog("Supprimer ce défi ?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Supprimer le défi", role: .destructive) { onCancel?() }
        } message: {
            Text("Personne ne l'a encore commencé : il disparaît chez toi et chez ton ami.")
        }
    }
}

/// Textes communs des duels.
enum DuelText {
    /// « 10 questions · Histoire, Sciences · Difficile »
    static func settings(_ duel: Duel) -> String {
        var parts = ["\(duel.questionCount) questions"]
        if let seconds = duel.seconds { parts.append("\(seconds) s") }
        if let domains = duel.domains, !domains.isEmpty {
            parts.append(domains.count <= 2 ? domains.map(DomainPalette.fallbackName).joined(separator: ", ")
                                            : "\(domains.count) domaines")
        } else if duel.seconds == nil {
            parts.append("tous les domaines")
        }
        if let difficulty = duel.difficulty.flatMap(DuelDifficulty.init(rawValue:)), difficulty != .auto {
            parts.append(difficulty.title.lowercased())
        }
        return parts.joined(separator: " · ")
    }

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoPlain = ISO8601DateFormatter()

    private static let output: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter
    }()

    /// « 30 septembre »
    static func date(_ duel: Duel) -> String {
        guard let raw = duel.createdAt, let date = iso.date(from: raw) ?? isoPlain.date(from: raw) else { return "Duel" }
        return output.string(from: date)
    }

    private static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return iso.date(from: raw) ?? isoPlain.date(from: raw)
    }

    private static let monthFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter
    }()

    /// Jour du duel (sa fin, sinon sa création) : « Aujourd'hui », « Hier », « 30 septembre ».
    static func day(_ duel: Duel) -> String {
        guard let date = parse(duel.finishedAt) ?? parse(duel.createdAt) else { return "Duel" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(date) { return "Hier" }
        return output.string(from: date)
    }

    /// « Octobre 2026 »
    static func month(_ duel: Duel) -> String {
        guard let date = parse(duel.finishedAt) ?? parse(duel.createdAt) else { return "Plus ancien" }
        let text = monthFormat.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Format court : « 7 questions · 25 s », « 10 questions ».
    static func format(_ duel: Duel) -> String {
        duel.seconds.map { "\(duel.questionCount) questions · \($0) s" } ?? "\(duel.questionCount) questions"
    }
}
