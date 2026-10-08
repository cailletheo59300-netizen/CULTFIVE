import SwiftUI
import CultFiveCore

// Nouveaux types de réponses (serveur 0038–0039), d'après la maquette validée :
// la marge est annoncée avant de répondre (étiquette 🎯), la zone visée s'affiche en direct,
// et la correction dit « Pile ! », « Juste, dans la marge », « Presque… hors de la marge » ou « Raté ».

// MARK: - Outils communs

enum AnswerValueFormat {
    /// Valeur lisible selon le type : année (« 44 av. J.-C. »), pourcentage, ou nombre avec son unité.
    static func text(_ value: Double, type: QuestionType, unit: String?) -> String {
        switch type {
        case .timeline:
            let year = Int(value.rounded())
            return year < 0 ? "\(-year) av. J.-C." : "\(year)"
        case .gauge:
            return "\(NumberFormat.display(value)) %"
        default:
            let text = NumberFormat.display(value, decimals: value.rounded() == value ? 0 : (value < 10 ? 2 : 1))
            guard let unit, !unit.isEmpty else { return text }
            return "\(text) \(unit)"
        }
    }

    /// Marge en clair, pour l'étiquette annoncée avant de répondre.
    static func margin(of payload: QuestionPayload, type: QuestionType) -> String? {
        if type == .proportion, let rel = payload.relTolerance {
            return "± \(Int((rel * 100).rounded())) %"
        }
        guard let tolerance = payload.tolerance else { return nil }
        if tolerance == 0 { return nil }
        switch type {
        case .timeline: return "± \(NumberFormat.display(tolerance)) ans"
        case .gauge: return "± \(NumberFormat.display(tolerance)) points"
        default:
            return payload.unit.map { "± \(NumberFormat.display(tolerance)) \($0)" } ?? "± \(NumberFormat.display(tolerance))"
        }
    }
}

/// Étiquette 🎯 : marge acceptée (violet) ou nombre exact demandé (orange).
struct MarginChip: View {
    let text: String?

    var body: some View {
        let exact = text == nil
        Text(exact ? "🎯 Nombre exact demandé" : "🎯 Marge acceptée : \(text ?? "")")
            .font(.system(.footnote, design: .rounded).weight(.heavy))
            .foregroundStyle(exact ? Color.orange : Color.brand)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background((exact ? Color.orange : Color.brand).opacity(0.12), in: Capsule())
            .padding(.horizontal, Space.gutter)
            .accessibilityLabel(exact ? "Nombre exact demandé" : "Marge acceptée : \(text ?? "")")
    }
}

/// Bouton « Valider » des nouveaux types, aux couleurs du domaine.
struct ValidateButton: View {
    let domainId: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button("Valider") {
            Haptics.selection()
            action()
        }
        .buttonStyle(.domain(domainId))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .padding(.horizontal, Space.gutter)
    }
}

/// Valeur soumise (après validation) ou valeur en cours.
private func submittedNumber(_ phase: AnswerPhase) -> Double? {
    if case .number(let value)? = phase.given { return NSDecimalNumber(decimal: value).doubleValue }
    return nil
}

/// Zone visée en clair : « Juste si la bonne réponse est entre X et Y ».
struct LiveRange: View {
    let low: String
    let high: String

    var body: some View {
        (Text("Juste si la bonne réponse est entre ") + Text("\(low) et \(high)").foregroundColor(.brand))
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(Color.inkSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.gutter)
    }
}

// MARK: - Compteur

struct CounterAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var value: Int = 0
    @State private var ready = false

    private var payload: QuestionPayload { question.payload }
    private var low: Int { Int(payload.min ?? 0) }
    private var high: Int { Int(payload.max ?? 100) }
    private var tolerance: Int { Int(payload.tolerance ?? 0) }

    var body: some View {
        VStack(spacing: Space.m) {
            MarginChip(text: AnswerValueFormat.margin(of: payload, type: .counter))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Space.m) {
                stepButton("minus", delta: -1)
                VStack(spacing: 2) {
                    Text(NumberFormat.display(Double(shown)))
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                        .contentTransition(.numericText())
                    if let unit = payload.unit { Text(unit).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft) }
                }
                .frame(minWidth: 150)
                .padding(.vertical, Space.s)
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(shown)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: change(1)
                    case .decrement: change(-1)
                    @unknown default: break
                    }
                }
                stepButton("plus", delta: 1)
            }
            HStack(spacing: Space.s) {
                tenButton("−10", delta: -10)
                tenButton("+10", delta: 10)
            }
            if tolerance > 0 {
                LiveRange(low: NumberFormat.display(Double(Swift.max(low, shown - tolerance))),
                          high: NumberFormat.display(Double(shown + tolerance)))
            }
            if phase.isAnswering {
                ValidateButton(domainId: question.domainId) { onSubmit(.number(Decimal(value))) }
            }
        }
        .onAppear {
            guard !ready else { return }
            value = Int(payload.start ?? payload.min ?? 0)
            ready = true
        }
    }

    private var shown: Int {
        if let given = submittedNumber(phase) { return Int(given) }
        return value
    }

    private func change(_ delta: Int) {
        guard phase.isAnswering else { return }
        value = Swift.min(high, Swift.max(low, value + delta))
        Haptics.selection()
    }

    private func stepButton(_ symbol: String, delta: Int) -> some View {
        Button { withAnimation(.snappy) { change(delta) } } label: {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.correct, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        }
        .buttonStyle(AnswerPressStyle())
        .disabled(!phase.isAnswering)
        .accessibilityLabel(delta > 0 ? "Plus un" : "Moins un")
    }

    private func tenButton(_ title: String, delta: Int) -> some View {
        Button(title) { withAnimation(.snappy) { change(delta) } }
            .font(.system(.callout, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.correct)
            .frame(width: 72, height: 40)
            .background(Color.correct.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .disabled(!phase.isAnswering)
            .accessibilityLabel(delta > 0 ? "Plus dix" : "Moins dix")
    }
}

// MARK: - Frise

struct TimelineAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var year: Double = 0
    @State private var ready = false

    private var low: Double { question.payload.min ?? 1900 }
    private var high: Double { question.payload.max ?? 2030 }
    private var tolerance: Double { question.payload.tolerance ?? 0 }

    var body: some View {
        VStack(spacing: Space.m) {
            MarginChip(text: AnswerValueFormat.margin(of: question.payload, type: .timeline))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(AnswerValueFormat.text(shown, type: .timeline, unit: nil))
                .font(.system(size: 56, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.ink)
                .contentTransition(.numericText())
            HorizontalScale(value: Binding(get: { shown }, set: { if phase.isAnswering { year = $0.rounded() } }),
                            range: low...high, band: tolerance, enabled: phase.isAnswering,
                            correct: phase.revealed?.reveal.answer.value?.doubleValue,
                            labels: [low, (low + high) / 2, high].map { AnswerValueFormat.text($0.rounded(), type: .timeline, unit: nil) })
                .frame(height: 84)
                .padding(.horizontal, Space.gutter)
                .accessibilityElement()
                .accessibilityLabel("Frise")
                .accessibilityValue(AnswerValueFormat.text(shown, type: .timeline, unit: nil))
                .accessibilityAdjustableAction { direction in
                    guard phase.isAnswering else { return }
                    switch direction {
                    case .increment: year = Swift.min(high, year + 1)
                    case .decrement: year = Swift.max(low, year - 1)
                    @unknown default: break
                    }
                }
            if tolerance > 0 {
                LiveRange(low: AnswerValueFormat.text(Swift.max(low, shown - tolerance), type: .timeline, unit: nil),
                          high: AnswerValueFormat.text(Swift.min(high, shown + tolerance), type: .timeline, unit: nil))
            }
            if phase.isAnswering {
                ValidateButton(domainId: question.domainId) { onSubmit(.number(Decimal(Int(year)))) }
            }
        }
        .onAppear {
            guard !ready else { return }
            year = ((low + high) / 2).rounded()
            ready = true
        }
    }

    private var shown: Double { submittedNumber(phase) ?? year }
}

/// Frise horizontale à glisser, avec la zone visée (± marge) autour du curseur.
struct HorizontalScale: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let band: Double
    let enabled: Bool
    /// Après la réponse : la bonne valeur, en vert, à côté de la tienne.
    var correct: Double? = nil
    let labels: [String]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = Swift.max(range.upperBound - range.lowerBound, 1)
            let x = CGFloat((value - range.lowerBound) / span) * width
            let bandWidth = CGFloat(2 * band / span) * width
            ZStack(alignment: .topLeading) {
                Capsule().fill(Color.hairline).frame(height: 6).offset(y: 38)
                ForEach(0..<11, id: \.self) { i in
                    Rectangle().fill(Color.inkSoft.opacity(0.35))
                        .frame(width: 2, height: i % 5 == 0 ? 24 : 12)
                        .offset(x: width * CGFloat(i) / 10 - 1, y: i % 5 == 0 ? 29 : 35)
                }
                if band > 0 {
                    Capsule().fill(Color.brand.opacity(0.22))
                        .frame(width: Swift.max(bandWidth, 8), height: 18)
                        .offset(x: x - bandWidth / 2, y: 32)
                }
                ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                    Text(label)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.inkSoft)
                        .fixedSize()
                        .position(x: Swift.min(Swift.max(width * CGFloat(i) / CGFloat(Swift.max(labels.count - 1, 1)), 24), width - 24), y: 72)
                }
                if let correct {
                    let cx = CGFloat((correct - range.lowerBound) / span) * width
                    Capsule().fill(Color.correct).frame(width: 6, height: 44).offset(x: cx - 3, y: 19)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.correct)
                        .background(Circle().fill(.white)).offset(x: cx - 10, y: -6)
                }
                Circle().fill(Color.brand)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                    .frame(width: 38, height: 38)
                    .shadow(color: Color.brand.opacity(0.4), radius: 4, y: 3)
                    .offset(x: x - 19, y: 22)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                guard enabled else { return }
                let ratio = Swift.min(Swift.max(drag.location.x / Swift.max(width, 1), 0), 1)
                value = range.lowerBound + Double(ratio) * span
            })
        }
    }
}

// MARK: - Jauge

struct GaugeAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var percent: Double = 50
    private var tolerance: Double { question.payload.tolerance ?? 0 }

    var body: some View {
        VStack(spacing: Space.m) {
            MarginChip(text: AnswerValueFormat.margin(of: question.payload, type: .gauge))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Space.l) {
                GeometryReader { geo in
                    let h = geo.size.height
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.paperRaised)
                        LinearGradient(colors: [Color(hex: 0x3BC9DB), Color(hex: 0x1C7ED6)], startPoint: .top, endPoint: .bottom)
                            .frame(height: h * shown / 100)
                        if tolerance > 0 {
                            Rectangle().fill(Color.brand.opacity(0.25))
                                .overlay(alignment: .top) { Rectangle().fill(Color.brand).frame(height: 2) }
                                .overlay(alignment: .bottom) { Rectangle().fill(Color.brand).frame(height: 2) }
                                .frame(height: h * CGFloat(Swift.min(100, shown + tolerance) - Swift.max(0, shown - tolerance)) / 100)
                                .offset(y: -h * CGFloat(Swift.max(0, shown - tolerance)) / 100)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.hairline, lineWidth: 3))
                    .overlay(alignment: .bottom) {
                        if let correct = phase.revealed?.reveal.answer.value?.doubleValue {
                            HStack(spacing: 4) {
                                Rectangle().fill(Color.correct).frame(height: 4)
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.correct).background(Circle().fill(.white))
                            }
                            .offset(x: 14, y: -h * CGFloat(correct) / 100 + 2)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                        guard phase.isAnswering else { return }
                        percent = (Swift.min(Swift.max(1 - drag.location.y / Swift.max(h, 1), 0), 1) * 100).rounded()
                    })
                }
                .frame(width: 96, height: 280)
                .accessibilityElement()
                .accessibilityLabel("Jauge")
                .accessibilityValue("\(Int(shown)) pour cent")
                .accessibilityAdjustableAction { direction in
                    guard phase.isAnswering else { return }
                    switch direction {
                    case .increment: percent = Swift.min(100, percent + 1)
                    case .decrement: percent = Swift.max(0, percent - 1)
                    @unknown default: break
                    }
                }
                Text("\(Int(shown)) %")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText())
            }
            if tolerance > 0 {
                LiveRange(low: "\(Int(Swift.max(0, shown - tolerance))) %", high: "\(Int(Swift.min(100, shown + tolerance))) %")
            }
            if phase.isAnswering {
                ValidateButton(domainId: question.domainId) { onSubmit(.number(Decimal(Int(percent)))) }
            }
        }
    }

    private var shown: Double { submittedNumber(phase) ?? percent }
}

// MARK: - Proportions

struct ProportionAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var size: Double = 0
    @State private var ready = false

    private var payload: QuestionPayload { question.payload }
    private var reference: ScaleItem { payload.reference ?? ScaleItem(label: "Référence", size: 1, icon: nil) }
    private var maxSize: Double { payload.max ?? Swift.max(reference.size ?? 1, 1) * 3 }

    var body: some View {
        VStack(spacing: Space.m) {
            MarginChip(text: AnswerValueFormat.margin(of: payload, type: .proportion))
                .frame(maxWidth: .infinity, alignment: .leading)
            GeometryReader { geo in
                let h = geo.size.height - 56
                let scale = h / CGFloat(maxSize)
                let refHeight = CGFloat(reference.size ?? 1) * scale
                let itemHeight = CGFloat(shown) * scale
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [Color(hex: 0xDFF1FF), Color(hex: 0xF3FAFF)], startPoint: .top, endPoint: .bottom)
                    Rectangle().fill(Color(hex: 0x69DB7C)).frame(height: 24)
                    HStack(alignment: .bottom, spacing: Space.m) {
                        bar(label: reference.label, icon: reference.icon, height: refHeight, color: Color.inkSoft.opacity(0.5),
                            value: AnswerValueFormat.text(reference.size ?? 0, type: .proportion, unit: payload.unit))
                        bar(label: payload.item?.label ?? "", icon: payload.item?.icon, height: itemHeight, color: Color.brand,
                            value: AnswerValueFormat.text(shown, type: .proportion, unit: payload.unit))
                        if let correct = phase.revealed?.reveal.answer.value?.doubleValue {
                            bar(label: "Vraie taille", icon: payload.item?.icon, height: CGFloat(correct) * scale, color: Color.correct,
                                value: AnswerValueFormat.text(correct, type: .proportion, unit: payload.unit))
                        }
                    }
                    .padding(.bottom, 24)
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    guard phase.isAnswering else { return }
                    let fromBottom = geo.size.height - 24 - drag.location.y
                    size = Swift.min(Swift.max(Double(fromBottom / Swift.max(scale, 0.0001)), maxSize * 0.02), maxSize)
                })
            }
            .frame(height: 330)
            .padding(.horizontal, Space.gutter)
            .accessibilityElement()
            .accessibilityLabel("Taille de \(payload.item?.label ?? "l'élément")")
            .accessibilityValue(AnswerValueFormat.text(shown, type: .proportion, unit: payload.unit))
            .accessibilityAdjustableAction { direction in
                guard phase.isAnswering else { return }
                let step = maxSize / 100
                switch direction {
                case .increment: size = Swift.min(maxSize, size + step)
                case .decrement: size = Swift.max(step, size - step)
                @unknown default: break
                }
            }
            if let rel = payload.relTolerance, rel > 0 {
                LiveRange(low: AnswerValueFormat.text(shown * (1 - rel), type: .proportion, unit: payload.unit),
                          high: AnswerValueFormat.text(shown * (1 + rel), type: .proportion, unit: payload.unit))
            }
            Text("Glisse vers le haut ou le bas pour étirer \(payload.item?.label ?? "l'élément").")
                .font(.cfFootnote.weight(.bold))
                .foregroundStyle(Color.inkSoft)
                .padding(.horizontal, Space.gutter)
            if phase.isAnswering {
                ValidateButton(domainId: question.domainId) { onSubmit(.number(Decimal(rounded(size)))) }
            }
        }
        .onAppear {
            guard !ready else { return }
            size = (reference.size ?? 1)
            ready = true
        }
    }

    private var shown: Double { submittedNumber(phase) ?? size }

    /// Arrondi lisible selon l'ordre de grandeur (3 chiffres significatifs).
    private func rounded(_ value: Double) -> Double {
        guard value > 0 else { return 0 }
        let magnitude = pow(10, floor(log10(value)) - 2)
        return (value / magnitude).rounded() * magnitude
    }

    private func bar(label: String, icon: String?, height: CGFloat, color: Color, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkFixed)
            Text(ScaleIcon.emoji(icon)).font(.system(size: 30))
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color)
                .frame(width: 56, height: Swift.max(height, 4))
            Text(label).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkFixed)
                .lineLimit(2).multilineTextAlignment(.center).frame(width: 90)
        }
    }
}

/// Pictogrammes des objets à l'échelle (en attendant des silhouettes dessinées).
enum ScaleIcon {
    static func emoji(_ name: String?) -> String {
        switch name {
        case "person": return "🧍"
        case "giraffe": return "🦒"
        case "elephant": return "🐘"
        case "ostrich", "bird": return "🦅"
        case "whale": return "🐋"
        case "bus": return "🚌"
        case "shark": return "🦈"
        case "dinosaur": return "🦖"
        case "car": return "🚗"
        case "tree": return "🌲"
        case "arch": return "🏛️"
        case "tower": return "🗼"
        case "statue": return "🗽"
        case "skyscraper", "building": return "🏢"
        case "pyramid": return "🔺"
        case "mountain": return "🏔️"
        case "waterfall": return "💧"
        case "canyon": return "🏜️"
        case "earth": return "🌍"
        case "moon": return "🌕"
        case "planet": return "🪐"
        case "sun": return "☀️"
        case "rocket": return "🚀"
        case "ship": return "🚢"
        case "plane": return "✈️"
        case "court", "hoop": return "🏀"
        case "goal": return "🥅"
        case "field": return "⚽"
        case "pool": return "🏊"
        case "bear": return "🐻‍❄️"
        case "crocodile": return "🐊"
        case "horse": return "🐎"
        case "dolphin": return "🐬"
        case "cathedral": return "⛪"
        case "clocktower": return "🕰️"
        case "pole": return "🤸"
        case "train": return "🚄"
        default: return "📏"
        }
    }
}

// MARK: - Lettres mélangées et mots dans l'ordre

/// Tuiles à placer dans l'ordre : lettres (mot) ou mots (phrase). Toucher une tuile la place ; toucher une case la retire.
struct TileOrderAnswerView: View {
    enum Mode { case letters, words }

    let question: Question
    let mode: Mode
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var placed: [Choice] = []

    private var tiles: [Choice] { question.payload.tiles ?? [] }
    private var remaining: [Choice] { tiles.filter { tile in !placed.contains { $0.id == tile.id } } }
    private var complete: Bool { placed.count == tiles.count && !tiles.isEmpty }

    var body: some View {
        VStack(spacing: Space.l) {
            Text(mode == .letters ? "\(tiles.count) lettres" : "Touche les mots dans le bon ordre")
                .font(.cfFootnote.weight(.bold))
                .foregroundStyle(Color.inkSoft)
            answerLine
            FlowLayout(spacing: 8) {
                ForEach(tiles) { tile in
                    let used = placed.contains { $0.id == tile.id }
                    Button {
                        guard phase.isAnswering, !used else { return }
                        Haptics.selection()
                        withAnimation(.snappy) { placed.append(tile) }
                    } label: {
                        Text(tile.text ?? "")
                            .font(.system(size: mode == .letters ? 24 : 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color.inkFixed)
                            .frame(minWidth: mode == .letters ? 46 : nil, minHeight: mode == .letters ? 52 : 44)
                            .padding(.horizontal, mode == .letters ? 0 : 12)
                            .background(Color.sun, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(AnswerPressStyle())
                    .opacity(used ? 0 : 1)
                    .disabled(used || !phase.isAnswering)
                    .accessibilityHidden(used)
                }
            }
            .padding(.horizontal, Space.gutter)
            if phase.isAnswering {
                ValidateButton(domainId: question.domainId, enabled: complete) {
                    let texts = placed.compactMap(\.text)
                    onSubmit(mode == .letters ? .text(texts.joined()) : .words(texts))
                }
            }
        }
        .onAppear(perform: restore)
    }

    private var answerLine: some View {
        FlowLayout(spacing: mode == .letters ? 5 : 6) {
            if mode == .letters {
                ForEach(0..<tiles.count, id: \.self) { i in
                    let tile = i < placed.count ? placed[i] : nil
                    Button {
                        guard phase.isAnswering, tile != nil else { return }
                        withAnimation(.snappy) { _ = placed.remove(at: i) }
                    } label: {
                        Text(tile?.text ?? "")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 31, height: 42)
                            .background(tile == nil ? Color.hairline : Color.brand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tile?.text ?? "Case vide")
                }
            } else {
                ForEach(Array(placed.enumerated()), id: \.element.id) { i, tile in
                    Button {
                        guard phase.isAnswering else { return }
                        withAnimation(.snappy) { _ = placed.remove(at: i) }
                    } label: {
                        Text(tile.text ?? "")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(Color.brand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: mode == .letters ? 46 : 96, alignment: .topLeading)
        .padding(mode == .letters ? 0 : 10)
        .background(mode == .letters ? Color.clear : Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .padding(.horizontal, Space.gutter)
    }

    /// Après validation, on remet la réponse donnée (l'état local a pu être réinitialisé).
    private func restore() {
        guard placed.isEmpty else { return }
        var pool = tiles
        let texts: [String]
        switch phase.given {
        case .text(let word)?: texts = word.map(String.init)
        case .words(let words)?: texts = words
        default: return
        }
        for text in texts {
            if let index = pool.firstIndex(where: { $0.text == text }) { placed.append(pool.remove(at: index)) }
        }
    }
}

// MARK: - Choix d'images

struct ImageChoiceAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    private var options: [Choice] { question.payload.options ?? [] }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(options) { option in
                Button {
                    guard phase.isAnswering else { return }
                    Haptics.selection()
                    onSubmit(.option(option.id))
                } label: {
                    tile(option)
                }
                .buttonStyle(AnswerPressStyle())
                .disabled(!phase.isAnswering)
                .accessibilityLabel(label(for: option) ?? "Image \((options.firstIndex(of: option) ?? 0) + 1)")
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private func tile(_ option: Choice) -> some View {
        let state = rowState(option)
        return VStack(spacing: 0) {
            ZStack {
                Color.paperRaised
                if let flag = option.flag {
                    Text(Self.flagEmoji(flag)).font(.system(size: 84))
                } else if let image = option.image, let url = URL(string: image) {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { ProgressView() }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            if let text = label(for: option) {
                Text(text)
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(state == .correct ? Color.correct : Color.ink.opacity(0.75))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(border(state), lineWidth: 3))
        .opacity(state == .dimmed ? 0.55 : 1)
    }

    /// Le nom de chaque image n'apparaît qu'après la réponse.
    private func label(for option: Choice) -> String? {
        phase.revealed?.reveal.answer.labels?[option.id]
    }

    private func rowState(_ option: Choice) -> AnswerRow.RowState {
        let chosen = phase.given == .option(option.id)
        if let result = phase.revealed {
            if option.id == result.reveal.answer.optionId { return .correct }
            return chosen ? .wrong : .dimmed
        }
        if case .submitting = phase, chosen { return .selected }
        return .idle
    }

    private func border(_ state: AnswerRow.RowState) -> Color {
        switch state {
        case .correct: return .correct
        case .wrong: return .wrong
        case .selected: return .brand
        default: return .hairline
        }
    }

    /// Drapeau dessiné par le système à partir du code pays (« fr » → 🇫🇷).
    static func flagEmoji(_ code: String) -> String {
        String(String.UnicodeScalarView(code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }))
    }
}

// MARK: - Correction des types à marge

/// Verdict détaillé : « Pile ! » (+5 graines), « Juste, dans la marge », « Presque… hors de la marge », « Raté »,
/// avec la bonne réponse, la réponse donnée et l'écart.
struct MarginVerdictCard: View {
    let question: Question
    let given: GivenAnswer?
    let answer: CorrectAnswer

    var body: some View {
        if let margin = AnswerEvaluator.margin(given, type: question.type, answer: answer),
           let expected = answer.value?.doubleValue, case .number(let decimal)? = given {
            let value = NSDecimalNumber(decimal: decimal).doubleValue
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: 8) {
                    Text(title(margin)).font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(color(margin))
                    if margin == .exact {
                        Text("+5 graines")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.inkFixed)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.sun, in: Capsule())
                    }
                }
                Text(detail(margin)).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    cell("Bonne réponse", AnswerValueFormat.text(expected, type: question.type, unit: question.payload.unit))
                    cell("Ta réponse", AnswerValueFormat.text(value, type: question.type, unit: question.payload.unit))
                    cell("Écart", gap(abs(value - expected)))
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func title(_ margin: AnswerEvaluator.Margin) -> String {
        switch margin {
        case .exact: return "Pile !"
        case .within: return "Juste, dans la marge"
        case .near: return "Presque… hors de la marge"
        case .missed: return "Raté"
        }
    }

    private func color(_ margin: AnswerEvaluator.Margin) -> Color {
        switch margin {
        case .exact, .within: return .correct
        case .near: return .orange
        case .missed: return .wrong
        }
    }

    private func detail(_ margin: AnswerEvaluator.Margin) -> String {
        let allowed = AnswerValueFormat.margin(of: question.payload, type: question.type)
        switch margin {
        case .exact: return "Exactement la bonne réponse."
        case .within: return "Tu étais dans la marge acceptée (\(allowed ?? ""))."
        case .near, .missed:
            return allowed.map { "Il fallait être à \($0) près." } ?? "Il fallait le nombre exact."
        }
    }

    private func gap(_ value: Double) -> String {
        switch question.type {
        case .timeline: return "\(Int(value.rounded())) an\(value >= 2 ? "s" : "")"
        case .gauge: return "\(NumberFormat.display(value)) pt\(value >= 2 ? "s" : "")"
        default: return AnswerValueFormat.text(value, type: question.type, unit: question.payload.unit)
        }
    }

    private func cell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
            Text(value).font(.system(.callout, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
    }
}
