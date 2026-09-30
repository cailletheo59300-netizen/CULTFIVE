import SwiftUI
import CultFiveCore

// MARK: - Modèle

/// Partie de duel : comme le 5 du jour (question servie sans réponse, temps officiel serveur), sur la série du duel.
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
    private var lastVerdict: DailyVerdict?
    private var pendingGiven: GivenAnswer?
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
            stopwatch.reset()
            stage = .question
        } catch {
            stage = .failed(message(for: error))
        }
    }

    func questionDisplayed() { stopwatch.start() }
    func pause() { stopwatch.pause() }
    func resume() { if stage == .question && phase.isAnswering { stopwatch.start() } }

    func submit(_ given: GivenAnswer) {
        guard phase.isAnswering else { return }
        stopwatch.pause()
        let ms = stopwatch.elapsedMilliseconds
        pendingGiven = given
        pendingMs = ms
        phase = .submitting(given)
        Task { await send(given: given, ms: ms) }
    }

    func retry() {
        guard let given = pendingGiven else { return }
        isRetrying = false
        Task { await send(given: given, ms: pendingMs) }
    }

    private func send(given: GivenAnswer, ms: Int?) async {
        do {
            let verdict = try await service.duelAnswer(duel: duelId, position: position, given: given, clientMs: ms)
            guard let reveal = verdict.reveal else { throw BackendError.decoding("verdict incomplet") }
            let correct = verdict.isCorrect ?? false
            lastVerdict = verdict
            Feedback.answer(correct)
            if results.count < position { results.append(correct) }
            phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
            pendingGiven = nil
        } catch {
            isRetrying = true
        }
    }

    func next() async {
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
            ProgressView().tint(Color.brand)
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
                        Label("Duel", systemImage: "bolt.fill").font(.cfFootnote.weight(.heavy)).foregroundStyle(Color.brand)
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
                           onClose: { close() })
        }
    }

    private func close() {
        Task { await app.refreshProfile() }
        dismiss()
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
                rematchError = (error as? LocalizedError)?.errorDescription ?? "Revanche impossible pour l'instant."
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
                    player(myHandle, color: .sun, pose: .wave)
                    Text("VS").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .scaleEffect(appeared ? 1 : 0.3)
                    player(duel.opponent?.handle ?? "?", color: Color(hex: 0xFF8FB1), pose: .curious)
                }
                VStack(spacing: 6) {
                    Text("\(duel.questionCount) questions, les mêmes pour vous deux.")
                    Text(DuelText.settings(duel)).foregroundStyle(.white.opacity(0.75))
                    Text("Le meilleur score gagne ; à égalité, le plus rapide.")
                    if let opponent = duel.opponent, opponent.answered == duel.questionCount {
                        Text("\(opponent.handle ?? "Ton adversaire") a déjà joué : à toi !").foregroundStyle(Color.sun)
                    } else if duel.opponent == nil {
                        Text("Personne n'a encore rejoint : joue, puis partage le lien.").foregroundStyle(Color.sun)
                    }
                }
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

    private func player(_ handle: String, color: Color, pose: Leon.Pose) -> some View {
        VStack(spacing: 6) {
            Leon(color: color, pose: pose).frame(width: 110)
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
                        column(duel.opponent?.handle ?? "?", score: duel.opponent?.score, ms: duel.opponent?.totalMs,
                               marks: duel.theirAnswers ?? [], highlight: duel.winner == "opponent")
                    }
                    if duel.winner == "me" {
                        Label("+20 XP · +5 \(Brand.currencyPlural)", systemImage: "trophy.fill")
                            .font(.system(.callout, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkFixed)
                            .padding(.horizontal, 16).padding(.vertical, 8).background(Color.sun, in: Capsule())
                    }
                    if !duel.isFinished, duel.status != "expired" {
                        VStack(spacing: Space.s) {
                            Text(duel.opponent == nil ? "Envoie le lien : le premier qui l'ouvre devient ton adversaire."
                                                      : "Tu seras prévenu dans l'onglet Amis quand il aura joué.")
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

    private var status: (String, Color) {
        switch duel.winner {
        case "me": return ("Gagné \(duel.me.score)–\(duel.opponent?.score ?? 0)", .correct)
        case "opponent": return ("Perdu \(duel.me.score)–\(duel.opponent?.score ?? 0)", .wrong)
        case "draw": return ("Égalité", .inkSoft)
        default: break
        }
        if duel.status == "expired" { return ("Expiré", .inkSoft) }
        if duel.myTurn { return (duel.me.answered > 0 ? "À finir" : "À toi de jouer", .brand) }
        if duel.opponent == nil { return ("Lien en attente", .inkSoft) }
        return ("En attente de \(duel.opponent?.handle ?? "l'adversaire")", .inkSoft)
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(duel.myTurn ? Color.white : Color.brand)
                    .frame(width: 42, height: 42)
                    .background(duel.myTurn ? Color.brand : Color.brand.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(showsDate ? DuelText.date(duel) : (duel.opponent?.handle.map { "Contre \($0)" } ?? "Défi par lien"))
                        .font(.cfTitle3).foregroundStyle(Color.ink)
                    Text(status.0).font(.cfFootnote.weight(.bold)).foregroundStyle(status.1)
                    Text(DuelText.settings(duel)).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer(minLength: 0)
                if duel.myTurn, !duel.iAmChallenger, duel.me.answered == 0 {
                    Button("Refuser", action: onDecline).buttonStyle(TextLinkStyle(color: .inkSoft))
                }
                Image(systemName: "chevron.right").font(.callout.weight(.heavy)).foregroundStyle(Color.inkSoft.opacity(0.6))
            }
            .popCard(padding: 12)
        }
        .buttonStyle(.row)
    }
}

/// Textes communs des duels.
enum DuelText {
    /// « 10 questions · Histoire, Sciences · Difficile »
    static func settings(_ duel: Duel) -> String {
        var parts = ["\(duel.questionCount) questions"]
        if let domains = duel.domains, !domains.isEmpty {
            parts.append(domains.count <= 2 ? domains.map(DomainPalette.fallbackName).joined(separator: ", ")
                                            : "\(domains.count) domaines")
        } else {
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
}
