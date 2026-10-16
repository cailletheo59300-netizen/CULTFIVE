import SwiftUI

/// Ouverture d'une pochette en plein écran : on déchire le haut d'un glissé, les 5 cartes attendent face cachée,
/// chaque toucher en retourne une (la face n'apparaît qu'une fois la carte sur la tranche), effets selon la rareté,
/// puis le récapitulatif. Les cartes sont déjà tirées et rangées : l'écran ne fait que les montrer.
struct PackOpeningView: View {
    let opening: PackOpening
    let back: String
    var onDone: () -> Void

    private enum Phase: Equatable { case pack, cards, summary }

    @State private var phase: Phase = .pack
    @State private var tear: CGFloat = 0
    @State private var torn = false
    @State private var index = 0
    @State private var angle: Double = 0
    @State private var faceUp = false
    @State private var flipping = false
    @State private var bob = false
    @State private var flash = 0.0
    @State private var leaving = false
    /// Carte suivie au doigt : on peut glisser (frotter) la carte au lieu de toucher.
    @State private var drag: CGSize = .zero
    /// La légendaire grossit en se retournant, puis se pose.
    @State private var pop = false
    /// Cartes du récapitulatif déjà apparues.
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pull: Pull? { opening.pulls.indices.contains(index) ? opening.pulls[index] : nil }
    private var packImage: String { opening.coffret ? "" : (opening.gold ? "gold" : opening.series.id) }

    var body: some View {
        ZStack {
            background
            VStack(spacing: Space.l) {
                header
                Spacer(minLength: 0)
                switch phase {
                case .pack: packStage
                case .cards: cardStage
                case .summary: summary
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(Space.gutter)
            if phase == .cards, faceUp, let pull, pull.card.rarity == .legend, !reduceMotion {
                Confetti().ignoresSafeArea().allowsHitTesting(false)
            }
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if opening.coffret { torn = true; phase = .cards }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    private var background: some View {
        let glow: Color = {
            guard phase == .cards, faceUp, let pull else { return Color(hex: 0xFFECAA) }
            return pull.card.rarity == .common ? Color.white : pull.card.rarity.color
        }()
        return RadialGradient(colors: opening.gold ? [Color(hex: 0xC89A3A), Color(hex: 0x7A4A08), Color(hex: 0x2A1804)]
                                                   : [Color(hex: 0x8A6BFF), Color(hex: 0x6A4CFF), Color(hex: 0x3A1FB8)],
                              center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 640)
            .overlay {
                RadialGradient(colors: [glow.opacity(0.55), .clear], center: UnitPoint(x: 0.5, y: 0.45), startRadius: 10, endRadius: 280)
                    .opacity(phase == .pack ? 0.4 : 1)
                    .animation(Motion.standard, value: faceUp)
            }
            .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: Space.s) {
            Text(opening.coffret ? "Coffret \(opening.series.label)" : (opening.gold ? "Pochette dorée" : "Pochette \(opening.series.label)"))
                .font(.cfTitle3).foregroundStyle(.white)
            if phase == .cards {
                // Avancement : de simples pastilles, pas de miniatures des cartes.
                HStack(spacing: 6) {
                    ForEach(opening.pulls.indices, id: \.self) { i in
                        Capsule()
                            .fill(i < index || (i == index && faceUp) ? Color.sun : .white.opacity(0.3))
                            .frame(width: i == index ? 22 : 10, height: 8)
                    }
                }
                .animation(Motion.bounce, value: index)
                .accessibilityElement()
                .accessibilityLabel("Carte \(index + 1) sur \(opening.pulls.count)")
            }
        }
    }

    // MARK: - La pochette

    private var packStage: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.72, 280)
            let height = width * 1.5
            ZStack {
                // Le corps de la pochette.
                packArt
                    .frame(width: width, height: height)
                    .mask(alignment: .bottom) { Rectangle().frame(height: height * 0.885) }
                    .offset(y: torn ? height * 0.9 : 0)
                    .opacity(torn ? 0 : 1)
                // La bande du haut, qui s'envole quand on déchire.
                packArt
                    .frame(width: width, height: height)
                    .mask(alignment: .top) { Rectangle().frame(height: height * 0.115) }
                    .rotationEffect(.degrees(torn ? -18 : 0), anchor: .bottomTrailing)
                    .offset(x: torn ? width * 0.4 : 0, y: torn ? -height * 0.6 : 0)
                    .opacity(torn ? 0 : 1)
                // Le trait de la déchirure, qui suit le doigt.
                Capsule()
                    .fill(.white)
                    .frame(width: width * 0.92 * tear, height: 3)
                    .shadow(color: .white, radius: 6)
                    .frame(width: width * 0.92, alignment: .leading)
                    .offset(y: -height * 0.385)
                    .opacity(torn ? 0 : 1)
                if tear == 0 && !reduceMotion {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                        .offset(x: bob ? width * 0.3 : -width * 0.3, y: -height * 0.34)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: height)
            .offset(y: bob && !torn ? -6 : 0)
            .rotation3DEffect(.degrees(bob && !torn ? 4 : -4), axis: (x: 0, y: 1, z: 0))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        guard !torn else { return }
                        let progress = max(0, min(1, abs(value.translation.width) / (width * 0.8)))
                        if progress > tear + 0.15 { Haptics.selection() }
                        tear = max(tear, progress)
                        if tear >= 1 { tearOpen() }
                    }
                    .onEnded { _ in
                        if tear > 0.6 { tearOpen() } else if !torn { withAnimation(Motion.standard) { tear = 0 } }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Pochette fermée")
            .accessibilityHint("Glisse le long du haut pour la déchirer")
            .accessibilityAction(named: "Ouvrir") { tearOpen() }
        }
    }

    @ViewBuilder private var packArt: some View {
        AlbumImage(kind: .packs, name: packImage)
    }

    private func tearOpen() {
        guard !torn else { return }
        Haptics.success()
        withAnimation(.easeIn(duration: 0.45)) {
            tear = 1
            torn = true
        }
        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.12)) { flash = 0.5 }
            withAnimation(.easeOut(duration: 0.5).delay(0.12)) { flash = 0 }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(Motion.moment) { phase = .cards }
        }
    }

    // MARK: - Les cartes

    private var cardStage: some View {
        VStack(spacing: Space.l) {
            ZStack {
                // La pile qui reste, derrière.
                ForEach(Array(opening.pulls.indices.reversed()), id: \.self) { i in
                    if i > index {
                        AlbumCardBack(kind: back)
                            .frame(width: 240)
                            .rotationEffect(.degrees(Double(i - index) * 3))
                            .offset(x: CGFloat(i - index) * 6, y: CGFloat(i - index) * 4)
                    }
                }
                if let pull {
                    Group {
                        if faceUp {
                            AlbumCardView(card: pull.card, state: displayState(pull))
                        } else {
                            AlbumCardBack(kind: back)
                                .modifier(Tension(rarity: pull.card.rarity, active: !reduceMotion))
                        }
                    }
                    .frame(width: 240)
                    .shadow(color: faceUp ? pull.card.rarity.color.opacity(pull.card.rarity == .common ? 0.2 : 0.8) : .black.opacity(0.3),
                            radius: faceUp && pull.card.rarity >= .epic ? 30 : 12)
                    .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .scaleEffect(pop ? 1.22 : (faceUp && pull.card.rarity == .legend ? 1.04 : 1))
                    .offset(x: leaving ? -420 : drag.width, y: leaving ? 0 : drag.height * 0.25)
                    .rotationEffect(.degrees(leaving ? -12 : Double(drag.width) / 22))
                    .id(index)
                }
            }
            .background {
                // Derrière la carte, sans changer la mise en page.
                if let pull, faceUp, !reduceMotion {
                    RevealEffects(rarity: pull.card.rarity)
                        .id(index)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 340)
            .contentShape(Rectangle())
            .onTapGesture { advance() }
            // Glisser la carte : elle suit le doigt ; lâchée assez loin, elle se retourne ou laisse place à la suivante.
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard !flipping else { return }
                        drag = value.translation
                    }
                    .onEnded { value in
                        let far = abs(value.translation.width) > 70 || abs(value.predictedEndTranslation.width) > 180
                        withAnimation(Motion.bounce) { drag = .zero }
                        if far {
                            Haptics.selection()
                            advance()
                        }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(faceUp ? (pull.map { "\($0.card.name), \($0.card.rarity.label)" } ?? "") : "Carte face cachée")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { advance() }

            Group {
                if faceUp, let pull {
                    VStack(spacing: 6) {
                        Text(pull.card.rarity.label.uppercased())
                            .font(.system(.footnote, design: .rounded).weight(.black)).tracking(2)
                            .foregroundStyle(pull.card.rarity == .common ? .white.opacity(0.7) : pull.card.rarity.color)
                        OutcomeTag(outcome: pull.outcome)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Touche ou glisse la carte pour la retourner").font(.cfCallout).foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(height: 60)
        }
    }

    private func displayState(_ pull: Pull) -> OwnedCard {
        switch pull.outcome {
        case .new: return OwnedCard(shiny: false)
        case .shiny, .neurones, .nothing: return OwnedCard(shiny: true)
        }
    }

    private func advance() {
        guard phase == .cards, !flipping, let pull else { return }
        if !faceUp {
            flipping = true
            let rarity = pull.card.rarity
            // La légendaire se retourne plus lentement.
            let half: Double = reduceMotion ? 0.01 : (rarity == .legend ? 0.34 : rarity == .epic ? 0.22 : 0.16)
            withAnimation(.easeIn(duration: half)) { angle = 90 }
            Task {
                try? await Task.sleep(for: .milliseconds(Int(half * 1000) + 10))
                // La face n'est posée qu'une fois la carte sur la tranche : on ne la voit jamais avant.
                faceUp = true
                angle = -90
                withAnimation(rarity >= .epic ? Motion.bounce : Motion.moment) { angle = 0 }
                switch rarity {
                case .legend:
                    Haptics.success()
                    if !reduceMotion {
                        pop = true
                        withAnimation(.easeOut(duration: 0.1)) { flash = 0.7 }
                        withAnimation(.easeOut(duration: 0.7).delay(0.1)) { flash = 0 }
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.15)) { pop = false }
                        try? await Task.sleep(for: .milliseconds(220))
                        Haptics.success()
                    }
                case .epic:
                    Haptics.success()
                    if !reduceMotion {
                        withAnimation(.easeOut(duration: 0.08)) { flash = 0.25 }
                        withAnimation(.easeOut(duration: 0.4).delay(0.08)) { flash = 0 }
                    }
                case .rare: Haptics.soft()
                case .common: Haptics.selection()
                }
                flipping = false
            }
        } else if index < opening.pulls.count - 1 {
            flipping = true
            withAnimation(.easeIn(duration: 0.22)) { leaving = true }
            Task {
                try? await Task.sleep(for: .milliseconds(230))
                leaving = false
                faceUp = false
                angle = 0
                index += 1
                flipping = false
            }
        } else {
            withAnimation(Motion.moment) { phase = .summary }
        }
    }

    // MARK: - Récapitulatif

    private var summary: some View {
        VStack(spacing: Space.m) {
            Text("Dans ta pochette").font(.cfHeadline).foregroundStyle(.white)
            // Rangées centrées : 3 en haut, 2 en bas (un coffret de 3 tient sur une ligne).
            VStack(spacing: 14) {
                summaryRow(Array(opening.pulls.prefix(3)), offset: 0)
                if opening.pulls.count > 3 {
                    summaryRow(Array(opening.pulls.dropFirst(3)), offset: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .task {
                shown = reduceMotion ? opening.pulls.count : 0
                while shown < opening.pulls.count {
                    try? await Task.sleep(for: .milliseconds(120))
                    withAnimation(Motion.bounce) { shown += 1 }
                }
            }
            let gained = opening.pulls.reduce(0) { total, pull in
                if case .neurones(let value) = pull.outcome { return total + value }
                return total
            }
            if gained > 0 {
                HStack(spacing: 4) {
                    Text("Doublons :")
                    NeuronesAmount(amount: gained, color: .white)
                }
                .font(.cfCallout).foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private func summaryRow(_ pulls: [Pull], offset: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(pulls.enumerated()), id: \.element.id) { i, pull in
                VStack(spacing: 6) {
                    AlbumCardView(card: pull.card, state: displayState(pull), outlined: true)
                        .shadow(color: pull.card.rarity >= .epic ? pull.card.rarity.color.opacity(0.7) : .black.opacity(0.3),
                                radius: pull.card.rarity >= .epic ? 12 : 6, y: 3)
                    OutcomeTag(outcome: pull.outcome, compact: true)
                }
                .frame(width: 98)
                .scaleEffect(offset + i < shown ? 1 : 0.6)
                .opacity(offset + i < shown ? 1 : 0)
            }
        }
    }

    private var footer: some View {
        Group {
            switch phase {
            case .pack:
                Button("Ouvrir") { tearOpen() }.buttonStyle(.inverted)
            case .cards:
                Button(faceUp ? (index < opening.pulls.count - 1 ? "Carte suivante" : "Voir le récapitulatif") : "Retourner") { advance() }
                    .buttonStyle(.inverted)
            case .summary:
                Button("Ranger dans l'album") { onDone() }.buttonStyle(.sun)
            }
        }
    }
}

// MARK: - Effets de rareté

/// Avant le retournement : le dos d'une épique ou d'une légendaire tremble et s'entoure d'une lueur de sa couleur.
private struct Tension: ViewModifier {
    let rarity: CardRarity
    let active: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        let strong = active && rarity >= .epic
        content
            .shadow(color: strong ? rarity.color.opacity(on ? 0.9 : 0.35) : .clear, radius: on ? 26 : 12)
            .rotationEffect(.degrees(strong ? (on ? 1.4 : -1.4) : 0))
            .onAppear {
                guard strong else { return }
                let speed = rarity == .legend ? 0.09 : 0.14
                withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

/// Derrière la carte qui vient d'être retournée : anneau (rare), rayons et étincelles (épique), rayons dorés et
/// pluie d'étoiles (légendaire). Rien pour une commune.
private struct RevealEffects: View {
    let rarity: CardRarity
    @State private var go = false

    private var color: Color { rarity == .legend ? Color(hex: 0xFFD23F) : rarity.color }

    var body: some View {
        ZStack {
            if rarity >= .epic {
                RotatingRays(color: color, count: rarity == .legend ? 18 : 12)
                    .frame(width: 520, height: 520)
                    .scaleEffect(go ? 1 : 0.3)
                    .opacity(go ? 1 : 0)
            }
            if rarity >= .rare {
                Circle()
                    .stroke(color, lineWidth: rarity == .rare ? 6 : 9)
                    .frame(width: 240, height: 240)
                    .scaleEffect(go ? 1.9 : 0.5)
                    .opacity(go ? 0 : 0.95)
            }
            if rarity >= .epic {
                ForEach(0..<(rarity == .legend ? 28 : 14), id: \.self) { i in
                    spark(i)
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: rarity == .legend ? 1.4 : 0.9)) { go = true } }
    }

    private func spark(_ i: Int) -> some View {
        let count = Double(rarity == .legend ? 28 : 14)
        let angle = Double(i) / count * 2 * .pi + Double(i % 3) * 0.2
        let distance: CGFloat = CGFloat(150 + (i * 37) % 110)
        let size: CGFloat = CGFloat(rarity == .legend ? 12 + (i % 4) * 3 : 8 + (i % 3) * 2)
        return Image(systemName: rarity == .legend ? "star.fill" : "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(i % 4 == 0 ? Color.white : color)
            .offset(x: go ? CGFloat(cos(angle)) * distance : 0, y: go ? CGFloat(sin(angle)) * distance : 0)
            .opacity(go ? 0 : 1)
            .scaleEffect(go ? 0.6 : 1.2)
    }
}

/// Rayons de lumière qui tournent lentement.
private struct RotatingRays: View {
    let color: Color
    let count: Int

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2
                let spin = t.truncatingRemainder(dividingBy: 12) / 12 * 2 * .pi
                let width = Double.pi / Double(count) * 0.55
                for i in 0..<count {
                    let a = Double(i) / Double(count) * 2 * .pi + spin
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + radius * CGFloat(cos(a - width)), y: center.y + radius * CGFloat(sin(a - width))))
                    path.addLine(to: CGPoint(x: center.x + radius * CGFloat(cos(a + width)), y: center.y + radius * CGFloat(sin(a + width))))
                    path.closeSubpath()
                    context.fill(path, with: .radialGradient(Gradient(colors: [color.opacity(0.55), color.opacity(0)]),
                                                             center: center, startRadius: 0, endRadius: radius))
                }
            }
        }
    }
}

/// Ce qu'une carte a donné : nouvelle, devient brillante, des neurones, ou rien (coffret déjà brillant).
struct OutcomeTag: View {
    let outcome: Pull.Outcome
    var compact = false

    private var text: String {
        switch outcome {
        case .new: return "Nouvelle !"
        case .shiny: return compact ? "Brillante" : "Doublon : elle devient brillante"
        case .neurones(let value): return compact ? "+\(value) neurones" : "Déjà brillante : +\(value) neurones"
        case .nothing: return compact ? "Déjà brillante" : "Déjà brillante : rien de plus"
        }
    }

    private var color: Color {
        switch outcome {
        case .new: return .sun
        case .shiny: return Color(hex: 0x7BE3FF)
        case .neurones: return Color(hex: 0xFF8FB1)
        case .nothing: return .white.opacity(0.6)
        }
    }

    var body: some View {
        Text(text)
            .font(.system(compact ? .caption2 : .subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(Color.inkFixed)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, compact ? 6 : 12)
            .padding(.vertical, compact ? 3 : 6)
            .background(color, in: Capsule())
    }
}
