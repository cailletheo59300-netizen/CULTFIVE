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
    /// Coffres boostés par une pub (chances de montée doublées, graines +50 %).
    @State private var boosted: Set<UUID> = []
    @State private var boosting = false
    /// Image de l'ouverture du couvercle (0 : fermé … `ChestFrames.count - 1` : ouvert).
    @State private var lidFrame = 0

    private var chest: ChestRef? { chests.indices.contains(index) ? chests[index] : nil }
    private var tier: ChestTier { upgraded ?? chest?.tier ?? .wood }
    private var isLast: Bool { index >= chests.count - 1 }
    private var rewards: [ChestReward] { contents.map(ChestReward.list) ?? [] }

    var body: some View {
        ZStack {
            // Le violet de l'app (comme les célébrations), sans rayons qui tournent.
            RadialGradient(colors: [Color(hex: 0x8A6BFF), Color(hex: 0x6A4CFF), Color(hex: 0x3A1FB8)],
                           center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 640)
                .ignoresSafeArea()
            if phase != .closed && phase != .charging {
                // Après l'ouverture, une lueur douce reste derrière les cartes.
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFECAA).opacity(0.5), .clear], center: .center, startRadius: 10, endRadius: 260))
                    .frame(width: 520, height: 520)
                    .allowsHitTesting(false)
                    .transition(.opacity)
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
            if let chest, boosted.contains(chest.id) {
                Label("Boosté", systemImage: "bolt.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.sun)
                    .transition(.scale.combined(with: .opacity))
            }
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
                        // Lueur douce derrière le coffre, qui grandit à chaque toucher.
                        Circle()
                            .fill(RadialGradient(colors: [Color(hex: 0xFFECAA).opacity(0.55), .clear], center: .center, startRadius: 8, endRadius: 170))
                            .frame(width: 340, height: 340)
                            .scaleEffect(1 + 0.12 * Double(taps))
                            .opacity(0.45 + 0.18 * Double(taps))
                        // Ombre au sol.
                        Ellipse()
                            .fill(Color(hex: 0x140850).opacity(0.45))
                            .frame(width: 170, height: 22)
                            .blur(radius: 6)
                            .offset(y: 112)
                        ChestFrames(tier: tier, frame: lidFrame)
                            .frame(maxWidth: 260)
                            .rotationEffect(.degrees(taps == 0 && wobble ? 2.5 : (taps == 0 ? -2.5 : 0)), anchor: .bottom)
                            .rotationEffect(.degrees(kick), anchor: .bottom)
                            .scaleEffect(1 + 0.06 * Double(taps))
                    }
                    .id(chest.id)
                    // Le coffre arrive en grandissant ; à l'ouverture il éclate vers l'avant (jamais il ne rapetisse).
                    .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity),
                                            removal: .scale(scale: 1.25).combined(with: .opacity)))
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
                // Pas de pub sur le coffre de bienvenue.
                if let chest, chest.source != "welcome", taps == 0, !boosted.contains(chest.id), (app.adStatus?.boostChest ?? 0) > 0 {
                    Button { Task { await boost(chest) } } label: {
                        HStack(spacing: 8) {
                            if boosting { ProgressView().controlSize(.small) }
                            Label("Booster avec une pub", systemImage: "play.rectangle.fill")
                        }
                    }
                    .buttonStyle(InkButtonStyle(fill: Color.sun, text: Color(hex: 0x1E1340)))
                    .disabled(boosting)
                    Text("Chances d'amélioration doublées, graines +50 %")
                        .font(.cfFootnote).foregroundStyle(.white.opacity(0.7))
                }
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
                await openUp(with: opened)
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

    /// Coffre boosté par une pub : le serveur le marque, l'ouverture en tient compte.
    private func boost(_ chest: ChestRef) async {
        guard !boosting else { return }
        boosting = true
        defer { boosting = false }
        error = nil
        do {
            if try await app.watchAd(.boostChest, ref: chest.id.uuidString.lowercased()) != nil {
                withAnimation(Motion.bounce) { _ = boosted.insert(chest.id) }
                Haptics.success()
                pulse(big: true)
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Pub indisponible pour l'instant."
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

    private func openUp(with opened: ChestContents) async {
        SoundFX.play(.chest)
        // Le couvercle bascule, la lueur monte, puis l'éclat.
        if !reduceMotion {
            for frame in 1 ..< ChestFrames.count {
                lidFrame = frame
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        contents = opened
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
            lidFrame = 0
            upgraded = nil
            upgradeBanner = nil
            phase = .closed
        }
    }
}

/// Le coffre 3D de l'écran d'ouverture, image par image (rendues à partir du modèle 3D, voir `scripts/icons`).
struct ChestFrames: View {
    static let count = 10
    let tier: ChestTier
    var frame = 0

    var body: some View {
        Image("chest_\(tier.rawValue)_\(min(max(frame, 0), Self.count - 1))")
            .resizable()
            .scaledToFit()
            .accessibilityElement()
            .accessibilityLabel(tier.title)
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

/// Rareté d'une récompense : couleur du cadre et du ruban, nombre de losanges.
private enum Rarity {
    case common, rare, epic, legendary

    init(_ reward: ChestReward) {
        switch reward {
        case .seeds: self = .common
        case .tickets: self = .rare
        case .joker: self = .epic
        case .item: self = .legendary
        }
    }

    var label: String {
        switch self {
        case .common: return "COMMUN"
        case .rare: return "RARE"
        case .epic: return "ÉPIQUE"
        case .legendary: return "LÉGENDAIRE"
        }
    }

    var gems: Int {
        switch self {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }

    /// Cadre de la carte.
    var frame: AnyShapeStyle {
        switch self {
        case .common: return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE3B0), Color(hex: 0xC98A2B)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .rare: return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xA5D8FF), Color(hex: 0x1C7ED6)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .epic: return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xD0BFFF), Color(hex: 0x6A4CFF)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .legendary: return AnyShapeStyle(AngularGradient(colors: [Color(hex: 0xFFE680), Color(hex: 0xFF922B), Color(hex: 0xF783AC),
                                                                       Color(hex: 0xB197FC), Color(hex: 0x74C0FC), Color(hex: 0xFFE680)], center: .center))
        }
    }

    var ribbon: Color {
        switch self {
        case .common: return Color(hex: 0xB9772A)
        case .rare: return Color(hex: 0x1C7ED6)
        case .epic: return Color(hex: 0x6A4CFF)
        case .legendary: return Color(hex: 0xE8590C)
        }
    }

    /// Losanges et rayons.
    var tint: Color {
        switch self {
        case .common: return Color(hex: 0xFFD9A0)
        case .rare: return Color(hex: 0xA5D8FF)
        case .epic: return Color(hex: 0xD0BFFF)
        case .legendary: return Color(hex: 0xFFE680)
        }
    }
}

/// Carte d'une récompense, façon carte à collectionner : cadre de rareté, objet 3D, quantité, ruban, rareté.
/// En grand, elle sort face cachée puis se retourne ; en petit (récapitulatif), une tuile.
private struct RewardCard: View {
    let reward: ChestReward
    let glow: Color
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var counted = 0
    @State private var flip = 180.0

    private var rarity: Rarity { Rarity(reward) }

    var body: some View {
        Group {
            if compact { tile } else { card }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibleTitle), \(rarity.label.lowercased())")
        .task {
            if !compact {
                if reduceMotion { flip = 0 } else {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { flip = 0 }
                }
            }
            guard case .seeds(let n) = reward else { return }
            if compact { counted = n; return }
            // Les graines défilent jusqu'au total, une fois la carte retournée.
            try? await Task.sleep(nanoseconds: 350_000_000)
            let steps = 14
            for step in 1 ... steps {
                try? await Task.sleep(nanoseconds: 45_000_000)
                withAnimation(.snappy) { counted = n * step / steps }
            }
        }
    }

    // MARK: Grande carte

    private var card: some View {
        ZStack {
            front.opacity(flip < 90 ? 1 : 0)
            CardBack().opacity(flip < 90 ? 0 : 1)
        }
        .frame(width: 236, height: 340)
        .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .shadow(color: glow.opacity(0.45), radius: 26)
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(rarity.frame)
            .overlay {
                ZStack(alignment: .top) {
                    LinearGradient(colors: [Color(hex: 0x33246E), Color(hex: 0x1A1140)], startPoint: .top, endPoint: .bottom)
                    CardRays(color: rarity.tint).frame(width: 340, height: 340).offset(y: -80)
                    VStack(spacing: 0) {
                        art.frame(width: 170, height: 138).padding(.top, 10)
                        Text(title)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(counted)))
                            .shadow(color: Color(hex: 0x1A1140), radius: 0, x: 0, y: 3)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .padding(.horizontal, 12)
                        Text(name)
                            .font(.system(.headline, design: .rounded).weight(.black))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .padding(.horizontal, 22).padding(.vertical, 6)
                            .background(rarity.ribbon, in: RibbonShape())
                            .padding(.top, 6)
                        Text(subtitle)
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(Color(hex: 0xC9C3E6))
                            .multilineTextAlignment(.center)
                            .lineLimit(3).minimumScaleFactor(0.85)
                            .padding(.horizontal, 14).padding(.top, 6)
                        Spacer(minLength: 0)
                        rarityRow.padding(.bottom, 10)
                    }
                    if rarity == .legendary { HoloShine() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(5)
            }
    }

    private var rarityRow: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< 4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < rarity.gems ? rarity.tint : .white.opacity(0.18))
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(45))
            }
            Text(rarity.label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(rarity.tint)
                .padding(.leading, 2)
        }
    }

    // MARK: Tuile du récapitulatif

    private var tile: some View {
        VStack(spacing: 4) {
            art.frame(width: 58, height: 52)
            Text(compactTitle)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 108)
        .background(LinearGradient(colors: [Color(hex: 0x33246E), Color(hex: 0x1A1140)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(rarity.frame, lineWidth: 3))
    }

    // MARK: Contenu

    private var title: String {
        switch reward {
        case .seeds: return "+\(counted)"
        case .tickets(_, let n): return "× \(n)"
        case .joker: return "× 1"
        case .item: return "Nouveau"
        }
    }

    private var name: String {
        switch reward {
        case .seeds: return Brand.currencyPlural.capitalized
        case .tickets(let kind, let n): return "Ticket\(n > 1 ? "s" : "") \(kind == .fiftyFifty ? "50/50" : "indice")"
        case .joker: return "Joker de série"
        case .item(let item): return item.name
        }
    }

    private var compactTitle: String {
        switch reward {
        case .seeds(let n): return "+\(n)"
        case .tickets(let kind, let n): return "\(n) \(kind == .fiftyFifty ? "50/50" : "indice")"
        case .joker: return "Joker"
        case .item(let item): return item.name
        }
    }

    private var accessibleTitle: String {
        switch reward {
        case .seeds(let n): return "\(n) \(Brand.currencyPlural)"
        case .tickets(let kind, let n): return "\(n) ticket\(n > 1 ? "s" : "") \(kind == .fiftyFifty ? "50/50" : "indice")"
        case .joker: return "Un joker de série"
        case .item(let item): return "\(item.name), nouveau pour Léon"
        }
    }

    private var subtitle: String {
        switch reward {
        case .seeds: return "Pour l'arbre de Léon et les aides"
        case .tickets(let kind, _): return kind == .fiftyFifty ? "Retire deux mauvaises réponses, sans graines" : "Un indice ou une seconde chance, sans graines"
        case .joker: return "Sauve ta série un jour où tu oublies de jouer"
        case .item: return "Nouveau pour Léon : il le porte déjà !"
        }
    }

    @ViewBuilder
    private var art: some View {
        switch reward {
        case .seeds: GameIcon.seeds.image
        case .tickets(let kind, _): (kind == .fiftyFifty ? GameIcon.ticketFifty : GameIcon.ticketHint).image
        case .joker: GameIcon.joker.image
        case .item(let item):
            Leon(color: .brand, pose: .proud, curl: 0.6, animated: !compact, outfit: LeonOutfit().trying(item.id, slot: item.slot))
        }
    }
}

/// Dos des cartes : violet, les quatre traits du 5 du jour barrés en or.
private struct CardBack: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0x3A1FB8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 3).padding(8))
            .overlay {
                Canvas { context, size in
                    let s = min(size.width, size.height) / 100
                    context.translateBy(x: size.width / 2 - 50 * s, y: size.height / 2 - 50 * s)
                    context.scaleBy(x: s, y: s)
                    for x in [26.0, 42, 58, 74] {
                        var bar = Path()
                        bar.move(to: CGPoint(x: x, y: 22))
                        bar.addLine(to: CGPoint(x: x, y: 78))
                        context.stroke(bar, with: .color(.white), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    }
                    var slash = Path()
                    slash.move(to: CGPoint(x: 14, y: 66))
                    slash.addLine(to: CGPoint(x: 86, y: 34))
                    context.stroke(slash, with: .color(Color.sun), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                }
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.25), radius: 0, y: 4)
            }
            .accessibilityHidden(true)
    }
}

/// Ruban du nom : bords échancrés.
private struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let notch = rect.height * 0.32
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

/// Rayons qui tournent derrière l'objet de la carte.
private struct CardRays: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time: Double = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                CardRays.draw(in: &context, size: size, time: time, color: color)
            }
            .mask(RadialGradient(colors: [.black, .clear], center: .center, startRadius: 30, endRadius: 170))
        }
        .accessibilityHidden(true)
    }

    private static func draw(in context: inout GraphicsContext, size: CGSize, time: Double, color: Color) {
        let cx = Double(size.width) / 2, cy = Double(size.height) / 2
        let r: Double = min(cx, cy)
        let turn: Double = time.truncatingRemainder(dividingBy: 14) / 14 * 2 * Double.pi
        for i in 0 ..< 18 {
            let a: Double = Double(i) / 18 * 2 * Double.pi + turn
            let b: Double = a + 0.17
            var ray = Path()
            ray.move(to: CGPoint(x: cx, y: cy))
            ray.addLine(to: CGPoint(x: cx + r * cos(a), y: cy + r * sin(a)))
            ray.addLine(to: CGPoint(x: cx + r * cos(b), y: cy + r * sin(b)))
            ray.closeSubpath()
            context.fill(ray, with: .color(color.opacity(0.33)))
        }
    }
}

/// Reflet holographique qui balaie les cartes légendaires.
private struct HoloShine: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t: Double = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
            let shift: Double = reduceMotion ? -0.6 : 0.45 - 1.8 * t
            GeometryReader { geo in
                LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .white.opacity(0.35), location: 0.45),
                                       .init(color: Color(hex: 0xFFAAF0).opacity(0.25), location: 0.52),
                                       .init(color: Color(hex: 0x8CDCFF).opacity(0.2), location: 0.58), .init(color: .clear, location: 0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: geo.size.width * 2.5)
                    .offset(x: geo.size.width * CGFloat(shift))
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
