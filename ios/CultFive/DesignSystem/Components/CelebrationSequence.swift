import SwiftUI
import CultFiveCore

/// Un moment fort à fêter en plein écran.
enum Celebration: Hashable, Identifiable {
    /// Nouveau niveau d'XP, avec le coffre qu'il a donné.
    case level(Int, xp: Int?, chest: ChestTier?)
    /// Nouveau rang (ou Elo confirmé) dans un domaine.
    case rank(CoteCULT.Rank, domain: String, cote: Int, confirmed: Bool)
    case trophy(name: String, detail: String?, chest: ChestTier?)
    /// Nouveau record de série ; `joker` : un joker de série gagné.
    case streak(Int, joker: Bool)
    case quest(label: String, seeds: Int, xp: Int, chest: ChestTier?)

    var id: String {
        switch self {
        case .level(let n, _, _): return "level-\(n)"
        case .rank(let r, let d, _, let c): return "rank-\(d)-\(r.rawValue)-\(c)"
        case .trophy(let name, _, _): return "trophy-\(name)"
        case .streak(let n, _): return "streak-\(n)"
        case .quest(let label, _, _, _): return "quest-\(label)"
        }
    }
}

/// Les moments forts, en plein écran et l'un après l'autre (niveau, rang, trophée, record de série, défi rempli).
/// L'objet entre en scène, puis l'éclat, les confettis et les textes. « Continuer » termine l'animation en cours,
/// puis passe au suivant.
struct CelebrationSequence: View {
    let items: [Celebration]
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var start = Date()
    /// Animation d'entrée terminée : textes, confettis, bouton « Continuer ».
    @State private var revealed = false
    /// Animation sautée (toucher pendant l'entrée, ou animations réduites).
    @State private var skipped = false

    private var item: Celebration? { items.indices.contains(index) ? items[index] : nil }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x8A6BFF), Color(hex: 0x6A4CFF), Color(hex: 0x3A1FB8)],
                           center: UnitPoint(x: 0.5, y: 0.32), startRadius: 0, endRadius: 640)
                .ignoresSafeArea()
            CelebrationRays().ignoresSafeArea()
            if let item {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: onDone) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.16), in: Circle())
                        }
                        .accessibilityLabel("Fermer")
                    }
                    Spacer(minLength: Space.s)
                    TimelineView(.animation(paused: skipped || revealed && !loops(item))) { timeline in
                        CelebrationStage(item: item, elapsed: skipped ? 99 : timeline.date.timeIntervalSince(start),
                                         time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                    .frame(width: 280, height: 280)
                    .accessibilityHidden(true)
                    texts(item)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 14)
                    Spacer(minLength: Space.s)
                    footer
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.m)
                .id(item.id)
                .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
            }
            if revealed && !reduceMotion {
                Confetti().id(index).ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .task(id: index) { await play() }
        .accessibilityElement(children: .contain)
    }

    // MARK: Textes

    private func texts(_ item: Celebration) -> some View {
        VStack(spacing: 6) {
            Text(caption(item))
                .font(.system(size: 13, weight: .black, design: .rounded)).tracking(2)
                .foregroundStyle(Color.sun)
            Text(title(item))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.6)
            Text(detail(item))
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if case .streak(let days, _) = item { WeekRow(days: days).padding(.top, 10) }
            rewards(item).padding(.top, 12)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func rewards(_ item: Celebration) -> some View {
        let chips = rewardChips(item)
        if !chips.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    HStack(spacing: 6) {
                        chip.icon.frame(width: 28, height: 28)
                        Text(chip.text).font(.system(.subheadline, design: .rounded).weight(.black))
                    }
                    .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1.5))
                }
            }
        }
    }

    private struct Chip {
        let icon: AnyView
        let text: String
    }

    private func rewardChips(_ item: Celebration) -> [Chip] {
        var chips: [Chip] = []
        func chest(_ tier: ChestTier?) {
            if let tier { chips.append(Chip(icon: AnyView(ChestView(tier: tier)), text: tier.title)) }
        }
        switch item {
        case .level(_, _, let tier): chest(tier)
        case .rank: break
        case .trophy(_, _, let tier): chest(tier)
        case .streak(_, let joker):
            if joker { chips.append(Chip(icon: AnyView(GameIcon.joker.image), text: "Joker de série +1")) }
        case .quest(_, let seeds, let xp, let tier):
            chest(tier)
            if tier == nil, seeds > 0 { chips.append(Chip(icon: AnyView(SeedIcon()), text: "+\(seeds) \(Brand.currencyPlural)")) }
            if tier == nil, xp > 0 { chips.append(Chip(icon: AnyView(EmptyView()), text: "+\(xp) XP")) }
        }
        return chips
    }

    private func caption(_ item: Celebration) -> String {
        switch item {
        case .level: return "NIVEAU SUPÉRIEUR"
        case .rank(_, _, _, let confirmed): return confirmed ? "ELO CONFIRMÉ" : "NOUVEAU RANG"
        case .trophy: return "TROPHÉE DÉBLOQUÉ"
        case .streak: return "NOUVEAU RECORD"
        case .quest: return "DÉFI RÉUSSI"
        }
    }

    private func title(_ item: Celebration) -> String {
        switch item {
        case .level(let n, _, _): return "Niveau \(n)"
        case .rank(let rank, _, _, _): return rank.name
        case .trophy(let name, _, _): return name
        case .streak(let n, _): return "\(n) jours de suite"
        case .quest(let label, _, _, _): return label
        }
    }

    private func detail(_ item: Celebration) -> String {
        switch item {
        case .level(_, _, let tier):
            return tier != nil ? "Ton XP grimpe, et un coffre t'attend." : "Ton XP grimpe, continue comme ça !"
        case .rank(_, let domain, let cote, let confirmed):
            return confirmed ? "\(domain) · Elo \(CoteCULT.format(cote)). Il bouge maintenant de 40 points au plus par partie."
                : "\(domain) · Elo \(CoteCULT.format(cote))"
        case .trophy(_, let detail, _): return detail ?? "Un nouveau trophée dans ta vitrine."
        case .streak(let n, _): return "Ton meilleur record ! Reviens demain pour faire \(n + 1)."
        case .quest(_, let seeds, _, let tier):
            return tier != nil ? "Ton coffre t'attend." : seeds > 0 ? "Tes graines sont dans ton sac." : "Bien joué !"
        }
    }

    // MARK: Bas de l'écran

    private var footer: some View {
        VStack(spacing: Space.m) {
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { i in
                        Capsule().fill(.white.opacity(i == index ? 1 : 0.3)).frame(width: i == index ? 20 : 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
            Button(index >= items.count - 1 ? "Terminer" : "Continuer") { advance() }
                .buttonStyle(InkButtonStyle(fill: .white, text: Color(hex: 0x3A1FB8)))
        }
    }

    // MARK: Déroulé

    private func play() async {
        guard let item else { return }
        revealed = false
        skipped = reduceMotion
        start = Date()
        if !reduceMotion {
            try? await Task.sleep(nanoseconds: UInt64(CelebrationStage.revealAt(item) * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        reveal()
    }

    private func reveal() {
        guard !revealed else { return }
        withAnimation(Motion.bounce) { revealed = true }
        SoundFX.play(.reward)
        Haptics.success()
    }

    /// Premier toucher : finir l'animation ; ensuite, moment suivant ou fin.
    private func advance() {
        if !revealed {
            skipped = true
            reveal()
            return
        }
        if index >= items.count - 1 {
            onDone()
        } else {
            withAnimation(Motion.standard) { index += 1 }
        }
    }

    /// Animations qui continuent après l'entrée (étincelles, flamme).
    private func loops(_ item: Celebration) -> Bool {
        switch item {
        case .level, .streak, .rank: return true
        default: return false
        }
    }
}

// MARK: - Scène

/// L'objet du moment fort, animé selon le temps écoulé depuis son entrée.
private struct CelebrationStage: View {
    let item: Celebration
    let elapsed: Double
    let time: Double

    /// Instant où l'objet a fini d'entrer (textes, confettis).
    static func revealAt(_ item: Celebration) -> Double {
        switch item {
        case .level: return 1.45
        case .rank: return 1.25
        case .trophy: return 0.8
        case .streak: return 1.3
        case .quest: return 0.95
        }
    }

    var body: some View {
        switch item {
        case .level(let n, let xp, _): level(n, xp: xp)
        case .rank(let rank, _, _, _): rankEmblem(rank)
        case .trophy: trophy
        case .streak(let n, _): streak(n)
        case .quest: quest
        }
    }

    private static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    private func ring(_ i: Int) -> CGFloat { CGFloat(200 - 36 * i) }
    private static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    // Niveau : l'anneau d'XP se remplit, puis le nombre passe au niveau suivant.
    private func level(_ n: Int, xp: Int?) -> some View {
        let fill: Double = Self.clamp((elapsed - 0.3) / 1.1)
        let done = fill >= 1
        let pop: Double = done ? Self.easeOutBack(Self.clamp((elapsed - 1.4) / 0.5)) : 1
        let shownXP: Int = Int(Double(xp ?? 0) * fill)
        return ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: 16).frame(width: 208, height: 208)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(AngularGradient(colors: [Color(hex: 0xFFE680), Color(hex: 0xFFB800), Color(hex: 0xFFE680)], center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 208, height: 208)
            ZStack {
                Circle().fill(Color(hex: 0x140850).opacity(0.35)).frame(width: 168, height: 168).offset(y: 6)
                Circle().fill(.white).frame(width: 168, height: 168)
                Circle().fill(Color(hex: 0xF3F0FF)).frame(width: 148, height: 148)
                VStack(spacing: -6) {
                    Text("NIVEAU").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(Color.brand)
                    Text("\(done ? n : n - 1)").font(.system(size: 76, weight: .black, design: .rounded)).foregroundStyle(Color(hex: 0x3A1FB8))
                        .monospacedDigit()
                }
            }
            .scaleEffect(pop)
            if done { Sparkles(time: time, radius: 128) }
            if xp != nil {
                Text("+\(shownXP) XP")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .offset(y: 132)
            }
        }
    }

    // Rang : l'emblème 3D arrive en tournant.
    private func rankEmblem(_ rank: CoteCULT.Rank) -> some View {
        let k: Double = Self.clamp((elapsed - 0.15) / 1.1)
        let sway: Double = k >= 1 ? sin(time * 0.8) * 22 : 0
        let spin: Double = (1 - k) * 720 + sway
        let scale: Double = max(0.01, Self.easeOutBack(k) * 1.1 - 0.1 * k)
        return ZStack {
            Circle().fill(RadialGradient(colors: [.white.opacity(0.45), .clear], center: .center, startRadius: 10, endRadius: 140))
            Image("rank_\(String(describing: rank))")
                .resizable().scaledToFit()
                .frame(width: 230, height: 230)
                .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                .scaleEffect(scale)
            if k >= 1 { Sparkles(time: time, radius: 132) }
        }
    }

    // Trophée : la coupe tombe d'en haut, rebondit et se balance.
    private var trophy: some View {
        let k: Double = Self.clamp((elapsed - 0.1) / 0.7)
        let since: Double = elapsed - 0.8
        let swing: Double = k >= 1 ? exp(-since * 1.4) * 9 * sin(since * 6) : 0
        let drop: Double = -(1 - Self.easeOutBack(k)) * 420
        return Image("trophy_cup")
            .resizable().scaledToFit()
            .frame(width: 230, height: 230)
            .rotationEffect(.degrees(swing), anchor: .top)
            .offset(y: drop)
    }

    // Record de série : la flamme grandit, le compteur passe au nouveau record.
    private func streak(_ n: Int) -> some View {
        let grow: Double = Self.easeOutBack(Self.clamp((elapsed - 0.2) / 0.7))
        let lit = elapsed >= 1.2
        let flicker: Double = 1 + sin(time * 9) * 0.025
        let sx: Double = grow * (lit ? 1.08 : 1)
        let sy: Double = sx * flicker
        let pop: Double = lit ? Self.easeOutBack(Self.clamp((elapsed - 1.2) / 0.4)) : 1
        return ZStack {
            Ellipse().fill(Color(hex: 0x140850).opacity(0.3)).frame(width: 150, height: 20).offset(y: 120)
            Image("flame")
                .resizable().scaledToFit()
                .frame(width: 240, height: 240)
                .scaleEffect(x: sx, y: sy, anchor: .bottom)
            Text("\(lit ? n : max(n - 1, 0))")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .monospacedDigit()
                .shadow(color: Color(hex: 0xA03200).opacity(0.7), radius: 0, x: 0, y: 4)
                .offset(y: 40)
                .scaleEffect(pop)
                .opacity(grow > 0.6 ? 1 : 0)
        }
    }

    // Défi rempli : la flèche se plante au centre, puis la coche.
    private var quest: some View {
        let appear: Double = Self.easeOutBack(Self.clamp(elapsed / 0.6))
        let hit: Double = Self.clamp((elapsed - 0.6) / 0.35)
        let check: Double = elapsed > 1.05 ? Self.easeOutBack(Self.clamp((elapsed - 1.05) / 0.45)) : 0
        let arrowX: Double = 65 + (1 - hit) * 220
        let arrowY: Double = -(1 - hit) * 160
        return ZStack {
            ZStack {
                Circle().fill(Color(hex: 0x140850).opacity(0.3)).frame(width: 200, height: 200).offset(y: 8)
                ForEach(0 ..< 6, id: \.self) { i in
                    Circle().fill(i.isMultiple(of: 2) ? Color.white : Color(hex: 0xFF4D5E))
                        .frame(width: ring(i), height: ring(i))
                }
            }
            .scaleEffect(appear)
            Arrow()
                .frame(width: 130, height: 30)
                .rotationEffect(.degrees(-36), anchor: .leading)
                .offset(x: arrowX, y: arrowY)
                .opacity(elapsed > 0.55 ? 1 : 0)
            ZStack {
                Circle().fill(Color.correct).frame(width: 60, height: 60)
                Image(systemName: "checkmark").font(.system(size: 26, weight: .black))
            }
            .scaleEffect(check)
            .offset(x: 82, y: 82)
        }
    }
}

/// Flèche (empennage doré), pointe à gauche.
private struct Arrow: View {
    var body: some View {
        Canvas { context, size in
            let h = size.height, w = size.width
            context.fill(Path(CGRect(x: 10, y: h / 2 - 3, width: w - 10, height: 6)), with: .color(Color(hex: 0x8D5B3A)))
            var tip = Path()
            tip.move(to: CGPoint(x: 0, y: h / 2))
            tip.addLine(to: CGPoint(x: 20, y: h / 2 - 11))
            tip.addLine(to: CGPoint(x: 20, y: h / 2 + 11))
            tip.closeSubpath()
            context.fill(tip, with: .color(Color(hex: 0x3A1FB8)))
            for side in [-1.0, 1.0] {
                var feather = Path()
                feather.move(to: CGPoint(x: w - 28, y: h / 2))
                feather.addLine(to: CGPoint(x: w - 4, y: h / 2 + side * 14))
                feather.addLine(to: CGPoint(x: w, y: h / 2 + side * 14))
                feather.addLine(to: CGPoint(x: w - 16, y: h / 2))
                feather.closeSubpath()
                context.fill(feather, with: .color(Color.sun))
            }
        }
    }
}

/// Étoiles qui tournent autour de l'objet une fois révélé.
private struct Sparkles: View {
    let time: Double
    let radius: Double

    private func size(_ i: Int) -> CGFloat {
        let pulse: Double = 0.5 + 0.5 * sin(time * 4 + Double(i))
        return CGFloat(14 + 6 * pulse)
    }

    private func offset(_ i: Int) -> CGSize {
        let angle: Double = Double(i) / 6 * 2 * Double.pi + time * 0.6
        let r: Double = radius + sin(time * 3 + Double(i)) * 4
        return CGSize(width: cos(angle) * r, height: sin(angle) * r)
    }

    var body: some View {
        ZStack {
            ForEach(0 ..< 6, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: size(i), weight: .black))
                    .foregroundStyle(Color.sun)
                    .offset(offset(i))
            }
        }
    }
}

/// Les 7 derniers jours de la série, aujourd'hui en or avec le nombre de jours.
private struct WeekRow: View {
    let days: Int
    @State private var lit = 0

    private var labels: [String] {
        // Les 7 derniers jours, le dernier étant aujourd'hui.
        let symbols = ["D", "L", "M", "M", "J", "V", "S"]
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        return (0 ..< 7).map { symbols[(today - 6 + $0 + 7) % 7] }
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0 ..< 7, id: \.self) { i in
                let today = i == 6
                let on = i < lit
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(on ? (today ? Color.sun : Color(hex: 0xFF922B)) : .white.opacity(0.14))
                        if on {
                            Text(today ? "\(days)" : "✓")
                                .font(.system(size: today ? 12 : 14, weight: .black, design: .rounded))
                                .foregroundStyle(today ? Color(hex: 0x1E1340) : .white)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .scaleEffect(on ? 1.06 : 1)
                    Text(labels[i]).font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .task {
            for i in 1 ... 7 {
                try? await Task.sleep(nanoseconds: 90_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { lit = i }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Rayons de lumière qui tournent lentement derrière l'objet.
private struct CelebrationRays: View {
    private static func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let cx = Double(size.width) / 2, cy = Double(size.height) * 0.33
        let r: Double = max(Double(size.width), Double(size.height))
        let turn: Double = time * 0.12
        let shading = GraphicsContext.Shading.radialGradient(Gradient(colors: [.white.opacity(0.16), .white.opacity(0)]),
                                                               center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r * 0.7)
        for i in 0 ..< 14 {
            let a: Double = Double(i) / 14 * 2 * Double.pi + turn
            let a1: Double = a - 0.08, a2: Double = a + 0.08
            var ray = Path()
            ray.move(to: CGPoint(x: cx, y: cy))
            ray.addLine(to: CGPoint(x: cx + r * cos(a1), y: cy + r * sin(a1)))
            ray.addLine(to: CGPoint(x: cx + r * cos(a2), y: cy + r * sin(a2)))
            ray.closeSubpath()
            context.fill(ray, with: shading)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time: Double = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                CelebrationRays.draw(in: &context, size: size, time: time)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
