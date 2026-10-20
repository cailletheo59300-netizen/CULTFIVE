import SwiftUI
import CultFiveCore

/// Frise des siècles (D-087) : à la place des 4 choix d'un QCM de siècles, on fait défiler les siècles du Ier au XXIe ;
/// le siècle au centre est choisi, sa grande période s'affiche dessous. Répondre au hasard ne paie plus (1 chance sur 21).
/// Après la réponse : le bon siècle en vert, le tien en rouge s'il diffère, et l'écart en siècles.
struct CenturyAnswerView: View {
    let question: Question
    let scale: CenturyScale
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var selected: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tileWidth: CGFloat = 66
    private var centuries: [Int] { Array(scale.min...scale.max) }
    private var color: Color { DomainPalette.color(question.domainId) }

    /// Siècle soumis (après validation) ou siècle au centre de la frise.
    private var current: Int {
        if case .century(let value)? = phase.given { return value }
        return selected ?? Self.start(scale)
    }

    /// Bon siècle, une fois la réponse révélée.
    private var correct: Int? {
        guard let reveal = phase.revealed?.reveal else { return nil }
        if let century = reveal.answer.century { return century }
        return question.payload.options?.first { $0.id == reveal.answer.optionId }.flatMap { Century.parse($0.text) }
    }

    /// Départ au milieu de la frise : il ne doit rien laisser deviner.
    private static func start(_ scale: CenturyScale) -> Int { (scale.min + scale.max) / 2 }

    var body: some View {
        VStack(spacing: Space.m) {
            VStack(spacing: 2) {
                Text(Century.label(current))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText(value: Double(current)))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(Century.era(current))
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(color)
                    .contentTransition(.opacity)
            }
            .animation(Motion.adaptive(Motion.standard, reduceMotion: reduceMotion), value: current)
            .accessibilityElement(children: .combine)

            strip
                .frame(height: 112)

            if let correct {
                verdict(correct: correct)
            } else if phase.isAnswering {
                Text("Fais défiler la frise, puis valide")
                    .font(.cfFootnote)
                    .foregroundStyle(Color.inkSoft)
                ValidateButton(domainId: question.domainId) { onSubmit(.century(current)) }
            }
        }
        .onAppear {
            if selected == nil { selected = Self.start(scale) }
        }
    }

    // MARK: Frise

    private var strip: some View {
        GeometryReader { geo in
            let side = max((geo.size.width - Self.tileWidth) / 2, 0)
            ZStack(alignment: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(centuries, id: \.self) { century in
                            tile(century)
                                .frame(width: Self.tileWidth)
                                .id(century)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selected, anchor: .center)
                .contentMargins(.horizontal, side, for: .scrollContent)
                .scrollDisabled(!phase.isAnswering)
                // Bords qui s'effacent : la frise continue au-delà.
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                             .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                                     startPoint: .leading, endPoint: .trailing))
                // Repère du centre.
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(color)
                    .offset(y: -2)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: selected) { _, value in
            if value != nil, phase.isAnswering { Haptics.selection() }
        }
        .accessibilityElement()
        .accessibilityLabel("Frise des siècles")
        .accessibilityValue(Century.label(current))
        .accessibilityAdjustableAction { direction in
            guard phase.isAnswering else { return }
            switch direction {
            case .increment: selected = min(scale.max, current + 1)
            case .decrement: selected = max(scale.min, current - 1)
            @unknown default: break
            }
        }
    }

    private func tile(_ century: Int) -> some View {
        let isCurrent = century == current
        let state = tileState(century)
        return VStack(spacing: 6) {
            Text(Century.roman(century))
                .font(.system(isCurrent ? .title2 : .headline, design: .rounded).weight(.black))
                .foregroundStyle(state.text)
                .frame(width: Self.tileWidth - 10, height: 58)
                .background(state.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(state.border, lineWidth: isCurrent || state.border != .clear ? 2.5 : 0))
                .scaleEffect(isCurrent ? 1.08 : 1)
            // Bande de la grande période, d'une couleur par période.
            Capsule()
                .fill(Self.eraColor(century).opacity(0.75))
                .frame(height: 6)
                .padding(.horizontal, 2)
        }
        .padding(.top, 18)
        .animation(Motion.adaptive(Motion.standard, reduceMotion: reduceMotion), value: isCurrent)
    }

    private func tileState(_ century: Int) -> (fill: Color, text: Color, border: Color) {
        if let correct {
            if century == correct { return (Color.correct, .white, .clear) }
            if century == current { return (Color.wrong, .white, .clear) }
            return (Color.paperRaised, Color.inkSoft.opacity(0.6), .clear)
        }
        if century == current { return (color.opacity(0.16), Color.ink, color) }
        return (Color.paperRaised, Color.inkSoft, .clear)
    }

    private static func eraColor(_ century: Int) -> Color {
        switch Century.era(century) {
        case "Antiquité": return Color(hex: 0xC98A00)
        case "Moyen Âge": return Color(hex: 0x6A4CFF)
        case "Renaissance": return Color(hex: 0x12B76A)
        case "Temps modernes": return Color(hex: 0x2F6BFF)
        default: return Color(hex: 0xE8452C)
        }
    }

    // MARK: Correction

    @ViewBuilder private func verdict(correct: Int) -> some View {
        let gap = abs(current - correct)
        let text = gap == 0 ? "Pile le bon siècle !"
            : gap == 1 ? "À 1 siècle près… c'était le \(Century.label(correct))"
            : "C'était le \(Century.label(correct)), à \(gap) siècles"
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(gap == 0 ? Color.correct : Color.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.gutter)
            .onAppear {
                // La frise vient se placer sur le bon siècle.
                withAnimation(Motion.adaptive(Motion.standard, reduceMotion: reduceMotion)) { selected = correct }
            }
    }
}
