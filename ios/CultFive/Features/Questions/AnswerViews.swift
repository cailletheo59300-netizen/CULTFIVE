import SwiftUI
import MapKit
import CultFiveCore

/// État d'une question à l'écran.
enum AnswerPhase: Equatable {
    case answering
    case submitting(GivenAnswer?)
    case revealed(given: GivenAnswer?, isCorrect: Bool, reveal: Reveal)

    var isAnswering: Bool {
        if case .answering = self { return true }
        return false
    }

    var given: GivenAnswer? {
        switch self {
        case .answering: return nil
        case .submitting(let given): return given
        case .revealed(let given, _, _): return given
        }
    }

    var revealed: (isCorrect: Bool, reveal: Reveal)? {
        if case .revealed(_, let isCorrect, let reveal) = self { return (isCorrect, reveal) }
        return nil
    }
}

// MARK: - QCM

struct ChoiceAnswerView: View {
    let options: [Choice]
    let phase: AnswerPhase
    var removed: Set<String> = []
    var accent: Color = .brand
    let onSubmit: (GivenAnswer) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                AnswerRow(key: ["A", "B", "C", "D", "E", "F"][min(index, 5)],
                          text: option.text ?? "",
                          state: state(for: option),
                          accent: accent,
                          isDisabled: !phase.isAnswering || removed.contains(option.id)) {
                    onSubmit(.option(option.id))
                }
                .opacity(removed.contains(option.id) ? 0.25 : 1)
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private func state(for option: Choice) -> AnswerRow.RowState {
        let chosen = phase.given == .option(option.id)
        if let result = phase.revealed {
            if option.id == result.reveal.answer.optionId { return .correct }
            if chosen { return .wrong }
            return .dimmed
        }
        if case .submitting = phase, chosen { return .selected }
        return .idle
    }
}

/// Réponse en pastille : lettre dans une bulle colorée, carte blanche arrondie.
/// Choisie = aplat couleur ; juste = vert qui rebondit ; fausse = corail qui secoue.
struct AnswerRow: View {
    enum RowState { case idle, selected, correct, wrong, dimmed }

    let key: String
    let text: String
    let state: RowState
    var accent: Color = .brand
    var isDisabled = false
    let action: () -> Void

    @State private var shakes: CGFloat = 0
    @State private var pop = false

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(keyFill)
                    if state == .correct || state == .wrong {
                        Image(systemName: state == .correct ? "checkmark" : "xmark")
                            .font(.system(.callout, design: .rounded).weight(.black))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(key).font(.system(.callout, design: .rounded).weight(.heavy))
                    }
                }
                .foregroundStyle(keyText)
                .frame(width: 34, height: 34)
                Text(text)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .frame(minHeight: 62)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(border, lineWidth: 2))
            .shadow(color: shadow, radius: 10, y: 5)
        }
        .buttonStyle(AnswerPressStyle())
        .disabled(isDisabled)
        .scaleEffect(pop ? 1.04 : 1)
        .modifier(Shake(animatableData: shakes))
        .opacity(state == .dimmed ? 0.45 : 1)
        .animation(Motion.bounce, value: state)
        .onChange(of: state) { _, new in
            switch new {
            case .correct:
                withAnimation(Motion.bounce) { pop = true }
                withAnimation(Motion.bounce.delay(0.18)) { pop = false }
            case .wrong:
                withAnimation(.linear(duration: 0.4)) { shakes += 1 }
            default: break
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var background: Color {
        switch state {
        case .selected: return accent
        case .correct: return .correct
        case .wrong: return .wrong
        default: return .paperRaised
        }
    }

    private var border: Color {
        switch state {
        case .idle, .dimmed: return .hairline
        default: return .clear
        }
    }

    private var shadow: Color {
        switch state {
        case .correct: return Color.correct.opacity(0.35)
        case .wrong: return Color.wrong.opacity(0.3)
        case .selected: return accent.opacity(0.3)
        default: return Color(hex: 0x3A1FB8).opacity(0.05)
        }
    }

    private var keyFill: Color {
        switch state {
        case .idle, .dimmed: return accent.opacity(0.14)
        default: return .white.opacity(0.25)
        }
    }

    private var keyText: Color {
        switch state {
        case .idle, .dimmed: return accent
        default: return .white
        }
    }

    private var textColor: Color {
        switch state {
        case .selected, .correct, .wrong: return .white
        case .dimmed: return .inkSoft
        case .idle: return .ink
        }
    }

    private var accessibilityText: String {
        switch state {
        case .correct: return "\(text), bonne réponse"
        case .wrong: return "\(text), ta réponse, fausse"
        default: return text
        }
    }
}

private struct AnswerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Vrai / faux

struct TrueFalseAnswerView: View {
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    var body: some View {
        HStack(spacing: 12) {
            choice(true, title: "Vrai", symbol: "hand.thumbsup.fill", tint: .correct)
            choice(false, title: "Faux", symbol: "hand.thumbsdown.fill", tint: .wrong)
        }
        .padding(.horizontal, Space.gutter)
    }

    private func choice(_ value: Bool, title: String, symbol: String, tint: Color) -> some View {
        let chosen = phase.given == .bool(value)
        let correct = phase.revealed?.reveal.answer.value?.boolValue
        let isRight = correct == value
        let revealed = phase.revealed != nil
        let filled = revealed ? (isRight || chosen) : chosen
        let fill: Color = revealed ? (isRight ? .correct : (chosen ? .wrong : .paperRaised)) : (chosen ? tint : .paperRaised)
        return Button {
            Haptics.selection()
            onSubmit(.bool(value))
        } label: {
            VStack(spacing: Space.s) {
                Image(systemName: revealed && (isRight || chosen) ? (isRight ? "checkmark" : "xmark") : symbol)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(filled ? .white : tint)
                Text(title).font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(filled ? .white : Color.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(filled ? Color.clear : tint.opacity(0.35), lineWidth: 2.5))
            .shadow(color: filled ? fill.opacity(0.35) : .clear, radius: 12, y: 6)
            .opacity(revealed && !isRight && !chosen ? 0.45 : 1)
        }
        .buttonStyle(AnswerPressStyle())
        .disabled(!phase.isAnswering)
        .animation(Motion.bounce, value: phase)
        .accessibilityLabel(title)
    }
}

// MARK: - Classement (toucher dans l'ordre)

struct OrderingAnswerView: View {
    let items: [Choice]
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var order: [String] = []

    var body: some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                let rank = order.firstIndex(of: item.id).map { $0 + 1 }
                Button {
                    Haptics.selection()
                    if let index = order.firstIndex(of: item.id) {
                        order.removeSubrange(index...)
                    } else {
                        order.append(item.id)
                    }
                } label: {
                    HStack(spacing: Space.m) {
                        ZStack {
                            Circle().fill(rank == nil ? Color.brand.opacity(0.12) : Color.brand)
                            if let rank {
                                Text("\(rank)").font(.system(.callout, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                                    .transition(.scale)
                            }
                        }
                        .frame(width: 34, height: 34)
                        Text(item.text ?? "").font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let correctRank = correctRank(of: item.id) {
                            Text("\(correctRank)")
                                .font(.system(.callout, design: .rounded).weight(.heavy))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(correctRank == rank ? Color.correct : Color.wrong, in: Circle())
                                .accessibilityLabel("Position correcte : \(correctRank)")
                        }
                    }
                    .padding(14)
                    .frame(minHeight: 62)
                    .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(rank == nil ? Color.hairline : Color.brand.opacity(0.5), lineWidth: 2))
                    .padding(.horizontal, Space.gutter)
                    .animation(Motion.bounce, value: rank)
                }
                .buttonStyle(AnswerPressStyle())
                .disabled(!phase.isAnswering)
            }
            if phase.isAnswering {
                Text(order.count < items.count ? "Touche les éléments dans l'ordre." : "Ordre complet.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.s)
                Button("Valider l'ordre") { onSubmit(.order(order)) }
                    .buttonStyle(.ink)
                    .disabled(order.count < items.count)
                    .padding(.horizontal, Space.gutter)
                    .padding(.top, Space.m)
            }
        }
        .onAppear {
            if case .order(let given)? = phase.given { order = given }
        }
    }

    private func correctRank(of id: String) -> Int? {
        guard let answer = phase.revealed?.reveal.answer.order else { return nil }
        return answer.firstIndex(of: id).map { $0 + 1 }
    }
}

// MARK: - Associations

struct PairsAnswerView: View {
    let left: [Choice]
    let right: [Choice]
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var pairs: [String: String] = [:]
    @State private var pendingLeft: String?

    var body: some View {
        VStack(spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.m) {
                VStack(spacing: Space.s) {
                    ForEach(left) { item in
                        cell(item.text ?? "", badge: badge(forLeft: item.id), highlighted: pendingLeft == item.id) {
                            pendingLeft = pendingLeft == item.id ? nil : item.id
                            pairs[item.id] = nil
                        }
                    }
                }
                VStack(spacing: Space.s) {
                    ForEach(right) { item in
                        cell(item.text ?? "", badge: badge(forRight: item.id), highlighted: false) {
                            guard let pending = pendingLeft else { return }
                            for (key, value) in pairs where value == item.id { pairs[key] = nil }
                            pairs[pending] = item.id
                            pendingLeft = left.first { pairs[$0.id] == nil }?.id
                        }
                    }
                }
            }
            .padding(.horizontal, Space.gutter)

            if let revealed = phase.revealed, let answer = revealed.reveal.answer.pairs, !revealed.isCorrect {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Les bonnes associations").labelCaps()
                    ForEach(left) { item in
                        let match = right.first { $0.id == answer[item.id] }?.text ?? "—"
                        Text("\(item.text ?? "") → \(match)").font(.cfCallout).foregroundStyle(Color.ink)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.gutter)
            }

            if phase.isAnswering {
                Button("Valider") { onSubmit(.pairs(pairs)) }
                    .buttonStyle(.ink)
                    .disabled(pairs.count < left.count)
                    .padding(.horizontal, Space.gutter)
            }
        }
        .onAppear {
            pendingLeft = left.first?.id
            if case .pairs(let given)? = phase.given { pairs = given }
        }
    }

    private func badge(forLeft id: String) -> Int? {
        guard pairs[id] != nil, let index = left.firstIndex(where: { $0.id == id }) else { return nil }
        return index + 1
    }

    private func badge(forRight id: String) -> Int? {
        guard let leftId = pairs.first(where: { $0.value == id })?.key,
              let index = left.firstIndex(where: { $0.id == leftId }) else { return nil }
        return index + 1
    }

    /// Une couleur par paire formée : on voit d'un coup d'œil qui va avec qui.
    private func pairColor(_ index: Int) -> Color {
        [Color.brand, Color(hex: 0xF76707), Color(hex: 0x0CA678), Color(hex: 0xF0588F), Color(hex: 0x1C7ED6), Color(hex: 0x845EF7)][(index - 1) % 6]
    }

    private func cell(_ text: String, badge: Int?, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                if let badge {
                    Text("\(badge)")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(pairColor(badge), in: Circle())
                        .transition(.scale)
                }
                Text(text).font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(highlighted ? Color.sun.opacity(0.6) : Color.paperRaised,
                        in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .strokeBorder(badge.map(pairColor) ?? Color.hairline, lineWidth: 2))
            .animation(Motion.bounce, value: badge)
        }
        .buttonStyle(AnswerPressStyle())
        .disabled(!phase.isAnswering)
    }
}

// MARK: - Carte

struct MapPickAnswerView: View {
    let region: MapRegion
    let options: [Choice]
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: region.lat, longitude: region.lon),
            span: MKCoordinateSpan(latitudeDelta: region.span, longitudeDelta: region.span * 1.2))),
            interactionModes: [.pan, .zoom]) {
            ForEach(options) { option in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: option.lat ?? 0, longitude: option.lon ?? 0)) {
                    pin(option)
                }
            }
        }
        // Imagerie sans libellés : la carte ne donne pas la réponse.
        .mapStyle(.imagery(elevation: .flat))
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .shadow(color: Color(hex: 0x3A1FB8).opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal, Space.gutter)
    }

    private func pin(_ option: Choice) -> some View {
        let chosen = phase.given == .option(option.id)
        let isAnswer = phase.revealed?.reveal.answer.optionId == option.id
        let color: Color = phase.revealed != nil ? (isAnswer ? .correct : (chosen ? .wrong : .inkFixed)) : (chosen ? .sun : .paperFixed)
        return Button {
            Haptics.selection()
            onSubmit(.option(option.id))
        } label: {
            ZStack {
                Circle().fill(color).frame(width: 28, height: 28)
                Circle().stroke(Color.white, lineWidth: 3).frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                if phase.revealed != nil && (isAnswer || chosen) {
                    Image(systemName: isAnswer ? "checkmark" : "xmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Color.paperFixed)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!phase.isAnswering)
        .accessibilityLabel(isAnswer && phase.revealed != nil ? "Bon emplacement" : "Emplacement")
    }
}
