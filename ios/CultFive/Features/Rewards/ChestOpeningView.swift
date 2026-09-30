import SwiftUI
import CultFiveCore

/// Ouverture des coffres, en plein écran, à la chaîne. La Recharge : trois touchers, le coffre tremble de plus en plus
/// fort dans son halo, des étincelles jaillissent, et il peut monter de rang (tirage fait par le serveur à l'ouverture).
/// Au 3e toucher il s'ouvre dans un éclat ; les récompenses sortent une par une en grandes cartes, puis le récapitulatif.
struct ChestOpeningView: View {
    let chests: [ChestRef]
    var onDone: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable { case closed, charging, card(Int), summary }
    private static let taps = 3

    @State private var index = 0
    @State private var phase: Phase = .closed
    @State private var contents: ChestContents?
    @State private var opening: Task<ChestContents, Error>?
    @State private var taps = 0
    @State private var busy = false
    /// Rang atteint pendant la Recharge (nil : rang d'origine).
    @State private var upgraded: ChestTier?
    @State private var upgradeBanner: ChestTier?
    @State private var kick = 0.0
    @State private var wobble = false
    @State private var burst: ChestBurst?
    @State private var flash = 0.0
    @State private var error: String?

    private var chest: ChestRef? { chests.indices.contains(index) ? chests[index] : nil }
    private var tier: ChestTier { upgraded ?? chest?.tier ?? .wood }
    private var isLast: Bool { index >= chests.count - 1 }
    private var rewards: [ChestReward] { contents.map(ChestReward.list) ?? [] }

    var body: some View {
        ZStack {
            Color(hex: 0x1E1340).ignoresSafeArea()
            if phase != .closed && phase != .charging {
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
            if let burst, !reduceMotion {
                ChestSparks(burst: burst).ignoresSafeArea().allowsHitTesting(false)
            }
            Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
            if case .card(let i) = phase, rewards.indices.contains(i), rewards[i].isItem || tier.rank >= 2 {
                Confetti().ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { wobble = true }
        }
    }

    // MARK: Blocs

    private var glow: Color { ChestGlow.color(tier) }

    private var header: some View {
        VStack(spacing: 4) {
            Text(tier.title).font(.system(.title, design: .rounded).weight(.black)).foregroundStyle(.white)
                .contentTransition(.opacity)
                .id(tier)
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
        case .closed, .charging:
            VStack(spacing: Space.l) {
                if let chest {
                    ZStack {
                        // Halo de la rareté, qui grossit à chaque toucher.
                        Circle()
                            .fill(RadialGradient(colors: [glow.opacity(0.6), glow.opacity(0)], center: .center, startRadius: 8, endRadius: 170))
                            .frame(width: 340, height: 340)
                            .scaleEffect(1 + 0.12 * Double(taps))
                        ChestView(tier: tier)
                            .frame(maxWidth: 220)
                            .rotationEffect(.degrees(taps == 0 && wobble ? 2.5 : (taps == 0 ? -2.5 : 0)), anchor: .bottom)
                            .rotationEffect(.degrees(kick), anchor: .bottom)
                            .scaleEffect(1 + 0.06 * Double(taps))
                            .shadow(color: glow.opacity(0.5), radius: 30)
                    }
                    .id(chest.id)
                    .transition(.scale.combined(with: .opacity))
                }
                if let upgradeBanner {
                    Text("Amélioré : \(upgradeBanner.title) !")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(ChestGlow.color(upgradeBanner))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(taps == 0 ? "Touche 3 fois pour recharger le coffre" : "Encore !")
                        .font(.system(.headline, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                }
                HStack(spacing: 8) {
                    ForEach(0 ..< Self.taps, id: \.self) { i in
                        Circle().fill(i < taps ? glow : .white.opacity(0.2)).frame(width: 10, height: 10)
                    }
                }
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Touche trois fois pour ouvrir le coffre")
        case .card(let i):
            if rewards.indices.contains(i) {
                RewardCard(reward: rewards[i], glow: glow)
                    .id(i)
                    .transition(.asymmetric(insertion: .scale(scale: 0.3).combined(with: .opacity).combined(with: .offset(y: 120)),
                                            removal: .scale(scale: 0.6).combined(with: .opacity).combined(with: .offset(x: -200))))
            }
        case .summary:
            VStack(spacing: Space.m) {
                ChestView(tier: tier, open: true).frame(width: 110)
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
            case .charging:
                Color.clear.frame(height: 44)
            }
        }
    }

    // MARK: Déroulé

    /// Un toucher fait avancer : recharger, carte suivante, récapitulatif.
    private func advance() {
        switch phase {
        case .closed, .charging: Task { await charge() }
        case .card(let i):
            Haptics.selection()
            withAnimation(Motion.bounce) { phase = i + 1 < rewards.count ? .card(i + 1) : .summary }
            if i + 1 < rewards.count { cueFor(rewards[i + 1]) }
        default: break
        }
    }

    /// Un toucher de Recharge. Le serveur tire tout dès le premier ; les montées se dévoilent sur les derniers touchers
    /// (une montée au 3e, deux aux 2e et 3e…), pour garder le suspense jusqu'au bout.
    private func charge() async {
        guard let chest, !busy, taps < Self.taps, contents == nil else { return }
        busy = true
        defer { busy = false }
        error = nil
        if taps == 0 {
            let service = app.service
            let id = chest.id
            opening = Task { try await service.openChest(id) }
            withAnimation(.easeIn(duration: 0.15)) { phase = .charging }
        }
        taps += 1
        pulse(big: false)
        Haptics.soft()
        do {
            guard let opening else { return }
            let opened = try await opening.value
            let reached = opened.reachedTier
            let rise = max(0, reached.rank - chest.tier.rank)
            // Montées à dévoiler à ce toucher : celles dont le tour est arrivé.
            let due = max(0, rise - (Self.taps - taps))
            let shown = (upgraded ?? chest.tier).rank - chest.tier.rank
            if due > shown, let next = ChestTier.allCases.first(where: { $0.rank == chest.tier.rank + due }) {
                reveal(upgrade: next)
            }
            if taps == Self.taps {
                try? await Task.sleep(nanoseconds: upgradeBanner != nil ? 700_000_000 : 250_000_000)
                openUp(with: opened)
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Ouverture impossible. Réessaie."
            opening = nil
            withAnimation(Motion.standard) {
                taps = 0
                upgraded = nil
                phase = .closed
            }
        }
    }

    /// Secousse du coffre et gerbe d'étincelles.
    private func pulse(big: Bool) {
        burst = ChestBurst(date: Date(), color: glow, big: big)
        guard !reduceMotion else { return }
        kick = (taps.isMultiple(of: 2) ? -1 : 1) * (6 + 4 * Double(taps)) * (big ? 1.5 : 1)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.25)) { kick = 0 }
    }

    private func reveal(upgrade next: ChestTier) {
        withAnimation(Motion.bounce) {
            upgraded = next
            upgradeBanner = next
        }
        SoundFX.play(.reward)
        Haptics.success()
        pulse(big: true)
        if !reduceMotion {
            flash = 0.7
            withAnimation(.easeOut(duration: 0.5)) { flash = 0 }
        }
    }

    private func openUp(with opened: ChestContents) {
        contents = opened
        SoundFX.play(.chest)
        Haptics.success()
        if !reduceMotion {
            flash = 0.9
            withAnimation(.easeOut(duration: 0.6)) { flash = 0 }
        }
        withAnimation(Motion.bounce) {
            upgradeBanner = nil
            phase = .card(0)
        }
        if let first = rewards.first { cueFor(first) }
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
            opening = nil
            taps = 0
            upgraded = nil
            upgradeBanner = nil
            phase = .closed
        }
    }
}

/// Couleur du halo et de la lumière selon la rareté.
enum ChestGlow {
    static func color(_ tier: ChestTier) -> Color {
        switch tier {
        case .wood: return Color(hex: 0xFFB36B)
        case .silver: return Color(hex: 0xC5D3E8)
        case .gold: return Color.sun
        case .savant: return Color(hex: 0xB197FC)
        }
    }
}

struct ChestBurst: Equatable {
    let id = UUID()
    let date: Date
    let color: Color
    let big: Bool
}

/// Étincelles qui jaillissent du coffre à chaque toucher (plus nombreuses et plus loin à une montée de rang).
private struct ChestSparks: View {
    let burst: ChestBurst

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
            Canvas { context, size in
                let elapsed: Double = timeline.date.timeIntervalSince(burst.date)
                ChestSparks.draw(in: &context, size: size, elapsed: elapsed, color: burst.color, big: burst.big)
            }
        }
        .accessibilityHidden(true)
    }

    private static func draw(in context: inout GraphicsContext, size: CGSize, elapsed: Double, color: Color, big: Bool) {
        let duration: Double = big ? 1.1 : 0.7
        guard elapsed >= 0, elapsed < duration else { return }
        let t: Double = elapsed / duration
        let eased: Double = 1 - (1 - t) * (1 - t)
        let center = CGPoint(x: size.width / 2, y: size.height * 0.48)
        let count: Int = big ? 28 : 14
        let reach: Double = big ? 210 : 130
        for i in 0 ..< count {
            let noise: Double = abs(sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
            let angle: Double = Double(i) / Double(count) * 2 * Double.pi + noise * 0.6
            let distance: Double = reach * (0.55 + 0.45 * noise) * eased
            let x: Double = Double(center.x) + cos(angle) * distance
            let y: Double = Double(center.y) + sin(angle) * distance + 40 * t * t
            let radius: Double = (big ? 4.5 : 3.5) * (1 - t * 0.6)
            let spark = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius))
            context.fill(spark, with: .color((i.isMultiple(of: 3) ? Color.white : color).opacity(1 - t)))
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
        if let bonus = contents.bonusItem { list.append(.item(bonus)) }
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
        case .tickets(let kind, _): return kind == .fiftyFifty ? "Retire deux mauvaises réponses, sans dépenser de graines" : "Un indice ou une seconde chance, sans dépenser de graines"
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
