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
    let onSubmit: (GivenAnswer) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                AnswerRow(key: ["A", "B", "C", "D", "E", "F"][min(index, 5)],
                          text: option.text ?? "",
                          state: state(for: option),
                          isDisabled: !phase.isAnswering || removed.contains(option.id)) {
                    onSubmit(.option(option.id))
                }
                .opacity(removed.contains(option.id) ? 0.25 : 1)
            }
        }
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

/// Ligne de réponse éditoriale : lettre-clé en serif, filet dessous. Pressée = aplat encre.
struct AnswerRow: View {
    enum RowState { case idle, selected, correct, wrong, dimmed }

    let key: String
    let text: String
    let state: RowState
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text(key)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(keyColor)
                    .frame(width: 22, alignment: .leading)
                Text(text)
                    .font(.system(.title3))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                verdictMark
            }
            .padding(.vertical, 18)
            .padding(.horizontal, Space.gutter)
            .background(background)
            .overlay(alignment: .bottom) { Hairline() }
        }
        .buttonStyle(AnswerPressStyle())
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var verdictMark: some View {
        switch state {
        case .correct:
            Label("Juste", systemImage: "checkmark").labelStyle(.iconOnly).foregroundStyle(Color.correct).font(.body.weight(.bold))
        case .wrong:
            Label("Raté", systemImage: "xmark").labelStyle(.iconOnly).foregroundStyle(Color.wrong).font(.body.weight(.bold))
        default:
            EmptyView()
        }
    }

    private var background: Color {
        switch state {
        case .selected: return .ink
        case .correct: return Color.correct.opacity(0.1)
        case .wrong: return Color.wrong.opacity(0.08)
        default: return .clear
        }
    }

    private var textColor: Color {
        switch state {
        case .selected: return .paper
        case .dimmed: return .inkSoft
        default: return .ink
        }
    }

    private var keyColor: Color {
        state == .selected ? .paper : .inkSoft
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
            .background(Color.ink.opacity(configuration.isPressed ? 0.08 : 0))
            .animation(Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Vrai / faux

struct TrueFalseAnswerView: View {
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    var body: some View {
        HStack(spacing: Space.s) {
            choice(true, title: "Vrai")
            choice(false, title: "Faux")
        }
        .padding(.horizontal, Space.gutter)
    }

    private func choice(_ value: Bool, title: String) -> some View {
        let chosen = phase.given == .bool(value)
        let correct = phase.revealed?.reveal.answer.value?.boolValue
        let isRight = correct == value
        return Button {
            Haptics.selection()
            onSubmit(.bool(value))
        } label: {
            VStack(spacing: Space.s) {
                Text(title).font(.system(.title, design: .serif).weight(.semibold))
                if phase.revealed != nil && (isRight || chosen) {
                    Image(systemName: isRight ? "checkmark" : "xmark").font(.body.weight(.bold))
                }
            }
            .foregroundStyle(foreground(chosen: chosen, isRight: isRight))
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(fill(chosen: chosen, isRight: isRight), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.ink.opacity(0.9), lineWidth: 1.5))
        }
        .buttonStyle(AnswerPressStyle())
        .disabled(!phase.isAnswering)
        .accessibilityLabel(title)
    }

    private func fill(chosen: Bool, isRight: Bool) -> Color {
        if phase.revealed != nil {
            if isRight { return Color.correct.opacity(0.12) }
            if chosen { return Color.wrong.opacity(0.1) }
            return .clear
        }
        return chosen ? .ink : .clear
    }

    private func foreground(chosen: Bool, isRight: Bool) -> Color {
        if phase.revealed != nil {
            if isRight { return .correct }
            if chosen { return .wrong }
            return .inkSoft
        }
        return chosen ? .paper : .ink
    }
}

// MARK: - Classement (toucher dans l'ordre)

struct OrderingAnswerView: View {
    let items: [Choice]
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var order: [String] = []

    var body: some View {
        VStack(spacing: 0) {
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
                            Circle().stroke(Color.ink, lineWidth: 1.5)
                            if let rank {
                                Circle().fill(Color.ink)
                                Text("\(rank)").font(.system(.callout, design: .serif).weight(.bold)).foregroundStyle(Color.paper)
                            }
                        }
                        .frame(width: 30, height: 30)
                        Text(item.text ?? "").font(.system(.body)).foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let correctRank = correctRank(of: item.id) {
                            Text("\(correctRank)")
                                .font(.system(.callout, design: .serif).weight(.bold))
                                .foregroundStyle(correctRank == rank ? Color.correct : Color.wrong)
                                .accessibilityLabel("Position correcte : \(correctRank)")
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, Space.gutter)
                    .overlay(alignment: .bottom) { Hairline() }
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

    private func cell(_ text: String, badge: Int?, highlighted: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                if let badge {
                    Text("\(badge)")
                        .font(.system(.caption, design: .serif).weight(.bold))
                        .foregroundStyle(Color.paper)
                        .frame(width: 20, height: 20)
                        .background(Color.ink, in: Circle())
                }
                Text(text).font(.system(.callout)).foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(highlighted ? Color.chloro.opacity(0.55) : Color.paperRaised,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.hairline, lineWidth: 1))
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
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(.horizontal, Space.gutter)
    }

    private func pin(_ option: Choice) -> some View {
        let chosen = phase.given == .option(option.id)
        let isAnswer = phase.revealed?.reveal.answer.optionId == option.id
        let color: Color = phase.revealed != nil ? (isAnswer ? .correct : (chosen ? .wrong : .inkFixed)) : (chosen ? .chloro : .paperFixed)
        return Button {
            Haptics.selection()
            onSubmit(.option(option.id))
        } label: {
            ZStack {
                Circle().fill(color).frame(width: 28, height: 28)
                Circle().stroke(Color.inkFixed, lineWidth: 2).frame(width: 28, height: 28)
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
