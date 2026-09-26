import SwiftUI
import CultFiveCore

/// Onboarding court : on joue tout de suite (3 vraies questions), puis 3 choix rapides. Pas de tutoriel abstrait.
struct OnboardingFlow: View {
    enum Step: Hashable { case welcome, questions, level, interests, account, handle }

    @Environment(AppModel.self) private var app
    @State private var step: Step = .welcome
    @State private var pack: PlayPack?
    @State private var index = 0
    @State private var phase: AnswerPhase = .answering
    @State private var attempts: [PlayAttempt] = []
    @State private var stopwatch = Stopwatch()
    @State private var level = "balanced"
    @State private var interests: Set<String> = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            switch step {
            case .welcome: welcome
            case .questions: questions
            case .level: levelStep
            case .interests: interestsStep
            case .account: accountStep
            case .handle: HandleStep { Task { await finish() } }
            }
        }
        .animation(Motion.standard, value: step)
        .task {
            #if DEBUG
            if Demo.screen == .onboardingQuestion {
                step = .questions
                await loadPack()
            }
            #endif
        }
    }

    // MARK: 1. Accueil

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Spacer()
            Leon(color: .chloro, pose: .curious).frame(width: 190)
            Text(Brand.name)
                .font(.system(size: 44, weight: .black, design: .serif))
                .tracking(2)
            Text(Brand.onboardingHook)
                .font(.system(.title, design: .serif).italic())
                .foregroundStyle(Color.inkSoft)
            Spacer()
            Button("Commencer") {
                step = .questions
                Task { await loadPack() }
            }
            .buttonStyle(.ink)
        }
        .padding(Space.gutter)
    }

    // MARK: 2–3. Trois vraies questions

    @ViewBuilder private var questions: some View {
        if let pack, pack.questions.indices.contains(index) {
            let question = pack.questions[index]
            QuestionScreen(
                question: question,
                domainName: app.domainName(question.domainId),
                phase: phase,
                continueTitle: index == pack.questions.count - 1 ? "Continuer" : "Suivante",
                onSubmit: { submit($0, question: question) },
                onContinue: { advance() },
                onDisplayed: { stopwatch.reset(); stopwatch.start() }
            ) {
                Text("\(index + 1) / \(pack.questions.count)").font(.cfNumber).foregroundStyle(Color.inkSoft)
            }
            .id(question.id)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
        } else if let error {
            VStack(spacing: Space.l) {
                Text(error).font(.cfBody)
                Button("Réessayer") { Task { await loadPack() } }.buttonStyle(.ink)
                Button("Passer") { step = .level }.buttonStyle(.textLink)
            }
            .padding(Space.gutter)
        } else {
            ProgressView()
        }
    }

    private func loadPack() async {
        error = nil
        do {
            let loaded = try await app.service.onboardingPack()
            if loaded.questions.isEmpty { step = .level } else { pack = loaded }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Connexion impossible."
        }
    }

    private func submit(_ given: GivenAnswer, question: Question) {
        guard phase.isAnswering, let reveal = question.reveal else { return }
        stopwatch.pause()
        let correct = AnswerEvaluator.isCorrect(given, for: question) ?? false
        attempts.append(PlayAttempt(questionId: question.id, given: given, responseMs: stopwatch.elapsedMilliseconds))
        correct ? Haptics.success() : Haptics.error()
        phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
    }

    private func advance() {
        guard let pack else { return }
        if index < pack.questions.count - 1 {
            index += 1
            phase = .answering
        } else {
            // Les réponses de l'onboarding comptent déjà : première estimation du niveau.
            let session = pack.sessionId
            let answers = attempts
            let queue = app.queue
            let service = app.service
            Task {
                do {
                    _ = try await service.playSubmit(session: session, attempts: answers)
                } catch {
                    await queue.enqueue(session: session, attempts: answers)
                }
            }
            step = .level
        }
    }

    // MARK: 4. Niveau de challenge (prior initial)

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Quel niveau de défi ?").font(.cfDisplay).padding(.top, Space.xl)
            Text("Un point de départ. Ensuite, \(Brand.name) s'ajuste à tes réponses.")
                .font(.cfCallout).foregroundStyle(Color.inkSoft)
            VStack(spacing: 0) {
                levelRow("discovery", "Découverte", "Des questions accessibles pour commencer.")
                levelRow("balanced", "Équilibre", "Un peu de tout, ni trop simple ni trop dur.")
                levelRow("challenge", "Challenge", "Tu aimes être poussé.")
                levelRow("expert", "Expert", "Tu penses tout savoir. Vraiment ?")
            }
            Spacer()
            Button("Continuer") { step = .interests }.buttonStyle(.ink)
        }
        .padding(Space.gutter)
    }

    private func levelRow(_ id: String, _ title: String, _ detail: String) -> some View {
        Button {
            Haptics.selection()
            level = id
        } label: {
            HStack(spacing: Space.m) {
                Image(systemName: level == id ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(Color.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.cfTitle3).foregroundStyle(Color.ink)
                    Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) { Hairline() }
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(level == id ? .isSelected : [])
    }

    // MARK: 5. Centres d'intérêt (personnalisent Jouer, jamais le Daily)

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Ce qui t'attire").font(.cfDisplay).padding(.top, Space.xl)
            Text("Pour composer tes parties. Le \(Brand.dailyName) reste varié pour tout le monde.")
                .font(.cfCallout).foregroundStyle(Color.inkSoft)
            FlowLayout(spacing: Space.s) {
                ForEach(domainOptions, id: \.id) { domain in
                    let selected = interests.contains(domain.id)
                    Button {
                        Haptics.selection()
                        if selected { interests.remove(domain.id) } else { interests.insert(domain.id) }
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(DomainPalette.color(domain.id)).frame(width: 8, height: 8)
                            Text(domain.name)
                        }
                        .font(.system(.callout).weight(.medium))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .foregroundStyle(selected ? Color.paper : Color.ink)
                        .background(selected ? Color.ink : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(Color.ink.opacity(selected ? 0 : 0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Spacer()
            Button(interests.isEmpty ? "Passer" : "Continuer") {
                Task { await saveChoices() }
            }
            .buttonStyle(.ink)
            .disabled(busy)
            if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
        }
        .padding(Space.gutter)
    }

    private var domainOptions: [DomainInfo] {
        app.domains.isEmpty
            ? ["history", "geography", "science", "french", "sport", "arts", "logic", "tech", "cinema", "music", "nature", "calc"]
                .enumerated().map { DomainInfo(id: $0.element, name: DomainPalette.fallbackName($0.element), dailySlot: nil, sort: $0.offset) }
            : app.domains
    }

    private func saveChoices() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await app.service.completeOnboarding(level: level, interests: Array(interests))
            step = app.isAnonymous ? .account : .handle
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
        }
    }

    // MARK: 6. Compte (facultatif à ce stade)

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Spacer()
            Leon(color: .chloro, pose: .proud).frame(width: 150)
            Text("Garde ta progression.").font(.cfDisplay)
            Text("Crée ton compte en un geste pour retrouver ta série et tes amis partout. Tu peux aussi le faire plus tard.")
                .font(.cfCallout).foregroundStyle(Color.inkSoft)
            Spacer()
            AccountInline { step = .handle }
            Button("Plus tard") { step = .handle }.buttonStyle(.textLink)
        }
        .padding(Space.gutter)
    }

    private func finish() async {
        await app.finishOnboarding()
    }
}

/// Bouton compte intégré à l'onboarding (ouvre la feuille complète).
private struct AccountInline: View {
    var onDone: () -> Void
    @State private var show = false

    var body: some View {
        Button("Créer mon compte") { show = true }
            .buttonStyle(.ink)
            .sheet(isPresented: $show) {
                AccountSheet(onDone: onDone)
            }
    }
}

/// Choix du pseudo (unique, vérifié en temps réel).
private struct HandleStep: View {
    var onDone: () -> Void

    @Environment(AppModel.self) private var app
    @State private var handle = ""
    @State private var status: String?
    @State private var available = true
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Ton pseudo").font(.cfDisplay).padding(.top, Space.xl)
            Text("C'est ainsi que tes amis te verront dans leurs ligues.").font(.cfCallout).foregroundStyle(Color.inkSoft)
            TextField("pseudo", text: $handle)
                .font(.system(.title, design: .serif))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.vertical, Space.s)
                .overlay(alignment: .bottom) { Hairline(color: .ink) }
            if let status {
                Text(status).font(.cfFootnote).foregroundStyle(available ? Color.correct : Color.wrong)
            }
            Spacer()
            Button("C'est parti") { save() }
                .buttonStyle(.ink)
                .disabled(busy || !available || handle.count < 3)
        }
        .padding(Space.gutter)
        .onAppear { handle = app.profile?.handle ?? "" }
        .task(id: handle) {
            guard handle != app.profile?.handle, handle.count >= 3 else { status = nil; available = handle.count >= 3; return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let result = try? await app.service.handleAvailable(handle) else { return }
            available = result.available
            status = result.available ? "Disponible" : (result.reason == "invalid" ? "3 à 20 caractères : lettres, chiffres ou _."
                                                        : result.reason == "not_allowed" ? "Pseudo non autorisé." : "Déjà pris.")
        }
    }

    private func save() {
        busy = true
        Task {
            if handle != app.profile?.handle {
                do {
                    app.profile = try await app.service.setHandle(handle)
                } catch {
                    status = (error as? LocalizedError)?.errorDescription
                    available = false
                    busy = false
                    return
                }
            }
            busy = false
            onDone()
        }
    }
}

/// Disposition en lignes qui passent à la ligne (puces de centres d'intérêt).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
