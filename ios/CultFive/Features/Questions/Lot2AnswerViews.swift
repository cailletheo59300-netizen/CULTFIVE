import SwiftUI
import MapKit
import CultFiveCore

// Nouveaux types, lot 2 (serveur 0040–0041) : le compte est bon, mot mystère, épingle sur la carte,
// tri express et pyramide des âges. À la correction, on voit sa réponse et la bonne réponse au même endroit.

// MARK: - Le compte est bon

struct NumberTargetAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    private struct Tile: Identifiable, Equatable { let id: Int; let value: Int }

    @State private var tiles: [Tile] = []
    @State private var history: [[Tile]] = []
    @State private var steps: [TargetStep] = []
    @State private var selected: Int?
    @State private var op: String?
    @State private var message = "Touche un nombre, une opération, puis un autre nombre."
    @State private var nextId = 100

    private var target: Int { question.payload.target ?? 0 }
    private var reached: Bool { tiles.contains { $0.value == target } }

    var body: some View {
        VStack(spacing: Space.m) {
            VStack(spacing: 0) {
                Text("Cible").labelCaps()
                Text("\(target)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(reached ? Color.correct : Color.brand)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            if phase.isAnswering {
                FlowLayout(spacing: 8) {
                    ForEach(tiles) { tile in
                        Button { pick(tile) } label: {
                            Text("\(tile.value)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(selected == tile.id ? Color.white : Color.inkFixed)
                                .frame(minWidth: 58, minHeight: 56)
                                .padding(.horizontal, 6)
                                .background(selected == tile.id ? Color.brand : (tile.value == target ? Color.correct : Color.sun),
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(AnswerPressStyle())
                        .accessibilityLabel("\(tile.value)")
                    }
                }
                .padding(.horizontal, Space.gutter)
                HStack(spacing: 8) {
                    ForEach(["+", "-", "*", "/"], id: \.self) { symbol in
                        Button { if selected != nil { op = symbol; Haptics.selection() } } label: {
                            Text(TargetStep(a: 0, op: symbol, b: 0).symbol)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(op == symbol ? Color.white : Color.ink)
                                .frame(width: 56, height: 46)
                                .background(op == symbol ? Color.ink : Color.paperRaised,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(["+": "plus", "-": "moins", "*": "fois", "/": "divisé par"][symbol] ?? symbol)
                    }
                }
                Text(message).font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                    .padding(.horizontal, Space.gutter)
                HStack(spacing: Space.s) {
                    Button { undo() } label: { Label("Annuler", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(.textLink)
                        .disabled(history.isEmpty)
                }
                ValidateButton(domainId: question.domainId) { onSubmit(.steps(steps)) }
            } else {
                stepsSummary
            }
        }
        .onAppear(perform: reset)
    }

    /// Après la réponse : tes opérations, puis une solution.
    private var stepsSummary: some View {
        let mine: [TargetStep] = { if case .steps(let s)? = phase.given { return s }; return [] }()
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("Tes calculs").labelCaps()
            if mine.isEmpty {
                Text("Aucun calcul").font(.cfReading).foregroundStyle(Color.inkSoft)
            } else {
                ForEach(Array(mine.enumerated()), id: \.offset) { _, step in
                    Text("\(step.a) \(step.symbol) \(step.b) = \(step.result.map { "\($0)" } ?? "?")")
                        .font(.system(.body, design: .rounded).weight(.heavy))
                        .foregroundStyle(step.result == target ? Color.correct : Color.ink)
                }
            }
            if let solution = phase.revealed?.reveal.answer.solution {
                Text("Une solution").labelCaps().padding(.top, 4)
                Text(solution.joined(separator: "  ·  "))
                    .font(.system(.body, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.correct)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard()
        .padding(.horizontal, Space.gutter)
    }

    private func reset() {
        guard tiles.isEmpty else { return }
        tiles = (question.payload.numbers ?? []).enumerated().map { Tile(id: $0.offset, value: $0.element) }
    }

    private func pick(_ tile: Tile) {
        Haptics.selection()
        guard let first = selected, let op, first != tile.id, let a = tiles.first(where: { $0.id == first }) else {
            selected = selected == tile.id ? nil : tile.id
            op = nil
            return
        }
        let step = TargetStep(a: a.value, op: op, b: tile.value)
        guard let result = step.result else {
            message = op == "/" ? "Division impossible ici : on reste en nombres entiers." : "Pas de nombre négatif."
            return
        }
        history.append(tiles)
        steps.append(step)
        withAnimation(.snappy) {
            tiles.removeAll { $0.id == first || $0.id == tile.id }
            tiles.append(Tile(id: nextId, value: result))
        }
        nextId += 1
        message = "\(step.a) \(step.symbol) \(step.b) = \(result)"
        selected = nil
        self.op = nil
        if result == target { Haptics.success() }
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        withAnimation(.snappy) { tiles = previous }
        steps.removeLast()
        selected = nil
        op = nil
        message = "Dernière opération annulée."
    }
}

// MARK: - Mot mystère

struct RiddleAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var shown = 1

    private var clues: [String] { question.payload.clues ?? [] }
    private var visible: Int { phase.isAnswering ? shown : clues.count }

    var body: some View {
        VStack(spacing: Space.m) {
            if phase.isAnswering {
                Text(bonusText)
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color(hex: 0x8A6400))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.sun.opacity(0.25), in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.gutter)
            }
            VStack(spacing: 8) {
                ForEach(Array(clues.enumerated()), id: \.offset) { index, clue in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(.footnote, design: .rounded).weight(.black))
                            .foregroundStyle(index < visible ? Color.white : Color.inkSoft)
                            .frame(width: 24, height: 24)
                            .background(index < visible ? Color.brand : Color.hairline, in: Circle())
                        Text(index < visible ? clue : "Indice \(index + 1) caché")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(index < visible ? Color.ink : Color.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(index < visible ? Color.paperRaised : Color.clear,
                                in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                        .strokeBorder(index < visible ? Color.clear : Color.hairline, lineWidth: 2))
                }
            }
            .padding(.horizontal, Space.gutter)
            if phase.isAnswering && shown < clues.count {
                Button("Indice suivant") { withAnimation(.snappy) { shown += 1 } }
                    .buttonStyle(.textLink)
            }
            VStack(spacing: 10) {
                ForEach(Array((question.payload.options ?? []).enumerated()), id: \.element.id) { index, option in
                    AnswerRow(key: ["A", "B", "C", "D"][min(index, 3)], text: option.text ?? "", state: state(for: option),
                              accent: DomainPalette.color(question.domainId), isDisabled: !phase.isAnswering) {
                        onSubmit(.riddle(option.id, clues: shown))
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
        }
    }

    private var bonusText: String {
        switch shown {
        case 1: return "💎 Trouve au 1er indice : +3 graines"
        case 2: return "💎 Trouve au 2e indice : +1 graine"
        default: return "Dernier indice : pas de bonus"
        }
    }

    private func state(for option: Choice) -> AnswerRow.RowState {
        let chosen: Bool = { if case .riddle(let id, _)? = phase.given { return id == option.id }; return false }()
        if let result = phase.revealed {
            if option.id == result.reveal.answer.optionId { return .correct }
            return chosen ? .wrong : .dimmed
        }
        if case .submitting = phase, chosen { return .selected }
        return .idle
    }
}

// MARK: - Épingle sur la carte

struct MapPinAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var pin: CLLocationCoordinate2D?

    private var region: MapRegion? { question.payload.region }
    private var tolerance: Double { question.payload.toleranceKm ?? 50 }

    var body: some View {
        VStack(spacing: Space.m) {
            MarginChip(text: "\(Int(tolerance)) km")
                .frame(maxWidth: .infinity, alignment: .leading)
            MapReader { proxy in
                Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: region?.lat ?? 46.6, longitude: region?.lon ?? 2.4),
                        span: MKCoordinateSpan(latitudeDelta: region?.span ?? 11, longitudeDelta: (region?.span ?? 11) * 1.2))),
                    interactionModes: [.pan, .zoom]) {
                    if let shownPin {
                        MapCircle(center: shownPin, radius: tolerance * 1000)
                            .foregroundStyle(Color.brand.opacity(0.18))
                            .stroke(Color.brand, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        Annotation("", coordinate: shownPin, anchor: .bottom) {
                            Image(systemName: "mappin")
                                .font(.system(size: 34, weight: .black))
                                .foregroundStyle(phase.revealed == nil ? Color.sun : (phase.revealed?.isCorrect == true ? Color.correct : Color.wrong))
                                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                        }
                    }
                    if let answer = answerPoint {
                        if let shownPin {
                            MapPolyline(coordinates: [shownPin, answer])
                                .stroke(Color.wrong, style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
                        }
                        Annotation(phase.revealed?.reveal.answer.place ?? "", coordinate: answer) {
                            Circle().fill(Color.correct).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(.white, lineWidth: 3))
                        }
                    }
                }
                // Imagerie sans libellés : la carte ne donne pas la réponse.
                .mapStyle(.imagery(elevation: .flat))
                .onTapGesture { point in
                    guard phase.isAnswering, let coordinate = proxy.convert(point, from: .local) else { return }
                    Haptics.selection()
                    pin = coordinate
                }
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .padding(.horizontal, Space.gutter)
            .accessibilityLabel("Carte : touche pour placer l'épingle")
            if phase.isAnswering {
                Text(pin == nil ? "Touche la carte pour placer l'épingle. Tu peux zoomer et te déplacer." : "Touche ailleurs pour la déplacer.")
                    .font(.cfFootnote.weight(.bold))
                    .foregroundStyle(Color.inkSoft)
                    .padding(.horizontal, Space.gutter)
                ValidateButton(domainId: question.domainId, enabled: pin != nil) {
                    if let pin { onSubmit(.pin(lat: pin.latitude, lon: pin.longitude)) }
                }
            }
        }
    }

    private var shownPin: CLLocationCoordinate2D? {
        if case .pin(let lat, let lon)? = phase.given { return CLLocationCoordinate2D(latitude: lat, longitude: lon) }
        return pin
    }

    private var answerPoint: CLLocationCoordinate2D? {
        guard let answer = phase.revealed?.reveal.answer, let lat = answer.lat, let lon = answer.lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Tri express et pyramide des âges

/// Étiquettes à faire glisser dans des paniers (tri express) ou des époques (pyramide des âges).
/// Toucher une étiquette posée la renvoie en haut. À la correction : vert si bien rangée, rouge sinon, avec la bonne case.
struct SortAnswerView: View {
    let question: Question
    let phase: AnswerPhase
    let onSubmit: (GivenAnswer) -> Void

    @State private var placement: [String: String] = [:]
    @State private var frames: [String: CGRect] = [:]
    @State private var dragging: String?
    @State private var dragOffset: CGSize = .zero
    @State private var hovered: String?

    private var items: [Choice] { question.payload.items ?? [] }
    private var groups: [SortGroup] { question.payload.groups ?? [] }
    private var isTimeline: Bool { question.payload.layout == "timeline" }
    private var shownPlacement: [String: String] {
        if case .groups(let map)? = phase.given { return map }
        return placement
    }
    private var complete: Bool { items.allSatisfy { placement[$0.id] != nil } }
    private static let eraColors: [Color] = [Color(hex: 0xF08C00), Color(hex: 0x2F9E44), Color(hex: 0x1C7ED6), Color(hex: 0xAE3EC9), Color(hex: 0xE64980)]

    var body: some View {
        VStack(spacing: Space.m) {
            if phase.isAnswering {
                FlowLayout(spacing: 8) {
                    ForEach(items.filter { placement[$0.id] == nil }) { item in label(item) }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, Space.gutter)
                .overlay {
                    if items.allSatisfy({ placement[$0.id] != nil }) {
                        Text("Tout est rangé : vérifie, puis valide.").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                    }
                }
            }
            if isTimeline {
                VStack(spacing: 6) { ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in zone(group, index: index) } }
                    .padding(.horizontal, Space.gutter)
            } else {
                HStack(alignment: .top, spacing: 10) { ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in zone(group, index: index) } }
                    .padding(.horizontal, Space.gutter)
            }
            if phase.isAnswering {
                ValidateButton(domainId: question.domainId, enabled: complete) { onSubmit(.groups(placement)) }
            }
        }
        .coordinateSpace(name: "sort")
        .onPreferenceChange(SortFrameKey.self) { frames = $0 }
    }

    private func zone(_ group: SortGroup, index: Int) -> some View {
        let color = isTimeline ? Self.eraColors[index % Self.eraColors.count] : Color.brand
        let placed = items.filter { shownPlacement[$0.id] == group.id }
        let layout = isTimeline ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 6))
        return layout {
            VStack(alignment: isTimeline ? .leading : .center, spacing: 0) {
                Text(group.label).font(.system(.subheadline, design: .rounded).weight(.black)).foregroundStyle(color)
                if let sub = group.sub { Text(sub).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft) }
            }
            .frame(minWidth: isTimeline ? 104 : nil, alignment: .leading)
            FlowLayout(spacing: 6) {
                ForEach(placed) { item in label(item) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: isTimeline ? 58 : 150, alignment: isTimeline ? .leading : .top)
        .background(hovered == group.id ? color.opacity(0.10) : Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        .overlay(alignment: .leading) {
            if isTimeline { RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 6) }
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
            .strokeBorder(hovered == group.id ? color : Color.hairline, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
        .background(GeometryReader { proxy in
            Color.clear.preference(key: SortFrameKey.self, value: [group.id: proxy.frame(in: .named("sort"))])
        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(group.label)
    }

    private func label(_ item: Choice) -> some View {
        let verdict = verdict(for: item)
        return VStack(spacing: 2) {
            Text(item.text ?? "")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(verdict == nil ? Color.inkFixed : Color.white)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(verdict.map { $0 ? Color.correct : Color.wrong } ?? Color.sun,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if verdict == false, let right = correctGroup(for: item) {
                Text("→ \(right.label)").font(.system(.caption2, design: .rounded).weight(.heavy)).foregroundStyle(Color.correct)
            }
        }
        .offset(dragging == item.id ? dragOffset : .zero)
        .zIndex(dragging == item.id ? 10 : 0)
        .scaleEffect(dragging == item.id ? 1.08 : 1)
        .highPriorityGesture(phase.isAnswering ? drag(item) : nil)
        .onTapGesture {
            guard phase.isAnswering, placement[item.id] != nil else { return }
            withAnimation(.snappy) { placement[item.id] = nil }
        }
        .accessibilityLabel(item.text ?? "")
        .accessibilityActions {
            if phase.isAnswering {
                ForEach(groups) { group in
                    Button("Ranger dans « \(group.label) »") { placement[item.id] = group.id }
                }
            }
        }
    }

    private func drag(_ item: Choice) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("sort"))
            .onChanged { value in
                dragging = item.id
                dragOffset = value.translation
                hovered = frames.first { $0.value.contains(value.location) }?.key
            }
            .onEnded { value in
                if let target = frames.first(where: { $0.value.contains(value.location) })?.key {
                    Haptics.selection()
                    withAnimation(.snappy) { placement[item.id] = target }
                }
                dragging = nil
                dragOffset = .zero
                hovered = nil
            }
    }

    /// Après la réponse : juste ou non pour cette étiquette (nil pendant le jeu).
    private func verdict(for item: Choice) -> Bool? {
        guard let answer = phase.revealed?.reveal.answer.groups else { return nil }
        return shownPlacement[item.id] == answer[item.id]
    }

    private func correctGroup(for item: Choice) -> SortGroup? {
        guard let id = phase.revealed?.reveal.answer.groups?[item.id] else { return nil }
        return groups.first { $0.id == id }
    }
}

private struct SortFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Correction de l'épingle

/// Distance entre l'épingle et le bon point : « Pile ! », « Juste, dans la marge », « Presque… », « Raté ».
struct DistanceVerdictCard: View {
    let question: Question
    let given: GivenAnswer?
    let answer: CorrectAnswer

    var body: some View {
        if case .pin(let lat, let lon)? = given,
           let distance = AnswerEvaluator.distanceKm(lat: lat, lon: lon, answer: answer),
           let margin = AnswerEvaluator.margin(given, type: .mapPin, answer: answer) {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: 8) {
                    Text(title(margin)).font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(margin == .near ? Color.orange : (margin == .missed ? Color.wrong : Color.correct))
                    if margin == .exact {
                        Text("+5 graines").font(.system(.caption, design: .rounded).weight(.heavy)).foregroundStyle(Color.inkFixed)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Color.sun, in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    cell("Bonne réponse", answer.place ?? "Le point vert")
                    cell("Ton épingle", "à \(NumberFormat.display(distance.rounded())) km")
                    cell("Marge", "\(NumberFormat.display(answer.toleranceKm ?? 0)) km")
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

    private func cell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(.caption2, design: .rounded).weight(.bold)).foregroundStyle(Color.inkSoft)
            Text(value).font(.system(.callout, design: .rounded).weight(.black)).foregroundStyle(Color.ink)
                .minimumScaleFactor(0.6).lineLimit(2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
    }
}
