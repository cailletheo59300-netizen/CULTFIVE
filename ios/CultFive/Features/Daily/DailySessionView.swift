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
        .task {
            if model == nil {
                let session = DailySessionModel(service: app.service)
                model = session
                await session.start()
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
            ProgressView().tint(Color.ink)
        case .failed(let message):
            VStack(alignment: .leading, spacing: Space.l) {
                Text(message).font(.cfHeadline)
                Button("Fermer") { close() }.buttonStyle(.ink)
            }
            .padding(Space.gutter)
        case .question:
            if let question = model.question {
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
                        Text("\(model.position) / 5")
                            .font(.cfNumber)
                            .foregroundStyle(Color.inkSoft)
                        Button { close() } label: {
                            Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Color.inkSoft)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Quitter (tu pourras reprendre)")
                    }
                }
                .id(question.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .overlay(alignment: .bottom) {
                    if model.isRetrying {
                        VStack(spacing: Space.s) {
                            Text("Connexion perdue. Ta réponse est gardée.").font(.cfCallout).foregroundStyle(Color.paper)
                            Button("Renvoyer") { model.retry() }.buttonStyle(.chloro)
                        }
                        .padding(Space.m)
                        .background(Color.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
