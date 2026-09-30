import SwiftUI
import CultFiveCore

/// Le 5 du jour en plein écran. Aucune distraction : pas d'onglets, pas de chiffres parasites.
struct DailySessionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: DailySessionModel?
    @State private var showReview = false
    @State private var showShare = false

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .animation(Motion.standard, value: model?.advancing)
        .task {
            if model == nil {
                let session = DailySessionModel(service: app.service)
                model = session
                await session.start()
                #if DEBUG
                if Demo.screen == .reveal, let option = session.question?.payload.options?.first {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    session.submit(.option(option.id))
                }
                if Demo.screen == .share, case .finished = session.stage { showShare = true }
                #endif
            }
        }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? model?.resume() : model?.pause()
        }
    }

    @ViewBuilder
    private func content(_ model: DailySessionModel) -> some View {
        switch model.stage {
        case .loading:
            ProgressView().tint(Color.brand)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Space.l) {
                Text(message).font(.cfHeadline)
                Button("Fermer") { close() }.buttonStyle(.ink)
            }
            .padding(Space.gutter)
        case .question:
            if model.advancing {
                DailyNextPlaceholder(position: model.position + 1)
                    .transition(.opacity)
            } else if let question = model.question {
                QuestionScreen(
                    question: question,
                    domainName: app.domainName(question.domainId),
                    phase: model.phase,
                    badge: model.lastVerdict?.errorTransition == "corrected" ? "Erreur corrigée ✓" : nil,
                    continueTitle: model.position >= 5 ? "Voir mon résultat" : "Question suivante",
                    onSubmit: { model.submit($0) },
                    onContinue: { Task { await model.next() } },
                    onDisplayed: { model.questionDisplayed() }
                ) {
                    HStack(spacing: Space.m) {
                        ProgressPills(current: model.position, total: 5, color: DomainPalette.color(question.domainId))
                        Button { close() } label: { CloseCircle() }
                        .accessibilityLabel("Quitter (tu pourras reprendre)")
                    }
                }
                .id(question.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .overlay(alignment: .bottom) {
                    if model.isRetrying {
                        VStack(spacing: Space.s) {
                            Text("Connexion perdue. Ta réponse est gardée.").font(.cfCallout).foregroundStyle(.white)
                            Button("Renvoyer") { model.retry() }.buttonStyle(.sun)
                        }
                        .padding(Space.m)
                        .background(Color.brandDeep, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
                        .padding(Space.gutter)
                    }
                }
            }
        case .finished(let result):
            DailyResultView(result: result,
                            onReview: { showReview = true },
                            onShare: { showShare = true },
                            onClose: { close() })
                .transition(.opacity)
                .sheet(isPresented: $showReview) {
                    DailyReviewView(date: result.date)
                }
                .sheet(isPresented: $showShare) {
                    ShareSheetView(content: .daily(result, handle: app.profile?.handle ?? ""))
                }
        }
    }

    private func close() {
        Task {
            await app.refreshDaily()
            await app.refreshProfile()
        }
        dismiss()
    }
}

/// Entre deux questions : la place de la suivante, le temps qu'elle arrive (le chrono n'a pas commencé).
private struct DailyNextPlaceholder: View {
    let position: Int

    var body: some View {
        VStack(spacing: Space.m) {
            HStack {
                Spacer()
                ProgressPills(current: position, total: 5, color: .brand)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, Space.m)
            Spacer()
            Text("Question \(position) sur 5")
                .font(.cfHeadline)
                .foregroundStyle(Color.inkSoft)
            ProgressView().tint(Color.brand)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Question \(position) sur 5, chargement")
    }
}
