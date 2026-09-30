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
                    ChestsWaitingCard(count: progression.chests.count,
                                      tier: progression.chests.map(\.tier).max { $0.rank < $1.rank } ?? .wood) {
                        app.openChests()
                    }
                }
                tickets(progression.tickets)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            }
            if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.m)
    }

    // MARK: Arbre

    /// La scène : ciel clair, sol en bas, l'arbre au centre et Léon debout dans l'herbe à côté.
    private func scene(_ tree: TreeState) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: 0xDFF1FF), Color(hex: 0xF3FAFF)], startPoint: .top, endPoint: .bottom)
            SkyDecor().allowsHitTesting(false)
            VStack(spacing: 0) {
                Rectangle().fill(Color(hex: 0x69DB7C)).frame(height: 10)
                Rectangle().fill(Color(hex: 0xA47551)).frame(height: 26)
            }
            LeonTreeView(stage: tree.stage, fruits: tree.fruits, scene: true)
                .frame(height: 236)
                .padding(.bottom, 36 - 236 * 32 / 200)
            HStack {
                Leon(color: .brand, pose: feeding ? .tongue : .rest, curl: 0.5)
                    .frame(width: 88 + CGFloat(tree.stage) * 6)
                    .padding(.leading, Space.m)
                    .padding(.bottom, 24)
                Spacer()
            }
            if let floating {
                Text("+\(floating)")
                    .font(.system(.title, design: .rounded).weight(.black))
                    .foregroundStyle(Color.correct)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, Space.l)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(height: 236)
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
            if let next = tree.nextAt, let label = tree.nextLabel {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline)
                        Capsule().fill(Color.correct).frame(width: max(12, geo.size.width * tree.progress))
                    }
                }
                .frame(height: 10)
                .animation(Motion.standard, value: tree.points)
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
            if !reduceMotion { withAnimation(Motion.bounce) { floating = result.fed } }
            var lines: [String] = []
            if result.newChests > 0 {
                lines.append("Nouvelle étape : \(result.tree.stageName) !")
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
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Impossible de nourrir l'arbre. Réessaie."
        }
        feeding = false
    }

    // MARK: Tickets et tenue

    @ViewBuilder
    private func tickets(_ tickets: HelpTickets) -> some View {
        if tickets.fiftyFifty + tickets.hint > 0 {
            HStack(spacing: Space.m) {
                Text("🎟️ \(tickets.fiftyFifty) ticket\(tickets.fiftyFifty > 1 ? "s" : "") 50/50")
                Text("💡 \(tickets.hint) ticket\(tickets.hint > 1 ? "s" : "") indice")
            }
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(Color.inkSoft)
            .accessibilityLabel("Tickets d'aide : \(tickets.fiftyFifty) 50/50, \(tickets.hint) indice ou seconde chance. Utilisés avant tes graines pendant les parties.")
        }
    }

}

/// Le ciel au-dessus de l'arbre : un soleil et deux nuages qui dérivent doucement (l'arbre remplira la place en grandissant).
private struct SkyDecor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width
                Circle().fill(Color.sun.opacity(0.9)).frame(width: 44, height: 44)
                    .shadow(color: Color.sun.opacity(0.6), radius: 14)
                    .position(x: w - 46, y: 42)
                cloud.position(x: drift(t, speed: 6, offset: 0, width: w), y: 58)
                cloud.scaleEffect(0.7).position(x: drift(t, speed: 4, offset: w * 0.55, width: w), y: 100)
            }
        }
        .accessibilityHidden(true)
    }

    private var cloud: some View {
        ZStack {
            Capsule().fill(.white).frame(width: 70, height: 22).offset(y: 6)
            Circle().fill(.white).frame(width: 30, height: 30).offset(x: -12, y: -2)
            Circle().fill(.white).frame(width: 38, height: 38).offset(x: 10, y: -6)
        }
        .opacity(0.9)
    }

    /// Les nuages traversent le ciel lentement, puis reviennent par la gauche.
    private func drift(_ t: Double, speed: Double, offset: Double, width: Double) -> Double {
        let span = width + 120
        return (t * speed + offset).truncatingRemainder(dividingBy: span) - 60
    }
}
