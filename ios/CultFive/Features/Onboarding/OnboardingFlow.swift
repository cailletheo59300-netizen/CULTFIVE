import SwiftUI
import CultFiveCore

/// Onboarding : on joue tout de suite (3 vraies questions, annoncées et expliquées), on voit son résultat et le niveau
/// proposé, on choisit ses domaines et son pseudo, on peut créer son compte, puis on ouvre un coffre de bienvenue.
/// Repère d'étape nommé (« Étape 2 sur 4 · Tes domaines ») et retour après les questions. Le rappel de notification est proposé plus tard, après le premier 5 du jour.
struct OnboardingFlow: View {
    enum Step: Int, Hashable, Comparable {
        case welcome, intro, questions, result, interests, handle, account, gift, howItWorks
        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }

    @Environment(AppModel.self) private var app
    @State private var step: Step = .welcome
    @State private var pack: PlayPack?
    @State private var index = 0
    @State private var phase: AnswerPhase = .answering
    @State private var attempts: [PlayAttempt] = []
    @State private var correctCount = 0
    @State private var stopwatch = Stopwatch()
    @State private var level = "balanced"
    @State private var interests: Set<String> = []
    @State private var busy = false
    @State private var error: String?
    @State private var welcomeChest: ChestRef?

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            switch step {
            case .welcome: welcome
            case .intro: framed { intro }
            case .questions: questions
            case .result: framed(back: false) { resultStep }
            case .interests: framed { interestsStep }
            case .handle: framed { HandleStep { step = app.isAnonymous ? .account : .gift; Task { await prepareGift() } } }
            case .account: framed { accountStep }
            case .gift: giftStep
            case .howItWorks: howItWorks
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

    // MARK: Cadre : repère d'étape et retour

    /// Étapes nommées après les questions (pendant les questions, seul « Question 1 sur 3 » s'affiche).
    private static let namedSteps: [(step: Step, name: String)] = [
        (.result, "Ton niveau"), (.interests, "Tes domaines"), (.handle, "Ton pseudo"), (.account, "Ton compte"),
    ]

    private var previous: Step? {
        switch step {
        case .intro: return .welcome
        case .interests: return .result
        case .handle: return .interests
        case .account: return .handle
        default: return nil
        }
    }

    private func framed<Content: View>(back: Bool = true, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.s) {
                if back, let previous {
                    Button {
                        Haptics.selection()
                        step = previous
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.ink)
                            .frame(width: 36, height: 36)
                            .background(Color.paperRaised, in: Circle())
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Retour")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
                Spacer()
                if let index = Self.namedSteps.firstIndex(where: { $0.step == step }) {
                    HStack(spacing: 6) {
                        ForEach(0 ..< Self.namedSteps.count, id: \.self) { i in
                            Capsule().fill(i <= index ? Color.brand : Color.hairline)
                                .frame(width: i == index ? 18 : 7, height: 7)
                        }
                        Text("Étape \(index + 1) sur \(Self.namedSteps.count) · \(Self.namedSteps[index].name)")
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.inkSoft)
                            .padding(.leading, 4)
                    }
                    .animation(Motion.standard, value: index)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Étape \(index + 1) sur \(Self.namedSteps.count) : \(Self.namedSteps[index].name)")
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, Space.s)
            content()
        }
    }

    // MARK: 1. Accueil

    /// Premier écran : fond violet, Léon qui salue au milieu d'une ronde de domaines. Fait pour donner envie en 2 secondes.
    private var welcome: some View {
        ZStack {
            Color.popGradient.ignoresSafeArea()
            VStack(spacing: Space.l) {
                Spacer()
                ZStack {
                    FloatingDomains()
                    Leon(color: .sun, pose: .wave, curl: 0.7).frame(width: 190)
                }
                .frame(height: 280)
                VStack(spacing: Space.s) {
                    Text(Brand.name)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(Brand.onboardingHook)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.sun)
                        .multilineTextAlignment(.center)
                    Text("5 questions par jour. Tout le monde les mêmes.\nQui en sait le plus ?")
                        .font(.cfCallout)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                Spacer()
                Button("C'est parti !") { step = .intro }
                    .buttonStyle(.sun)
            }
            .padding(Space.gutter)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: 2. Ce qui va se passer

    private var intro: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Spacer(minLength: Space.m)
            Leon(color: .brand, pose: .curious, curl: 0.5).frame(width: 130)
            Text("On fait connaissance").font(.cfDisplay)
            VStack(alignment: .leading, spacing: Space.m) {
                introLine("3", "vraies questions, sur des sujets variés.")
                introLine("0", "pression : il n'y a rien à perdre, c'est juste pour régler \(Brand.name) à ton niveau.")
                introLine("5", "questions chaque jour ensuite : les mêmes pour tout le monde, c'est le \(Brand.dailyName).")
            }
            Spacer()
            Button("Je suis prêt") {
                step = .questions
                if pack == nil { Task { await loadPack() } }
            }
            .buttonStyle(.ink)
        }
        .padding(Space.gutter)
    }

    private func introLine(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Text(number)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.brand)
                .frame(width: 34, alignment: .leading)
            Text(text).font(.cfReading).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 3. Trois vraies questions

    @ViewBuilder private var questions: some View {
        if let pack, pack.questions.indices.contains(index) {
            let question = pack.questions[index]
            QuestionScreen(
                question: question,
                domainName: app.domainName(question.domainId),
                phase: phase,
                continueTitle: index == pack.questions.count - 1 ? "Voir mon résultat" : "Suivante",
                onSubmit: { submit($0, question: question) },
                onContinue: { advance() },
                onDisplayed: { stopwatch.reset(); stopwatch.start() }
            ) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Question \(index + 1) sur \(pack.questions.count)").font(.cfNumber).foregroundStyle(Color.ink)
                    Text("pour régler ton niveau").font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(Color.inkSoft)
                }
            }
            .id(question.id)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
        } else if let error {
            VStack(spacing: Space.l) {
                Text(error).font(.cfBody)
                Button("Réessayer") { Task { await loadPack() } }.buttonStyle(.ink)
                Button("Passer") { step = .result }.buttonStyle(.textLink)
            }
            .padding(Space.gutter)
        } else {
            ProgressView().frame(maxHeight: .infinity)
        }
    }

    private func loadPack() async {
        error = nil
        do {
            let loaded = try await app.service.onboardingPack()
            if loaded.questions.isEmpty { step = .result } else { pack = loaded }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Connexion impossible."
        }
    }

    private func submit(_ given: GivenAnswer, question: Question) {
        guard phase.isAnswering, let reveal = question.reveal else { return }
        stopwatch.pause()
        let correct = AnswerEvaluator.isCorrect(given, for: question) ?? false
        attempts.append(PlayAttempt(questionId: question.id, given: given, responseMs: stopwatch.elapsedMilliseconds))
        if correct { correctCount += 1 }
        Feedback.answer(correct)
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
            level = correctCount >= 3 ? "challenge" : correctCount == 2 ? "balanced" : "discovery"
            step = .result
        }
    }

    // MARK: 4. Résultat et niveau proposé

    private var total: Int { pack?.questions.count ?? 0 }

    private var resultStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack(alignment: .bottom, spacing: Space.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        if total > 0 {
                            Text("\(correctCount) sur \(total)").font(.system(size: 52, weight: .black, design: .rounded))
                                .foregroundStyle(Color.brand)
                            Text(verdict).font(.cfHeadline)
                        } else {
                            Text("Ton niveau de départ").font(.cfDisplay)
                        }
                    }
                    Spacer()
                    Leon(color: .brand, pose: correctCount >= 2 ? .proud : .curious, curl: 0.6).frame(width: 110)
                }
                .padding(.top, Space.m)
                (total > 0
                    ? Text("On te propose le niveau ") + Text(levelName(level)).bold().foregroundColor(Color.ink)
                        + Text(". \(Brand.name) s'ajustera ensuite à chacune de tes réponses. Tu peux changer :")
                    : Text("Choisis un point de départ. \(Brand.name) s'ajustera ensuite à chacune de tes réponses."))
                    .font(.cfCallout).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    levelRow("discovery", "Des questions accessibles pour commencer.")
                    levelRow("balanced", "Un peu de tout, ni trop simple ni trop dur.")
                    levelRow("challenge", "Tu aimes être poussé.")
                    levelRow("expert", "Tu penses tout savoir. Vraiment ?")
                }
                Button("Continuer") { step = .interests }.buttonStyle(.ink).padding(.top, Space.s)
            }
            .padding(Space.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private var verdict: String {
        switch correctCount {
        case 3...: return "Impressionnant !"
        case 2: return "Pas mal du tout."
        case 1: return "Un bon début."
        default: return "Pas de panique : ici, on apprend."
        }
    }

    private func levelName(_ id: String) -> String {
        switch id {
        case "discovery": return "Découverte"
        case "challenge": return "Challenge"
        case "expert": return "Expert"
        default: return "Équilibre"
        }
    }

    private func levelRow(_ id: String, _ detail: String) -> some View {
        Button {
            Haptics.selection()
            level = id
        } label: {
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(levelName(id)).font(.cfTitle3).foregroundStyle(level == id ? .white : Color.ink)
                    Text(detail).font(.cfFootnote).foregroundStyle(level == id ? .white.opacity(0.85) : Color.inkSoft)
                }
                Spacer()
                Image(systemName: level == id ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(level == id ? .white : Color.hairline)
            }
            .padding(Space.m)
            .background(level == id ? Color.brand : Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .shadow(color: level == id ? Color.brand.opacity(0.3) : .clear, radius: 10, y: 5)
            .animation(Motion.bounce, value: level)
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(level == id ? .isSelected : [])
    }

    // MARK: 5. Centres d'intérêt (personnalisent Jouer, jamais le Daily)

    private var interestsStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Ce qui t'attire").font(.cfDisplay).padding(.top, Space.m)
            Text("Pour composer tes parties : choisis-en au moins 3 pour qu'elles restent variées. Le \(Brand.dailyName) mélange tout, pour tout le monde.")
                .font(.cfCallout).foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                FlowLayout(spacing: Space.s) {
                    ForEach(domainOptions, id: \.id) { domain in
                        let selected = interests.contains(domain.id)
                        Button {
                            Haptics.selection()
                            if selected { interests.remove(domain.id) } else { interests.insert(domain.id) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: selected ? "checkmark" : DomainPalette.symbol(domain.id))
                                    .foregroundStyle(selected ? DomainPalette.onColor(domain.id) : DomainPalette.color(domain.id))
                                Text(domain.name)
                            }
                            .font(.system(.callout, design: .rounded).weight(.heavy))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 46)
                            .foregroundStyle(selected ? DomainPalette.onColor(domain.id) : Color.ink)
                            .background(selected ? DomainPalette.color(domain.id) : Color.paperRaised, in: Capsule())
                            .shadow(color: selected ? DomainPalette.color(domain.id).opacity(0.35) : .clear, radius: 8, y: 4)
                            .scaleEffect(selected ? 1.04 : 1)
                            .animation(Motion.bounce, value: selected)
                        }
                        .buttonStyle(.row)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            Text(interests.isEmpty ? "Aucun choisi : tes parties piocheront partout." : "\(interests.count) choisi\(interests.count > 1 ? "s" : "")")
                .font(.cfFootnote.weight(.bold)).foregroundStyle(interests.count >= 3 || interests.isEmpty ? Color.inkSoft : Color(hex: 0xE8590C))
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
            step = .handle
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
        }
    }

    // MARK: 7. Compte (facultatif à ce stade)

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Spacer()
            Leon(color: .brand, pose: .proud).frame(width: 150)
            Text("Garde ta progression").font(.cfDisplay)
            Text("Avec un compte, ta série, tes amis, tes coffres et l'arbre de Léon te suivent, même si tu changes d'iPhone. Ça se fait en un geste, et tu peux aussi le faire plus tard.")
                .font(.cfCallout).foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            AccountInline { step = .gift }
            Button("Plus tard") { step = .gift }.buttonStyle(.textLink)
        }
        .padding(Space.gutter)
    }

    // MARK: 8. Cadeau de bienvenue, puis comment ça marche

    private func prepareGift() async {
        await app.refreshProgression()
        welcomeChest = app.progression?.chests.first { $0.source == "welcome" }
    }

    @ViewBuilder private var giftStep: some View {
        if let welcomeChest {
            ChestOpeningView(chests: [welcomeChest]) { step = .howItWorks }
        } else {
            howItWorks
                .task {
                    await prepareGift()
                }
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Spacer(minLength: Space.m)
            Leon(color: .brand, pose: .wave, curl: 0.6).frame(width: 130)
            Text("Voilà comment ça marche").font(.cfDisplay)
            VStack(alignment: .leading, spacing: Space.m) {
                howLine(title: "Un \(Brand.dailyName) chaque jour", detail: "Les 5 mêmes questions pour tout le monde. Ta série grandit jour après jour.") {
                    TallyMark(strokes: [.correct, .correct, .correct, .correct, .ready]).frame(width: 46)
                }
                howLine(title: "Des coffres à gagner", detail: "Défis du jour et de la semaine, niveaux, trophées, podium de ligue.") {
                    ChestView(tier: .gold).frame(width: 46)
                }
                howLine(title: "L'arbre de Léon", detail: "Nourris-le de tes graines : il grandit, puis donne des fruits rares.") {
                    LeonTreeView(stage: 3).frame(width: 46, height: 46)
                }
            }
            Spacer()
            Button("Allons-y !") { Task { await finish() } }
                .buttonStyle(.ink)
                .disabled(busy)
        }
        .padding(Space.gutter)
    }

    private func howLine<Art: View>(title: String, detail: String, @ViewBuilder art: () -> Art) -> some View {
        HStack(spacing: Space.m) {
            art().frame(width: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.cfTitle3).foregroundStyle(Color.ink)
                Text(detail).font(.cfFootnote).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func finish() async {
        busy = true
        await app.finishOnboarding()
        busy = false
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
            Text("Ton pseudo").font(.cfDisplay).padding(.top, Space.m)
            Text("C'est ainsi que tes amis te verront dans leurs ligues.").font(.cfCallout).foregroundStyle(Color.inkSoft)
            TextField("pseudo", text: $handle)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, Space.m)
                .frame(minHeight: 60)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(status == nil ? Color.hairline : (available ? Color.correct : Color.wrong), lineWidth: 2))
            if let status {
                Text(status).font(.cfFootnote).foregroundStyle(available ? Color.correct : Color.wrong)
            }
            Button {
                Task { await suggest() }
            } label: {
                Label("Proposer un pseudo", systemImage: "dice.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.brand)
                    .padding(.horizontal, 14).frame(minHeight: 40)
                    .background(Color.brand.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.row)
            .disabled(busy)
            Spacer()
            Button("Valider mon pseudo") { save() }
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

    private static let firstWords = ["Curieux", "Malin", "Rapide", "Brillant", "Sage", "Vif", "Joyeux", "Calme", "Tenace",
                                      "Hardi", "Subtil", "Lucide"]
    private static let secondWords = ["Hibou", "Renard", "Lynx", "Panda", "Castor", "Koala", "Loup", "Lion", "Faucon",
                                       "Dauphin", "Colibri", "Cameleon"]

    /// Invente un pseudo libre (« MalinCastor42 »), vérifié auprès du serveur ; quelques essais au plus.
    private func suggest() async {
        Haptics.selection()
        for _ in 0 ..< 5 {
            let candidate = "\(Self.firstWords.randomElement()!)\(Self.secondWords.randomElement()!)\(Int.random(in: 2...99))"
            if let result = try? await app.service.handleAvailable(candidate), result.available {
                handle = candidate
                return
            }
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

/// Pastilles de domaines qui flottent autour de Léon sur l'écran d'accueil.
private struct FloatingDomains: View {
    private let domains = ["geography", "history", "science", "arts", "sport", "cinema", "music", "french"]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                ForEach(Array(domains.enumerated()), id: \.offset) { index, id in
                    Image(systemName: DomainPalette.symbol(id))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DomainPalette.onColor(id))
                        .frame(width: 44, height: 44)
                        .background(DomainPalette.color(id), in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                        .position(position(index: index, time: t, size: proxy.size))
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// Ronde elliptique qui tourne lentement, chaque pastille flottant un peu.
    private func position(index: Int, time: Double, size: CGSize) -> CGPoint {
        let turning = reduceMotion ? 0 : time * 0.12
        let angle = Double(index) / Double(domains.count) * 2 * Double.pi + turning
        let radiusX = min(Double(size.width) / 2 - 34, 150)
        let radiusY = Double(size.height) / 2 - 22
        let bob = reduceMotion ? 0 : sin(time * 2 + Double(index)) * 4
        return CGPoint(x: Double(size.width) / 2 + radiusX * cos(angle),
                       y: Double(size.height) / 2 + radiusY * sin(angle) + bob)
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
