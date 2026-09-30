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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Picker("Léon", selection: $tab) {
                    Text("Arbre").tag(Tab.tree)
                    Text("Tenue").tag(Tab.outfit)
                }
                .pickerStyle(.segmented)
                .padding(.top, Space.s)
                if tab == .outfit, progression != nil {
                    LeonWardrobe()
                } else if let progression {
                    scene(progression.tree)
                    gauge(progression.tree)
                    Button { showStages = true } label: {
                        Label("Voir toutes les étapes", systemImage: "list.bullet")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                    }
                    .buttonStyle(TextLinkStyle(color: .brand))
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
                    Button { withAnimation(Motion.standard) { tab = .outfit } } label: {
                        Label("Habiller Léon : garde-robe et boutique", systemImage: "tshirt.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                    }
                    .buttonStyle(TextLinkStyle(color: .brand))
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                }
                if let error { Text(error).font(.cfFootnote).foregroundStyle(Color.wrong) }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .scrollIndicators(.hidden)
        .clearsTabBar()
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

    // MARK: Arbre

    private func scene(_ tree: TreeState) -> some View {
        ZStack(alignment: .bottomLeading) {
            LeonTreeView(stage: tree.stage, fruits: tree.fruits)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
            // Léon grandit avec l'arbre.
            Leon(color: .brand, pose: feeding ? .tongue : .rest, curl: 0.5)
                .frame(width: 64 + CGFloat(tree.stage) * 9)
                .padding(.leading, Space.s)
            if let floating {
                Text("+\(floating)")
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(Color.correct)
                    .frame(maxWidth: .infinity)
                    .offset(y: -150)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .padding(.top, Space.s)
        .accessibilityElement(children: .combine)
    }

    private func gauge(_ tree: TreeState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(tree.stageName).font(.cfHeadline)
                Spacer()
                if tree.stage >= 6 {
                    Text("\(tree.fruits)/4 fruits").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                } else {
                    Text("Étape \(tree.stage)/6").font(.cfFootnote.weight(.bold)).foregroundStyle(Color.inkSoft)
                }
            }
            if let next = tree.nextAt, let label = tree.nextLabel {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.hairline)
                        Capsule().fill(Color.correct).frame(width: max(12, geo.size.width * tree.progress))
                    }
                }
                .frame(height: 12)
                .animation(Motion.standard, value: tree.points)
                Text("\(tree.points - tree.levelStart) / \(next - tree.levelStart) \(Brand.currencyPlural) avant \(label.lowercased())")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft).monospacedDigit()
            } else {
                Text("L'arbre est complet : tous ses fruits sont cueillis. Bravo !")
                    .font(.cfFootnote).foregroundStyle(Color.inkSoft)
            }
        }
    }

    @ViewBuilder
    private func feedButtons(_ tree: TreeState) -> some View {
        if !tree.complete {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: 10) {
                    feedButton("+10", amount: 10)
                    feedButton("+50", amount: 50)
                    feedButton("Tout", amount: seeds)
                }
                HStack(spacing: 4) {
                    Text("Tu as")
                    SeedsAmount(amount: seeds)
                    Text("· un coffre d'or à chaque étape, un objet rare à chaque fruit")
                }
                .font(.cfFootnote).foregroundStyle(Color.inkSoft)
                .lineLimit(2)
            }
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
            .accessibilityLabel("Tickets d'aide : \(tickets.fiftyFifty) 50/50, \(tickets.hint) indice. Utilisés avant tes graines pendant les parties.")
        }
    }

}
