import SwiftUI
import CultFiveCore

struct PlaySessionView: View {
    let config: PlayConfig

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: PlaySessionModel?

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil else { return }
            let session = PlaySessionModel(config: config, service: app.service, queue: app.queue, cache: app.cache,
                                           seeds: app.profile?.seeds)
            model = session
            await session.start()
        }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? model?.resume() : model?.pause()
        }
    }

    @ViewBuilder
    private func content(_ model: PlaySessionModel) -> some View {
        switch model.stage {
        case .loading:
            ProgressView()
        case .failed(let message), .empty(let message):
            VStack(alignment: .leading, spacing: Space.l) {
                Spacer()
                Leon(color: accent, pose: .curious).frame(width: 160)
                Text(message).font(.cfHeadline).fixedSize(horizontal: false, vertical: true)
                Button("Fermer") { close() }.buttonStyle(.ink)
                Spacer()
            }
            .padding(Space.gutter)
        case .playing:
            if let question = model.current {
                QuestionScreen(
                    question: question,
                    domainName: app.domainName(question.domainId),
                    phase: model.phase,
                    removedOptions: model.removedOptions,
                    badge: model.badge,
                    continueTitle: model.isLast ? "Terminer" : "Suivante",
                    onSubmit: { model.submit($0) },
                    onContinue: { Task { await model.next() } },
                    onDisplayed: { model.questionDisplayed() },
                    trailing: { header(model) },
                    help: { helpBar(model, question: question) }
                )
                .id(question.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        case .summary(let summary):
            PlaySummaryView(config: config, summary: summary,
                            onAgain: { Task { await model.start() } },
                            onClose: { close() })
        }
    }

    private var accent: Color {
        config.domain.map(DomainPalette.color) ?? .brand
    }

    private func accent(for model: PlaySessionModel) -> Color {
        model.current.map { DomainPalette.color($0.domainId) } ?? accent
    }

    private func header(_ model: PlaySessionModel) -> some View {
        HStack(spacing: Space.m) {
            if model.isOffline {
                Image(systemName: "wifi.slash").foregroundStyle(Color.inkSoft).accessibilityLabel("Hors ligne")
            }
            if model.questions.count <= 12 {
                ProgressPills(current: model.index + 1, total: model.questions.count, color: accent(for: model))
            } else {
                Text("\(model.index + 1) / \(model.questions.count)").font(.cfNumber).foregroundStyle(Color.inkSoft)
            }
            Menu {
                Button("Terminer la partie") { Task { await model.finish() } }
                Button("Quitter sans enregistrer", role: .destructive) { close() }
            } label: {
                CloseCircle()
            }
            .accessibilityLabel("Options de partie")
        }
    }

    @ViewBuilder
    private func helpBar(_ model: PlaySessionModel, question: Question) -> some View {
        let helps = model.availableHelps(for: question)
        VStack(alignment: .leading, spacing: Space.s) {
            if let text = model.helpText {
                HStack(alignment: .top, spacing: Space.s) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Color(hex: 0xFFB020)).accessibilityHidden(true)
                    Text(text).font(.cfCallout).foregroundStyle(Color.ink)
                }
                .popCard(padding: 12, radius: Radius.s)
            }
            if !helps.isEmpty {
                HStack(spacing: Space.m) {
                    ForEach(helps, id: \.self) { kind in
                        Button {
                            Task { await model.useHelp(kind) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(title(kind))
                                SeedsAmount(amount: kind.cost, color: .inkSoft)
                            }
                            .font(.system(.footnote, design: .rounded).weight(.heavy))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(Color.paperRaised, in: Capsule())
                            .shadow(color: Color(hex: 0x3A1FB8).opacity(0.08), radius: 6, y: 3)
                        }
                        .buttonStyle(.row)
                        .foregroundStyle(Color.ink)
                        .disabled((model.seedsBalance ?? 0) < kind.cost)
                    }
                    Spacer()
                }
            }
            if let error = model.helpError {
                Text(error).font(.cfFootnote).foregroundStyle(Color.wrong)
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    private func title(_ kind: HelpKind) -> String {
        switch kind {
        case .fiftyFifty: return "50/50"
        case .hint: return "Indice"
        case .context: return "Contexte"
        }
    }

    private func close() {
        Task {
            await app.refreshProfile()
            await app.syncPending()
        }
        dismiss()
    }
}

struct PlaySummaryView: View {
    let config: PlayConfig
    let summary: PlaySessionModel.PlaySummary
    var onAgain: () -> Void
    var onClose: () -> Void

    @Environment(AppModel.self) private var app
    @State private var appeared = false

    private var accent: Color { config.domain.map(DomainPalette.color) ?? .brand }
    private var rate: Double { summary.total > 0 ? Double(summary.correct) / Double(summary.total) : 0 }
    private var perfect: Bool { summary.total > 0 && summary.correct == summary.total }
    /// Le profil n'est rafraîchi qu'à la fermeture : il porte encore l'XP d'avant la partie.
    private var levelUp: Int? {
        guard let before = app.profile?.xpTotal, let xp = summary.xp, xp > 0 else { return nil }
        let old = XPLevel(totalXP: before).level, new = XPLevel(totalXP: before + xp).level
        return new > old ? new : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    DomainTag(domainId: config.domain ?? "", name: config.domain.map { app.domainName($0) } ?? config.title)
                    Spacer()
                    Button(action: onClose) { CloseCircle() }
                        .accessibilityLabel("Fermer")
                }
                VStack(spacing: Space.s) {
                    Leon(color: accent, pose: rate >= 0.7 ? .proud : (rate >= 0.4 ? .wave : .curious), rainbow: perfect)
                        .frame(width: 150)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(summary.correct)").numeral(size: 96).foregroundStyle(accent)
                            .scaleEffect(appeared ? 1 : 0.4)
                        Text("/\(summary.total)").numeral(size: 40).foregroundStyle(Color.inkSoft)
                    }
                    Text(perfect ? "Sans faute !" : rate >= 0.7 ? "Belle partie !" : rate >= 0.4 ? "Pas mal du tout." : "Chaque erreur t'apprend quelque chose.")
                        .font(.cfHeadline).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)

                if summary.synced {
                    HStack(spacing: Space.s) {
                        chip(Text("+\(summary.xp ?? 0) XP").monospacedDigit(), tint: .brand)
                        if let seeds = summary.seeds, seeds > 0 {
                            chip(SeedsAmount(amount: seeds, signed: true, color: .correct), tint: .correct)
                        }
                        Spacer()
                    }
                }
                if summary.corrected > 0 {
                    CelebrationCard(kind: .corrected,
                                    title: "\(summary.corrected) erreur\(summary.corrected > 1 ? "s" : "") corrigée\(summary.corrected > 1 ? "s" : "")",
                                    detail: "Elles sortent de ta liste à revoir.")
                }
                if let levelUp {
                    CelebrationCard(kind: .levelUp, title: "Niveau \(levelUp)", detail: "Ton XP grimpe, continue comme ça.")
                }
                ForEach(summary.achievements, id: \.self) { name in
                    CelebrationCard(kind: .trophy, title: name)
                }
                if summary.synced, !summary.domainMoves.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ce que ça change").labelCaps()
                        ForEach(summary.domainMoves.sorted { $0.key < $1.key }, id: \.key) { domain, move in
                            HStack {
                                DomainTag(domainId: domain, name: app.domainName(domain))
                                Spacer()
                                Text("\(Int(move.0.rounded()))").foregroundStyle(Color.inkSoft)
                                Image(systemName: move.1 >= move.0 ? "arrow.up.right" : "arrow.down.right")
                                    .foregroundStyle(move.1 >= move.0 ? Color.correct : Color.wrong)
                                Text("\(Int(move.1.rounded()))").foregroundStyle(Color.ink)
                            }
                            .font(.system(.callout, design: .rounded).weight(.heavy).monospacedDigit())
                        }
                    }
                    .popCard()
                } else if !summary.synced, summary.total > 0 {
                    Label("Hors ligne : ta partie sera enregistrée dès le retour du réseau.", systemImage: "wifi.slash")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft)
                }
                VStack(spacing: Space.s) {
                    Button("Rejouer", action: onAgain).buttonStyle(InkButtonStyle(fill: accent, text: config.domain.map(DomainPalette.onColor) ?? .white))
                    Button("Terminer", action: onClose).buttonStyle(.textLink)
                }
                .padding(.top, Space.s)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xl)
        }
        .scrollIndicators(.hidden)
        .background(Color.paper)
        .overlay {
            if perfect || levelUp != nil || !summary.achievements.isEmpty { Confetti().ignoresSafeArea() }
        }
        .onAppear {
            withAnimation(Motion.bounce.delay(0.1)) { appeared = true }
            rate >= 0.7 ? Haptics.success() : Haptics.soft()
        }
    }

    private func chip(_ content: some View, tint: Color) -> some View {
        content
            .font(.system(.callout, design: .rounded).weight(.heavy))
            .foregroundStyle(tint)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
