import SwiftUI
import CultFiveCore

/// Léon, en deux onglets. Arbre : on le nourrit de graines, il grandit en 6 étapes (un coffre d'or à chacune), puis
/// donne ses fruits (objets rares). Tenue : garde-robe et boutique réunies (voir `LeonWardrobe`).
struct LeonTreeScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.leonOutfit) private var outfit
    @State private var feeding = false
    @State private var floating: Int?
    @State private var news: [String] = []
    @State private var error: String?
    @State private var showStages = false
    @State private var tab: Tab = .tree
    /// Graines qui volent vers l'arbre (instant du don).
    @State private var seedFlight: Date?
    /// Petit rebond de l'arbre quand les graines arrivent.
    @State private var boing = false
    /// L'arbre vient de changer d'étape : Léon est fier.
    @State private var proud = false

    enum Tab: Hashable { case tree, outfit }

    private var progression: ProgressionOverview? { app.progression }
    private var seeds: Int { app.profile?.seeds ?? progression?.seeds ?? 0 }

    @Environment(\.tabBarClearance) private var clearance

    var body: some View {
        Group {
            if tab == .outfit {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.l) {
                        picker
                        LeonWardrobe()
                    }
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.l)
                }
                .scrollIndicators(.hidden)
                .clearsTabBar()
            } else {
                // L'arbre tient sur l'écran ; il ne défile que s'il le faut vraiment (petit iPhone, célébration).
                ViewThatFits(in: .vertical) {
                    treeContent.padding(.bottom, clearance)
                    ScrollView { treeContent }
                        .scrollIndicators(.hidden)
                        .clearsTabBar()
                }
            }
        }
        .background(Color.paper)
        .navigationTitle("Léon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Color.paper, for: .navigationBar)
        .task { await app.refreshProfile() }
        .sheet(isPresented: $showStages) {
            if let tree = progression?.tree { TreeStagesSheet(tree: tree) }
        }
    }

    private var picker: some View {
        Picker("Léon", selection: $tab) {
            Text("Arbre").tag(Tab.tree)
            Text("Tenue").tag(Tab.outfit)
        }
        .pickerStyle(.segmented)
        .padding(.top, Space.s)
    }

    private var treeContent: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            picker
            if let progression {
                scene(progression.tree)
                gauge(progression.tree)
                feedButtons(progression.tree)
                ForEach(news, id: \.self) { line in
                    CelebrationCard(kind: .levelUp, title: line)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if !progression.chests.isEmpty {
                    ChestsWaitingCard(tiers: progression.chests.map(\.tier)) {
                        app.openChests()
                    }
                }
                FreeChestOffer()
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            }
            if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.m)
    }

    // MARK: Arbre

    /// La scène : ciel, soleil, nuages, colline, herbe ; l'arbre au centre et Léon dans l'herbe à côté.
    private func scene(_ tree: TreeState) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                Canvas { context, size in TreeScenery.draw(in: &context, size: size, time: time) }
                LeonTreeView(stage: tree.stage, fruits: tree.fruits, scene: true, time: reduceMotion ? nil : time)
                    .frame(height: 236)
                    .scaleEffect(x: boing ? 0.96 : 1, y: boing ? 1.06 : 1, anchor: .bottom)
                    .padding(.bottom, 44 - 236 * 32 / 200)
                    .offset(x: 26)
                HStack {
                    Leon(color: .brand, pose: proud ? .proud : (feeding ? .tongue : .rest), curl: 0.5)
                        .frame(width: 88 + CGFloat(tree.stage) * 5)
                        .padding(.leading, Space.s)
                        .padding(.bottom, 30)
                    Spacer()
                }
                if let seedFlight {
                    Canvas { context, size in
                        TreeScenery.drawSeeds(in: &context, size: size, elapsed: timeline.date.timeIntervalSince(seedFlight), stage: tree.stage)
                    }
                    .allowsHitTesting(false)
                }
                if let floating {
                    Text("+\(floating)")
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(Color.correct)
                        .shadow(color: .white, radius: 0, y: 2)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, Space.l)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                }
            }
        }
        .frame(height: 270)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Étape, jauge vers la suivante et lien vers toutes les étapes, dans une carte.
    private func gauge(_ tree: TreeState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(tree.stageName).font(.cfTitle3)
                Text(tree.stage >= 6 ? "· \(tree.fruits)/4 fruits" : "· étape \(tree.stage)/6")
                    .font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                Spacer(minLength: Space.s)
                Button { showStages = true } label: {
                    HStack(spacing: 2) {
                        Text("Toutes les étapes")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.brand)
                }
            }
            StageDots(stage: tree.stage, progress: tree.complete ? 1 : tree.progress, fruitsDone: tree.stage >= 6)
            if let next = tree.nextAt, let label = tree.nextLabel {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline)
                        Capsule().fill(Color.correct).frame(width: max(12, geo.size.width * tree.progress))
                    }
                }
                .frame(height: 12)
                .animation(Motion.bounce, value: tree.points)
                Text("\(tree.points - tree.levelStart) / \(next - tree.levelStart) \(Brand.currencyPlural) avant \(label.lowercased())")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft).monospacedDigit()
            } else {
                Text("L'arbre est complet : tous ses fruits sont cueillis. Bravo !")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
        .popCard(padding: 14)
    }

    /// Nourrir l'arbre : titre et solde sur une ligne, trois boutons, une seule ligne d'explication.
    @ViewBuilder
    private func feedButtons(_ tree: TreeState) -> some View {
        if !tree.complete {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Nourrir l'arbre").font(.cfTitle3)
                    Spacer()
                    SeedsAmount(amount: seeds)
                        .font(.cfNumber)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.correct.opacity(0.12), in: Capsule())
                }
                HStack(spacing: 10) {
                    feedButton("+10", amount: 10)
                    feedButton("+50", amount: 50)
                    feedButton("Tout", amount: seeds)
                }
                Text("Un coffre d'or à chaque étape, un objet rare à chaque fruit.")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .popCard(padding: 14)
        }
    }

    private func feedButton(_ title: String, amount: Int) -> some View {
        Button {
            Task { await feed(amount) }
        } label: {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.correct, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
        }
        .buttonStyle(.row)
        .disabled(feeding || seeds <= 0 || amount <= 0)
        .opacity(seeds <= 0 ? 0.45 : 1)
        .accessibilityLabel(title == "Tout" ? "Donner toutes mes graines" : "Donner \(amount) graines")
    }

    private func feed(_ amount: Int) async {
        guard !feeding else { return }
        feeding = true
        error = nil
        Haptics.soft()
        do {
            let result = try await app.service.feedTree(amount: min(amount, seeds), clientId: UUID())
            if !reduceMotion {
                seedFlight = Date()
                withAnimation(Motion.bounce) { floating = result.fed }
                // Les graines arrivent : l'arbre rebondit.
                Task {
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) { boing = true }
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.35)) { boing = false }
                }
            }
            var lines: [String] = []
            if result.newChests > 0 {
                lines.append("Nouvelle étape : \(result.tree.stageName) !")
                proud = true
            }
            for item in result.newItems { lines.append("Fruit cueilli : \(item.name)") }
            if !lines.isEmpty {
                SoundFX.play(.reward)
                Haptics.success()
                withAnimation(Motion.bounce) { news = lines + news }
            }
            await app.refreshProfile()
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(Motion.standard) { floating = nil }
            seedFlight = nil
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            proud = false
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Impossible de nourrir l'arbre. Réessaie."
        }
        feeding = false
    }


}

/// Les 6 étapes de l'arbre en traits : faites en vert, celle en cours remplie à moitié selon la jauge.
private struct StageDots: View {
    let stage: Int
    let progress: Double
    var fruitsDone = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1 ... 6, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline)
                        Capsule().fill(Color.correct).frame(width: geo.size.width * fill(i))
                    }
                }
                .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func fill(_ i: Int) -> CGFloat {
        if i < stage || fruitsDone { return 1 }
        return i == stage ? CGFloat(progress) : 0
    }
}

/// Le décor de l'arbre : ciel, soleil qui tourne, nuages qui dérivent, colline au loin, herbe qui bouge, terre.
private enum TreeScenery {
    static func draw(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let w = Double(size.width), h = Double(size.height)
        let gy: Double = h - 44
        // Ciel.
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xCDEBFF), Color(hex: 0xF3FAFF)]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        // Soleil, halo et rayons.
        let sx: Double = w - 50, sy: Double = 44
        context.fill(Path(ellipseIn: CGRect(x: sx - 70, y: sy - 70, width: 140, height: 140)),
                     with: .radialGradient(Gradient(colors: [Color.sun.opacity(0.55), Color.sun.opacity(0)]),
                                           center: CGPoint(x: sx, y: sy), startRadius: 10, endRadius: 70))
        for i in 0 ..< 10 {
            let a: Double = Double(i) / 10 * 2 * Double.pi + t * 0.15
            var ray = context
            ray.translateBy(x: sx, y: sy)
            ray.rotate(by: .radians(a))
            ray.fill(Path(roundedRect: CGRect(x: -3, y: -36, width: 6, height: 10), cornerRadius: 3), with: .color(Color.sun.opacity(0.8)))
        }
        circle(&context, sx, sy, 22, Color.sun)
        circle(&context, sx - 6, sy - 6, 7, .white.opacity(0.5))
        // Nuages.
        cloud(&context, x: drift(t, 9, 0, w), y: 56, scale: 1)
        cloud(&context, x: drift(t, 6, w * 0.55, w), y: 96, scale: 0.7)
        cloud(&context, x: drift(t, 4, w * 0.3, w), y: 30, scale: 0.5)
        // Colline au loin et petits arbres.
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: gy - 6))
        hill.addCurve(to: CGPoint(x: w * 0.6, y: gy - 14), control1: CGPoint(x: w * 0.25, y: gy - 46), control2: CGPoint(x: w * 0.45, y: gy - 30))
        hill.addCurve(to: CGPoint(x: w, y: gy - 24), control1: CGPoint(x: w * 0.75, y: gy - 2), control2: CGPoint(x: w * 0.9, y: gy - 36))
        hill.addLine(to: CGPoint(x: w, y: h))
        hill.addLine(to: CGPoint(x: 0, y: h))
        hill.closeSubpath()
        context.fill(hill, with: .color(Color(hex: 0xB2F2BB)))
        for (x, y, r) in [(w * 0.12, gy - 28, 9.0), (w * 0.2, gy - 34, 12.0), (w * 0.86, gy - 26, 10.0)] {
            context.fill(Path(CGRect(x: x - 1.5, y: y, width: 3, height: 10)), with: .color(Color(hex: 0x7BCB8A)))
            circle(&context, x, y - r * 0.4, r, Color(hex: 0x8FD89B))
        }
        // Herbe.
        var grass = Path()
        grass.move(to: CGPoint(x: 0, y: gy))
        grass.addCurve(to: CGPoint(x: w, y: gy - 4), control1: CGPoint(x: w * 0.3, y: gy - 8), control2: CGPoint(x: w * 0.7, y: gy + 6))
        grass.addLine(to: CGPoint(x: w, y: h))
        grass.addLine(to: CGPoint(x: 0, y: h))
        grass.closeSubpath()
        context.fill(grass, with: .color(Color(hex: 0x69DB7C)))
        // Terre et cailloux.
        var dirt = Path()
        dirt.move(to: CGPoint(x: 0, y: gy + 12))
        dirt.addCurve(to: CGPoint(x: w, y: gy + 10), control1: CGPoint(x: w * 0.3, y: gy + 6), control2: CGPoint(x: w * 0.7, y: gy + 18))
        dirt.addLine(to: CGPoint(x: w, y: h))
        dirt.addLine(to: CGPoint(x: 0, y: h))
        dirt.closeSubpath()
        context.fill(dirt, with: .color(Color(hex: 0xA47551)))
        for (x, y, r) in [(w * 0.15, h - 14, 4.0), (w * 0.42, h - 10, 3.0), (w * 0.7, h - 16, 5.0), (w * 0.9, h - 8, 3.0)] {
            context.fill(Path(ellipseIn: CGRect(x: x - r * 1.4, y: y - r, width: r * 2.8, height: r * 2)), with: .color(Color(hex: 0x8A5E3F)))
        }
        // Brins d'herbe et fleurettes.
        for i in 0 ..< 14 {
            let x: Double = (Double(i) * w / 13 + 7).truncatingRemainder(dividingBy: w)
            let y: Double = gy + 2 + Double((i * 7) % 5)
            let bend: Double = sin(t * 2 + Double(i)) * 1.5
            var blade = Path()
            blade.move(to: CGPoint(x: x, y: y + 4))
            blade.addQuadCurve(to: CGPoint(x: x + bend * 1.6, y: y - 6), control: CGPoint(x: x + bend, y: y - 2))
            context.stroke(blade, with: .color(Color(hex: 0x40C057)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        for (x, color) in [(w * 0.08, Color(hex: 0xFCC2D7)), (w * 0.33, Color.white), (w * 0.93, Color.sun), (w * 0.58, Color(hex: 0xFCC2D7))] {
            circle(&context, x, gy + 4, 3.5, color)
            circle(&context, x, gy + 4, 1.4, Color.sun)
        }
    }

    /// Graines qui partent du bas et filent en arc jusqu'à l'arbre (0,8 s environ).
    static func drawSeeds(in context: inout GraphicsContext, size: CGSize, elapsed: Double, stage: Int) {
        let w = Double(size.width), h = Double(size.height)
        let seed = context.resolve(Image("seeds"))
        // Hauteur du feuillage au-dessus du sol, selon l'étape.
        let heights: [Double] = [20, 40, 70, 100, 130, 150]
        let lift: Double = heights[min(max(stage, 1), 6) - 1]
        let target = CGPoint(x: w / 2 + 26, y: h - 44 - lift)
        for i in 0 ..< 10 {
            let noise: Double = abs(sin(Double(i) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
            let k: Double = min(max((elapsed - Double(i) * 0.04) / 0.62, 0), 1)
            guard k > 0, k < 1 else { continue }
            let x0: Double = w * (0.2 + 0.6 * noise), y0: Double = h + 10
            let tx: Double = Double(target.x) + (noise - 0.5) * 40, ty: Double = Double(target.y) + (noise - 0.5) * 30
            let arc: Double = 60 + noise * 50
            let x: Double = x0 + (tx - x0) * k
            let y: Double = y0 + (ty - y0) * k - sin(k * Double.pi) * arc
            let side: Double = 20 * (1 - k * 0.35)
            context.draw(seed, in: CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side))
        }
    }

    private static func circle(_ context: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(color))
    }

    private static func cloud(_ context: inout GraphicsContext, x: Double, y: Double, scale: Double) {
        var c = context
        c.translateBy(x: x, y: y)
        c.scaleBy(x: scale, y: scale)
        c.opacity = 0.95
        c.fill(Path(roundedRect: CGRect(x: -36, y: -4, width: 72, height: 22), cornerRadius: 11), with: .color(.white))
        c.fill(Path(ellipseIn: CGRect(x: -27, y: -19, width: 30, height: 30)), with: .color(.white))
        c.fill(Path(ellipseIn: CGRect(x: -9, y: -27, width: 38, height: 38)), with: .color(.white))
        c.fill(Path(roundedRect: CGRect(x: -34, y: 10, width: 68, height: 8), cornerRadius: 4), with: .color(Color(hex: 0xE3F0FA).opacity(0.5)))
    }

    /// Les nuages traversent le ciel lentement, puis reviennent par la gauche.
    private static func drift(_ t: Double, _ speed: Double, _ offset: Double, _ width: Double) -> Double {
        let span = width + 140
        return (t * speed + offset).truncatingRemainder(dividingBy: span) - 70
    }
}
