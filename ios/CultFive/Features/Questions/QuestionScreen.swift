import SwiftUI
import CultFiveCore

/// Écran de question : concentration. Pastille du domaine, progression, énoncé, réponses en pastilles.
/// Un voile de la couleur du domaine en haut d'écran donne l'ambiance sans gêner la lecture.
/// Partagé par le Daily, Jouer et l'onboarding ; chaque mode fournit sa progression et ses aides.
struct QuestionScreen<Trailing: View, Help: View>: View {
    let question: Question
    let domainName: String
    let phase: AnswerPhase
    var removedOptions: Set<String> = []
    var badge: String? = nil
    var continueTitle: String = "Continuer"
    let onSubmit: (GivenAnswer) -> Void
    let onContinue: () -> Void
    var onDisplayed: () -> Void = {}
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var help: () -> Help

    @State private var entry = NumericEntry()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                DomainTag(domainId: question.domainId, name: domainName)
                Spacer()
                trailing()
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.m)

            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.l) {
                        Text(question.prompt)
                            .font(.cfQuestion)
                            .foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Space.gutter)
                            .accessibilityAddTraits(.isHeader)

                        answerArea

                        if phase.isAnswering {
                            help()
                        }

                        if let result = phase.revealed {
                            RevealPanel(question: question, isCorrect: result.isCorrect, reveal: result.reveal,
                                        given: phase.given, badge: badge)
                                .id("reveal")
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.bottom, Space.xl)
                }
                .scrollIndicators(.hidden)
                .onChange(of: phase.revealed != nil) { _, revealed in
                    guard revealed else { return }
                    withAnimation(Motion.adaptive(Motion.standard, reduceMotion: reduceMotion)) {
                        reader.scrollTo("reveal", anchor: .top)
                    }
                }
            }

            if question.type == .numeric && phase.isAnswering {
                NumericKeypad(entry: $entry) {
                    if let value = entry.value { onSubmit(.number(value)) }
                }
                .padding(.bottom, Space.s)
            } else if phase.revealed != nil {
                Button(continueTitle, action: onContinue)
                    .buttonStyle(.domain(question.domainId))
                    .padding(.horizontal, Space.gutter)
                    .padding(.vertical, Space.s)
            } else if case .submitting = phase {
                ProgressView().frame(height: 56).padding(.vertical, Space.s)
            }
        }
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Color.paper
                LinearGradient(colors: [DomainPalette.color(question.domainId).opacity(0.16), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 280)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            entry = NumericEntry(maxDecimals: max(question.payload.decimals ?? 0, 3),
                                 allowNegative: question.payload.allowNegative ?? false)
            onDisplayed()
        }
        .animation(Motion.adaptive(Motion.standard, reduceMotion: reduceMotion), value: phase)
    }

    @ViewBuilder private var answerArea: some View {
        switch question.type {
        case .mcq:
            if let shape = question.payload.shape {
                CountryShapeView(shape: shape, color: DomainPalette.color(question.domainId))
                    .frame(height: 200)
                    .padding(Space.m)
                    .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                    .padding(.horizontal, Space.gutter)
            }
            ChoiceAnswerView(options: question.payload.options ?? [], phase: phase, removed: removedOptions,
                             accent: DomainPalette.color(question.domainId), onSubmit: onSubmit)
        case .trueFalse:
            TrueFalseAnswerView(phase: phase, onSubmit: onSubmit)
        case .numeric:
            NumericDisplay(entry: displayedEntry, unit: question.payload.unit)
                .padding(.horizontal, Space.gutter)
        case .ordering:
            OrderingAnswerView(items: question.payload.items ?? [], phase: phase, onSubmit: onSubmit)
        case .pairs:
            PairsAnswerView(left: question.payload.left ?? [], right: question.payload.right ?? [], phase: phase, onSubmit: onSubmit)
        case .mapPick:
            if let region = question.payload.region {
                MapPickAnswerView(region: region, options: question.payload.options ?? [], phase: phase, onSubmit: onSubmit)
            }
        }
    }

    /// Après validation, on affiche la valeur soumise (même si l'état local a été réinitialisé).
    private var displayedEntry: NumericEntry {
        guard case .number(let value)? = phase.given, entry.isEmpty else { return entry }
        var restored = NumericEntry(maxDecimals: 6, allowNegative: true, maxDigits: 15)
        let text = NSDecimalNumber(decimal: abs(value)).stringValue
        for char in text {
            if char == "." { restored.appendDecimalSeparator() } else if let digit = char.wholeNumberValue { restored.append(digit: digit) }
        }
        if value < 0 { restored.toggleSign() }
        return restored
    }
}

extension QuestionScreen where Help == EmptyView {
    init(question: Question, domainName: String, phase: AnswerPhase, removedOptions: Set<String> = [], badge: String? = nil,
         continueTitle: String = "Continuer", onSubmit: @escaping (GivenAnswer) -> Void, onContinue: @escaping () -> Void,
         onDisplayed: @escaping () -> Void = {}, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(question: question, domainName: domainName, phase: phase, removedOptions: removedOptions, badge: badge,
                  continueTitle: continueTitle, onSubmit: onSubmit, onContinue: onContinue, onDisplayed: onDisplayed,
                  trailing: trailing, help: { EmptyView() })
    }
}

/// Verdict + explication. Léon réagit (langue sur une bonne réponse, gris sur une mauvaise), puis l'explication en carte.
struct RevealPanel: View {
    let question: Question
    let isCorrect: Bool
    let reveal: Reveal
    let given: GivenAnswer?
    var badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .center, spacing: Space.s) {
                Leon(color: DomainPalette.color(question.domainId), pose: isCorrect ? .tongue : .sad)
                    .frame(width: 78)
                VStack(alignment: .leading, spacing: 4) {
                    Text(isCorrect ? "Juste !" : "Raté…")
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(isCorrect ? Color.correct : Color.wrong)
                    if let badge {
                        Text(badge)
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.correct, in: Capsule())
                    }
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: Space.m) {
                if let answerText = AnswerText.correct(for: question, answer: reveal.answer), !isCorrect || question.type == .numeric {
                    HStack(spacing: Space.s) {
                        Text("Réponse").labelCaps()
                        Text(answerText)
                            .font(.system(.body, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.correct)
                    }
                }

                Text(reveal.explanation)
                    .font(.cfReading)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let takeaway = reveal.takeaway {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("À retenir", systemImage: "lightbulb.fill").labelCaps(DomainPalette.color(question.domainId))
                        Text(takeaway).font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DomainPalette.color(question.domainId).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                }

                if let source = reveal.source {
                    Text(sourceLine(source)).font(.cfFootnote).foregroundStyle(Color.inkSoft)
                }
            }
            .popCard()
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
    }

    private func sourceLine(_ source: String) -> String {
        guard let date = reveal.factAsOf else { return "Source : \(source)" }
        return "Source : \(source) (\(date.prefix(4)))"
    }
}

enum AnswerText {
    /// Bonne réponse en toutes lettres, quand c'est pertinent (QCM, vrai/faux, nombre).
    static func correct(for question: Question, answer: CorrectAnswer) -> String? {
        switch question.type {
        case .mcq:
            return question.payload.options?.first { $0.id == answer.optionId }?.text
        case .trueFalse:
            return answer.value?.boolValue.map { $0 ? "Vrai" : "Faux" }
        case .numeric:
            guard let value = answer.value?.doubleValue else { return nil }
            let text = NumberFormat.display(value)
            return question.payload.unit.map { "\(text) \($0)" } ?? text
        case .ordering, .pairs, .mapPick:
            return nil
        }
    }
}
