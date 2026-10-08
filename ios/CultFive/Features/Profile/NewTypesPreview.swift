import SwiftUI
import CultFiveCore

/// Canal de distribution : l'aperçu des nouveaux types n'existe que dans les builds de test (TestFlight, Xcode),
/// jamais dans la version de l'App Store.
enum AppChannel {
    static var isTestBuild: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}

/// Aperçu des nouveaux types de réponses (TestFlight) : de vraies questions rangées dans l'app, corrigées sur le téléphone,
/// pour essayer chaque écran avant que le serveur ne les envoie.
struct NewTypesPreviewView: View {
    @State private var questions: [Question] = []

    private struct Kind: Identifiable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let matches: (Question) -> Bool
    }

    private let kinds: [Kind] = [
        Kind(id: "counter", title: "Compteur", detail: "Un nombre, marge annoncée ou nombre exact", symbol: "plusminus", matches: { $0.type == .counter }),
        Kind(id: "timeline", title: "Frise", detail: "Glisser jusqu'à la bonne année", symbol: "calendar", matches: { $0.type == .timeline }),
        Kind(id: "gauge", title: "Jauge", detail: "Un pourcentage", symbol: "drop.fill", matches: { $0.type == .gauge }),
        Kind(id: "proportion", title: "Proportions", detail: "Étirer à la vraie taille", symbol: "arrow.up.and.down", matches: { $0.type == .proportion }),
        Kind(id: "letters", title: "Lettres mélangées", detail: "Retrouver le mot", symbol: "textformat.abc", matches: { $0.type == .letters }),
        Kind(id: "word_order", title: "Mots dans l'ordre", detail: "Proverbes, citations, répliques", symbol: "text.word.spacing", matches: { $0.type == .wordOrder }),
        Kind(id: "image_choice", title: "Drapeaux", detail: "Quatre drapeaux, un seul bon", symbol: "flag.fill", matches: { $0.type == .imageChoice }),
        Kind(id: "number_target", title: "Le compte est bon", detail: "Atteindre la cible avec + − × ÷", symbol: "function", matches: { $0.type == .numberTarget }),
        Kind(id: "riddle", title: "Mot mystère", detail: "Trois indices, bonus si trouvé tôt", symbol: "questionmark.bubble.fill", matches: { $0.type == .riddle }),
        Kind(id: "map_pin", title: "Épingle sur la carte", detail: "Placer le lieu, marge en km", symbol: "mappin.and.ellipse", matches: { $0.type == .mapPin }),
        Kind(id: "sort_bins", title: "Tri express", detail: "Glisser dans deux paniers", symbol: "tray.2.fill", matches: { $0.type == .sort && $0.payload.layout != "timeline" }),
        Kind(id: "sort_timeline", title: "Pyramide des âges", detail: "Chacun à son époque", symbol: "hourglass", matches: { $0.type == .sort && $0.payload.layout == "timeline" }),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("Réservé aux builds de test. Ces questions sont rangées dans l'app et corrigées sur ton téléphone : rien n'est envoyé au serveur, ni Elo, ni graines.")
                    .font(.cfFootnote)
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(kinds) { kind in
                        let list = questions.filter(kind.matches)
                        NavigationLink {
                            PreviewPlayView(title: kind.title, questions: list)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: kind.symbol)
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(kind.title).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Color.ink)
                                    Text("\(kind.detail) · \(list.count) questions").font(.cfFootnote).foregroundStyle(Color.inkSoft)
                                }
                                Spacer(minLength: Space.s)
                                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Color.inkSoft.opacity(0.6))
                            }
                            .padding(.horizontal, Space.m)
                            .frame(minHeight: 60)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.row)
                        .disabled(list.isEmpty)
                        if kind.id != kinds.last?.id {
                            Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 62)
                        }
                    }
                }
                .background(Color.paperRaised, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.l)
        }
        .scrollIndicators(.hidden)
        .clearsTabBar()
        .background(Color.paper)
        .navigationTitle("Nouveaux types")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { if questions.isEmpty { questions = Self.load() } }
    }

    static func load() -> [Question] {
        guard let url = Bundle.main.url(forResource: "new_types.preview", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Question].self, from: data)) ?? []
    }
}

/// Une série de questions d'un même type, jouée et corrigée sur place.
private struct PreviewPlayView: View {
    let title: String
    let questions: [Question]

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var phase: AnswerPhase = .answering

    var body: some View {
        Group {
            if index < questions.count {
                let question = questions[index]
                QuestionScreen(question: question, domainName: app.domainName(question.domainId), phase: phase,
                               continueTitle: index + 1 < questions.count ? "Question suivante" : "Terminer",
                               onSubmit: { given in submit(given, for: question) },
                               onContinue: next) {
                    Text("\(index + 1) / \(questions.count)")
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.inkSoft)
                }
                .id(question.id)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func submit(_ given: GivenAnswer, for question: Question) {
        guard phase.isAnswering, let reveal = question.reveal else { return }
        let correct = AnswerEvaluator.isCorrect(given, for: question) ?? false
        if correct { Haptics.success() } else { Haptics.error() }
        phase = .revealed(given: given, isCorrect: correct, reveal: reveal)
    }

    private func next() {
        if index + 1 < questions.count {
            index += 1
            phase = .answering
        } else {
            dismiss()
        }
    }
}
