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
                Leon(color: accent, pose: .curious).frame(width: 150)
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
        config.domain.map(DomainPalette.color) ?? .chloro
    }

    private func header(_ model: PlaySessionModel) -> some View {
        HStack(spacing: Space.m) {
            if model.isOffline {
                Image(systemName: "wifi.slash").foregroundStyle(Color.inkSoft).accessibilityLabel("Hors ligne")
            }
            Text("\(model.index + 1) / \(model.questions.count)").font(.cfNumber).foregroundStyle(Color.inkSoft)
            Menu {
                Button("Terminer la partie") { Task { await model.finish() } }
                Button("Quitter sans enregistrer", role: .destructive) { close() }
            } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Color.inkSoft)
                    .frame(width: 44, height: 44)
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
                    Image(systemName: "lightbulb.min").foregroundStyle(Color.inkSoft).accessibilityHidden(true)
                    Text(text).font(.cfCallout).foregroundStyle(Color.ink)
                }
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
                            .font(.cfFootnote.weight(.medium))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                            .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    Text(config.domain.map { app.domainName($0) } ?? config.title).labelCaps()
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Color.inkSoft).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Fermer")
                }
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(summary.correct)").numeral(size: 110)
                    Text("/\(summary.total)").numeral(size: 44, weight: .semibold).foregroundStyle(Color.inkSoft)
                    Spacer()
                    Leon(color: config.domain.map(DomainPalette.color) ?? .chloro,
                         pose: summary.total > 0 && Double(summary.correct) / Double(summary.total) >= 0.7 ? .proud : .rest)
                        .frame(width: 96)
                }
                if summary.corrected > 0 {
                    Label("\(summary.corrected) erreur\(summary.corrected > 1 ? "s" : "") corrigée\(summary.corrected > 1 ? "s" : "") ✓",
                          systemImage: "checkmark")
                        .font(.system(.headline)).foregroundStyle(Color.correct)
                }
                Hairline()
                if summary.synced {
                    HStack(spacing: Space.m) {
                        Text("+\(summary.xp ?? 0) XP").monospacedDigit()
                        if let seeds = summary.seeds, seeds > 0 { SeedsAmount(amount: seeds, signed: true) }
                        Spacer()
                    }
                    .font(.system(.callout).weight(.semibold))
                    ForEach(summary.domainMoves.sorted { $0.key < $1.key }, id: \.key) { domain, move in
                        HStack {
                            Circle().fill(DomainPalette.color(domain)).frame(width: 8, height: 8)
                            Text(app.domainName(domain))
                            Spacer()
                            Text("\(Int(move.0.rounded())) → \(Int(move.1.rounded()))").monospacedDigit()
                                .foregroundStyle(move.1 >= move.0 ? Color.ink : Color.inkSoft)
                        }
                        .font(.cfCallout)
                    }
                } else if summary.total > 0 {
                    Label("Hors ligne : ta partie sera enregistrée dès le retour du réseau.", systemImage: "wifi.slash")
                        .font(.cfCallout).foregroundStyle(Color.inkSoft)
                }
                VStack(alignment: .leading, spacing: Space.s) {
                    Button("Rejouer", action: onAgain).buttonStyle(.ink)
                    Button("Terminer", action: onClose).buttonStyle(.textLink)
                }
                .padding(.top, Space.m)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xl)
        }
        .background(Color.paper)
    }
}
