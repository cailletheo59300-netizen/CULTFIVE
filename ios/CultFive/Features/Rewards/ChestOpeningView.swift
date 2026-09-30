import SwiftUI
import CultFiveCore

/// Ouverture des coffres, en plein écran, à la chaîne. On touche le coffre : il tremble de plus en plus fort, saute
/// dans un éclat de lumière, puis les récompenses sortent une par une en grandes cartes dessinées (on touche pour
/// la suivante) : graines qui défilent, tickets, bouclier de joker, Léon qui porte son nouvel objet. Récapitulatif à la fin.
struct ChestOpeningView: View {
    let chests: [ChestRef]
    var onDone: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable { case closed, shaking, card(Int), summary }

    @State private var index = 0
    @State private var phase: Phase = .closed
    @State private var contents: ChestContents?
    @State private var shake = 0.0
    @State private var flash = 0.0
    @State private var error: String?

    private var chest: ChestRef? { chests.indices.contains(index) ? chests[index] : nil }
    private var isLast: Bool { index >= chests.count - 1 }
    private var rewards: [ChestReward] { contents.map(ChestReward.list) ?? [] }

    var body: some View {
        ZStack {
            Color(hex: 0x1E1340).ignoresSafeArea()
            if phase != .closed && phase != .shaking {
                LightRays(color: glow).ignoresSafeArea().transition(.opacity)
            }
            VStack(spacing: Space.l) {
                header
                Spacer(minLength: 0)
                stage
                Spacer(minLength: 0)
                footer
            }
            .padding(Space.gutter)
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
            if case .card(let i) = phase, rewards.indices.contains(i), rewards[i].isItem || chest?.tier == .gold {
                Confetti().ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .preferredColorScheme(.dark)
    }

    // MARK: Blocs

    private var glow: Color {
        switch chest?.tier {
        case .gold: return Color.sun
        case .silver: return Color(hex: 0xC5D3E8)
        default: return Color(hex: 0xFFB36B)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(chest?.tier.title ?? "").font(.system(.title, design: .rounded).weight(.black)).foregroundStyle(.white)
            Text(chest?.origin ?? "").font(.cfCallout).foregroundStyle(.white.opacity(0.7))
            if chests.count > 1 {
                Text("\(index + 1) sur \(chests.count)")
                    .font(.system(.footnote, design: .rounded).weight(.heavy)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.top, Space.l)
    }

    @ViewBuilder
    private var stage: some View {
        switch phase {
        case .closed, .shaking:
            VStack(spacing: Space.l) {
                if let chest {
                    ChestView(tier: chest.tier)
                        .frame(maxWidth: 220)
                        .rotationEffect(.degrees(sin(shake * .pi * 14) * 9 * shake))
                        .scaleEffect(1 + 0.08 * shake)
                        .shadow(color: glow.opacity(0.5 * shake), radius: 30)
                        .id(chest.id)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(phase == .shaking ? " " : "Touche le coffre pour l'ouvrir")
                    .font(.system(.headline, design: .rounded)).foregroundStyle(.white.opacity(0.8))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        case .card(let i):
            if rewards.indices.contains(i) {
                RewardCard(reward: rewards[i], glow: glow)
                    .id(i)
                    .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity).combined(with: .offset(y: 120)),
                                            removal: .scale(scale: 0.6).combined(with: .opacity).combined(with: .offset(x: -200))))
            }
        case .summary:
            VStack(spacing: Space.m) {
                ChestView(tier: chest?.tier ?? .wood, open: true).frame(width: 110)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(Array(rewards.enumerated()), id: \.offset) { _, reward in
                        RewardCard(reward: reward, glow: glow, compact: true)
                    }
                }
            }
            .transition(.opacity)
        }
    }

    private var footer: some View {
        VStack(spacing: Space.s) {
            if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
            switch phase {
            case .summary:
                Button(isLast ? "Terminé" : "Coffre suivant") { next() }
                    .buttonStyle(InkButtonStyle(fill: Color.sun, text: Color(hex: 0x1E1340)))
            case .card(let i):
                Text(i < rewards.count - 1 ? "Touche pour la suite · \(i + 1)/\(rewards.count)" : "Touche pour tout voir")
                    .font(.system(.footnote, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.6))
                    .frame(minHeight: 44)
            case .closed:
                Button("Plus tard") { onDone() }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(minHeight: 44)
            case .shaking:
                Color.clear.frame(height: 44)
            }
        }
    }

    // MARK: Déroulé

    /// Un toucher fait avancer : ouvrir, carte suivante, récapitulatif.
    private func advance() {
        switch phase {
        case .closed: Task { await open() }
        case .card(let i):
            Haptics.selection()
            withAnimation(Motion.bounce) { phase = i + 1 < rewards.count ? .card(i + 1) : .summary }
            if i + 1 < rewards.count { cueFor(rewards[i + 1]) }
        default: break
        }
    }

    private func open() async {
        guard let chest, contents == nil, phase == .closed else { return }
        error = nil
        withAnimation(.easeIn(duration: 0.2)) { phase = .shaking }
        let service = app.service
        async let result = service.openChest(chest.id)
        if !reduceMotion {
            // Le tremblement monte, les vibrations aussi.
            withAnimation(.easeIn(duration: 1.1)) { shake = 1 }
            for step in 0 ..< 6 {
                try? await Task.sleep(nanoseconds: UInt64(260_000_000 - step * 30_000_000))
                Haptics.soft()
            }
        }
        do {
            let opened = try await result
            contents = opened
            SoundFX.play(.chest)
            Haptics.success()
            shake = 0
            if !reduceMotion {
                flash = 0.9
                withAnimation(.easeOut(duration: 0.6)) { flash = 0 }
            }
            withAnimation(Motion.bounce) { phase = .card(0) }
            if let first = rewards.first { cueFor(first) }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Ouverture impossible. Réessaie."
            withAnimation(Motion.standard) {
                shake = 0
                phase = .closed
            }
        }
    }

    private func cueFor(_ reward: ChestReward) {
        if reward.isItem { SoundFX.play(.reward) } else { SoundFX.play(.correct) }
    }

    private func next() {
        if isLast {
            onDone()
            return
        }
        withAnimation(Motion.standard) {
            index += 1
            contents = nil
            phase = .closed
        }
    }
}

// MARK: - Récompenses

enum ChestReward: Hashable {
    case seeds(Int)
    case tickets(HelpKind, Int)
    case joker
    case item(ChestItem)

    var isItem: Bool { if case .item = self { return true } else { return false } }

    static func list(_ contents: ChestContents) -> [ChestReward] {
        var list: [ChestReward] = [.seeds(contents.seeds)]
        if contents.tickets.fiftyFifty > 0 { list.append(.tickets(.fiftyFifty, contents.tickets.fiftyFifty)) }
        if contents.tickets.hint > 0 { list.append(.tickets(.hint, contents.tickets.hint)) }
        if contents.joker { list.append(.joker) }
        if let item = contents.item { list.append(.item(item)) }
        return list
    }
}

/// Grande carte d'une récompense (ou petite, dans le récapitulatif), avec son dessin.
private struct RewardCard: View {
    let reward: ChestReward
    let glow: Color
    var compact = false

    @State private var counted = 0

    var body: some View {
        VStack(spacing: compact ? 4 : Space.m) {
            art.frame(width: compact ? 54 : 150, height: compact ? 54 : 150)
            Text(title)
                .font(compact ? .system(.subheadline, design: .rounded).weight(.heavy) : .system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(counted)))
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
            if !compact {
                Text(subtitle).font(.cfCallout).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            }
        }
        .padding(compact ? 10 : Space.l)
        .frame(maxWidth: compact ? .infinity : 300)
        .background(.white.opacity(compact ? 0.1 : 0.12), in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.l, style: .continuous).strokeBorder(glow.opacity(reward.isItem ? 0.9 : 0.35), lineWidth: 2))
        .shadow(color: glow.opacity(compact ? 0 : 0.4), radius: 24)
        .accessibilityElement(children: .combine)
        .task {
            guard case .seeds(let n) = reward else { return }
            if compact { counted = n; return }
            // Les graines défilent jusqu'au total.
            let steps = 14
            for step in 1 ... steps {
                try? await Task.sleep(nanoseconds: 45_000_000)
                withAnimation(.snappy) { counted = n * step / steps }
            }
        }
    }

    private var title: String {
        switch reward {
        case .seeds(let n): return "+\(compact ? n : counted)"
        case .tickets(let kind, let n): return "\(n) ticket\(n > 1 ? "s" : "") \(kind == .fiftyFifty ? "50/50" : "indice")"
        case .joker: return "Joker de série"
        case .item(let item): return item.name
        }
    }

    private var subtitle: String {
        switch reward {
        case .seeds: return "\(Brand.currencyPlural.capitalized) pour l'arbre de Léon et les aides"
        case .tickets(let kind, _): return kind == .fiftyFifty ? "Retire deux mauvaises réponses, sans dépenser de graines" : "Un indice gratuit pendant une partie"
        case .joker: return "Protège ta série un jour où tu oublies de jouer"
        case .item: return "Nouveau pour Léon : il le porte déjà !"
        }
    }

    @ViewBuilder
    private var art: some View {
        switch reward {
        case .seeds: SeedPile()
        case .tickets(let kind, _): TicketShape(color: kind == .fiftyFifty ? Color(hex: 0x4DABF7) : Color.sun, label: kind == .fiftyFifty ? "50/50" : "?")
        case .joker: ShieldShape()
        case .item(let item):
            Leon(color: .brand, pose: .proud, curl: 0.6, animated: !compact, outfit: LeonOutfit().trying(item.id, slot: item.slot))
        }
    }
}

/// Petit tas de graines dessiné.
private struct SeedPile: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 100
            context.scaleBy(x: s, y: s)
            let seeds: [(Double, Double, Double)] = [(30, 62, -0.5), (54, 66, 0.3), (42, 44, 0.9), (68, 46, -0.2), (56, 26, 0.5)]
            for (x, y, angle) in seeds {
                let seed = Path(ellipseIn: CGRect(x: -12, y: -18, width: 24, height: 36))
                    .applying(CGAffineTransform(rotationAngle: angle))
                    .applying(CGAffineTransform(translationX: x, y: y))
                context.fill(seed, with: .color(Color(hex: 0xF0B654)))
                context.fill(seed.applying(CGAffineTransform(translationX: 2, y: 2)), with: .color(Color(hex: 0xB9772A).opacity(0.35)))
                context.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 10, width: 6, height: 10)), with: .color(.white.opacity(0.5)))
            }
            var sprout = Path()
            sprout.move(to: CGPoint(x: 56, y: 12))
            sprout.addQuadCurve(to: CGPoint(x: 66, y: 0), control: CGPoint(x: 58, y: 2))
            context.stroke(sprout, with: .color(Color(hex: 0x51CF66)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// Ticket dessiné (encoches sur les côtés).
private struct TicketShape: View {
    let color: Color
    let label: String

    var body: some View {
        ZStack {
            Canvas { context, size in
                let rect = CGRect(x: 0, y: size.height * 0.2, width: size.width, height: size.height * 0.6)
                var ticket = Path(roundedRect: rect, cornerRadius: 10)
                let r = rect.height * 0.16
                ticket.addEllipse(in: CGRect(x: -r, y: rect.midY - r, width: 2 * r, height: 2 * r))
                ticket.addEllipse(in: CGRect(x: rect.maxX - r, y: rect.midY - r, width: 2 * r, height: 2 * r))
                context.fill(ticket, with: .color(color), style: FillStyle(eoFill: true))
                var dash = Path()
                dash.move(to: CGPoint(x: rect.width * 0.7, y: rect.minY + 6))
                dash.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.maxY - 6))
                context.stroke(dash, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            .rotationEffect(.degrees(-8))
            Text(label)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: 0x1E1340))
                .rotationEffect(.degrees(-8))
                .offset(x: -12)
        }
        .accessibilityHidden(true)
    }
}

/// Bouclier du joker de série.
private struct ShieldShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var shield = Path()
            shield.move(to: CGPoint(x: w * 0.5, y: h * 0.06))
            shield.addLine(to: CGPoint(x: w * 0.88, y: h * 0.2))
            shield.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.95), control: CGPoint(x: w * 0.9, y: h * 0.7))
            shield.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.2), control: CGPoint(x: w * 0.1, y: h * 0.7))
            shield.closeSubpath()
            context.fill(shield, with: .linearGradient(Gradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8)]),
                                                        startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
            context.stroke(shield, with: .color(Color.sun), lineWidth: 4)
            var flame = Path()
            flame.move(to: CGPoint(x: w * 0.5, y: h * 0.28))
            flame.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.75), control: CGPoint(x: w * 0.78, y: h * 0.5))
            flame.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.28), control: CGPoint(x: w * 0.24, y: h * 0.52))
            context.fill(flame, with: .color(Color(hex: 0xFF922B)))
        }
        .accessibilityHidden(true)
    }
}

/// Rayons de lumière qui tournent lentement derrière la récompense.
private struct LightRays: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                LightRays.draw(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate, color: color)
            }
        }
        .accessibilityHidden(true)
    }

    private static func draw(in context: inout GraphicsContext, size: CGSize, time: Double, color: Color) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.45)
        let radius: Double = max(Double(size.width), Double(size.height))
        let gradient = Gradient(colors: [color.opacity(0.35), color.opacity(0)])
        let shading = GraphicsContext.Shading.radialGradient(gradient, center: center, startRadius: 20, endRadius: radius * 0.6)
        for i in 0 ..< 12 {
            let start: Double = Double(i) / 12 * 2 * Double.pi + time * 0.25
            let end: Double = start + 0.16
            let p1 = CGPoint(x: center.x + radius * cos(start), y: center.y + radius * sin(start))
            let p2 = CGPoint(x: center.x + radius * cos(end), y: center.y + radius * sin(end))
            var ray = Path()
            ray.move(to: center)
            ray.addLine(to: p1)
            ray.addLine(to: p2)
            ray.closeSubpath()
            context.fill(ray, with: shading)
        }
    }
}
